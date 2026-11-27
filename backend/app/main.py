from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException

from app.core.config import settings
from app.core.firebase import (
    initialize_firebase,
    get_firestore_client,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_firebase()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    lifespan=lifespan,
)


@app.get("/")
def root():
    return {
        "message": "Diabetes Management System API is running"
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy"
    }


@app.get("/health/firebase")
def firebase_health_check():
    try:
        db = get_firestore_client()

        # Attempt to access Firestore
        list(db.collections())

        return {
            "status": "connected",
            "service": "Firestore"
        }

    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Firestore connection failed"
        )