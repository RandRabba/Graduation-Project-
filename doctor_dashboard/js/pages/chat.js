// Chat: messaging is available for every patient assigned to the doctor (no subscription system).
import { mount } from '../ui/layout.js';
import { t, tt, ldate } from '../core/i18n.js';
import { $, h, nl2br, qint } from '../core/dom.js';
import { getPatients, firstPatientId, getChat, sendMessage, getNotifications, ackNotification } from '../data/api.js';
import { go } from '../ui/nav.js';
import { statusPill, patientMeta, avatar, lower, empty } from '../ui/components.js';

const all = await getPatients();
let id = qint('p', 1); if (!all[id]) id = firstPatientId(all);
const head = { page: 'chat', title: t('nav.chat'), heading: t('nav.chat'), sub: t('chat.sub') };

if (!id) {
  await mount(head, empty('empty.patients'));
} else {
  const p = all[id], msgs = await getChat(id);
  // Reading the conversation reviews its message notifications
  for (const n of (await getNotifications()).filter(x => x.pid === id && x.kind === 'message' && !x.ack)) await ackNotification(id, n.id);
  const side = await Promise.all(Object.values(all).map(async x => {
    const c = await getChat(x.id), lm = c[c.length - 1], wait = lm && lm[0] === 'patient';
    return `<a href="chat.html?p=${x.id}" class="pt ${x.id === id ? 'on' : ''}" data-s="${h(lower(x.name))}">
        ${avatar(x.name)}
        <div class="pm"><b dir="auto">${h(x.name)}</b><small dir="auto">${lm ? (lm[0] === 'doctor' ? tt('chat.you', { m: lm[1] }) : h(lm[1])) : tt('chat.none')}</small></div>
        ${wait ? `<span class="pill b-ctrl">${tt('chat.reply')}</span>` : ''}
      </a>`; }));

  await mount(head, `
<div class="chatbox">
  <aside class="plist">${side.join('')}</aside>
  <section class="conv">
    <div class="chead">
      ${avatar(p.name)}
      <div><b dir="auto">${h(p.name)}</b><small>${h(patientMeta(p))}</small></div>
      ${statusPill(p.status)}
      <a class="btn ghost" href="patient.html?id=${id}">${tt('chat.file')}</a>
    </div>
    <div class="msgs" id="msgs">
      ${msgs.map(m => `<div class="b ${m[0]}"><p dir="auto">${nl2br(m[1])}</p><small>${h(ldate('h:i A', m[2]))}</small></div>`).join('') || empty('chat.start', { name: p.name })}
    </div>
    <form class="comp" id="comp">
      <textarea name="text" id="msg" rows="1" dir="auto" required placeholder="${tt('chat.ph')}"></textarea>
      <button class="btn" type="submit">${tt('chat.send')}</button>
    </form>
  </section>
</div>`);

  const box = $('#msgs'); box.scrollTop = box.scrollHeight;
  const ta = $('#msg'), form = $('#comp');
  const send = async () => { const text = ta.value.trim(); if (!text) return; await sendMessage(id, text); go(`chat.html?p=${id}`); };
  form.onsubmit = e => { e.preventDefault(); send(); };
  // Enter sends, Shift+Enter adds a new line
  ta.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } });
}
