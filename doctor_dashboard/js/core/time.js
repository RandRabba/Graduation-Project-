// Time helpers. All timestamps in the app are Unix seconds (like the PHP version and a typical API).
// Day arithmetic goes through Date so it stays correct across daylight-saving changes.

export const DAY = 86400;
export const now = () => Math.floor(Date.now() / 1000);
const toDate = ts => new Date(ts * 1000);
const toTs = d => Math.floor(d.getTime() / 1000);

// Local midnight of the day containing ts (PHP: strtotime('today', ts))
export function startOfDay(ts = now()) { const d = toDate(ts); d.setHours(0, 0, 0, 0); return toTs(d); }
export const today = () => startOfDay();
// ts moved by n calendar days, same clock time (PHP: strtotime("+n days", ts))
export function addDays(ts, n) { const d = toDate(ts); d.setDate(d.getDate() + n); return toTs(d); }
export function addHours(ts, n) { return ts + n * 3600; }

// 'YYYY-MM-DD' <-> local midnight timestamp (used in ?day= links)
const pad = n => String(n).padStart(2, '0');
export function ymd(ts) { const d = toDate(ts); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; }
export function parseYmd(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const [y, m, d] = s.split('-').map(Number); const dt = new Date(y, m - 1, d);
  return Number.isNaN(dt.getTime()) ? null : toTs(dt);
}
// Value for <input type="datetime-local"> and back
export function toLocalInput(ts) { const d = toDate(ts); return `${ymd(ts)}T${pad(d.getHours())}:${pad(d.getMinutes())}`; }
export function fromLocalInput(s) { const t = Date.parse(s); return Number.isNaN(t) ? null : Math.floor(t / 1000); }

// Small subset of PHP date() formats used by the dashboard: d j D M Y g G h H i A
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
export function phpDate(fmt, ts) {
  const d = toDate(ts), H = d.getHours(), h12 = H % 12 || 12;
  const map = { d: pad(d.getDate()), j: d.getDate(), D: DOW[d.getDay()], M: MON[d.getMonth()], Y: d.getFullYear(),
    g: h12, G: H, h: pad(h12), H: pad(H), i: pad(d.getMinutes()), A: H < 12 ? 'AM' : 'PM' };
  return fmt.replace(/[djDMYgGhHiA]/g, c => map[c]);
}
