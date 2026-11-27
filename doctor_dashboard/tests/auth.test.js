// Sign-in and the authorized HTTP client (js/data/auth.js, js/data/http.js), with fetch, sessionStorage and location
// replaced by small fakes. Run: npm test
import test from 'node:test';
import assert from 'node:assert/strict';

const mem = new Map();
globalThis.sessionStorage = { getItem: k => (mem.has(k) ? mem.get(k) : null), setItem: (k, v) => mem.set(k, String(v)), removeItem: k => mem.delete(k) };
globalThis.location = { pathname: '/doctor_dashboard/patient.html', search: '?id=2', hash: '#t-meds', replaced: null, replace(u) { this.replaced = u; } };

const { CONFIG } = await import('../js/config.js');
const auth = await import('../js/data/auth.js');
const { http } = await import('../js/data/http.js');

const json = (status, body) => ({ ok: status >= 200 && status < 300, status, json: async () => body });
let calls;
const fakeFetch = handler => { calls = []; globalThis.fetch = async (url, init = {}) => { calls.push({ url: String(url), init }); return handler(String(url), init); }; };
const reset = () => { mem.clear(); location.replaced = null; };
const stored = () => JSON.parse(mem.get('dms-auth') ?? 'null');
const signInOk = { idToken: 'id-1', refreshToken: 'refresh-1', expiresIn: '3600' };
const leaves = async p => (await Promise.race([p.then(() => 'continued'), new Promise(r => setTimeout(() => r('waiting'), 20))])) === 'waiting';

test('signIn stores the tokens and getIdToken uses them without the network', async () => {
  reset(); fakeFetch(() => json(200, signInOk));
  await auth.signIn('  roa@example.com ', 'pw');
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /signInWithPassword\?key=/);
  assert.equal(JSON.parse(calls[0].init.body).email, 'roa@example.com');
  assert.equal(auth.isSignedIn(), true);
  fakeFetch(() => { throw new Error('no network call expected'); });
  assert.equal(await auth.getIdToken(), 'id-1');
});

test('signIn errors are reported by code', async () => {
  reset();
  for (const [msg, code] of [['INVALID_LOGIN_CREDENTIALS', 'INVALID_LOGIN_CREDENTIALS'], ['TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account has been temporarily disabled', 'TOO_MANY_ATTEMPTS_TRY_LATER'],
    ['USER_DISABLED', 'USER_DISABLED'], ['INVALID_EMAIL', 'INVALID_EMAIL'], ['SOMETHING_NEW', 'OTHER']]) {
    fakeFetch(() => json(400, { error: { message: msg } }));
    await assert.rejects(auth.signIn('a@b.c', 'x'), e => e instanceof auth.AuthError && e.code === code, msg);
  }
  fakeFetch(() => { throw new TypeError('Failed to fetch'); });
  await assert.rejects(auth.signIn('a@b.c', 'x'), e => e.code === 'NETWORK');
  assert.equal(auth.isSignedIn(), false);
});

test('getIdToken is null when nobody signed in', async () => {
  reset();
  assert.equal(await auth.getIdToken(), null);
  assert.equal(auth.isSignedIn(), false);
});

test('an expiring token is refreshed once, even for requests that start together', async () => {
  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'old', refreshToken: 'refresh-1', exp: Date.now() + 10_000 }));
  fakeFetch(() => json(200, { id_token: 'new', refresh_token: 'refresh-2', expires_in: '3600' }));
  const tokens = await Promise.all([auth.getIdToken(), auth.getIdToken(), auth.getIdToken()]);
  assert.deepEqual(tokens, ['new', 'new', 'new']);
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /securetoken\.googleapis\.com\/v1\/token\?key=/);
  assert.match(calls[0].init.body, /grant_type=refresh_token&refresh_token=refresh-1/);
  assert.equal(stored().refreshToken, 'refresh-2');
});

test('a refused refresh signs the doctor out; a failing network does not', async () => {
  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'old', refreshToken: 'r', exp: 0 }));
  fakeFetch(() => json(400, { error: { message: 'TOKEN_EXPIRED' } }));
  assert.equal(await auth.getIdToken(), null);
  assert.equal(auth.isSignedIn(), false);

  mem.set('dms-auth', JSON.stringify({ idToken: 'old', refreshToken: 'r', exp: 0 }));
  fakeFetch(() => { throw new TypeError('Failed to fetch'); });
  await assert.rejects(auth.getIdToken(), e => e.code === 'NETWORK');
  assert.equal(auth.isSignedIn(), true);   // still signed in: the connection was the problem
  fakeFetch(() => json(500, {}));
  await assert.rejects(auth.getIdToken(), e => e.code === 'OTHER');
  assert.equal(auth.isSignedIn(), true);
});

