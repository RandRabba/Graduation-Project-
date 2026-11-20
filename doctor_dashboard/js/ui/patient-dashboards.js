// The complete Glucose Monitoring and Nutrition dashboards for one patient, shared by the patient file tabs
// (patient.html#t-glu / #t-nut) and the standalone routes (glucose.html / meals.html).
// Each view only renders and wires; every number comes from the same core functions as before (clinical.js,
// analytics.js). The caller decides where the dashboard lives through `q` (its period / filters, with the keys
// r, from, to, src, day) and `link(o)` (the URL for changed values), so two dashboards can sit on one page with
// independent filters.
import { t, tt, ldate, DF, ltr } from '../core/i18n.js';
import { h, dash, signed, ic } from '../core/dom.js';
import { DAY } from '../core/time.js';
import { targets, glucoseStats, tirBreakdown, stRange, IMPACT } from '../core/clinical.js';
import { series, combineSeries, dailyPostMealRise, nutritionImpact, findings, gmi, hourlyProfile, alertOrder } from '../core/analytics.js';
import { PROTOCOLS } from '../core/protocols.js';
import { readingLabel, card, readRange, rangeControls, wireRange, empty, UNIT } from './components.js';
import { glucoseTimeChart, glucoseLegend, carbRisePanels, carbRiseLegend, carbRiseTable, wireTips, hbars, mealScatter, agpChart, agpLegend } from './charts.js';
import { tirSummary, mealLog, wireMealLog, alertBasis } from './clinical-ui.js';

// The query value of a period / filter with its own range keys, current values merged into every link
function periodOf(q, keys) {
  const rg = readRange(q, '14d', keys), custom = rg.key === 'custom';
  return { rg, base: { r: custom ? null : rg.key, from: custom ? rg.fromS : null, to: custom ? rg.toS : null } };
}

