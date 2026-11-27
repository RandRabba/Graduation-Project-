// Page shell shared by every page (replaces header.php, footer.php and Common.js):
// sidebar with counters, top bar (page title, notifications bell, doctor), mobile drawer and tabs.
import '../core/theme.js';
import { t, tt, LANG, DIR } from '../core/i18n.js';
import { $, $$, h, ic } from '../core/dom.js';
import { TEST_ON, getDoctor, openNotifications, missedReminders, newReports } from '../data/api.js';
import { docAvatar } from './components.js';

// Sidebar groups: [group, [[page key, icon, href, counter?], ...]]. Nutrition and Glucose Monitoring are patient tabs, not here
const NAV = [
  ['main', [['dashboard', 'home', 'index.html'], ['patients', 'users', 'patients.html'], ['stats', 'trend', 'statistics.html']]],
  ['manage', [['reports', 'report', 'reports.html', 'reports'], ['chat', 'chat', 'chat.html'], ['reminders', 'clock', 'reminders.html', 'missed'],
    ['notifications', 'bell', 'notifications.html', 'open']]],
  ['account', [['profile', 'user', 'profile.html']]],
];
// Collapsed (icons only) is remembered per browser; boot.js applies it before drawing (html[data-side=mini])
const SIDE_KEY = 'dms-side';

// opts: {page, title, heading, sub, greet?}, body: HTML of the page content
export async function mount(opts, body) {
  const root = document.documentElement;
  root.lang = LANG; root.dir = DIR;
  if (TEST_ON) root.dataset.mode = 'test';
  document.title = 'DMS · ' + opts.title;
  const counts = { reports: await newReports(), missed: await missedReminders(), open: await openNotifications() };
  const doc = getDoctor();   // after the data: with the backend the doctor's name arrives with it
  const mini = root.dataset.side === 'mini';
  // A link: icon, label (kept for screen readers when collapsed), optional count badge; data-tip = collapsed tooltip
  const link = ([k, i, href, c]) => { const n = c ? counts[c] : 0, on = k === opts.page;
    return `<a href="${href}" class="${on ? 'active' : ''}"${on ? ' aria-current="page"' : ''} data-tip="${tt('nav.' + k)}${n ? ' · ' + n : ''}">${ic(i)}<span class="lbl">${tt('nav.' + k)}</span>${n ? `<em class="nb" aria-label="${h(t('nav.badge', { n }))}">${n > 99 ? '99+' : n}</em>` : ''}</a>`; };
  document.body.innerHTML = `
<aside class="side" id="side">
  <div class="brand"><span class="logo">${ic('drop')}</span><div class="bt"><b>DMS</b><small>${tt('app.full')}</small></div>
    <button type="button" class="sidecol" id="sidecol" aria-controls="side" aria-expanded="${!mini}" aria-label="${tt(mini ? 'side.expand' : 'side.collapse')}" title="${tt(mini ? 'side.expand' : 'side.collapse')}">${ic('panel')}</button></div>
  <nav aria-label="${tt('side.nav')}">${NAV.map(([g, items]) => `<div class="ngroup ng-${g}" role="group" aria-labelledby="ng-${g}"><p class="nav-h" id="ng-${g}">${tt('navg.' + g)}</p>${items.map(link).join('')}</div>`).join('')}</nav>
  <p class="tag">${tt('app.tag1')}<br>${tt('app.tag2')}</p>
</aside>
<div class="scrim" id="scrim" hidden></div>
<main>
  <header class="top">
    <button id="menu" class="icon menu" aria-label="${tt('top.menu')}" aria-controls="side" aria-expanded="false">${ic('menu')}</button>
    <div class="hello"><div><h1 id="greet"${opts.greet ? ` data-name="${h(opts.greet)}"` : ''}>${h(opts.heading)}</h1>${opts.sub ? `<p>${h(opts.sub)}</p>` : ''}</div></div>
    <a class="icon" href="notifications.html" aria-label="${counts.open ? tt('top.notif_open', { n: counts.open }) : tt('nav.notifications')}" title="${tt('nav.notifications')}">${ic('bell')}${counts.open ? `<i>${counts.open}</i>` : ''}</a>
    <a class="user" href="profile.html" aria-label="${tt('top.profile')}">${docAvatar(doc)}<div><b>${h(doc.name)}</b><small>${h(doc.spec)}</small></div></a>
  </header>
  ${body}
</main>`;
  wireCommon();
}

