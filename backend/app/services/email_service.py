"""Email delivery service supporting Gmail SMTP and Resend API for real-time OTPs."""
import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

import httpx

from backend.app.core.config import settings

logger = logging.getLogger("toolverse.email")


def _build_html_email(code: str, to_email: str) -> str:
    """Modern dark-neon HTML email template tailored for ToolVerse."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your ToolVerse Verification Code</title>
  <style>
    body {{
      margin: 0;
      padding: 0;
      background-color: #0B0E14;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #E6EDF3;
    }}
    .container {{
      max-width: 520px;
      margin: 40px auto;
      background: linear-gradient(135deg, #161B22 0%, #0D1117 100%);
      border-radius: 20px;
      border: 1px solid rgba(139, 92, 246, 0.3);
      padding: 36px 32px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.6);
    }}
    .brand {{
      display: flex;
      align-items: center;
      margin-bottom: 24px;
    }}
    .brand-icon {{
      background: linear-gradient(135deg, #00F5FF, #8B5CF6);
      width: 38px;
      height: 38px;
      border-radius: 10px;
      display: inline-block;
      text-align: center;
      line-height: 38px;
      font-size: 20px;
      margin-right: 12px;
    }}
    .brand-title {{
      font-size: 22px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.5px;
    }}
    h1 {{
      font-size: 20px;
      font-weight: 700;
      color: #F0F6FC;
      margin-top: 0;
      margin-bottom: 12px;
    }}
    p {{
      font-size: 14px;
      line-height: 1.6;
      color: #8B949E;
      margin: 0 0 20px 0;
    }}
    .otp-card {{
      background: rgba(0, 245, 255, 0.05);
      border: 1px solid rgba(0, 245, 255, 0.35);
      border-radius: 14px;
      padding: 24px 16px;
      text-align: center;
      margin: 28px 0;
    }}
    .otp-code {{
      font-family: 'SF Mono', Consolas, Menlo, Monaco, monospace;
      font-size: 38px;
      font-weight: 800;
      letter-spacing: 10px;
      color: #00F5FF;
      text-shadow: 0 0 20px rgba(0, 245, 255, 0.4);
      margin: 0;
    }}
    .otp-caption {{
      font-size: 12px;
      color: #7EE787;
      margin-top: 8px;
      font-weight: 600;
    }}
    .divider {{
      height: 1px;
      background: rgba(255, 255, 255, 0.1);
      margin: 28px 0 20px 0;
    }}
    .footer {{
      font-size: 12px;
      color: #484F58;
      text-align: center;
      line-height: 1.5;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="brand">
      <span class="brand-icon">🛠️</span>
      <span class="brand-title">ToolVerse</span>
    </div>
    <h1>Verify your account</h1>
    <p>Welcome! Enter the following one-time verification code in ToolVerse to sign in or complete your profile:</p>
    
    <div class="otp-card">
      <div class="otp-code">{code}</div>
      <div class="otp-caption">Valid for 10 minutes</div>
    </div>
    
    <p style="font-size: 12.5px; color: #8B949E;">
      Security Notice: Never share this code with anyone. ToolVerse staff will never ask for your verification code.
    </p>
    
    <div class="divider"></div>
    <div class="footer">
      Sent to {to_email} &bull; ToolVerse Neighborhood Tool Sharing<br>
      If you did not request this code, you can safely ignore this email.
    </div>
  </div>
</body>
</html>
"""


def _send_smtp_sync(to_email: str, code: str) -> None:
    """Synchronous SMTP worker run inside an asyncio thread."""
    sender = settings.SMTP_USERNAME or settings.EMAIL_FROM
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"{code} is your ToolVerse verification code"
    msg["From"] = f"ToolVerse <{sender}>"
    msg["To"] = to_email

    text_content = (
        f"Your ToolVerse verification code is: {code}\n\n"
        f"This code will expire in 10 minutes.\n"
        f"If you did not request this, please ignore this email."
    )
    html_content = _build_html_email(code, to_email)

    msg.attach(MIMEText(text_content, "plain", "utf-8"))
    msg.attach(MIMEText(html_content, "html", "utf-8"))

    if settings.SMTP_PORT == 465:
        with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=12.0) as server:
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            server.sendmail(sender, [to_email], msg.as_string())
    else:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=12.0) as server:
            if settings.SMTP_USE_TLS:
                server.starttls()
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            server.sendmail(sender, [to_email], msg.as_string())


async def _send_via_resend(to_email: str, code: str) -> bool:
    """Send via Resend HTTP API if configured."""
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {settings.RESEND_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "from": settings.EMAIL_FROM,
        "to": [to_email],
        "subject": f"{code} is your ToolVerse verification code",
        "html": _build_html_email(code, to_email),
        "text": f"Your ToolVerse verification code is: {code} (expires in 10 minutes).",
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(url, headers=headers, json=payload)
        if resp.status_code in (200, 201):
            logger.info("Resend successfully delivered OTP to %s", to_email)
            return True
        logger.error("Resend API failed: %s - %s", resp.status_code, resp.text)
        return False


async def send_verification_email(to_email: str, code: str) -> bool:
    """Send real-time 6-digit OTP code to the recipient's Gmail address."""
    to_email = to_email.strip().lower()

    # 1. Try Gmail SMTP if credentials configured
    if settings.smtp_configured:
        try:
            logger.info("Sending OTP via Gmail SMTP (%s) to %s...", settings.SMTP_HOST, to_email)
            await asyncio.to_thread(_send_smtp_sync, to_email, code)
            logger.info("Successfully sent OTP email via SMTP to %s", to_email)
            return True
        except Exception as exc:
            logger.error("Failed to send email via SMTP to %s: %s", to_email, exc)

    # 2. Try Resend if configured
    if settings.resend_configured:
        try:
            if await _send_via_resend(to_email, code):
                return True
        except Exception as exc:
            logger.error("Failed to send email via Resend to %s: %s", to_email, exc)

    # 3. Log clearly if neither or failed
    logger.warning(
        "\n===================================================================\n"
        "🔔 [ToolVerse OTP Delivery Notice]\n"
        "Target Gmail: %s\n"
        "Generated OTP Code: %s\n"
        "SMTP Configured: %s | Resend Configured: %s\n"
        "To enable direct delivery to the Gmail inbox, add your Gmail & App Password\n"
        "in backend/.env (SMTP_USERNAME & SMTP_PASSWORD).\n"
        "===================================================================\n",
        to_email,
        code,
        settings.smtp_configured,
        settings.resend_configured,
    )
    return False