test('signOut forgets the tokens', async () => {
  reset(); fakeFetch(() => json(200, signInOk));
  await auth.signIn('a@b.c', 'x');
  auth.signOut();
  assert.equal(auth.isSignedIn(), false);
  assert.equal(stored(), null);
});

test('safeNext only accepts pages of this folder', () => {
  for (const ok of ['index.html', 'patient.html?id=2', 'patient.html?id=2#t-meds', 'notifications.html?p=1&alert=a-1'])
    assert.equal(auth.safeNext(ok), ok);
  for (const bad of ['https://evil.example/x.html', '//evil.example/a.html', '/etc/passwd', '../x.html', 'javascript:alert(1)', 'a.html\nb', '', null, undefined, 5])
    assert.equal(auth.safeNext(bad), 'index.html', String(bad));
});

test('redirectToLogin remembers the page and never resolves', async () => {
  reset();
  assert.equal(await leaves(auth.redirectToLogin()), true);
  assert.equal(location.replaced, 'login.html?next=' + encodeURIComponent('patient.html?id=2#t-meds'));
});

test('checkDoctor tells a doctor, another role, a bad token and a missing server apart', async () => {
  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'tok', refreshToken: 'r', exp: Date.now() + 3_600_000 }));
  for (const [answer, expected] of [[200, 'ok'], [403, 'not_doctor'], [401, 'rejected'], [500, 'unreachable']]) {
    fakeFetch(() => json(answer, {}));
    assert.equal(await auth.checkDoctor(), expected);
    assert.equal(calls[0].url, `${CONFIG.apiBaseUrl}/doctor`);
    assert.equal(calls[0].init.headers.Authorization, 'Bearer tok');
  }
  fakeFetch(() => { throw new TypeError('Failed to fetch'); });
  assert.equal(await auth.checkDoctor(), 'unreachable');
  reset();
  assert.equal(await auth.checkDoctor(), 'rejected');
});

test('http sends the token and returns the answer', async () => {
  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'tok', refreshToken: 'r', exp: Date.now() + 3_600_000 }));
  fakeFetch(() => json(200, { 1: { name: 'Sobhi' } }));
  assert.deepEqual(await http.get('/patients'), { 1: { name: 'Sobhi' } });
  assert.equal(calls[0].url, `${CONFIG.apiBaseUrl}/patients`);
  assert.equal(calls[0].init.headers.Authorization, 'Bearer tok');
  assert.equal(calls[0].init.credentials, undefined);   // cookies are not used any more

  fakeFetch(() => json(200, { id: 'c1' }));
  await http.post('/patients/1/consultations', { a: 1 });
  assert.equal(calls[0].init.headers['Content-Type'], 'application/json');
  assert.equal(calls[0].init.body, '{"a":1}');
});

test('http without a sign-in goes to the login page and does not call the backend', async () => {
  reset(); fakeFetch(() => { throw new Error('no call expected'); });
  assert.equal(await leaves(http.get('/patients')), true);
  assert.equal(calls.length, 0);
  assert.match(location.replaced, /^login\.html\?next=/);
});

test('http: a 401 signs out and goes to the login page; other errors are thrown', async () => {
  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'tok', refreshToken: 'r', exp: Date.now() + 3_600_000 }));
  fakeFetch(() => json(401, { detail: 'Invalid or expired token' }));
  assert.equal(await leaves(http.get('/patients')), true);
  assert.equal(auth.isSignedIn(), false);
  assert.match(location.replaced, /^login\.html/);

  reset(); mem.set('dms-auth', JSON.stringify({ idToken: 'tok', refreshToken: 'r', exp: Date.now() + 3_600_000 }));
  fakeFetch(() => json(404, { detail: 'Patient not found' }));
  await assert.rejects(http.get('/patients/9/readings'), /404/);
  assert.equal(auth.isSignedIn(), true);
  assert.equal(location.replaced, null);
});
