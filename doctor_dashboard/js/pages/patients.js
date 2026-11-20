// My Patients: a searchable directory of the patients assigned to the doctor. One card per patient, tinted by the
// calculated clinical status (Normal / Controlled / Critical — never set here), with the latest glucose reading,
// the last consultation and the next follow-up, and two actions: View Profile (primary), New Consultation.
// Search by name or patient ID and the status filter work together; rendering is one pass over the list, so it
// stays fast with hundreds of patients.
// "Link a patient" (header button): a dialog where the doctor creates a single-use code for one patient (text + QR,
// entered or scanned in the Patient App at the clinic) and sees the pending / used codes. The QR contains ONLY the
// code (data/api.js createLinkCode / listLinkCodes / cancelLinkCode).
import { mount } from '../ui/layout.js';
import { t, tt, tv, ldate, DF } from '../core/i18n.js';
import { $, h, ic } from '../core/dom.js';
import { getPatients, createLinkCode, listLinkCodes, cancelLinkCode, LINK_CODE_RE, LINK_DEMO } from '../data/api.js';
import { PST, statusPill, awaitingPill, avatar, lower, UNIT, consKind } from '../ui/components.js';

const ps = Object.values(await getPatients()).sort((a, b) => a.name.localeCompare(b.name) || a.id - b.id);
// Age, diabetes type and treatment only (the directory line)
const meta = p => [p.age != null ? t('pat.years', { n: p.age }) : null, p.type ? tv('ptype.', p.type) : p.reportedType ? t('pat.reported_type', { v: tv('ptype.', p.reportedType) }) : null,
  p.treat ? tv('treat.', p.treat) : null].filter(Boolean).join(' · ') || t('pat.no_profile');
for (const p of ps) p._s = lower(p.name);
const count = n => tt(n === 1 ? 'pats.count_one' : 'pats.count', { n });

const card = p => {
  const l = p.readings[0], lc = p.consultations.at(-1), st = p.status ?? 'none';
  return `<article class="pcard st-${st}" aria-label="${h(p.name)}">
    <div class="pc-id">${avatar(p.name)}<div><a class="pc-name" href="patient.html?id=${p.id}" dir="auto">${h(p.name)}</a>
      <small>${tt('st2.pid', { id: p.id })} · ${h(meta(p))}</small></div></div>
    <div class="pc-st"><span class="pc-l">${tt('home.col.status')}</span><span class="stblock">${statusPill(p.status)}${p.awaiting ? awaitingPill() : ''}</span></div>
    <div class="pc-gl"><span class="pc-l">${tt('home4.col.last')}</span>${l
      ? `<bdi class="qty"><b class="v r-${l.st}">${h(l.v)}</b>${UNIT()}</bdi><small>${h(ldate(DF.DATE_TIME, l.at))}</small>`
      : `<small>${tt('pats.no_readings')}</small>`}</div>
    <div class="pc-cons"><span class="pc-l">${tt('pats.last_cons')}</span>${lc
      ? `<span>${h(ldate(DF.DATE, lc.at))}</span><small>${h(consKind(lc.kind))}</small>` : `<small>${tt('cons.awaiting')}</small>`}
      ${p.followUp ? `<small class="fu">${tt('pats.next_fu', { d: ldate(DF.DATE, p.followUp.at) })}</small>` : ''}</div>
    <div class="pc-act"><a class="btn sm" href="patient.html?id=${p.id}">${tt('pats.view')}</a>
      <a class="btn ghost sm" href="consultation.html?id=${p.id}">${ic('steth')} ${p.awaiting ? tt('cons.new_initial') : tt('cons.new')}</a></div>
  </article>`;
};

