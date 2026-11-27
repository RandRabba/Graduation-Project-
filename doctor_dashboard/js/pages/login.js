// Doctor sign-in (only with the backend: CONFIG.dataSource === 'api'). Firebase email + password through
// data/auth.js, then a check that the account is a doctor, then back to the page the doctor came from (?next=).
import '../core/theme.js';
import { t, tt, LANG, DIR } from '../core/i18n.js';
import { $, ic } from '../core/dom.js';
import { CONFIG } from '../config.js';
import { signIn, signOut, checkDoctor, isSignedIn, safeNext, AuthError } from '../data/auth.js';

const root = document.documentElement;
root.lang = LANG; root.dir = DIR;
document.title = 'DMS · ' + t('login.title');
document.body.classList.add('login-page');

const next = safeNext(new URLSearchParams(location.search).get('next'));
const brand = `<div class="brand"><span class="logo">${ic('drop')}</span><div class="bt"><b>DMS</b><small>${tt('app.full')}</small></div></div>`;

if (CONFIG.dataSource !== 'api') {
  // Test data needs no account
  document.body.innerHTML = `<main class="login">${brand}<p class="hint">${tt('login.mock')}</p><a class="btn" href="index.html">${tt('login.open')}</a></main>`;
} else {
  document.body.innerHTML = `<main class="login">${brand}
    <h1>${tt('login.heading')}</h1><p class="hint">${tt('login.sub')}</p>
    <form class="pform one editing" id="login" novalidate>
      <p class="warn" id="lerr" role="alert" hidden></p>
      <label>${tt('login.email')}<input type="email" name="email" required autocomplete="username" autofocus></label>
      <label>${tt('login.password')}<input type="password" name="password" required autocomplete="current-password"></label>
      <div class="pact"><button type="submit" class="btn" id="lbtn">${tt('login.btn')}</button></div>
    </form></main>`;

  const err = $('#lerr'), btn = $('#lbtn');
  const show = key => { err.textContent = t(key); err.hidden = false; };
  const ERRORS = { INVALID_LOGIN_CREDENTIALS: 'credentials', TOO_MANY_ATTEMPTS_TRY_LATER: 'many', USER_DISABLED: 'disabled',
    INVALID_EMAIL: 'email', NETWORK: 'network', OTHER: 'other' };

  // Already signed in (and the token still works): straight to the dashboard
  if (isSignedIn() && await checkDoctor() === 'ok') location.replace(next);

  $('#login').onsubmit = async e => {
    e.preventDefault();
    const f = new FormData(e.target);
    err.hidden = true;
    if (!f.get('email').trim() || !f.get('password')) return show('login.err.credentials');
    btn.disabled = true; btn.textContent = t('login.busy');
    try {
      await signIn(f.get('email'), f.get('password'));
      const who = await checkDoctor();
      if (who === 'ok') return location.replace(next);
      signOut();
      show(who === 'not_doctor' ? 'login.err.not_doctor' : who === 'unreachable' ? 'login.err.server' : 'login.err.other');
    } catch (x) {
      show('login.err.' + (ERRORS[x instanceof AuthError ? x.code : 'OTHER'] ?? 'other'));
    }
    btn.disabled = false; btn.textContent = t('login.btn');
  };
}
