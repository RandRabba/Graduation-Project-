# Caregiver Module (Flutter)

Caregiver mobile interface for the **Diabetes Monitoring and Meal Analysis System**.
It is a Flutter port of the Caregiver prototype, built as a **self-contained module**
so it can run on its own now and be pushed from the existing Patient app later.
The Patient app and the Doctor dashboard are not touched.

- Flutter widgets and Dart only (Material 3), no external state-management package
- Read-only by design: no add, edit or delete of readings, meals, reminders or medications
- One fixed set of read-only screens (no Basic / Extended UI, see "What the caregiver sees")
- Looks like the Patient app: same floating tab bar, page headers, hero card, pill tabs and grouped
  list rows (see "Patient-style UI")
- Light and dark mode, **identical to the Patient app** (same palette, text sizes, shapes and
  System / Light / Dark choice, see "Theme" below)
- English (LTR) and Arabic (RTL)
- Realistic mock data behind a repository interface

## Verification status (please read)

This code was written **without access to a Flutter or Dart SDK**, so it has **not been
compiled or run**. What was checked instead, with small Python scripts:

- Brackets are balanced in every Dart file.
- Every relative import resolves, and every project symbol a file uses is imported there
  (heuristic), with no obviously unused project imports.
- Every `.dart` file parses as valid Dart (tree-sitter syntax check, no errors).
- Every palette token used (`pal.xxx`) exists in `AppPalette`.
- Every string key used in the UI exists in **both** the English and Arabic tables (identical
  key sets).

What was *not* checked: type errors, analyzer warnings, layout overflow at runtime, and how
it looks on a device. Run `flutter analyze` first. If it reports anything, send me the output
and I will fix it. Then compare each screen with the Patient app in light and dark mode.

## Run it

Requires the same SDK as the Patient app (Dart `^3.10.7`).

The folder already has its platform folders (`web/`, `android/`, ...), so from inside it:

```bash
flutter pub get
flutter analyze
flutter run -d chrome                           # the app as a user sees it
flutter run -d chrome --dart-define=DEMO=true   # with the prototype controls and demo sign-in
```

On a wide window (Chrome on a laptop) the app is drawn as a centred phone-sized column, at most
480 px wide (`widgets/phone_frame.dart`). On a phone it uses the full width.

`url_launcher` was added to `pubspec.yaml` (the emergency contact's call button opens the
dialer), so run `flutter pub get` once after copying this folder.

### With Firebase (real sign in)

The demo above is the default and needs nothing. To use the real backend instead:

```bash
# once: Firebase project setup, rules and the data model are in ../firebase/README.md
dart pub global activate flutterfire_cli
flutterfire configure            # overwrites lib/firebase_options.dart (a placeholder until then)
flutter pub get                  # if it cannot solve the Firebase versions: flutter pub add firebase_core firebase_auth cloud_firestore

flutter run -d chrome --dart-define=BACKEND=firebase
```

What works in this mode: registration (only for an email a patient added, checked by the
Firestore rules), sign in, sign out, password change and reset by email, the linked patient's
name and diabetes type, "Disconnect", and the loading / error / "no linked patient" states.
Readings, notifications, reminders and reports are **not connected yet**: they show their empty
states, not invented numbers. To try it before the patient app writes links, see "Try the
caregiver app before the patient app is connected" in `../firebase/README.md`.

## Theme

The Caregiver theme is the Patient app's theme, so the two apps look the same in light and dark:

- `theme/app_palette.dart` holds the **same hex values** as `patient_interface/lib/theme.dart`
  (`AppPalette.light` / `AppPalette.dark`). The short caregiver token names (`pri`, `sub`, `line`,
  ...) are kept, and the table at the top of that file maps each one to its Patient name.
  **If the Patient palette changes, change the same lines here.**
- The dark palette is the Patient app's **Graphite & Periwinkle** (charcoal surfaces, soft
  periwinkle accent), copied from its latest `theme.dart`. The check that compares all 21 colours
  in light and dark, plus the `ThemeData`, against `patient_interface/lib/theme.dart` reports no
  differences.
