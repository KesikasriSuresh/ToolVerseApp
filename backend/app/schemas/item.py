from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

Category = Literal["tools", "electronics", "sports", "camping", "games"]


class ItemCreate(BaseModel):
    """Client may NOT choose owner/ownerId/publicId: the server derives them."""

    model_config = ConfigDict(extra="ignore")

    name: str = Field(..., min_length=2, max_length=100)
    category: Category
    desc: str = Field("", max_length=1000)
    deposit: int = Field(0, ge=0, le=1_000_000)
    imageUrl: str = Field("", max_length=1000)
    isAvailable: bool = True

    @field_validator("name", "desc")
    @classmethod
    def _strip(cls, v: str) -> str:
        return v.strip()


class ItemUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: Optional[str] = Field(None, min_length=2, max_length=100)
    category: Optional[Category] = None
    desc: Optional[str] = Field(None, max_length=1000)
    deposit: Optional[int] = Field(None, ge=0, le=1_000_000)
    imageUrl: Optional[str] = Field(None, max_length=1000)
    isAvailable: Optional[bool] = None


class ItemOut(BaseModel):
    id: str
    name: str
    category: str
    desc: str = ""
    deposit: int = 0
    imageUrl: str = ""
    cloudinaryPublicId: Optional[str] = None
    isAvailable: bool = True
    owner: str
    ownerId: str
    createdAt: datetime
    updatedAt: Optional[datetime] = None
