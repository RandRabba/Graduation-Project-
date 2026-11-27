from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    APP_NAME: str = "Diabetes Management System"
    API_V1_PREFIX: str = "/api/v1"

    FIREBASE_CREDENTIALS_PATH: str = str(
        BASE_DIR / "secrets" / "firebase-service-account.json"
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()