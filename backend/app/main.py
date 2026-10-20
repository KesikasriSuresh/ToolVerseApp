import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware

from backend.app.core.config import settings
from backend.app.db.mongodb import close_mongo_connection, connect_to_mongo, db_instance
from backend.app.routers import auth, bookings, chats, items, notifications, uploads, users
from backend.app.services.cloudinary_service import configure_cloudinary

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logging.getLogger("httpx").setLevel(logging.WARNING)  # httpx logs full request URLs; keep them out of logs
logger = logging.getLogger("toolverse.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate_for_startup()  # raises with a clear, secret-free message
    configure_cloudinary()
    try:
        await connect_to_mongo()
        logger.info("ToolVerse API ready (env=%s, otp=%s).", settings.ENVIRONMENT, settings.SMS_PROVIDER)
    except Exception as e:
        logger.warning("MongoDB Atlas connection pending/retry: %s", e)
    yield
    await close_mongo_connection()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="ToolVerse REST API: FastAPI + MongoDB Atlas + Cloudinary.",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production_like else None,
    redoc_url=None,
    openapi_url="/openapi.json" if not settings.is_production_like else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (auth, users, items, bookings, chats, notifications, uploads):
    app.include_router(r.router)


@app.get("/", tags=["Health"])
async def root():
    return {"app": settings.PROJECT_NAME, "status": "online"}


@app.get("/api/health", tags=["Health"])
async def health_check(response: Response):
    mongo_ok = False
    if db_instance.client is not None:
        try:
            await db_instance.client.admin.command("ping")
            mongo_ok = True
        except Exception:
            mongo_ok = False
    if not mongo_ok:
        response.status_code = 503
    return {
        "status": "healthy" if mongo_ok else "degraded",
        "mongodb": "healthy" if mongo_ok else "unreachable",
        "cloudinary": "configured" if settings.cloudinary_configured else "not_configured",
        "otp_provider": settings.SMS_PROVIDER,
        "push": "configured" if settings.FIREBASE_CREDENTIALS_FILE else "not_configured",
    }
