"""Turns stored documents into the shapes the doctor dashboard expects.

Kept free of FastAPI and Firestore so it can be tested on plain dictionaries.
"""

from datetime import date, datetime
from typing import Any

from app.schemas.doctor import PatientOut, ReadingOut


def unix_seconds(value: Any) -> int | None:
    """A Firestore timestamp (a datetime) as Unix seconds; None if it is not one."""
    if isinstance(value, datetime):
        return int(value.timestamp())
    return None


def age_from_birth_date(text: Any, today: date | None = None) -> int | None:
    """Age in years from the patient app's ``YYYY-MM-DD`` text; None if unknown."""
    if not isinstance(text, str) or not text:
        return None
    try:
        born = date.fromisoformat(text)
    except ValueError:
        return None
    today = today or date.today()
    years = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
    return years if 0 <= years < 130 else None


# The patient app stores these codes (patient_interface/lib/auth_screen.dart);
# the dashboard knows "Type 1" and "Type 2" (its ``ptype.*`` texts).
_REPORTED_TYPES = {
    "type1": "Type 1",
    "type2": "Type 2",
    "gestational": "Gestational",
    "prediabetes": "Prediabetes",
    "other": "Other",
}


def reported_type(value: Any) -> str | None:
    """The diabetes type the patient chose at sign-up, as the dashboard names it."""
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    return _REPORTED_TYPES.get(text.lower(), text)


def patient_out(profile: dict[str, Any] | None, link: dict[str, Any]) -> PatientOut:
    profile = profile or {}
    return PatientOut(
        name=str(profile.get("fullName") or profile.get("email") or "Patient"),
        age=age_from_birth_date(profile.get("dateOfBirth")),
        sex=None,  # the patient app does not collect it yet
        reportedType=reported_type(profile.get("diabetesType")),
        linkedAt=unix_seconds(link.get("linkedAt")),
    )


def reading_type(timing: Any) -> str:
    """The patient app's ``timing`` -> the dashboard's reading type.

    Same rule as the caregiver app: without a timing it is a random reading.
    """
    if timing == "fasting":
        return "FBS"
    if timing == "after_meal":
        return "PPBS"
    return "RBS"


def reading_source(source: Any) -> str:
    """Manual entries stay manual; every sensor source counts as CGM."""
    return "manual" if source in (None, "", "manual") else "cgm"


def reading_out(doc: dict[str, Any]) -> ReadingOut | None:
    """One stored reading, or None when it is missing its value or time."""
    value = doc.get("value")
    at = unix_seconds(doc.get("at"))
    if isinstance(value, bool) or not isinstance(value, (int, float)) or at is None:
        return None
    return ReadingOut(
        id=str(doc["id"]),
        v=float(value),
        at=at,
        src=reading_source(doc.get("source")),
        type=reading_type(doc.get("timing")),
    )
