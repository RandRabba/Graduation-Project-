// Data service: the only module pages use to read or change data.
// Today it reads the local mock data and keeps the doctor's actions in the browser (js/core/storage.js).
// With CONFIG.dataSource = 'api' it loads from FastAPI (js/data/http.js) and sends the actions there.
// Either way the raw data goes through the same enrichment (classification, status, treatment, flags,
// notifications), so every page shows the same numbers.
//
// NOT FUNCTIONAL YET (needs the backend): secure sign-in, synchronization with the Patient App
// (prescriptions, reminders, messages), and storing the doctor's actions anywhere but this browser tab.
import { CONFIG } from '../config.js';
import { LANG, t, iso } from '../core/i18n.js';
import { local, getScenario, setScenario, state, updateState } from '../core/storage.js';
import { DAY, now } from '../core/time.js';
import { targets, cleanReadings, overallStatus, autoReports, reminderStatus, deriveAlerts, overviewStats, impactOf, STATUSES } from '../core/clinical.js';
import { deriveRegimen, treatmentKind, TIMING } from '../core/medications.js';
import { PROTOCOLS, protocolOf, effectiveTargets, defaultProtocolId } from '../core/protocols.js';
import { interventionFlags } from '../core/analytics.js';
import { buildNotifications } from '../core/notify.js';
import { buildSampleData } from './mock/sample-data.js';
import { buildDemoData, demoReviewed } from './mock/demo-patients.js';
import { http, loadFromApi } from './http.js';
import { makeLinkCode, LINK_CODE_RE } from '../core/linkcode.js';

const MOCK = CONFIG.dataSource !== 'api';
export const TEST_ON = MOCK && CONFIG.testMode;
// True when the data comes from the FastAPI backend and the doctor signs in (js/data/auth.js)
export const API_MODE = !MOCK;
// Shown next to anything the Patient App will receive once the backend exists
export const SYNC_READY = false;

// Test data (internal, for development and testing only). Default: the three demo patients Sobhi, Soso and Fofo
// (data/mock/demo-patients.js). ?demo=all|ok|ctrl|crit|new on any page switches to one of the detailed single-patient
// scenarios (data/mock/sample-data.js); ?demo=demo switches back.
// There is no visible selector; the interface shows only a small "Demo" indicator while sample data is loaded.
if (TEST_ON) { const d = new URLSearchParams(location.search).get('demo'); if (d) setScenario(d); }

let raw = null;
async function dataset() {
  if (raw) return raw;
  const scn = getScenario();
  if (MOCK) raw = !TEST_ON ? { patients: {} } : scn === 'demo' ? buildDemoData({ lang: LANG }) : buildSampleData({ lang: LANG, scenario: scn });
  else raw = await loadFromApi();
  return raw;
}

