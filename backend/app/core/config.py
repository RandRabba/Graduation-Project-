from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    APP_NAME: str = "Diabetes Management System"
    API_V1_PREFIX: str = "/api/v1"

    FIREBASE_CREDENTIALS_PATH: str = str(
        BASE_DIR / "secrets" / "firebase-service-account.json"
    )

    # Web pages allowed to call this API from a browser (the doctor dashboard).
    # In .env write it as JSON, e.g.
    # CORS_ORIGINS=["http://127.0.0.1:5500","http://localhost:5500"]
    CORS_ORIGINS: list[str] = [
        "http://127.0.0.1:5500",
        "http://localhost:5500",
        "http://127.0.0.1:8080",
        "http://localhost:8080",
    ]

    # Only used by scripts/get_token.py to sign in with email + password.
    # It is the "apiKey" of the web app in patient_interface/lib/firebase_options.dart.
    # It identifies the Firebase project and is not a secret, but keep it in .env.
    FIREBASE_WEB_API_KEY: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
