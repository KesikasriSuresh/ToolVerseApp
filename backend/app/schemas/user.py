import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

E164 = re.compile(r"^\+[1-9]\d{7,14}$")
_EMAIL = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,255}\.[^@\s]{2,}$")


class SendOtpRequest(BaseModel):
    phone: Optional[str] = Field(None, max_length=32)
    email: Optional[str] = Field(None, max_length=320)

    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            v = v.strip().lower()
            if not _EMAIL.match(v):
                raise ValueError("Enter a valid email address.")
            return v
        return None


class SendOtpResponse(BaseModel):
    success: bool
    message: str
    phone: Optional[str] = None
    email: Optional[str] = None
    # Only populated by the development provider; always None in production.
    dev_code: Optional[str] = None


class VerifyOtpRequest(BaseModel):
    phone: Optional[str] = Field(None, max_length=32)
    email: Optional[str] = Field(None, max_length=320)
    otp: str = Field(..., min_length=4, max_length=10, pattern=r"^\d+$")

    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            v = v.strip().lower()
            if not _EMAIL.match(v):
                raise ValueError("Enter a valid email address.")
            return v
        return None


class UserOut(BaseModel):
    """The caller's own profile."""

    id: str
    uid: str
    name: str = ""
    society: str = ""
    phone: str = ""
    email: str = ""
    profilePic: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    formattedAddress: str = ""
    createdAt: Optional[datetime] = None
    updatedAt: Optional[datetime] = None


class PublicUserOut(BaseModel):
    """What other signed-in users may see. No phone, email, coordinates or tokens."""

    uid: str
    name: str = ""
    society: str = ""
    profilePic: str = ""


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    uid: str
    is_new_user: bool
    is_profile_complete: bool = False
    user: Optional[UserOut] = None


VerifyOtpResponse = AuthResponse
AnonymousAuthResponse = AuthResponse


class GoogleAuthRequest(BaseModel):
    email: str = Field(..., max_length=320)
    name: Optional[str] = Field(None, max_length=120)
    profilePic: Optional[str] = Field(None, max_length=1000)
    googleId: Optional[str] = Field(None, max_length=128)
    idToken: Optional[str] = None


class UserProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: Optional[str] = Field(None, max_length=80)
    society: Optional[str] = Field(None, max_length=120)
    email: Optional[str] = Field(None, max_length=320)
    phone: Optional[str] = Field(None, max_length=32)
    profilePic: Optional[str] = Field(None, max_length=1000)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    formattedAddress: Optional[str] = Field(None, max_length=300)

    @field_validator("email")
    @classmethod
    def _check_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return v
        v = v.strip()
        if not _EMAIL.match(v):
            raise ValueError("Enter a valid email address.")
        return v

    @field_validator("name", "society", "formattedAddress")
    @classmethod
    def _strip(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if isinstance(v, str) else v


class RegisterFcmTokenRequest(BaseModel):
    fcmToken: str = Field(..., min_length=1, max_length=4096)
