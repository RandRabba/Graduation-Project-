// HTTP client for the future FastAPI backend (used only when CONFIG.dataSource === 'api').
// THE BACKEND IS NOT IMPLEMENTED YET. Nothing is synchronized with the Patient App and there is no secure
// sign-in until it is. These are the endpoints the frontend expects; every response uses the same data shapes
// as the mock data (js/data/mock/sample-data.js). Timestamps are Unix seconds.
//
//   GET    /doctor                                  doctor profile          PUT /doctor
//   POST   /doctor/link-codes                       body {label} → {id, label, code, at, st: 'pending', usedAt: null}
//          (the backend generates a unique single-use code for one patient, no expiry, and stores it)
//   GET    /doctor/link-codes                       [{id, label, code, at, st: 'pending'|'used', usedAt}]
//   DELETE /doctor/link-codes/{id}                  cancel a pending (unused) code
//          Redeeming is NOT a dashboard endpoint: the Patient App's endpoint binds the code to that patient
//          account and marks it used.
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

async function request(method, path, body) {
  const res = await fetch(CONFIG.apiBaseUrl + path, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
    credentials: 'include',
  });
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
  const patients = await http.get('/patients');
  const ids = Object.keys(patients);
  const per = async path => Object.fromEntries(await Promise.all(ids.map(async id => [id, await http.get(`/patients/${id}/${path}`)])));
  const [readings, meals, consultations, doses, requests, ins, chat, reminders] = await Promise.all([
    per('readings'), per('meals'), per('consultations'), per('doses'), per('requests'), per('instructions'), per('chat'), http.get('/reminders')]);
  return { patients, readings, meals, consultations, doses, requests, ins, chat, reminders };
}
