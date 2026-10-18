from typing import Literal

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.db.mongodb import get_collection
from backend.app.schemas.upload import UploadResponse
from backend.app.services.cloudinary_service import delete_asset, upload_image_file

router = APIRouter(prefix="/api/uploads", tags=["Uploads"])


@router.post("/image", response_model=UploadResponse)
async def upload_image(
    file: UploadFile = File(...),
    category: Literal["item_photo", "profile_picture"] = Query("item_photo"),
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    await hit(f"upload:{uid}", 40, 3600, "Upload limit reached. Try again later.")
    folder = "items" if category == "item_photo" else "profiles"
    return UploadResponse(**await upload_image_file(file=file, folder=folder, user_id=uid))


@router.delete("/image")
async def delete_image(
    public_id: str = Query(..., min_length=3, max_length=300),
    current_user: dict = Depends(get_current_user),
):
    """Delete an image you uploaded, unless an item or profile still uses it."""
    uid = current_user["uid"]
    rec = await get_collection("uploads").find_one({"publicId": public_id, "ownerId": uid})
    if not rec:  # same answer for "not yours" and "not found": no enumeration
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Image not found.")
    in_use = await get_collection("items").find_one({"cloudinaryPublicId": public_id}) or \
        await get_collection("users").find_one({"profilePic": rec["url"]})
    if in_use:
        raise HTTPException(status.HTTP_409_CONFLICT, "This image is still in use.")
    if not await delete_asset(public_id):
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Could not delete the image right now.")
    return {"success": True}
