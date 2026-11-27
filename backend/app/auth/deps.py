"""FastAPI dependencies: who is calling, and are they a doctor.

The role is read from ``users/{uid}`` in Firestore (the same document the
Firestore rules and the apps use). Doctor accounts are created only with
``scripts/make_doctor.py``: the rules never let an app create one.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth.models import ROLE_DOCTOR, ROLE_PATIENT, CurrentUser
from app.auth.tokens import InvalidTokenError, TokenServiceError, verify_token
from app.core.firebase import get_db

# auto_error=False so a missing header gives our own 401 (HTTPBearer's default
# would answer 403).
bearer_scheme = HTTPBearer(auto_error=False, description="Firebase ID token")


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db=Depends(get_db),
) -> CurrentUser:
    if credentials is None or not credentials.credentials:
        raise _unauthorized("Missing bearer token")

    try:
        claims = verify_token(credentials.credentials)
    except InvalidTokenError:
        raise _unauthorized("Invalid or expired token")
    except TokenServiceError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not check the token right now",
        )

    uid = claims["uid"]
    snapshot = db.collection("users").document(uid).get()
    profile = snapshot.to_dict() if snapshot.exists else None
    if not profile or not isinstance(profile.get("role"), str):
        # A valid Firebase account that has no profile in the DMS.
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has no DMS profile",
        )

    return CurrentUser(
        uid=uid,
        email=str(claims.get("email") or profile.get("email") or "").lower(),
        role=profile["role"],
        name=str(profile.get("fullName") or ""),
    )


def require_doctor(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if user.role != ROLE_DOCTOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctors only",
        )
    return user


def require_patient(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if user.role != ROLE_PATIENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Patients only",
        )
    return user
