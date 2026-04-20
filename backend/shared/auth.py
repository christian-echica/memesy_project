import os
from functools import wraps

import jwt
from flask import g, jsonify, request

from shared.cache import redis_client

_SECRET = os.environ.get("JWT_SECRET_KEY", "")


def require_auth(f):
    """Decorator that validates JWT and confirms the session is alive in Redis."""

    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"error": "Missing token"}), 401

        token = header.split(" ", 1)[1]
        try:
            payload = jwt.decode(token, _SECRET, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expired"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401

        # Redis check: token can be revoked instantly on logout/password change
        if not redis_client.exists(f"session:{payload['user_id']}"):
            return jsonify({"error": "Session expired"}), 401

        g.user_id = payload["user_id"]
        return f(*args, **kwargs)

    return wrapper


def issue_token(user_id: int) -> str:
    import datetime

    payload = {
        "user_id": user_id,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=24),
        "iat": datetime.datetime.utcnow(),
    }
    token = jwt.encode(payload, _SECRET, algorithm="HS256")
    redis_client.set(f"session:{user_id}", token, ex=86400)
    return token


def revoke_token(user_id: int) -> None:
    redis_client.delete(f"session:{user_id}")
