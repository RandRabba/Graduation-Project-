"""Link codes: making them and reading what a patient typed.

A code is made for ONE patient by the doctor, works once, and has no expiry.
The format is the dashboard's (doctor_dashboard/js/core/linkcode.js):
``DMS-XXXX-XXXX-XX`` with 10 random characters from a 31-character alphabet
(no 0/O, no 1/I/L), about 8 x 10^14 possible codes.

Kept free of FastAPI and Firestore so it can be tested on plain values.
"""

import re
import secrets
from typing import Any

from app.schemas.link_codes import LinkCodeOut
from app.services.doctor_service import unix_seconds

ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
RANDOM_LEN = 10

# What the dashboard shows and the Patient App sends back.
CODE_RE = re.compile(r"^DMS-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{2}$")
# For the URL of DELETE /doctor/link-codes/{id}: the id is the code itself.
CODE_PATH_PATTERN = r"^DMS-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{2}$"


def generate_code() -> str:
    """A new random code (``secrets``: not guessable from earlier codes)."""
    s = "".join(secrets.choice(ALPHABET) for _ in range(RANDOM_LEN))
    return f"DMS-{s[:4]}-{s[4:8]}-{s[8:]}"


def normalize_code(text: str) -> str | None:
    """The code a patient typed, in the stored layout; None if it cannot be a code.

    Capital letters, spaces and dashes do not matter: ``dms 2345 6789 AB`` and
    ``DMS-2345-6789-AB`` are the same code.
    """
    letters = re.sub(r"[^A-Z0-9]", "", str(text).upper())
    if len(letters) != 3 + RANDOM_LEN or not letters.startswith("DMS"):
        return None
    body = letters[3:]
    code = f"DMS-{body[:4]}-{body[4:8]}-{body[8:]}"
    return code if CODE_RE.fullmatch(code) else None


def code_out(doc: dict[str, Any]) -> LinkCodeOut | None:
    """A stored code as the dashboard expects it; None for a document that is not a valid code."""
    created = unix_seconds(doc.get("createdAt"))
    status = doc.get("status")
    if created is None or status not in ("pending", "used") or not CODE_RE.fullmatch(str(doc.get("id", ""))):
        return None
    return LinkCodeOut(
        id=doc["id"],
        label=str(doc.get("label") or ""),
        code=doc["id"],
        at=created,
        st=status,
        usedAt=unix_seconds(doc.get("usedAt")),
    )
