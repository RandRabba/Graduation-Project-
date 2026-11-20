// Small DOM and HTML helpers shared by every page.
import { ICONS } from './icons-data.js';

export const $ = s => document.querySelector(s);
export const $$ = s => [...document.querySelectorAll(s)];

// Escape text for HTML (PHP htmlspecialchars)
export const h = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[c]));
// Escaped text with line breaks kept (PHP nl2br(h()))
export const nl2br = s => h(s).replace(/\n/g, '<br>');

export const ic = n => `<svg class="i" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${ICONS[n] ?? ''}</svg>`;

// Works with Arabic names and single names
export function initials(n) {
  const p = String(n ?? '').trim().split(/\s+/u);
  const first = [...(p[0] ?? '')][0] ?? '';
  const last = p.length > 1 ? [...p[p.length - 1]][0] ?? '' : '';
  return (first + last).toLocaleUpperCase();
}
// A value that can't be calculated (no readings) shows "—"
export const dash = (v, unit = '') => (v === null || v === undefined ? '—' : `${v}${unit}`);
export const signed = n => (n >= 0 ? '+' : '') + n;

// URL query helpers
export const params = () => new URLSearchParams(location.search);
export const qint = (k, f = 0) => { const v = parseInt(params().get(k) ?? '', 10); return Number.isNaN(v) ? f : v; };
export function url(page, q = {}, hash = '') {
  const s = new URLSearchParams(Object.entries(q).filter(([, v]) => v !== null && v !== undefined && v !== '' && v !== 0)).toString();
  return page + (s ? '?' + s : '') + (hash ? '#' + hash : '');
}
