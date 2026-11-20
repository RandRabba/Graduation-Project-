// Shared HTML pieces. Each returns an HTML string.
import { t, tt, tv, ldate, ltr, iso } from '../core/i18n.js';
import { h, ic, initials, dash } from '../core/dom.js';
import { DAY, now, today, addDays, addHours, ymd, parseYmd, startOfDay } from '../core/time.js';
import { targets, stRange, statusHistory, dailyAverages } from '../core/clinical.js';
import { docPhoto } from '../data/api.js';
import { targetLines } from './charts.js';

export const PST = { ok: t('st.ok'), ctrl: t('st.ctrl'), high: t('st.high'), crit: t('st.crit'), low: t('st.low') };
// Label of a single READING. Same as PST except 'ctrl': a reading of 181–250 is "Above target"; "Controlled" is
// only the patient's overall status (badge, status history, statistics)
export const readingLabel = st => (st === 'ctrl' ? t('st.reading.ctrl') : PST[st]);
export const GSRC = { manual: [ic('drop'), t('src.manual')], cgm: [ic('activity'), t('src.cgm')] };
export const RTYPE = { med: [ic('pill'), t('rtype.med')], glu: [ic('drop'), t('rtype.glu')], meal: [ic('meal'), t('rtype.meal')], visit: [ic('calendar'), t('rtype.visit')], custom: [ic('note'), t('rtype.custom')] };
export const RREP = { once: t('rrep.once'), daily: t('rrep.daily'), weekly: t('rrep.weekly') };
export const RSRC = { doctor: t('rsrc.doctor'), patient: t('rsrc.patient'), system: t('rsrc.system'), prescription: t('rsrc.prescription') };
export const RST = { up: t('rst.up'), done: t('rst.done'), missed: t('rst.missed') };
const RCL = { up: 'info', done: 'ok', missed: 'high' };
export const UNIT = () => ` <span>${tt('unit.mgdl')}</span>`;
export const lower = s => String(s).toLocaleLowerCase();
// Text of unknown language (typed by a person) gets automatic direction; text built by the dashboard is already
// isolated (core/i18n.js bidi) and must inherit the page direction, because automatic direction ignores isolates
export const auto = s => (/[\u2066-\u2069]/.test(String(s ?? '')) ? `<span>${h(s)}</span>` : `<bdi>${h(s)}</bdi>`);

// "52 years · Male · Type 2 · Insulin". Before the initial consultation the type is self-reported
export function patientMeta(p) {
  const a = [];
  if (p.age !== null && p.age !== undefined) a.push(t('pat.years', { n: p.age }));
  if (p.sex) a.push(t('sex.' + p.sex));
  if (p.type) a.push(tv('ptype.', p.type));
  else if (p.reportedType) a.push(t('pat.reported_type', { v: tv('ptype.', p.reportedType) }));
  if (p.treat) a.push(tv('treat.', p.treat));
  return a.length ? a.join(' · ') : t('pat.no_profile');
}
export const statusPill = st => (st && PST[st] ? `<span class="pill b-${st}">${h(PST[st])}</span>` : `<span class="pill b-none">${tt('common.no_data')}</span>`);
export const awaitingPill = () => `<span class="pill b-await">${ic('calendar')} ${tt('cons.awaiting')}</span>`;
// Status with where it comes from, so a status is never shown without saying how it was obtained
export const statusSource = p => (p.statusSrc === 'backend' ? tt('status.src.backend') : tt('status.src.calc'));
export function statusBlock(p) {
  return `<span class="stblock">${statusPill(p.status)}${p.awaiting ? awaitingPill() : ''}<small>${statusSource(p)}</small></span>`;
}
export const flagText = f => t('flag.' + f.k, { ...(f.a ?? {}), at: f.a?.at ? ldate('M d', f.a.at) : '' });
export const flagChips = (flags, max = 4) => (flags.length ? `<span class="flags">${flags.slice(0, max).map(f => `<span class="flag f-${f.sev}">${h(flagText(f))}</span>`).join('')}${flags.length > max ? `<span class="flag f-info">+${flags.length - max}</span>` : ''}</span>` : '');

