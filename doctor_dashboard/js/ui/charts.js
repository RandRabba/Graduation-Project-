// Charts shared by Monitoring, Nutrition, Statistics, the patient file and reports. Each returns an SVG/HTML
// string. Rules kept everywhere: the time axis runs left-to-right in both languages; one y-axis per plot
// (different measures are stacked as panels on the same time axis, never on two scales); every mark has a
// hover tooltip and the values are also available in a data table; status colors only for status.
import { t, tt, ldate, ltr, RTL, bidi } from '../core/i18n.js';
import { h } from '../core/dom.js';
import { DAY, addDays, startOfDay } from '../core/time.js';

const r1 = v => Math.round(v * 10) / 10;
const dash = v => (v === null || v === undefined ? '—' : v);
const niceMax = (v, step) => Math.max(step, Math.ceil((v * 1.1) / step) * step);

// Time ticks for an x range: hours for a day, otherwise days (thinned to at most ~8 labels)
export function timeTicks(from, to) {
  const span = to - from, out = [];
  if (span <= 1.01 * DAY) {
    const d0 = new Date(from * 1000); d0.setMinutes(0, 0, 0);
    for (let ts = Math.floor(d0 / 1000) + 3600; ts <= to; ts += 3600) if (new Date(ts * 1000).getHours() % 3 === 0) out.push([ts, ldate('g A', ts)]);
    return out;
  }
  const days = Math.round(span / DAY), step = days <= 8 ? 1 : days <= 16 ? 2 : days <= 35 ? 5 : 10;
  for (let ts = addDays(startOfDay(from), 1), i = 0; ts <= to; ts = addDays(ts, 1), i++) if (i % step === 0) out.push([ts, ldate('M d', ts)]);
  return out;
}
// Target-range lines with their values (low/high first; 54/250 only if they don't overlap)
export function targetLines(tg, L, R, Y) {
  let o = ''; const ly = [];
  for (const g of [tg.low, tg.high, tg.vlow, tg.vhigh]) {
    o += `<line x1="${L}" x2="${R}" y1="${Y(g)}" y2="${Y(g)}" class="grid${[tg.vlow, tg.vhigh].includes(g) ? ' lim' : ''}"/>`;
    if (!ly.some(y => Math.abs(y - Y(g)) < 12)) { ly.push(Y(g)); o += `<text x="${L - 6}" y="${Y(g) + 4}" text-anchor="end" class="ax">${g}</text>`; }
  }
  return o;
}

// ===== Glucose over time, with meals, missed doses and consultations underneath =====
// rs: readings (any order); meals: [{at, carbs, name}]; doses: [{at, taken, label}]; marks: [{at, label}]
// events: false draws readings only (no event strip under the plot, so no empty space)
export function glucoseTimeChart({ rs, tg, from, to, meals = [], doses = [], marks = [], label, events = true }) {
  const L = 50, R = 704, T = 14, B = 204, V0 = 40, V1 = 320, EV = 226, H = events ? 268 : 230, AX = events ? EV + 12 : B;
  if (!events) { meals = []; doses = []; marks = []; }
  const X = ts => r1(L + (ts - from) / (to - from) * (R - L));
  const Y = v => r1(B - (Math.max(V0, Math.min(V1, v)) - V0) / (V1 - V0) * (B - T));
  const asc = [...rs].filter(r => r.at >= from && r.at <= to).sort((a, b) => a.at - b.at);
  // The sensor line breaks on gaps over 3 hours so it doesn't suggest readings that don't exist
  const segs = []; let cur = [], prev = null;
  for (const r of asc) { if (r.src !== 'cgm') continue;
    if (prev !== null && r.at - prev > 3 * 3600) { if (cur.length > 1) segs.push(cur); cur = []; }
    cur.push(X(r.at) + ',' + Y(r.v)); prev = r.at; }
  if (cur.length > 1) segs.push(cur);
  const rad = asc.length > 200 ? 1.6 : asc.length > 80 ? 2.4 : 3.4;
  const tip = r => h(`${r.v} mg/dL · ${ldate('M d, h:i A', r.at)} · ${t(r.src === 'cgm' ? 'src.cgm' : 'src.manual')} · ${t(r.st === 'ctrl' ? 'st.reading.ctrl' : 'st.' + r.st)}`);
  let o = `<svg class="chart gchart" viewBox="0 0 720 ${H}" role="img" aria-label="${h(label)}">
    <rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>${targetLines(tg, L, R, Y)}
    <line x1="${L}" x2="${R}" y1="${B}" y2="${B}" class="grid"/><text x="${L - 6}" y="${T - 2}" text-anchor="end" class="ax">mg/dL</text>
    ${events ? `<line x1="${L}" x2="${R}" y1="${AX}" y2="${AX}" class="grid"/>` : ''}`;
  for (const [ts, lb] of timeTicks(from, to)) o += `<line x1="${X(ts)}" x2="${X(ts)}" y1="${AX}" y2="${AX + 4}" class="grid"/><text x="${X(ts)}" y="${H - 4}" text-anchor="middle" class="ax">${h(lb)}</text>`;
  for (const m of marks.filter(m => m.at >= from && m.at <= to))
    o += `<g class="cmark"><line x1="${X(m.at)}" x2="${X(m.at)}" y1="${T}" y2="${EV + 12}"/><text x="${X(m.at) + 3}" y="${T + 9}">${h(m.short ?? 'C')}</text><title>${h(m.label)}</title></g>`;
  if (!asc.length) return o + `<text x="377" y="100" text-anchor="middle" class="ax">${tt('glu.none_period')}</text></svg>`;
  // Periods of 24 hours or more without any reading (including before the first and after the last one) are
  // shaded and labelled, so an empty stretch is not read as a stable or zero value
  const edges = [from, ...asc.map(r => r.at), to];
  for (let i = 1; i < edges.length; i++) if (edges[i] - edges[i - 1] >= DAY) {
    const x1 = X(edges[i - 1]), x2 = X(edges[i]);
    o += `<rect x="${x1}" y="${T}" width="${r1(x2 - x1)}" height="${B - T}" class="nodata"><title>${h(t('chart.no_data_span', { a: ldate('M d, h:i A', edges[i - 1]), b: ldate('M d, h:i A', edges[i]) }))}</title></rect>`;
    if (x2 - x1 > 60) o += `<text x="${r1((x1 + x2) / 2)}" y="${r1((T + B) / 2)}" text-anchor="middle" class="ax">${tt('chart.no_data')}</text>`;
  }
  o += segs.map(s => `<polyline class="cgm" points="${s.join(' ')}"/>`).join('');
  for (const r of asc) { const x = X(r.at), y = Y(r.v);
    o += r.src === 'cgm' ? `<circle cx="${x}" cy="${y}" r="${rad}" class="dot"><title>${tip(r)}</title></circle>`
      : `<rect x="${x - 4}" y="${y - 4}" width="8" height="8" class="mdot"><title>${tip(r)}</title></rect>`; }
  const hi = asc.reduce((a, r) => (r.v > a.v ? r : a)), lo = asc.reduce((a, r) => (r.v < a.v ? r : a));
  for (const m of [hi, lo]) o += `<text x="${X(m.at)}" y="${m === hi ? Y(m.v) - 8 : Y(m.v) + 16}" text-anchor="middle" class="mm">${h(m.v)}</text>`;
  // Event strip: meals (size by carbs) and missed doses
  for (const m of meals.filter(m => m.at >= from && m.at <= to)) { const x = X(m.at), s = 3 + Math.min(5, m.carbs / 25);
    o += `<path d="M${x} ${EV - s}L${r1(x + s)} ${EV + s / 1.2}L${r1(x - s)} ${EV + s / 1.2}Z" class="ev-meal"><title>${h(`${m.name} · ${m.carbs} g ${t('meals.carbs')} · ${ldate('M d, h:i A', m.at)}`)}</title></path>`; }
  for (const d of doses.filter(d => !d.taken && d.at >= from && d.at <= to)) { const x = X(d.at);
    o += `<g class="ev-miss"><path d="M${x - 4} ${EV - 4}L${x + 4} ${EV + 4}M${x + 4} ${EV - 4}L${x - 4} ${EV + 4}"/><rect x="${x - 7}" y="${EV - 7}" width="14" height="14" class="hit"/><title>${h(`${t('mon.missed_dose')}: ${d.label} · ${ldate('M d, h:i A', d.at)}`)}</title></g>`; }
  return o + '</svg>';
}
export const glucoseLegend = (tg, extra = true) => `<div class="legend"><span><i class="lg dotk"></i>${tt('src.cgm')}</span><span><i class="lg sqk"></i>${tt('glu.manual')}</span>
  ${extra ? `<span><i class="lg trik"></i>${tt('mon.lg_meal')}</span><span><i class="lg xk">×</i>${tt('mon.lg_missed')}</span><span><i class="lg ck"></i>${tt('mon.lg_cons')}</span>` : ''}
  <span><i class="lg bandk"></i>${tt('glu.band_note')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')}</span></div>`;

