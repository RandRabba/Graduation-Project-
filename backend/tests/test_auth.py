import pytest
from firebase_admin import auth as firebase_auth

from app.auth import deps, tokens
from app.auth.tokens import InvalidTokenError, TokenServiceError
from tests.conftest import auth


def test_missing_token_is_401(client):
    r = client.get("/api/v1/me")
    assert r.status_code == 401
    assert r.headers["www-authenticate"] == "Bearer"


def test_invalid_token_is_401(client):
    r = client.get("/api/v1/me", headers=auth("nonsense"))
    assert r.status_code == 401


def test_valid_account_without_profile_is_403(client):
    r = client.get("/api/v1/me", headers=auth("ghost-token"))
    assert r.status_code == 403


def test_me_returns_role_for_any_account(client):
    r = client.get("/api/v1/me", headers=auth("patient-token"))
    assert r.status_code == 200
    assert r.json() == {"uid": "p1", "email": "sobhi@example.com", "role": "patient", "name": "Sobhi"}


def test_doctor_profile_only_for_doctors(client):
    assert client.get("/api/v1/doctor", headers=auth("patient-token")).status_code == 403
    assert client.get("/api/v1/doctor", headers=auth("caregiver-token")).status_code == 403
    r = client.get("/api/v1/doctor", headers=auth("doctor-token"))
    assert r.status_code == 200
    assert r.json() == {"id": "doc1", "name": "Dr. Roa", "email": "roa@example.com"}


def test_token_service_down_is_503(client, monkeypatch):
    def down(token, **_):
        raise TokenServiceError("no internet")

    monkeypatch.setattr(deps, "verify_token", down)
    assert client.get("/api/v1/me", headers=auth("doctor-token")).status_code == 503


@pytest.fixture
def no_firebase_init(monkeypatch):
    monkeypatch.setattr(tokens, "initialize_firebase", lambda: None)


@pytest.mark.parametrize(
    "error",
    [
        ValueError("malformed"),
        firebase_auth.ExpiredIdTokenError("expired", None),
        firebase_auth.RevokedIdTokenError("revoked"),
        firebase_auth.InvalidIdTokenError("invalid"),
        firebase_auth.UserDisabledError("disabled"),
    ],
)
def test_verify_token_maps_bad_tokens(no_firebase_init, monkeypatch, error):
    def raise_it(*a, **k):
        raise error

    monkeypatch.setattr(tokens.firebase_auth, "verify_id_token", raise_it)
    with pytest.raises(InvalidTokenError):
        tokens.verify_token("x")


def test_verify_token_maps_certificate_problem(no_firebase_init, monkeypatch):
    def raise_it(*a, **k):
        raise firebase_auth.CertificateFetchError("offline", None)

    monkeypatch.setattr(tokens.firebase_auth, "verify_id_token", raise_it)
    with pytest.raises(TokenServiceError):
        tokens.verify_token("x")


def test_verify_token_returns_claims_and_allows_clock_skew(no_firebase_init, monkeypatch):
    seen = {}

    def ok(token, **kwargs):
        seen.update(kwargs)
        return {"uid": "u"}

    monkeypatch.setattr(tokens.firebase_auth, "verify_id_token", ok)
    assert tokens.verify_token("x") == {"uid": "u"}
    assert seen["clock_skew_seconds"] == tokens.CLOCK_SKEW_SECONDS
    assert seen["check_revoked"] is False
