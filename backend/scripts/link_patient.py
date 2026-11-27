"""Link a patient to a doctor (or remove the link).

Until the link-code flow exists, this is how a doctor gets patients. It writes
doctors/{doctorUid}/patients/{patientUid}, which only the backend can read.

Run from the backend folder, with the virtual environment active:

    python -m scripts.link_patient roa@example.com patient1@example.com
    python -m scripts.link_patient roa@example.com patient1@example.com --remove
"""

import argparse
import sys

from firebase_admin import auth

from app.auth.models import ROLE_DOCTOR, ROLE_PATIENT
from app.core.firebase import get_firestore_client
from app.repositories.doctor_repository import DoctorRepository


def _account(db, email: str, role: str):
    """The uid of the account with this email and role, or None (it explains why)."""
    try:
        user = auth.get_user_by_email(email)
    except auth.UserNotFoundError:
        print(f"No Firebase account for {email}.")
        return None
    snapshot = db.collection("users").document(user.uid).get()
    found = (snapshot.to_dict() or {}).get("role") if snapshot.exists else None
    if found != role:
        print(f"{email} is {'a ' + found if found else 'not set up in the DMS'}, not a {role}.")
        return None
    return user.uid


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("doctor_email")
    parser.add_argument("patient_email")
    parser.add_argument("--remove", action="store_true", help="end the link instead of creating it")
    args = parser.parse_args(argv)

    doctor_email = args.doctor_email.strip().lower()
    patient_email = args.patient_email.strip().lower()
    db = get_firestore_client()

    doctor_uid = _account(db, doctor_email, ROLE_DOCTOR)
    patient_uid = _account(db, patient_email, ROLE_PATIENT)
    if doctor_uid is None or patient_uid is None:
        return 1

    repo = DoctorRepository(db)
    if args.remove:
        repo.unlink(doctor_uid, patient_uid)
        print(f"{patient_email} is no longer linked to {doctor_email}.")
    else:
        repo.link(doctor_uid, patient_uid, patient_email)
        print(f"{patient_email} is now linked to {doctor_email}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
