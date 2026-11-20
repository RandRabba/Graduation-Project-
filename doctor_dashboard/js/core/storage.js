// Browser storage, replacing the PHP session and cookies. Every access is wrapped so the app still works
// when storage is blocked (private mode, strict settings); values then just don't persist.
//
// localStorage (kept after closing the browser): language, appearance, doctor profile and preferences.
// sessionStorage (this browser tab only): Test Mode scenario and what the doctor does on test data
// (reviewed alerts, opened reports, sent messages/instructions, added/deleted reminders).
// Like the PHP version, the dashboard opens on "All" again in a new session, and changing the scenario
// clears that session state so every page matches the new scenario.

function read(area, key, fallback) {
  try { const v = area.getItem(key); return v === null ? fallback : JSON.parse(v); } catch (e) { return fallback; }
}
function write(area, key, value) {
  try { value === undefined ? area.removeItem(key) : area.setItem(key, JSON.stringify(value)); } catch (e) { /* storage unavailable */ }
}
const L = () => { try { return localStorage; } catch (e) { return null; } };
const S = () => { try { return sessionStorage; } catch (e) { return null; } };

export const local = {
  get: (k, f = null) => (L() ? read(L(), k, f) : f),
  set: (k, v) => L() && write(L(), k, v),
  // raw strings (dms-lang / dms-theme are read as plain strings by boot.js)
  getRaw: k => { try { return localStorage.getItem(k); } catch (e) { return null; } },
  setRaw: (k, v) => { try { localStorage.setItem(k, v); } catch (e) { /* ignore */ } },
};
export const session = {
  get: (k, f = null) => (S() ? read(S(), k, f) : f),
  set: (k, v) => S() && write(S(), k, v),
};

// ===== Test Mode scenario =====
// demo (default): the three demo patients (data/mock/demo-patients.js). The others are the detailed single-patient
// scenarios of data/mock/sample-data.js (Sobhi only), kept for development and the unit tests.
export const TEST_STATES = ['demo', 'all', 'ok', 'ctrl', 'crit', 'new'];
export function getScenario() {
  const v = session.get('dms-test-scn', 'demo');
  return TEST_STATES.includes(v) ? v : 'demo';
}
export function setScenario(v) {
  if (!TEST_STATES.includes(v)) return;
  if (v !== getScenario()) session.set('dms-state', undefined);
  session.set('dms-test-scn', v);
}

// ===== Doctor actions on the data (until the backend stores them) =====
// { ack: {pid: {alertId: ts}}, repSeen: {pid: {reportId: ts}}, chat: {pid: [[who,text,ts]]},
//   ins: {pid: [[text,ts]]}, rem: [reminder], remdel: [id], cons: {pid: [consultation]} }
// ack holds every reviewed notification (glucose alerts and the other kinds) by its id
export function state() {
  return Object.assign({ ack: {}, repSeen: {}, chat: {}, ins: {}, rem: [], remdel: [], cons: {} }, session.get('dms-state', {}));
}
export function updateState(fn) { const s = state(); fn(s); session.set('dms-state', s); return s; }

// One-time message shown after a redirect (like the PHP flash), stored as a translation key
export function setFlash(key) { session.set('dms-flash', key); }
export function takeFlash() { const k = session.get('dms-flash', ''); session.set('dms-flash', undefined); return k; }
