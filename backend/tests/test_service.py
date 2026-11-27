from datetime import date, datetime, timezone

from app.repositories.doctor_repository import DoctorRepository
from app.services import doctor_service as s
from tests.fake_firestore import FakeFirestore


def test_age_from_birth_date():
    today = date(2026, 11, 27)
    assert s.age_from_birth_date("1990-11-27", today) == 36  # birthday today
    assert s.age_from_birth_date("1990-11-28", today) == 35  # birthday tomorrow
    assert s.age_from_birth_date("2026-11-27", today) == 0


def test_age_from_birth_date_unknown_values():
    today = date(2026, 11, 27)
    for bad in (None, "", "15/06/1990", "not a date", 1990, "2030-01-01", "1800-01-01"):
        assert s.age_from_birth_date(bad, today) is None, bad


def test_reported_type_uses_dashboard_names():
    assert s.reported_type("type1") == "Type 1"
    assert s.reported_type("type2") == "Type 2"
    assert s.reported_type(" TYPE2 ") == "Type 2"
    assert s.reported_type("gestational") == "Gestational"
    assert s.reported_type("Type 1") == "Type 1"  # already a dashboard name
    assert s.reported_type("something else") == "something else"
    assert s.reported_type("") is None and s.reported_type(None) is None and s.reported_type(5) is None


def test_patient_out_converts_the_type_code():
    assert s.patient_out({"diabetesType": "type2"}, {}).reportedType == "Type 2"


def test_reading_type_and_source():
    assert s.reading_type("fasting") == "FBS"
    assert s.reading_type("after_meal") == "PPBS"
    assert s.reading_type("before_meal") == "RBS"
    assert s.reading_type("random") == "RBS"
    assert s.reading_type(None) == "RBS"
    assert s.reading_source("manual") == "manual"
    assert s.reading_source(None) == "manual"
    for sensor in ("dexcom", "sensor", "simulator"):
        assert s.reading_source(sensor) == "cgm"


def test_reading_out_skips_incomplete_documents():
    at = datetime(2026, 11, 27, tzinfo=timezone.utc)
    assert s.reading_out({"id": "a", "at": at}) is None
    assert s.reading_out({"id": "a", "value": 100}) is None
    assert s.reading_out({"id": "a", "value": True, "at": at}) is None
    assert s.reading_out({"id": "a", "value": "100", "at": at}) is None
    assert s.reading_out({"id": "a", "value": 100, "at": at}).v == 100.0


def test_patient_out_without_profile_fields():
    p = s.patient_out({"email": "x@example.com"}, {})
    assert p.name == "x@example.com"
    assert p.age is None and p.reportedType is None and p.linkedAt is None
    assert s.patient_out(None, {}).name == "Patient"


def test_link_and_unlink():
    repo = DoctorRepository(FakeFirestore())
    assert not repo.is_linked("d", "p")
    repo.link("d", "p", "p@example.com")
    assert repo.is_linked("d", "p")
    [link] = repo.linked_patients("d")
    assert link["id"] == "p" and link["patientEmail"] == "p@example.com"
    assert isinstance(link["linkedAt"], datetime)
    repo.unlink("d", "p")
    assert not repo.is_linked("d", "p")