// ===== Glucose Monitoring =====
// Order: filters → 3 summary cards → one glucose trend (sensor line + manual markers only) → Time in Range
// → Glucose Alerts (compact) → Advanced Analysis (24-hour profile, collapsed) → Reading History (collapsed).
// p: the patient. extraCtl: page-only controls (the standalone patient selector).
// alerts: { href(a) → review URL, ackedAt(a) → review time or null } to list the patient's glucose alerts.
// presets: false shows only the From / To dates (patient file); the default period stays the last 14 days
export function monitoringView(p, { q, link, extraCtl = '', alerts = null, presets = true }) {
  const tg = targets(p), KEYS = ['24h', '7d', '14d', '30d'];
  const { rg, base } = periodOf(q, KEYS), { from, to } = rg, days = Math.max(1, Math.round((to - from) / DAY));
  const src = ['cgm', 'manual'].includes(q.get('src')) ? q.get('src') : 'all';
  const url = o => link({ ...base, src, ...o });
  const period = p.readings.filter(r => r.at >= from && r.at < to);
  const ns = period.filter(r => r.src === 'cgm').length, nm = period.length - ns;
  const rs = src === 'all' ? period : period.filter(r => r.src === src);
  const st = glucoseStats(rs, tg), cg = glucoseStats(period, tg), bd = tirBreakdown(period, tg);
  const covDays = new Set(period.filter(r => r.src === 'cgm').map(r => Math.floor((r.at - from) / DAY))).size, covPct = days > 1 ? Math.round(covDays / days * 100) : null;
  const seg = (items, cur, label) => `<div class="seg" role="group" aria-label="${label}">${items.map(([k, lb, c]) =>
    `<a href="${h(url(c))}" class="${k === cur ? 'on' : ''}"${k === cur ? ' aria-current="true"' : ''}>${lb}</a>`).join('')}</div>`;

  // Glucose alerts, compact: value, severity (hypoglycaemia is never shown as normal or controlled), time, episode
  // size, review. Unreviewed and most severe first; the rest behind "Show all"
  const sev = a => (a.st === 'crit' ? (a.v < tg.low ? 'crit_lo' : 'crit_hi') : a.st);
  const SEVCL = { crit_lo: 'b-crit', crit_hi: 'b-crit', low: 'b-low', ctrl: 'b-ctrl' };
  const al = alerts ? p.alerts.filter(a => a.at >= from && a.at < to).sort(alertOrder(alerts.ackedAt)) : [], SHOW = 5;
  const alertRow = (a, i) => { const ak = alerts.ackedAt(a), s = sev(a);
    return `<div class="arow"${i >= SHOW ? ' hidden data-more' : ''}>
      <bdi class="qty"><b class="v r-${a.st === 'crit' ? 'crit' : a.st}">${h(a.v)}</b> <span>${tt('unit.mgdl')}</span></bdi>
      <span class="pill ${SEVCL[s] ?? 'b-none'}">${tt('al.sev.' + s)}</span>
      <span class="when">${h(ldate(DF.DATE_TIME, a.at))}</span>
      <small>${a.n > 1 ? tt('ab.n', { n: a.n }) : ''}</small>
      <span class="act">${ak ? `<small>${tt('al.reviewed', { d: ldate(DF.DATE_TIME, ak) })}</small>` : `<a class="btn sm" href="${h(alerts.href(a))}">${tt('al.review')}</a>`}</span>
      ${alertBasis(p, a)}</div>`; };

  const html = `<div class="pdash mon${presets ? '' : ' nopre'}" data-dash="glu">
  <div class="bar"><h2>${t('glu.count', { name: h(p.name), n: `<span class="cnt">${rs.length}</span>` })}</h2>
    <div class="ctl">
      ${rangeControls(rg, url, presets ? KEYS : [])}
      ${seg([['all', tt('common.all'), period.length], ['cgm', tt('glu.sensor'), ns], ['manual', tt('glu.manual'), nm]].map(([k, lb, c]) => [k, `${lb} <em>${c}</em>`, { src: k }]), src, tt('glu.filter'))}
      ${extraCtl}
    </div></div>
  <p class="tgline">${tt('glu.target')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')} · ${tt('glu.goal')} ${ltr('> ' + tg.tir + '%')} · ${tt('prot.' + p.protocolId)}${PROTOCOLS[p.protocolId].reviewed ? '' : ` <span class="pill b-draft">${tt('prot.unreviewed')}</span>`}</p>

  <section class="stats three">
    ${card('c-avg', 'drop', t('glu.card.avg'), st.avg === null ? '—' : st.avg + UNIT(), st.avg ? tt('gmi.v', { v: gmi(st.avg) }) : '')}
    ${card('c-ok', 'clock', t('glu.card.tir'), covPct !== null && covPct < 70 ? '—' : dash(cg.tir, '%'),
      covPct !== null && covPct < 70 ? tt('home.no_cgm') : tt('glu.card.tir_sub', { g: tg.tir }))}
    ${card('c-info', 'report', t('glu.card.total'), rs.length, tt('mon.sm_sub', { s: ns, m: nm }))}
  </section>

  <section class="msec"><h2>${tt('mon.trend')}</h2>
    ${glucoseTimeChart({ rs, tg, from, to, label: t('mon.trend'), events: false })}
    ${glucoseLegend(tg, false)}</section>

  <section class="msec"><h2>${tt('glu.tir_title')}</h2>
    ${tirSummary(bd, tg)}
    ${bd && covPct !== null ? `<small class="note">${tt('glu.coverage', { d: covDays, n: days })}</small>${covPct < 70 ? `<p class="warn tirwarn">${tt('glu.coverage_low')}</p>` : ''}` : ''}</section>

  ${alerts ? `<section class="msec"><div class="bar"><h2>${tt('pf.glu_alerts')} <small class="hint">(${al.length})</small></h2>
      ${al.length > SHOW ? `<button type="button" class="lnk" data-allalerts aria-expanded="false">${tt('mon.all_alerts', { n: al.length })}</button>` : ''}</div>
    <div class="alist">${al.map(alertRow).join('') || empty('file.no_alerts')}</div></section>` : ''}

  <details class="msec adv"><summary><h2>${tt('mon.advanced')}</h2></summary>
    <h3 class="h3">${tt('chart.agp')}</h3>
    ${agpChart(hourlyProfile(period), tg, t('chart.agp'))}${agpLegend()}</details>

  <details class="msec adv"><summary><h2>${tt('glu.history')} <small class="hint">(${rs.length})</small></h2></summary>
    ${rs.length ? `<div class="tscroll"><table class="tbl sm"><thead><tr><th>${tt('ab.c.time')}</th><th>mg/dL</th><th>${tt('ab.c.src')}</th><th>${tt('mon.col.type')}</th><th>${tt('ab.c.class')}</th></tr></thead><tbody>
      ${rs.map(r => `<tr><td>${h(ldate(DF.DATE_TIME, r.at))}</td><td><b class="r-${r.st}">${h(r.v)}</b></td><td><span class="src s-${r.src === 'cgm' ? 'sensor' : 'manual'}">${tt(r.src === 'cgm' ? 'glu.sensor' : 'glu.manual')}</span></td><td>${h(r.type ?? '')}</td><td>${h(readingLabel(r.st))} ${ltr('(' + stRange(r.st, tg, r.v) + ')')}</td></tr>`).join('')}
    </tbody></table></div>` : empty('glu.none_period')}</details></div>`;
  // Wire THIS dashboard only (root = its container): custom dates, full alert list
  const wire = root => {
    wireRange(url, root);
    const more = root.querySelector('[data-dash=glu] [data-allalerts]');
    if (more) more.onclick = () => { const open = more.getAttribute('aria-expanded') !== 'true';
      root.querySelectorAll('[data-dash=glu] .arow[data-more]').forEach(r => { r.hidden = !open; });
      more.setAttribute('aria-expanded', open); more.textContent = open ? t('mon.fewer_alerts') : t('mon.all_alerts', { n: al.length }); };
  };
  return { html, wire, rg, period };
}

