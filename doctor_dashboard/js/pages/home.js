// Home: four counts and one patient list with status tabs, sorting and a name search. Analytics are on Statistics.
//
// Every number comes from the enriched patients (data/api.js). The tabs filter by the calculated clinical status
// only (Normal / Controlled / Critical); the status rules themselves are not changed here.
// Each row shows the patient's latest reading (all time, there is no date range on Home).
// Default sort: clinical priority (Critical → Controlled → Normal → not assessed, then the most urgent flags).
// URL: ?sort=…&q=…  The tab is not kept in the URL: Home always opens on All Patients.
import { mount } from '../ui/layout.js';
import { t, tt, ldate, DF } from '../core/i18n.js';
import { $, $$, h, ic, params, url } from '../core/dom.js';
import { needsReview, HOME_SORTS, priorityCompare } from '../core/analytics.js';
import { getPatients, getDoctor } from '../data/api.js';
import { readingLabel, statusPill, awaitingPill, patientMeta, avatar, UNIT, lower } from '../ui/components.js';

const list = Object.values(await getPatients()), q0 = params();
// Tabs: one test per tab, used for both its count and its rows. All Patients first and selected on every visit
const TABS = { all: () => true, crit: p => p.status === 'crit', ctrl: p => p.status === 'ctrl', ok: p => p.status === 'ok' };
// Default: clinical priority (core/analytics.js priorityCompare: Critical → Controlled → Normal, then the most
// urgent flags), ties by name. Then the sorts by the latest reading (HOME_SORTS, unchanged)
const SORTS = { priority: (a, b) => priorityCompare(a, b) || HOME_SORTS.name(a, b), ...HOME_SORTS };
const count = k => list.filter(TABS[k]).length;
let tab = 'all';
let sort = SORTS[q0.get('sort')] ? q0.get('sort') : 'priority';
const link = () => url('index.html', { sort: sort === 'priority' ? null : sort, q: $('#fq')?.value.trim() || null });
const greet = getDoctor().name;
// Search text per patient, computed once (fast with hundreds of patients)
for (const p of list) p._s = lower(p.name);

// Summary cards: Total and Critical also select their tab; the other two are counts only. Only Critical uses a
// status color; "Needing clinical review" is not a status, so it uses the neutral accent card (c-avg)
const sumCard = (k, cls, icon, label, sub, n) => `<${k ? `button type="button" data-f="${k}" aria-controls="att"` : 'div'} class="card sumcard ${cls}">
  <span class="ico">${ic(icon)}</span><span><small>${tt(label)}</small><b>${n}</b>${sub ? `<small class="csub">${sub}</small>` : ''}</span></${k ? 'button' : 'div'}>`;

await mount({ page: 'dashboard', title: t('dash.title'), heading: t('dash.greet.morning', { name: greet }), sub: '', greet }, `
  <section class="stats four" aria-label="${tt('home2.summary')}">
    ${sumCard('all', 'c-info', 'users', 'home.total', '', count('all'))}
    ${sumCard('crit', 'c-high', 'alert', 'stat.crit', '', count('crit'))}
    ${sumCard(null, 'c-await', 'calendar', 'cons.awaiting', '', list.filter(p => p.awaiting).length)}
    ${sumCard(null, 'c-avg', 'steth', 'home2.review', '', list.filter(needsReview).length)}
  </section>

  <section class="dsec att-sec" id="att" aria-labelledby="att-h">
    <div class="bar"><h2 id="att-h">${tt('home4.title')}</h2></div>
    <div class="ftabs" role="tablist" aria-label="${tt('home2.filter')}">
      ${Object.keys(TABS).map(k => `<button type="button" role="tab" id="tab-${k}" data-f="${k}" aria-controls="rows" class="ft ft-${k}">
        <span>${tt('home3.f.' + k)}</span><em>${count(k)}</em></button>`).join('')}
    </div>
    <div class="fbar">
      <label class="fl grow"><span>${tt('home.f.name')}</span><input type="search" id="fq" value="${h(q0.get('q') ?? '')}" placeholder="${tt('home.f.name_ph')}"></label>
      <label class="fl"><span>${tt('home.f.sort')}</span><select id="fsort">${Object.keys(SORTS).map(k => `<option value="${k}"${k === sort ? ' selected' : ''}>${tt('home4.sort.' + k)}</option>`).join('')}</select></label>
    </div>
    <div class="ptable att4" role="tabpanel" aria-labelledby="att-h">
      <div class="ph" role="row"><span role="columnheader">${tt('home.col.patient')}</span><span role="columnheader">${tt('home.col.status')}</span>
        <span role="columnheader">${tt('home4.col.last')}</span><span role="columnheader">${tt('home4.col.when')}</span><span></span></div>
      <div id="rows" aria-live="polite"></div>
    </div>
  </section>`);

