// Doctor profile: photo, information, security, notifications and preferences (language, appearance, glucose unit).
// Saved in this browser until the backend stores them (getDoctor / saveDoctor in data/api.js).
import { mount } from '../ui/layout.js';
import { t, tt, tv, ldate, DF, LANG, setLang } from '../core/i18n.js';
import { $, $$, h, ic } from '../core/dom.js';
import { setFlash, takeFlash } from '../core/storage.js';
import { setTheme } from '../core/theme.js';
import { getPatients, getDoctor, saveDoctor, docPhoto, API_MODE } from '../data/api.js';
import { signOut } from '../data/auth.js';
import { go } from '../ui/nav.js';
import { docAvatar } from '../ui/components.js';

// The patients first: with the backend, the doctor's name arrives with that data (getDoctor)
const nPatients = Object.keys(await getPatients()).length, d = getDoctor(), flash = takeFlash();
const F = [['name', 'text'], ['spec', 'text'], ['hosp', 'text'], ['email', 'email'], ['phone', 'tel'], ['loc', 'text']];
const TABS = { 't-info': 'prof.tab.info', 't-sec': 'prof.tab.sec', 't-not': 'prof.tab.not', 't-pref': 'prof.tab.pref' };
const meta = Object.entries({ building: d.hosp, pin: d.loc, mail: d.email }).filter(([, v]) => v !== '');
// Messages are stored as translation keys so they show in the page language after reloading
const done = (key, tab) => { setFlash(key); go('profile.html#' + tab); };

