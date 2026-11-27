# DMS - Firebase backend (shared by all three apps)

One Firebase project serves the patient app, the caregiver app and the doctor
website. There is no server of our own: **Firebase Auth** identifies people and
**Firestore** stores the data. `firestore.rules` is the permission system, so
it is the one file to review whenever "who can see what" changes. Changing how
a screen looks never touches it.

## One-time setup

1. Firebase console, project of the new account:
   - Authentication > Sign-in method > enable **Email/Password**.
   - Firestore Database > **Create database** (production mode, pick a region
     close to you; it cannot be changed later).
2. In this folder:
   ```
   npm install -g firebase-tools
   firebase login
   firebase use --add          # choose the project
   firebase deploy --only firestore
   ```
   The deploy checks the rules syntax and publishes them with the indexes.
3. In each Flutter app folder (once per app):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure       # choose the project, tick the platforms you run
   flutter pub add firebase_core firebase_auth cloud_firestore
   ```
   `flutterfire configure` writes `lib/firebase_options.dart`. It holds public
   app identifiers, not secrets.

## Data model

Field names are camelCase. Times are Firestore timestamps.

| Path | Written by | Fields |
|---|---|---|
| `users/{uid}` | the account owner | `role` (`patient` or `caregiver`; `doctor` is added by hand), `email` (lower case), `fullName`, `phone`, `dateOfBirth`, `diabetesType`, `doctorId`, `createdAt` |
| `links/{caregiverEmail}` | the patient | `patientUid`, `caregiverEmail`, `status` (`pending` until the caregiver registers, then `active`), `shareGlucose`, `createdAt`, `caregiverUid`, `claimedAt` |
| `patients/{uid}/readings/{id}` | the patient | `value` (mg/dL), `at` (timestamp of the measurement), `source` (`manual`, `dexcom`, ...), `sensor`, `note`, `timing` (`fasting`, `before_meal`, `after_meal`, `random`), `createdAt`. The id is `<source>-<unix seconds>`, so the same reading cannot be stored twice |
| `patients/{uid}/reminders/{id}` | the patient | as the patient app's `Reminder` (`assignedBy` marks doctor reminders) |
| `patients/{uid}/alerts/{id}` | the patient | the patient's own notification history |
| `caregiverNotifications/{id}` | the patient app, one per caregiver | `patientUid`, `caregiverEmail`, `kind`, `glucose`, `message`, `createdAt`, `read` (the caregiver can only change `read`) |

The id of a `links` document is the caregiver's **lower-case email**.

### Caregiver onboarding, as the rules enforce it

1. The patient adds an email: the app creates `links/{email}` with `status: pending`.
2. The caregiver registers with that email and a password (Firebase Auth). The
   app creates `users/{uid}` with `role: caregiver`. The rules refuse this if no
   link exists for the email, and the app then removes the new account.
3. The app sets the link to `active` and stores the caregiver's uid. There is
   no accept step and no email verification.
4. Either side can end the link by deleting it (the patient removes the
   caregiver, or the caregiver taps Disconnect). Access ends immediately.

What a linked caregiver can read: the patient's profile, reminders, and, only
when `shareGlucose` is true, readings. They get their own notifications from
`caregiverNotifications`. They can write nothing but `read` on those.

## Patient app (real flow)

The patient app signs up with Firebase Auth and creates `users/{uid}` with
`role: patient`. "Add caregiver" writes `links/{caregiverEmail}` (status
`pending`, `shareGlucose` true), and "Remove caregiver" deletes it. The SOS
button adds a `caregiverNotifications` document (`kind: sos`). Run it with
the same Firebase project: copy `lib/firebase_options.dart` from the caregiver
app, or run `flutterfire configure` in the patient app.

Glucose readings (manual entries) are written to `patients/{uid}/readings`.
The caregiver app listens to the newest 500 of them while `shareGlucose` is
true and builds the latest reading, the history, the chart and the summary
from them. Alerts, reminders and reports are not connected yet.

A caregiver email and a patient email must be different accounts: one email is
one Firebase account.

## Try the caregiver app before the patient app is connected

Create these in the Firestore console (console writes ignore the rules):

- `users/patient-demo` : `role` "patient", `email` "omar@example.com",
  `fullName` "Omar Haddad", `diabetesType` "Type 2"
- `links/nour@example.com` : `patientUid` "patient-demo", `caregiverEmail`
  "nour@example.com", `status` "pending", `shareGlucose` false (boolean)

Then register `nour@example.com` in the caregiver app. (With the patient app
connected you do not need these documents: sign up as a patient and add the
caregiver from the app.)

## Known limits

- **No email verification** (by design): whoever registers an invited email
  first gets that caregiver's access. Adding `request.auth.token.email_verified`
  to the rules later is a one-line change.
- **Push when the app is closed** needs Cloud Functions + FCM, which need the
  Blaze plan. Until then the caregiver sees notifications live while the app
  is open.
- **Doctor website**: a PHP page cannot use these client rules. It will talk to
  Firebase through the Admin SDK on the server (which bypasses the rules), so
  its own access checks live in that PHP code.
- One caregiver email follows one patient.
- The rules could not be run against the emulator here. Check them with
  `firebase deploy --only firestore`, then try the flow above.
