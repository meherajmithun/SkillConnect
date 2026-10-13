import re
from datetime import timedelta
from decimal import Decimal
from unittest.mock import Mock

import pytest
from django.core import mail
from django.core.cache import cache
from django.utils import timezone

from marketplace.models import (AvailabilitySlot, Booking, EmailChallenge, Message,
    Notification, Payment, Promotion, PushDelivery, Device)
from marketplace.payments import validate_payment
from marketplace.tests.test_marketplace import world, client, booking_payload, make_booking

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def email_and_throttle(settings):
    settings.EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
    cache.clear()
    yield
    cache.clear()


def mail_code():
    return re.search(r'is (\d{8})\.', mail.outbox[-1].body).group(1)


def test_reset_is_private_one_use_and_revokes_existing_sessions(world):
    api = client()
    login = api.post('/api/auth/login/', {'username': 'customer', 'password': 'SecureTestingPass42!'}).data
    unknown = api.post('/api/auth/password-reset/', {'email': 'unknown@example.com'})
    known = api.post('/api/auth/password-reset/', {'email': world['customer'].email})
    assert unknown.data == known.data
    code = mail_code()
    challenge = EmailChallenge.objects.get(user=world['customer'])
    assert code not in challenge.code_hash and 'code' not in known.data
    payload = {'email': world['customer'].email, 'code': code, 'new_password': 'ChangedSecurePassword93!'}
    assert api.post('/api/auth/password-reset/confirm/', payload).status_code == 200
    assert api.post('/api/auth/password-reset/confirm/', payload).status_code == 400
    assert api.post('/api/auth/refresh/', {'refresh': login['refresh']}).status_code == 401
    api.credentials(HTTP_AUTHORIZATION=f'Bearer {login["access"]}')
    assert api.get('/api/me/').status_code == 401
    assert client().post('/api/auth/login/', {'username': 'customer', 'password': payload['new_password']}).status_code == 200


def test_codes_expire_and_lock_after_five_failed_attempts(world):
    api = client(world['customer'])
    assert api.post('/api/auth/email-verification/').status_code == 200
    code = mail_code()
    bad_code = '00000000' if code != '00000000' else '11111111'
    for _ in range(5):
        assert api.post('/api/auth/email-verification/confirm/', {'code': bad_code}).status_code == 400
    assert api.post('/api/auth/email-verification/confirm/', {'code': code}).status_code == 400
    challenge = EmailChallenge.objects.latest('id')
    assert challenge.attempts == 5 and challenge.used
    api.post('/api/auth/email-verification/')
    new_code = mail_code()
    EmailChallenge.objects.filter(used=False).update(expires_at=timezone.now() - timedelta(seconds=1))
    assert api.post('/api/auth/email-verification/confirm/', {'code': new_code}).status_code == 400


def test_email_change_clears_verification_and_old_challenges(world):
    api = client(world['customer'])
    api.post('/api/auth/email-verification/')
    code = mail_code()
    assert api.post('/api/auth/email-verification/confirm/', {'code': code}).status_code == 200
    assert api.get('/api/me/').data['email_verified']
    api.post('/api/auth/password-reset/', {'email': world['customer'].email})
    old_reset = mail_code()
    assert api.patch('/api/me/', {'email': 'changed@example.com', 'email_verified': True}).data['email_verified'] is False
    assert client().post('/api/auth/password-reset/confirm/', {'email': 'changed@example.com',
        'code': old_reset, 'new_password': 'AnotherSecurePassword71!'}).status_code == 400
    assert api.patch('/api/me/', {'email': world['stranger'].email.upper()}).status_code == 400


def test_resend_invalidates_old_code_and_weak_password_keeps_code_usable(world):
    api = client()
    email = world['customer'].email
    api.post('/api/auth/password-reset/', {'email': email})
    first = mail_code()
    api.post('/api/auth/password-reset/', {'email': email})
    second = mail_code()
    assert api.post('/api/auth/password-reset/confirm/', {'email': email, 'code': first,
        'new_password': 'GoodUpdatedPassword83!'}).status_code == 400
    assert api.post('/api/auth/password-reset/confirm/', {'email': email, 'code': second,
        'new_password': '12345678'}).status_code == 400
    assert api.post('/api/auth/password-reset/confirm/', {'email': email, 'code': second,
        'new_password': 'GoodUpdatedPassword83!'}).status_code == 200


