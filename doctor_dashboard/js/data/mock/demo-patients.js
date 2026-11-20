// ===== TEST DATA ONLY: the default demo =====
// Not real patient information. Three fictional test patients for trying the dashboard before the FastAPI
// backend is connected. Loaded only through js/data/api.js when CONFIG.dataSource is 'mock' and CONFIG.testMode
// is true; real patient data never comes from this file. Test patients use ids 1–3.
//
//   1 Sobhi (صبحي)  Critical    his complete original record, unchanged, from sample-data.js (scenario "all"):
//                               3 weeks of readings, meals, 4 consultations, prescriptions, doses, instructions,
//                               messages, requests, reminders, and the health reports generated from them
//   2 Soso (سوسو)   Normal      registered 16 days ago, awaiting the initial consultation
//   3 Fofo (فوفو)   Controlled  registered 16 days ago, awaiting the initial consultation
//
// NO STATUS IS SET BY HAND. Each patient only has inputs (readings, meals, and for Sobhi his clinical record);
// the dashboard calculates every status, alert, notification, report and statistic with the normal rules.
//
// Soso and Fofo are kept minimal: 16 days of hourly sensor readings (so the first automatic health report,
// due 14 days after the first reading, exists for each), meals logged on the last 3 days, no consultations
// (so no prescriptions: treatment starts only at the initial consultation), no messages, requests or reminders.
// Their readings never go below 70 or above 250 mg/dL, so they produce no glucose alerts.
//
// Notifications: generated normally from all this data (Sobhi's history produces about 40). The demo records
// which ones the doctor has already reviewed (demoReviewed below), like the backend will send the reviewed state,
// so only 2 are open: Sobhi's latest critical glucose alert and his latest urgent appointment request.
// Deterministic: identical on every load; times are relative to now, so the data stays current.
import { DAY, now as nowTs, today } from '../../core/time.js';
import { impactOf } from '../../core/clinical.js';
import { buildSampleData } from './sample-data.js';

const DAYS = 16, MEAL_DAYS = 3;
// Glucose rise after a meal relative to its peak (1 at 75 minutes), over 5 hours
const mealCurve = hrs => (hrs <= 0 || hrs > 5 ? 0 : (hrs / 1.25) * Math.exp(1 - hrs / 1.25));
const dawn = h => (h >= 3 && h <= 8 ? 12 * Math.sin(Math.PI * (h - 3) / 5) : 0);
// Small deterministic variation in [-1, 1] (no randomness, so every load is identical)
const wave = (i, seed) => Math.sin(i * 12.9898 + seed * 78.233) * 0.5 + Math.sin(i * 4.1414 + seed) * 0.5;

// Glucose model inputs per patient. base: glucose without meals; sens: mg/dL rise per gram of carbs at the
// peak; carbs: usual carbs per meal [breakfast, lunch, dinner]; range: sensor values stay within it
const PROFILES = {
  2: { base: 98, sens: 0.9, carbs: [34, 42, 30], noise: 7, range: [78, 162], seed: 12 },
  3: { base: 146, sens: 1.2, carbs: [55, 72, 60], noise: 9, range: [102, 238], seed: 13 },
};

