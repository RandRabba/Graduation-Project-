// Reminders: patient, system and doctor reminders; the doctor can add reminders and delete her own.
import { mount, wireSegFilter } from '../ui/layout.js';
import { t, tt } from '../core/i18n.js';
import { $, h, qint, url } from '../core/dom.js';
import { now, addDays, ymd, toLocalInput, fromLocalInput } from '../core/time.js';
import { getPatients, getReminders, addReminder, deleteReminder } from '../data/api.js';
import { go } from '../ui/nav.js';
import { RTYPE, RREP, RST, card, remRow, empty } from '../ui/components.js';

const all = await getPatients(), sel = qint('p');
const back = url('reminders.html', { p: sel });
const items = (await getReminders()).filter(r => !sel || r.pid === sel);
const cnt = st => items.filter(r => r.st === st).length;
const nToday = items.filter(r => r.st === 'up' && ymd(r.at) === ymd(now())).length;
const nWeek = items.filter(r => r.st === 'up' && r.at < addDays(now(), 7)).length;
const nDone = cnt('done'), nMiss = cnt('missed');
const adh = nDone + nMiss ? Math.round(nDone / (nDone + nMiss) * 100) + '%' : '—';
// Medication reminders come only from prescriptions (consultations), visit reminders from the planned follow-up
const FORM_TYPES = Object.fromEntries(Object.entries(RTYPE).filter(([k]) => !['med', 'visit'].includes(k)));
const opts = (map, cur) => Object.entries(map).map(([k, v]) => `<option value="${k}"${k === cur ? ' selected' : ''}>${h(Array.isArray(v) ? v[1] : v)}</option>`).join('');

await mount({ page: 'reminders', title: t('nav.reminders'), heading: t('nav.reminders'), sub: t('rem.sub') }, `
  <div class="bar"><h2>${t('rem.count', { n: `<span id="cnt">${items.length}</span>` })}</h2>
    <div class="ctl">
      <div class="seg" role="group" aria-label="${tt('rem.filter')}">
        <button data-f="all" class="on" aria-pressed="true">${tt('common.all')}</button>${Object.entries(RST).map(([k, v]) => `<button data-f="${k}" aria-pressed="false">${h(v)}</button>`).join('')}
      </div>
      <select id="pick" aria-label="${tt('common.select_patient')}">
        <option value="0">${tt('common.all_patients')}</option>
        ${Object.values(all).map(x => `<option value="${x.id}"${sel === x.id ? ' selected' : ''}>${h(x.name)}</option>`).join('')}
      </select></div></div>

  <section class="stats">
    ${card('c-avg', 'calendar', t('rem.card.today'), nToday)}
    ${card('c-info', 'clock', t('rem.card.week'), nWeek)}
    ${card('c-high', 'xcircle', t('rem.card.missed'), nMiss)}
    ${card('c-ok', 'check', t('rem.card.adh'), adh)}
  </section>

  <h2 class="sub" id="new">${tt('rem.new')}</h2>
  <form class="rform" id="rform" novalidate>
    <p class="warn" id="err" hidden></p>
    <label>${tt('rem.patient')}<select name="pid" required>
      <option value="">${tt('rem.choose')}</option>
      ${Object.values(all).map(x => `<option value="${x.id}"${sel === x.id ? ' selected' : ''}>${h(x.name)}</option>`).join('')}
    </select></label>
    <label>${tt('rem.type')}<select name="type">${opts(FORM_TYPES, 'glu')}</select></label>
    <label class="wide">${tt('rem.title')}<input name="title" dir="auto" required maxlength="120" placeholder="${tt('rem.title_ph')}"></label>
    <label>${tt('rem.at')}<input type="datetime-local" name="at" required min="${toLocalInput(now())}"></label>
    <label>${tt('rem.repeat')}<select name="rep">${opts(RREP, 'once')}</select></label>
    <button type="submit" class="btn">${tt('rem.add')}</button>
    <small class="hint wide">${tt('rem.med_note')}</small>
  </form>

  <h2 class="sub">${tt('rem.list')}</h2>
  <section class="list" id="rl">
    ${items.map(r => remRow(r, all[r.pid].name, r.src === 'doctor' && r.type !== 'visit'
      ? `<button class="lnk del" data-del="${h(r.id)}">${tt('rem.delete')}</button>` : `<small>${tt(r.src === 'prescription' ? 'rem.from_rx' : r.type === 'visit' ? 'rem.from_cons' : 'rem.view_only')}</small>`)).join('') || empty('rem.none')}
  </section>`);

wireSegFilter('#rl', c => { $('#cnt').textContent = c; });
$('#pick').onchange = e => { location.href = url('reminders.html', { p: Number(e.target.value) }); };
document.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => { await deleteReminder(b.dataset.del); go(back); });

// Same checks as before: every field is required, and the time must be in the future
$('#rform').onsubmit = async e => {
  e.preventDefault();
  const f = new FormData(e.target), pid = Number(f.get('pid')), type = f.get('type'), rep = f.get('rep');
  const title = String(f.get('title') ?? '').trim(), ts = fromLocalInput(String(f.get('at') ?? ''));
  const err = !all[pid] || !FORM_TYPES[type] || !RREP[rep] || !title || !ts ? 'rem.err_fields' : ts <= now() ? 'rem.err_past' : '';
  if (err) { const el = $('#err'); el.textContent = t(err); el.hidden = false; return; }
  await addReminder({ pid, type, title, at: ts, rep });
  go(back);
};

