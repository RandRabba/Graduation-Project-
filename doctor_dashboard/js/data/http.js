// HTTP client for the FastAPI backend (used only when CONFIG.dataSource === 'api').
// Every request carries the signed-in doctor's Firebase ID token (js/data/auth.js). Without one the browser goes to
// login.html; a 401 answer signs the doctor out and goes there too.
//
// WHAT THE BACKEND ANSWERS TODAY (backend/README.md): GET /doctor, GET /patients (patient ids are small whole numbers,
// one sequence per doctor), GET /patients/{id}/readings, the link codes (POST / GET / DELETE /doctor/link-codes), and an
// empty list for meals, consultations, doses, requests, instructions, chat and /reminders. Everything else below is NOT
// implemented yet: the doctor's actions (consultations, instructions, chat, reviewing alerts, reports, reminders) and
// /protocols. Those requests fail, and nothing is synchronized with the Patient App until they exist.
// These are the endpoints the frontend expects; every response uses the same data shapes
// as the mock data (js/data/mock/sample-data.js). Timestamps are Unix seconds.
//
//   GET    /doctor                                  doctor profile          PUT /doctor
//   POST   /doctor/link-codes                       body {label} → {id, label, code, at, st: 'pending', usedAt: null}
//          (the backend generates a unique single-use code for one patient, no expiry, and stores it; the answer is 201,
//           id is the code itself, and a doctor may hold at most 50 unused codes: more answers 409)
//   GET    /doctor/link-codes                       [{id, label, code, at, st: 'pending'|'used', usedAt}]
//   DELETE /doctor/link-codes/{id}                  cancel a pending (unused) code → 204 (404 unknown, 409 already used)
//          Redeeming is NOT a dashboard endpoint: the Patient App calls POST /link-codes/redeem with the patient's own
//          token; the backend binds the code to that patient account, marks it used and links the patient to the doctor.
//   GET    /patients                                { id: {name, age, sex, reportedType, linkedAt, cg?, status?} }
//          (only patients securely linked to this doctor after registration; status is optional and,
//           when sent, must be calculated by the backend's clinical rules)
//   GET    /patients/{id}/readings                  [{id, v, at, src: 'cgm'|'manual', type: 'FBS'|'RBS'|'PPBS', st?}]
//   GET    /patients/{id}/meals                     [{id, name, type, carbs, kcal, protein, fat, items, at, before, after, imp?}]
//   GET    /patients/{id}/consultations             [consultation]   POST same path (new consultation)
//          consultation: {id, at, kind: 'initial'|'follow_up'|'urgent', mode: 'in_person'|'phone'|'video',
//            complaint, history, exam: {weight, height, sys, dia, hr, notes}, dx: {type, since, conditions[], notes},
//            labs: [{test, v, at}], protocol, targets: {low, high, tir, tbr}|null,
//            meds: [{act: 'start'|'change'|'stop'|'continue', rx, drug, dose, unit, route, freq, timing[], days, notes, reason}],
//            plan, followUp: {at, notes}, notes}
//          The backend derives prescriptions from consultations (see core/medications.js deriveRegimen)
//   POST   /patients/{id}/prescriptions/sync        body: syncPayload() from core/medications.js → Patient App
//   GET    /patients/{id}/doses                     [{rx, ver, at, slot, taken}]   dose log from the Patient App
//   GET    /patients/{id}/requests                  [{id, at, kind: 'initial'|'follow_up'|'urgent', urgent, note}]
//   GET    /patients/{id}/alerts                    [{id, st, v, at}]   (optional: derived from readings if missing)
//   POST   /patients/{id}/notifications/{nid}/ack
//   GET    /patients/{id}/instructions              [[text, at]]         POST same path {text}
//   GET    /patients/{id}/chat                      [[who, text, at]]    POST same path {text}
//   GET    /reminders                               [{id, pid, type, title, at, rep, src, st}]
//   POST   /reminders                               DELETE /reminders/{id}
//   POST   /patients/{id}/reports/{rid}/seen
//   GET    /protocols                               clinically approved protocols (replaces core/protocols.js defaults)
import { CONFIG } from '../config.js';
import { getIdToken, signOut, redirectToLogin } from './auth.js';

async function request(method, path, body) {
  const token = await getIdToken();
  if (!token) return redirectToLogin();
  const headers = { Authorization: `Bearer ${token}` };
  if (body) headers['Content-Type'] = 'application/json';
  const res = await fetch(CONFIG.apiBaseUrl + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  if (res.status === 401) { signOut(); return redirectToLogin(); }
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status}`);
  return res.status === 204 ? null : res.json();
}
export const http = {
  get: p => request('GET', p),
  post: (p, b = {}) => request('POST', p, b),
  put: (p, b = {}) => request('PUT', p, b),
  del: p => request('DELETE', p),
};

// Raw dataset in the same shape as buildSampleData(), loaded from the API
export async function loadFromApi() {
  const [doctor, patients] = await Promise.all([http.get('/doctor'), http.get('/patients')]);
  const ids = Object.keys(patients);
  const per = async path => Object.fromEntries(await Promise.all(ids.map(async id => [id, await http.get(`/patients/${id}/${path}`)])));
  const [readings, meals, consultations, doses, requests, ins, chat, reminders] = await Promise.all([
    per('readings'), per('meals'), per('consultations'), per('doses'), per('requests'), per('instructions'), per('chat'), http.get('/reminders')]);
  return { doctor, patients, readings, meals, consultations, doses, requests, ins, chat, reminders };
}
