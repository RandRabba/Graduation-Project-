// Translations: English is the default and the fallback for any key missing in Arabic.
// The language is stored in localStorage ('dms-lang') and applied before drawing by boot.js.
import en from '../i18n/en.js';
import ar from '../i18n/ar.js';
import { CONFIG } from '../config.js';
import { local } from './storage.js';
import { phpDate } from './time.js';
import { h } from './dom.js';

export const LANGS = ['en', 'ar'];
const stored = local.getRaw('dms-lang');
export const LANG = LANGS.includes(stored) ? stored : CONFIG.defaultLang;
export const DIR = LANG === 'ar' ? 'rtl' : 'ltr';
const DICT = LANG === 'en' ? en : { ...en, ...ar };

export function setLang(l) { if (LANGS.includes(l)) local.setRaw('dms-lang', l); }

// t(): plain text with {placeholders}. tt(): the same, HTML-escaped for templates
// ===== Bidirectional text (Arabic only) =====
// Arabic sentences contain numbers, units, abbreviations and English drug names ("318 mg/dL", "HbA1c 8.6%",
// "70–180", "11:22"). Without isolation the browser's bidi algorithm can reorder them ("mg/dL 318") or move
// punctuation. bidi() isolates every Latin/number run as left-to-right (LRI…PDI) and the whole Arabic phrase
// as right-to-left (RLI…PDI), so it reads correctly both in RTL pages and inside left-to-right charts.
// English text is never changed.
export const RTL = DIR === 'rtl';
const LRI = '\u2066', RLI = '\u2067', PDI = '\u2069';
const RUN = /(?:[<>≤≥±+−-]\s?)?[A-Za-z0-9](?:[A-Za-z0-9 .,:\/%+\-–−×=]*[A-Za-z0-9%])?/g;
const ARABIC = /[\u0600-\u06FF]/;
export function bidi(s) {
  if (!RTL || s === null || s === undefined) return s;
  s = String(s).replace(/[\u2066-\u2069]/g, '').replace(RUN, m => LRI + m + PDI);
  return ARABIC.test(s) ? RLI + s + PDI : s;
}
// A piece that must stay together in Arabic, e.g. a dose "12 وحدة" next to an English drug name.
// The direction is chosen explicitly (Arabic inside → right-to-left, otherwise left-to-right): a first-strong
// isolate would ignore Arabic words that are themselves isolated translations
export function iso(s) {
  if (!RTL) return s;
  const x = String(s).replace(/[\u2066-\u2069]/g, '');
  return (ARABIC.test(x) ? RLI : LRI) + x + PDI;
}

// t(): plain text with {placeholders}. Placeholder values that are HTML (e.g. a counter <span>) are kept out
// of the bidi processing and put back unchanged, and so are values that are already isolated (dates from ldate(),
// iso() doses): stripping their isolates would let neighbouring numbers merge ("2026 – 12" in a date range)
export function t(k, a = {}) {
  let s = DICT[k] ?? k; const html = [];
  for (const [n, v] of Object.entries(a)) {
    let val = String(v);
    if (RTL && (/<[a-z]/i.test(val) || /[\u2066-\u2069]/.test(val))) { html.push(val); val = String.fromCharCode(0xE000 + html.length - 1); }
    s = s.split(`{${n}}`).join(val);
  }
  if (!RTL) return s;
  s = bidi(s);
  return html.length ? s.replace(/[\uE000-\uE0FF]/g, c => html[c.charCodeAt(0) - 0xE000]) : s;
}
export const tt = (k, a = {}) => h(t(k, a));
// A value coming from the backend: translated when a key exists for it, otherwise shown as is
export const tv = (prefix, v) => (v != null && DICT[prefix + v] !== undefined ? DICT[prefix + v] : (v ?? ''));
export const has = k => DICT[k] !== undefined;

// Dates with month/day names and AM/PM in the current language (PHP ldate)
let calMap = null;
export function ldate(fmt, ts) {
  if (!Number.isFinite(ts)) return String(ts ?? '');
  if (LANG === 'en') return phpDate(fmt, ts);
  // Arabic order: day before month ("7 نوفمبر 2026"), Arabic comma, then names in Arabic
  const f = fmt.replace(/M d, Y/, 'j M Y').replace(/M d/, 'j M').replace('D, ', 'D، ').replace(', h', ' · h');
  if (!calMap) {
    calMap = { AM: DICT['time.am'], PM: DICT['time.pm'] };
    for (const x of ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) calMap[x] = DICT['cal.' + x];
  }
  return bidi(phpDate(f, ts).replace(/Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Mon|Tue|Wed|Thu|Fri|Sat|Sun|AM|PM/g, m => calMap[m]));
}
// A signed number (+23) or range (70 – 180) that keeps its order inside Arabic text
export const ltr = v => `<bdi dir="ltr">${h(v)}</bdi>`;
