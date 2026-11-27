"""Firestore access for link codes.

``linkCodes/{code}`` (the document id IS the code, so a code can never exist
twice and redeeming is one lookup):

* ``doctorUid``   the doctor who made it
* ``label``       the doctor's own note ("Ahmad, clinic visit"); never shown to patients
* ``status``      ``pending`` or ``used``
* ``createdAt``   when it was made
* ``usedAt``, ``usedBy``   set when a patient redeems it (``usedBy`` is that patient's uid)

The Firestore rules never match ``linkCodes/...``, so the apps cannot read or
write it; only this server (Admin SDK) can. Redeeming and cancelling run in
transactions, so a code works for exactly one patient even if two requests
arrive together.
"""

from datetime import datetime, timezone
from typing import Any

from google.api_core.exceptions import AlreadyExists
from google.cloud import firestore
from google.cloud.firestore import FieldFilter

COLLECTION = "linkCodes"
PENDING = "pending"
USED = "used"


def run_transaction(db, work):
    """Runs ``work(transaction)`` in a Firestore transaction and returns its result.

    (A separate function so the tests can swap it for the in-memory fake.)
    """
    transaction = db.transaction()
    return firestore.transactional(work)(transaction)


class LinkCodeRepository:
    def __init__(self, db) -> None:
        self._db = db

    def _ref(self, code: str):
        return self._db.collection(COLLECTION).document(code)

    def create(self, doctor_uid: str, label: str, code: str) -> dict[str, Any] | None:
        """Stores a new pending code. None if that code already exists (draw another)."""
        data = {
            "doctorUid": doctor_uid,
            "label": label,
            "status": PENDING,
            "createdAt": datetime.now(timezone.utc),
            "usedAt": None,
            "usedBy": None,
        }
        try:
            self._ref(code).create(data)
        except AlreadyExists:
            return None
        return {"id": code, **data}

    def list_for(self, doctor_uid: str) -> list[dict[str, Any]]:
        """All codes of the doctor (pending and used); ``id`` is the code."""
        query = self._db.collection(COLLECTION).where(filter=FieldFilter("doctorUid", "==", doctor_uid))
        return [{"id": s.id, **(s.to_dict() or {})} for s in query.stream()]

    def count_pending(self, doctor_uid: str) -> int:
        return sum(1 for c in self.list_for(doctor_uid) if c.get("status") == PENDING)

    def cancel(self, doctor_uid: str, code: str) -> str:
        """Deletes a pending code of this doctor: ``deleted``, ``missing`` or ``used``.

        Someone else's code answers ``missing``, the same as a code that does not exist.
        """
        ref = self._ref(code)

        def work(transaction):
            snapshot = ref.get(transaction=transaction)
            data = snapshot.to_dict() if snapshot.exists else None
            if not data or data.get("doctorUid") != doctor_uid:
                return "missing"
            if data.get("status") != PENDING:
                return "used"
            transaction.delete(ref)
            return "deleted"

        return run_transaction(self._db, work)

    def claim(self, code: str, patient_uid: str) -> dict[str, Any] | None:
        """Marks a pending code as used by this patient.

        Returns the code's document (with ``doctorUid``), or None if there is no
        such code or it was already used or cancelled. Only one caller can win.
        """
        ref = self._ref(code)

        def work(transaction):
            snapshot = ref.get(transaction=transaction)
            data = snapshot.to_dict() if snapshot.exists else None
            if not data or data.get("status") != PENDING:
                return None
            transaction.update(
                ref,
                {"status": USED, "usedAt": datetime.now(timezone.utc), "usedBy": patient_uid},
            )
            return data

        return run_transaction(self._db, work)

    def release(self, code: str) -> None:
        """Gives a claimed code back (the link could not be stored)."""
        self._ref(code).update({"status": PENDING, "usedAt": None, "usedBy": None})
