// Statistics over one selected period (?r=7d|14d|30d or &from=&to=).
//  - Opens on the All Patients overview: the four status cards (current population, not date-dependent), the mean
//    Time in Range by status group, and short population warnings that link to the patients concerned.
//  - A patient search at the top (name or patient ID) opens one patient's statistics (?p=<id>): overview, glucose
//    trend (events on demand), meals and glucose change, medication adherence, and glucose around consultations.
// All values are calculated from the recorded data (core/analytics.js); nothing is filled in or invented.
import { mount } from '../ui/layout.js';
import { t, tt, ldate, DF, ltr, iso } from '../core/i18n.js';
import { $, $$, h, ic, params, qint, url } from '../core/dom.js';
import { DAY, now, ymd } from '../core/time.js';
import { targets } from '../core/clinical.js';
import { adherence } from '../core/medications.js';
import { mealImpact, findings, mean, tirByStatus, reliableTir, episodes, aroundConsultation } from '../core/analytics.js';
import { getPatients } from '../data/api.js';
import { LABS } from '../core/record.js';
import { PST, card, statusPill, awaitingPill, patientMeta, medDose, avatar, readRange, wireRange, empty, lower, consKind } from '../ui/components.js';
import { glucoseTimeChart, glucoseLegend, hbars, dataTable, tirStatusBars, carbBandChart, consultChart, consultLegend, wireTips } from '../ui/charts.js';

const all = await getPatients(), list = Object.values(all), q = params();
let sel = qint('p', 0); if (sel && !all[sel]) sel = 0;
const rg = readRange(q, '14d'), { from, to } = rg, span = to - from, nd = Math.max(1, Math.round(span / DAY));
const custom = rg.key === 'custom';
const link = o => url('statistics.html', { p: sel, r: custom ? null : rg.key, from: custom ? rg.fromS : null, to: custom ? rg.toS : null, ...o });
const head = { page: 'stats', title: t('nav.stats'), heading: t('nav.stats'), sub: t('st2.sub') };
const pct = (n, of) => (of ? Math.round(n / of * 100) : 0);

// ===== Top: patient search, then one date range for the whole page =====
// Searchable selector: filters in memory by name or patient ID and lists at most 8 matches, so it stays usable with
// hundreds of patients (the full list is never rendered)
const searchBar = p => `<div class="psel">
  <label for="pq">${tt('st3.search')}</label>
  <div class="combo"><input id="pq" type="search" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="pql" autocomplete="off" dir="auto" placeholder="${tt('st2.pick_ph')}">
    <ul id="pql" role="listbox" aria-label="${tt('st2.pick')}" hidden></ul></div>
  ${p ? `<div class="pchosen">${avatar(p.name)}<div><b><bdi>${h(p.name)}</bdi></b><small>${tt('st2.pid', { id: p.id })} · ${h(patientMeta(p))}</small></div>
    <span class="stblock">${statusPill(p.status)}${p.awaiting ? awaitingPill() : ''}</span><a class="lnk" href="patient.html?id=${p.id}">${tt('st2.open_file')}</a></div>
    <a class="btn ghost sm back" href="${h(link({ p: null }))}">${tt('st3.back')}</a>` : ''}
</div>`;
const rangeBar = `<div class="filters strange">
  <div class="fl"><span>${tt('range.label')}</span><div class="ctl">
    <div class="seg" role="group" aria-label="${tt('range.label')}">${['7d', '14d', '30d'].map(k =>
      `<a href="${h(link({ r: k, from: null, to: null }))}" class="${rg.key === k ? 'on' : ''}"${rg.key === k ? ' aria-current="true"' : ''}>${tt('st2.r.' + k)}</a>`).join('')}
      <button type="button" id="custBtn" class="${custom ? 'on' : ''}" aria-expanded="${custom}" aria-controls="custForm">${tt('st2.r.custom')}</button></div>
    <form class="dates" data-range id="custForm"${custom ? '' : ' hidden'}>
      <label><span>${tt('range.from')}</span><input type="date" name="from" value="${h(rg.fromS)}" max="${ymd(now())}" required></label>
      <label><span>${tt('range.to')}</span><input type="date" name="to" value="${h(rg.toS)}" max="${ymd(now())}" required></label>
      <button class="btn sm" type="submit">${tt('range.apply')}</button></form></div></div>
  <p class="speriod">${ic('calendar')} ${tt('st2.period', { a: ldate(DF.DATE, from), b: ldate(DF.DATE, to - 1), n: nd })}</p></div>`;

