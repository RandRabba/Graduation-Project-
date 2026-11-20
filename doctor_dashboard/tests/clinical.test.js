// Unit tests for the clinical rules, medication model, analytics and the test data.
// Run: npm test (Node 18+, no packages needed).
import test from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_TG, classify, stRange, glucoseStats, cgmCoverage, periodStatus, overallStatus, statusHistory, autoReports, cleanReadings, targets, deriveAlerts, impactOf, dailyMinMax } from '../js/core/clinical.js';
import { deriveRegimen, scheduledDoses, adherence, syncPayload, treatmentKind } from '../js/core/medications.js';
import { PROTOCOLS, effectiveTargets, protocolOf } from '../js/core/protocols.js';
import { series, hourlyProfile, mealImpact, matchMealRise, dailyPostMealRise, nutritionImpact, findings, interventionFlags, priorityCompare, pearson, gmi, needsReview, requiresAttention, populationTrend, reliableTir, tirByStatus, episodes, populationInsights, aroundConsultation, HOME_SORTS, glucoseFindings, alertOrder } from '../js/core/analytics.js';
import { buildNotifications } from '../js/core/notify.js';
import { buildSampleData } from '../js/data/mock/sample-data.js';
import { DAY, now, startOfDay } from '../js/core/time.js';

// The same enrichment as js/data/api.js getPatients(), without the browser parts
const patient = scenario => {
  const d = buildSampleData({ scenario });
  const p = { id: 1, ...d.patients[1] };
  p.consultations = d.consultations[1];
  p.awaiting = !p.consultations.some(c => c.kind === 'initial');
  p.type = p.consultations.at(-1)?.dx?.type ?? null;
  p.protocolId = p.consultations.at(-1)?.protocol;
  p.targets = effectiveTargets(protocolOf(p), null);
  p.regimen = deriveRegimen(p.consultations);
  p.treat = treatmentKind(p.regimen.active);
  p.readings = cleanReadings(d.readings[1], targets(p));
  p.meals = d.meals[1]; p.doses = d.doses[1]; p.requests = d.requests[1];
  p.alerts = deriveAlerts(p.readings, p, now() - 10 * DAY);
  p.status = overallStatus(p, p.readings);
  const last = p.consultations.at(-1);
  p.followUp = last?.followUp?.at ? { ...last.followUp, cid: last.id } : null;
  p.flags = interventionFlags(p);
  return { d, p };
};

test('classify follows the consensus ranges', () => {
  assert.equal(classify(53, DEFAULT_TG), 'crit');
  assert.equal(classify(60, DEFAULT_TG), 'low');
  assert.equal(classify(70, DEFAULT_TG), 'ok');
  assert.equal(classify(180, DEFAULT_TG), 'ok');
  assert.equal(classify(181, DEFAULT_TG), 'ctrl');
  assert.equal(classify(250, DEFAULT_TG), 'ctrl');
  assert.equal(classify(251, DEFAULT_TG), 'crit');
  assert.equal(stRange('crit', DEFAULT_TG, 40), '< 54');
  assert.equal(stRange('crit', DEFAULT_TG, 300), '> 250');
});

test('time in range uses sensor readings only', () => {
  const t = now();
  const s = glucoseStats([{ v: 100, src: 'cgm', at: t }, { v: 200, src: 'cgm', at: t }, { v: 400, src: 'manual', at: t }]);
  assert.equal(s.tir, 50);
  assert.equal(s.avg, 233);
});

test('sensor coverage below 70% is insufficient', () => {
  const c = cgmCoverage(Array.from({ length: 5 }, (_, i) => ({ v: 120, src: 'cgm', at: now() - i * DAY - 60 })));
  assert.equal(c.days, 5);
  assert.equal(c.ok, false);
});

test('first report arrives 14 days after the first reading, then weekly', () => {
  assert.deepEqual(autoReports([{ at: now() - 13 * DAY }]), []);
  const r = autoReports([{ at: now() - 21 * DAY }]);
  assert.equal(r[0].kind, 'first');
  assert.equal(r[0].to - r[0].from, 14 * DAY);
  assert.equal(r[1].kind, 'weekly');
});

