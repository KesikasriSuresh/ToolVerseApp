from typing import Any, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from backend.app.core.security import decode_access_token
from backend.app.db.mongodb import get_collection, serialize_doc

security = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> dict[str, Any]:
    """Resolve the caller from a bearer token. Never creates accounts."""
    if not credentials:
        raise _unauthorized("Missing authentication credentials.")

    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise _unauthorized("Invalid or expired authentication token.")

    user = await get_collection("users").find_one({"uid": payload["sub"]})
    if not user:
        raise _unauthorized("Account no longer exists.")
    # Logout bumps tokenVersion, which revokes every previously issued token.
    if int(payload.get("tv", 0)) != int(user.get("tokenVersion", 0)):
        raise _unauthorized("Session has been signed out. Please log in again.")

    return serialize_doc(user)
