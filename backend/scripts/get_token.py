"""Sign in with email and password and print a Firebase ID token.

For testing the API in Swagger (http://127.0.0.1:8000/docs): press Authorize
and paste the token. A token works for one hour.

Needs FIREBASE_WEB_API_KEY in backend/.env: the "apiKey" of the web app in
patient_interface/lib/firebase_options.dart (a public project identifier).
This script does not use the service-account key.

Run from the backend folder, with the virtual environment active:

    python -m scripts.get_token roa@example.com
"""

import argparse
import getpass
import sys

import httpx

from app.core.config import settings

SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("email")
    args = parser.parse_args(argv)

    if not settings.FIREBASE_WEB_API_KEY:
        print("Add FIREBASE_WEB_API_KEY=... to backend/.env first (see this file's description).")
        return 1

    password = getpass.getpass("Password: ")
    response = httpx.post(
        SIGN_IN_URL,
        params={"key": settings.FIREBASE_WEB_API_KEY},
        json={"email": args.email.strip().lower(), "password": password, "returnSecureToken": True},
        timeout=20,
    )
    body = response.json()
    if response.status_code != 200:
        print("Sign-in failed:", body.get("error", {}).get("message", response.status_code))
        return 1

    print(body["idToken"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
