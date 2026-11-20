// Reports (health_reports.php): the list of generated medical reports, and one report (?p=&r=) that can be
// printed or saved as PDF. The first report arrives 14 days after the patient's first glucose reading,
// then a weekly report every 7 days (see autoReports in core/clinical.js).
import { mount } from '../ui/layout.js';
import { t, tt, ldate, DF, dateRange, ltr } from '../core/i18n.js';
import { $, h, ic, dash, signed, params, qint, url } from '../core/dom.js';
import { DAY, startOfDay } from '../core/time.js';
import { targets, glucoseStats, dailyAverages, tirBreakdown, cgmCoverage, periodStatus } from '../core/clinical.js';
import { matchedPairs } from '../core/analytics.js';
import { adherence } from '../core/medications.js';
import { tirSummary } from '../ui/clinical-ui.js';
import { getPatients, getDoctor, reportSeen, markReportSeen } from '../data/api.js';
import { statusPill, statusSource, patientMeta, alertTitle, reportTitle, avatar, card, avgChart, medDose, lower, empty, UNIT, auto, consKind } from '../ui/components.js';

const all = await getPatients(), pid = qint('p'), rid = params().get('r');
const rp = pid && all[pid] ? all[pid].reports.find(r => r.id === rid) : null;
// Opening a report means the doctor received it; recorded before drawing so the counter updates at once
if (rp) await markReportSeen(pid, rp.id);
const head = { page: 'reports', title: t('nav.reports'), heading: t('nav.reports'), sub: t('hr.sub') };