// ===== Patients =====
// Enriched patient: registration data + consultations, regimen (prescriptions), protocol and targets,
// readings (classified, newest first), meals, doses, alerts, requests, reports, status, follow-up and flags
let patientsCache = null;
// Review state that comes with the data (test data: demoReviewed in data/mock/demo-patients.js; the backend will
// send its own). It covers only notifications generated from the source data, never ones the doctor's actions create.
let sourceReviewed = {};
export async function getPatients() {
  if (patientsCache) return patientsCache;
  const d = await dataset();
  patientsCache = enrich(d, state());
  if (TEST_ON && getScenario() === 'demo') {
    const src = enrich(d, EMPTY_STATE);
    sourceReviewed = demoReviewed(Object.values(src).flatMap(p => buildNotifications(p, d.chat?.[p.id] ?? [])), now());
  }
  return patientsCache;
}
const EMPTY_STATE = { ack: {}, repSeen: {}, chat: {}, ins: {}, rem: [], remdel: [], cons: {} };
function enrich(d, s) {
  const out = {}, t0 = now();
  for (const [key, f] of Object.entries(d.patients ?? {})) {
    const id = Number(key);
    const x = { id, age: null, sex: null, reportedType: null, linkedAt: null, status: null, cg: null, focus_day: null, ...f };
    // Clinical record: consultations from the source + the ones documented in this browser (oldest first)
    x.consultations = [...(d.consultations?.[id] ?? []), ...(s.cons[id] ?? [])].sort((a, b) => a.at - b.at);
    const last = x.consultations.at(-1) ?? null;
    x.initial = x.consultations.find(c => c.kind === 'initial') ?? null;
    x.awaiting = !x.initial;
    // Diabetes type, protocol and targets come from the latest consultation; before it, the type is self-reported
    const lastDx = [...x.consultations].reverse().find(c => c.dx?.type)?.dx ?? null;
    x.dx = lastDx;
    x.type = lastDx?.type ?? null;
    x.typeConfirmed = !!lastDx?.type;
    const lastProt = [...x.consultations].reverse().find(c => c.protocol);
    x.protocolId = PROTOCOLS[lastProt?.protocol] ? lastProt.protocol : defaultProtocolId(x.type ?? x.reportedType);
    x.indivTargets = [...x.consultations].reverse().find(c => c.targets)?.targets ?? null;
    x.targets = effectiveTargets(protocolOf(x), x.indivTargets);
    x.regimen = deriveRegimen(x.consultations, t0);
    x.treat = treatmentKind(x.regimen.active);
    x.followUp = last?.followUp?.at ? { ...last.followUp, cid: last.id } : null;
    x.labs = x.consultations.flatMap(c => (c.labs ?? []).map(l => ({ ...l, cid: c.id }))).sort((a, b) => a.at - b.at);

    x.readings = cleanReadings(d.readings?.[id] ?? [], targets(x));
    x.meals = (d.meals?.[id] ?? []).map(m => ({ ...m, imp: m.imp ?? (Number.isFinite(m.after) && Number.isFinite(m.before) ? impactOf(m.after - m.before) : null) }))
      .sort((a, b) => b.at - a.at);
    x.doses = (d.doses?.[id] ?? []).slice().sort((a, b) => a.at - b.at);
    x.requests = d.requests?.[id] ?? [];
    // Alerts from the backend, otherwise derived from the readings with the same rule
    x.alerts = d.alerts?.[id] ?? deriveAlerts(x.readings, x, t0 - 10 * DAY);
    x.ins = [...(s.ins[id] ?? []), ...(d.ins?.[id] ?? [])];
    // Overall status: normal / controlled / critical only. From the backend when it sends one; otherwise
    // calculated from the readings. Test data never sends a status, so it is always calculated
    const st = ['high', 'low'].includes(x.status) ? 'ctrl' : x.status;
    x.statusSrc = STATUSES.includes(st) ? 'backend' : 'calc';
    x.status = STATUSES.includes(st) ? st : overallStatus(x, x.readings);
    x.reports = autoReports(x.readings);
    x.ov = overviewStats(x);
    x.flags = interventionFlags(x, t0);
    out[id] = x;
  }
  return out;
}
export const firstPatientId = ps => Number(Object.keys(ps)[0] ?? 0) || null;

// ===== Consultations (the only way to change treatment) =====
export async function addConsultation(pid, c) {
  const rec = { id: 'c' + Date.now().toString(36), ...c };
  if (!MOCK) await http.post(`/patients/${pid}/consultations`, rec);
  updateState(s => { (s.cons[pid] ??= []).push(rec); });
  return rec;
}

// ===== Notifications (glucose alerts, requests, messages, treatment updates, follow-ups, adherence) =====
export const isAcked = (pid, nid) => state().ack[pid]?.[nid] ?? sourceReviewed[pid]?.[nid] ?? null;
export async function ackNotification(pid, nid) {
  if (!MOCK) await http.post(`/patients/${pid}/notifications/${encodeURIComponent(nid)}/ack`);
  updateState(s => { (s.ack[pid] ??= {})[nid] = now(); });
}
export const ackAlert = ackNotification;
// Every notification, with `ack` = time reviewed (by the doctor, or handled by a reply / consultation)
export async function getNotifications() {
  const ps = await getPatients(), out = [];
  for (const p of Object.values(ps)) {
    for (const n of buildNotifications(p, await getChat(p.id))) out.push({ ...n, ack: isAcked(p.id, n.id) ?? n.auto ?? null });
  }
  return out.sort((a, b) => b.at - a.at);
}
export async function openNotifications() { return (await getNotifications()).filter(n => !n.ack).length; }

