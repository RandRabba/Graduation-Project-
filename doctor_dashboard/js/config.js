// App configuration. The only file to change when the FastAPI backend is ready.
//
// dataSource:
//   'mock' — local test data (js/data/mock/sample-data.js). No server needed; works with Live Server.
//   'api'  — the FastAPI backend at apiBaseUrl (see js/data/http.js for the expected endpoints).
// testMode: loads the test patients (Sobhi, Soso, Fofo) from js/data/mock/demo-patients.js, kept apart from real data.
//   Nothing in the interface is labelled as test data. Must be false in production (real data from the backend).
export const CONFIG = {
  dataSource: 'mock',
  apiBaseUrl: 'http://127.0.0.1:8000/api',
  testMode: true,
  defaultLang: 'en',
  doctorName: 'Dr. Roa Daraghmeh',
};