if (rp) {
  const p = all[pid], doc = getDoctor();
  // Calendar days from the day of the first reading to the day it was sent
  const start = rp.from, end = rp.to, days = Math.round((startOfDay(end - 1) - startOfDay(start)) / DAY) + 1;
  const period = dateRange(start, end - 1);
  // Everything in the report is calculated only from the patient's data recorded inside the report period
  const inP = x => x.at >= start && x.at < end;
  const rs = p.readings.filter(inP), s = glucoseStats(rs, targets(p));
  // Time in range only with enough sensor data (70% of the period's days), the same rule as everywhere else
  const cov = cgmCoverage(rs, days, end), tirOk = cov.ok && s.tir !== null;
  // Status of the report period (sensor data of the period, same goals); the patient's current status is shown apart
  const pst = cov.ok ? periodStatus(p, rs) : null;
  // Glucose change after meals: matched readings before and ~2 h after each meal, the same method as the
  // Nutrition tab (core/analytics matchMealRise); meals without both readings are counted, not estimated
  const m = p.meals.filter(inP), nm = m.length, pairs = matchedPairs([p], start, end);
  const withC = m.filter(x => Number.isFinite(x.carbs)), avgC = withC.length ? Math.round(withC.reduce((a, x) => a + x.carbs, 0) / withC.length) : null;
  const avgD = pairs.length ? Math.round(pairs.reduce((a, q) => a + q.rise, 0) / pairs.length) : null;
  const ad = adherence(p.doses, start, end), cons = p.consultations.filter(inP);
  const txOf = c => p.regimen.versions.filter(v => v.cid === c.id).map(v => { const pv = p.regimen.versions.find(x => x.id === v.prev);
    return `${t('medact.' + v.act)}: ${v.drug} ${pv ? medDose(pv) + ' → ' : ''}${medDose(v)}${v.reason ? ' (' + v.reason + ')' : ''}`; });
  const al = p.alerts.filter(inP), ins = p.ins.filter(i => Number.isFinite(i[1]) && i[1] >= start && i[1] < end);
  const rowOf = (cls, icon, title, sub, dirAuto = false) => `<div class="row ${cls}"><div class="who"><div class="ico">${ic(icon)}</div><div><b>${dirAuto ? auto(title) : h(title)}</b><small>${h(sub)}</small></div></div><span></span><span></span><span></span></div>`;

  await mount(head, `
  <div class="noprint bar"><a class="btn ghost" href="reports.html">${tt('hr.back')}</a>
    <button class="btn" id="print">${tt('hr.print')}</button></div>

  <div class="card c-info head">
    ${avatar(p.name, 'avatar big')}
    <div><b class="nm">${h(reportTitle(rp))}</b><small>${h(p.name)} · ${h(patientMeta(p))}</small><small>${tt('hr.period', { p: period, doc: doc.name })}</small>${rp.kind === 'first' ? `<small>${tt('hr.auto')}</small>` : rp.kind === 'weekly' ? `<small>${tt('hr.auto_weekly')}</small>` : ''}</div>
    <span class="stblock"><small>${tt('hr.st_period')}</small>${pst ? statusPill(pst) : `<span class="pill b-none">${tt('home.no_cgm')}</span>`}
      <small>${tt('hr.st_now')}</small>${statusPill(p.status)}<small>${statusSource(p)}</small></span>
  </div>

  <section class="stats">
    ${card('c-avg', 'drop', t('card.avg'), s.avg === null ? '—' : s.avg + UNIT())}
    ${card('c-ok', 'clock', t('card.tir'), tirOk ? dash(s.tir, '%') : '—', tirOk ? '' : tt('home.no_cgm'))}
    ${card('c-ctrl', 'alert', t('card.high'), dash(s.high, '%'))}
    ${card('c-high', 'drop', t('card.low'), dash(s.low, '%'))}
    ${card('c-info', 'report', t('card.total'), s.total)}
  </section>

  <h2 class="sub">${tt('chart.daily')}</h2>
  ${avgChart(dailyAverages(rs, days, end - 1), t('chart.daily'))}
  <small class="note">${tt('chart.band')}</small>

  <h2 class="sub">${tt('glu.tir_title')}</h2>
  ${cov.ok ? tirSummary(tirBreakdown(rs, targets(p)), targets(p)) : `<p class="txt">${tt('hr.tir_insuf', { d: cov.days, n: days })}</p>`}

  <h2 class="sub">${tt('hr.adh')}</h2>
  <p class="txt">${ad.scheduled ? tt('hr.adh_sum', { p: ad.pct, a: ad.taken, b: ad.scheduled, m: ad.missed }) : tt('hr.no_adh')}</p>

  <h2 class="sub">${tt('hr.cons')}</h2>
  <div class="list">${cons.map(c => rowOf('info', 'steth', `${consKind(c.kind)} · ${ldate(DF.DATE, c.at)}`, [c.plan, ...txOf(c)].filter(Boolean).join(' · '), true)).join('') || `<p class="txt">${tt('hr.no_cons')}</p>`}</div>

  <h2 class="sub">${tt('hr.meals')}</h2>
  <p class="txt">${!nm ? tt('hr.no_meals') : pairs.length ? t('hr.meals_sum2', { n: nm, c: dash(avgC), d: ltr(signed(avgD)), k: pairs.length })
    : t('hr.meals_sum_insuf', { n: nm, c: dash(avgC) })}</p>

  <h2 class="sub">${tt('hr.alerts')}</h2>
  <div class="list">${al.map(a => rowOf(a.st, 'alert', alertTitle(a), ldate(DF.DATE_TIME, a.at))).join('') || `<p class="txt">${tt('hr.no_alerts')}</p>`}</div>

  <h2 class="sub">${tt('hr.ins')}</h2>
  <div class="list">${ins.map(i => rowOf('ok', 'steth', i[0], ldate(DF.DATE_TIME, i[1]), true)).join('') || `<p class="txt">${tt('hr.no_ins')}</p>`}</div>`);

  // Print / save as PDF from the browser's print dialog (the sidebar and controls are hidden in print)
  $('#print').onclick = () => window.print();
} else {
  const items = Object.values(all).filter(p => !pid || pid === p.id)
    .flatMap(p => p.reports.map(r => ({ pid: p.id, rid: r.id, t: reportTitle(r), kind: r.kind, pt: p.name, ts: r.at, isNew: !reportSeen(p.id, r) })))
    .sort((a, b) => b.ts - a.ts);
  await mount(head, `
  <div class="bar"><h2>${tt('hr.count', { n: items.length })}</h2>
    <select id="pick" aria-label="${tt('common.select_patient')}">
      <option value="0">${tt('common.all_patients')}</option>
      ${Object.values(all).map(x => `<option value="${x.id}"${pid === x.id ? ' selected' : ''}>${h(x.name)}</option>`).join('')}
    </select></div>
  <div class="list">
    ${items.map(it => `<a class="row pl ok" href="${h(url('reports.html', { p: it.pid, r: it.rid }))}" data-s="${h(lower(it.t + ' ' + it.pt))}">
        <div class="who"><div class="ico">${ic('report')}</div><div><b>${h(it.t)}</b><small>${h(it.pt)}</small></div></div>
        <div class="val"><span>${h(ldate(DF.DATE, it.ts))}</span></div>
        <div class="stat"><span class="pill b-ok">${tt('rep.kind.' + it.kind)}</span>${it.isNew ? ` <span class="pill b-new">${tt('hr.new')}</span>` : ''}</div><span>${tt('common.chev')}</span></a>`).join('') || empty('hr.none')}
  </div>`);
  $('#pick').onchange = e => { location.href = url('reports.html', { p: Number(e.target.value) }); };
}
