"""Link-code request and response shapes (names follow doctor_dashboard/js/data/http.js)."""

from typing import Annotated, Literal

from pydantic import BaseModel, Field, StringConstraints

# The doctor's own note about who the code is for. Optional; the dashboard cuts it at 60 characters.
Label = Annotated[str, StringConstraints(strip_whitespace=True, max_length=60)]


class LinkCodeCreate(BaseModel):
    label: Label = ""


class LinkCodeOut(BaseModel):
    id: str  # the code itself
    label: str
    code: str
    at: int  # created, Unix seconds
    st: Literal["pending", "used"]
    usedAt: int | None  # Unix seconds


class RedeemIn(BaseModel):
    # Whatever the patient typed or scanned; normalised by the server.
    code: str = Field(min_length=1, max_length=64)


class RedeemOut(BaseModel):
    alreadyLinked: bool  # the patient was already this doctor's patient
    doctorName: str
