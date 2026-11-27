"""Create a doctor account, or make an existing account a doctor.

Doctor accounts are never created from an app: the Firestore rules only let an
app create patients and caregivers. This script uses the service-account key
in backend/secrets/ (it never prints it).

Run from the backend folder, with the virtual environment active:

    python -m scripts.make_doctor roa@example.com "Dr. Roa Daraghmeh"

If the email has no Firebase account yet, it asks for a password and creates
one. If the account already belongs to a patient or caregiver, it stops: a
doctor needs their own account.
"""

import argparse
import getpass
import sys

from firebase_admin import auth, firestore

from app.auth.models import ROLE_DOCTOR
from app.core.firebase import get_firestore_client


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("email")
    parser.add_argument("name", help='full name, e.g. "Dr. Roa Daraghmeh"')
    args = parser.parse_args(argv)

    email = args.email.strip().lower()
    db = get_firestore_client()

    try:
        user = auth.get_user_by_email(email)
        print(f"Found the existing account {email}.")
    except auth.UserNotFoundError:
        password = getpass.getpass("Password for the new account (at least 6 characters): ")
        repeated = getpass.getpass("Repeat the password: ")
        if len(password) < 6:
            print(f"The password has {len(password)} characters; it needs at least 6. Nothing was created.")
            return 1
        if password != repeated:
            print("The two passwords are different. Nothing was created.")
            return 1
        user = auth.create_user(email=email, password=password, display_name=args.name)
        print(f"Created the account {email}.")

    ref = db.collection("users").document(user.uid)
    snapshot = ref.get()
    existing = snapshot.to_dict() if snapshot.exists else {}
    if existing.get("role") not in (None, ROLE_DOCTOR):
        print(f"{email} is already a {existing['role']}. Use a different email for the doctor.")
        return 1

    profile = {"role": ROLE_DOCTOR, "email": email, "fullName": args.name.strip()}
    if not snapshot.exists:
        profile["createdAt"] = firestore.SERVER_TIMESTAMP
    ref.set(profile, merge=True)
    print(f"{email} is now a doctor (uid {user.uid}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
