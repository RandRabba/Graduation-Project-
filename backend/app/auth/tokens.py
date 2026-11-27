"""Checking the Firebase ID token that a client sends with each request."""

from firebase_admin import auth as firebase_auth

from app.core.firebase import initialize_firebase

# Allow a few seconds of difference between this computer's clock and Google's.
CLOCK_SKEW_SECONDS = 10


class InvalidTokenError(Exception):
    """The token is missing, malformed, expired, revoked or for a disabled user."""


class TokenServiceError(Exception):
    """The token could not be checked right now (for example no internet)."""


def verify_token(token: str, *, check_revoked: bool = False) -> dict:
    """Return the claims of a valid Firebase ID token.

    The claims include ``uid`` and, for email sign-in, ``email``.

    ``check_revoked`` also asks Firebase whether the account was disabled or
    its sessions were revoked. It costs one extra network call per request, so
    it is off by default.
    """

    initialize_firebase()
    try:
        return firebase_auth.verify_id_token(
            token,
            check_revoked=check_revoked,
            clock_skew_seconds=CLOCK_SKEW_SECONDS,
        )
    except (
        ValueError,
        # Expired and revoked tokens are subclasses of this one.
        firebase_auth.InvalidIdTokenError,
        firebase_auth.UserDisabledError,
    ) as exc:
        raise InvalidTokenError(str(exc)) from exc
    except firebase_auth.CertificateFetchError as exc:
        raise TokenServiceError(str(exc)) from exc