await mount({ page: 'profile', title: t('nav.profile'), heading: t('nav.profile'), sub: t('prof.sub') }, `
  <section class="pro">
    <form class="pav" onsubmit="return false">
      ${docAvatar(d, 'avatar xl')}
      <label class="cam" title="${tt('prof.change_photo')}">${ic('camera')}<input type="file" id="photo" accept="image/jpeg,image/png,image/webp" aria-label="${tt('prof.change_photo')}"></label>
    </form>
    <div class="pinfo">
      <h2><span dir="auto">${h(d.name)}</span> <button type="button" class="pen js-edit" aria-label="${tt('prof.edit')}">${ic('pencil')}</button></h2>
      <p dir="auto">${d.spec !== '' ? h(d.spec) : tt('prof.spec_unset')}</p>
      <div class="pmeta">${meta.map(([i, v]) => `<span>${ic(i)}<bdi>${h(v)}</bdi></span>`).join('') || `<span class="hint">${tt('prof.meta_unset')}</span>`}</div>
      ${docPhoto(d) ? `<div class="nophoto"><button type="button" class="lnk del" id="nophoto">${tt('prof.remove_photo')}</button></div>` : ''}
      <p class="warn" id="perr" hidden></p>
    </div>
    <button type="button" class="btn ghost js-edit">${ic('pencil')} ${tt('prof.edit_btn')}</button>
  </section>

  <section class="stats">
    <div class="card c-avg"><div class="ico">${ic('steth')}</div><div><small>${tt('prof.card.spec')}</small><strong dir="auto">${d.spec !== '' ? h(d.spec) : '—'}</strong></div></div>
    <div class="card c-ok"><div class="ico">${ic('users')}</div><div><small>${tt('prof.card.pats')}</small><b>${nPatients}</b></div></div>
    <div class="card c-high"><div class="ico">${ic('calendar')}</div><div><small>${tt('prof.card.joined')}</small><b>${d.joined ? h(ldate(DF.MONTH, d.joined)) : '—'}</b></div></div>
    <div class="card c-ok"><div class="ico">${ic('shield')}</div><div><small>${tt('prof.card.status')}</small>${d.status ? `<span class="pill on">${h(tv('acct.', d.status))}</span>` : '<b>—</b>'}</div></div>
  </section>

  ${flash ? `<p class="okmsg">${tt(flash)}</p>` : ''}
  <div class="tabs pills">
    ${Object.entries(TABS).map(([k, v]) => `<button data-tab="${k}" class="${k === 't-info' ? 'on' : ''}">${tt(v)}</button>`).join('')}
  </div>

  <section class="tab" id="t-info">
    <form class="pform" id="pinfo" novalidate>
      <p class="warn" id="ierr" hidden></p>
      ${F.map(([k, type]) => `<label>${tt('prof.f.' + k)}<input type="${type}" name="${k}" value="${h(d[k])}" dir="auto" placeholder="${tt('prof.not_set')}" required readonly></label>`).join('')}
      <div class="pact"><button type="submit" class="btn">${tt('prof.save')}</button><a class="btn ghost" href="profile.html">${tt('prof.cancel')}</a></div>
    </form>
  </section>

  <section class="tab" id="t-sec" hidden>
    <form class="pform editing" id="pw" novalidate>
      <p class="warn" id="pwerr"${d.pw ? ' hidden' : ''}>${d.pw ? '' : tt('prof.msg.pw_na')}</p>
      <input type="text" name="username" autocomplete="username" value="${h(d.email)}" hidden>${/* for password managers */ ''}
      <label>${tt('prof.pw.cur')}<input type="password" name="cur" required autocomplete="current-password"></label>
      <label>${tt('prof.pw.new')}<input type="password" name="new" required minlength="8" autocomplete="new-password"></label>
      <label>${tt('prof.pw.conf')}<input type="password" name="conf" required minlength="8" autocomplete="new-password"></label>
      <small class="hint">${tt('prof.pw.hint')}</small>
      <div class="pact"><button type="submit" class="btn">${tt('prof.pw.btn')}</button></div>
    </form>
    ${API_MODE ? `<div class="pform one editing so">
      <p class="hint">${tt('prof.signout_hint')}</p>
      <div class="pact"><button type="button" class="btn ghost" id="signout">${tt('prof.signout')}</button></div>
    </div>` : ''}
  </section>

  <section class="tab" id="t-not" hidden>
    <form class="pform editing one" id="notif">
      ${['crit', 'msg', 'req', 'fu', 'rem', 'email'].map(k => `<label class="sw"><span><b>${tt('prof.n.' + k)}</b><small>${tt('prof.n.' + k + '_d')}</small></span><input type="checkbox" name="${k}"${d.notif?.[k] ? ' checked' : ''}><i></i></label>`).join('')}
      <div class="pact"><button type="submit" class="btn">${tt('prof.n.save')}</button></div>
    </form>
  </section>

  <section class="tab" id="t-pref" hidden>
    <form class="pform editing" onsubmit="return false">
      <div class="pref"><span id="lbl-lang">${tt('prof.lang')}</span>
        <!-- Choosing a language saves it and reloads the page in that language -->
        <div class="seg" role="group" aria-labelledby="lbl-lang">
          ${Object.entries({ en: 'English', ar: 'العربية' }).map(([l, name]) => `<a href="profile.html#t-pref" data-lang="${l}" lang="${l}" class="${LANG === l ? 'on' : ''}"${LANG === l ? ' aria-current="true"' : ''}>${name}</a>`).join('')}
        </div></div>
      <div class="pref"><span id="lbl-theme">${tt('prof.theme')}</span>
        <div class="seg" role="group" aria-labelledby="lbl-theme" aria-describedby="theme-hint" id="themeSeg">${['system', 'light', 'dark'].map(v => `<button type="button" data-v="${v}">${tt('prof.' + v)}</button>`).join('')}</div>
        <small class="hint" id="theme-hint">${tt('prof.theme_hint')}</small></div>
      <!-- The glucose unit is saved as soon as it changes, like language and appearance -->
      <label>${tt('prof.unit')}<select id="unit">${['mg/dL', 'mmol/L'].map(u => `<option${d.unit === u ? ' selected' : ''}>${u}</option>`).join('')}</select></label>
    </form>
  </section>`);

const showErr = (sel, key) => { const el = $(sel); el.textContent = t(key); el.hidden = false; };

