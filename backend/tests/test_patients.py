from tests.conftest import T0, T1, T2, auth

DOC = auth("doctor-token")


def test_patients_only_those_linked_to_the_doctor(client):
    r = client.get("/api/v1/patients", headers=DOC)
    assert r.status_code == 200
    body = r.json()
    assert list(body) == ["1"]
    p = body["1"]
    assert p["name"] == "Sobhi"
    assert p["reportedType"] == "Type 1"
    assert isinstance(p["age"], int)
    assert p["sex"] is None
    assert p["linkedAt"] == int(T0.timestamp())


def test_patients_are_listed_by_number(client, db):
    db.put("users", "p3", {"role": "patient", "email": "third@example.com", "fullName": "Third"})
    db.put("doctors", "doc1", "patients", "p3", {"patientUid": "p3", "linkedAt": T1, "seq": 3})
    body = client.get("/api/v1/patients", headers=DOC).json()
    assert list(body) == ["1", "3"]
    assert body["3"]["name"] == "Third"


def test_second_doctor_sees_nobody(client):
    r = client.get("/api/v1/patients", headers=auth("doctor2-token"))
    assert r.status_code == 200
    assert r.json() == {}


def test_patients_need_a_doctor(client):
    assert client.get("/api/v1/patients").status_code == 401
    assert client.get("/api/v1/patients", headers=auth("patient-token")).status_code == 403
    assert client.get("/api/v1/patients", headers=auth("caregiver-token")).status_code == 403


def test_readings_newest_first_and_mapped(client):
    r = client.get("/api/v1/patients/1/readings", headers=DOC)
    assert r.status_code == 200
    assert r.json() == [
        {"id": "dexcom-2", "v": 260.0, "at": int(T2.timestamp()), "src": "cgm", "type": "RBS"},
        {"id": "manual-1", "v": 105.0, "at": int(T1.timestamp()), "src": "manual", "type": "FBS"},
    ]  # the document without a value is skipped


def test_readings_limit_and_since(client):
    r = client.get("/api/v1/patients/1/readings?limit=1", headers=DOC)
    assert [x["id"] for x in r.json()] == ["dexcom-2"]
    r = client.get(f"/api/v1/patients/1/readings?since={int(T2.timestamp())}", headers=DOC)
    assert [x["id"] for x in r.json()] == ["dexcom-2"]


def test_readings_reject_bad_query(client):
    assert client.get("/api/v1/patients/1/readings?limit=0", headers=DOC).status_code == 422
    assert client.get("/api/v1/patients/1/readings?limit=5000", headers=DOC).status_code == 422
    assert client.get("/api/v1/patients/1/readings?since=-1", headers=DOC).status_code == 422


def test_unknown_patient_numbers_are_404(client):
    a = client.get("/api/v1/patients/2/readings", headers=DOC)  # the doctor has no patient 2
    b = client.get("/api/v1/patients/999/readings", headers=DOC)
    assert a.status_code == b.status_code == 404
    assert a.json() == b.json()


def test_patient_ids_must_be_whole_numbers(client):
    for bad in ("p1", "0", "-3", "1.5", "99999999999999999999"):
        assert client.get(f"/api/v1/patients/{bad}/readings", headers=DOC).status_code == 422, bad


def test_other_roles_cannot_read_readings(client):
    for token in ("patient-token", "caregiver-token"):
        assert client.get("/api/v1/patients/1/readings", headers=auth(token)).status_code == 403
    assert client.get("/api/v1/patients/1/readings").status_code == 401


def test_second_doctor_cannot_read_first_doctors_patient(client, db):
    # Patient number 1 of doctor 2 is a different patient, never doctor 1's.
    assert client.get("/api/v1/patients/1/readings", headers=auth("doctor2-token")).status_code == 404
    db.put("doctors", "doc2", "patients", "p2", {"patientUid": "p2", "linkedAt": T0, "seq": 1})
    r = client.get("/api/v1/patients/1/readings", headers=auth("doctor2-token"))
    assert [x["id"] for x in r.json()] == ["manual-9"]  # p2's reading, not p1's
    r = client.get("/api/v1/patients", headers=auth("doctor2-token"))
    assert r.json()["1"]["name"] == "Other"


def test_not_stored_yet_endpoints_return_empty_lists(client):
    for name in ("meals", "consultations", "doses", "requests", "instructions", "chat"):
        r = client.get(f"/api/v1/patients/1/{name}", headers=DOC)
        assert r.status_code == 200 and r.json() == [], name
        assert client.get(f"/api/v1/patients/2/{name}", headers=DOC).status_code == 404, name
    assert client.get("/api/v1/reminders", headers=DOC).json() == []
    assert client.get("/api/v1/reminders", headers=auth("patient-token")).status_code == 403


def test_cors_allows_the_dashboard_origin_only(client):
    ask = {"Access-Control-Request-Method": "GET", "Access-Control-Request-Headers": "authorization"}
    ok = client.options("/api/v1/patients", headers={"Origin": "http://127.0.0.1:5500", **ask})
    assert ok.status_code == 200
    assert ok.headers["access-control-allow-origin"] == "http://127.0.0.1:5500"
    assert ok.headers["access-control-allow-credentials"] == "true"
    bad = client.options("/api/v1/patients", headers={"Origin": "http://evil.example", **ask})
    assert "access-control-allow-origin" not in bad.headers
