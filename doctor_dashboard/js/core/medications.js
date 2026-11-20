// Medication management. Pure functions, no DOM.
//
// Prescriptions are NEVER edited directly. Each consultation carries a list of medication actions
// (start / change / stop / continue, each with a reason), and the prescription history is rebuilt by replaying
// the consultations in order. So every treatment change is tied to a documented clinical assessment, and the
// previous prescriptions are always kept.
//
// Medication action (inside consultation.meds):
//   { act: 'start'|'change'|'stop'|'continue', rx: line id, drug, dose, unit, route, freq, timing: [..], days, notes, reason }
// Prescription version (output):
//   { id, rx, drug, dose, unit, route, freq, timing, days, notes, start, end, status, cid, reason, act, prev }
import { DAY, now, ymd, addDays } from './time.js';

export const FREQ = ['once_daily', 'twice_daily', 'three_times_daily', 'weekly', 'as_needed'];
// Dose times. These are the reminder times the Patient App will use once the backend sends them
export const TIMING = { before_breakfast: '07:30', with_breakfast: '08:00', with_lunch: '13:00', with_dinner: '19:00', bedtime: '22:00' };
export const UNITS = ['mg', 'units', 'mcg', 'mL'];
export const ROUTES = ['oral', 'subcutaneous'];
// Suggestions for the drug field (the doctor can type any name)
export const DRUGS = ['Metformin', 'Insulin glargine', 'Insulin degludec', 'Insulin aspart', 'Insulin lispro', 'Gliclazide',
  'Empagliflozin', 'Dapagliflozin', 'Sitagliptin', 'Semaglutide', 'Dulaglutide', 'Pioglitazone'];
export const isInsulin = v => /insulin/i.test(v?.drug ?? '');

// Rebuild every prescription version from the consultations (any order in, oldest first inside)
export function deriveRegimen(consultations, t = now()) {
  const versions = [], cur = {};
  for (const c of [...consultations].sort((a, b) => a.at - b.at)) {
    for (const m of c.meds ?? []) {
      const prev = cur[m.rx];
      if (m.act === 'continue' || (m.act !== 'start' && !prev)) continue;
      if (prev) { prev.end = c.at; prev.status = m.act === 'stop' ? 'stopped' : 'replaced'; delete cur[m.rx]; }
      if (m.act === 'stop') { prev.stopReason = m.reason; prev.stopCid = c.id; continue; }
      const base = m.act === 'change' ? prev : {};
      const v = {
        rx: m.rx, drug: m.drug ?? base.drug, dose: m.dose ?? base.dose, unit: m.unit ?? base.unit, route: m.route ?? base.route,
        freq: m.freq ?? base.freq, timing: m.timing ?? base.timing ?? [], days: m.days ?? null, notes: m.notes ?? '',
        id: `${m.rx}@${c.id}`, start: c.at, end: null, status: 'active', cid: c.id, reason: m.reason ?? '', act: m.act, prev: prev?.id ?? null,
      };
      // calendar days, so a course keeps its length across daylight-saving changes
      if (v.days) v.end = addDays(v.start, v.days);
      versions.push(v); cur[m.rx] = v;
    }
  }
  // A course with a set duration that has ended is completed
  for (const v of versions) if (v.status === 'active' && v.end && v.end <= t) v.status = 'completed';
  return { versions, active: versions.filter(v => v.status === 'active') };
}

// Version that was active at time ts for each prescription line
export const activeAt = (versions, ts) => versions.filter(v => v.start <= ts && (v.end === null || v.end > ts));

// Treatment summary for the patient header: insulin / oral / none
export function treatmentKind(active) {
  if (active.some(isInsulin)) return 'insulin';
  return active.length ? 'oral' : null;
}

// Doses expected from the active versions between from and to: [{rx, ver, at, slot}]
export function scheduledDoses(versions, from, to) {
  const out = [];
  for (const v of versions) {
    if (v.freq === 'as_needed') continue;
    for (let d = Math.floor(from / DAY) * DAY - DAY; d <= to; d += DAY) {
      for (const slot of v.timing) {
        const [hh, mm] = TIMING[slot].split(':').map(Number), dt = new Date(d * 1000);
        dt.setHours(hh, mm, 0, 0);
        const at = Math.floor(dt / 1000);
        if (at >= from && at < to && at >= v.start && (v.end === null || at < v.end)) out.push({ rx: v.rx, ver: v.id, at, slot });
      }
    }
  }
  return out.sort((a, b) => a.at - b.at);
}

// Adherence from the dose log sent by the Patient App: [{rx, ver, at, taken}]
export function adherence(doses, from = -Infinity, to = Infinity, rx = null) {
  const ds = doses.filter(d => d.at >= from && d.at < to && (!rx || d.rx === rx));
  const taken = ds.filter(d => d.taken).length;
  return { scheduled: ds.length, taken, missed: ds.length - taken, pct: ds.length ? Math.round(taken / ds.length * 100) : null };
}

// Payload for the future backend → Patient App synchronization (POST /patients/{id}/prescriptions/sync).
// Nothing is sent today; the dashboard shows the sync as pending.
export function syncPayload(pid, v) {
  return {
    patient_id: pid, prescription_id: v.rx, version_id: v.id, consultation_id: v.cid,
    drug_name: v.drug, dose: v.dose, unit: v.unit, route: v.route, frequency: v.freq,
    times: v.timing.map(k => TIMING[k]), start_date: ymd(v.start), end_date: v.end ? ymd(v.end) : null, status: v.status,
    reminders: v.timing.map(k => ({ time: TIMING[k], slot: k, title: `${v.drug} ${v.dose} ${v.unit}` })),
  };
}