def publish_slot(world):
    start = (timezone.now() + timedelta(days=2)).replace(second=0, microsecond=0)
    result = client(world['owner']).post('/api/slots/', {'starts_at': start.isoformat(),
        'ends_at': (start + timedelta(hours=1)).isoformat()})
    assert result.status_code == 201
    return result.data


def test_calendar_enforces_ownership_duration_and_overlap(world):
    slot = publish_slot(world)
    payload = {'starts_at': slot['starts_at'], 'ends_at': slot['ends_at']}
    assert client(world['owner']).post('/api/slots/', payload).status_code == 400
    assert client(world['customer']).post('/api/slots/', payload).status_code == 403
    assert client(world['stranger']).delete(f'/api/slots/{slot["id"]}/').status_code == 403
    assert client(world['owner']).post('/api/slots/', dict(payload, ends_at=slot['starts_at'])).status_code == 400
    assert client(world['owner']).delete(f'/api/slots/{slot["id"]}/').status_code == 204


def test_slot_booking_reserves_and_cancellation_releases_time(world):
    slot = publish_slot(world)
    client(world['owner']).patch('/api/profile/', {'schedule_enabled': True})
    customer = client(world['customer'])
    payload = booking_payload(world)
    assert customer.post('/api/bookings/', payload).status_code == 400
    payload.update(slot=slot['id'], scheduled_at=slot['starts_at'], duration_minutes=60)
    response = customer.post('/api/bookings/', payload)
    assert response.status_code == 201
    endpoint = f'/api/professionals/{world["profile"].pk}/availability/'
    assert client().get(endpoint).data['slots'] == []
    assert client(world['stranger']).post('/api/bookings/', payload).status_code == 400
    assert client(world['owner']).delete(f'/api/slots/{slot["id"]}/').status_code == 400
    assert customer.post(f'/api/bookings/{response.data["id"]}/status/', {'status': 'cancelled'}).status_code == 200
    assert len(client().get(endpoint).data['slots']) == 1
    assert customer.post('/api/bookings/', payload).status_code == 201


def test_custom_booking_overlap_and_invalid_slot_are_rejected(world):
    api = client(world['customer'])
    payload = booking_payload(world)
    first = api.post('/api/bookings/', payload)
    assert first.status_code == 201
    start = timezone.datetime.fromisoformat(payload['scheduled_at'])
    assert api.post('/api/bookings/', dict(payload, scheduled_at=(start + timedelta(minutes=30)).isoformat())).status_code == 400
    assert api.post('/api/bookings/', dict(payload, scheduled_at=(start + timedelta(minutes=60)).isoformat())).status_code == 201
    slot = publish_slot(world)
    assert api.post('/api/bookings/', dict(payload, slot=slot['id'])).status_code == 400
    assert api.post('/api/bookings/', dict(payload, duration_minutes=481)).status_code == 400


def test_existing_bookings_can_be_accepted_after_enabling_calendar(world):
    booking = make_booking(world)
    api = client(world['owner'])
    api.patch('/api/profile/', {'schedule_enabled': True})
    assert api.post(f'/api/bookings/{booking.pk}/status/', {'status': 'accepted'}).status_code == 200


def make_quote(world):
    payload = booking_payload(world)
    payload.pop('address')
    payload.pop('scheduled_at')
    created = client(world['customer']).post('/api/quotes/', payload)
    return created.data['id']


def test_quote_acceptance_snapshots_terms_is_idempotent_and_freezes_reply(world):
    pk = make_quote(world)
    reply = {'amount': '750.00', 'response': 'Parts and labor included'}
    pro = client(world['owner'])
    quote = pro.post(f'/api/quotes/{pk}/reply/', reply).data
    payload = dict(booking_payload(world), quote_revision=quote['revision'], agreed_price='1')
    assert pro.post(f'/api/quotes/{pk}/accept/', payload).status_code == 403
    assert client(world['stranger']).post(f'/api/quotes/{pk}/accept/', payload).status_code == 404
    customer = client(world['customer'])
    response = customer.post(f'/api/quotes/{pk}/accept/', payload)
    assert response.status_code == 201
    assert Decimal(response.data['agreed_price']) == 750
    assert response.data['agreed_terms'] == reply['response']
    assert response.data['quote'] == pk
    assert customer.post(f'/api/quotes/{pk}/accept/', payload).data['id'] == response.data['id']
    assert Booking.objects.filter(quote_id=pk).count() == 1
    assert pro.post(f'/api/quotes/{pk}/reply/', dict(reply, amount='999')).status_code == 400
    assert customer.get(f'/api/quotes/{pk}/').data['booking_id'] == response.data['id']


