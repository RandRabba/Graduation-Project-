// Appearance: 'system' (default, follows the device), or a manual 'light' / 'dark' override.
// Saved automatically in localStorage and applied immediately on every open page (boot.js applies it before drawing).
const root = document.documentElement;
const darkMq = matchMedia('(prefers-color-scheme: dark)');

export function applyTheme(p) {
  root.dataset.themePref = p;
  root.dataset.theme = p === 'system' ? (darkMq.matches ? 'dark' : 'light') : p;
}
export function setTheme(p) {
  try { localStorage.setItem('dms-theme', p); } catch (e) { /* storage unavailable */ }
  applyTheme(p);
}
export const themePref = () => root.dataset.themePref || 'system';

// The device appearance changed while the page is open
darkMq.addEventListener('change', () => { if (root.dataset.themePref === 'system') applyTheme('system'); });
// The choice changed in another tab
addEventListener('storage', e => {
  if (e.key === 'dms-theme') applyTheme(e.newValue === 'light' || e.newValue === 'dark' ? e.newValue : 'system');
});
