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
| `GET /patients` | `{patientUid: {name, age, sex, reportedType, linkedAt}}` |
| `GET /patients/{uid}/readings?limit=500&since=<unix s>` | `[{id, v, at, src: cgm\|manual, type: FBS\|RBS\|PPBS}]`, newest first |
| `GET /patients/{uid}/{meals,consultations,doses,requests,instructions,chat}` and `GET /reminders` | `[]` for now: not stored anywhere yet, but the dashboard asks for them on load |

A patient who is not linked to the calling doctor answers **404**, the same as
a patient that does not exist. No token: 401. A patient or caregiver token on a
doctor route: 403.

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
`GET /patients` and `GET /patients/{uid}/readings`.

## Tests

```
python -m pytest
```

They use an in-memory stand-in for Firestore and a fake token check: nothing
touches Firebase.

## Connecting the doctor dashboard (not done yet)

1. `CONFIG.apiBaseUrl` in `doctor_dashboard/js/config.js`: `/api` -> `/api/v1`.
2. Sign the doctor in with the Firebase web SDK and send the ID token as
   `Authorization: Bearer ...` (`js/data/http.js` sends cookies today).
3. Patient ids are Firebase uids (text), not numbers: `Number(key)` in
   `enrich()` in `js/data/api.js` must go.
4. Serve the dashboard from an address listed in `CORS_ORIGINS` (Live Server on
   port 5500 is already allowed).