await mount({ page: 'patients', title: t('nav.patients'), heading: t('pats.heading'), sub: t('pats.sub') }, `
  <div class="pats-bar">
    <h2 id="pats-n">${count(ps.length)}</h2>
    <div class="ctl">
      <label class="psearch"><span class="sr">${tt('pats.search')}</span><input type="search" id="pq" placeholder="${tt('pats.search')}" autocomplete="off" dir="auto"></label>
      <select id="filter" aria-label="${tt('pats.filter')}"><option value="">${tt('pats.all_status')}</option>
        ${['crit', 'ctrl', 'ok'].map(k => `<option value="${k}">${h(PST[k])}</option>`).join('')}</select>
      <button type="button" class="btn" id="link-btn" aria-haspopup="dialog" aria-controls="linkdlg">${ic('users')} ${tt('pats.link_btn')}</button>
    </div></div>
  <div class="pcards" id="pcards" aria-live="polite"></div>
  <dialog class="linkdlg" id="linkdlg" aria-labelledby="link-h"><div class="lc-in">
    <h2 id="link-h">${tt('link.title')}</h2>
    <p class="hint">${tt('link.help')} ${tt('link.single')}</p>
    <form class="lc-form" id="lc-form" novalidate>
      <label class="lc-fl"><span>${tt('link.name')}</span><input id="lc-name" maxlength="60" autocomplete="off" dir="auto" aria-describedby="lc-hint lc-err">
        <small class="hint" id="lc-hint">${tt('link.name_hint')}</small></label>
      <button type="submit" class="btn">${tt('link.generate')}</button>
      <small class="lc-err" id="lc-err" role="alert" hidden></small>
    </form>
    <section class="lc-new" id="lc-new" aria-labelledby="lc-for" hidden>
      <p class="lc-l" id="lc-for"></p>
      <div class="lc-row"><span class="lc-code" id="lc-code" dir="ltr" aria-labelledby="lc-for"></span>
        <button type="button" class="btn ghost sm" id="lc-copy">${tt('link.copy')}</button></div>
      <small class="lc-st" id="lc-st" role="status" aria-live="polite"></small>
      <div class="lc-qr" id="lc-qr" dir="ltr"></div>
    </section>
    <h3 class="lc-h">${tt('link.pending_h')}</h3>
    <div class="lc-list" id="lc-list"></div>
    ${LINK_DEMO ? `<p class="lc-demo">${tt('link.demo')}</p>` : ''}
    <div class="lc-act"><button type="button" class="btn ghost" id="lc-close">${tt('link.close')}</button></div>
  </div></dialog>`);

