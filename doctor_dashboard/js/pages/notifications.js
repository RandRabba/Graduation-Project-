// Notifications (formerly Alerts). Critical medical alerts are shown first, in their own section, and
// can't be mixed up with ordinary notifications: consultation requests, patient messages, treatment updates,
// follow-up reminders, missed doses and other abnormal glucose readings.
// Glucose alerts are reviewed in the patient file after looking at the data; others can be marked here.
import { mount } from '../ui/layout.js';
import { t, tt, ldate } from '../core/i18n.js';
import { $, $$, h, ic, qint, url } from '../core/dom.js';
import { NOTIF_KINDS } from '../core/notify.js';
import { getPatients, getNotifications, ackNotification } from '../data/api.js';
import { go } from '../ui/nav.js';
import { card, notifText, notifLink, NICON, lower, empty, auto } from '../ui/components.js';

const all = await getPatients(), sel = qint('p');
const items = (await getNotifications()).filter(n => !sel || n.pid === sel);
const crit = items.filter(n => n.sev === 'crit'), other = items.filter(n => n.sev !== 'crit');
// Unreviewed first, then newest
const order = (a, b) => (!!a.ack - !!b.ack) || (b.at - a.at);
crit.sort(order); other.sort(order);
const nOpen = items.filter(n => !n.ack).length, nCrit = crit.filter(n => !n.ack).length;
const back = url('notifications.html', { p: sel });

const row = n => { const x = notifText(n), pt = all[n.pid]?.name ?? '', lnk = notifLink(n, sel);
  const handled = n.ack && n.auto && n.ack === n.auto;
  return `<div class="row ${n.sev === 'crit' ? 'crit' : n.sev === 'warn' ? 'ctrl' : 'info'} ${n.ack ? 'done' : ''}" data-t="${n.kind}" data-open="${n.ack ? 0 : 1}" data-s="${h(lower(x.title + ' ' + x.sub + ' ' + pt))}">
    <div class="who"><div class="ico">${ic(NICON[n.kind])}</div><div><b>${h(x.title)}</b><small><a href="patient.html?id=${n.pid}" dir="auto">${h(pt)}</a>${x.sub ? ` · ${auto(x.sub)}` : ''}</small></div></div>
    <div class="val"><span>${h(ldate('M d, Y · h:i A', n.at))}</span></div>
    <div class="stat"><span class="pill">${tt('nk.' + n.kind)}</span>${n.sev === 'crit' ? `<span class="rng">${tt('n.urgent')}</span>` : ''}</div>
    <div class="act">${n.ack ? `<small>${handled ? tt('n.handled', { d: ldate('M d · h:i A', n.ack) }) : tt('al.reviewed', { d: ldate('M d · h:i A', n.ack) })}</small> <a class="lnk" href="${h(lnk)}">${tt('n.open')}</a>`
      : n.kind === 'glucose' ? `<a class="btn sm" href="${h(lnk)}">${tt('al.review')}</a>`
      : `<a class="lnk" href="${h(lnk)}">${tt('n.open')}</a> <button class="btn sm" data-ack="${h(n.id)}" data-pid="${n.pid}">${tt('n.mark')}</button>`}</div>
  </div>`; };

await mount({ page: 'notifications', title: t('nav.notifications'), heading: t('nav.notifications'), sub: t('n.sub') }, `
  <section class="stats">
    ${card('c-ctrl', 'bell', t('n.card.open'), nOpen)}
    ${card('c-high', 'alert', t('al.card.crit'), nCrit)}
    ${card('c-ok', 'check', t('al.card.rev'), items.length - nOpen)}
    ${card('c-info', 'report', t('al.card.total'), items.length)}
  </section>

  <section class="critbox" aria-labelledby="crit-h">
    <div class="bar"><h2 id="crit-h">${ic('alert')} ${tt('n.crit_title')}</h2><small>${tt('n.crit_sub')}</small></div>
    <div class="list">${crit.map(row).join('') || `<p class="txt">${tt('n.crit_none')}</p>`}</div>
  </section>

  <div class="bar sub"><h2>${t('n.other', { n: `<span id="cnt">${other.length}</span>` })}</h2>
    <div class="ctl">
      <div class="seg" role="group" aria-label="${tt('n.filter_kind')}">
        <button data-f="all" class="on" aria-pressed="true">${tt('common.all')}</button>${NOTIF_KINDS.filter(k => other.some(n => n.kind === k)).map(k => `<button data-f="${k}" aria-pressed="false">${tt('nk.' + k)}</button>`).join('')}
      </div>
      <label class="chk"><input type="checkbox" id="onlyOpen"> ${tt('n.only_open')}</label>
      ${Object.keys(all).length > 1 ? `<select id="pick" aria-label="${tt('common.select_patient')}"><option value="0">${tt('common.all_patients')}</option>
        ${Object.values(all).map(x => `<option value="${x.id}"${sel === x.id ? ' selected' : ''}>${h(x.name)}</option>`).join('')}</select>` : ''}
    </div></div>
  <section class="list" id="nl">${other.map(row).join('') || empty('n.none')}
    ${other.length ? `<p class="empty" id="nofilt" hidden>${tt('n.none_filter')}</p>` : ''}</section>`);

// Type filter and "unreviewed only" work together
let kind = 'all';
const apply = () => {
  const oo = $('#onlyOpen').checked; let c = 0;
  $$('#nl [data-t]').forEach(r => { const ok = (kind === 'all' || r.dataset.t === kind) && (!oo || r.dataset.open === '1'); r.style.display = ok ? '' : 'none'; if (ok) c++; });
  $('#cnt').textContent = c; const nf = $('#nofilt'); if (nf) nf.hidden = c > 0;
};
$$('.seg button[data-f]').forEach(b => b.onclick = () => {
  kind = b.dataset.f;
  $$('.seg button[data-f]').forEach(x => { x.classList.toggle('on', x === b); x.setAttribute('aria-pressed', x === b); });
  apply();
});
$('#onlyOpen').onchange = apply;
$$('[data-ack]').forEach(b => b.onclick = async () => { await ackNotification(Number(b.dataset.pid), b.dataset.ack); go(back); });
const pick = $('#pick'); if (pick) pick.onchange = e => { location.href = url('notifications.html', { p: Number(e.target.value) }); };
