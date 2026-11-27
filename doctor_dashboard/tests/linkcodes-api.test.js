// Link codes in API mode (js/data/api.js → js/data/http.js), with fetch and the browser's storage replaced by fakes.
// Run: npm test
import test from 'node:test';
import assert from 'node:assert/strict';

const mem = new Map();
const store = () => ({ getItem: k => (mem.has(k) ? mem.get(k) : null), setItem: (k, v) => mem.set(k, String(v)), removeItem: k => mem.delete(k), clear: () => mem.clear() });
globalThis.sessionStorage = store();
globalThis.localStorage = store();
globalThis.location = { pathname: '/doctor_dashboard/patients.html', search: '', hash: '', replace() {} };
globalThis.document = globalThis.document ?? { documentElement: {}, cookie: '' };

const { CONFIG } = await import('../js/config.js');
CONFIG.dataSource = 'api';   // before api.js is loaded: it reads the mode once
const { createLinkCode, listLinkCodes, cancelLinkCode } = await import('../js/data/api.js');

mem.set('dms-auth', JSON.stringify({ idToken: 'id-1', refreshToken: 'r-1', exp: Date.now() + 3600e3 }));   // signed in
const json = (status, body) => ({ ok: status >= 200 && status < 300, status, json: async () => body });
let calls;
const fakeFetch = handler => { calls = []; globalThis.fetch = async (url, init = {}) => { calls.push({ url: String(url), init }); return handler(String(url), init); }; };

const pending = { id: 'DMS-2345-6789-AB', label: 'Ahmad', code: 'DMS-2345-6789-AB', at: 1790000000, st: 'pending', usedAt: null };
const used = { id: 'DMS-CCCC-DDDD-EF', label: 'Lina', code: 'DMS-CCCC-DDDD-EF', at: 1780000000, st: 'used', usedAt: 1781000000 };

test('createLinkCode posts the label to the backend and returns the code it made', async () => {
  fakeFetch(() => json(201, pending));
  const c = await createLinkCode('  Ahmad  ');
  assert.deepEqual(c, pending);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].init.method, 'POST');
  assert.equal(calls[0].url, `${CONFIG.apiBaseUrl}/doctor/link-codes`);
  assert.deepEqual(JSON.parse(calls[0].init.body), { label: 'Ahmad' });
  assert.equal(calls[0].init.headers.Authorization, 'Bearer id-1');
  assert.equal(localStorage.getItem('dms-link-codes'), null, 'nothing is kept in the browser in API mode');
});

test('createLinkCode refuses an answer that is not a code', async () => {
  fakeFetch(() => json(201, { id: 'x', code: 'hello there', st: 'pending' }));
  await assert.rejects(createLinkCode('A'), /invalid response/);
});

test('createLinkCode fails when the backend refuses (too many unused codes)', async () => {
  fakeFetch(() => json(409, { detail: 'Too many unused codes' }));
  await assert.rejects(createLinkCode('A'), /409/);
});

test('listLinkCodes returns pending and used codes, newest first, and drops broken records', async () => {
  fakeFetch(() => json(200, [used, { ...pending, code: '<script>' }, pending]));
  assert.deepEqual((await listLinkCodes()).map(c => c.code), [pending.code, used.code]);
  assert.equal(calls[0].init.method, 'GET');
});

test('cancelLinkCode deletes a pending code on the backend', async () => {
  fakeFetch((url, init) => (init.method === 'DELETE' ? json(204, null) : json(200, [pending, used])));
  assert.equal(await cancelLinkCode(pending.id), true);
  const del = calls.find(c => c.init.method === 'DELETE');
  assert.equal(del.url, `${CONFIG.apiBaseUrl}/doctor/link-codes/DMS-2345-6789-AB`);
});

test('cancelLinkCode never tries to cancel a used or unknown code', async () => {
  fakeFetch(() => json(200, [pending, used]));
  assert.equal(await cancelLinkCode(used.id), false);
  assert.equal(await cancelLinkCode('DMS-ZZZZ-ZZZZ-ZZ'), false);
  assert.ok(calls.every(c => c.init.method === 'GET'));
});
