// Notifications for one patient, built from the patient's data. Pure, no DOM.
// The backend will send its own notifications later (GET /notifications); these are the same kinds with
// stable ids, so the doctor's "reviewed" state keeps working.
//
// { id, pid, kind, sev, at, a, auto? }
//   kind: 'glucose' | 'request' | 'message' | 'treatment' | 'followup' | 'adherence'
//   sev:  'crit' (critical medical alert, shown apart) | 'warn' | 'info'
//   auto: time the item was handled by something else (a reply, a consultation), so it counts as reviewed
import { DAY, now } from './time.js';

export const NOTIF_KINDS = ['glucose', 'request', 'message', 'treatment', 'followup', 'adherence'];

export function buildNotifications(p, chat = [], t = now()) {
  const out = [], after = ts => p.consultations.find(c => c.at > ts);
  // Glucose alerts: level 2 readings are critical, other abnormal readings are warnings
  for (const a of p.alerts) out.push({ id: a.id, pid: p.id, kind: 'glucose', sev: a.st === 'crit' ? 'crit' : 'warn', at: a.at, a: { st: a.st, v: a.v, n: a.n } });
  // Consultation requests sent from the Patient App; a later consultation answers them
  for (const r of p.requests) out.push({ id: r.id, pid: p.id, kind: 'request', sev: r.urgent ? 'warn' : 'info', at: r.at, a: { kind: r.kind, note: r.note }, auto: after(r.at)?.at ?? null });
  // Patient messages; a later reply from the doctor counts as reviewed
  for (const [who, text, at] of chat) if (who === 'patient') {
    const reply = chat.find(m => m[0] === 'doctor' && m[2] > at);
    out.push({ id: `msg-${p.id}-${at}`, pid: p.id, kind: 'message', sev: 'info', at, a: { text }, auto: reply ? reply[2] : null });
  }
  // Treatment updates: each consultation that started, changed or stopped a medication
  for (const c of p.consultations) {
    const ch = p.regimen.versions.filter(v => v.cid === c.id).map(v => ({ act: v.act, drug: v.drug, dose: v.dose, unit: v.unit,
      prev: p.regimen.versions.find(x => x.id === v.prev) ?? null }))
      .concat(p.regimen.versions.filter(v => v.stopCid === c.id).map(v => ({ act: 'stop', drug: v.drug, dose: v.dose, unit: v.unit, prev: null })));
    if (ch.length) out.push({ id: `tx-${c.id}`, pid: p.id, kind: 'treatment', sev: 'info', at: c.at, a: { cid: c.id, ch } });
  }
  // Follow-up from the latest consultation: due within 2 days, or overdue
  if (p.followUp) {
    const f = p.followUp, due = f.at - t;
    if (due < 0) out.push({ id: `fu-${f.cid}-over`, pid: p.id, kind: 'followup', sev: 'warn', at: f.at, a: { at: f.at, over: true } });
    else if (due <= 2 * DAY) out.push({ id: `fu-${f.cid}`, pid: p.id, kind: 'followup', sev: 'info', at: Math.max(f.at - 2 * DAY, p.consultations.at(-1)?.at ?? 0), a: { at: f.at, over: false } });
  }
  // Two or more missed doses in the last 3 days
  const missed = p.doses.filter(d => !d.taken && d.at > t - 3 * DAY && d.at <= t);
  if (missed.length >= 2) out.push({ id: `adh-${p.id}-${missed.at(-1).at}`, pid: p.id, kind: 'adherence', sev: 'warn', at: missed.at(-1).at, a: { n: missed.length } });
  return out;
}
