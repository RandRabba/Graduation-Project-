from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.auth import deps
from app.auth.tokens import InvalidTokenError
from app.core.firebase import get_db
from app.core.throttle import redeem_limiter
from app.main import app
from app.repositories import link_code_repository
from tests.fake_firestore import FakeFirestore

T0 = datetime(2026, 11, 27, 9, 0, tzinfo=timezone.utc)
T1 = datetime(2026, 11, 27, 15, 30, tzinfo=timezone.utc)
T2 = datetime(2026, 11, 27, 16, 25, tzinfo=timezone.utc)

# token -> the claims Firebase would return for it
TOKENS = {
    "doctor-token": {"uid": "doc1", "email": "roa@example.com"},
    "doctor2-token": {"uid": "doc2", "email": "second@example.com"},
    "patient-token": {"uid": "p1", "email": "sobhi@example.com"},
    "patient2-token": {"uid": "p2", "email": "other@example.com"},
    "caregiver-token": {"uid": "care1", "email": "care@example.com"},
    "ghost-token": {"uid": "ghost", "email": "ghost@example.com"},
}


def auth(token):
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def db():
    d = FakeFirestore()
    d.put("users", "doc1", {"role": "doctor", "email": "roa@example.com", "fullName": "Dr. Roa"})
    d.put("users", "doc2", {"role": "doctor", "email": "second@example.com", "fullName": "Dr. Second"})
    d.put("users", "p1", {"role": "patient", "email": "sobhi@example.com", "fullName": "Sobhi",
                          "diabetesType": "Type 1", "dateOfBirth": "1990-06-15"})
    d.put("users", "p2", {"role": "patient", "email": "other@example.com", "fullName": "Other"})
    d.put("users", "care1", {"role": "caregiver", "email": "care@example.com"})
    d.put("doctors", "doc1", {"lastSeq": 1})
    d.put("doctors", "doc1", "patients", "p1", {"patientUid": "p1", "linkedAt": T0, "seq": 1})
    d.put("patients", "p1", "readings", "manual-1", {"value": 105, "at": T1, "source": "manual", "timing": "fasting"})
    d.put("patients", "p1", "readings", "dexcom-2", {"value": 260.0, "at": T2, "source": "dexcom"})
    d.put("patients", "p1", "readings", "broken-3", {"at": T0, "source": "manual"})  # no value
    d.put("patients", "p2", "readings", "manual-9", {"value": 90, "at": T1, "source": "manual"})
    return d


@pytest.fixture(autouse=True)
def fake_transactions(monkeypatch):
    """Link codes use Firestore transactions; the fake has no server, so just run the work."""
    monkeypatch.setattr(link_code_repository, "run_transaction", lambda db, work: work(db.transaction()))
    redeem_limiter.clear_all()


@pytest.fixture
def client(db, monkeypatch):
    def fake_verify(token, **_):
        if token not in TOKENS:
            raise InvalidTokenError("bad token")
        return TOKENS[token]

    monkeypatch.setattr(deps, "verify_token", fake_verify)
    app.dependency_overrides[get_db] = lambda: db
    yield TestClient(app)
    app.dependency_overrides.clear()
