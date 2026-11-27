// Doctor sign-in for the FastAPI backend (used only when CONFIG.dataSource === 'api').
//
// The doctor signs in with the same Firebase account system as the apps. This module talks to Firebase's two public
// REST endpoints (no SDK to install), keeps the tokens in sessionStorage (this tab only, gone when it closes) and
// gives http.js a valid ID token for the `Authorization: Bearer …` header. The backend checks the token and that the
// account is a doctor (backend/app/auth); nothing is trusted from the browser.
import { CONFIG } from '../config.js';
import { session } from '../core/storage.js';

const KEY = 'dms-auth';
const SIGN_IN_URL = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword';
const REFRESH_URL = 'https://securetoken.googleapis.com/v1/token';
const EARLY = 60_000;   // refresh a minute before the token expires

// A sign-in problem. code: INVALID_LOGIN_CREDENTIALS | TOO_MANY_ATTEMPTS_TRY_LATER | USER_DISABLED | INVALID_EMAIL |
// NETWORK | OTHER. The login page turns the code into a message.
export class AuthError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const saved = () => session.get(KEY, null);
const save = (idToken, refreshToken, expiresInSeconds) =>
  session.set(KEY, { idToken, refreshToken, exp: Date.now() + Number(expiresInSeconds) * 1000 });

export const isSignedIn = () => !!saved()?.refreshToken;
export function signOut() { session.set(KEY, undefined); }

async function post(url, init) {
  let res;
  try { res = await fetch(`${url}?key=${encodeURIComponent(CONFIG.firebaseApiKey)}`, { method: 'POST', ...init }); }
  catch (e) { throw new AuthError('NETWORK'); }
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

export async function signIn(email, password) {
  const r = await post(SIGN_IN_URL, {
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: String(email).trim(), password, returnSecureToken: true }),
  });
  if (!r.ok) {
    const code = String(r.body?.error?.message ?? '').split(' ')[0];   // e.g. "TOO_MANY_ATTEMPTS_TRY_LATER : Access to…"
    throw new AuthError(['INVALID_LOGIN_CREDENTIALS', 'TOO_MANY_ATTEMPTS_TRY_LATER', 'USER_DISABLED', 'INVALID_EMAIL'].includes(code) ? code : 'OTHER');
  }
  save(r.body.idToken, r.body.refreshToken, r.body.expiresIn);
}

let refreshing = null;   // one refresh at a time, shared by requests that start together
async function refresh(refreshToken) {
  const r = await post(REFRESH_URL, {
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: refreshToken }).toString(),
  });
  if (!r.ok) {
    // The sign-in is no longer valid (disabled account, revoked session): sign in again. Anything else is left alone.
    if (r.status === 400) { signOut(); return null; }
    throw new AuthError('OTHER');
  }
  save(r.body.id_token, r.body.refresh_token, r.body.expires_in);
  return r.body.id_token;
}

// A token that is valid now, or null when the doctor has to sign in. Throws AuthError('NETWORK') when Firebase cannot
// be reached, so a lost connection is not mistaken for a signed-out doctor.
export async function getIdToken() {
  const s = saved();
  if (!s?.refreshToken) return null;
  if (s.idToken && s.exp - EARLY > Date.now()) return s.idToken;
  refreshing ??= refresh(s.refreshToken).finally(() => { refreshing = null; });
  return refreshing;
}

// Where to go back to after signing in: a page of this folder only (never another site)
const NEXT_RE = /^[A-Za-z0-9_-]+\.html(\?[^#]*)?(#.*)?$/;
export const safeNext = next => (typeof next === 'string' && NEXT_RE.test(next) ? next : 'index.html');

export function redirectToLogin() {
  const here = location.pathname.split('/').pop() + location.search + location.hash;
  location.replace('login.html' + (NEXT_RE.test(here) && !here.startsWith('login.html') ? `?next=${encodeURIComponent(here)}` : ''));
  return new Promise(() => {});   // the page is leaving: whoever was waiting for data never continues
}

// After a successful sign-in: is this account a doctor, and is the backend reachable?
// 'ok' | 'not_doctor' | 'rejected' | 'unreachable'
export async function checkDoctor() {
  const token = await getIdToken();
  if (!token) return 'rejected';
  let res;
  try { res = await fetch(`${CONFIG.apiBaseUrl}/doctor`, { headers: { Authorization: `Bearer ${token}` } }); }
  catch (e) { return 'unreachable'; }
  if (res.ok) return 'ok';
  if (res.status === 403) return 'not_doctor';
  return res.status === 401 ? 'rejected' : 'unreachable';
}
