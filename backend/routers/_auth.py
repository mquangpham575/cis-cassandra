"""
Authentication middleware đơn giản bằng Bearer token.
Dùng cho các POST endpoints (audit, remediate, verify).
"""
from fastapi import HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings

security = HTTPBearer()


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> str:
    """
    Kiểm tra Bearer token.
    Token phải trùng với API_SECRET_KEY trong config.
    """
    if credentials.credentials != settings.api_secret_key:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
        )
    return credentials.credentials