// A key measure with its change against the previous period of the same length (better / worse in words)
const tile = (label, v, pv, unit, better, { digits = 0, note = '', na = '' } = {}) => {
  const d = v !== null && pv !== null ? Math.round((v - pv) * 10 ** digits) / 10 ** digits : null;
  const good = d === null || d === 0 ? null : (better === 'up') === (d > 0);
  return `<div class="tile"><small>${h(label)}</small><b>${v === null ? `<span class="na">${h(na || t('common.no_data'))}</span>` : ltr(v + unit)}</b>
    ${v === null ? '' : `<span class="delta ${good === null ? '' : good ? 'up' : 'down'}">${d === null ? tt('stats.no_prev') : d === 0 ? tt('stats.same') : `${ltr((d > 0 ? '+' : '') + d + unit)} · ${tt(good ? 'stats.better' : 'stats.worse')}`}</span>`}
    ${note ? `<small class="tnote">${note}</small>` : ''}</div>`;
};

// ===== All patients =====
function allPatients() {
  const n = list.length, cnt = st => list.filter(p => p.status === st).length, unc = list.filter(p => !p.status).length;
  const statusCard = (cls, icon, st) => card(cls, icon, t('st2.card.' + st), cnt(st), tt('st2.of_total', { v: pct(cnt(st), n) }));
  const goals = new Set(list.map(p => targets(p).tir)), goal = goals.size === 1 ? [...goals][0] : null;
  const groups = tirByStatus(list, from, to);
  // Population warnings: who, not how many (the cards already give the counts). Shown only when someone matches
  const rep = list.filter(p => { const e = episodes(p, from, to); return [...e.high, ...e.low].filter(x => x.l2).length >= 2; });
  const tbr = list.filter(p => { const r = reliableTir(p, from, to); return r && r.tbr >= r.tbrGoal; });
  const chips = ps => ps.slice(0, 12).map(p => `<a class="pchip" href="${h(link({ p: p.id }))}"><bdi>${h(p.name)}</bdi></a>`).join('') + (ps.length > 12 ? `<span class="pchip more">+${ps.length - 12}</span>` : '');
  const warn = [['st3.w.rep', rep, 'crit'], ['st3.w.tbr', tbr, 'warn']].filter(([, ps]) => ps.length);
  return `
  <section class="stats four" aria-label="${tt('st2.cards')}">
    ${card('c-info', 'users', t('st2.card.total'), n, tt('st2.current'))}
    ${statusCard('c-ok', 'check', 'ok')}${statusCard('c-ctrl', 'activity', 'ctrl')}${statusCard('c-high', 'alert', 'crit')}
  </section>
  ${unc ? `<p class="hint snote">${tt('st2.unclassified', { n: unc })}</p>` : ''}
  ${warn.length ? `<section class="pwarn" aria-label="${tt('st3.w.title')}">${warn.map(([k, ps, sev]) => `<div class="pw pw-${sev}">${ic('alert')}<b>${tt(k)}</b><span class="pchips">${chips(ps)}</span></div>`).join('')}</section>` : ''}
  <section class="spanel single"><h2>${tt('st2.tir')}</h2><p class="hint">${tt('st3.tir_note')}</p>
    ${tirStatusBars(groups, goal, t('st2.tir'))}
    ${dataTable([t('home.col.status'), t('st2.col_tir'), t('st2.col_eligible')], groups.map(g => [PST[g.st], g.tir === null ? t('st2.insufficient') : g.tir + '%', `${g.n} / ${g.total}`]))}</section>`;
}

// Laboratory results over time: every recorded lab of the patient, one column per date, with units.
// Each consultation still shows its own results in the patient file
const labTable = p => {
  if (!p.labs.length) return `<p class="txt">${tt('stats.no_labs')}</p>`;
  const dates = [...new Set(p.labs.map(l => l.at))].sort((a, b) => a - b), tests = [...new Set(p.labs.map(l => l.test))];
  return `<div class="tscroll"><table class="tbl"><thead><tr><th>${tt('cf.lab_test')}</th>${dates.map(a => `<th>${h(ldate(DF.DATE, a))}</th>`).join('')}</tr></thead><tbody>
    ${tests.map(k => `<tr><td>${tt('lab.' + k)} <small>${ltr(LABS[k] ?? '')}</small></td>${dates.map(a => { const l = p.labs.find(x => x.test === k && x.at === a); return `<td>${l ? ltr(String(l.v)) : '—'}</td>`; }).join('')}</tr>`).join('')}</tbody></table></div>`;
};

