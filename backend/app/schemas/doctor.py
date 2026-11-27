"""Response shapes. Field names follow doctor_dashboard/js/data/http.js, so the
dashboard can use the answers without changes (camelCase where it uses it)."""

from typing import Literal

from pydantic import BaseModel


class MeOut(BaseModel):
    uid: str
    email: str
    role: str
    name: str


class DoctorOut(BaseModel):
    id: str
    name: str
    email: str


class PatientOut(BaseModel):
    name: str
    age: int | None
    sex: str | None
    reportedType: str | None
    linkedAt: int | None  # Unix seconds


class ReadingOut(BaseModel):
    id: str
    v: float  # mg/dL
    at: int  # Unix seconds
    src: Literal["cgm", "manual"]
    type: Literal["FBS", "RBS", "PPBS"]
