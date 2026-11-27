from fastapi import APIRouter, Depends

from app.auth.deps import get_current_user, require_doctor
from app.auth.models import CurrentUser
from app.schemas.doctor import DoctorOut, MeOut

router = APIRouter(tags=["account"])


@router.get("/me", response_model=MeOut)
def me(user: CurrentUser = Depends(get_current_user)):
    """Who the token belongs to. Works for any role; handy to test a token."""
    return MeOut(uid=user.uid, email=user.email, role=user.role, name=user.name)


@router.get("/doctor", response_model=DoctorOut)
def doctor_profile(doctor: CurrentUser = Depends(require_doctor)):
    return DoctorOut(id=doctor.uid, name=doctor.name or doctor.email, email=doctor.email)
