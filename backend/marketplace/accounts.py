"""Email ownership and one-use recovery codes; no codes are returned by the API."""
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import password_validation
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.utils import timezone
from rest_framework import permissions, serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.response import Response
from rest_framework.throttling import SimpleRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer, TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from .models import EmailChallenge, User


class SessionTokenSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['session_version'] = user.session_version
        return token


class SessionRefreshSerializer(TokenRefreshSerializer):
    def validate(self, attrs):
        token = RefreshToken(attrs['refresh'])
        user = User.objects.filter(pk=token.get('user_id'), is_active=True).first()
        if not user or token.get('session_version', 0) != user.session_version:
            raise AuthenticationFailed('Please sign in again.')
        return super().validate(attrs)


class RecoveryThrottle(SimpleRateThrottle):
    scope = 'recovery'

    def get_cache_key(self, request, view):
        return self.cache_format % {'scope': self.scope, 'ident': self.get_ident(request)}


class EmailInput(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class CodeInput(EmailInput):
    code = serializers.RegexField(r'^\d{8}$', max_length=8)
    new_password = serializers.CharField(min_length=8, max_length=128, required=False, write_only=True)


@transaction.atomic
def issue_code(user, purpose):
    user = User.objects.select_for_update().get(pk=user.pk)
    EmailChallenge.objects.filter(user=user, purpose=purpose, used=False).update(used=True)
    code = f'{secrets.randbelow(100_000_000):08d}'
    EmailChallenge.objects.create(user=user, purpose=purpose, email=user.email,
        code_hash=make_password(code), expires_at=timezone.now() + timedelta(minutes=15))
    label = 'reset your password' if purpose == 'reset' else 'verify your email'
    send_mail('SkillConnect email code',
        f'Your code to {label} is {code}. It expires in 15 minutes. '
        'Enter it in SkillConnect. If you did not request this, ignore this email.',
        settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)


def consume_code(user, purpose, code, password=None):
    # Return failed checks instead of raising within atomic: attempts must persist.
    with transaction.atomic():
        user = User.objects.select_for_update().get(pk=user.pk)
        challenge = EmailChallenge.objects.select_for_update().filter(
            user=user, purpose=purpose, email=user.email, used=False).order_by('-id').first()
        if not challenge or challenge.expires_at <= timezone.now() or challenge.attempts >= 5:
            return False
        challenge.attempts += 1
        valid = check_password(code, challenge.code_hash)
        challenge.used = valid or challenge.attempts >= 5
        challenge.save(update_fields=['attempts', 'used'])
        if not valid:
            return False
        if purpose == 'reset':
            user.set_password(password)
            user.session_version += 1
            user.save(update_fields=['password', 'session_version'])
            EmailChallenge.objects.filter(user=user, purpose='reset', used=False).update(used=True)
        else:
            user.email_verified = True
            user.save(update_fields=['email_verified'])
        return True


class PasswordResetRequest(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [RecoveryThrottle]

    def post(self, request):
        data = EmailInput(data=request.data)
        data.is_valid(raise_exception=True)
        user = User.objects.filter(email__iexact=data.validated_data['email'], is_active=True).first()
        if user:
            try:
                issue_code(user, 'reset')
            except Exception:
                # Avoid disclosing account existence even on mail delivery failure.
                import logging
                logging.getLogger(__name__).error('Recovery email delivery failed.')
        return Response({'detail': 'If an active account matches, a code has been sent. Check your email.'})


class PasswordResetConfirm(PasswordResetRequest):
    def post(self, request):
        data = CodeInput(data=request.data)
        data.is_valid(raise_exception=True)
        password = data.validated_data.get('new_password')
        if not password:
            raise serializers.ValidationError({'new_password': 'Enter a new password.'})
        user = User.objects.filter(email__iexact=data.validated_data['email'], is_active=True).first()
        try:
            password_validation.validate_password(password, user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'new_password': exc.messages})
        if not user or not consume_code(user, 'reset', data.validated_data['code'], password):
            raise serializers.ValidationError('Invalid or expired code. Request a new code.')
        return Response({'detail': 'Password updated. Sign in with your new password.'})


class EmailVerificationRequest(APIView):
    throttle_classes = [RecoveryThrottle]

    def post(self, request):
        if request.user.email_verified:
            return Response({'detail': 'Your email is already verified.'})
        try:
            issue_code(request.user, 'verify')
        except Exception:
            return Response({'detail': 'Email delivery is unavailable. Try again later.'}, status=503)
        return Response({'detail': 'Verification code sent. Check your email.'})


class EmailVerificationConfirm(APIView):
    throttle_classes = [RecoveryThrottle]

    def post(self, request):
        data = CodeInput(data={'email': request.user.email, 'code': request.data.get('code')})
        data.is_valid(raise_exception=True)
        if not consume_code(request.user, 'verify', data.validated_data['code']):
            raise serializers.ValidationError('Invalid or expired code. Request a new code.')
        return Response({'detail': 'Email verified.'})
