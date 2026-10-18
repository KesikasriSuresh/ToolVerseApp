from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: str
    userId: str
    title: str
    body: str
    type: str = "booking"
    isRead: bool = False
    data: Optional[dict[str, Any]] = None
    timestamp: datetime