test('one test patient only: Sobhi / صبحي', () => {
  for (const scenario of ['all', 'ok', 'ctrl', 'crit', 'new']) assert.deepEqual(Object.keys(buildSampleData({ scenario }).patients), ['1']);
  assert.equal(buildSampleData().patients[1].name, 'Sobhi');
  assert.equal(buildSampleData({ lang: 'ar' }).patients[1].name, 'صبحي');
});

test('test data never sets a status by hand', () => {
  for (const scenario of ['all', 'ok', 'ctrl', 'crit', 'new']) assert.equal(buildSampleData({ scenario }).patients[1].status, undefined);
});

test('each scenario\'s CALCULATED status matches its name, in every week', () => {
  for (const sc of ['ok', 'ctrl', 'crit']) {
    const { p } = patient(sc);
    assert.equal(p.status, sc, `${sc}: calculated overall status`);
    assert.equal(periodStatus(p, p.readings.filter(r => r.at >= now() - 14 * DAY)), sc);
    assert.ok(statusHistory(p).every(w => w.st === sc), `${sc}: every week`);
  }
});

test('"All" shows the three phases in order', () => {
  const { p } = patient('all');
  assert.equal(p.status, 'crit');
  assert.deepEqual(statusHistory(p).map(w => w.st), ['ok', 'ctrl', 'crit']);
});

test('example day keeps 110 → 280 → 195 → 120 with different classifications', () => {
  const { p } = patient('all');
  const day = p.focus_day, atH = (h, src) => p.readings.find(r => r.at === day + h * 3600 && r.src === src);
  assert.deepEqual([atH(9, 'cgm'), atH(13, 'manual'), atH(17, 'cgm'), atH(21, 'cgm')].map(r => r.v), [110, 280, 195, 120]);
  assert.deepEqual([atH(9, 'cgm'), atH(13, 'manual'), atH(17, 'cgm'), atH(21, 'cgm')].map(r => r.st), ['ok', 'crit', 'ctrl', 'ok']);
  const mansaf = p.meals.find(m => m.id === 'ex-l');
  assert.equal(mansaf.after, 280);
  assert.equal(mansaf.imp, 'high');
});

test('alert ids are stable between loads', async () => {
  const ids = () => patient('all').p.alerts.map(a => a.id).join();
  const a = ids(); await new Promise(r => setTimeout(r, 1100));
  assert.equal(ids(), a);
});

test('awaiting initial consultation: no treatment, no confirmed type', () => {
  const { p } = patient('new');
  assert.equal(p.awaiting, true);
  assert.equal(p.consultations.length, 0);
  assert.equal(p.regimen.active.length, 0);
  assert.equal(p.type, null);
  assert.ok(p.flags.some(f => f.k === 'awaiting'));
});

test('treatment changes only through consultations, previous prescriptions kept', () => {
  const { p } = patient('all');
  const gla = p.regimen.versions.filter(v => v.rx === 'rx-gla');
  assert.deepEqual(gla.map(v => v.dose), [14, 16, 12]);
  assert.deepEqual(gla.map(v => v.status), ['replaced', 'replaced', 'active']);
  assert.ok(gla.every(v => v.cid && p.consultations.some(c => c.id === v.cid)), 'every version has its consultation');
  assert.ok(gla.slice(1).every(v => v.reason), 'every change has a reason');
  assert.equal(gla[2].prev, gla[1].id);
  assert.equal(p.consultations[0].kind, 'initial');
  assert.equal(p.consultations[0].mode, 'in_person');
});

test('regimen: stop and fixed-duration courses', () => {
  const t = now();
  const cs = [{ id: 'a', at: t - 20 * DAY, meds: [{ act: 'start', rx: 'x', drug: 'Metformin', dose: 500, unit: 'mg', freq: 'once_daily', timing: ['with_breakfast'] },
    { act: 'start', rx: 'y', drug: 'Drug Y', dose: 1, unit: 'mg', freq: 'once_daily', timing: ['bedtime'], days: 5 }] },
  { id: 'b', at: t - 2 * DAY, meds: [{ act: 'stop', rx: 'x', reason: 'GI side effects' }] }];
  const r = deriveRegimen(cs, t);
  assert.equal(r.active.length, 0);
  assert.equal(r.versions.find(v => v.rx === 'x').status, 'stopped');
  assert.equal(r.versions.find(v => v.rx === 'y').status, 'completed');
  assert.equal(scheduledDoses(r.versions, t - 20 * DAY, t).filter(d => d.rx === 'y').length, 5);
});