export function buildDemoData({ lang = 'en' } = {}) {
  const t0 = today(), now = nowTs(), lastAt = now - 50 * 60;
  const at = (day, hour) => Math.floor(t0 + day * DAY + hour * 3600);   // negative day = days ago
  const L = (en, ar) => (lang === 'ar' ? ar : en);
  const first = -(DAYS - 1);

  // Registration data from the Patient App (the diabetes type is self-reported until the initial consultation)
  const patients = {
    2: { name: L('Soso', 'سوسو'), age: 34, sex: 'F', reportedType: 'Type 2', linkedAt: at(first - 1, 15) },
    3: { name: L('Fofo', 'فوفو'), age: 45, sex: 'M', reportedType: 'Type 2', linkedAt: at(first - 1, 17) },
  };

  // ===== Meals: 3 a day. Every day shapes the glucose; only the last 3 days are logged in the app =====
  const M = (en, ar, kcal, protein, fat, items) => ({ name: L(en, ar), kcal, protein, fat, items: items.map(([e, a]) => L(e, a)) });
  const MENU = {
    2: [M('Oats with milk', 'شوفان بالحليب', 300, 11, 8, [['Oats', 'شوفان'], ['Milk', 'حليب']]),
      M('Grilled chicken with salad', 'دجاج مشوي مع سلطة', 430, 34, 12, [['Grilled chicken', 'دجاج مشوي'], ['Green salad', 'سلطة خضراء'], ['Brown rice', 'أرز بني']]),
      M('Yogurt with cucumber', 'لبن مع خيار', 240, 12, 7, [['Yogurt', 'لبن'], ['Cucumber', 'خيار'], ['Whole-wheat bread', 'خبز قمح كامل']])],
    3: [M('Falafel sandwich', 'ساندويش فلافل', 540, 16, 22, [['Falafel', 'فلافل'], ['Pita bread', 'خبز عربي']]),
      M('Rice with okra stew', 'أرز مع بامية', 650, 24, 20, [['White rice', 'أرز أبيض'], ['Okra stew', 'بامية']]),
      M('Cheese sandwich', 'ساندويش جبنة', 420, 16, 18, [['White bread', 'خبز أبيض'], ['White cheese', 'جبنة بيضاء']])],
  };
  const TYPES = ['breakfast', 'lunch', 'dinner'], HOURS = [7.5, 13, 19.5];
  const eaten = {}, logged = {};
  for (const id of Object.keys(PROFILES)) {
    const pf = PROFILES[id];
    eaten[id] = [];
    for (let d = first - 1; d <= 0; d++) TYPES.forEach((type, k) => {
      const i = (d + 40) * 3 + k, ts = at(d, HOURS[k] + Math.round(wave(i, pf.seed) * 20) / 60);
      if (ts < lastAt) eaten[id].push({ type, k, at: ts, carbs: Math.round(pf.carbs[k] * (1 + wave(i + 7, pf.seed) * 0.12)) });
    });
    logged[id] = eaten[id].filter(m => m.at >= at(-(MEAL_DAYS - 1), 0)).map(m => ({
      ...MENU[id][m.k], id: `d${id}-${m.type}-${Math.floor((m.at - t0) / DAY)}`, type: m.type, at: m.at, carbs: m.carbs,
      kcal: Math.round(MENU[id][m.k].kcal * m.carbs / pf.carbs[m.k]) }));
  }

  // ===== Sensor (CGM) readings: one every hour =====
  const readings = {};
  for (const id of Object.keys(PROFILES)) {
    const pf = PROFILES[id], R = [];
    const model = ts => { const h = (ts - t0) / 3600 - Math.floor((ts - t0) / DAY) * 24;
      return pf.base + dawn(h) + eaten[id].reduce((s, m) => s + pf.sens * m.carbs * mealCurve((ts - m.at) / 3600), 0); };
    for (let ts = at(first, 0), i = 0; ts < lastAt; ts += 3600, i++) {
      const v = Math.max(pf.range[0], Math.min(pf.range[1], model(ts) + wave(i, pf.seed) * pf.noise));
      R.push({ id: `g${id}-${i}`, v: Math.round(v), at: ts, src: 'cgm', type: 'RBS' });
    }
    const latest = Math.round(Math.max(pf.range[0], Math.min(pf.range[1], model(lastAt))));
    R.push({ id: `g${id}-latest`, v: latest, at: lastAt, src: 'cgm', type: 'RBS' });
    readings[id] = R;
  }

  // Glucose at the meal and 2 hours after it, from actual readings only (null when there is none within 30 min)
  const meals = {};
  for (const id of Object.keys(PROFILES)) {
    const near = ts => readings[id].filter(r => Math.abs(r.at - ts) <= 1800).sort((a, b) => Math.abs(a.at - ts) - Math.abs(b.at - ts))[0]?.v ?? null;
    meals[id] = logged[id].map(m => { const before = near(m.at), after = m.at + 7200 <= lastAt ? near(m.at + 7200) : null;
      return { ...m, before, after, imp: before !== null && after !== null ? impactOf(after - before) : null, src: 'cgm' }; })
      .sort((a, b) => b.at - a.at);
  }

  // Sobhi: the original record, unchanged. Soso and Fofo: readings and meals only
  const sobhi = buildSampleData({ lang, scenario: 'all' });
  const add = (k, own = { 2: [], 3: [] }) => ({ 1: sobhi[k][1], ...own });
  return { patients: add('patients', patients), readings: add('readings', readings), meals: add('meals', meals),
    consultations: add('consultations'), doses: add('doses'), requests: add('requests'), ins: add('ins'), chat: add('chat'),
    reminders: sobhi.reminders };
}

// Review state of the demo, like the backend will send it: which generated notifications the doctor has already
// reviewed, and when. notifs: the notifications generated from this test data only (never the ones the doctor's own
// actions create in the session). Everything is reviewed half an hour after it arrived, except the two items left
// open: the latest critical glucose alert and the latest urgent appointment request. Items already handled by
// something else (a reply, a later consultation) keep that. Returns { pid: { notificationId: reviewedAt } }.
export function demoReviewed(notifs, t) {
  const latest = f => notifs.filter(f).sort((a, b) => b.at - a.at)[0]?.id;
  const open = new Set([latest(n => n.kind === 'glucose' && n.sev === 'crit'), latest(n => n.kind === 'request' && n.sev === 'warn')]);
  const out = {};
  for (const n of notifs) if (!open.has(n.id) && !n.auto) (out[n.pid] ??= {})[n.id] = Math.max(n.at, Math.min(n.at + 1800, t - 300));
  return out;
}