// Medication helpers
// The dose and its unit stay together, and an English drug name keeps its own direction, in Arabic text
export const medDose = v => iso(`${v.dose} ${t('unit.' + v.unit)}`);
export const medSchedule = v => [t('freq.' + v.freq), ...(v.timing ?? []).map(k => t('timing.' + k))].join(' · ');
export const medLine = v => `${iso(v.drug)} ${medDose(v)} · ${t('route.' + v.route)} · ${medSchedule(v)}`;

export const alertTitle = a => t('al.title.' + a.st, { v: a.v ?? '—' }) + (a.n > 1 ? ' · ' + t('al.episode', { n: a.n }) : '');
// Consultation type as displayed: only Initial or Follow-up. An older record stored as 'urgent' is a follow-up visit;
// the record itself (kind, date, notes, treatment changes) is unchanged. Urgency is a separate flag (c.urgent)
export const consKind = k => t(k === 'initial' ? 'cons.kind.initial' : 'cons.kind.follow_up');
export const reportTitle = r => t('rep.title.' + r.kind);
export const avatar = (name, cls = 'avatar', tag = 'div') => `<${tag} class="${cls}">${h(initials(name))}</${tag}>`;
export const card = (cls, icon, label, value, sub = '') =>
  `<div class="card ${cls}"><div class="ico">${ic(icon)}</div><div><small>${h(label)}</small><b>${value}</b>${sub ? `<small class="csub">${sub}</small>` : ''}</div></div>`;

// ===== Notifications: icon, title and detail line =====
export const NICON = { glucose: 'alert', request: 'calendar', message: 'chat', treatment: 'pill', followup: 'clock', adherence: 'xcircle' };
export function notifText(n) {
  const a = n.a;
  switch (n.kind) {
    case 'glucose': return { title: alertTitle(a), sub: '' };
    case 'request': return { title: t('n.request.' + a.kind), sub: a.note };
    case 'message': return { title: t('n.message'), sub: a.text };
    case 'treatment': return { title: t('n.treatment'), sub: a.ch.map(c => c.act === 'change' && c.prev ? `${iso(c.drug)} ${medDose(c.prev)} → ${medDose(c)}` : `${t('medact.' + c.act)}: ${iso(c.drug)} ${medDose(c)}`).join(' · ') + ' · ' + t('sync.pending_short') };
    case 'followup': return { title: t(a.over ? 'n.fu_over' : 'n.fu_due'), sub: ldate('D, M d · h:i A', a.at) };
    case 'adherence': return { title: t('n.adherence', { n: a.n }), sub: '' };
    default: return { title: n.kind, sub: '' };
  }
}
// Where the action of a notification leads
export function notifLink(n, back = 0) {
  switch (n.kind) {
    case 'glucose': return `patient.html?id=${n.pid}&alert=${encodeURIComponent(n.id)}${back ? '&p=' + back : ''}#t-glu`;
    case 'request': return `consultation.html?id=${n.pid}`;
    case 'message': return `chat.html?p=${n.pid}`;
    case 'treatment': return `patient.html?id=${n.pid}#t-med`;
    case 'followup': return `consultation.html?id=${n.pid}`;
    default: return `patient.html?id=${n.pid}#t-med`;
  }
}

// Doctor's photo, or initials without "Dr."
export function docAvatar(d, cls = 'avatar') {
  const p = docPhoto(d);
  return p ? `<img class="${cls} pic" src="${h(p)}" alt="${h(d.name)}">` : `<span class="${cls}">${h(initials(String(d.name).replace(/^Dr\.?\s*/i, '')))}</span>`;
}

