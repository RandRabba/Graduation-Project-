"""Linking a patient to a doctor with a one-time code.

1. The doctor (dashboard) creates a code for one patient: ``POST /doctor/link-codes``.
2. The patient types or scans it in the Patient App, which calls
   ``POST /link-codes/redeem`` with the patient's own token.
3. The server marks the code used and links the patient to that doctor
   (``doctors/{doctorUid}/patients/{patientUid}``, with the patient's number).

A code works once, for one patient account, and has no expiry; the doctor can
cancel it until it is used.
"""

from fastapi import APIRouter, Depends, HTTPException, Path, Response, status

from app.access.doctor_access import get_repository
from app.auth.deps import require_doctor, require_patient
from app.auth.models import CurrentUser
from app.core.firebase import get_db
from app.core.throttle import FailureLimiter, TooManyAttempts, redeem_limiter
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.link_code_repository import LinkCodeRepository
from app.schemas.link_codes import LinkCodeCreate, LinkCodeOut, RedeemIn, RedeemOut
from app.services import link_codes as codes_service

router = APIRouter(tags=["link codes"])

# A doctor cannot pile up unused codes without limit.
MAX_PENDING_CODES = 50
# The same answer for a wrong, a used and a cancelled code: nothing to learn from it.
INVALID_CODE = "This code is not valid or was already used"


def get_link_codes(db=Depends(get_db)) -> LinkCodeRepository:
    return LinkCodeRepository(db)


def get_redeem_limiter() -> FailureLimiter:
    return redeem_limiter


# ---- the doctor's side (dashboard) -------------------------------------


@router.post("/doctor/link-codes", response_model=LinkCodeOut, status_code=status.HTTP_201_CREATED)
def create_link_code(
    body: LinkCodeCreate,
    doctor: CurrentUser = Depends(require_doctor),
    codes: LinkCodeRepository = Depends(get_link_codes),
):
    """A new single-use code for one patient."""
    if codes.count_pending(doctor.uid) >= MAX_PENDING_CODES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Too many unused codes: cancel some first",
        )
    for _ in range(10):  # a clash with an existing code is practically impossible
        stored = codes.create(doctor.uid, body.label, codes_service.generate_code())
        if stored is not None:
            return codes_service.code_out(stored)
    raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Could not make a code")


@router.get("/doctor/link-codes", response_model=list[LinkCodeOut])
def list_link_codes(
    doctor: CurrentUser = Depends(require_doctor),
    codes: LinkCodeRepository = Depends(get_link_codes),
):
    """This doctor's codes, pending and used, newest first."""
    out = (codes_service.code_out(doc) for doc in codes.list_for(doctor.uid))
    return sorted((c for c in out if c is not None), key=lambda c: c.at, reverse=True)


@router.delete("/doctor/link-codes/{code_id}", status_code=status.HTTP_204_NO_CONTENT)
def cancel_link_code(
    code_id: str = Path(pattern=codes_service.CODE_PATH_PATTERN),
    doctor: CurrentUser = Depends(require_doctor),
    codes: LinkCodeRepository = Depends(get_link_codes),
):
    """Cancels a code that has not been used."""
    result = codes.cancel(doctor.uid, code_id)
    if result == "missing":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Code not found")
    if result == "used":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This code was already used")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---- the patient's side (Patient App) ----------------------------------


@router.post("/link-codes/redeem", response_model=RedeemOut)
def redeem_link_code(
    body: RedeemIn,
    patient: CurrentUser = Depends(require_patient),
    codes: LinkCodeRepository = Depends(get_link_codes),
    repo: DoctorRepository = Depends(get_repository),
    limiter: FailureLimiter = Depends(get_redeem_limiter),
):
    """Links the signed-in patient to the doctor who made the code, and uses the code up."""
    try:
        limiter.check(patient.uid)
    except TooManyAttempts as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many wrong codes. Try again later",
            headers={"Retry-After": str(e.retry_after)},
        )

    code = codes_service.normalize_code(body.code)
    claimed = codes.claim(code, patient.uid) if code else None
    if claimed is None:
        limiter.record_failure(patient.uid)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=INVALID_CODE)

    try:
        _, created = repo.link(claimed["doctorUid"], patient.uid, patient.email)
    except Exception:
        codes.release(code)  # the patient can try again
        raise

    limiter.clear(patient.uid)
    doctor = repo.user_profile(claimed["doctorUid"]) or {}
    return RedeemOut(alreadyLinked=not created, doctorName=str(doctor.get("fullName") or ""))