// ===== One patient =====
function onePatient(p) {
  const tg = targets(p), inP = x => x.at >= from && x.at < to, pf = from - span, inPrev = x => x.at >= pf && x.at < from;
  const rs = p.readings.filter(inP), prs = p.readings.filter(inPrev);
  const avg = v => (v.length ? Math.round(mean(v.map(r => r.v))) : null);
  const tir = reliableTir(p, from, to), ptir = reliableTir(p, pf, from);
  const ep = episodes(p, from, to), pep = episodes(p, pf, from);
  const cgmDays = new Set(rs.filter(r => r.src === 'cgm').map(r => Math.floor((r.at - from) / DAY))).size;
  const fnd = findings(p, from, to).filter(f => ['f.night_lows', 'f.fasting_high'].includes(f.k));
  const verOf = d => p.regimen.versions.find(x => x.id === d.ver) ?? p.regimen.versions.filter(x => x.rx === d.rx).at(-1);
  const doseLabel = d => { const v = verOf(d); return v ? `${iso(v.drug)} ${medDose(v)}` : d.rx; };
  const marks = p.consultations.map(c => ({ at: c.at, short: t(c.kind === 'initial' ? 'chart.mark_c1' : 'chart.mark_c'), label: `${consKind(c.kind)} · ${ldate(DF.DATE, c.at)}` }));
  const meals = p.meals.filter(inP), mi = mealImpact(meals), doses = p.doses.filter(inP);
  // Adherence per medication from the dose log (taken = confirmed by the patient)
  const byRx = [...new Set(doses.map(d => d.rx))].map(rx => { const a = adherence(p.doses, from, to, rx), v = p.regimen.versions.filter(x => x.rx === rx).at(-1);
    return { label: v?.drug ?? rx, sub: t('med.adh_7', { a: a.taken, b: a.scheduled }), value: a.pct, cls: 's-adh' }; });
  // Consultations in the period (or the latest one before it), up to the 4 most recent, oldest first
  const cons = [...p.consultations].sort((a, b) => a.at - b.at);
  let shown = cons.filter(c => c.at >= from && c.at < to);
  if (!shown.length && cons.some(c => c.at < from)) shown = [cons.filter(c => c.at < from).at(-1)];
  const prog = shown.slice(-4).map(c => ({ label: consKind(c.kind), at: c.at, ...aroundConsultation(p, c, cons[cons.indexOf(c) + 1]) }));
  const EV = [['meal', 'mon.lg_meal'], ['miss', 'mon.lg_missed'], ['cons', 'mon.lg_cons']];

  return `
  <section class="ssec first"><h2>${tt('st2.p.overview')}</h2>
    <p class="hint">${tt('st2.p.overview_note', { n: rs.length, c: cgmDays, d: nd })} · ${tt('glu.target')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')}</p>
    <section class="tiles">
      ${tile(t('card.avg'), avg(rs), avg(prs), ' mg/dL', 'down')}
      ${tile(t('card.tir'), tir?.tir ?? null, ptir?.tir ?? null, '%', 'up', { na: t('st2.insufficient'), note: tir ? '' : tt('st2.tir_rule') })}
      ${tile(t('st2.p.high_ep'), ep.high.length, pep.high.length, '', 'down', { note: tt('st2.p.l2_hi', { n: ep.high.filter(e => e.l2).length, v: tg.vhigh }) })}
      ${tile(t('st2.p.low_ep'), ep.low.length, pep.low.length, '', 'down', { note: tt('st2.p.l2_lo', { n: ep.low.filter(e => e.l2).length, v: tg.vlow }) })}
    </section>
  </section>

  <section class="ssec"><div class="bar"><h2>${tt('st2.p.trend')}</h2>
    <fieldset class="evtoggle"><legend>${tt('st3.events')}</legend>${EV.map(([k, l]) => `<label><input type="checkbox" data-ev="${k}"> ${tt(l)}</label>`).join('')}</fieldset></div>
    <div class="gwrap" id="gwrap" data-hide="meal miss cons">
      ${glucoseTimeChart({ rs: p.readings, tg, from, to, meals, doses: doses.map(d => ({ ...d, label: doseLabel(d) })), marks, label: t('st2.p.trend') })}</div>
    ${glucoseLegend(tg, false)}
    ${fnd.length ? `<ul class="findings">${fnd.map(f => `<li class="fi-${f.sev}">${h(t(f.k, f.a))}</li>`).join('')}</ul>` : ''}
  </section>

  <div class="sgrid">
    <section class="spanel"><h2>${tt('st2.p.nutrition')}</h2><p class="hint">${tt('ch.carb_note')}</p>
      ${mi.bands.some(b => b.n) ? carbBandChart(mi.bands, t('st2.p.nutrition')) : `<p class="txt">${tt('st2.p.no_rise')}</p>`}</section>
    <section class="spanel"><h2>${tt('st2.p.adh')}</h2><p class="hint">${tt('st3.adh_note')}</p>
      ${byRx.length ? hbars(byRx, { unit: '%', max: 100 }) : `<p class="txt">${tt(p.regimen.active.length ? 'st2.p.no_doses' : 'stats.no_rx')}</p>`}</section>
  </div>

  <section class="spanel sprog"><h2>${tt('st3.prog')}</h2><p class="hint">${tt('st3.prog_note')}</p>
    ${prog.length ? `${consultChart(prog, tg, t('st3.prog'))}${consultLegend(tg)}` : `<p class="txt">${tt('st2.p.no_cons')}</p>`}</section>

  <section class="spanel slabs"><h2>${tt('cons.labs_trend')}</h2>
    ${labTable(p)}</section>`;
}