// One row per patient; the background follows the current status (soft tint, see .pr.st-*)
function row(p) {
  const l = p.readings[0];
  return `<a class="pr st-${p.status ?? 'none'}" role="row" href="patient.html?id=${p.id}" aria-label="${tt('home2.open', { name: p.name })}">
    <span role="cell" class="who">${avatar(p.name)}<span><b dir="auto">${h(p.name)}</b><small>${tt('st2.pid', { id: p.id })} · ${h(patientMeta(p))}</small></span></span>
    <span role="cell" data-l="${tt('home.col.status')}"><span class="stblock">${statusPill(p.status)}${p.awaiting ? awaitingPill() : ''}</span></span>
    <span role="cell" data-l="${tt('home4.col.last')}">${l ? `<bdi class="qty"><b class="v r-${l.st}">${h(l.v)}</b>${UNIT()}</bdi>${l.st !== p.status ? `<small>${h(readingLabel(l.st))}</small>` : ''}` : `<small>${tt('common.no_data')}</small>`}</span>
    <span role="cell" data-l="${tt('home4.col.when')}">${l ? `<span class="when">${h(ldate(DF.DATE, l.at))}</span><small>${h(ldate(DF.TIME, l.at))}</small>` : '<small>—</small>'}</span>
    <span class="open">${tt('home2.open_btn')} ${tt('common.chev')}</span></a>`;
}

function render() {
  const q = lower($('#fq').value.trim());
  const rows = list.filter(p => TABS[tab](p) && (!q || p._s.includes(q))).sort(SORTS[sort]);
  $$('.ftabs [data-f]').forEach(b => { const on = b.dataset.f === tab; b.classList.toggle('on', on); b.setAttribute('aria-selected', on); b.tabIndex = on ? 0 : -1; });
  history.replaceState(null, '', link());
  const none = !list.length ? tt('empty.patients') : q ? tt('home.none_filter') : tt('home3.empty.' + tab);
  $('#rows').innerHTML = rows.map(row).join('') || `<p class="empty" role="status">${none}${tab !== 'all' && list.length ? ` <button type="button" class="lnk" data-show-all>${tt('home2.show_all')}</button>` : ''}</p>`;
  const sa = $('#rows [data-show-all]'); if (sa) sa.onclick = () => { tab = 'all'; $('#fq').value = ''; render(); };
}
const choose = (k, scroll) => { tab = k; render(); if (scroll) $('#att').scrollIntoView({ behavior: 'smooth', block: 'start' }); };
$$('.ftabs [data-f]').forEach(b => b.onclick = () => choose(b.dataset.f));
$$('.sumcard[data-f]').forEach(b => b.onclick = () => choose(b.dataset.f, true));
// Arrow keys move between tabs (tablist pattern), in reading order for both directions
$('.ftabs').addEventListener('keydown', e => {
  const keys = Object.keys(TABS), rtl = document.dir === 'rtl', i = keys.indexOf(tab);
  const step = { ArrowRight: rtl ? -1 : 1, ArrowLeft: rtl ? 1 : -1 }[e.key];
  const to = e.key === 'Home' ? 0 : e.key === 'End' ? keys.length - 1 : step ? (i + step + keys.length) % keys.length : null;
  if (to === null) return;
  e.preventDefault(); choose(keys[to]); $(`#tab-${keys[to]}`).focus();
});
$('#fsort').onchange = e => { sort = e.target.value; render(); };
$('#fq').oninput = render;
render();
