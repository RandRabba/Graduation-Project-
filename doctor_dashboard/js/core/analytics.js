// Monitoring analytics. Pure functions over an enriched patient (see data/api.js), no DOM.
//
// Everything here DESCRIBES the data for the doctor: trends, patterns and flags for clinical review.
// Nothing here changes a treatment, and the findings are associations in the recorded data, not diagnoses.
import { DAY, addDays, startOfDay, now } from './time.js';
import { targets, cgmCoverage, tirBreakdown, periodStatus, glucoseStats, ALERT_GAP, impactOf } from './clinical.js';
import { adherence, isInsulin } from './medications.js';
import { protocolOf } from './protocols.js';

export const mean = xs => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const sg = v => (v === null ? '—' : (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v));
const rnd = (v, d = 0) => (v === null || v === undefined || Number.isNaN(v) ? null : Math.round(v * 10 ** d) / 10 ** d);
const within = (from, to) => x => x.at >= from && x.at < to;
// Glucose Management Indicator (estimated HbA1c, %) from mean glucose in mg/dL
export const gmi = avg => (avg === null || avg === undefined ? null : rnd(3.31 + 0.02392 * avg, 1));

export function pearson(xs, ys) {
  const n = xs.length; if (n < 3) return null;
  const mx = mean(xs), my = mean(ys);
  let sxy = 0, sxx = 0, syy = 0;
  for (let i = 0; i < n; i++) { const a = xs[i] - mx, b = ys[i] - my; sxy += a * b; sxx += a * a; syy += b * b; }
  return sxx && syy ? rnd(sxy / Math.sqrt(sxx * syy), 2) : null;
}
function pct(sorted, q) {
  if (!sorted.length) return null;
  const i = (sorted.length - 1) * q, lo = Math.floor(i), hi = Math.ceil(i);
  return Math.round(sorted[lo] + (sorted[hi] - sorted[lo]) * (i - lo));
}

// Buckets of `step` days covering [from, to), aligned to local midnight: [[start, end], ...]
export function buckets(from, to, step = 1) {
  const out = [];
  for (let d = startOfDay(from); d < to; d = addDays(d, step)) out.push([d, Math.min(addDays(d, step), to)]);
  return out;
}

// One patient, one bucket: glucose, time in ranges, nutrition and adherence
export function bucketStats(p, from, to) {
  const tg = targets(p), inB = within(from, to);
  const rs = p.readings.filter(inB), vs = rs.map(r => r.v), cgm = rs.filter(r => r.src === 'cgm');
  const meals = p.meals.filter(inB), ad = adherence(p.doses, from, to);
  const bd = tirBreakdown(rs, tg), days = Math.max(1, Math.round((to - from) / DAY));
  const cov = cgmCoverage(rs, days, to);
  return {
    from, to, n: rs.length, avg: rnd(mean(vs)), min: vs.length ? Math.min(...vs) : null, max: vs.length ? Math.max(...vs) : null,
    tir: bd ? rnd(bd.pct.in) : null, tbr: bd ? rnd(bd.pct.low + bd.pct.vlow, 1) : null, tar: bd ? rnd(bd.pct.high + bd.pct.vhigh) : null,
    bd, cgm: cgm.length, cov,
    status: days >= 7 && cov.ok ? periodStatus(p, rs) : null,
    // nutrition per day of the bucket (only days with logged meals count)
    meals: meals.length, carbs: meals.length ? Math.round(meals.reduce((s, m) => s + m.carbs, 0) / Math.max(1, new Set(meals.map(m => startOfDay(m.at))).size)) : null,
    kcal: meals.length ? Math.round(meals.reduce((s, m) => s + m.kcal, 0) / Math.max(1, new Set(meals.map(m => startOfDay(m.at))).size)) : null,
    adh: ad.pct, sched: ad.scheduled, taken: ad.taken,
  };
}
export const series = (p, from, to, step = 1) => buckets(from, to, step).map(([a, b]) => bucketStats(p, a, b));