test('sync payload is ready for the Patient App', () => {
  const { p } = patient('crit');
  const s = syncPayload(1, p.regimen.active.find(v => v.rx === 'rx-gla'));
  assert.equal(s.dose, 12);
  assert.deepEqual(s.times, ['22:00']);
  assert.equal(s.reminders.length, 1);
});

test('protocol targets and individualized targets', () => {
  assert.equal(effectiveTargets(PROTOCOLS['t2-older'], null).tir, 50);
  assert.equal(effectiveTargets(PROTOCOLS['t2-default'], { tir: 60 }).tir, 60);
  assert.ok(Object.values(PROTOCOLS).every(p => p.reviewed === false), 'defaults are marked as not clinically reviewed');
});

test('adherence drops with the scenario', () => {
  const pct = sc => adherence(patient(sc).p.doses).pct;
  assert.ok(pct('ok') > pct('ctrl') && pct('ctrl') > pct('crit'), `${pct('ok')} > ${pct('ctrl')} > ${pct('crit')}`);
});

test('analytics: meals with more carbs raise glucose more; flags for the critical scenario', () => {
  const { p } = patient('crit');
  const mi = mealImpact(p.meals);
  const lo = mi.bands.find(b => b.k === 'lt45'), hi = mi.bands.find(b => b.k === 'gt75');
  assert.ok(hi.rise > lo.rise || lo.n === 0, `high-carb rise ${hi.rise} vs low-carb ${lo.rise}`);
  const f = findings(p, now() - 14 * DAY, now()).map(x => x.k);
  assert.ok(f.includes('f.night_lows'));
  assert.ok(p.flags.some(x => x.k === 'crit_status') && p.flags.some(x => x.k === 'hypo_l2'));
  const days = series(p, startOfDay() - 7 * DAY, startOfDay());   // complete days only
  assert.ok(days.length >= 7 && days.every(d => d.carbs !== null));
  assert.equal(hourlyProfile(p.readings).length, 24);
  assert.equal(impactOf(85), 'high');
});

test('normal scenario has no clinical flags', () => {
  const { p } = patient('ok');
  assert.deepEqual(p.flags.filter(f => f.sev !== 'info').map(f => f.k), []);
});

test('clinical priority: critical, then controlled, then normal', () => {
  const mk = (status, tir) => ({ status, flags: [], ov: { tir } });
  const list = [mk('ok', 90), mk(null, null), mk('crit', 20), mk('ctrl', 50)].sort(priorityCompare);
  assert.deepEqual(list.map(x => x.status), ['crit', 'ctrl', 'ok', null]);
});

test('notifications: kinds, critical alerts and handled items', () => {
  const { d, p } = patient('all');
  const ns = buildNotifications(p, d.chat[1]);
  const kinds = new Set(ns.map(n => n.kind));
  for (const k of ['glucose', 'message', 'treatment', 'followup', 'request']) assert.ok(kinds.has(k), k);
  assert.ok(ns.some(n => n.sev === 'crit' && n.kind === 'glucose'));
  assert.equal(new Set(ns.map(n => n.id)).size, ns.length, 'ids are unique');
  // A patient message the doctor already answered counts as handled
  const answered = ns.find(n => n.kind === 'message' && n.auto);
  assert.ok(answered);
});

test('helpers', () => {
  assert.equal(pearson([1, 2, 3, 4], [2, 4, 6, 8]), 1);
  assert.equal(gmi(154), 7);
  assert.ok(startOfDay() <= now());
});

test('Home tabs: status kept apart from attention, consistent in every scenario', () => {
  // [critical, controlled, normal, awaiting, needs review, needs attention]
  const expect = { all: [1, 0, 0, 0, 1, 1], ok: [0, 0, 1, 0, 0, 0], ctrl: [0, 1, 0, 0, 1, 1], crit: [1, 0, 0, 0, 1, 1], new: [0, 1, 0, 1, 0, 1] };
  for (const [sc, exp] of Object.entries(expect)) {
    const { p } = patient(sc);
    const got = [p.status === 'crit', p.status === 'ctrl', p.status === 'ok', p.awaiting, needsReview(p), requiresAttention(p)].map(Number);
    assert.deepEqual(got, exp, sc);
    // exactly one status tab, and attention follows only from status or warning flags
    assert.equal(got[0] + got[1] + got[2], 1, sc);
    assert.equal(requiresAttention(p), p.status !== 'ok' || needsReview(p), sc);
  }
});