// Photo: JPG, PNG or WEBP up to 2 MB; the type is checked by decoding the image, not by the file name
$('#photo').onchange = e => {
  const f = e.target.files[0];
  if (!f) return showErr('#perr', 'prof.msg.photo_choose');
  if (f.size > 2 * 1024 * 1024) return showErr('#perr', 'prof.msg.photo_size');
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(f.type)) return showErr('#perr', 'prof.msg.photo_type');
  const reader = new FileReader();
  reader.onerror = () => showErr('#perr', 'prof.msg.photo_upload');
  reader.onload = () => {
    const img = new Image();
    img.onerror = () => showErr('#perr', 'prof.msg.photo_type');
    img.onload = async () => {
      await saveDoctor({ photo: reader.result });
      // Browser storage can be full: then the photo isn't kept
      if (getDoctor().photo !== reader.result) return showErr('#perr', 'prof.msg.photo_save');
      done('prof.msg.photo_ok', 't-info');
    };
    img.src = reader.result;
  };
  reader.readAsDataURL(f);
};
const np = $('#nophoto');
if (np) np.onclick = async () => { await saveDoctor({ photo: null }); done('prof.msg.photo_removed', 't-info'); };

// The edit button opens the fields for typing
const pinfo = $('#pinfo');
$$('.js-edit').forEach(b => b.onclick = () => {
  document.querySelector('.tabs button[data-tab="t-info"]').click();
  pinfo.classList.add('editing');
  pinfo.querySelectorAll('input[readonly]').forEach(i => { i.readOnly = false; });
  pinfo.querySelector('input[name=name]').focus();
});
pinfo.onsubmit = async e => {
  e.preventDefault();
  const v = Object.fromEntries(F.map(([k]) => [k, String(new FormData(pinfo).get(k) ?? '').trim()]));
  if (Object.values(v).includes('')) return showErr('#ierr', 'prof.msg.fields');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.email)) return showErr('#ierr', 'prof.msg.email');
  await saveDoctor(v);
  done('prof.msg.updated', 't-info');
};

// Sign out (only with the backend: the sign-in lives in this tab)
const so = $('#signout');
if (so) so.onclick = () => { signOut(); location.replace('login.html'); };

// There is no real password before sign-in is connected to the backend, so a made-up one isn't checked
$('#pw').onsubmit = e => {
  e.preventDefault();
  const f = new FormData(e.target), nw = String(f.get('new') ?? '');
  if (!d.pw) return showErr('#pwerr', 'prof.msg.pw_na');
  if (nw.length < 8 || !/[A-Z]/.test(nw) || !/\d/.test(nw)) return showErr('#pwerr', 'prof.msg.pw_rule');
  if (nw !== f.get('conf')) return showErr('#pwerr', 'prof.msg.pw_match');
  showErr('#pwerr', 'prof.msg.pw_na');   // changing the password needs the backend
};

$('#notif').onsubmit = async e => {
  e.preventDefault();
  const f = new FormData(e.target);
  await saveDoctor({ notif: Object.fromEntries(['crit', 'msg', 'req', 'fu', 'rem', 'email'].map(k => [k, f.has(k) ? 1 : 0])) });
  done('prof.msg.notif_ok', 't-not');
};

// Language: saved and applied by reloading in the new language
$$('[data-lang]').forEach(a => a.onclick = e => { e.preventDefault(); setLang(a.dataset.lang); go('profile.html#t-pref'); });
// Appearance changes at once and is saved automatically, without a Save button
const seg = $$('#themeSeg button');
const mark = () => seg.forEach(x => { const on = x.dataset.v === document.documentElement.dataset.themePref; x.classList.toggle('on', on); x.setAttribute('aria-pressed', on); });
seg.forEach(b => b.onclick = () => { setTheme(b.dataset.v); mark(); });
addEventListener('storage', mark);
mark();
$('#unit').onchange = async e => { await saveDoctor({ unit: e.target.value === 'mmol/L' ? 'mmol/L' : 'mg/dL' }); done('prof.msg.prefs_ok', 't-pref'); };