// Several patients: the mean of the patients that have data in each bucket (adherence pooled over doses)
export function combineSeries(list) {
  if (list.length === 1) return list[0];
  return list[0].map((b0, i) => {
    const xs = list.map(s => s[i]), avgOf = k => rnd(mean(xs.map(x => x[k]).filter(v => v !== null)));
    const sched = xs.reduce((s, x) => s + x.sched, 0), taken = xs.reduce((s, x) => s + x.taken, 0);
    const mins = xs.map(x => x.min).filter(v => v !== null), maxs = xs.map(x => x.max).filter(v => v !== null);
    const bds = xs.map(x => x.bd).filter(Boolean);
    const bd = bds.length ? { pct: Object.fromEntries(['vlow', 'low', 'in', 'high', 'vhigh'].map(k => [k, mean(bds.map(b => b.pct[k]))])) } : null;
    return { ...b0, n: xs.reduce((s, x) => s + x.n, 0), avg: avgOf('avg'), min: mins.length ? Math.min(...mins) : null, max: maxs.length ? Math.max(...maxs) : null,
      tir: avgOf('tir'), tbr: rnd(mean(xs.map(x => x.tbr).filter(v => v !== null)), 1), tar: avgOf('tar'), bd, carbs: avgOf('carbs'), kcal: avgOf('kcal'),
      meals: xs.reduce((s, x) => s + x.meals, 0), sched, taken, adh: sched ? Math.round(taken / sched * 100) : null, status: null };
  });
}

// Ambulatory glucose profile: sensor readings of the period folded into the 24 hours of a day
export function hourlyProfile(rs) {
  const bins = Array.from({ length: 24 }, () => []);
  for (const r of rs) if (r.src === 'cgm') bins[new Date(r.at * 1000).getHours()].push(r.v);
  return bins.map((b, h) => { const s = [...b].sort((x, y) => x - y);
    return { h, n: s.length, p10: pct(s, 0.1), p25: pct(s, 0.25), p50: pct(s, 0.5), p75: pct(s, 0.75), p90: pct(s, 0.9) }; });
}

// Meal impact: the glucose rise two hours after eating, grouped by carbohydrate amount and by meal type
export const CARB_BANDS = [['lt45', 0, 45], ['45to75', 45, 75], ['gt75', 75, Infinity]];
export function mealImpact(meals) {
  const ok = meals.filter(m => Number.isFinite(m.before) && Number.isFinite(m.after));
  const grp = f => { const g = ok.filter(f); return { n: g.length, rise: rnd(mean(g.map(m => m.after - m.before))), carbs: rnd(mean(g.map(m => m.carbs))) }; };
  return {
    bands: CARB_BANDS.map(([k, a, b]) => ({ k, ...grp(m => m.carbs >= a && m.carbs < b) })),
    types: ['breakfast', 'lunch', 'dinner', 'snack'].map(k => ({ k, ...grp(m => m.type === k) })).filter(x => x.n),
    points: ok.map(m => ({ carbs: m.carbs, rise: m.after - m.before, m })),
  };
}