test('Statistics: population trend averages patient means, not readings', () => {
  const t0 = startOfDay(now()) - 2 * DAY;
  const mk = (id, vs) => ({ id, readings: vs.map((v, i) => ({ v, at: t0 + 3600 * (i + 1), src: 'manual' })) });
  // patient A: 4 readings of 100, patient B: 1 reading of 200 → mean of means 150 (a pooled mean would be 120)
  const pts = populationTrend([mk(1, [100, 100, 100, 100]), mk(2, [200])], t0, t0 + 2 * DAY);
  assert.equal(pts.length, 2);
  assert.deepEqual([pts[0].avg, pts[0].n], [150, 2]);
  assert.deepEqual([pts[1].avg, pts[1].n], [null, 0], 'a day without readings stays empty');
});

test('Statistics: TIR only with enough sensor data; manual readings never count', () => {
  for (const sc of ['all', 'ok', 'ctrl', 'crit']) {
    const { p } = patient(sc), to = now();
    const r = reliableTir(p, to - 14 * DAY, to);
    assert.ok(r && r.tir >= 0 && r.tir <= 100, sc);
    const g = tirByStatus([p], to - 14 * DAY, to);
    assert.equal(g.length, 3);
    const mine = g.find(x => x.st === p.status);
    assert.equal(mine.total, 1); assert.equal(mine.n, 1); assert.equal(mine.tir, r.tir);
    assert.ok(g.filter(x => x.st !== p.status).every(x => x.total === 0 && x.tir === null));
  }
  const manual = { readings: [{ v: 120, at: now() - DAY, src: 'manual' }] };
  assert.equal(reliableTir({ ...manual, targets: null }, now() - 7 * DAY, now()), null);
});

test('Statistics: episodes group consecutive sensor readings, split by 3-hour gaps', () => {
  const t0 = now() - 10 * 3600, c = (h, v) => ({ v, at: t0 + h * 3600, src: 'cgm' });
  const p = { targets: null, readings: [c(0, 200), c(1, 260), c(2, 190), c(3, 120), c(4, 60), c(8, 50), { v: 300, at: t0 + 9 * 3600, src: 'manual' }] };
  const e = episodes(p, t0 - 1, now());
  assert.equal(e.high.length, 2); assert.equal(e.low.length, 2);
  assert.deepEqual([e.high[0].n, e.high[0].v, e.high[0].l2], [3, 260, true]);
  assert.equal(e.low.filter(x => x.l2).length, 1);
});

test('Statistics: insights compare with the previous period and need data', () => {
  const { p } = patient('all'), to = now(), from = to - 7 * DAY;
  const ins = populationInsights([p], from, to);
  assert.ok(ins.length >= 2 && ins.length <= 4);
  assert.ok(ins.every(i => ['ok', 'warn', 'crit', 'info'].includes(i.sev)));
  assert.deepEqual(populationInsights([{ id: 9, readings: [], status: null }], from, to), []);
  const c = p.consultations.at(-1), x = aroundConsultation(p, c, null);
  assert.ok(x.before.n > 0 && x.after.to <= now());
});

test('Home sorting: Name, Reading, Time, Date; stable ties; patients without readings last', () => {
  const d0 = startOfDay(now()), at = (day, h, m = 0) => d0 - day * DAY + h * 3600 + m * 60;
  const mk = (id, name, ts, v) => ({ id, name, readings: ts === null ? [] : [{ at: ts, v }] });
  const ps = [mk(1, 'Amal', at(0, 23, 30), 90), mk(2, 'Basel', at(1, 22), 250), mk(3, 'Carim', at(0, 15), 140), mk(4, 'Dana', null, null), mk(5, 'Eman', at(1, 15), 140)];
  const order = k => [...ps].sort(HOME_SORTS[k]).map(p => p.name[0]).join('');
  assert.deepEqual(Object.keys(HOME_SORTS), ['name', 'reading', 'time', 'date']);
  assert.equal(order('name'), 'ABCDE');
  assert.equal(order('reading'), 'BCEAD', 'highest first; same value → name');
  assert.equal(order('time'), 'ABCED', 'latest clock time first, whatever the day; same time → name');
  assert.equal(order('date'), 'ACBED', 'newest day first; same day → name');
  // order does not depend on the input order (stable)
  assert.equal([...ps].reverse().sort(HOME_SORTS.date).map(p => p.name[0]).join(''), 'ACBED');
});