// ===== Daily average chart (kept for the status history and reports) =====
// Daily averages; days without readings are shaded "No data" and break the line (nothing is drawn between them)
export function avgChart(series, label) {
  const n = series.length, step = n > 1 ? 600 / (n - 1) : 0, pts = [], segs = [];
  let o = `<svg class="chart" viewBox="0 0 700 200" role="img" aria-label="${h(label)}"><rect x="0" y="${170 - (180 - 60) / 200 * 140}" width="700" height="${(180 - 70) / 200 * 140}" class="band"/>`;
  let cur = [];
  series.forEach(([day, v], i) => {
    const x = Math.round((50 + i * step) * 10) / 10;
    if (n <= 7 || i % 5 === 0) o += `<text x="${x}" y="195" text-anchor="middle" class="ax">${h(ldate(n > 7 ? 'M d' : 'D', day))}</text>`;
    if (v === null) {
      if (cur.length) segs.push(cur); cur = [];
      const w = Math.max(8, step || 40);
      o += `<rect x="${Math.round((x - w / 2) * 10) / 10}" y="30" width="${Math.round(w * 10) / 10}" height="140" class="nodata"><title>${h(ldate('M d', day) + ' · ' + t('chart.no_data_day'))}</title></rect>`;
      return;
    }
    const q = [x, Math.round((170 - (Math.max(60, Math.min(260, v)) - 60) / 200 * 140) * 10) / 10, v, day];
    pts.push(q); cur.push(q);
  });
  if (cur.length) segs.push(cur);
  if (pts.length) {
    o += segs.filter(sg => sg.length > 1).map(sg => `<polyline class="line" points="${sg.map(q => q[0] + ',' + q[1]).join(' ')}"/>`).join('');
    // Values on the first, last, highest and lowest points only; every point has a tooltip
    const lab = new Set([pts[0], pts.at(-1), pts.reduce((a, q) => (q[2] > a[2] ? q : a)), pts.reduce((a, q) => (q[2] < a[2] ? q : a))]);
    for (const q of pts) o += `<circle cx="${q[0]}" cy="${q[1]}" r="5" class="dot"><title>${h(ldate('M d', q[3]) + ' · ' + q[2] + ' mg/dL')}</title></circle>${lab.has(q) || n <= 7 ? `<text x="${q[0]}" y="${q[1] - 12}" text-anchor="middle">${q[2]}</text>` : ''}`;
  } else o += `<text x="350" y="60" text-anchor="middle" class="ax">${tt('empty.readings')}</text>`;
  return o + '</svg>';
}

export function readingRow(r, tg) {
  const s = GSRC[r.src];
  return `<div class="row ${r.st}" data-s="${h(lower(s[1] + ' ' + (r.type ?? '') + ' ' + r.v + ' ' + readingLabel(r.st)))}"><div class="who"><div class="ico">${s[0]}</div><div><b>${h(s[1])}</b><small>${h(r.type ?? '')}</small></div></div><div class="val"><bdi class="qty"><b>${h(r.v)}</b> <span>${tt('unit.mgdl')}</span></bdi><div class="when">${h(ldate('M d, Y · h:i A', r.at))}</div></div><div class="stat"><span class="pill">${h(readingLabel(r.st))}</span><span class="rng">(${ltr(stRange(r.st, tg, r.v))})</span></div><span></span></div>`;
}