// Name contains the text, or the patient ID equals / starts with it ("#12" works too). Status filter on top
function render() {
  const q = lower($('#pq').value.trim()), id = q.replace(/^#/, ''), st = $('#filter').value;
  const rows = ps.filter(p => (!st || p.status === st) && (!q || p._s.includes(q) || (/^\d+$/.test(id) && String(p.id).startsWith(id))));
  $('#pcards').innerHTML = rows.map(card).join('')
    || `<p class="empty" role="status">${tt(ps.length ? 'pats.none_match' : 'empty.patients')}${ps.length ? ` <button type="button" class="lnk" id="clr">${tt('pats.clear')}</button>` : ''}</p>`;
  const clr = $('#clr'); if (clr) clr.onclick = () => { $('#pq').value = ''; $('#filter').value = ''; render(); $('#pq').focus(); };
}
$('#pq').oninput = render;
$('#filter').onchange = render;
render();

// ===== Link a patient =====
// QR library (js/vendor/qrcode-generator.js, MIT, unchanged copy; a classic script that defines `qrcode`).
// Loaded only when the dialog is first opened; no CDN. If it can't load, the dialog still shows the code.
let qrLib = null;
const loadQr = () => (qrLib ??= new Promise((ok, no) => {
  if (window.qrcode) { ok(window.qrcode); return; }
  const s = document.createElement('script');
  s.src = 'js/vendor/qrcode-generator.js';
  s.onload = () => (window.qrcode ? ok(window.qrcode) : no(new Error('qr')));
  s.onerror = () => no(new Error('qr'));
  document.head.append(s);
}));
// SVG of the QR code: black squares on white with a 4-module quiet zone (scannable in dark mode too).
// The only input is the validated link code.
function qrSvg(lib, code) {
  const q = lib(0, 'M'); q.addData(code); q.make();
  const n = q.getModuleCount(), m = 4, size = n + 2 * m;
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c + m},${r + m}h1v1h-1z`;
  return `<svg viewBox="0 0 ${size} ${size}" role="img" aria-label="${tt('link.qr_alt')}" shape-rendering="crispEdges"><rect width="${size}" height="${size}" fill="#fff"/><path d="${d}" fill="#000"/></svg>`;
}
const dlg = $('#linkdlg'), lcCode = $('#lc-code'), lcCopy = $('#lc-copy'), lcSt = $('#lc-st'), lcQr = $('#lc-qr');
const lcNew = $('#lc-new'), lcFor = $('#lc-for'), lcName = $('#lc-name'), lcErr = $('#lc-err'), lcList = $('#lc-list');
let shown = null;   // id of the code shown in the result area
// The name is optional: an empty one is shown as "Unnamed" (never stored as translated text)
const nameOf = c => c.label || t('link.unnamed');
const err = key => { lcErr.textContent = key ? t(key) : ''; lcErr.hidden = !key; lcName.setAttribute('aria-invalid', !!key); };
// Show one code: large text with Copy, and the QR (drawn only after the code passes LINK_CODE_RE)
async function showCode(c) {
  shown = c.id; lcNew.hidden = false; lcSt.textContent = '';
  lcFor.textContent = t('link.code_for', { name: nameOf(c) });
  lcCode.textContent = c.code;
  if (!LINK_CODE_RE.test(String(c.code))) { lcQr.innerHTML = `<p class="lc-none">${tt('link.qr_fail')}</p>`; return; }
  lcQr.innerHTML = '';
  try { lcQr.innerHTML = qrSvg(await loadQr(), c.code); }
  catch (e) { qrLib = null; lcQr.innerHTML = `<p class="lc-none">${tt('link.qr_fail')}</p>`; }
}
// Pending and used codes: name, code, created date, status; Show and Cancel for pending ones. Neutral pills only
let codes = [];
async function renderCodes() {
  try { codes = await listLinkCodes(); } catch (e) { lcList.innerHTML = `<p class="lc-none">${tt('link.list_fail')}</p>`; return; }
  lcList.innerHTML = codes.length ? codes.map(c => { const p = c.st === 'pending';
    return `<div class="lc-item"><div class="lc-who"><b dir="auto">${h(nameOf(c))}</b><small><bdi class="lc-mono" dir="ltr">${h(c.code)}</bdi> · ${h(ldate(DF.DATE, c.at))}</small></div>
      <span class="pill ${p ? 'b-new' : 'b-none'}">${tt('link.st.' + c.st)}</span>
      ${p ? `<span class="lc-btns"><button type="button" class="btn ghost sm" data-show="${h(c.id)}" aria-label="${tt('link.show_a', { name: nameOf(c) })}">${tt('link.show')}</button><button type="button" class="btn ghost sm" data-cancel="${h(c.id)}" aria-label="${tt('link.cancel_a', { name: nameOf(c) })}">${tt('link.cancel')}</button></span>` : ''}</div>`; }).join('')
    : `<p class="lc-none">${tt('link.none')}</p>`;
}
lcList.addEventListener('click', async e => {
  const b = e.target.closest('button'); if (!b) return;
  const c = codes.find(x => x.id === (b.dataset.show ?? b.dataset.cancel)); if (!c) return;
  if (b.dataset.show) { showCode(c); return; }
  if (!confirm(t('link.cancel_q', { name: nameOf(c), code: c.code }))) return;
  if (await cancelLinkCode(c.id).catch(() => false) && shown === c.id) { lcNew.hidden = true; shown = null; }
  renderCodes();
});
$('#lc-form').onsubmit = async e => {
  e.preventDefault();
  const label = lcName.value.trim();   // optional
  err(null);
  try { const c = await createLinkCode(label); lcName.value = ''; await showCode(c); renderCodes(); }
  catch (x) { err('link.unavailable'); }
};
$('#link-btn').onclick = () => {
  err(null); lcNew.hidden = true; shown = null; lcName.value = '';
  if (dlg.showModal) dlg.showModal(); else dlg.setAttribute('open', '');
  renderCodes();
};
// Copy: clipboard API, otherwise select the code so the doctor can copy it with the keyboard
lcCopy.onclick = async () => {
  try { await navigator.clipboard.writeText(lcCode.textContent); lcSt.textContent = t('link.copied'); }
  catch (e) {
    const r = document.createRange(); r.selectNodeContents(lcCode);
    const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r);
    lcSt.textContent = t('link.copy_fail');
  }
};
const closeDlg = () => (dlg.close ? dlg.close() : dlg.removeAttribute('open'));
$('#lc-close').onclick = closeDlg;
// A click on the dimmed backdrop closes the dialog too (the content sits in .lc-in, so it never matches)
dlg.addEventListener('click', e => { if (e.target === dlg) closeDlg(); });
