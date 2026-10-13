"""SSLCommerz hosted checkout. Only server-validated payments activate promotions."""
import secrets
from decimal import Decimal, InvalidOperation
from urllib.parse import urlparse

import requests
from django.conf import settings
from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import permissions, serializers
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.response import Response

from .models import Payment, Promotion
from .services import activate_promotion


def payment_enabled():
    base = urlparse(settings.PAYMENT_CALLBACK_BASE_URL)
    return bool(settings.SSLCOMMERZ_STORE_ID and settings.SSLCOMMERZ_STORE_PASSWORD and
        base.hostname and base.scheme in (['http', 'https'] if settings.SSLCOMMERZ_SANDBOX else ['https']) and
        not base.username and not base.query and not base.fragment)


def gateway_base(sandbox):
    return 'https://sandbox.sslcommerz.com' if sandbox else 'https://securepay.sslcommerz.com'


def credentials():
    return {'store_id': settings.SSLCOMMERZ_STORE_ID, 'store_passwd': settings.SSLCOMMERZ_STORE_PASSWORD}


def gateway_request(method, path, sandbox, data):
    try:
        response = requests.request(method, gateway_base(sandbox) + path,
            **({'data': data} if method == 'POST' else {'params': data}), timeout=20)
        response.raise_for_status()
        result = response.json()
        if not isinstance(result, dict):
            raise ValueError()
        return result
    except (requests.RequestException, ValueError):
        raise serializers.ValidationError('The payment provider is unavailable. Refresh payment status before trying again.')


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'transaction_id', 'amount', 'status', 'gateway_url', 'sandbox', 'created_at']
        read_only_fields = fields


def checkout(promotion_id, user):
    if not payment_enabled():
        raise serializers.ValidationError('Online payments are not configured. Contact the administrator for payment confirmation.')
    # Serialize attempt creation against activation and other checkout requests.
    with transaction.atomic():
        promotion = get_object_or_404(Promotion.objects.select_for_update(), pk=promotion_id, professional__user=user)
        if promotion.status != 'pending':
            raise serializers.ValidationError('Only pending promotions can be paid.')
        if not user.phone:
            raise serializers.ValidationError('Add your phone number in Account before checkout.')
        previous = promotion.payments.exclude(status='failed').order_by('-id').first()
        if previous:
            if previous.status == 'pending' and previous.gateway_url:
                return previous
            raise serializers.ValidationError('A payment attempt already exists. Refresh its status or contact the administrator.')
        payment = Payment.objects.create(promotion=promotion, amount=promotion.price_paid,
            transaction_id='SC' + secrets.token_hex(12), sandbox=settings.SSLCOMMERZ_SANDBOX)
    callback = settings.PAYMENT_CALLBACK_BASE_URL.rstrip('/') + '/api/payments/'
    payload = dict(credentials(), total_amount=str(payment.amount), currency='BDT', tran_id=payment.transaction_id,
        success_url=callback + 'return/', fail_url=callback + 'return/', cancel_url=callback + 'return/',
        ipn_url=callback + 'ipn/', cus_name=user.get_full_name() or user.username, cus_email=user.email,
        cus_phone=user.phone, cus_add1=promotion.area.name, cus_city=promotion.area.city,
        cus_postcode='1200', cus_country='Bangladesh', shipping_method='NO', num_of_item=1,
        product_name=f'Promotion {promotion.pk}', product_category='service', product_profile='non-physical-goods')
    result = gateway_request('POST', '/gwprocess/v4/api.php', payment.sandbox, payload)
    if result.get('status') != 'SUCCESS':
        payment.status = 'failed'
        payment.save(update_fields=['status'])
        raise serializers.ValidationError('The provider could not create checkout. Check your merchant configuration.')
    url = urlparse(result.get('GatewayPageURL', ''))
    if url.scheme != 'https' or url.hostname not in ['sandbox.sslcommerz.com', 'securepay.sslcommerz.com'] or url.username:
        # Keep the attempt unresolved: a session may exist at the provider.
        raise serializers.ValidationError('The provider returned an invalid checkout address. Contact the administrator.')
    with transaction.atomic():
        current = Payment.objects.select_for_update().get(pk=payment.pk)
        current.gateway_url = result['GatewayPageURL']
        current.session_key = result.get('sessionkey', '')
        if current.status == 'initiating':
            current.status = 'pending'
        current.save(update_fields=['gateway_url', 'session_key', 'status'])
    return current