// ===== Reports =====
export const reportSeen = (pid, r) => !!state().repSeen[pid]?.[r.id];
export async function markReportSeen(pid, rid) {
  if (!MOCK) await http.post(`/patients/${pid}/reports/${rid}/seen`);
  updateState(s => { (s.repSeen[pid] ??= {})[rid] = now(); });
}
export async function newReports() {
  let n = 0;
  for (const p of Object.values(await getPatients())) for (const r of p.reports) if (!reportSeen(p.id, r)) n++;
  return n;
}

// ===== Instructions and chat =====
export async function addInstruction(pid, text) {
  if (!MOCK) await http.post(`/patients/${pid}/instructions`, { text });
  updateState(s => { (s.ins[pid] ??= []).unshift([text, now()]); });
}
export async function getChat(pid) {
  const d = await dataset();
  return [...(d.chat?.[pid] ?? []), ...(state().chat[pid] ?? [])];
}
export async function sendMessage(pid, text) {
  if (!MOCK) await http.post(`/patients/${pid}/chat`, { text });
  updateState(s => { (s.chat[pid] ??= []).push(['doctor', text, now()]); });
}

// ===== Reminders =====
// Glucose-check and custom reminders from the source and the doctor, plus reminders built from the data:
// medication reminders from the active prescriptions (next dose, and the last 24 hours from the dose log)
// and the planned follow-up visit
function derivedReminders(p) {
  const out = [], t0 = now();
  for (const v of p.regimen.active) {
    if (v.freq === 'as_needed') continue;
    for (const slot of v.timing) {
      const [hh, mm] = TIMING[slot].split(':').map(Number), dt = new Date(); dt.setHours(hh, mm, 0, 0);
      let at = Math.floor(dt / 1000); if (at <= t0) at += DAY;
      out.push({ id: `rx-${v.id}-${slot}`, pid: p.id, type: 'med', title: `${iso(v.drug)} ${iso(v.dose + ' ' + t('unit.' + v.unit))} · ${t('timing.' + slot)}`,
        at, rep: v.freq === 'weekly' ? 'weekly' : 'daily', src: 'prescription', st: 'up' });
    }
  }
  for (const d of p.doses.filter(x => x.at > t0 - DAY && x.at <= t0)) {
    const v = p.regimen.versions.find(x => x.id === d.ver);
    if (v) out.push({ id: `dose-${d.ver}-${d.at}`, pid: p.id, type: 'med', title: `${iso(v.drug)} ${iso(v.dose + ' ' + t('unit.' + v.unit))} · ${t('timing.' + d.slot)}`,
      at: d.at, rep: 'daily', src: 'prescription', st: d.taken ? 'done' : 'missed' });
  }
  if (p.followUp && p.followUp.at > t0) out.push({ id: `visit-${p.followUp.cid}`, pid: p.id, type: 'visit', title: t('rem.visit_title'), at: p.followUp.at, rep: 'once', src: 'doctor', st: 'up' });
  return out;
}
export async function getReminders() {
  const d = await dataset(), s = state(), ps = await getPatients();
  return [...(d.reminders ?? []), ...s.rem, ...Object.values(ps).flatMap(derivedReminders)]
    .filter(x => !s.remdel.includes(x.id) && ps[x.pid])
    .map(x => ({ ...x, st: reminderStatus(x) }))
    .sort((a, b) => a.at - b.at);
}
export async function missedReminders() { return (await getReminders()).filter(r => r.st === 'missed').length; }
export async function addReminder(r) {
  const rem = { id: 'r' + Date.now().toString(36), src: 'doctor', st: 'up', ...r };
  if (!MOCK) await http.post('/reminders', rem);
  updateState(s => { s.rem.push(rem); });
}
// The doctor can delete only the reminders she created by hand (not prescription or visit reminders)
export async function deleteReminder(id) {
  const r = (await getReminders()).find(x => x.id === id && x.src === 'doctor' && x.type !== 'visit');
  if (!r) return;
  if (!MOCK) await http.del(`/reminders/${id}`);
  updateState(s => { s.remdel.push(id); });
}

