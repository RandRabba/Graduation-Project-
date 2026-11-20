// Runs in <head> before the page is drawn, so there is no flash of the wrong theme or text direction.
// Appearance: 'system' (default, follows the device) or a manual 'light' / 'dark' override (see core/theme.js).
// Language: 'en' (default) or 'ar' (right-to-left).
(function () {
  var r = document.documentElement, p, l;
  var sd;
  try { p = localStorage.getItem('dms-theme'); l = localStorage.getItem('dms-lang'); sd = localStorage.getItem('dms-side'); } catch (e) {}
  // Sidebar collapsed to icons (layout.js toggle), applied before drawing so it doesn't jump
  if (sd === 'mini') r.dataset.side = 'mini';
  if (p !== 'light' && p !== 'dark') p = 'system';
  r.dataset.themePref = p;
  r.dataset.theme = p === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : p;
  l = l === 'ar' ? 'ar' : 'en';
  r.lang = l;
  r.dir = l === 'ar' ? 'rtl' : 'ltr';

  // If the page can't start, say why instead of staying on "Loading…"
  function fail(msg) {
    var b = document.getElementById('boot');
    if (b) b.textContent = msg;
  }
  // Browsers block JavaScript modules on pages opened directly from disk
  if (location.protocol === 'file:') document.addEventListener('DOMContentLoaded', function () {
    fail('Open this folder with Live Server (or any local web server). Browsers block the dashboard scripts on file:// pages. · افتح المجلد باستخدام Live Server.');
  });
  addEventListener('error', function () { fail('Could not load the dashboard. Please reload the page. · تعذّر تحميل لوحة التحكم، أعد تحميل الصفحة.'); });
  addEventListener('unhandledrejection', function () { fail('Could not load the dashboard. Please reload the page. · تعذّر تحميل لوحة التحكم، أعد تحميل الصفحة.'); });
})();