test('Monitoring: at most 3 glucose findings, most important first; alerts unreviewed + severe first', () => {
  const ALLOWED = ['gf.hypo', 'gf.hyper', 'gf.fasting', 'gf.night'], RANK = { 'gf.hypo': 0, 'gf.hyper': 1, 'gf.fasting': 2, 'gf.night': 3 };
  for (const sc of ['all', 'ok', 'ctrl', 'crit', 'new']) {
    const { p } = patient(sc), to = now();
    const f = glucoseFindings(p, to - 14 * DAY, to);
    assert.ok(f.length <= 3, sc);
    assert.ok(f.every(x => ALLOWED.includes(x.k) && ['crit', 'warn'].includes(x.sev)), sc);
    assert.deepEqual(f.map(x => x.k), [...f].sort((a, b) => RANK[a.k] - RANK[b.k]).map(x => x.k), sc + ' order');
  }
  // hypoglycaemia: two low episodes, one below 54 → critical finding
  const t0 = now() - 20 * 3600, c = (h, v) => ({ v, at: t0 + h * 3600, src: 'cgm' });
  const p = { targets: null, readings: [c(0, 60), c(5, 120), c(8, 50)], meals: [], doses: [], regimen: { versions: [] }, protocolId: 'type2' };
  const g = glucoseFindings(p, t0 - 1, now());
  assert.equal(g[0].k, 'gf.hypo'); assert.equal(g[0].sev, 'crit'); assert.equal(g[0].a.n, 2); assert.equal(g[0].a.l2, 1);
  // alert order
  const al = [{ id: 'a', st: 'ctrl', at: 5 }, { id: 'b', st: 'low', at: 3 }, { id: 'c', st: 'crit', at: 1 }, { id: 'd', st: 'crit', at: 9 }];
  const acked = { d: 100 };
  assert.equal([...al].sort(alertOrder(a => acked[a.id] ?? null)).map(a => a.id).join(''), 'cbad');
});

test('post-meal rise uses only matched real readings, never estimates', () => {
  const H = 3600, m0 = 100000;
  const rs = [{ v: 110, at: m0 - 0.5 * H }, { v: 170, at: m0 + 2 * H }];
  assert.deepEqual(matchMealRise(rs, [{ at: m0, carbs: 60 }]).map(x => x.rise), [60]);
  // no pre-meal reading within the hour before, or post-meal reading outside 90–150 min → left out
  assert.equal(matchMealRise([{ v: 110, at: m0 - 2 * H }, { v: 170, at: m0 + 2 * H }], [{ at: m0, carbs: 60 }]).length, 0);
  assert.equal(matchMealRise([{ v: 110, at: m0 - 0.5 * H }, { v: 170, at: m0 + 3 * H }], [{ at: m0, carbs: 60 }]).length, 0);
  // another meal before the post-meal reading → both meals left out (mixed rise)
  assert.equal(matchMealRise(rs, [{ at: m0, carbs: 60 }, { at: m0 + H, carbs: 20 }]).length, 0);
  // stored before/after values are ignored
  assert.equal(matchMealRise([], [{ at: m0, carbs: 60, before: 100, after: 180 }]).length, 0);
});

test('daily post-meal rise: sensor patient has values, manual-only new patient is insufficient', () => {
  const from = startOfDay() - 7 * DAY, to = startOfDay();
  const { p } = patient('crit'), days = dailyPostMealRise([p], series(p, from, to));
  assert.equal(days.length, 7);
  assert.ok(days.some(d => d.rise !== null) && days.every(d => d.n <= d.meals));
  for (const d of days) if (d.rise === null) assert.equal(d.n, 0);
  const { p: n } = patient('new'), nd = dailyPostMealRise([n], series(n, now() - 7 * DAY, now()));
  assert.ok(nd.every(d => d.rise === null));
});