// ===== Glucose through one day =====
export function selectedDay(p) { return parseYmd(new URLSearchParams(location.search).get('day')) ?? p.focus_day ?? today(); }
export function dayTimeline(p, url) {
  const tg = targets(p), day = selectedDay(p), end = addDays(day, 1);
  const rs = p.readings.filter(r => r.at >= day && r.at < end).reverse();
  let o = `<div class="seg daysel" role="group" aria-label="${tt('tl.days')}">`;
  for (let i = 6; i >= 0; i--) {
    const d = addDays(today(), -i), on = d === day;
    o += `<a href="${h(url(ymd(d)))}" class="${on ? 'on' : ''}"${on ? ' aria-current="true"' : ''}>${h({ 0: t('day.today'), 1: t('day.yesterday') }[i] ?? ldate('M d', d))}</a>`;
  }
  o += '</div>';
  if (!rs.length) return o + `<p class="empty">${tt('tl.none')}</p>`;
  const counts = {}; for (const r of rs) counts[r.st] = (counts[r.st] ?? 0) + 1;
  o += '<div class="tlsum">' + Object.entries(counts).map(([st, n]) => `<span class="pill b-${st}">${h(readingLabel(st))} · ${n}</span>`).join('') + '</div>';
  const L = 50, R = 704, T = 14, B = 204, V0 = 40, V1 = 320;
  const X = ts => Math.round((L + (ts - day) / (end - day) * (R - L)) * 10) / 10;
  const Y = v => Math.round((B - (Math.max(V0, Math.min(V1, v)) - V0) / (V1 - V0) * (B - T)) * 10) / 10;
  o += `<svg class="chart gchart tl" viewBox="0 0 720 232" role="img" aria-label="${tt('tl.title')}"><rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${Y(tg.low) - Y(tg.high)}" class="band"/>`;
  o += targetLines(tg, L, R, Y) + `<line x1="${L}" x2="${R}" y1="${B}" y2="${B}" class="grid"/>`;
  for (let hr = 0; hr < 24; hr += 3) { const ts = addHours(day, hr);
    o += `<line x1="${X(ts)}" x2="${X(ts)}" y1="${B}" y2="${B + 4}" class="grid"/><text x="${X(ts)}" y="${B + 18}" text-anchor="middle" class="ax">${h(ldate('g A', ts))}</text>`; }
  o += `<polyline class="tline" points="${rs.map(r => X(r.at) + ',' + Y(r.v)).join(' ')}"/>`;
  for (const r of rs) {
    const x = X(r.at), y = Y(r.v), tip = `<title>${h(`${r.v} mg/dL · ${ldate('h:i A', r.at)} · ${GSRC[r.src][1]} · ${readingLabel(r.st)}`)}</title>`;
    o += r.src === 'cgm' ? `<circle cx="${x}" cy="${y}" r="5" class="p-${r.st}">${tip}</circle>` : `<rect x="${x - 5}" y="${y - 5}" width="10" height="10" class="p-${r.st}">${tip}</rect>`;
    if (rs.length <= 16) o += `<text x="${x}" y="${y - 10}" text-anchor="middle" class="mm">${h(r.v)}</text>`;
  }
  o += `</svg><small class="note"><span class="lg dotk"></span> ${tt('src.cgm')} &nbsp; <span class="lg sqk"></span> ${tt('glu.manual')}</small>`;
  return o + `<details class="dtable"><summary>${tt('tl.list', { n: rs.length })}</summary><section class="list tllist">${rs.map(r => readingRow(r, tg)).join('')}</section></details>`;
}
export { targetLines };

// ===== Status history (Overview): one compact row per week, last 3 weeks =====
// Each week is classified with the existing rule (core/clinical statusHistory: sensor data on at least 70% of its
// days). A week WITH readings but too little sensor coverage says so; "No readings" only when there are none.
// The detailed readings stay in Glucose Monitoring.
export const weekLabel = w => ldate('M d', w.from) + ' – ' + ldate('M d', w.to - 1);
export function statusHistoryHtml(p) {
  return `<ol class="shist2">${statusHistory(p).map(w => {
    const k = w.st ?? (w.n ? 'insuf' : 'none');
    const badge = w.st ? statusPill(w.st) : `<span class="pill b-none">${tt(w.n ? 'hist.insuf' : 'hist.no_readings')}</span>`;
    const sub = w.n ? tt('hist.n_readings', { n: w.n }) + (w.st && w.tir !== null ? ' · ' + tt('hist.tir', { v: w.tir }) : '') : '';
    return `<li class="sh-${k}"><span class="shd"><b>${h(weekLabel(w))}</b>${w.now ? `<small>${tt('hist.now')}</small>` : ''}</span>${badge}${sub ? `<small class="shn">${sub}</small>` : ''}</li>`;
  }).join('')}</ol>`;
}

