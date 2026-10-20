import base64
import json
import logging
from typing import Any, Dict, Optional
import httpx

from backend.app.core.config import settings

logger = logging.getLogger("toolverse.gemini")

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent"


async def analyze_tool_condition_with_gemini(
    listing_image_bytes: bytes,
    return_image_bytes: bytes,
    tool_name: str = "Tool",
    deposit_amount: int = 0,
    api_key: str | None = None,
) -> dict:
    """Sends both the original listing photo and returned tool photo to Gemini 1.5 Flash Vision.

    Performs multimodal visual reasoning:
    1. Validates whether both photos represent the same tool.
    2. Inspects surfaces, edges, casing, cords, and attachments for damage or wear.
    3. Calculates an accurate condition match percentage.
    4. Provides defect count and spoken summary for TTS.
    """
    key = api_key or settings.GEMINI_API_KEY
    if not key:
        return {
            "success": False,
            "error": "GEMINI_API_KEY_MISSING",
            "message": "Gemini API key is not configured. Please add your GEMINI_API_KEY in app settings.",
            "matchPercentage": 0.0,
            "defectsCount": 0,
            "surfaceIntegrity": 0.0,
            "defectsSummary": "AI inspection unavailable - API key missing.",
            "spokenVerdict": "AI inspection could not run because the Gemini API key is not configured.",
            "depositApproved": False,
            "isSameItem": False,
        }

    b64_listing = base64.b64encode(listing_image_bytes).decode("utf-8")
    b64_return = base64.b64encode(return_image_bytes).decode("utf-8")

    prompt = (
        "You are the ToolVerse AI Vision Return Inspector for a tool sharing marketplace.\n\n"
        f"You are given TWO images:\n"
        f"- IMAGE 1: The ORIGINAL baseline photo of '{tool_name}' taken by the owner when listed.\n"
        "- IMAGE 2: The RETURN photo captured by camera at return handoff.\n\n"
        "YOUR TASK: Perform a rigorous, honest, and STRICT visual comparison.\n\n"
        "CRITICAL RULES (YOU MUST FOLLOW THESE):\n"
        "- If IMAGE 2 shows a COMPLETELY DIFFERENT object, scene, person, or unrelated item: "
        "isSameItem MUST be false, matchPercentage MUST be below 15.\n"
        "- If the images are same category of tool but clearly different units/models: "
        "isSameItem MUST be false, matchPercentage should be 20 to 35.\n"
        "- Do NOT award high scores by default. Only award 90+ if the tool is genuinely the "
        "SAME PHYSICAL ITEM in near-perfect condition.\n"
        "- Any major discoloration, dents, broken parts, missing accessories, or structural damage "
        "MUST reduce the score significantly.\n"
        "- Be STRICT and HONEST. The purpose is damage detection, not approval by default.\n\n"
        "SCORING GUIDE:\n"
        "- 93 to 100: Identical same item, pristine condition, no visible damage.\n"
        "- 75 to 92: Same item with minor cosmetic dust or light scuffs that clean off.\n"
        "- 40 to 74: Same item with noticeable damage - dents, cracks, heavy scratches, missing parts.\n"
        "- 1 to 39: Severely damaged, wrong unit, or completely different object.\n\n"
        "ANALYSIS STEPS:\n"
        "1. Determine if Image 2 is the SAME PHYSICAL ITEM as Image 1.\n"
        "2. Inspect carefully: surface finish, casing color, shape, logos, cord, battery, blade, guard, size.\n"
        "3. List any new damage visible in Image 2 that was NOT present in Image 1.\n"
        "4. Compute matchPercentage HONESTLY using the scoring guide above.\n"
        "5. Count defects (0 means pristine).\n"
        "6. Write a 1-sentence spoken verdict for text-to-speech.\n\n"
        f"Deposit amount: Rs {deposit_amount}\n"
        "depositApproved must be true ONLY if matchPercentage >= 75 AND isSameItem is true.\n\n"
        "Respond with ONLY valid JSON (no markdown, no code fences):\n"
        "{\n"
        '  "isSameItem": true,\n'
        '  "matchPercentage": 96.8,\n'
        '  "defectsCount": 0,\n'
        '  "surfaceIntegrity": 98.2,\n'
        '  "defectsSummary": "No visible structural damage detected",\n'
        f'  "spokenVerdict": "ToolVerse AI complete. Matched 96.8 percent. Deposit of Rs {deposit_amount} approved.",\n'
        '  "depositApproved": true\n'
        "}"
    )

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": "image/jpeg", "data": b64_listing}},
                    {"inline_data": {"mime_type": "image/jpeg", "data": b64_return}},
                ]
            }
        ],
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.1,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            resp = await client.post(
                f"{GEMINI_API_URL}?key={key}",
                json=payload,
                headers={"Content-Type": "application/json"},
            )

        if resp.status_code != 200:
            logger.error("Gemini API error %s: %s", resp.status_code, resp.text)
            return {
                "success": False,
                "error": f"GEMINI_HTTP_{resp.status_code}",
                "message": f"Gemini API error {resp.status_code}: {resp.text[:200]}",
                "matchPercentage": 0.0,
                "defectsCount": 0,
                "surfaceIntegrity": 0.0,
                "defectsSummary": f"AI inspection failed - API error {resp.status_code}.",
                "spokenVerdict": "AI inspection failed. Please check your API key and try again.",
                "depositApproved": False,
                "isSameItem": False,
            }

        result = resp.json()
        candidates = result.get("candidates", [])
        if not candidates:
            raise ValueError("No response candidate returned by Gemini.")

        raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        parsed = json.loads(raw_text)

        # Enforce depositApproved server-side - never trust the model alone
        match_pct = float(parsed.get("matchPercentage", 0.0))
        is_same = bool(parsed.get("isSameItem", False))
        parsed["depositApproved"] = is_same and match_pct >= 75.0
        parsed["success"] = True
        return parsed

    except Exception as exc:
        logger.exception("Error executing Gemini vision comparison: %s", exc)
        return {
            "success": False,
            "error": str(exc),
            "matchPercentage": 0.0,
            "defectsCount": 0,
            "surfaceIntegrity": 0.0,
            "defectsSummary": "AI inspection could not complete due to a connection error.",
            "spokenVerdict": "ToolVerse AI inspection failed due to a connection error. Please retry.",
            "depositApproved": False,
            "isSameItem": False,
        }