def test_acceptance_rejects_unanswered_or_changed_quote(world):
    pk = make_quote(world)
    api = client(world['customer'])
    payload = dict(booking_payload(world), quote_revision=0)
    assert api.post(f'/api/quotes/{pk}/accept/', payload).status_code == 400
    client(world['owner']).post(f'/api/quotes/{pk}/reply/', {'amount': 300, 'response': 'Labor only'})
    assert api.post(f'/api/quotes/{pk}/accept/', payload).status_code == 400


@pytest.mark.parametrize('kind', ['bookings', 'quotes'])
def test_conversations_are_participant_only_with_bounded_read_receipts(world, kind):
    pk = make_booking(world).pk if kind == 'bookings' else make_quote(world)
    endpoint = f'/api/{kind}/{pk}/messages/'
    customer, pro, stranger = client(world['customer']), client(world['owner']), client(world['stranger'])
    first = customer.post(endpoint, {'body': 'Can you bring the parts?', 'sender': world['stranger'].pk})
    assert first.status_code == 201 and first.data['sender'] == world['customer'].pk
    second = customer.post(endpoint, {'body': 'Please confirm.'})
    assert stranger.get(endpoint).status_code == 404
    assert stranger.post(endpoint, {'body': 'Intrusion'}).status_code == 404
    assert pro.post(endpoint, {'body': ' '}).status_code == 400
    assert pro.get(endpoint).data['count'] == 2
    assert pro.post(endpoint + 'read/', {'through_id': first.data['id']}).status_code == 200
    assert Message.objects.get(pk=first.data['id']).read_at is not None
    assert Message.objects.get(pk=second.data['id']).read_at is None
    assert customer.post(endpoint + 'read/', {'through_id': second.data['id']}).status_code == 200
    assert Message.objects.get(pk=second.data['id']).read_at is None
    assert Notification.objects.filter(user=world['owner'], message__contains='New message').count() == 2


@pytest.fixture
def payment_setup(world, settings):
    settings.SSLCOMMERZ_STORE_ID = 'test-store'
    settings.SSLCOMMERZ_STORE_PASSWORD = 'test-secret'
    settings.SSLCOMMERZ_SANDBOX = True
    settings.PAYMENT_CALLBACK_BASE_URL = 'http://localhost:8000'
    world['owner'].phone = '+8801700000000'
    world['owner'].save()
    promotion = Promotion.objects.create(professional=world['profile'], package=world['package'],
        category=world['category'], area=world['area'], price_paid=300, duration_days=7)
    return promotion


def payment_row(promotion):
    return Payment.objects.create(promotion=promotion, transaction_id='SCtest123', amount=300, status='pending')


def gateway_result(payment, **overrides):
    return dict(status='VALID', tran_id=payment.transaction_id, val_id='validated-123',
        currency='BDT', amount=str(payment.amount), risk_level='0', **overrides)


def test_checkout_uses_server_amount_and_reuses_pending_session(world, payment_setup, monkeypatch):
    request = Mock(return_value={'status': 'SUCCESS', 'sessionkey': 'session123',
        'GatewayPageURL': 'https://sandbox.sslcommerz.com/checkout/test'})
    monkeypatch.setattr('marketplace.payments.gateway_request', request)
    endpoint = f'/api/promotions/{payment_setup.pk}/payment/'
    assert client(world['stranger']).post(endpoint).status_code == 404
    api = client(world['owner'])
    result = api.post(endpoint, {'amount': 1})
    assert result.status_code == 200 and Decimal(result.data['amount']) == 300
    assert request.call_args.args[3]['total_amount'] == '300.00'
    assert api.post(endpoint).data['transaction_id'] == result.data['transaction_id']
    assert request.call_count == 1
    assert 'store_passwd' not in result.data and 'session_key' not in result.data


