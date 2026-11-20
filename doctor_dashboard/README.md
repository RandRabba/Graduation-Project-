# DMS — Doctor Dashboard (static frontend)

The Doctor Dashboard of the Diabetes Management System as plain **HTML, CSS and JavaScript**.
No PHP and no build step. It runs on local test data and is ready to be connected to a FastAPI backend later.
The Patient Interface is not part of this project.

## Run it

1. Open this `doctor_dashboard` folder in VS Code.
2. Right-click `index.html`, then **Open with Live Server**.

Any static web server works. Opening the files directly from disk (`file://`) does not: browsers block
JavaScript modules there, and the page says so.

Tests (Node 18 or later, nothing to install):

```
npm test
```

## Pages

| Page | File | Script |
|---|---|---|
| Home: four counts; patient list with tabs All Patients (always the default) / Critical / Controlled / Normal, Sort By Name / Reading / Time / Date (latest reading), and name search (`?sort=&q=`); rows tinted by status | `index.html` | `js/pages/home.js` |
| Patients: directory of linked patients, consultation state | `patients.html` | `js/pages/patients.js` |
| Patient file (`?id=`): Overview, Glucose Monitoring, Nutrition, Medications, Consultations, Reports, Communication; alert review with `&alert=` | `patient.html` | `js/pages/patient.js` |
| Consultation form (`?id=`): initial face-to-face consultation, follow-ups, the only place treatment changes | `consultation.html` | `js/pages/consultation.js` |
| Statistics: All Patients overview; patient search (name or ID) opens one patient (`?p=id`); `&r=7d\|14d\|30d` or `&from=&to=` | `statistics.html` | `js/pages/statistics.js` |
| Monitoring (from the patient file, not in the sidebar): glucose with meals, doses, consultations; daily trend panels; patterns (`?p=&r=24h…&src=&day=`) | `glucose.html` | `js/pages/glucose.js` |
| Nutrition (from the patient file, not in the sidebar): carbohydrate/calorie trends, meal impact, meal log | `meals.html` | `js/pages/meals.js` |
| Reports, report detail with print / PDF (`?p=&r=`) | `reports.html` | `js/pages/reports.js` |
| Chat | `chat.html` | `js/pages/chat.js` |
| Reminders (medication reminders come from prescriptions) | `reminders.html` | `js/pages/reminders.js` |
| Notifications (critical medical alerts shown apart); `alerts.html` redirects here | `notifications.html` | `js/pages/notifications.js` |
| Profile | `profile.html` | `js/pages/profile.js` |

## Structure

```
js/
├── config.js              data source (mock / api), API URL, Test Mode on/off
├── core/                  pure logic, no DOM, unit-tested
│   ├── clinical.js        classification, TIR, status, alerts (one per episode), reports
│   ├── protocols.js       Type 1 / Type 2 monitoring protocols (DRAFT defaults, need clinical approval)
│   ├── medications.js     prescriptions rebuilt from consultations, doses, adherence, Patient App sync payload
│   ├── analytics.js       daily/weekly series, 24-hour profile, meal impact, patterns, intervention flags
│   ├── notify.js          notifications of every kind with stable ids
│   ├── record.js          consultation vocabulary (labs, conditions, visit kinds), BMI
│   └── i18n.js, theme.js, storage.js, time.js, dom.js
├── data/
│   ├── api.js             the only data module pages use (enrichment is the same for mock and API data)
│   ├── http.js            FastAPI client + the list of expected endpoints and data shapes
│   └── mock/                 TEST DATA ONLY: demo-patients.js (default demo: Sobhi, Soso, Fofo),
│                             sample-data.js (detailed single-patient scenarios for development and tests)
├── ui/                    layout, components, charts.js, clinical-ui.js (shared clinical pieces)
└── pages/                 one script per page
```

## Clinical rules in the frontend

- **Statistics** (`core/analytics.js`): the four status cards are the current population and ignore the date range;
  unclassified patients are listed separately. The glucose trend averages each patient's mean first (days without
  readings stay empty). Mean TIR per status group only uses patients with sensor data on at least 70% of the
  period's days, with their own targets; otherwise "Insufficient data". Insights compare with the previous period of
  the same length and appear only when the data supports them.
- **Status is always calculated** from the readings (last 14 days) unless the backend sends one, and the page
  says which ("Calculated from readings · last 14 days"). Test Mode never sets a status by hand.
- **Treatment changes only in a consultation.** Each consultation holds medication actions
  (start / change / stop / continue, each with a reason); prescriptions are rebuilt from them, so every
  version keeps its consultation, reason and the version it replaced. Records are not edited afterwards.