test('nutrition summary accounts for every meal, including unmatched and unclassified ones', () => {
  const { p } = patient('all'), from = now() - 14 * DAY, to = now();
  // one meal without a carbohydrate value and one without a meal type must not disappear
  const extra = [{ id: 'x1', at: from + 3 * DAY + 13 * 3600, carbs: null, kcal: 300, type: 'lunch', name: 'x', items: [] },
    { id: 'x2', at: from + 4 * DAY + 16 * 3600, carbs: 30, kcal: 200, type: undefined, name: 'y', items: [] }];
  const q = { ...p, meals: [...p.meals, ...extra] };
  const ni = nutritionImpact([q], from, to), sum = xs => xs.reduce((s, x) => s + x, 0);
  const inRange = q.meals.filter(m => m.at >= from && m.at < to).length;
  assert.equal(ni.total, inRange);
  assert.equal(ni.matched + ni.unmatched, ni.total);
  assert.equal(sum(ni.bands.map(b => b.total)) + ni.noCarbs.total, ni.total);
  assert.equal(sum(ni.types.map(b => b.total)) + ni.otherType.total, ni.total);
  assert.equal(sum(ni.bands.map(b => b.n)) + ni.noCarbs.n, ni.matched);
  assert.ok(ni.noCarbs.total >= 1 && ni.otherType.total >= 1);
  // the rise is the mean of the matched pairs only
  const mean = ni.pairs.reduce((s, x) => s + x.rise, 0) / ni.pairs.length;
  assert.equal(ni.rise, Math.round(mean));
});

// ===== Default demo: three test patients (js/data/mock/demo-patients.js) =====
import { buildDemoData, demoReviewed } from '../js/data/mock/demo-patients.js';
const demoPatients = lang => {
  const d = buildDemoData({ lang });
  return Object.keys(d.patients).map(Number).map(id => {
    const p = { id, ...d.patients[id] };
    p.consultations = d.consultations[id];
    p.awaiting = !p.consultations.some(c => c.kind === 'initial');
    p.type = p.consultations.at(-1)?.dx?.type ?? null;
    p.protocolId = p.consultations.at(-1)?.protocol;
    p.targets = effectiveTargets(protocolOf(p), null);
    p.regimen = deriveRegimen(p.consultations);
    p.treat = treatmentKind(p.regimen.active);
    p.readings = cleanReadings(d.readings[id], targets(p));
    p.meals = d.meals[id]; p.doses = d.doses[id]; p.requests = d.requests[id];
    p.alerts = deriveAlerts(p.readings, p, now() - 10 * DAY);
    p.status = overallStatus(p, p.readings);
    const last = p.consultations.at(-1);
    p.followUp = last?.followUp?.at ? { ...last.followUp, cid: last.id } : null;
    return { p, chat: d.chat[id], raw: d };
  });
};

test('demo: three patients, statuses calculated from readings (Sobhi critical, Soso normal, Fofo controlled)', () => {
  const ps = demoPatients('en');
  assert.deepEqual(ps.map(x => [x.p.name, x.p.status]), [['Sobhi', 'crit'], ['Soso', 'ok'], ['Fofo', 'ctrl']]);
  // the raw data carries no status: it is always calculated
  for (const x of ps) assert.equal(x.raw.patients[x.p.id].status, undefined);
  assert.deepEqual(demoPatients('ar').map(x => x.p.name), ['صبحي', 'سوسو', 'فوفو']);
});

test('demo: Sobhi is his complete original record, unchanged (sample-data.js scenario "all")', () => {
  const orig = buildSampleData({ scenario: 'all' }), demo = buildDemoData({});
  for (const k of ['patients', 'readings', 'meals', 'consultations', 'doses', 'requests', 'ins', 'chat']) assert.deepEqual(demo[k][1], orig[k][1], k);
  assert.deepEqual(demo.reminders, orig.reminders);
});

test('demo: notifications are generated normally; only 2 are open (latest critical glucose alert + urgent request)', () => {
  const ns = demoPatients('en').flatMap(x => buildNotifications(x.p, x.chat));
  assert.ok(ns.length > 20, `generated ${ns.length}`);
  const rev = demoReviewed(ns, now());
  const open = ns.filter(n => !rev[n.pid]?.[n.id] && !n.auto);
  assert.deepEqual(open.map(n => [n.pid, n.kind, n.sev]).sort(), [[1, 'glucose', 'crit'], [1, 'request', 'warn']]);
  const latestCrit = ns.filter(n => n.kind === 'glucose' && n.sev === 'crit').sort((a, b) => b.at - a.at)[0];
  assert.ok(open.some(n => n.id === latestCrit.id));
  for (const m of Object.values(rev)) for (const ts of Object.values(m)) assert.ok(ts <= now());
});