// ===== Nutrition =====
// scope: the patients included (one patient in the patient file; one or all on the standalone route).
// all: the patients by id, to name them in the meal log when several are shown.
// details: false leaves out the per-meal scatter (with its observed patterns) and the meal log — the patient file's
// Nutrition tab shows the summary only; the meal records stay in the data (standalone route keeps them)
// presets: false shows only the From / To dates (patient file); the default period stays the last 14 days.
// Every post-meal rise here (cards, daily chart, group charts, scatter) comes from the same matched readings
// (core/analytics matchMealRise); meals without them are counted as "insufficient data", never estimated.
export function nutritionView(scope, { q, link, all = null, extraCtl = '', details = true, presets = true }) {
  const KEYS = ['7d', '14d', '30d'];
  const { rg, base } = periodOf(q, KEYS), { from, to } = rg, nd = Math.max(1, Math.round((to - from) / DAY));
  const url = o => link({ ...base, ...o });
  const meals = scope.flatMap(p => p.meals.filter(m => m.at >= from && m.at < to).map(m => ({ ...m, pid: p.id }))).sort((a, b) => b.at - a.at);
  const bs = scope.length ? combineSeries(scope.map(p => series(p, from, to))) : [];
  const riseDays = dailyPostMealRise(scope, bs), ni = nutritionImpact(scope, from, to);
  const hasCarbs = m => Number.isFinite(m.carbs) && m.carbs >= 0, perDay = (xs, k) => {
    const ok = xs.filter(m => Number.isFinite(m[k])), dn = new Set(ok.map(m => `${m.pid}-${Math.floor(m.at / DAY)}`)).size;
    return dn ? Math.round(ok.reduce((s, m) => s + m[k], 0) / dn) : null; };
  const avgCarbs = perDay(meals, 'carbs'), avgKcal = perDay(meals, 'kcal');
  const withRise = ni.pairs.filter(x => hasCarbs(x.m)).map(x => ({ carbs: x.m.carbs, rise: x.rise, m: { ...x.m, before: x.pre.v, after: x.post.v } }));
  const fnd = scope.length === 1 ? findings(scope[0], from, to).filter(f => ['f.carb_bands', 'f.meal_type', 'f.post_meal_l2', 'f.carb_corr'].includes(f.k)) : [];
  // Group rows: matched meals of all meals in the group; unclassified groups only when they have meals
  const row = (label, g, sub) => ({ label, sub: sub(g), value: g.n ? g.rise : null, empty: g.total ? t('st2.insufficient') : t('nut.no_meals') });
  const bandRows = [...ni.bands.map(b => row(t('band.' + b.k), b, g => t('nut.matched_of', { n: g.n, t: g.total }))),
    ...(ni.noCarbs.total ? [row(t('nut.band_none'), ni.noCarbs, g => t('nut.matched_of', { n: g.n, t: g.total }))] : [])];
  const typeRows = [...ni.types.filter(x => x.total).map(x => row(t('mealtype.' + x.k), x, g => t('nut.matched_of', { n: g.n, t: g.total }) + (g.carbs === null ? '' : ' · ' + t('nut.avg_carbs', { c: g.carbs })))),
    ...(ni.otherType.total ? [row(t('nut.type_none'), ni.otherType, g => t('nut.matched_of', { n: g.n, t: g.total }))] : [])];
  const recon = ni.total ? `<p class="hint recon">${tt('nut.recon', { n: ni.matched, t: ni.total, u: ni.unmatched })}</p>` : '';
  const method = t('nut.rp.method');

  const html = `<div class="pdash nut${presets ? '' : ' nopre'}" data-dash="nut">
  <div class="bar"><h2>${tt('nut.count', { n: meals.length })}</h2>
    <div class="ctl">${rangeControls(rg, url, presets ? KEYS : [])}${extraCtl}</div></div>
  <p class="tgline">${tt('nut.range_note', { a: ldate(DF.DATE, from), b: ldate(DF.DATE, to - 1) })}</p>
  <section class="stats">
    ${card('c-avg', 'meal', t('nut.card.carbs'), avgCarbs === null ? '—' : `${avgCarbs} <span>${tt('unit.g')}</span>`, tt('pf.per_day'))}
    ${card('c-info', 'activity', t('nut.card.kcal'), avgKcal === null ? '—' : `${avgKcal} <span>${tt('meals.kcal')}</span>`, tt('pf.per_day'))}
    ${card('c-ctrl', 'trend', t('meals.card.rise'), ni.rise === null ? '—' : ltr(signed(ni.rise)) + UNIT(), (ni.total && !ni.matched ? tt('st2.insufficient') + ' · ' : '') + tt('nut.matched_of', { n: ni.matched, t: ni.total }))}
    ${card('c-high', 'alert', t('meals.card.hi'), ni.matched ? ni.high : '—', tt('nut.card.hi_sub2', { n: ni.matched, v: IMPACT.high }))}
  </section>

  ${bs.length && nd > 1 ? `<section class="cwide">
    <h2 class="sub hinfo">${tt('nut.trends')}<button type="button" class="infotip" data-tip="${h(method)}" aria-label="${h(t('nut.rp.how') + ': ' + method)}">${ic('info')}</button></h2>
    <p class="hint">${tt('nut.rp.short')}</p>
    ${carbRisePanels(riseDays, t('nut.trends'))}${carbRiseLegend()}${carbRiseTable(riseDays)}</section>` : ''}

  <div class="dgrid even">
    <section><h2 class="sub">${tt('nut.by_band')}</h2>${hbars(bandRows, { unit: ' mg/dL', signed: true, fit: true })}</section>
    <section><h2 class="sub">${tt('nut.by_type')}</h2>${hbars(typeRows, { unit: ' mg/dL', signed: true, fit: true })}</section>
  </div>
  ${recon}
  ${details ? `<h2 class="sub">${tt('nut.scatter')}</h2>
  ${mealScatter(withRise, t('nut.scatter'))}
  ${fnd.length ? `<ul class="findings">${fnd.map(f => `<li class="fi-${f.sev}">${h(t(f.k, { ...f.a, type: f.a.type ? t('mealtype.' + f.a.type) : '' }))}</li>`).join('')}</ul>` : ''}

  <h2 class="sub">${tt('nut.log')}</h2>
  ${mealLog(meals, { patients: scope.length > 1 ? all : null, limit: 15 })}` : ''}</div>`;
  const wire = root => { wireRange(url, root); wireTips(root); if (details) wireMealLog(); };
  return { html, wire, rg };
}