// ===== Reminders =====
export function remWhen(ts) {
  const d = Math.round((startOfDay(ts) - today()) / DAY);
  const day = { [-1]: 'day.yesterday', 0: 'day.today', 1: 'day.tomorrow' }[d];
  return (day ? t(day) : ldate('M d, Y', ts)) + ' · ' + ldate('h:i A', ts);
}
export function remRow(r, pt = '', act = '') {
  const ty = RTYPE[r.type] ?? RTYPE.custom;
  const meta = (pt !== '' ? `<a href="patient.html?id=${r.pid}#t-com">${h(pt)}</a> · ` : '') + h(ty[1] + ' · ' + RREP[r.rep]);
  return `<div class="row ${RCL[r.st]}" data-t="${r.st}" data-s="${h(lower(r.title + ' ' + pt + ' ' + ty[1] + ' ' + RST[r.st]))}"><div class="who"><div class="ico">${ty[0]}</div><div><b>${auto(r.title)}</b><small>${meta}</small></div></div><div class="val"><span>${h(remWhen(r.at))}</span></div><div class="stat"><span class="pill">${h(RST[r.st])}</span><span class="rng">${h(RSRC[r.src] ?? '')}</span></div>${act !== '' ? `<div class="act">${act}</div>` : '<span></span>'}</div>`;
}

// Range presets and custom dates shared by Home, Monitoring, Nutrition and Statistics (?r=7d|14d|30d or ?from=&to=)
export const RANGES = { '24h': 1, '7d': 7, '14d': 14, '30d': 30 };
const KEYS = ['7d', '14d', '30d'];
export function readRange(q, def = '14d', keys = KEYS) {
  const f = parseYmd(q.get('from')), tt0 = parseYmd(q.get('to'));
  if (f !== null && tt0 !== null && tt0 >= f) return { key: 'custom', from: f, to: Math.min(addDays(tt0, 1), now()), fromS: q.get('from'), toS: q.get('to') };
  const key = keys.includes(q.get('r')) ? q.get('r') : def, to = now();
  return { key, from: to - RANGES[key] * DAY, to, fromS: ymd(to - RANGES[key] * DAY), toS: ymd(to) };
}
// Preset buttons + from/to dates. link(o) builds the URL with the given query changes.
// keys = [] shows the From / To dates only. The end date is inclusive (readRange counts the whole day)
export function rangeControls(rg, link, keys = KEYS) {
  return `${keys.length ? `<div class="seg" role="group" aria-label="${tt('glu.range')}">${keys.map(k =>
    `<a href="${h(link({ r: k, from: null, to: null }))}" class="${rg.key === k ? 'on' : ''}"${rg.key === k ? ' aria-current="true"' : ''}>${tt('glu.r.' + k)}</a>`).join('')}</div>` : ''}
    <form class="dates" data-range novalidate>
      <label><span>${tt('range.from')}</span><input type="date" name="from" value="${h(rg.fromS)}" max="${h(rg.toS)}" required></label>
      <label><span>${tt('range.to')}</span><input type="date" name="to" value="${h(rg.toS)}" min="${h(rg.fromS)}" max="${ymd(now())}" required></label>
      <button class="btn sm" type="submit">${tt('range.apply')}</button>
      <small class="derr" role="alert" hidden>${tt('range.invalid')}</small></form>`;
}
// root: wire only the forms inside this element (a page with two independent ranges, e.g. the patient file)
export function wireRange(link, root = document) {
  root.querySelectorAll('form[data-range]').forEach(f => {
    const { from, to } = f.elements, err = f.querySelector('.derr');
    const mark = bad => { f.classList.toggle('bad', bad); [from, to].forEach(i => i.setAttribute('aria-invalid', bad)); if (err) err.hidden = !bad; };
    // each date limits the other in the picker, so From can't be set after To
    const sync = () => { to.min = from.value; if (to.value) from.max = to.value; mark(false); };
    from.oninput = sync; to.oninput = sync;
    f.onsubmit = e => {
      e.preventDefault();
      const a = from.value, b = to.value;
      if (!a || !b || b < a) { mark(true); return; }
      location.href = link({ r: null, from: a, to: b });
    };
  });
}

export const empty = (key, a) => `<p class="empty">${tt(key, a)}</p>`;
export { dash, now };
