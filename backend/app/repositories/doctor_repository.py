"""Firestore access for the doctor API (read-mostly).

Collections used (see firebase/README.md):

* ``users/{uid}``                         profile and role of every account
* ``doctors/{doctorUid}/patients/{uid}``   "this doctor follows this patient".
  The Firestore rules never match ``doctors/...``, so apps cannot read or
  write it; only this server (Admin SDK) and the scripts can.
* ``patients/{uid}/readings/{id}``         the patient's glucose readings
"""

from datetime import datetime
from typing import Any

from google.cloud import firestore
from google.cloud.firestore import FieldFilter


def _with_id(snapshot) -> dict[str, Any]:
    return {"id": snapshot.id, **(snapshot.to_dict() or {})}


class DoctorRepository:
    def __init__(self, db) -> None:
        self._db = db

    # ---- accounts -------------------------------------------------------

    def user_profile(self, uid: str) -> dict[str, Any] | None:
        snapshot = self._db.collection("users").document(uid).get()
        return snapshot.to_dict() if snapshot.exists else None

    # ---- doctor <-> patient links --------------------------------------

    def _links(self, doctor_uid: str):
        return self._db.collection("doctors").document(doctor_uid).collection("patients")

    def linked_patients(self, doctor_uid: str) -> list[dict[str, Any]]:
        """Link documents of the doctor; ``id`` is the patient's uid."""
        return [_with_id(s) for s in self._links(doctor_uid).stream()]

    def is_linked(self, doctor_uid: str, patient_uid: str) -> bool:
        return self._links(doctor_uid).document(patient_uid).get().exists

    def link(self, doctor_uid: str, patient_uid: str, patient_email: str) -> None:
        self._links(doctor_uid).document(patient_uid).set(
            {
                "patientUid": patient_uid,
                "patientEmail": patient_email,
                "linkedAt": firestore.SERVER_TIMESTAMP,
            }
        )

    def unlink(self, doctor_uid: str, patient_uid: str) -> None:
        self._links(doctor_uid).document(patient_uid).delete()

    # ---- patient data ---------------------------------------------------

    def readings(
        self, patient_uid: str, *, limit: int, since: datetime | None = None
    ) -> list[dict[str, Any]]:
        """Newest readings first; ``id`` is the document id."""
        query = self._db.collection("patients").document(patient_uid).collection("readings")
        if since is not None:
            query = query.where(filter=FieldFilter("at", ">=", since))
        query = query.order_by("at", direction=firestore.Query.DESCENDING).limit(limit)
        return [_with_id(s) for s in query.stream()]
