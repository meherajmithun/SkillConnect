from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication


class SessionAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if validated_token.get('session_version', 0) != user.session_version:
            raise AuthenticationFailed('Your password changed. Please sign in again.')
        return user