// Post-meal glucose rise matched from the patient's own readings. The meal's stored before/after values are not
// used here: they can be filled in from an estimate when no reading was taken near the meal.
// A meal counts only when all of these hold (otherwise it is left out, never estimated):
//   pre-meal  = the last reading in the hour up to the meal time
//   post-meal = the reading closest to 2 h after the meal, between 90 and 150 minutes after it
//   no other meal was logged in the hour before it or before its post-meal reading (the rise would be mixed)
export const POST_MEAL = { pre: 60 * 60, postFrom: 90 * 60, postTo: 150 * 60, aim: 120 * 60 };
export function matchMealRise(readings, meals) {
  const rs = readings.filter(r => Number.isFinite(r.v) && Number.isFinite(r.at)), ms = [...meals].sort((a, b) => a.at - b.at);
  return ms.map((m, i) => {
    const pre = rs.filter(r => r.at <= m.at && r.at >= m.at - POST_MEAL.pre).sort((a, b) => b.at - a.at)[0];
    const post = rs.filter(r => r.at >= m.at + POST_MEAL.postFrom && r.at <= m.at + POST_MEAL.postTo)
      .sort((a, b) => Math.abs(a.at - m.at - POST_MEAL.aim) - Math.abs(b.at - m.at - POST_MEAL.aim))[0];
    const next = ms[i + 1], prev = ms[i - 1];
    if (!pre || !post || (next && next.at <= post.at) || (prev && prev.at >= m.at - POST_MEAL.pre)) return null;
    return { m, pre, post, rise: post.v - pre.v };
  }).filter(Boolean);
}
// The matched pairs of every patient in scope for meals in [from, to) (readings and later meals just outside the
// range still count for matching)
export function matchedPairs(scope, from, to) {
  return scope.flatMap(p => matchMealRise(p.readings.filter(r => r.at >= from - POST_MEAL.pre && r.at <= to + POST_MEAL.postTo),
    p.meals.filter(within(from, to + POST_MEAL.postTo)))).filter(q => q.m.at >= from && q.m.at < to);
}
// Nutrition summary from matched pairs only, so every rise on the Nutrition tab uses the same method.
// Every meal of the period is accounted for: total = matched + unmatched; per carbohydrate group and per meal type,
// n = matched meals and total = all meals of that group. Meals without a valid carbohydrate value or with an
// unknown meal type are counted in their own "unclassified" group instead of being dropped.
export const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'];
export function nutritionImpact(scope, from, to) {
  const meals = scope.flatMap(p => p.meals.filter(within(from, to))), pairs = matchedPairs(scope, from, to);
  const hasCarbs = m => Number.isFinite(m.carbs) && m.carbs >= 0;
  const grp = f => { const g = pairs.filter(q => f(q.m)), all = meals.filter(f);
    return { n: g.length, total: all.length, rise: rnd(mean(g.map(q => q.rise))), carbs: rnd(mean(g.filter(q => hasCarbs(q.m)).map(q => q.m.carbs))) }; };
  return {
    total: meals.length, matched: pairs.length, unmatched: meals.length - pairs.length, pairs,
    rise: rnd(mean(pairs.map(q => q.rise))), high: pairs.filter(q => impactOf(q.rise) === 'high').length,
    bands: CARB_BANDS.map(([k, a, b]) => ({ k, ...grp(m => hasCarbs(m) && m.carbs >= a && m.carbs < b) })),
    noCarbs: grp(m => !hasCarbs(m)),
    types: MEAL_TYPES.map(k => ({ k, ...grp(m => m.type === k) })),
    otherType: grp(m => !MEAL_TYPES.includes(m.type)),
  };
}
// Per day (bs: buckets of series/combineSeries): mean post-meal rise of the matched meals, with how many meals of the
// day were matched. Several patients: each patient's day mean first, then the mean of those patients (as combineSeries).
// rise is null when the day has no matched meal; meals > 0 then means "Insufficient data", meals 0 means no meals.
export function dailyPostMealRise(scope, bs) {
  if (!bs.length) return [];
  const from = bs[0].from, to = bs.at(-1).to;
  const per = scope.map(p => ({ meals: p.meals.filter(within(from, to)), pairs: matchedPairs([p], from, to) }));
  return bs.map(b => {
    const inB = within(b.from, b.to), xs = per.map(x => ({ meals: x.meals.filter(inB).length, rises: x.pairs.filter(q => inB(q.m)).map(q => q.rise) }));
    const all = xs.flatMap(x => x.rises), means = xs.filter(x => x.rises.length).map(x => mean(x.rises));
    return { from: b.from, to: b.to, carbs: b.carbs ?? null, meals: xs.reduce((s, x) => s + x.meals, 0), n: all.length,
      rise: means.length ? rnd(mean(means)) : null, lo: all.length ? Math.min(...all) : null, hi: all.length ? Math.max(...all) : null };
  });
}