@pytest.mark.parametrize('field,value', [('amount', '1.00'), ('currency', 'USD'), ('tran_id', 'another'), ('status', 'FAILED'), ('val_id', 'wrong')])
def test_invalid_payment_never_activates(payment_setup, monkeypatch, field, value):
    payment = payment_row(payment_setup)
    result = gateway_result(payment)
    result[field] = value
    monkeypatch.setattr('marketplace.payments.gateway_request', Mock(return_value=result))
    assert client().post('/api/payments/ipn/', {'tran_id': payment.transaction_id, 'val_id': 'validated-123'}).status_code == 400
    payment_setup.refresh_from_db()
    assert payment_setup.status == 'pending'


def test_valid_payment_activates_once_and_browser_return_cannot_activate(payment_setup, monkeypatch):
    payment = payment_row(payment_setup)
    assert client().post('/api/payments/return/', {'status': 'VALID', 'tran_id': payment.transaction_id}).status_code == 200
    payment_setup.refresh_from_db()
    assert payment_setup.status == 'pending'
    monkeypatch.setattr('marketplace.payments.gateway_request', Mock(return_value=gateway_result(payment)))
    payload = {'tran_id': payment.transaction_id, 'val_id': 'validated-123'}
    assert client().post('/api/payments/ipn/', payload).data['status'] == 'paid'
    payment_setup.refresh_from_db()
    expires = payment_setup.expires_at
    assert payment_setup.status == 'paid'
    assert client().post('/api/payments/ipn/', payload).data['status'] == 'paid'
    payment_setup.refresh_from_db()
    assert payment_setup.expires_at == expires


def test_risky_payment_requires_review_and_cancelled_promotions_stay_cancelled(payment_setup, monkeypatch):
    payment = payment_row(payment_setup)
    result = gateway_result(payment)
    result['risk_level'] = '1'
    monkeypatch.setattr('marketplace.payments.gateway_request', Mock(return_value=result))
    assert validate_payment(payment, 'validated-123').status == 'review'
    payment_setup.refresh_from_db()
    assert payment_setup.status == 'pending'
    payment_setup.status = 'cancelled'
    payment_setup.save()
    result['risk_level'] = '0'
    assert validate_payment(payment, 'validated-123').status == 'review'
    payment_setup.refresh_from_db()
    assert payment_setup.status == 'cancelled'


def test_owner_can_reconcile_payment_without_ipn(world, payment_setup, monkeypatch):
    payment = payment_row(payment_setup)
    gateway = Mock(side_effect=[{'element': [gateway_result(payment)]}, gateway_result(payment)])
    monkeypatch.setattr('marketplace.payments.gateway_request', gateway)
    result = client(world['owner']).get(f'/api/promotions/{payment_setup.pk}/payment/')
    assert result.data['status'] == 'paid'
    assert gateway.call_count == 2


def test_push_retries_only_failed_device_and_removes_invalid_tokens(world, monkeypatch):
    from firebase_admin import messaging
    from marketplace.management.commands.deliver_push import Command
    notification = Notification.objects.create(user=world['customer'], message='Booking update')
    one = Device.objects.create(user=world['customer'], token='one')
    two = Device.objects.create(user=world['customer'], token='two')
    send = Mock(side_effect=['delivered', RuntimeError('temporary')])
    monkeypatch.setattr('marketplace.management.commands.deliver_push.messaging.send', send)
    command = Command()
    command.deliver()
    assert PushDelivery.objects.get(device=one).sent_at
    assert not PushDelivery.objects.get(device=two).sent_at
    notification.refresh_from_db()
    assert not notification.push_sent
    PushDelivery.objects.filter(device=two).update(retry_at=timezone.now() - timedelta(seconds=1))
    send.side_effect = None
    send.return_value = 'delivered'
    command.deliver()
    assert send.call_count == 3
    notification.refresh_from_db()
    assert notification.push_sent
    next_notification = Notification.objects.create(user=world['customer'], message='Next update')
    send.side_effect = ['delivered', messaging.UnregisteredError('invalid token')]
    command.deliver()
    assert not Device.objects.filter(pk=two.pk).exists()
    next_notification.refresh_from_db()
    assert next_notification.push_sent
