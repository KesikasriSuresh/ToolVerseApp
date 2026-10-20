from pathlib import Path
from typing import List, Optional, Union

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    PROJECT_NAME: str = "ToolVerse API"
    VERSION: str = "1.1.0"

    # "development" allows the dev OTP provider and permissive CORS.
    # Anything else is treated as production-like and is validated strictly.
    ENVIRONMENT: str = "development"

    # MongoDB Atlas
    MONGODB_URI: str = ""
    MONGODB_DATABASE: str = "toolverse"

    # JWT -- no default on purpose: the app refuses to start without a real secret.
    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""
    MAX_UPLOAD_BYTES: int = 10 * 1024 * 1024

    # Phone OTP: "twilio_verify" (real SMS) or "dev" (static code, development only)
    SMS_PROVIDER: str = "dev"
    SMS_DEV_CODE: str = "123456"
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_VERIFY_SERVICE_SID: str = ""
    # Used by the dev provider and by our own throttling
    OTP_MAX_SENDS_PER_HOUR: int = 5
    OTP_MAX_FAILED_CHECKS: int = 5

    # Email OTP configuration (Gmail SMTP or Resend)
    EMAIL_PROVIDER: str = "smtp"  # "smtp", "resend", or "dev"
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    EMAIL_FROM: str = "ToolVerse <noreply@toolverse.app>"
    RESEND_API_KEY: str = ""

    # Guest login (the app has a "continue as guest" path). Rate limited per IP.
    ALLOW_ANONYMOUS_AUTH: bool = True
    ANON_MAX_PER_HOUR_PER_IP: int = 10

    # The original demo app writes canned "system" chat messages from the client.
    # Keep True to preserve that behaviour; set False in a real deployment.
    ALLOW_CLIENT_SYSTEM_MESSAGES: bool = True

    # Google Gemini Vision API Key
    GEMINI_API_KEY: str = ""

    # Push notifications via Firebase Cloud Messaging (HTTP v1, service account).
    # Path to a service-account JSON file kept OUTSIDE git. Empty = push disabled.
    FIREBASE_CREDENTIALS_FILE: str = ""

    # CORS
    CORS_ORIGINS: Union[List[str], str] = ["*"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str):
            v = v.strip()
            if v.startswith("["):
                import json

                return json.loads(v)
            return [i.strip() for i in v.split(",") if i.strip()]
        return v

    model_config = SettingsConfigDict(
        env_file=(str(BACKEND_DIR / ".env"), ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def is_production_like(self) -> bool:
        return self.ENVIRONMENT.lower() not in ("development", "dev", "test")

    @property
    def cloudinary_configured(self) -> bool:
        return bool(
            self.CLOUDINARY_CLOUD_NAME
            and self.CLOUDINARY_API_KEY
            and self.CLOUDINARY_API_SECRET
        )

    @property
    def twilio_configured(self) -> bool:
        return bool(
            self.TWILIO_ACCOUNT_SID
            and self.TWILIO_AUTH_TOKEN
            and self.TWILIO_VERIFY_SERVICE_SID
        )

    @property
    def smtp_configured(self) -> bool:
        return bool(self.SMTP_USERNAME and self.SMTP_PASSWORD)

    @property
    def resend_configured(self) -> bool:
        return bool(self.RESEND_API_KEY)

    def validate_for_startup(self) -> None:
        """Fail fast on unsafe or incomplete configuration. Never echoes secret values."""
        problems: List[str] = []
        if len(self.JWT_SECRET_KEY) < 32:
            problems.append(
                "JWT_SECRET_KEY is missing or shorter than 32 characters "
                "(generate one with: python3 -c \"import secrets; print(secrets.token_urlsafe(64))\")"
            )
        if not self.MONGODB_URI or "<" in self.MONGODB_URI:
            problems.append("MONGODB_URI is not set (or still contains a placeholder).")
        provider = self.SMS_PROVIDER.lower()
        if provider not in ("dev", "twilio_verify"):
            problems.append("SMS_PROVIDER must be 'dev' or 'twilio_verify'.")
        if provider == "twilio_verify" and not self.twilio_configured:
            problems.append(
                "SMS_PROVIDER=twilio_verify needs TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_VERIFY_SERVICE_SID."
            )
        if self.is_production_like:
            if provider == "dev":
                problems.append("SMS_PROVIDER=dev is not allowed when ENVIRONMENT is not 'development'.")
            if "*" in self.CORS_ORIGINS:
                problems.append("CORS_ORIGINS must list explicit origins when ENVIRONMENT is not 'development'.")
        if problems:
            raise RuntimeError("Invalid configuration:\n - " + "\n - ".join(problems))


settings = Settings()