test('demo: Soso and Fofo are minimal (readings, a few meals, no consultations, no alerts); reports follow the 14-day rule', () => {
  const ps = demoPatients('en'), [sobhi, soso, fofo] = ps.map(x => x.p);
  for (const p of [soso, fofo]) { assert.equal(p.consultations.length, 0); assert.equal(p.regimen.versions.length, 0); assert.equal(p.alerts.length, 0); assert.ok(p.meals.length <= 9); }
  // first report 14 days after the first reading, then weekly: Sobhi (21 days of data) 2, Soso and Fofo (16 days) 1
  assert.deepEqual([sobhi, soso, fofo].map(p => autoReports(p.readings).map(r => r.kind)), [['first', 'weekly'], ['first'], ['first']]);
});

test('dailyMinMax: lowest and highest reading per day, null for a day without readings', () => {
  const d0 = startOfDay(now()), d1 = d0 - DAY, d2 = d0 - 2 * DAY;   // today, yesterday, 2 days ago (midday below)
  const at = (d, hr) => startOfDay(d + 12 * 3600) + hr * 3600;
  const rs = [{ v: 137, at: at(d2, 8) }, { v: 235, at: at(d2, 14) }, { v: 180, at: at(d2, 20) },
    { v: 95, at: at(d0, 7) },
    { v: 400, at: at(d2, 0) - 3 * DAY }];                             // outside the 3-day window: ignored
  const out = dailyMinMax(rs, 3);
  assert.equal(out.length, 3);
  assert.deepEqual(out.map(([d]) => d), [startOfDay(at(d2, 12)), startOfDay(at(d1, 12)), d0]);
  assert.deepEqual(out.map(([, m]) => m), [{ min: 137, max: 235 }, null, { min: 95, max: 95 }]);
  assert.deepEqual(dailyMinMax([], 2).map(([, m]) => m), [null, null]);
});

test('Home priority order on the demo patients: Critical → Controlled → Normal', () => {
  const ps = demoPatients('en').map(x => { x.p.flags = interventionFlags(x.p); return x.p; });
  const order = [...ps].sort((a, b) => priorityCompare(a, b) || HOME_SORTS.name(a, b));
  assert.deepEqual(order.map(p => p.status), ['crit', 'ctrl', 'ok']);
  assert.deepEqual(order.map(p => p.name), ['Sobhi', 'Fofo', 'Soso']);
});

// ===== Patient link codes (js/core/linkcode.js) =====
import { makeLinkCode, ALPHABET, LINK_CODE_FORMAT, LINK_CODE_RE, LINK_CODE_LEN } from '../js/core/linkcode.js';
test('makeLinkCode: DMS-XXXX-XXXX-XX, no look-alike characters, unique, collisions drawn again', () => {
  assert.equal(ALPHABET.length, 31);
  assert.ok(!/[01OIL]/.test(ALPHABET));
  assert.ok(LINK_CODE_LEN >= 10);
  const N = 5000, codes = Array.from({ length: N }, () => makeLinkCode());
  for (const c of codes) {
    assert.match(c, LINK_CODE_FORMAT);
    assert.match(c, LINK_CODE_RE);                    // the check done before a QR is drawn
    assert.ok(!/[01OIL]/.test(c.slice(4)), c);        // after the "DMS-" prefix
  }
  assert.equal(new Set(codes).size, N);
  // Fake random source: bytes from 248 up are skipped (no bias); byte k gives ALPHABET[k % 31]
  const seq = (...bytes) => () => Uint8Array.from(bytes);
  assert.equal(makeLinkCode(seq(255, 248, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9)), 'DMS-2345-6789-AB');
  // A code that is already in use is drawn again
  let n = 0; const twice = () => Uint8Array.from({ length: 16 }, (_, i) => (n++ < 16 ? 0 : i));
  assert.equal(makeLinkCode(twice, ['DMS-2222-2222-22']), 'DMS-2345-6789-AB');
});