// Patterns in the period, for clinical review. Each: { k: translation key, sev: 'info'|'warn', a: values }
export function findings(p, from, to) {
  const tg = targets(p), rules = protocolOf(p).rules, inP = within(from, to), out = [];
  const rs = p.readings.filter(inP), meals = p.meals.filter(inP), mi = mealImpact(meals);
  // 1. Carbohydrate amount and the rise after meals
  const lo = mi.bands[0], hi = mi.bands[2];
  if (lo.n >= 2 && hi.n >= 2) out.push({ k: 'f.carb_bands', sev: hi.rise - lo.rise >= 40 ? 'warn' : 'info', a: { hi: sg(hi.rise), nh: hi.n, lo: sg(lo.rise), nl: lo.n } });
  // 2. Meal type with the largest average rise
  const worst = mi.types.filter(t => t.n >= 2).sort((a, b) => b.rise - a.rise)[0];
  if (worst && worst.rise >= 40) out.push({ k: 'f.meal_type', sev: worst.rise >= 80 ? 'warn' : 'info', a: { type: worst.k, rise: sg(worst.rise), carbs: worst.carbs, n: worst.n } });
  // 3. After-meal readings at level 2 (above 250)
  const l2 = meals.filter(m => m.after > tg.vhigh).length;
  if (l2) out.push({ k: 'f.post_meal_l2', sev: 'warn', a: { n: l2, of: meals.length, v: tg.vhigh } });
  // 4. Missed doses and glucose in the 12 hours after them (per medication)
  for (const rx of new Set(p.doses.filter(inP).map(d => d.rx))) {
    const ds = p.doses.filter(d => d.rx === rx && inP(d)), after = d => mean(p.readings.filter(r => r.at > d.at && r.at <= d.at + 12 * 3600).map(r => r.v));
    const miss = ds.filter(d => !d.taken).map(after).filter(v => v !== null), tk = ds.filter(d => d.taken).map(after).filter(v => v !== null);
    const v = p.regimen.versions.find(x => x.rx === rx);
    if (miss.length && tk.length >= 2 && mean(miss) - mean(tk) >= 15)
      out.push({ k: 'f.dose_missed', sev: 'warn', a: { drug: v?.drug ?? rx, miss: rnd(mean(miss)), taken: rnd(mean(tk)), n: miss.length } });
  }
  // 5. Night-time lows (sensor below the target minimum between midnight and 6 AM), counted per night
  const nights = new Set(rs.filter(r => r.src === 'cgm' && r.v < tg.low && new Date(r.at * 1000).getHours() < 6).map(r => startOfDay(r.at)));
  if (nights.size) out.push({ k: 'f.night_lows', sev: 'warn', a: { n: nights.size } });
  // 6. Fasting readings above the preprandial target
  const fbs = rs.filter(r => r.type === 'FBS').map(r => r.v), fh = rules.fastingHigh ?? 130;
  if (fbs.length >= 3 && mean(fbs) > fh) out.push({ k: 'f.fasting_high', sev: 'info', a: { v: rnd(mean(fbs)), t: fh, n: fbs.length } });
  // 7. Daily carbohydrates and daily mean glucose move together
  const ds = series(p, from, to).filter(d => d.carbs !== null && d.avg !== null);
  const r = ds.length >= 7 ? pearson(ds.map(d => d.carbs), ds.map(d => d.avg)) : null;
  if (r !== null && Math.abs(r) >= 0.4) out.push({ k: 'f.carb_corr', sev: 'info', a: { r, n: ds.length } });
  return out;
}

