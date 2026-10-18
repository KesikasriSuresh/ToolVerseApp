from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class ChatMessageCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    text: str = Field(..., min_length=1, max_length=1000)
    type: Literal["text", "location"] = "text"
    # The demo client sends "system" for its canned replies; any other value is ignored
    # and the real sender is always the authenticated caller.
    senderId: Optional[str] = Field(None, max_length=64)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    locationAddress: Optional[str] = Field(None, max_length=300)


class ChatMessageOut(BaseModel):
    id: str
    bookingId: str
    text: str
    senderId: str
    fromMe: bool = False
    type: str = "text"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    locationAddress: Optional[str] = None
    timestamp: datetime
