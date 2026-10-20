from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class BookingCreate(BaseModel):
    """Only the item, dates and a note come from the client. Names, deposit, owner and
    lender are always read from the item record on the server."""

    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    itemId: str = Field(..., max_length=64)
    from_date: Optional[datetime] = Field(None, alias="from")
    to_date: Optional[datetime] = Field(None, alias="to")
    note: str = Field("", max_length=500)


class BookingStatusUpdate(BaseModel):
    status: Literal["active", "done", "cancelled"]


class BookingPhotosUpdate(BaseModel):
    before: Optional[bool] = None
    after: Optional[bool] = None


class BookingOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    itemId: str
    itemName: str
    itemCategory: str
    itemOwner: str
    itemDeposit: int
    itemImageUrl: Optional[str] = ""
    lenderId: str
    borrowerId: str
    borrowerName: Optional[str] = ""
    borrowerEmail: Optional[str] = ""
    lenderEmail: Optional[str] = ""
    from_date: Optional[datetime] = Field(None, alias="from")
    to_date: Optional[datetime] = Field(None, alias="to")
    note: str = ""
    status: str = "pending"
    beforePhoto: bool = False
    afterPhoto: bool = False
    createdAt: datetime
    updatedAt: Optional[datetime] = None
