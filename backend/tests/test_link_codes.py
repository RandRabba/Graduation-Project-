"""Link codes: the doctor makes them, a patient redeems them once."""

from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.api.v1 import link_codes as routes
from app.main import app
from app.repositories.doctor_repository import DoctorRepository
from app.services.link_codes import CODE_RE
from tests.conftest import auth

NEW = "/api/v1/doctor/link-codes"
REDEEM = "/api/v1/link-codes/redeem"
LATER = datetime(2026, 11, 27, 18, 0, tzinfo=timezone.utc)


def make_code(client, token="doctor-token", label="Ahmad"):
    r = client.post(NEW, json={"label": label}, headers=auth(token))
    assert r.status_code == 201, r.text
    return r.json()


def redeem(client, code, token="patient2-token"):
    return client.post(REDEEM, json={"code": code}, headers=auth(token))


# ---- the doctor makes and manages codes ------------------------------------


def test_create_returns_the_shape_the_dashboard_expects(client, db):
    c = make_code(client, label="  Ahmad, clinic  ")
    assert set(c) == {"id", "label", "code", "at", "st", "usedAt"}
    assert CODE_RE.fullmatch(c["code"])
    assert c["id"] == c["code"]
    assert c["label"] == "Ahmad, clinic"
    assert c["st"] == "pending" and c["usedAt"] is None
    assert isinstance(c["at"], int) and c["at"] > 0
    stored = db._store[("linkCodes", c["code"])]
    assert stored["doctorUid"] == "doc1" and stored["status"] == "pending"


def test_label_is_optional_and_limited(client):
    assert client.post(NEW, json={}, headers=auth("doctor-token")).json()["label"] == ""
    assert client.post(NEW, json={"label": "x" * 61}, headers=auth("doctor-token")).status_code == 422
    assert client.post(NEW, json={"label": "x" * 60}, headers=auth("doctor-token")).status_code == 201


def test_codes_are_different_each_time(client):
    assert len({make_code(client)["code"] for _ in range(20)}) == 20


@pytest.mark.parametrize("method", ["post", "get"])
def test_only_a_doctor_may_manage_codes(client, method):
    call = getattr(client, method)
    kwargs = {"json": {}} if method == "post" else {}
    assert call(NEW, **kwargs).status_code == 401
    for token in ("patient-token", "caregiver-token"):
        assert call(NEW, headers=auth(token), **kwargs).status_code == 403


def test_list_shows_only_my_codes_newest_first(client, db):
    older = make_code(client, label="older")
    newer = make_code(client, label="newer")
    db._store[("linkCodes", older["code"])]["createdAt"] = datetime(2026, 1, 1, tzinfo=timezone.utc)
    make_code(client, token="doctor2-token", label="not mine")
    db.put("linkCodes", "junk", {"doctorUid": "doc1", "status": "pending"})  # not a valid code: skipped

    codes = client.get(NEW, headers=auth("doctor-token")).json()
    assert [c["label"] for c in codes] == ["newer", "older"]
    assert codes[0]["code"] == newer["code"]


def test_list_shows_used_codes_with_the_time(client, db):
    c = make_code(client)
    redeem(client, c["code"])
    (listed,) = client.get(NEW, headers=auth("doctor-token")).json()
    assert listed["st"] == "used" and isinstance(listed["usedAt"], int)


def test_cancel_a_pending_code(client, db):
    c = make_code(client)
    assert client.delete(f"{NEW}/{c['id']}", headers=auth("doctor-token")).status_code == 204
    assert ("linkCodes", c["code"]) not in db._store
    assert redeem(client, c["code"]).status_code == 404  # a cancelled code is dead


def test_cancel_unknown_or_someone_elses_code_is_404(client):
    c = make_code(client)
    other = client.delete(f"{NEW}/{c['id']}", headers=auth("doctor2-token"))
    assert other.status_code == 404
    unknown = client.delete(f"{NEW}/DMS-2222-2222-22", headers=auth("doctor-token"))
    assert unknown.status_code == 404
    assert other.json() == unknown.json()
    assert redeem(client, c["code"]).status_code == 200  # still alive


def test_cancel_a_used_code_is_409(client):
    c = make_code(client)
    redeem(client, c["code"])
    assert client.delete(f"{NEW}/{c['id']}", headers=auth("doctor-token")).status_code == 409


def test_cancel_with_a_malformed_id_is_422(client):
    assert client.delete(f"{NEW}/not-a-code", headers=auth("doctor-token")).status_code == 422


def test_cancel_needs_a_doctor(client):
    c = make_code(client)
    assert client.delete(f"{NEW}/{c['id']}").status_code == 401
    assert client.delete(f"{NEW}/{c['id']}", headers=auth("patient-token")).status_code == 403