// ===== Overview: daily average glucose, last 14 days =====
// days: [{ day (local midnight), avg | null, n (readings that day) }] from the patient's actual readings.
// One line of daily averages over the patient's own target band. Nothing is estimated: a day without readings is
// shaded "No readings" and breaks the line; a day with fewer than LIMITED readings has a hollow point and says so.
// Hover/focus a day (data-tip): date, average and the number of readings used.
export const TREND_LIMITED = 3;
export function dailyTrendChart(days, tg, label) {
  const W = 720, L = 46, R = W - 14, T = 24, B = 170, H = 194, n = days.length, cw = (R - L) / n;
  const vs = days.filter(d => d.avg !== null).map(d => d.avg);
  // y-axis from the data: day averages and min/max, always the whole target band, ~10% padding, round ticks
  const ex = days.filter(d => d.min != null && d.max != null).flatMap(d => [d.min, d.max]);
  const lo = Math.min(tg.low, ...vs, ...ex), hi = Math.max(tg.high, ...vs, ...ex), pad = Math.max(10, (hi - lo) * 0.1);
  const step = hi - lo + 2 * pad > 240 ? 50 : hi - lo + 2 * pad > 120 ? 40 : 20;
  const V0 = Math.max(0, Math.floor((lo - pad) / step) * step), V1 = Math.ceil((hi + pad) / step) * step;
  const X = i => r1(L + cw * (i + 0.5)), Y = v => r1(B - (v - V0) / (V1 - V0) * (B - T));
  let o = `<svg class="chart dtrend" viewBox="0 0 ${W} ${H}" role="img" aria-label="${h(label)}">
    <rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>`;
  for (let v = V0; v <= V1; v += step) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid${v === V0 ? '' : ' faint'}"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v}</text>`;
  o += `<text x="${L - 6}" y="10" text-anchor="end" class="ax">mg/dL</text>`;
  days.forEach((d, i) => { if (n <= 8 || i % 2 === (n - 1) % 2) o += `<text x="${X(i)}" y="${H - 4}" text-anchor="middle" class="ax">${h(ldate('M d', d.day))}</text>`; });
  if (!vs.length) return o + `<text x="${(L + R) / 2}" y="${(T + B) / 2}" text-anchor="middle" class="ax">${tt('glu.none_period')}</text></svg>`;
  // line segments only between consecutive days that have readings
  const segs = []; let cur = [];
  days.forEach((d, i) => { if (d.avg === null) { if (cur.length) segs.push(cur); cur = []; } else cur.push(`${X(i)},${Y(d.avg)}`); });
  if (cur.length) segs.push(cur);
  o += segs.filter(sg => sg.length > 1).map(sg => `<polyline points="${sg.join(' ')}" class="s-glu-line"/>`).join('');
  days.forEach((d, i) => {
    const x0 = r1(L + cw * i), lim = d.avg !== null && d.n < TREND_LIMITED;
    const mm = d.avg !== null && d.min != null && d.max != null;
    const tip = [ldate('D, M d', d.day), d.avg === null ? t('chart.no_data_day') : t('ov.tr.tip_avg', { v: d.avg }),
      mm ? t('ov.tr.tip_range', { v: `${d.min}–${d.max} mg/dL` }) : '',
      d.avg === null ? '' : lim ? t('ov.tr.tip_limited', { n: d.n }) : t('ov.tr.tip_n', { n: d.n })].filter(Boolean).join('\n');
    // daily min–max whisker under the average dot (glucose series color, not status colors)
    const wk = mm && d.max > d.min ? `<line x1="${X(i)}" x2="${X(i)}" y1="${Y(d.max)}" y2="${Y(d.min)}" class="whisk"/>` : '';
    if (d.avg === null) o += `<rect x="${x0 + 1}" y="${T}" width="${r1(cw - 2)}" height="${B - T}" rx="3" class="nodata"/>`;
    o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${x0}" y="${T}" width="${r1(cw)}" height="${B - T}" class="hit"/>${wk}${d.avg === null ? ''
      : `<circle cx="${X(i)}" cy="${Y(d.avg)}" r="4" class="${lim ? 'dot-lim' : 's-glu-dot'}"/>`}</g>`;
  });
  return o + '</svg>';
}
export const dailyTrendLegend = tg => `<div class="legend"><span><i class="lg s-glu"></i>${tt('ov.tr.lg_avg')}</span><span><i class="lg whiskk"></i>${tt('ov.tr.lg_range')}</span><span><i class="lg bandk"></i>${tt('glu.target')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')}</span>
  <span><i class="lg limk"></i>${tt('ov.tr.lg_limited', { n: TREND_LIMITED })}</span><span><i class="lg nodk"></i>${tt('ov.tr.lg_none')}</span></div>`;

// ===== Stacked panels sharing one time axis: glucose, carbs, calories, adherence =====
// bs: bucket stats (core/analytics.js series); panels: subset of ['glu', 'carbs', 'kcal', 'adh']
export function trendPanels({ bs, tg, panels = ['glu', 'carbs', 'kcal', 'adh'], marks = [], adhGoal = null, label }) {
  if (!bs.length) return '';
  const L = 50, R = 704, PH = 78, GAP = 30, TOP = 22, from = bs[0].from, to = bs.at(-1).to;
  const H = TOP + panels.length * (PH + GAP) + 6;
  const X = ts => r1(L + (ts - from) / (to - from) * (R - L)), bw = Math.max(2, (R - L) / bs.length - 2);
  const P = {
    glu: { name: t('chart.p.glu'), unit: 'mg/dL', max: 320, min: 40, ticks: [70, 180, 250] },
    carbs: { name: t('chart.p.carbs'), unit: t('unit.g'), min: 0, max: niceMax(Math.max(0, ...bs.map(b => b.carbs ?? 0)), 50) },
    kcal: { name: t('chart.p.kcal'), unit: t('meals.kcal'), min: 0, max: niceMax(Math.max(0, ...bs.map(b => b.kcal ?? 0)), 500) },
    adh: { name: t('chart.p.adh'), unit: '%', min: 0, max: 100, ticks: [50, 100] },
  };
  let o = `<svg class="chart tpanels" viewBox="0 0 720 ${H}" role="img" aria-label="${h(label)}">`;
  panels.forEach((k, i) => {
    const p = P[k], y0 = TOP + i * (PH + GAP), yb = y0 + PH;
    const Y = v => r1(yb - (Math.max(p.min, Math.min(p.max, v)) - p.min) / (p.max - p.min) * PH);
    // In Arabic the title and its unit are one right-to-left phrase, so the unit stays after the name
    o += RTL ? `<text x="${L}" y="${y0 - 8}" class="ptitle">${h(bidi(`${p.name} (${p.unit})`))}</text>`
      : `<text x="${L}" y="${y0 - 8}" class="ptitle">${h(p.name)} <tspan class="ax">(${h(p.unit)})</tspan></text>`;
    o += `<line x1="${L}" x2="${R}" y1="${yb}" y2="${yb}" class="grid"/>`;
    for (const tv of p.ticks ?? [p.max / 2, p.max]) o += `<line x1="${L}" x2="${R}" y1="${Y(tv)}" y2="${Y(tv)}" class="grid faint"/><text x="${L - 6}" y="${Y(tv) + 4}" text-anchor="end" class="ax">${tv}</text>`;
    if (k === 'glu') {
      o += `<rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>`;
      for (const b of bs) if (b.min !== null) { const x = X((b.from + b.to) / 2); o += `<line x1="${x}" x2="${x}" y1="${Y(b.max)}" y2="${Y(b.min)}" class="whisk"/>`; }
      const pts = bs.filter(b => b.avg !== null).map(b => `${X((b.from + b.to) / 2)},${Y(b.avg)}`);
      if (pts.length > 1) o += `<polyline points="${pts.join(' ')}" class="s-glu-line"/>`;
      for (const b of bs) if (b.avg !== null) o += `<circle cx="${X((b.from + b.to) / 2)}" cy="${Y(b.avg)}" r="3.5" class="s-glu-dot"/>`;
    } else {
      for (const b of bs) { const v = b[k]; if (v === null || v === undefined) continue;
        const x = X(b.from) + 1, y = Y(v); o += `<rect x="${r1(x)}" y="${y}" width="${r1(bw)}" height="${r1(Math.max(0, yb - y))}" rx="2" class="s-${k}"/>`; }
      if (k === 'adh' && adhGoal) o += `<line x1="${L}" x2="${R}" y1="${Y(adhGoal)}" y2="${Y(adhGoal)}" class="goal"/><text x="${R - 4}" y="${Y(adhGoal) - 4}" text-anchor="end" class="ax lbl">${tt('chart.goal', { v: adhGoal })}</text>`;
    }
    if (!bs.some(b => (k === 'glu' ? b.avg : b[k]) !== null && (k === 'glu' ? b.avg : b[k]) !== undefined))
      o += `<text x="377" y="${y0 + PH / 2}" text-anchor="middle" class="ax">${tt('common.no_data')}</text>`;
  });
  const lastY = TOP + panels.length * (PH + GAP) - GAP;
  for (const m of marks.filter(m => m.at >= from && m.at <= to))
    o += `<g class="cmark"><line x1="${X(m.at)}" x2="${X(m.at)}" y1="${TOP - 4}" y2="${lastY}"/><text x="${X(m.at) + 3}" y="${TOP + 6}">${h(m.short ?? 'C')}</text><title>${h(m.label)}</title></g>`;
  for (const [ts, lb] of timeTicks(from, to)) o += `<text x="${X(ts)}" y="${H - 2}" text-anchor="middle" class="ax">${h(lb)}</text>`;
  // Hover column per bucket with every value of that day
  for (const b of bs) o += `<rect x="${X(b.from)}" y="${TOP - 14}" width="${r1(X(b.to) - X(b.from))}" height="${lastY - TOP + 14}" class="hit"><title>${h(bucketTip(b))}</title></rect>`;
  return o + '</svg>';
}
export const bucketLabel = b => (b.to - b.from > 1.5 * DAY ? ldate('M d', b.from) + ' – ' + ldate('M d', b.to - 1) : ldate('D, M d', b.from));
const bucketTip = b => [bucketLabel(b), `${t('chart.p.glu')}: ${b.avg === null ? '—' : `${b.avg} mg/dL (${b.min}–${b.max})`}`,
  `${t('card.tir')}: ${dash(b.tir)}${b.tir === null ? '' : '%'}`, `${t('chart.p.carbs')}: ${dash(b.carbs)} ${t('unit.g')}`, `${t('chart.p.kcal')}: ${dash(b.kcal)}`,
  `${t('chart.p.adh')}: ${b.adh === null ? '—' : `${b.adh}% (${b.taken}/${b.sched})`}`].join('\n');
export const panelsLegend = () => `<div class="legend"><span><i class="lg s-glu"></i>${tt('chart.lg.avg')}</span><span><i class="lg whiskk"></i>${tt('chart.lg.range')}</span>
  <span><i class="lg bandk"></i>${tt('chart.lg.target')}</span><span><i class="lg s-carbs"></i>${tt('chart.p.carbs')}</span><span><i class="lg s-kcal"></i>${tt('chart.p.kcal')}</span>
  <span><i class="lg s-adh"></i>${tt('chart.p.adh')}</span><span><i class="lg ck"></i>${tt('mon.lg_cons')}</span></div>`;

// ===== Nutrition: daily carbohydrates and post-meal glucose rise, two panels on one day axis =====
// days: core/analytics dailyPostMealRise. Top: mean post-meal rise (line, breaks on days without a value; can be
// negative, so the zero line is drawn). Bottom: carbohydrates per day (bars). A day with meals but no matched
// readings is shaded and says "Insufficient data"; nothing is estimated. Hover/focus a day: data-tip with both values.
const riseTxt = v => (v > 0 ? '+' : '') + v;
export const riseDayTip = d => [bucketLabel(d),
  d.rise !== null ? t('nut.rp.tip_rise', { v: riseTxt(d.rise), n: d.n, m: d.meals }) + (d.n > 1 ? ' ' + t('nut.rp.tip_span', { a: riseTxt(d.lo), b: riseTxt(d.hi) }) : '')
    : d.meals ? t('nut.rp.tip_insuf', { m: d.meals }) : t('nut.rp.tip_nomeals'),
  `${t('nut.rp.carbs')}: ${d.carbs === null ? '—' : `${d.carbs} ${t('unit.g')}`}`].join('\n');
export function carbRisePanels(days, label) {
  if (!days.length) return '';
  // Wider drawing area than the other panels (it spans the content width); the time axis stays left-to-right
  const W = 960, L = 50, R = W - 16, PH = 84, GAP = 32, TOP = 22, H = TOP + 2 * (PH + GAP) + 6, from = days[0].from, to = days.at(-1).to;
  const X = ts => r1(L + (ts - from) / (to - from) * (R - L)), bw = Math.max(2, (R - L) / days.length - 2);
  const vs = days.filter(d => d.rise !== null).map(d => d.rise);
  // Rise scale: ticks are multiples of one step, so 0 is always a tick (solid line); at most 4 ticks
  const vmin = Math.min(0, ...vs.map(v => v - 5)), vmax = Math.max(40, ...vs.map(v => v + 5));
  const rstep = [20, 40, 50, 100, 150, 200].find(s => Math.ceil(vmax / s) - Math.floor(vmin / s) <= 3) ?? 250;
  const rlo = Math.floor(vmin / rstep) * rstep, rhi = Math.ceil(vmax / rstep) * rstep;
  const cmax = niceMax(Math.max(0, ...days.map(d => d.carbs ?? 0)), 50);
  const P = [
    { name: t('nut.rp.rise'), unit: 'mg/dL', min: rlo, max: rhi },
    { name: t('nut.rp.carbs'), unit: t('unit.g'), min: 0, max: cmax },
  ];
  const y0s = P.map((_, i) => TOP + i * (PH + GAP)), Ys = P.map((p, i) => v => r1(y0s[i] + PH - (Math.max(p.min, Math.min(p.max, v)) - p.min) / (p.max - p.min) * PH));
  let o = `<div class="cscroll"><svg class="chart tpanels wide" viewBox="0 0 ${W} ${H}" role="img" aria-label="${h(label)}">`;
  P.forEach((p, i) => {
    const y0 = y0s[i], yb = y0 + PH, Y = Ys[i];
    // In Arabic the title and its unit are one right-to-left phrase, so the unit stays after the name
    o += RTL ? `<text x="${L}" y="${y0 - 8}" class="ptitle">${h(bidi(`${p.name} (${p.unit})`))}</text>`
      : `<text x="${L}" y="${y0 - 8}" class="ptitle">${h(p.name)} <tspan class="ax">(${h(p.unit)})</tspan></text>`;
    const ticks = i === 0 ? Array.from({ length: Math.round((rhi - rlo) / rstep) + 1 }, (_, k) => rlo + k * rstep) : [0, cmax / 2, cmax];
    for (const tv of ticks) o += `<line x1="${L}" x2="${R}" y1="${Y(tv)}" y2="${Y(tv)}" class="grid${tv === 0 ? '' : ' faint'}"/><text x="${L - 6}" y="${Y(tv) + 4}" text-anchor="end" class="ax">${i === 0 ? riseTxt(tv) : tv}</text>`;
  });
  // Top panel: days with meals but no matched pair are shaded; the line breaks on every day without a value
  const [YR, YC] = Ys, ybC = y0s[1] + PH;
  for (const d of days) if (d.rise === null) o += `<rect x="${r1(X(d.from) + 1)}" y="${y0s[0]}" width="${r1(bw)}" height="${PH}" rx="2" class="nodata"/>`;
  const segs = []; let cur = [];
  for (const d of days) { if (d.rise === null) { if (cur.length) segs.push(cur); cur = []; continue; } cur.push(`${X((d.from + d.to) / 2)},${YR(d.rise)}`); }
  if (cur.length) segs.push(cur);
  o += segs.filter(s => s.length > 1).map(s => `<polyline points="${s.join(' ')}" class="s-glu-line"/>`).join('');
  for (const d of days) if (d.rise !== null) o += `<circle cx="${X((d.from + d.to) / 2)}" cy="${YR(d.rise)}" r="${days.length > 20 ? 3 : 3.5}" class="s-glu-dot"/>`;
  if (!vs.length) o += `<text x="${(L + R) / 2}" y="${y0s[0] + PH / 2 + 4}" text-anchor="middle" class="ax">${tt(days.some(d => d.meals) ? 'st2.insufficient' : 'common.no_data')}</text>`;
  // Bottom panel: carbohydrates per day; a day without logged meals is shaded (no data), not drawn as 0 g
  for (const d of days) { if (d.carbs === null) { o += `<rect x="${r1(X(d.from) + 1)}" y="${y0s[1]}" width="${r1(bw)}" height="${PH}" rx="2" class="nodata"/>`; continue; }
    const y = YC(d.carbs);
    o += `<rect x="${r1(X(d.from) + 1)}" y="${y}" width="${r1(bw)}" height="${r1(Math.max(0, ybC - y))}" rx="2" class="s-carbs"/>`; }
  if (!days.some(d => d.carbs !== null)) o += `<text x="${(L + R) / 2}" y="${y0s[1] + PH / 2 + 4}" text-anchor="middle" class="ax">${tt('common.no_data')}</text>`;
  for (const [ts, lb] of timeTicks(from, to)) o += `<text x="${X(ts)}" y="${H - 2}" text-anchor="middle" class="ax">${h(lb)}</text>`;
  // One hover/focus column per day across both panels, so both values of the same day show together
  const lastY = ybC;
  for (const d of days) { const tip = riseDayTip(d);
    o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${X(d.from)}" y="${TOP - 14}" width="${r1(X(d.to) - X(d.from))}" height="${lastY - TOP + 14}" class="hit"/></g>`; }
  return o + '</svg></div>';
}
export const carbRiseLegend = () => `<div class="legend"><span><i class="lg s-glu"></i>${tt('nut.rp.lg_rise')}</span><span><i class="lg s-carbs"></i>${tt('nut.rp.carbs')}</span><span><i class="lg nodk"></i>${tt('nut.rp.lg_nodata')}</span></div>`;
export const carbRiseTable = days => dataTable([t('chart.col.period'), t('nut.rp.carbs') + ` (${t('unit.g')})`, t('nut.rp.rise') + ' (mg/dL)', t('nut.rp.col_n')],
  days.map(d => [bucketLabel(d), d.carbs, d.rise !== null ? riseTxt(d.rise) : d.meals ? t('st2.insufficient') : null, d.meals ? `${d.n} / ${d.meals}` : null]));

// ===== Time in the five ranges per bucket (100% stacked columns, status colors) =====
const RANGES = ['vlow', 'low', 'in', 'high', 'vhigh'];
export function tirColumns(bs, tg, label) {
  const L = 50, R = 704, T = 10, B = 170, H = 196, n = bs.length, cw = (R - L) / n, bw = Math.min(46, cw - 6);
  const Y = v => r1(B - v / 100 * (B - T));
  let o = `<svg class="chart tircols" viewBox="0 0 720 ${H}" role="img" aria-label="${h(label)}">`;
  for (const v of [0, 50, 100]) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid faint"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v}%</text>`;
  bs.forEach((b, i) => {
    const x = r1(L + i * cw + (cw - bw) / 2), lab = ldate(n > 8 ? 'd' : 'M d', b.from);
    if (n <= 16 || i % 2 === 0) o += `<text x="${r1(x + bw / 2)}" y="${H - 6}" text-anchor="middle" class="ax">${h(lab)}</text>`;
    if (!b.bd) { o += `<rect x="${x}" y="${T}" width="${r1(bw)}" height="${B - T}" rx="3" class="nodata"><title>${h(bucketLabel(b) + ' · ' + t('glu.no_cgm_short'))}</title></rect>`; return; }
    let acc = 0;
    for (const k of RANGES) { const v = b.bd.pct[k]; if (v <= 0) continue;
      const y1 = Y(acc + v), y2 = Y(acc); acc += v;
      o += `<rect x="${x}" y="${y1}" width="${r1(bw)}" height="${r1(Math.max(0.5, y2 - y1 - 1))}" class="t-${k}"/>`; }
    const tip = [bucketLabel(b), ...RANGES.slice().reverse().map(k => `${t('glu.t.' + k)}: ${Math.round(b.bd.pct[k])}%`)].join('\n');
    o += `<rect x="${x - 2}" y="${T}" width="${r1(bw + 4)}" height="${B - T}" class="hit"><title>${h(tip)}</title></rect>`;
  });
  // TIR goal over the columns, with a halo so it stays readable
  o += `<line x1="${L}" x2="${R}" y1="${Y(tg.tir)}" y2="${Y(tg.tir)}" class="goal"/><text x="${L + 4}" y="${Y(tg.tir) - 4}" class="ax lbl">${tt('chart.tir_goal', { v: tg.tir })}</text>`;
  return o + '</svg>';
}
export const tirLegend = tg => `<div class="legend">${RANGES.slice().reverse().map(k => `<span><i class="lg t-${k}"></i>${tt('glu.t.' + k)} ${ltr(
  { vhigh: '> ' + tg.vhigh, high: (tg.high + 1) + '–' + tg.vhigh, in: tg.low + '–' + tg.high, low: tg.vlow + '–' + (tg.low - 1), vlow: '< ' + tg.vlow }[k])}</span>`).join('')}</div>`;

// ===== Ambulatory glucose profile (24-hour percentiles) =====
export function agpChart(prof, tg, label) {
  const L = 50, R = 704, T = 14, B = 204, H = 228, V0 = 40, V1 = 320;
  const X = hr => r1(L + hr / 24 * (R - L)), Y = v => r1(B - (Math.max(V0, Math.min(V1, v)) - V0) / (V1 - V0) * (B - T));
  const pts = prof.filter(p => p.n);
  let o = `<svg class="chart agp" viewBox="0 0 720 ${H}" role="img" aria-label="${h(label)}">
    <rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>${targetLines(tg, L, R, Y)}
    <line x1="${L}" x2="${R}" y1="${B}" y2="${B}" class="grid"/>`;
  for (let hr = 0; hr <= 24; hr += 3) o += `<text x="${X(hr)}" y="${H - 4}" text-anchor="middle" class="ax">${hr === 24 ? '' : h(ldate('g A', Math.floor(new Date(2020, 0, 1, hr) / 1000)))}</text>`;
  if (pts.length < 2) return o + `<text x="377" y="100" text-anchor="middle" class="ax">${tt('glu.no_cgm_short')}</text></svg>`;
  const area = (a, b) => pts.map(p => `${X(p.h + 0.5)},${Y(p[a])}`).join(' ') + ' ' + pts.slice().reverse().map(p => `${X(p.h + 0.5)},${Y(p[b])}`).join(' ');
  o += `<polygon points="${area('p90', 'p10')}" class="agp-outer"/><polygon points="${area('p75', 'p25')}" class="agp-inner"/>`;
  o += `<polyline points="${pts.map(p => `${X(p.h + 0.5)},${Y(p.p50)}`).join(' ')}" class="s-glu-line"/>`;
  for (const p of pts) o += `<rect x="${X(p.h)}" y="${T}" width="${r1(X(1) - X(0))}" height="${B - T}" class="hit"><title>${h(`${ldate('g A', Math.floor(new Date(2020, 0, 1, p.h) / 1000))} · ${t('chart.median')} ${p.p50} · 25–75%: ${p.p25}–${p.p75} · 10–90%: ${p.p10}–${p.p90} mg/dL`)}</title></rect>`;
  return o + '</svg>';
}
export const agpLegend = () => `<div class="legend"><span><i class="lg s-glu"></i>${tt('chart.median')}</span><span><i class="lg agpi"></i>${tt('chart.iqr')}</span><span><i class="lg agpo"></i>${tt('chart.p1090')}</span></div>`;

// ===== Meal carbs vs glucose rise (scatter) =====
export function mealScatter(points, label) {
  const L = 50, R = 704, T = 14, B = 194, H = 222;
  const xm = niceMax(Math.max(60, ...points.map(p => p.carbs)), 20), ymin = Math.min(0, ...points.map(p => p.rise)), ymax = niceMax(Math.max(60, ...points.map(p => p.rise)), 40);
  const X = v => r1(L + v / xm * (R - L)), Y = v => r1(B - (v - ymin) / (ymax - ymin) * (B - T));
  let o = `<svg class="chart scat" viewBox="0 0 720 ${H}" role="img" aria-label="${h(label)}">`;
  for (const v of [ymin, 0, 40, 80, ymax].filter((v, i, a) => a.indexOf(v) === i && v >= ymin && v <= ymax))
    o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid${v === 0 ? '' : ' faint'}"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v > 0 ? '+' + v : v}</text>`;
  for (let v = 0; v <= xm; v += xm / 4) o += `<text x="${X(v)}" y="${B + 16}" text-anchor="middle" class="ax">${v}</text>`;
  o += `<text x="${R}" y="${H - 2}" text-anchor="end" class="ax">${tt('chart.carbs_axis')}</text><text x="${L}" y="${T - 2}" class="ax">${tt('chart.rise_axis')}</text>`;
  for (const p of points) o += `<g><circle cx="${X(p.carbs)}" cy="${Y(p.rise)}" r="4.5" class="s-carbs-dot"/><circle cx="${X(p.carbs)}" cy="${Y(p.rise)}" r="11" class="hit"/><title>${h(`${p.m.name} · ${ldate('M d, h:i A', p.m.at)} · ${p.carbs} g · ${p.m.before} → ${p.m.after} mg/dL (${p.rise >= 0 ? '+' : ''}${p.rise})`)}</title></g>`;
  if (!points.length) o += `<text x="377" y="100" text-anchor="middle" class="ax">${tt('meals.none')}</text>`;
  return o + '</svg>';
}

// ===== Horizontal bars (HTML): [{label, value, sub, cls}] =====
// fit: label and value columns size to their content (never clipped), the bar takes the rest; on narrow screens the
// bar moves under the label. item.empty: text shown instead of "—" when there is no value
export function hbars(items, { max = null, unit = '', signed = false, cls = 's-carbs', fit = false } = {}) {
  const m = max ?? Math.max(1, ...items.map(i => Math.abs(i.value ?? 0)));
  return `<div class="hbars${fit ? ' fit' : ''}">${items.map(i => `<div><span class="hl">${h(i.label)}${i.sub ? `<small>${h(i.sub)}</small>` : ''}</span>
    <span class="track"><i class="${i.cls ?? cls}" style="width:${i.value === null ? 0 : Math.max(1, Math.abs(i.value) / m * 100)}%"></i></span>
    <b${i.value === null && i.empty ? ' class="nv"' : ''}>${i.value === null ? h(i.empty ?? '—') : ltr((signed && i.value > 0 ? '+' : '') + i.value + unit)}</b></div>`).join('')}</div>`;
}

// ===== Data table behind a chart (accessible values, also for print) =====
export function dataTable(head, rows, summary = t('chart.table')) {
  return `<details class="dtable"><summary>${h(summary)}</summary><div class="tscroll"><table><thead><tr>${head.map(x => `<th>${h(x)}</th>`).join('')}</tr></thead>
    <tbody>${rows.map(r => `<tr>${r.map(c => `<td>${c === null || c === undefined ? '—' : h(c)}</td>`).join('')}</tr>`).join('')}</tbody></table></div></details>`;
}
export const bucketTable = bs => dataTable([t('chart.col.period'), t('chart.p.glu'), t('chart.col.range'), t('card.tir'), t('chart.col.tbr'), t('chart.p.carbs'), t('chart.p.kcal'), t('chart.p.adh')],
  bs.map(b => [bucketLabel(b), b.avg, b.min === null ? null : `${b.min}–${b.max}`, b.tir === null ? null : b.tir + '%', b.tbr === null ? null : b.tbr + '%', b.carbs, b.kcal, b.adh === null ? null : `${b.adh}% (${b.taken}/${b.sched})`]));

// ===== Tall segmented bar for part-to-whole (patient status distribution) =====
export function segBar(parts, total) {
  return `<div class="segbar" role="img" aria-label="${h(parts.map(p => `${p.label}: ${p.n}`).join(', '))}">${parts.filter(p => p.n).map(p =>
    `<i class="${p.cls}" style="flex:${p.n}" title="${h(`${p.label}: ${p.n}`)}"><span>${p.n}</span></i>`).join('') || `<i class="nodata" style="flex:1"></i>`}</div>
    <div class="legend">${parts.map(p => `<span><i class="lg ${p.cls}"></i>${h(p.label)} · <b>${p.n}</b>${total ? ` (${Math.round(p.n / total * 100)}%)` : ''}</span>`).join('')}</div>`;
}

// ===== Statistics: average glucose trend of the population (line) =====
// pts: core/analytics populationTrend. Days without data break the line (nothing is interpolated).
// Narrower viewBox so the text stays readable when two charts sit side by side. Hover/focus: data-tip
const W2 = 480;
export function avgTrendChart(pts, tg, label) {
  const L = 44, R = W2 - 12, T = 16, B = 196, H = 224, from = pts[0].from, to = pts.at(-1).to;
  const vs = pts.filter(p => p.avg !== null).map(p => p.avg);
  const V0 = Math.max(0, Math.floor((Math.min(tg.low, ...vs) - 15) / 20) * 20), V1 = Math.ceil((Math.max(tg.high, ...vs) + 15) / 20) * 20;
  const X = ts => r1(L + (ts - from) / (to - from) * (R - L)), Y = v => r1(B - (v - V0) / (V1 - V0) * (B - T));
  const step = V1 - V0 > 160 ? 40 : 20;
  let o = `<svg class="chart w2 trend" viewBox="0 0 ${W2} ${H}" role="img" aria-label="${h(label)}">
    <rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>`;
  for (let v = V0; v <= V1; v += step) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid faint"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v}</text>`;
  o += `<text x="${L - 6}" y="${T - 4}" text-anchor="end" class="ax">mg/dL</text><line x1="${L}" x2="${R}" y1="${B}" y2="${B}" class="grid"/>`;
  for (const [ts, lb] of timeTicks(from, to)) o += `<text x="${X(ts)}" y="${H - 4}" text-anchor="middle" class="ax">${h(lb)}</text>`;
  if (!vs.length) return o + `<text x="${(L + R) / 2}" y="${(T + B) / 2}" text-anchor="middle" class="ax">${tt('st2.trend_none')}</text></svg>`;
  const segs = []; let cur = [];
  for (const p of pts) { if (p.avg === null) { if (cur.length) segs.push(cur); cur = []; continue; } cur.push(`${X((p.from + p.to) / 2)},${Y(p.avg)}`); }
  if (cur.length) segs.push(cur);
  o += segs.filter(s => s.length > 1).map(s => `<polyline points="${s.join(' ')}" class="s-glu-line"/>`).join('');
  const bw = (R - L) / pts.length;
  for (const p of pts) if (p.avg === null) o += `<rect x="${X(p.from)}" y="${T}" width="${r1(X(p.to) - X(p.from))}" height="${B - T}" class="nodata"><title>${h(bucketLabel(p) + ' · ' + t('chart.no_data_day'))}</title></rect>`;
  for (const p of pts) { if (p.avg === null) continue; const x = X((p.from + p.to) / 2);
    const tip = [bucketLabel(p), t('st2.tip_avg', { v: p.avg }), t('st2.tip_n', { n: p.n })].join('\n');
    o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${r1(x - bw / 2)}" y="${T}" width="${r1(bw)}" height="${B - T}" class="hit"/><circle cx="${x}" cy="${Y(p.avg)}" r="${pts.length > 20 ? 3 : 4}" class="s-glu-dot"/></g>`; }
  return o + '</svg>';
}
export const avgTrendLegend = tg => `<div class="legend"><span><i class="lg s-glu"></i>${tt('st2.lg_avg')}</span><span><i class="lg bandk"></i>${tt('st2.lg_band')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')}</span></div>`;

// ===== Statistics: mean time in range per status group (three vertical bars, status colors) =====
// groups: core/analytics tirByStatus. A group without eligible patients shows "Insufficient data", not a bar.
// Categories (not time) follow the reading direction, so in Arabic Normal is on the right
export function tirStatusBars(groups, goal, label) {
  const L = 44, R = W2 - 12, T = 22, B = 172, H = 222, Y = v => r1(B - v / 100 * (B - T));
  const gs = RTL ? [...groups].reverse() : groups, cw = (R - L) / gs.length, bw = Math.min(84, cw * 0.55);
  let o = `<svg class="chart w2 tirst" viewBox="0 0 ${W2} ${H}" role="img" aria-label="${h(label)}">`;
  for (const v of [0, 25, 50, 75, 100]) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid${v ? ' faint' : ''}"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v}%</text>`;
  gs.forEach((g, i) => {
    const cx = r1(L + i * cw + cw / 2), x = r1(cx - bw / 2), name = t('st.' + g.st);
    const sub = g.total ? t('st2.eligible', { n: g.n, of: g.total }) : t('st2.no_patients');
    o += `<text x="${cx}" y="${B + 20}" text-anchor="middle" class="cat">${h(name)}</text><text x="${cx}" y="${B + 37}" text-anchor="middle" class="ax">${h(sub)}</text>`;
    if (g.tir === null) {
      o += `<rect x="${x}" y="${T}" width="${r1(bw)}" height="${B - T}" rx="6" class="nodata"/><text x="${cx}" y="${r1((T + B) / 2 + 4)}" text-anchor="middle" class="ax">${tt(g.total ? 'st2.insufficient' : 'st2.no_patients')}</text>`;
      return;
    }
    const y = Y(g.tir), tip = [name, t('st2.tip_tir', { v: g.tir }), sub].join('\n');
    o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${x}" y="${y}" width="${r1(bw)}" height="${r1(Math.max(1, B - y))}" rx="6" class="sb-${g.st}"/>
      <rect x="${x - 6}" y="${T}" width="${r1(bw + 12)}" height="${B - T}" class="hit"/></g><text x="${cx}" y="${y - 7}" text-anchor="middle" class="val">${g.tir}%</text>`;
  });
  if (goal) o += `<line x1="${L}" x2="${R}" y1="${Y(goal)}" y2="${Y(goal)}" class="goal"/><text x="${RTL ? L + 4 : R - 4}" y="${Y(goal) - 5}" text-anchor="${RTL ? 'start' : 'end'}" class="ax lbl">${tt('chart.tir_goal', { v: goal })}</text>`;
  return o + '</svg>';
}

// Chart text keeps about its CSS size on screen. A chart drawn wider than its viewBox would scale the text up
// with it, so --ck (viewBox width / drawn width) shrinks it back. Shrink only (never above 1): on narrow screens
// the text stays as before, so labels never overflow the fixed margins. Safe to call again (each chart once)
let fitObs = null;
export function fitChartText(root = document) {
  if (typeof ResizeObserver === 'undefined') return;
  fitObs ??= new ResizeObserver(es => { for (const e of es) {
    const vb = e.target.viewBox?.baseVal?.width, w = e.contentRect.width;
    if (vb && w) e.target.style.setProperty('--ck', Math.min(1, vb / w).toFixed(3));
  } });
  root.querySelectorAll('svg.chart').forEach(svg => { if (!svg.dataset.fit) { svg.dataset.fit = '1'; fitObs.observe(svg); } });
}

// One floating tooltip for chart marks with data-tip (mouse hover and keyboard focus)
export function wireTips(root = document) {
  fitChartText(root);
  let tip = document.getElementById('ctip');
  if (!tip) { tip = document.createElement('div'); tip.id = 'ctip'; tip.className = 'ctip'; tip.setAttribute('role', 'tooltip'); tip.hidden = true; document.body.append(tip); }
  const show = (el, x, y) => { tip.textContent = el.dataset.tip; tip.hidden = false;
    const w = tip.offsetWidth, hh = tip.offsetHeight;
    tip.style.left = Math.max(8, Math.min(innerWidth - w - 8, x - w / 2)) + 'px';
    tip.style.top = (y - hh - 14 < 8 ? y + 18 : y - hh - 14) + 'px'; };
  root.querySelectorAll('[data-tip]').forEach(el => {
    if (el.dataset.tipOn) return; el.dataset.tipOn = '1';   // safe to call again on the same page
    el.addEventListener('pointerenter', e => show(el, e.clientX, e.clientY));
    el.addEventListener('pointermove', e => show(el, e.clientX, e.clientY));
    el.addEventListener('pointerleave', () => { tip.hidden = true; });
    el.addEventListener('focus', () => { const r = el.getBoundingClientRect(); show(el, r.left + r.width / 2, r.top); });
    el.addEventListener('blur', () => { tip.hidden = true; });
  });
}

// ===== Meals: average glucose change by carbohydrate group (one chart, vertical bars from zero) =====
// bands: core/analytics mealImpact().bands [{k, n, rise, carbs}]. Only meals with a reading before AND 2 h after
// count. Values can be negative, so bars start at the zero line. Categories follow the reading direction.
export function carbBandChart(bands, label) {
  const L = 52, R = W2 - 12, T = 34, B = 182, H = 232;
  const vs = bands.filter(b => b.n).map(b => b.rise);
  const hi = Math.max(40, Math.ceil((Math.max(0, ...vs) + 10) / 20) * 20), lo = Math.min(0, Math.floor((Math.min(0, ...vs) - 10) / 20) * 20);
  const Y = v => r1(B - (v - lo) / (hi - lo) * (B - T)), step = hi - lo > 120 ? 40 : 20;
  const gs = RTL ? [...bands].reverse() : bands, cw = (R - L) / gs.length, bw = Math.min(80, cw * 0.5);
  let o = `<svg class="chart w2 carbs" viewBox="0 0 ${W2} ${H}" role="img" aria-label="${h(label)}">`;
  for (let v = lo; v <= hi; v += step) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid${v === 0 ? '' : ' faint'}"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v > 0 ? '+' + v : v}</text>`;
  o += `<text x="${L - 6}" y="14" text-anchor="end" class="ax">mg/dL</text>`;
  gs.forEach((b, i) => {
    const cx = r1(L + i * cw + cw / 2), x = r1(cx - bw / 2), name = t('band.' + b.k), sub = t('nut.n_meals', { n: b.n });
    o += `<text x="${cx}" y="${B + 20}" text-anchor="middle" class="cat">${h(name)}</text><text x="${cx}" y="${B + 37}" text-anchor="middle" class="ax">${h(sub)}</text>`;
    if (!b.n) { o += `<text x="${cx}" y="${r1((T + B) / 2)}" text-anchor="middle" class="ax">${tt('ch.no_meals')}</text>`; return; }
    const y0 = Y(0), y = Y(b.rise), top = Math.min(y, y0), tip = [name, t('ch.carb_tip', { v: (b.rise > 0 ? '+' : '') + b.rise }), t('ch.carb_tip_n', { n: b.n, c: b.carbs })].join('\n');
    o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${x}" y="${top}" width="${r1(bw)}" height="${r1(Math.max(1, Math.abs(y0 - y)))}" rx="5" class="s-carbs"/>
      <rect x="${x - 6}" y="${T}" width="${r1(bw + 12)}" height="${B - T}" class="hit"/></g>
      <text x="${cx}" y="${b.rise >= 0 ? y - 7 : y + 16}" text-anchor="middle" class="val">${b.rise > 0 ? '+' : ''}${b.rise}</text>`;
  });
  return o + '</svg>';
}

// ===== Consultations: average glucose in the same number of days before and after each one =====
// items: [{ label, at, before: {avg, n, days}, after: {...} }] (core/analytics aroundConsultation). One measure
// (average glucose, mg/dL) on one scale with the target band behind it; values are shown side by side only
export function consultChart(items, tg, label) {
  const L = 52, R = W2 - 12, T = 34, B = 182, H = 232;
  const vs = items.flatMap(x => [x.before.avg, x.after.avg]).filter(v => v !== null);
  const hi = Math.ceil((Math.max(tg.high + 20, ...vs) + 20) / 50) * 50, Y = v => r1(B - v / hi * (B - T));
  const gs = RTL ? [...items].reverse() : items, cw = (R - L) / Math.max(1, gs.length), bw = Math.min(46, cw * 0.3);
  let o = `<svg class="chart w2 cons" viewBox="0 0 ${W2} ${H}" role="img" aria-label="${h(label)}">
    <rect x="${L}" y="${Y(tg.high)}" width="${R - L}" height="${r1(Y(tg.low) - Y(tg.high))}" class="band"/>`;
  for (let v = 0; v <= hi; v += 50) o += `<line x1="${L}" x2="${R}" y1="${Y(v)}" y2="${Y(v)}" class="grid${v ? ' faint' : ''}"/><text x="${L - 6}" y="${Y(v) + 4}" text-anchor="end" class="ax">${v}</text>`;
  o += `<text x="${L - 6}" y="14" text-anchor="end" class="ax">mg/dL</text>`;
  gs.forEach((c, i) => {
    const cx = r1(L + i * cw + cw / 2);
    o += `<text x="${cx}" y="${B + 20}" text-anchor="middle" class="cat">${h(c.label)}</text><text x="${cx}" y="${B + 37}" text-anchor="middle" class="ax">${h(ldate('M d, Y', c.at))}</text>`;
    const sides = RTL ? [['after', 0], ['before', 1]] : [['before', 0], ['after', 1]];
    for (const [k, j] of sides) {
      const s = c[k], x = r1(cx - bw - 3 + j * (bw + 6));
      if (s.avg === null) { o += `<text x="${r1(x + bw / 2)}" y="${B - 8}" text-anchor="middle" class="ax">—</text>`; continue; }
      const y = Y(s.avg), tip = [`${t('ch.' + k)} · ${c.label} · ${ldate('M d, Y', c.at)}`, t('st2.tip_avg', { v: s.avg }), t('ch.side_n', { d: s.days, n: s.n })].join('\n');
      o += `<g class="pt" tabindex="0" data-tip="${h(tip)}" aria-label="${h(tip.replace(/\n/g, ' · '))}"><rect x="${x}" y="${y}" width="${r1(bw)}" height="${r1(B - y)}" rx="4" class="cb-${k}"/>
        <rect x="${x - 2}" y="${T}" width="${r1(bw + 4)}" height="${B - T}" class="hit"/></g><text x="${r1(x + bw / 2)}" y="${y - 6}" text-anchor="middle" class="val sm">${s.avg}</text>`;
    }
  });
  return o + '</svg>';
}
export const consultLegend = tg => `<div class="legend"><span><i class="lg cb-before"></i>${tt('ch.before_l')}</span><span><i class="lg cb-after"></i>${tt('ch.after_l')}</span><span><i class="lg bandk"></i>${tt('st2.lg_band')} ${ltr(tg.low + '–' + tg.high + ' mg/dL')}</span></div>`;