function wireCommon() {
  // Mobile sidebar opens as a drawer
  const side = $('#side'), menu = $('#menu'), scrim = $('#scrim');
  const setMenu = open => {
    document.body.classList.toggle('menu-open', open);
    scrim.hidden = !open;
    menu.setAttribute('aria-expanded', open);
    if (open) side.querySelector('nav a').focus();
  };
  menu.onclick = () => setMenu(!document.body.classList.contains('menu-open'));
  scrim.onclick = () => setMenu(false);
  addEventListener('keydown', e => { if (e.key === 'Escape' && document.body.classList.contains('menu-open')) { setMenu(false); menu.focus(); } });

  // Collapse / expand the sidebar (desktop and tablet); the content column widens automatically (CSS grid)
  const col = $('#sidecol'), root = document.documentElement;
  col.onclick = () => {
    const mini = root.dataset.side !== 'mini';
    if (mini) root.dataset.side = 'mini'; else delete root.dataset.side;
    try { localStorage.setItem(SIDE_KEY, mini ? 'mini' : 'full'); } catch (e) { /* storage unavailable */ }
    const label = t(mini ? 'side.expand' : 'side.collapse');
    col.setAttribute('aria-expanded', !mini); col.setAttribute('aria-label', label); col.title = label;
  };

  // Greeting by the time on the doctor's device (Home only)
  const g = $('#greet'), hr = new Date().getHours();
  if (g.dataset.name) g.textContent = t(`dash.greet.${hr < 12 ? 'morning' : hr < 18 ? 'afternoon' : 'evening'}`, { name: g.dataset.name });

  wireTabs();
}

// Tabs: the hash keeps the open tab (#t-...), so links and reloads return to it
export function wireTabs() {
  const buttons = $$('.tabs button');
  buttons.forEach(b => b.onclick = () => {
    buttons.forEach(x => x.classList.toggle('on', x === b));
    $$('.tab').forEach(s => { s.hidden = s.id !== b.dataset.tab; });
    history.replaceState(null, '', location.pathname + location.search + '#' + b.dataset.tab);
  });
  // Old tab names (before the patient file was reorganized) still open the right tab
  const OLD = { 't-rd': 't-glu', 't-al': 't-glu', 't-ml': 't-nut', 't-rm': 't-com', 't-ins': 't-com' };
  const fromHash = () => { const h0 = location.hash.slice(1), t0 = OLD[h0] ?? h0, tb = t0 && buttons.find(b => b.dataset.tab === t0); if (tb && !tb.classList.contains('on')) tb.click(); };
  fromHash();
  // A link to another tab of the same page changes only the hash
  if (buttons.length) addEventListener('hashchange', fromHash);
}

// Segmented filter buttons that show/hide rows by data-t and update a counter (Alerts, Reminders)
export function wireSegFilter(listSel, onCount) {
  $$('.seg button[data-f]').forEach(b => b.onclick = () => {
    $$('.seg button[data-f]').forEach(x => { x.classList.toggle('on', x === b); x.setAttribute('aria-pressed', x === b); });
    let c = 0;
    $$(`${listSel} [data-t]`).forEach(r => { const ok = b.dataset.f === 'all' || r.dataset.t === b.dataset.f; r.style.display = ok ? '' : 'none'; if (ok) c++; });
    onCount(c);
  });
}

// A page restored from the browser cache (Back button) may show an old language or scenario: reload it
addEventListener('pageshow', e => { if (e.persisted) location.reload(); });
