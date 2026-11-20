// Clinical rules (ported from data.php). Pure functions with no DOM, so they can be unit-tested and
// reused unchanged when the backend sends the same data shapes.
//
// Default targets: international consensus on CGM metrics (Battelino et al., Diabetes Care 2019) and ADA:
// range 70–180, level 2 below 54 or above 250, time in range >70%, below range <4% (below 54 <1%),
// above range <25% (above 250 <5%). A patient can override them with `targets`
// (e.g. older / high-risk: in range >50%, below range <1%).
import { DAY, now, today, addDays, startOfDay } from './time.js';

export const DEFAULT_TG = { low: 70, high: 180, vlow: 54, vhigh: 250, tir: 70, tbr: 4, tbr2: 1, tar: 25, tar2: 5 };
export const STATUSES = ['ok', 'ctrl', 'crit'];              // overall patient status: one of these only
export const READING_ST = ['ok', 'ctrl', 'high', 'crit', 'low']; // classification of a single reading
export const SOURCES = ['manual', 'cgm'];
export const targets = p => ({ ...DEFAULT_TG, ...(p?.targets ?? {}) });
export const insulinTreated = p => p?.type === 'Type 1' || p?.treat === 'insulin';

// critical = level 2 (below 54 or above 250), low = below the minimum, normal = in range,
// controlled = above range without reaching level 2
export function classify(v, tg) {
  if (v < tg.vlow || v > tg.vhigh) return 'crit';
  if (v < tg.low) return 'low';
  return v <= tg.high ? 'ok' : 'ctrl';
}
// Range text shown next to a classification, from the patient's own targets
export function stRange(st, tg, v = null) {
  switch (st) {
    case 'ok': return `${tg.low} – ${tg.high}`;
    case 'ctrl': return `${tg.high + 1} – ${tg.vhigh}`;
    case 'low': return `${tg.vlow} – ${tg.low - 1}`;
    case 'crit': return v !== null && v < tg.low ? `< ${tg.vlow}` : `> ${tg.vhigh}`;
    default: return `> ${tg.high}`;
  }
}

// Alerts derived from readings (test data; the backend will send its own). Critical and low for every
// patient since `since`; above target only for insulin users, within the last 24 hours
// One alert per EPISODE, not per reading: consecutive sensor readings in the same abnormal state (no gap over
// 3 hours) form one episode, reported with its most extreme value (highest, or lowest for lows) and the time it
// started. This avoids an alert for every hourly sensor value (alarm fatigue). Manual readings alert on their own.
export const ALERT_GAP = 3 * 3600;
export function deriveAlerts(rs, p, since) {
  const tg = targets(p), out = [], t = now();
  const kind = x => { const st = x.st ?? classify(x.v, tg);
    if (['crit', 'low'].includes(st) && x.at >= since) return st === 'crit' ? (x.v < tg.low ? 'crit-lo' : 'crit-hi') : 'low';
    if (st === 'ctrl' && insulinTreated(p) && x.at >= t - DAY) return 'ctrl';
    return null; };
  let ep = null;
  const close = () => { if (ep) out.push({ id: ep.id, st: ep.st, v: ep.v, at: ep.at, n: ep.n, end: ep.end }); ep = null; };
  for (const x of [...rs].sort((a, b) => a.at - b.at)) {
    const k = kind(x), st = k ? (k.startsWith('crit') ? 'crit' : k) : null;
    if (x.src === 'manual') { if (k) out.push({ id: x.id ? `a-${x.id}` : `a${x.at}`, st, v: x.v, at: x.at, n: 1, end: x.at }); continue; }
    if (!k || (ep && (ep.k !== k || x.at - ep.end > ALERT_GAP))) close();
    if (!k) continue;
    // a stable id from the first reading of the episode (the backend sends its own alert ids)
    if (!ep) ep = { k, st, id: x.id ? `a-${x.id}` : `a${x.at}`, v: x.v, at: x.at, end: x.at, n: 0 };
    ep.n++; ep.end = x.at;
    if (k === 'crit-lo' || k === 'low' ? x.v < ep.v : x.v > ep.v) ep.v = x.v;
  }
  close();
  return out.sort((a, b) => b.at - a.at);
}