- **Awaiting initial consultation** until the first (face-to-face) consultation is documented: the type is
  self-reported, default targets apply, no treatment.
- **Diabetes type matters**: the consultation sets the type, the protocol and optional individual targets.
  Protocols in `core/protocols.js` are drafts (`reviewed: false`) and the UI says so until approved.
- **Monitoring never changes treatment.** Patterns and flags are labelled as associations for clinical review.
- Glucose alerts are one per episode of consecutive abnormal sensor readings, not one per reading.

## Test data and Test Mode

- Three fictional test patients (`js/data/mock/demo-patients.js`, ids 1–3):
  **Sobhi** (صبحي, Critical) — his complete original record from `sample-data.js` (scenario `all`), unchanged:
  3 weeks of readings and meals, 4 consultations, prescriptions and doses, instructions, messages, requests,
  reminders and 2 health reports. **Soso** (سوسو, Normal) and **Fofo** (فوفو, Controlled) — kept minimal: 16 days of
  hourly sensor readings, meals on the last 3 days, awaiting their initial consultation (so no prescriptions yet).
  Test data is loaded only when `dataSource: 'mock'` and `testMode: true` in `js/config.js`. Real (API) data never mixes with it.
- No status is set by hand: statuses, alerts, notifications and reports are calculated from the data with the
  normal rules, and the unit tests check the result (and that Sobhi is identical to the original record).
- Reports follow the generation rule: the first one 14 days after the first reading, then weekly. Sobhi has 2
  (first + weekly), Soso and Fofo 1 each (their data starts 16 days ago).
- Notifications are generated normally (Sobhi's history produces about 40). The demo also carries the review
  state, like the backend will (`demoReviewed`): everything is already reviewed except 2 open items, Sobhi's latest
  critical glucose alert and his urgent appointment request. Anything the doctor does in the session creates new,
  unreviewed notifications as usual.
- The interface has no scenario selector or warning banner; a small **Demo** tag in the top bar shows that
  test data is loaded (hover it for details).
- For development, `?demo=` on any page URL switches to a detailed single-patient scenario of
  `sample-data.js` (Sobhi only, 3 weeks, used by the unit tests): `all` (Normal → Controlled → Critical),
  `ok`, `ctrl`, `crit` or `new`; `?demo=demo` returns to the three demo patients. The choice lasts for the tab's session.
- What you do with sample data (consultations, reviews, messages, reminders) lasts for the browser tab's
  session; switching the scenario clears it. Language, appearance and the profile stay in `localStorage`.

## Arabic and right-to-left

- Arabic sets `dir="rtl"` on the page (`boot.js`); layout uses logical CSS properties, so the sidebar, cards,
  tables, forms and drawers mirror automatically. Charts keep time running left to right in both languages.
- Mixed text is handled in one place, `core/i18n.js`: in Arabic, `t()` and `ldate()` isolate numbers, units,
  abbreviations and English names ("318 mg/dL", "HbA1c", "70–180") so they never reorder, and dates use
  Arabic order ("7 نوفمبر 2026"). Use `iso()` for pieces built outside `t()` (e.g. a drug name and its dose),
  `.qty` for a number followed by its unit, and `auto()` (components) for text typed by people.
- Do not put `dir="auto"` on text produced by `t()`/`ldate()`: automatic direction ignores isolated text.
- Status terms: Normal = طبيعي, Controlled = تحت المراقبة (above target, not critical), Critical = حرج.

## Not functional yet (needs the FastAPI backend)

- Secure sign-in and secure doctor–patient linking after registration in the Patient App.
- Synchronizing prescriptions, medication reminders, instructions and messages with the Patient App
  (the payload is prepared: `syncPayload()` in `core/medications.js`, shown as "Sync pending").
- Receiving real readings, meals, dose logs and consultation requests from the Patient App.
- Storing consultations and the doctor's actions anywhere except the current browser tab.
- Clinically approved protocols (`GET /protocols`); the bundled ones are drafts.
- None of the dashboard's patterns or flags is clinical decision support; they summarize recorded data.

## Connecting FastAPI later

1. Implement the endpoints listed at the top of `js/data/http.js` (same shapes as the mock data, Unix seconds).
2. In `js/config.js`, set `dataSource: 'api'` and `apiBaseUrl`.

Pages don't change: `js/data/api.js` loads from the API and applies the same enrichment.

## Tests

`npm test` runs the unit tests (clinical rules, medication history, protocols, analytics, notifications and
the consistency of every Test Mode scenario).
