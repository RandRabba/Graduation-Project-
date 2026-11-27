from fastapi import APIRouter

from app.api.v1 import me, patients

api_router = APIRouter()
api_router.include_router(me.router)
api_router.include_router(patients.router)