def validate_payment(payment, validation_id):
    if payment.sandbox != settings.SSLCOMMERZ_SANDBOX or not payment_enabled():
        raise serializers.ValidationError('The payment environment changed. Contact the administrator.')
    verified = gateway_request('GET', '/validator/api/validationserverAPI.php', payment.sandbox,
        dict(credentials(), val_id=validation_id, format='json'))
    try:
        matches = (verified.get('tran_id') == payment.transaction_id and verified.get('val_id') == validation_id and
            verified.get('currency') == 'BDT' and Decimal(str(verified.get('amount'))) == payment.amount and
            verified.get('status') in ['VALID', 'VALIDATED'])
    except InvalidOperation:
        matches = False
    if not matches:
        raise serializers.ValidationError('Payment verification failed. The promotion remains unpaid.')
    # Match promotion -> payment lock order used during checkout.
    with transaction.atomic():
        promotion = Promotion.objects.select_for_update().get(pk=payment.promotion_id)
        payment = Payment.objects.select_for_update().get(pk=payment.pk)
        if payment.status == 'paid':
            return payment
        payment.validation_id = validation_id
        if str(verified.get('risk_level')) != '0' or promotion.status != 'pending':
            payment.status = 'review'
        else:
            payment.status = 'paid'
            activate_promotion(promotion.pk)
        payment.save(update_fields=['status', 'validation_id'])
    return payment


def refresh_payment(payment):
    if payment.status == 'paid':
        return payment
    if not payment_enabled() or payment.sandbox != settings.SSLCOMMERZ_SANDBOX:
        raise serializers.ValidationError('Configure the original payment environment to check this transaction.')
    lookup = {'sessionkey': payment.session_key} if payment.session_key else {'tran_id': payment.transaction_id}
    result = gateway_request('GET', '/validator/api/merchantTransIDvalidationAPI.php', payment.sandbox,
        dict(credentials(), format='json', **lookup))
    candidates = result.get('element', [result])
    if not isinstance(candidates, list):
        raise serializers.ValidationError('The provider returned an unexpected status. Try again later.')
    for candidate in candidates:
        if not isinstance(candidate, dict) or candidate.get('tran_id') != payment.transaction_id:
            continue
        if candidate.get('status') in ['VALID', 'VALIDATED'] and candidate.get('val_id'):
            return validate_payment(payment, candidate['val_id'])
        if candidate.get('status') in ['FAILED', 'CANCELLED']:
            Payment.objects.filter(pk=payment.pk, status__in=['pending', 'initiating']).update(status='failed')
    payment.refresh_from_db()
    return payment


@api_view(['POST'])
@authentication_classes([])
@permission_classes([permissions.AllowAny])
def ipn(request):
    transaction_id, validation_id = request.data.get('tran_id'), request.data.get('val_id')
    if not isinstance(transaction_id, str) or not isinstance(validation_id, str) or len(validation_id) > 255:
        raise serializers.ValidationError('Supply a transaction and validation ID.')
    payment = get_object_or_404(Payment, transaction_id=transaction_id)
    payment = validate_payment(payment, validation_id)
    return Response({'status': payment.status})


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([permissions.AllowAny])
def payment_return(request):
    # Browser redirects are informational. App refresh and IPN independently verify payment.
    return HttpResponse('<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>SkillConnect payment</title></head><body><h1>Return to SkillConnect</h1>'
        '<p>Open Promotions and tap Refresh payment status to verify your payment.</p></body></html>')
