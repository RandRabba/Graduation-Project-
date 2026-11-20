// Standalone Nutrition route (meals.html?p=<patient or 0 for all>&r=7d|14d|30d or &from=&to=).
// The dashboard itself is shared with the patient file's Nutrition tab (ui/patient-dashboards.js), which is where
// the doctor normally sees it; this route is kept for existing links and adds a patient selector (one or all).
import { mount } from '../ui/layout.js';
import { t, tt } from '../core/i18n.js';
import { $, h, params, qint, url } from '../core/dom.js';
import { getPatients } from '../data/api.js';
import { nutritionView } from '../ui/patient-dashboards.js';

const all = await getPatients(), list = Object.values(all), q = params();
let sel = qint('p', list.length === 1 ? list[0].id : 0); if (sel && !all[sel]) sel = 0;
const scope = sel ? [all[sel]] : list;
const pick = `<select id="pick" aria-label="${tt('common.select_patient')}">
  ${list.length > 1 ? `<option value="0">${tt('common.all_patients')}</option>` : ''}
  ${list.map(p => `<option value="${p.id}"${sel === p.id ? ' selected' : ''}>${h(p.name)}</option>`).join('')}</select>`;
const view = nutritionView(scope, { q, all, link: o => url('meals.html', { p: sel, ...o }), extraCtl: pick });

await mount({ page: 'patients', title: t('nav.meals'), heading: t('nav.meals'), sub: t('meals.sub') }, view.html);

view.wire(document);
$('#pick').onchange = e => {
  const r = view.rg.key === 'custom' ? { from: view.rg.fromS, to: view.rg.toS } : { r: view.rg.key };
  location.href = url('meals.html', { p: Number(e.target.value), ...r });
};
