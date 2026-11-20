// Navigation after an action (like the PHP redirect after a POST). Reloads even when only the #hash differs,
// so the page is drawn again from the updated data.
export function go(target) {
  const u = new URL(target, location.href);
  if (u.pathname === location.pathname && u.search === location.search) {
    if (u.hash !== location.hash) history.replaceState(null, '', u.href);
    location.reload();
  } else location.href = u.href;
}