// ===== Doctor profile and preferences (kept in this browser until the backend stores them) =====
const DOC_DEFAULT = { name: CONFIG.doctorName, spec: '', hosp: '', email: '', phone: '', loc: '', joined: null, status: null,
  unit: 'mg/dL', notif: { crit: 1, msg: 1, rem: 1, req: 1, fu: 1, email: 0 }, photo: 'default', pw: null };
export const DEFAULT_PHOTO = 'assets/img/doctor.png';
// With the backend the name and email come from the signed-in account (loaded with the first page data, see loadFromApi);
// what the doctor edits in the profile is kept in this browser and wins
const fromBackend = () => (raw?.doctor ? { name: raw.doctor.name, email: raw.doctor.email } : {});
export function getDoctor() { return { ...DOC_DEFAULT, ...fromBackend(), ...(local.get('dms-doctor', {}) ?? {}), lang: LANG }; }
export async function saveDoctor(fields) {
  const d = { ...(local.get('dms-doctor', {}) ?? {}), ...fields };
  // TODO(backend): store the profile with PUT /doctor (not implemented yet); until then it stays in this browser
  local.set('dms-doctor', d);
}
export function docPhoto(d = getDoctor()) { return d.photo === 'default' ? DEFAULT_PHOTO : (d.photo || ''); }

// ===== Patient linking: one link code per patient =====
// At the clinic the doctor creates a code for ONE specific patient; the patient enters or scans it in the Patient App
// and is then linked to the doctor (previous readings become visible, status "Awaiting initial consultation").
// A code is single-use (once a Patient App account redeems it, it is bound to that account and nobody else can use
// it) and has no expiry. The doctor can cancel a code that has not been used.
// API mode: the backend generates and stores the codes (POST / GET / DELETE /doctor/link-codes, see http.js).
// Redeeming happens in the backend's POST /link-codes/redeem, called with the patient's own token, which binds the
// code to that patient account and marks it used (st: 'used', usedAt). The dashboard never redeems a code.
// Mock mode: codes are kept in this browser (localStorage 'dms-link-codes') and cannot be redeemed here.
// The label is the doctor's own reference; only the code itself is ever put in the QR code.
// Code record: { id, label, code, at (created), st: 'pending' | 'used', usedAt }
export { LINK_CODE_RE };
export const LINK_DEMO = MOCK;
const LC_KEY = 'dms-link-codes', LC_LABEL_MAX = 60;
const lcValid = c => !!c && LINK_CODE_RE.test(String(c.code ?? '')) && ['pending', 'used'].includes(c.st);
const lcStored = () => (local.get(LC_KEY, []) ?? []).filter(lcValid);
const lcId = () => 'lc-' + Array.from(globalThis.crypto.getRandomValues(new Uint8Array(6)), b => b.toString(16).padStart(2, '0')).join('');
export async function createLinkCode(label) {
  // Optional: an empty label is stored as '' (the page shows "Unnamed"); the code is always generated, never typed
  const lb = String(label ?? '').trim().slice(0, LC_LABEL_MAX);
  if (!MOCK) {
    const c = await http.post('/doctor/link-codes', { label: lb });
    if (!lcValid(c)) throw new Error('link code: invalid response');
    return c;
  }
  const all = lcStored();
  const c = { id: lcId(), label: lb, code: makeLinkCode(undefined, all.map(x => x.code)), at: now(), st: 'pending', usedAt: null };
  local.set(LC_KEY, [c, ...all]);
  return c;
}
// All codes of this doctor (pending and used), newest first
export async function listLinkCodes() {
  const list = MOCK ? lcStored() : ((await http.get('/doctor/link-codes')) ?? []);
  return list.filter(lcValid).sort((a, b) => b.at - a.at);
}
// Cancel a code that has not been used. A used code is bound to a patient account and cannot be cancelled here
export async function cancelLinkCode(id) {
  const c = (await listLinkCodes()).find(x => x.id === id);
  if (!c || c.st !== 'pending') return false;
  if (!MOCK) await http.del(`/doctor/link-codes/${encodeURIComponent(id)}`);
  else local.set(LC_KEY, lcStored().filter(x => x.id !== id));
  return true;
}