// Flags that may need clinical intervention. They only point the doctor to the data
export function interventionFlags(p, t = now()) {
  const tg = targets(p), rules = protocolOf(p).rules, out = [];
  const r7 = p.readings.filter(r => r.at > t - 7 * DAY), r14 = p.readings.filter(r => r.at > t - 14 * DAY);
  if (p.awaiting) out.push({ k: 'awaiting', sev: 'info' });
  if (p.status === 'crit') out.push({ k: 'crit_status', sev: 'crit' });
  const hypo = r7.filter(r => r.v < (rules.hypoFlagBelow ?? tg.vlow));
  if (hypo.length) out.push({ k: 'hypo_l2', sev: 'crit', a: { n: hypo.length } });
  const cov = cgmCoverage(r14), s = glucoseStats(r14, tg);
  if (cov.ok && s.tir !== null && s.tir < tg.tir) out.push({ k: 'tir_low', sev: 'warn', a: { v: s.tir, g: tg.tir } });
  const ad = adherence(p.doses, t - 7 * DAY, t);
  if (ad.pct !== null && ad.pct < (rules.minAdherence ?? 80)) out.push({ k: 'adherence', sev: 'warn', a: { v: ad.pct } });
  if (rules.ketoneFlagAbove && p.readings.some(r => r.at > t - DAY && r.v > rules.ketoneFlagAbove)) out.push({ k: 'ketone', sev: 'warn' });
  if (p.followUp && p.followUp.at < t) out.push({ k: 'fu_overdue', sev: 'warn', a: { at: p.followUp.at } });
  if (p.readings.length && p.readings[0].at < t - DAY) out.push({ k: 'stale', sev: 'warn', a: { h: Math.round((t - p.readings[0].at) / 3600) } });
  const rank = { crit: 0, warn: 1, info: 2 };
  return out.sort((a, b) => rank[a.sev] - rank[b.sev]);
}

// One definition used by every count and list on Home. Clinical STATUS (normal / controlled / critical) and
// clinical ATTENTION are separate questions; a patient can match several filters (e.g. Critical and Needs Attention).
// - needs clinical review: at least one critical or warning flag (awaiting the initial consultation is info, not a warning)
// - requires attention: critical or controlled status, or a clinical warning flag
// - awaiting the initial consultation is its own category (p.awaiting), not part of attention
export const reviewFlags = p => p.flags.filter(f => f.sev !== 'info');
export const needsReview = p => reviewFlags(p).length > 0;
export const requiresAttention = p => p.status === 'crit' || p.status === 'ctrl' || needsReview(p);

// Clinical priority: Critical → Controlled → Normal → not assessed; then more urgent flags, then lower TIR
export const STATUS_RANK = { crit: 0, ctrl: 1, ok: 2 };
export function priorityCompare(a, b) {
  const s = (STATUS_RANK[a.status] ?? 3) - (STATUS_RANK[b.status] ?? 3);
  if (s) return s;
  const n = sev => p => p.flags.filter(f => f.sev === sev).length;
  return (n('crit')(b) - n('crit')(a)) || (n('warn')(b) - n('warn')(a)) || ((a.ov?.tir ?? 101) - (b.ov?.tir ?? 101));
}
export { isInsulin };

// ===== Statistics: population (all patients) and one patient =====
// Every function takes the period [from, to) and only uses readings recorded in it: no gaps are filled.

