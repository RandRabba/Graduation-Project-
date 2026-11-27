from dataclasses import dataclass

ROLE_DOCTOR = "doctor"
ROLE_PATIENT = "patient"
ROLE_CAREGIVER = "caregiver"


@dataclass(frozen=True)
class CurrentUser:
    """The signed-in account that made the request."""

    uid: str
    email: str
    role: str
    name: str = ""
