# DMS backend (FastAPI)

The doctor's API. The patient and caregiver apps talk to Firestore directly
(`firebase/firestore.rules` is their permission system). Doctors cannot, so the
dashboard calls this server, which checks who is asking and then reads
Firestore with the Admin SDK.

```
Authorization: Bearer <Firebase ID token>   ->   verified in app/auth
users/{uid}.role == "doctor"                 ->   require_doctor
doctors/{doctorUid}/patients/{patientUid}    ->   only the doctor's own patients (app/access)
```

## Run

```
cd backend
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

It needs the service-account key at `backend/secrets/firebase-service-account.json`
(git-ignored; never share or commit it). Swagger: http://127.0.0.1:8000/docs

## Endpoints (`/api/v1`, doctor token required unless noted)

| Method and path | Answer |
|---|---|
| `GET /me` (any signed-in account) | `{uid, email, role, name}` |
| `GET /doctor` | `{id, name, email}` |
| `GET /patients` | `{"1": {name, age, sex, reportedType, linkedAt}, "2": ...}` keyed by the patient's number |
| `GET /patients/{id}/readings?limit=500&since=<unix s>` | `[{id, v, at, src: cgm\|manual, type: FBS\|RBS\|PPBS}]`, newest first |
| `GET /patients/{id}/{meals,consultations,doses,requests,instructions,chat}` and `GET /reminders` | `[]` for now: not stored anywhere yet, but the dashboard asks for them on load |

**Patient numbers.** `{id}` is a small whole number (1, 2, 3...) that belongs to
the calling doctor, not the patient's Firebase uid: the dashboard uses whole
numbers as ids everywhere. `scripts/link_patient` hands out the next number
(never reusing one after an unlink) and keeps it in
`doctors/{doctorUid}/patients/{uid}.seq`. Links made before numbers existed get
theirs the first time the doctor's patients are listed.

A number that is not the calling doctor's answers **404**, the same as a patient
that does not exist. No token: 401. A patient or caregiver token on a doctor
route: 403. Patient type codes from the app (`type1`, `type2`...) are sent as
`Type 1`, `Type 2`... as the dashboard names them.

Shapes follow `doctor_dashboard/js/data/http.js`. Times are Unix seconds.

## Create a doctor and try the API

Create the doctor, link a patient, get a token (each prompts for what it needs):

```
python -m scripts.make_doctor roa@example.com "Dr. Roa Daraghmeh"
python -m scripts.link_patient roa@example.com patient1@example.com
python -m scripts.get_token roa@example.com
```

`get_token` needs `FIREBASE_WEB_API_KEY` in `backend/.env`: the web `apiKey`
from `patient_interface/lib/firebase_options.dart`. In Swagger press
**Authorize** and paste the token (it lasts one hour), then try `GET /me`,
`GET /patients` and `GET /patients/1/readings` (use a number from `/patients`).

## Tests

```
python -m pytest
```

They use an in-memory stand-in for Firestore and a fake token check: nothing
touches Firebase.

## Connecting the doctor dashboard

The dashboard (`doctor_dashboard/`) talks to this API when `dataSource` is `'api'`
in `doctor_dashboard/js/config.js` (the default stays `'mock'`, its test data).
It has a sign-in page (`login.html`): the doctor signs in with the Firebase
email and password, and every request carries the ID token.

1. Start this server (`uvicorn app.main:app --reload`).
2. In `doctor_dashboard/js/config.js` set `dataSource: 'api'`.
3. Open the dashboard with Live Server (port 5500 is allowed in `CORS_ORIGINS`;
   another address must be added there).
4. Sign in as the doctor made with `scripts/make_doctor`.

What works: sign-in and sign-out, the doctor's patients, their readings and the
status and alerts the dashboard calculates from them. What does not exist yet,
so it fails or stays empty: consultations, prescriptions, instructions, chat,
reviewing alerts, reports, reminders, link codes (`link_patient` is used
instead), and saving the doctor's profile (it stays in the browser).