// Average glucose trend of the population. For each bucket, each patient's own mean first, then the mean of
// those patient means, so a patient with many readings doesn't outweigh one with few. n = patients with data
export function populationTrend(list, from, to, step = 1) {
  return buckets(from, to, step).map(([a, b]) => {
    const per = list.map(p => mean(p.readings.filter(r => r.at >= a && r.at < b).map(r => r.v))).filter(v => v !== null);
    return { from: a, to: b, avg: rnd(mean(per)), n: per.length };
  });
}
// Time in range of one patient over a period, only when it is reliable: sensor (CGM) readings on at least
// 70% of the period's days (the consensus rule used for the status). Manual readings never count as time.
// Uses the patient's own targets (Type 1 / Type 2 protocol or individual targets). Null when not reliable
export function reliableTir(p, from, to) {
  const rs = p.readings.filter(within(from, to)), days = Math.max(1, Math.round((to - from) / DAY));
  if (!cgmCoverage(rs, days, to).ok) return null;
  const tg = targets(p), bd = tirBreakdown(rs, tg);
  return bd ? { tir: rnd(bd.pct.in), tbr: rnd(bd.pct.low + bd.pct.vlow, 1), tbrGoal: tg.tbr, goal: tg.tir } : null;
}
// Mean TIR per current status group, from the eligible patients only (total = patients in the group)
export function tirByStatus(list, from, to) {
  return ['ok', 'ctrl', 'crit'].map(st => {
    const g = list.filter(p => p.status === st), v = g.map(p => reliableTir(p, from, to)).filter(Boolean);
    return { st, total: g.length, n: v.length, tir: v.length ? rnd(mean(v.map(x => x.tir))) : null };
  });
}
// Glucose episodes in a period: consecutive sensor readings above the target maximum (high) or below the target
// minimum (low), no gap over 3 hours (same rule as alerts); a manual reading out of range is its own episode.
// l2 = the episode reached level 2 (above 250 / below 54)
export function episodes(p, from, to) {
  const tg = targets(p), out = { high: [], low: [] };
  const kindOf = v => (v > tg.high ? 'high' : v < tg.low ? 'low' : null), l2 = (k, v) => (k === 'high' ? v > tg.vhigh : v < tg.vlow);
  let ep = null; const close = () => { if (ep) out[ep.k].push(ep); ep = null; };
  for (const r of p.readings.filter(within(from, to)).sort((a, b) => a.at - b.at)) {
    const k = kindOf(r.v);
    if (r.src === 'manual') { if (k) out[k].push({ k, at: r.at, end: r.at, v: r.v, n: 1, l2: l2(k, r.v) }); continue; }
    if (!k || (ep && (ep.k !== k || r.at - ep.end > ALERT_GAP))) close();
    if (!k) continue;
    ep ??= { k, at: r.at, end: r.at, v: r.v, n: 0, l2: false };
    ep.n++; ep.end = r.at; ep.l2 ||= l2(k, r.v);
    if (k === 'high' ? r.v > ep.v : r.v < ep.v) ep.v = r.v;
  }
  close();
  return out;
}
// Clinical insights for the population: the selected period compared with the previous period of the same
// length. Each insight is shown only when the data supports it. { k, sev: 'ok'|'warn'|'crit'|'info', a }
export function populationInsights(list, from, to) {
  const span = to - from, pf = from - span, out = [];
  // 1. Average glucose: patients with readings in both periods (each patient's mean first)
  const pairs = list.map(p => [mean(p.readings.filter(within(pf, from)).map(r => r.v)), mean(p.readings.filter(within(from, to)).map(r => r.v))]).filter(([a, b]) => a !== null && b !== null);
  if (pairs.length) {
    const a = rnd(mean(pairs.map(x => x[0]))), b = rnd(mean(pairs.map(x => x[1]))), d = b - a;
    out.push({ k: Math.abs(d) < 5 ? 'si.glu_same' : d > 0 ? 'si.glu_up' : 'si.glu_down', sev: Math.abs(d) < 5 ? 'info' : d > 0 ? 'warn' : 'ok', a: { a, b, d: sg(d), n: pairs.length } });
  }
  // 2. Time in range: patients with reliable sensor data in both periods
  const tp = list.map(p => [reliableTir(p, pf, from), reliableTir(p, from, to)]).filter(([a, b]) => a && b);
  if (tp.length) {
    const a = rnd(mean(tp.map(x => x[0].tir))), b = rnd(mean(tp.map(x => x[1].tir))), d = b - a;
    out.push({ k: Math.abs(d) < 3 ? 'si.tir_same' : d > 0 ? 'si.tir_up' : 'si.tir_down', sev: Math.abs(d) < 3 ? 'info' : d > 0 ? 'ok' : 'warn', a: { a, b, d: sg(d), n: tp.length } });
  }
  // 3. Repeated level-2 episodes (two or more in the period), among patients with readings in the period
  const withData = list.filter(p => p.readings.some(within(from, to)));
  if (withData.length) {
    const rep = withData.filter(p => { const e = episodes(p, from, to); return [...e.high, ...e.low].filter(x => x.l2).length >= 2; }).length;
    out.push({ k: rep ? 'si.rep_crit' : 'si.rep_crit_none', sev: rep ? 'crit' : 'ok', a: { n: rep, of: withData.length } });
  }
  // 4. Time below range above its goal (hypoglycaemia risk), among patients with reliable sensor data
  const cur = list.map(p => reliableTir(p, from, to)).filter(Boolean);
  if (cur.length) {
    const n = cur.filter(x => x.tbr >= x.tbrGoal).length;
    out.push({ k: n ? 'si.tbr' : 'si.tbr_none', sev: n ? 'warn' : 'ok', a: { n, of: cur.length } });
  }
  return out;
}
// Before / after a consultation: the same length of time on each side (default 14 days), the "after" window
// ending at the next consultation or now. Side by side only; a change is not attributed to the treatment
export function aroundConsultation(p, c, next, t = now(), days = 14) {
  const b0 = c.at - days * DAY, a1 = Math.min(c.at + days * DAY, next?.at ?? Infinity, t);
  const side = (a, b) => { const rs = p.readings.filter(within(a, b)), rt = reliableTir(p, a, b);
    return { from: a, to: b, n: rs.length, avg: rnd(mean(rs.map(r => r.v))), tir: rt?.tir ?? null, days: rnd((b - a) / DAY, 1) }; };
  return { before: side(b0, c.at), after: side(c.at, a1) };
}