if (!list.length) {
  await mount(head, empty('empty.patients'));
} else {
  const p = sel ? all[sel] : null;
  await mount(head, `${searchBar(p)}${rangeBar}${p ? onePatient(p) : allPatients()}`);

  wireRange(link);
  wireTips();
  $('#custBtn').onclick = e => { const f = $('#custForm'); f.hidden = !f.hidden; e.currentTarget.setAttribute('aria-expanded', !f.hidden); if (!f.hidden) f.elements.from.focus(); };
  // Optional chart events (meals, missed doses, consultations): hidden by default, shown on demand
  const gw = $('#gwrap');
  if (gw) $$('[data-ev]').forEach(c => c.onchange = () => { gw.dataset.hide = $$('[data-ev]').filter(x => !x.checked).map(x => x.dataset.ev).join(' '); });

  // Patient search (combobox): arrow keys move, Enter opens, Escape closes
  const inp = $('#pq'), box = $('#pql'), MAX = 8, idx = list.map(x => ({ x, s: lower(x.name), id: String(x.id) }));
  let hits = [], cur = -1;
  const close = () => { box.hidden = true; inp.setAttribute('aria-expanded', 'false'); inp.removeAttribute('aria-activedescendant'); cur = -1; };
  const choose = x => { location.href = link({ p: x.id }); };
  const mark = () => { $$('#pql [role=option]').forEach((o, i) => o.setAttribute('aria-selected', i === cur)); if (cur >= 0) inp.setAttribute('aria-activedescendant', 'po-' + cur); };
  const render = () => {
    const v = lower(inp.value.trim()).replace(/^#/, '');
    if (!v) { close(); return; }
    const m = idx.filter(e => e.s.includes(v) || e.id === v || e.id.startsWith(v));
    hits = m.slice(0, MAX).map(e => e.x); cur = hits.length ? 0 : -1;
    box.innerHTML = hits.map((x, i) => `<li role="option" id="po-${i}" data-id="${x.id}"><b><bdi>${h(x.name)}</bdi></b><small>${tt('st2.pid', { id: x.id })}</small>${statusPill(x.status)}</li>`).join('')
      + (!m.length ? `<li class="none">${tt('st2.pick_none')}</li>` : m.length > MAX ? `<li class="none">${tt('st2.pick_more', { n: m.length - MAX })}</li>` : '');
    box.hidden = false; inp.setAttribute('aria-expanded', 'true'); mark();
  };
  inp.addEventListener('input', render);
  inp.addEventListener('keydown', e => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') { e.preventDefault(); if (hits.length) { cur = (cur + (e.key === 'ArrowDown' ? 1 : hits.length - 1)) % hits.length; mark(); } }
    else if (e.key === 'Enter') { e.preventDefault(); if (hits[cur]) choose(hits[cur]); }
    else if (e.key === 'Escape') close();
  });
  box.addEventListener('mousedown', e => { const o = e.target.closest('[data-id]'); if (o) { e.preventDefault(); choose(all[o.dataset.id]); } });
  inp.addEventListener('blur', () => setTimeout(close, 120));
}