- `theme/app_theme.dart` mirrors the Patient app's `buildTheme`: colour scheme, text sizes and
  weights, app bar, bottom sheet, dialog, snack bar, text button, input and progress themes.
- No custom font. Like the Patient app, the system font is used (the `google_fonts` package and
  its Plus Jakarta Sans / IBM Plex Sans Arabic fonts were removed), so the app also works offline
  and needs no `INTERNET` permission for fonts.
- Cards (22 px radius, hairline border, soft shadow), pill buttons (gradient call-to-action),
  text fields (filled, primary focus ring) and bottom sheets (28 px top radius) follow the Patient
  app's components.
- Theme mode is **System / Light / Dark** and defaults to System, like the Patient app
  (`CaregiverController.themeMode`, `setThemeMode`). Profile > Appearance opens the picker.
- Status colours follow the Patient app's glucose levels: in range = `normal`, high = `caution`,
  low = `elevated`, critical = `critical`. Critical notifications stay red in both apps' palettes.
- `AppPalette.alertRed` is a fixed solid red (the Patient app's light-mode `critical`) used for
  badges and solid emergency fills with white text, in both modes, so white text keeps its contrast.

### Using the demo

How a caregiver gets in (this is the real flow, only the backend is mocked):

1. The patient adds the caregiver in the Patient app with the caregiver's **email only**.
2. The caregiver opens the Caregiver app and taps **Create account** on the login screen.
3. They enter that same email, a password and the password again, and go **straight into the app**.
   There is no email verification and no invitation to accept. If the email was not added by a
   patient, registration says so.
4. Next time they use the same login screen. The backend decides the role after login; a
   PATIENT account is handed to the Patient dashboard.

Demo mode is **off by default**, so the app looks final. Turn it on with
`--dart-define=DEMO=true` (see "Run it"). Without it, registration only accepts the mock invited
email `nour.haddad@example.com`; any non-empty email and password sign in.

In demo mode the email is pre-filled and the login fields are pre-filled too. The small round
button at the bottom corner (demo mode only) opens
**Prototype controls**: theme (System / Light / Dark), language, data state (loading, old
reading, no reading, no notifications, error, access revoked, no linked patient) and the role returned
after login. Language and Appearance are also real settings under **Profile**.

## UI details

- **Hero card:** the latest reading, its classification and when it was recorded come first; the
  patient's overall status ("Patient status") is a separate labelled row at the bottom, so the
  two are not mixed up. The classification of a reading comes with the data (it is not computed
  in the app); the mock latest reading is 196 mg/dL, which is above the 70-180 target range.
- **Glucose chart:** mg/dL scale (70 / 120 / 180 / 240 / 300), light grid, the 70-180 target band,
  and tapping a point shows its value and label (time or day). A line under the title says what
  one point stands for in the selected range.
- **Notifications:** each card has a soft tint and a coloured bar on its leading edge by severity
  (critical = red, warning = orange), a "New" label next to the dot, and no heavy outline.
- **Emergency contact:** second in Quick access, with a round call button that dials at once
  (`tel:` link through `url_launcher`; a host app can still pass `onCall`).
- **Sign-in:** password fields have a show/hide button.
- **Readings:** "Reset filters" appears when a type or source filter is on.

## Project layout

```
lib/
  main.dart                      Standalone entry point (DEMO flag turns the prototype controls on)
  caregiver/
    caregiver.dart               Public API barrel (import this from the host app)
    caregiver_module.dart        CaregiverModule: MaterialApp, theme, locale, RTL, navigation
    theme/                       app_palette.dart (colour tokens, light/dark), app_theme.dart, text_styles.dart
    l10n/app_strings.dart        English and Arabic string tables
    models/models.dart           Plain Dart domain models and enums
    services/                    caregiver_repository.dart (interface), mock_caregiver_repository.dart
    state/                       caregiver_controller.dart (ChangeNotifier), caregiver_scope.dart (InheritedNotifier)
    utils/formatters.dart        Dates, "x min ago", glucose class labels, fixed mock clock
    widgets/                     Reusable widgets (cards, chips, buttons, chart, sheets, toast, ...);
                                 patient_style.dart = widgets mirroring the Patient app's common.dart
    shell/                       caregiver_shell.dart (4 tabs, nested navigators), bottom_nav.dart (floating bar)
    screens/
      auth/                      Login, Register, session_routes.dart (open dashboard, log out, patient-role stub)
      home/                      Home (hero, latest notifications, quick access, time in range, curve)
      readings/                  Readings (range tabs, chart, filters, history)
      alerts/                    Notifications list, Notification details
      reports/                   Health reports list, Report details
      reminders/                 Reminders
      patient/                   Patient information, Doctor instructions
      profile/                   Profile, Change password, Notification preferences, Privacy, Help
```

## Screens

| Requirement | File |
| --- | --- |
| Login | `screens/auth/login_screen.dart` |
| Registration (invited email + password + confirm, then straight in) | `screens/auth/register_screen.dart` |
| Home dashboard | `screens/home/home_screen.dart` |
| Glucose monitoring | `screens/readings/readings_screen.dart` |
| Notifications | `screens/alerts/alerts_screen.dart` |
| Notification details | `screens/alerts/alert_detail_screen.dart` |
| Health reports | `screens/reports/reports_screen.dart`, `report_detail_screen.dart` |
| Reminders | `screens/reminders/reminders_screen.dart` |
| Patient information | `screens/patient/patient_info_screen.dart` |
| Doctor instructions | `screens/patient/instructions_screen.dart` |
| Caregiver profile | `screens/profile/profile_screen.dart` |
| Settings | Profile screen, plus `change_password_screen.dart`, `notification_prefs_screen.dart`, `privacy_screen.dart`, `help_screen.dart` |

> **Naming:** the interface says "Notifications" everywhere (English and Arabic). Code identifiers
> (`alerts/`, `CaregiverAlert`, `AlertCard`, `a_*` string keys) still use "alert" so they match the
> backend naming; rename them together with the API if you want them to agree.

Navigation: bottom bar (Home, Readings, Notifications, Profile) with an unread badge on Notifications.
Each tab keeps its own back stack, so the bar stays visible on sub screens. Android back
closes a sub screen, then returns to Home, then leaves the module.

## Patient-style UI

The screens follow the Patient app's layout. `widgets/patient_style.dart` re-creates the Patient
app's `common.dart` pieces (the packages are separate, so they cannot be imported):

| Patient app | Caregiver app |
| --- | --- |
| floating rounded `_NavBar` | `shell/bottom_nav.dart` |
| `PageHeader` | `PageHeader` |
| hero card on Summary | `widgets/latest_reading_hero.dart` (latest reading, white "View readings" button) |
| `SettingsGroup` / `SettingsTile` ("Quick access", settings) | same names |
| `PillTabs` (range) | `PillTabs` |
| time in range bar + stat tiles | `TimeInRangeBar`, `RangeLegend`, `StatTile` |
| `SubPage` (app bar + list) | `SubPage` (all pushed screens) |
| `StatusPill`, `IconCircle`, `EmptyState` | same names |
| `Gap` | `CgGap` (renamed so both can live in one app) |

If the two apps ever share a package, delete `patient_style.dart` and import the shared widgets.

## What the caregiver sees

One fixed set of screens. Everything is read-only; there is no add, edit or delete anywhere.

| Shown | Not shown (no meaning for a caregiver) |
| --- | --- |
| Patient name, status, emergency contact (call) | Meals and meal analysis |
| Latest glucose reading, with time and a "may not be current" note, plus an old-reading warning | Sensor pairing and live sensor |
| Notifications (all), notification details, safety guidance | AI assistant and doctor chat |
| Readings history, chart, filters, HbA1c | Manual reading entry |
| Time in range, average, highest, lowest | Caregiver management (that is the patient's job) |
| Reports, reminders, doctor instructions | Editing the patient's profile |
| Diabetes type, assigned doctor | |

**Access tiers are dormant.** The earlier prototype had Basic and Extended monitoring. The
product now needs one set of screens, so the UI no longer branches on it. `AccessLevel`, the
`level` argument on `CaregiverRepository` methods and `CaregiverController.setLevel` are kept
(the controller uses `extended`) so tiers can come back without a rewrite. If they never do,
delete them. **In production the backend must still only send what the patient shares**.

Other safety decisions: opening a notification never marks it resolved; guidance on notifications is
generic and says it is not medical advice; classification pills carry an icon so colour is never
the only signal; charts and the time-in-range bar always run left to right, also in Arabic.

## Integrating into the Patient app

1. Copy the whole `lib/caregiver/` folder into the Patient app's `lib/`.
2. Add the dependencies from this `pubspec.yaml` if missing: `flutter_svg` and
   `flutter_localizations` (SDK).
3. Push the module from wherever the Patient app handles the caregiver role:

```dart
import 'caregiver/caregiver.dart' as caregiver; // alias avoids name clashes (Patient, Reminder, ...)

Navigator.of(context).push(MaterialPageRoute<void>(
  builder: (ctx) => caregiver.CaregiverModule(
    repository: ApiCaregiverRepository(session), // your FastAPI-backed implementation
    showDemoControls: false,                      // the default; shown only for demos
    startAtDashboard: true,                       // host already signed the caregiver in
    onExit: () => Navigator.of(ctx).pop(),
    onCall: (phone) => launchUrl(Uri.parse('tel:$phone')), // optional: by default the module dials itself
  ),
));
```

4. Implement `CaregiverRepository` (`services/caregiver_repository.dart`) against the FastAPI
   endpoints, and delete the use of `MockCaregiverRepository`. The interface is the only
   place the UI gets data from. Methods are synchronous in this demo; switch them to
   `Future` (and add loading handling in the controller) when you call a real API.
5. Login and registration are UI only. Register must call a backend endpoint that checks a
   pending caregiver link exists for the email (the mock checks `CaregiverRepository.invitedEmail`),
   then creates the account and signs it in. Or skip both with `startAtDashboard: true`.
6. The module has its own `MaterialApp`, so it brings its own theme and language and does not
   inherit the host's. Its theme already equals the Patient app's. If you prefer to share one
   app-wide language and theme mode, the controller's `arabic` and `themeMode` are the only things
   to bind (the Patient app keeps them in `AppSettings`).

## Deliberate differences from the prototype

- No email verification and no invitation-accept screen: the patient adds the caregiver by
  email, and the caregiver registers with that email and enters the app directly.
- A language link ("العربية" / "English") on the sign-in screens, so Arabic speakers do not
  need to log in first to change language.
- In demo mode, the login fields are pre-filled and a round demo-controls button replaces the
  prototype's side panel.
- After "Disconnect from patient", the Profile connection card shows "No linked patient"
  instead of still saying the patient is linked.
- Notification details opened from Home stay in the Home tab (the prototype switched the highlighted
  tab to Notifications).
- Dates and times come from a fixed mock clock (Fri 30 Oct 2026, 08:30) so the demo reads
  the same on any day. "x min ago" is computed from it.

## Known limitations

- Call, PDF download and support contact are placeholders (a message is shown).
- In the default demo mode authentication is a mock: any non-empty email/password signs in; no
  tokens or persistence. The registration email check is against a single mock invited address.
  Real sign in is `--dart-define=BACKEND=firebase` (see "With Firebase").
- In Firebase mode the emergency contact is empty (it is being removed, see the open design
  decisions) and the patient's status is hidden until the readings are connected.
- No SOS notification kind yet (the Patient app has an SOS action), no push notifications (the app has no
  FCM), and the data models are not yet aligned with the backend (the Patient app's
  `CaregiverLink`, alert `caregiver_notified`, ...).
- "Stale reading" is only a demo state; real staleness (reading older than a threshold) must be
  computed from the reading time.
- Meals are not shown: the Patient app keeps meals in memory with no caregiver-facing model yet.
- Settings (language, theme, notification switches, edited profile) are in memory only.
- No automated tests yet.
