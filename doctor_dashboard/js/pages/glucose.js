// Standalone Glucose Monitoring route (glucose.html?p=&r=24h|7d|14d|30d or &from=&to=, &src=all|cgm|manual, &day=).
// The dashboard itself is shared with the patient file's Glucose Monitoring tab (ui/patient-dashboards.js), which is
// where the doctor normally sees it; this route is kept for existing links. Only this page shows the clinic-wide
// list of patients who may need intervention and a patient selector.
// Monitoring never changes treatment: the doctor documents a consultation for that.
import { mount } from '../ui/layout.js';
import { t, tt } from '../core/i18n.js';
import { $, h, ic, params, qint, url as link } from '../core/dom.js';
import { priorityCompare } from '../core/analytics.js';
import { getPatients, firstPatientId } from '../data/api.js';
import { statusBlock, flagChips, avatar, empty } from '../ui/components.js';
import { monitoringView } from '../ui/patient-dashboards.js';

const all = await getPatients();
const head = { page: 'patients', title: t('nav.glucose'), heading: t('nav.glucose'), sub: t('glu.sub') };
if (!firstPatientId(all)) {
  await mount(head, empty('empty.patients'));
} else {
  let id = qint('p', 1); if (!all[id]) id = firstPatientId(all);
  const p = all[id], q = params();
  const watch = Object.values(all).filter(x => x.flags.some(f => f.sev !== 'info')).sort(priorityCompare);
  const pick = Object.keys(all).length > 1 ? `<select id="pick" aria-label="${tt('common.select_patient')}">${Object.values(all).map(x => `<option value="${x.id}"${x.id === id ? ' selected' : ''}>${h(x.name)}</option>`).join('')}</select>` : '';
  const view = monitoringView(p, { q, link: o => link('glucose.html', { p: id, ...o }), extraCtl: pick });

  await mount(head, `
  <section class="watch" aria-labelledby="w-h"><h2 id="w-h">${ic('alert')} ${tt('mon.watch')}</h2>
    ${watch.map(x => `<a class="wrow ${x.id === id ? 'on' : ''}" href="${h(link('glucose.html', { p: x.id }))}">${avatar(x.name)}<b dir="auto">${h(x.name)}</b>${statusBlock(x)}${flagChips(x.flags.filter(f => f.sev !== 'info' && f.k !== 'crit_status'), 4)}</a>`).join('') || `<p class="txt">${tt('home.review_none')}</p>`}</section>
  ${view.html}`);

  view.wire(document);
  const sel = $('#pick');
  if (sel) sel.onchange = () => { location.href = link('glucose.html', { p: sel.value, r: view.rg.key === 'custom' ? null : view.rg.key, src: q.get('src') }); };
}
