import os
import django

# Setup django for independent script execution if needed (though usually handled by asgi.py)
# os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
# django.setup()

from django.contrib.auth.models import AnonymousUser
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import UntypedToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from jwt import decode as jwt_decode
from django.conf import settings
from django.contrib.auth import get_user_model
from urllib.parse import parse_qs

User = get_user_model()

@database_sync_to_async
def get_user(user_id):
    try:
        return User.objects.get(id=user_id)
    except User.DoesNotExist:
        return AnonymousUser()

class JwtAuthMiddleware:
    """
    Custom middleware that takes a token from the query string and authenticates the user.
    """
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        # Extract the token from query string
        query_string = scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)
        token = query_params.get("token", [None])[0]

        print(f"WS Auth: Attempting connection with token: {(token or '')[:10]}...")

        if token:
            try:
                UntypedToken(token)
                decoded_data = jwt_decode(token, settings.SECRET_KEY, algorithms=["HS256"])
                user_id = decoded_data.get("user_id")
                scope["user"] = await get_user(user_id)
                print(f"WS Auth: Authenticated user {user_id}")
            except Exception as e:
                print(f"WS Auth Error: {str(e)}")
                scope["user"] = AnonymousUser()
        else:
            print("WS Auth: No token provided")
            scope["user"] = AnonymousUser()

        return await self.app(scope, receive, send)

def JwtAuthMiddlewareStack(inner):
    return JwtAuthMiddleware(inner)
