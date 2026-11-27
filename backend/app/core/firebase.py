import firebase_admin
from firebase_admin import credentials, firestore
from pathlib import Path

from app.core.config import settings


def initialize_firebase():
    """Initialize Firebase Admin SDK."""

    if not firebase_admin._apps:
        cred = credentials.Certificate(
            settings.FIREBASE_CREDENTIALS_PATH
        )

        firebase_admin.initialize_app(cred)


def get_firestore_client():
    """Return Firestore database client."""

    initialize_firebase()
    return firestore.client()


def get_db():
    """FastAPI dependency for the Firestore client.

    Tests replace it with a fake through ``app.dependency_overrides``.
    """

    return get_firestore_client()