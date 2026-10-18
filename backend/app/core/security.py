from datetime import datetime, timedelta, timezone
from typing import Any, Optional, Union

import bcrypt
import jwt

from backend.app.core.config import settings


def hash_secret(secret: str) -> str:
    return bcrypt.hashpw(secret.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_secret(plain_secret: str, hashed_secret: str) -> bool:
    try:
        return bcrypt.checkpw(plain_secret.encode("utf-8"), hashed_secret.encode("utf-8"))
    except Exception:
        return False


def create_access_token(
    subject: Union[str, Any],
    token_version: int = 0,
    expires_delta: Optional[timedelta] = None,
) -> str:
    now = datetime.now(timezone.utc)
    expire = now + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    claims = {"sub": str(subject), "iat": now, "exp": expire, "tv": int(token_version)}
    return jwt.encode(claims, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[dict[str, Any]]:
    try:
        return jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require": ["exp", "sub"]},
        )
    except jwt.PyJWTError:
        return None