// Valid readings only, classified with the patient's targets (unless the source sent `st`), newest first
export function cleanReadings(raw, tg) {
  return raw.filter(x => SOURCES.includes(x.src))
    .map(x => ({ ...x, st: x.st ?? classify(x.v, tg) }))
    .filter(x => READING_ST.includes(x.st))
    .sort((a, b) => b.at - a.at);
}

// Average from all readings. Time in / above / below range from sensor (CGM) readings only:
// manual readings are sparse and don't represent time
export function glucoseStats(rs, tg = DEFAULT_TG) {
  const n = rs.length, cgm = rs.filter(r => r.src === 'cgm').map(r => r.v), c = cgm.length;
  const pct = f => (c ? Math.round(cgm.filter(f).length / c * 100) : null);
  return { avg: n ? Math.round(rs.reduce((s, r) => s + r.v, 0) / n) : null,
    tir: pct(v => v >= tg.low && v <= tg.high), high: pct(v => v > tg.high), low: pct(v => v < tg.low), total: n, cgm: c };
}

// Enough sensor data (CGM consensus): assess the last 14 days, sensor active on at least 70% of them.
// Coverage = number of 24-hour parts of the period that have sensor readings
export const CGM_DAYS = 14, CGM_MIN_PCT = 70;
export function cgmCoverage(rs, days = CGM_DAYS, to = null) {
  to ??= now(); const from = to - days * DAY;
  const d = new Set(rs.filter(r => r.src === 'cgm' && r.at > from && r.at <= to).map(r => Math.floor((r.at - from) / DAY))).size;
  const pct = Math.round(d / days * 100);
  return { days: d, of: days, pct, ok: pct >= CGM_MIN_PCT };
}
// Home numbers for a patient: latest reading, average and time in range of the last 14 days.
// tir is null when sensor data is insufficient (the page shows "Insufficient CGM data")
export function overviewStats(p) {
  const rs = p.readings.filter(r => r.at > now() - CGM_DAYS * DAY);
  const s = glucoseStats(rs, targets(p)), cov = cgmCoverage(rs);
  return { last: p.readings[0] ?? null, avg: s.avg, tir: cov.ok ? s.tir : null, cov };
}

// Time split into the five ranges (sensor readings only) and whether each goal is met
export function tirBreakdown(rs, tg) {
  const cgm = rs.filter(r => r.src === 'cgm').map(r => r.v), c = cgm.length;
  if (!c) return null;
  const p = f => cgm.filter(f).length / c * 100;
  const b = { vlow: p(v => v < tg.vlow), low: p(v => v >= tg.vlow && v < tg.low), in: p(v => v >= tg.low && v <= tg.high),
    high: p(v => v > tg.high && v <= tg.vhigh), vhigh: p(v => v > tg.vhigh) };
  const met = { vlow: b.vlow < tg.tbr2, low: b.vlow + b.low < tg.tbr, in: b.in > tg.tir, high: b.high + b.vhigh < tg.tar, vhigh: b.vhigh < tg.tar2 };
  return { pct: b, met, n: c };
}
// Status of a period from sensor data only (same consensus goals), or null without sensor readings
export function periodStatus(p, rs) {
  const b = tirBreakdown(rs, targets(p));
  if (!b) return null;
  const m = b.met;
  if (!m.vlow || !m.low || !m.vhigh) return 'crit';
  return !m.in || !m.high ? 'ctrl' : 'ok';
}
// Fallback only when the backend doesn't send the overall status. One of three, from the patient's
// targets and last 14 days: critical if the latest reading is level 2 or a below-54 / below-70 / above-250
// limit is exceeded; controlled if time in range or time above 180 misses its goal; otherwise normal.
// Without sensor data: by the latest reading (in range = normal, otherwise controlled)
export function overallStatus(p, rs) {
  if (!rs.length) return null;
  if (rs[0].st === 'crit') return 'crit';
  return periodStatus(p, rs.filter(r => r.at >= now() - 14 * DAY)) ?? (rs[0].st === 'ok' ? 'ok' : 'ctrl');
}

