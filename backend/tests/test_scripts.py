from types import SimpleNamespace

import pytest
from firebase_admin import auth as firebase_auth

from scripts import link_patient, make_doctor

ACCOUNTS = {"roa@example.com": "doc1", "sobhi@example.com": "p1", "care@example.com": "care1"}


@pytest.fixture
def accounts(db, monkeypatch):
    """Both scripts talk to the fake Firestore and a fake Firebase Auth."""
    created = []

    def get_user_by_email(email):
        if email not in ACCOUNTS:
            raise firebase_auth.UserNotFoundError("nope")
        return SimpleNamespace(uid=ACCOUNTS[email])

    def create_user(email, password, display_name):
        created.append(email)
        user = SimpleNamespace(uid="new-" + email.split("@")[0])
        return user

    for module in (make_doctor, link_patient):
        monkeypatch.setattr(module, "get_firestore_client", lambda: db)
    monkeypatch.setattr(firebase_auth, "get_user_by_email", get_user_by_email)
    monkeypatch.setattr(firebase_auth, "create_user", create_user)
    return created


def test_make_doctor_creates_account_and_profile(db, accounts, monkeypatch):
    monkeypatch.setattr(make_doctor.getpass, "getpass", lambda prompt="": "secret123")
    assert make_doctor.main(["new.doc@example.com", "Dr. New"]) == 0
    assert accounts == ["new.doc@example.com"]
    profile = db.collection("users").document("new-new.doc").get().to_dict()
    assert profile["role"] == "doctor"
    assert profile["email"] == "new.doc@example.com"
    assert profile["fullName"] == "Dr. New"
    assert "createdAt" in profile


def test_make_doctor_rejects_mismatched_password(db, accounts, monkeypatch):
    answers = iter(["secret123", "different"])
    monkeypatch.setattr(make_doctor.getpass, "getpass", lambda prompt="": next(answers))
    assert make_doctor.main(["new.doc@example.com", "Dr. New"]) == 1
    assert accounts == []


def test_make_doctor_is_repeatable_for_a_doctor(db, accounts):
    assert make_doctor.main(["ROA@example.com", "Dr. Roa D."]) == 0
    profile = db.collection("users").document("doc1").get().to_dict()
    assert profile["role"] == "doctor" and profile["fullName"] == "Dr. Roa D."


def test_make_doctor_never_changes_a_patient(db, accounts):
    assert make_doctor.main(["sobhi@example.com", "Dr. Sobhi"]) == 1
    assert db.collection("users").document("p1").get().to_dict()["role"] == "patient"


def test_link_patient_and_remove(db, accounts):
    assert link_patient.main(["roa@example.com", "sobhi@example.com"]) == 0
    assert db.collection("doctors").document("doc1").collection("patients").document("p1").get().exists
    assert link_patient.main(["roa@example.com", "sobhi@example.com", "--remove"]) == 0
    assert not db.collection("doctors").document("doc1").collection("patients").document("p1").get().exists


def test_link_patient_checks_roles_and_accounts(db, accounts):
    assert link_patient.main(["sobhi@example.com", "roa@example.com"]) == 1  # swapped
    assert link_patient.main(["roa@example.com", "care@example.com"]) == 1  # caregiver
    assert link_patient.main(["roa@example.com", "nobody@example.com"]) == 1  # no account
