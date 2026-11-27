"""Doctor endpoints about patients (read only).

Everything here needs a doctor's token. Per-patient routes also need the
patient to be linked to that doctor, otherwise the answer is 404.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.access.doctor_access import get_repository, linked_patient_uid
from app.auth.deps import require_doctor
from app.auth.models import CurrentUser
from app.repositories.doctor_repository import DoctorRepository
from app.schemas.doctor import PatientOut, ReadingOut
from app.services import doctor_service

router = APIRouter(tags=["doctor"])


@router.get("/patients", response_model=dict[str, PatientOut])
def list_patients(
    doctor: CurrentUser = Depends(require_doctor),
    repo: DoctorRepository = Depends(get_repository),
):
    """The patients linked to this doctor, keyed by the patient's number
    (1, 2, 3... for this doctor; the other routes take the same number)."""
    result: dict[str, PatientOut] = {}
    for link in sorted(repo.linked_patients(doctor.uid), key=lambda link: link["seq"]):
        result[str(link["seq"])] = doctor_service.patient_out(repo.user_profile(link["id"]), link)
    return result


@router.get("/patients/{patient_id}/readings", response_model=list[ReadingOut])
def patient_readings(
    patient_uid: str = Depends(linked_patient_uid),  # the number in the URL, as a uid
    repo: DoctorRepository = Depends(get_repository),
    limit: int = Query(500, ge=1, le=2000, description="Newest readings to return"),
    since: int | None = Query(None, ge=0, description="Only readings at or after this Unix time (seconds)"),
):
    """Glucose readings, newest first."""
    since_time = datetime.fromtimestamp(since, tz=timezone.utc) if since is not None else None
    docs = repo.readings(patient_uid, limit=limit, since=since_time)
    readings = (doctor_service.reading_out(d) for d in docs)
    return [r for r in readings if r is not None]


# ---------------------------------------------------------------------------
# Not stored anywhere yet.
#
# The dashboard asks for all of these for every patient when it loads
# (doctor_dashboard/js/data/http.js, loadFromApi), and one failing request
# stops the whole page. They answer with an empty list until the data exists.
# ---------------------------------------------------------------------------

_NOT_STORED_YET = ("meals", "consultations", "doses", "requests", "instructions", "chat")


def _empty_list_route(name: str) -> None:
    @router.get(f"/patients/{{patient_id}}/{name}", response_model=list, name=f"patient_{name}")
    def empty(_: str = Depends(linked_patient_uid)):
        return []


for _name in _NOT_STORED_YET:
    _empty_list_route(_name)


@router.get("/reminders", response_model=list)
def reminders(_: CurrentUser = Depends(require_doctor)):
    return []
