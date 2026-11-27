"""Firestore access for the doctor API (read-mostly).

Collections used (see firebase/README.md):

* ``users/{uid}``                         profile and role of every account
* ``doctors/{doctorUid}/patients/{uid}``   "this doctor follows this patient".
  ``seq`` is the patient's number for this doctor (1, 2, 3...): the dashboard
  uses whole numbers as patient ids, and the numbers never reach other doctors
  or Firebase uids into URLs. ``doctors/{doctorUid}.lastSeq`` is the last
  number handed out, so a number is never reused after an unlink.
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


def _seconds(value: Any) -> float:
    return value.timestamp() if isinstance(value, datetime) else 0.0


class DoctorRepository:
    def __init__(self, db) -> None:
        self._db = db

    # ---- accounts -------------------------------------------------------

    def user_profile(self, uid: str) -> dict[str, Any] | None:
        snapshot = self._db.collection("users").document(uid).get()
        return snapshot.to_dict() if snapshot.exists else None

    # ---- doctor <-> patient links --------------------------------------

    def _doctor(self, doctor_uid: str):
        return self._db.collection("doctors").document(doctor_uid)

    def _links(self, doctor_uid: str):
        return self._doctor(doctor_uid).collection("patients")

    @staticmethod
    def _has_seq(link: dict[str, Any]) -> bool:
        return isinstance(link.get("seq"), int) and not isinstance(link.get("seq"), bool)

    def _next_seq(self, doctor_uid: str, links: list[dict[str, Any]]) -> int:
        snapshot = self._doctor(doctor_uid).get()
        last = (snapshot.to_dict() or {}).get("lastSeq") if snapshot.exists else 0
        known = [last] if isinstance(last, int) else []
        known += [link["seq"] for link in links if self._has_seq(link)]
        seq = max(known, default=0) + 1
        self._doctor(doctor_uid).set({"lastSeq": seq}, merge=True)
        return seq

    def linked_patients(self, doctor_uid: str) -> list[dict[str, Any]]:
        """Link documents of the doctor; ``id`` is the patient's uid.

        A link made before numbers existed gets its number here, oldest first,
        and keeps it from then on.
        """
        links = [_with_id(s) for s in self._links(doctor_uid).stream()]
        old_first = sorted(
            (link for link in links if not self._has_seq(link)),
            key=lambda link: (_seconds(link.get("linkedAt")), link["id"]),
        )
        for link in old_first:
            link["seq"] = self._next_seq(doctor_uid, links)
            self._links(doctor_uid).document(link["id"]).set({"seq": link["seq"]}, merge=True)
        return links

    def patient_uid_for(self, doctor_uid: str, seq: int) -> str | None:
        """The uid of the doctor's patient number ``seq``; None if there is none."""
        query = self._links(doctor_uid).where(filter=FieldFilter("seq", "==", seq)).limit(1)
        for snapshot in query.stream():
            return snapshot.id
        # Maybe an old link that has no number yet: give numbers out, then look again.
        for link in self.linked_patients(doctor_uid):
            if link["seq"] == seq:
                return link["id"]
        return None

    def link(self, doctor_uid: str, patient_uid: str, patient_email: str) -> tuple[int, bool]:
        """Link a patient. Returns (the patient's number, whether a link was created).

        Linking a patient who is already linked changes nothing.
        """
        links = self.linked_patients(doctor_uid)
        for existing in links:
            if existing["id"] == patient_uid:
                return existing["seq"], False
        seq = self._next_seq(doctor_uid, links)
        self._links(doctor_uid).document(patient_uid).set(
            {
                "patientUid": patient_uid,
                "patientEmail": patient_email,
                "linkedAt": firestore.SERVER_TIMESTAMP,
                "seq": seq,
            }
        )
        return seq, True

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
