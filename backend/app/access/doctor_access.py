"""Which patients a doctor may open (the doctor's own numbers only)."""

from fastapi import Depends, HTTPException, Path, status

from app.auth.deps import require_doctor
from app.auth.models import CurrentUser
from app.core.firebase import get_db
from app.repositories.doctor_repository import DoctorRepository


def get_repository(db=Depends(get_db)) -> DoctorRepository:
    return DoctorRepository(db)


def linked_patient_uid(
    patient_id: int = Path(ge=1, le=2**31 - 1, description="The patient's number for this doctor"),
    doctor: CurrentUser = Depends(require_doctor),
    repo: DoctorRepository = Depends(get_repository),
) -> str:
    """The Firebase uid of this doctor's patient number ``patient_id``.

    The number belongs to the calling doctor, so a number that is not theirs
    answers 404 exactly like a patient that does not exist.
    """
    uid = repo.patient_uid_for(doctor.uid, patient_id)
    if uid is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")
    return uid
