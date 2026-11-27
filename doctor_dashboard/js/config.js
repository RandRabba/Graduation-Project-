// App configuration. The only file to change when the FastAPI backend is ready.
//
// dataSource:
//   'mock' — local test data (js/data/mock/sample-data.js). No server needed; works with Live Server.
//   'api'  — the FastAPI backend at apiBaseUrl (see js/data/http.js for the expected endpoints). The doctor signs in
//            on login.html (Firebase email + password, js/data/auth.js).
// testMode: loads the test patients (Sobhi, Soso, Fofo) from js/data/mock/demo-patients.js, kept apart from real data.
//   Nothing in the interface is labelled as test data. Must be false in production (real data from the backend).
export const CONFIG = {
  dataSource: 'mock',
  apiBaseUrl: 'http://127.0.0.1:8000/api/v1',
  // Web API key of the Firebase project (the same public key as the web app in patient_interface/lib/firebase_options.dart).
  // It only identifies the project for sign-in; it is not a secret.
  firebaseApiKey: 'AIzaSyBjUiltlltjutYGl_RydKn9ro001kVsao0',
  testMode: true,
  defaultLang: 'en',
  doctorName: 'Dr. Roa Daraghmeh',
};
