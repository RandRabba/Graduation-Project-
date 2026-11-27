"""Which patients a doctor may open."""

from fastapi import Depends, HTTPException, Path, status

from app.auth.deps import require_doctor
from app.auth.models import CurrentUser
from app.core.firebase import get_db
from app.repositories.doctor_repository import DoctorRepository


def get_repository(db=Depends(get_db)) -> DoctorRepository:
    return DoctorRepository(db)


def linked_patient_uid(
    patient_uid: str = Path(min_length=1, max_length=128),
    doctor: CurrentUser = Depends(require_doctor),
    repo: DoctorRepository = Depends(get_repository),
) -> str:
    """The patient's uid, only if this doctor follows the patient.

    Answers 404 (not 403) for any other patient, so a doctor cannot find out
    which accounts exist.
    """
    if not repo.is_linked(doctor.uid, patient_uid):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")
    return patient_uid