def test_a_doctor_cannot_pile_up_codes(client, monkeypatch):
    monkeypatch.setattr(routes, "MAX_PENDING_CODES", 3)
    for _ in range(3):
        make_code(client)
    assert client.post(NEW, json={}, headers=auth("doctor-token")).status_code == 409
    assert client.post(NEW, json={}, headers=auth("doctor2-token")).status_code == 201  # per doctor


# ---- the patient redeems a code ---------------------------------------------


def test_redeem_links_the_patient_to_the_doctor(client, db):
    c = make_code(client)
    r = redeem(client, c["code"])
    assert r.status_code == 200
    assert r.json() == {"alreadyLinked": False, "doctorName": "Dr. Roa"}

    patients = client.get("/api/v1/patients", headers=auth("doctor-token")).json()
    assert sorted(patients) == ["1", "2"]  # p1 was number 1; the new patient gets 2
    assert patients["2"]["name"] == "Other"

    stored = db._store[("linkCodes", c["code"])]
    assert stored["status"] == "used" and stored["usedBy"] == "p2" and stored["usedAt"] is not None
    link = db._store[("doctors", "doc1", "patients", "p2")]
    assert link["patientEmail"] == "other@example.com" and link["seq"] == 2


def test_the_new_patient_is_not_visible_to_other_doctors(client):
    redeem(client, make_code(client)["code"])
    assert client.get("/api/v1/patients", headers=auth("doctor2-token")).json() == {}


def test_redeem_ignores_case_spaces_and_missing_dashes(client):
    c = make_code(client)
    typed = c["code"].lower().replace("-", " ")
    assert redeem(client, typed).status_code == 200


def test_a_code_works_only_once(client):
    c = make_code(client)
    assert redeem(client, c["code"]).status_code == 200
    again_same = redeem(client, c["code"])
    assert again_same.status_code == 404
    # nobody else can take it either
    db_other = redeem(client, c["code"], token="patient-token")
    assert db_other.status_code == 404
    assert db_other.json() == again_same.json()


def test_redeeming_when_already_linked_keeps_the_number(client, db):
    c = make_code(client)
    r = redeem(client, c["code"], token="patient-token")  # p1 is already doctor 1's patient number 1
    assert r.status_code == 200 and r.json()["alreadyLinked"] is True
    assert db._store[("doctors", "doc1", "patients", "p1")]["seq"] == 1
    assert db._store[("doctors", "doc1")]["lastSeq"] == 1


@pytest.mark.parametrize("text", ["DMS-2222-2222-22", "hello", "DMS-1111-1111-11", "", "DMS" * 30, "ß" * 5])
def test_a_wrong_code_gets_one_answer(client, text):
    r = redeem(client, text)
    assert r.status_code in (404, 422)
    if r.status_code == 404:
        assert r.json() == {"detail": routes.INVALID_CODE}


def test_only_a_patient_may_redeem(client):
    c = make_code(client)
    assert client.post(REDEEM, json={"code": c["code"]}).status_code == 401
    for token in ("doctor-token", "caregiver-token", "ghost-token"):
        assert redeem(client, c["code"], token=token).status_code in (403,)
    assert client.get(NEW, headers=auth("doctor-token")).json()[0]["st"] == "pending"


def test_guessing_is_stopped_after_five_wrong_codes(client):
    c = make_code(client)
    for _ in range(5):
        assert redeem(client, "DMS-2222-2222-22").status_code == 404
    blocked = redeem(client, c["code"])
    assert blocked.status_code == 429
    assert int(blocked.headers["Retry-After"]) > 0
    # it counts per account: another patient is not affected
    assert redeem(client, c["code"], token="patient-token").status_code == 200


def test_a_right_code_clears_earlier_typos(client):
    c = make_code(client)
    for _ in range(4):
        redeem(client, "DMS-2222-2222-22")
    assert redeem(client, c["code"]).status_code == 200
    for _ in range(4):
        assert redeem(client, "DMS-3333-3333-33").status_code == 404  # fresh count, not blocked


def test_the_code_is_given_back_if_linking_fails(client, db, monkeypatch):
    c = make_code(client)
    real_link = DoctorRepository.link
    calls = []

    def link_once_broken(self, *args, **kwargs):
        calls.append(1)
        if len(calls) == 1:
            raise RuntimeError("firestore down")
        return real_link(self, *args, **kwargs)

    monkeypatch.setattr(DoctorRepository, "link", link_once_broken)
    failing = TestClient(app, raise_server_exceptions=False)  # no "with": the app's start-up needs Firebase
    assert redeem(failing, c["code"]).status_code == 500
    assert db._store[("linkCodes", c["code"])]["status"] == "pending"

    assert redeem(client, c["code"]).status_code == 200  # the patient can try again