// Status history: the last 3 calendar weeks (oldest first), each assessed on its own sensor readings.
// Shows how the status changed over time; the current overall status stays a single value.
// A week with sensor data on fewer than 70% of its days (under 5 days) is not assessed
export function statusHistory(p, weeks = 3) {
  const out = [], t0 = today();
  for (let w = weeks - 1; w >= 0; w--) {
    const from = addDays(t0, -(w * 7 + 6)), to = addDays(from, 7);
    const rs = p.readings.filter(r => r.at >= from && r.at < to);
    const cov = cgmCoverage(rs, 7, Math.min(to, now())), s = glucoseStats(rs, targets(p));
    out.push({ from, to, st: cov.ok ? periodStatus(p, rs) : null, avg: s.avg, tir: cov.ok ? s.tir : null, n: rs.length, rs, now: w === 0 });
  }
  return out;
}

// Daily averages for the last `days` days ending on the day of `end`: [[dayTs, avg|null], ...]
export function dailyAverages(rs, days = 7, end = null) {
  const e = startOfDay(end ?? now()), out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = addDays(e, -i), d1 = addDays(d, 1);
    const v = rs.filter(r => r.at >= d && r.at < d1).map(r => r.v);
    out.push([d, v.length ? Math.round(v.reduce((s, x) => s + x, 0) / v.length) : null]);
  }
  return out;
}
// Daily lowest and highest reading for the same days as dailyAverages: [[dayTs, {min, max}|null], ...]
// (null = no readings that day). Used for the daily swing (whiskers) in the Overview trend
export function dailyMinMax(rs, days = 7, end = null) {
  const e = startOfDay(end ?? now()), out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = addDays(e, -i), d1 = addDays(d, 1);
    const v = rs.filter(r => r.at >= d && r.at < d1).map(r => r.v);
    out.push([d, v.length ? { min: Math.min(...v), max: Math.max(...v) } : null]);
  }
  return out;
}

// Reports: the first health report is generated automatically 14 days after the patient's FIRST glucose
// reading (not the registration date) and contains only data recorded in those days. After it, a weekly
// report every 7 days covers the week before it
export const FIRST_REPORT_DAYS = 14, WEEKLY_REPORT_DAYS = 7;
export function autoReports(rs) {
  if (!rs.length) return [];
  const first = Math.min(...rs.map(r => r.at)), due = first + FIRST_REPORT_DAYS * DAY;
  if (now() < due) return [];
  const out = [{ id: 'first', kind: 'first', from: first, to: due, at: due }];
  for (let i = 1, f = due, t; (t = f + WEEKLY_REPORT_DAYS * DAY) <= now(); i++, f = t)
    out.push({ id: `w${i}`, kind: 'weekly', from: f, to: t, at: t });
  return out;
}

// Glucose impact of a meal from the rise 2 hours after it (used when the backend doesn't classify the meal):
// below 40 mg/dL low, 40–79 moderate, 80 or more high
export const IMPACT = { high: 80, moderate: 40 };   // post-meal rise (mg/dL) for a high / moderate impact meal
export const impactOf = rise => (rise >= IMPACT.high ? 'high' : rise >= IMPACT.moderate ? 'moderate' : 'low');

// Reminders: one that the patient hasn't confirmed after its time counts as missed
export function reminderStatus(r) { return r.st === 'up' && r.at < now() ? 'missed' : r.st; }