// Home sorting: exactly four orders, one direction each. Reading / Time / Date use each patient's latest reading
// (readings are newest first). Time = clock time of day of that reading (latest in the day first); Date = its
// calendar day (newest first). Patients without readings always come last. Ties (same value, time or day, or no
// reading) fall back to the name, then the patient id, so the order is stable
const latest = p => p.readings[0] ?? null;
const clock = ts => { const d = new Date(ts * 1000); return d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds(); };
const byName = (a, b) => a.name.localeCompare(b.name) || (a.id ?? 0) - (b.id ?? 0);
const desc = f => (a, b) => { const x = latest(a), y = latest(b);
  if (!x || !y) return (!x - !y) || byName(a, b);
  return (f(y) - f(x)) || byName(a, b); };
export const HOME_SORTS = {
  name: byName,
  reading: desc(r => r.v),
  time: desc(r => clock(r.at)),
  date: desc(r => startOfDay(r.at)),
};

// Important glucose findings for the Monitoring tab: at most `max`, glucose-only, most important first.
// Built only from the existing rules (episodes, tirBreakdown with the patient's goals, findings()); no diagnosis,
// no treatment advice. Each: { k: translation key, sev: 'crit'|'warn', a: values }
//  1. hypoglycaemia: two or more low episodes in the period (critical if any went below 54)
//  2. persistent hyperglycaemia: sensor time above range over the patient's goal (critical if > 250 time over its goal)
//  3. fasting readings above the protocol's preprandial target
//  4. night-time lows (only when not already covered by 1)
export function glucoseFindings(p, from, to, max = 3) {
  const tg = targets(p), out = [], ep = episodes(p, from, to), bd = tirBreakdown(p.readings.filter(within(from, to)), tg);
  if (ep.low.length >= 2) { const l2 = ep.low.filter(e => e.l2).length; out.push({ k: 'gf.hypo', sev: l2 ? 'crit' : 'warn', a: { n: ep.low.length, l2, v: tg.vlow } }); }
  if (bd) { const tar = rnd(bd.pct.high + bd.pct.vhigh);
    if (tar > tg.tar) out.push({ k: 'gf.hyper', sev: bd.pct.vhigh > tg.tar2 ? 'crit' : 'warn', a: { v: tar, g: tg.tar, h: tg.high } }); }
  const f = findings(p, from, to), fast = f.find(x => x.k === 'f.fasting_high'), night = f.find(x => x.k === 'f.night_lows');
  if (fast) out.push({ k: 'gf.fasting', sev: 'warn', a: { v: fast.a.v, t: fast.a.t, n: fast.a.n } });
  if (night && !out.some(x => x.k === 'gf.hypo')) out.push({ k: 'gf.night', sev: 'warn', a: { n: night.a.n } });
  return out.slice(0, max);
}
// Alerts in clinical order for the Monitoring tab: not yet reviewed first, then critical before low before
// above-target, then newest. ackedAt(a) → review time or null
export const ALERT_RANK = { crit: 0, low: 1, ctrl: 2 };
export const alertOrder = ackedAt => (a, b) => (!!ackedAt(a) - !!ackedAt(b)) || ((ALERT_RANK[a.st] ?? 3) - (ALERT_RANK[b.st] ?? 3)) || (b.at - a.at);
