// Patient file: Overview, Glucose Monitoring, Nutrition, Medications, Consultations, Reports, Communication.
// Reviewing a glucose alert (?alert=<id>) happens here, after looking at the patient's data.
// Treatment can only be changed by documenting a consultation (consultation.html).
import { mount } from '../ui/layout.js';
import { t, tt, ldate } from '../core/i18n.js';
import { $, h, ic, params, qint, url } from '../core/dom.js';
import { DAY, now, today, addDays } from '../core/time.js';
import { targets, glucoseStats, cgmCoverage, dailyMinMax } from '../core/clinical.js';
import { getPatients, getReminders, getNotifications, getChat, isAcked, ackNotification, addInstruction } from '../data/api.js';
import { go } from '../ui/nav.js';
import { takeFlash, local } from '../core/storage.js';
import { readingLabel, statusBlock, patientMeta, alertTitle, reportTitle, avatar, card, remRow, statusHistoryHtml,
  notifText, notifLink, NICON, lower, empty, UNIT, auto } from '../ui/components.js';
import { wireTips, dailyTrendChart, dailyTrendLegend } from '../ui/charts.js';
import { monitoringView, nutritionView } from '../ui/patient-dashboards.js';
import { activeMedsTable, consultationCard, wireTabLinks, alertBasis, treatmentSummary, protocolSummary } from '../ui/clinical-ui.js';

const all = await getPatients(), id = qint('id'), p = all[id];
if (!p) {
  await mount({ page: 'patients', title: t('common.not_found'), heading: t('common.not_found'), sub: '' }, empty('common.not_found'));
} else {
  const tg = targets(p), t0 = now(), q = params();
  const aid = q.get('alert'), alert = aid ? p.alerts.find(a => a.id === aid) : null;
  const back = url('notifications.html', { p: qint('p') });
  const done = alert ? isAcked(id, alert.id) : null;
  const rm = (await getReminders()).filter(r => r.pid === id);
  const chat = await getChat(id), notifs = (await getNotifications()).filter(n => n.pid === id);
  const TABS = { 't-ov': 'tab.ov', 't-glu': 'tab.glu', 't-nut': 'tab.nut', 't-med': 'tab.med', 't-con': 'tab.con', 't-rp': 'tab.rp', 't-com': 'tab.com' };
  const s14 = glucoseStats(p.readings.filter(r => r.at > t0 - 14 * DAY), tg);
  const cov14 = cgmCoverage(p.readings.filter(r => r.at > t0 - 14 * DAY)), last = p.readings[0];
  // Overview trend: daily average of the actual readings of each of the last 14 calendar days (today included)
  // plus the lowest / highest reading of each day (same days, core/clinical dailyMinMax)
  const mm14 = dailyMinMax(p.readings, 14);
  const trend14 = Array.from({ length: 14 }, (_, i) => { const day = addDays(today(), i - 13), end = addDays(day, 1);
    const vs = p.readings.filter(r => r.at >= day && r.at < end).map(r => r.v);
    return { day, n: vs.length, avg: vs.length ? Math.round(vs.reduce((a, v) => a + v, 0) / vs.length) : null,
      min: mm14[i][1]?.min ?? null, max: mm14[i][1]?.max ?? null }; });
  const openN = notifs.filter(n => !n.ack).sort((a, b) => b.at - a.at);

  // The complete Glucose Monitoring and Nutrition dashboards (ui/patient-dashboards.js, also used by the standalone
  // routes), always for THIS patient (the id in the URL). Each tab keeps its own filters in the URL under its own
  // names, so changing one never resets the other, and every link keeps ?id= and returns to the same tab:
  //   Monitoring: mr / mf / mt (period), src (sensor / manual)     Nutrition: nr / nf / nt (period)
  const NS = { glu: { r: 'mr', from: 'mf', to: 'mt', src: 'src' }, nut: { r: 'nr', from: 'nf', to: 'nt' } };
  const own = ns => new URLSearchParams(Object.entries(NS[ns]).filter(([, v]) => q.get(v) !== null).map(([k, v]) => [k, q.get(v)]));
  const tabLink = (ns, tab) => o => {
    const keep = Object.fromEntries(Object.values(NS).flatMap(n => Object.values(n)).map(v => [v, q.get(v)]));
    for (const [k, v] of Object.entries(o)) keep[NS[ns][k] ?? k] = v;
    return url('patient.html', { id, ...keep }, tab);
  };
  const glu = monitoringView(p, { q: own('glu'), link: tabLink('glu', 't-glu'),
    alerts: { href: a => url('patient.html', { id, alert: a.id }, 't-glu'), ackedAt: a => isAcked(id, a.id) }, presets: false });
  const nut = nutritionView([p], { q: own('nut'), link: tabLink('nut', 't-nut'), details: false, presets: false });
  const flash = takeFlash();
  // An unsaved consultation draft for this patient in this browser (consultation.js), shown above the saved records
  const draft = local.get(`dms-cdraft-${id}`, null)?.v ? local.get(`dms-cdraft-${id}`, null) : null;
  const tone = st => ({ ok: 'c-ok', ctrl: 'c-ctrl', crit: 'c-high', low: 'c-high' }[st] || 'c-info');

  await mount({ page: 'patients', title: p.name, heading: p.name, sub: t('file.sub', { meta: patientMeta(p) }) }, `
  <div class="card c-info head">
    ${avatar(p.name, 'avatar big')}
    <div><b class="nm" dir="auto">${h(p.name)}</b><small>${h(patientMeta(p))}</small>
      ${p.cg || p.linkedAt ? `<small>${[p.cg ? tt('file.caregiver', { v: p.cg }) : '', p.linkedAt ? tt('file.linked', { d: ldate('M d, Y', p.linkedAt) }) : ''].filter(Boolean).join(' · ')}</small>` : ''}</div>
    ${statusBlock(p)}
    <div class="hact"><a class="btn ghost" href="chat.html?p=${id}">${ic('chat')} ${tt('pf.message')}</a>
      <a class="btn ghost" href="statistics.html?p=${id}">${ic('trend')} ${tt('pf.view_stats')}</a></div>
  </div>
  ${flash ? `<p class="okmsg">${tt(flash)}</p>` : ''}
  ${p.awaiting ? `<div class="await-banner">${ic('calendar')}<div><b>${tt('cons.awaiting')}</b><p>${tt('cons.awaiting_short')}</p></div>
    <a class="btn sm" href="consultation.html?id=${id}">${ic('steth')} ${tt('cons.new_initial')}</a></div>` : ''}
  ${alert ? `<div class="row review ${alert.st}">
    <div class="who"><div class="ico">${ic('alert')}</div><div><b>${tt('file.reviewing', { t: alertTitle(alert) })}</b><small>${h(ldate('M d, Y · h:i A', alert.at))}</small></div></div>
    <div class="act"><a class="lnk" href="${h(back)}">${tt('file.back_alerts')}</a>
      ${done ? `<small>${tt('file.reviewed', { d: ldate('M d · h:i A', done) })}</small>` : `<button class="btn sm" id="ack">${tt('file.mark')}</button>`}</div>
    ${alertBasis(p, alert, true)}
  </div>` : ''}
  <div class="tabs" role="tablist">
    ${Object.entries(TABS).map(([k, v]) => `<button data-tab="${k}" class="${k === 't-ov' ? 'on' : ''}">${tt(v)}</button>`).join('')}
  </div>

  <section class="tab" id="t-ov">
    <div class="stats three">
      ${card(last ? tone(last.st) : 'c-info', 'drop', t('home.last'), last ? h(last.v) + UNIT() : '—', last ? `${h(readingLabel(last.st))} · ${h(ldate('M d · h:i A', last.at))}` : tt('empty.readings'))}
      ${card('c-avg', 'activity', t('card.avg'), s14.avg === null ? '—' : s14.avg + UNIT(), s14.total ? tt('ov.avg_sub', { n: s14.total }) : tt('home.14d'))}
      ${card('c-avg', 'clock', t('card.tir'), cov14.ok && s14.tir !== null ? s14.tir + '%' : `<span class="na">${tt('home.no_cgm')}</span>`, tt('home.tir_sub', { d: cov14.days, n: cov14.of, g: tg.tir }))}
    </div>

    <section class="ovsec"><h2 class="sub">${tt('ov.trend')}</h2>
      ${dailyTrendChart(trend14, tg, t('ov.trend'))}${dailyTrendLegend(tg)}</section>

    <div class="dgrid even ovgrid">
      <section class="ovbox"><div class="bar sub"><h2>${tt('ov.tx_fu')}</h2><a class="lnk" href="#t-med" data-goto="t-med">${tt('ov.to_meds')}</a></div>${treatmentSummary(p, t0)}</section>
      <section class="ovbox"><h2 class="sub">${tt('pf.targets')}</h2>${protocolSummary(p, id)}</section>
    </div>

    <h2 class="sub">${tt('hist.title')}</h2>
    ${statusHistoryHtml(p)}

    <div class="bar sub"><h2>${tt('pf.open_notif')} <small class="hint">(${openN.length})</small></h2>
      <a class="lnk" href="${h(url('notifications.html', { p: id }))}">${tt('ov.all_notif')}</a></div>
    <div class="list">${openN.slice(0, 5).map(n => { const x = notifText(n);
      return `<a class="row compact ${n.sev === 'crit' ? 'crit' : n.sev === 'warn' ? 'ctrl' : 'info'}" href="${h(notifLink(n))}"><div class="who"><div class="ico">${ic(NICON[n.kind])}</div><div><b>${h(x.title)}</b><small>${h(ldate('M d · h:i A', n.at))}${x.sub ? ' · ' + auto(x.sub) : ''}</small></div></div><span>${tt('common.chev')}</span></a>`; }).join('') || `<p class="txt">${tt('n.none_open')}</p>`}</div>
  </section>

  <section class="tab" id="t-glu" hidden>
    ${glu.html}
  </section>

  <section class="tab" id="t-nut" hidden>
    ${nut.html}
  </section>

  <!-- Medications: the active prescriptions only. Treatment still changes only through a documented consultation
       (consultation.html); the Patient App payload (syncPayload) is built for the backend but not shown here -->
  <section class="tab" id="t-med" hidden>
    <div class="bar"><h2>${tt('med.active')}</h2><a class="btn" href="consultation.html?id=${id}">${ic('steth')} ${p.awaiting ? tt('cons.new_initial') : tt('med.change_btn')}</a></div>
    ${activeMedsTable(p)}
  </section>

  <section class="tab" id="t-con" hidden>
    <div class="bar"><h2>${tt('cons.history', { n: p.consultations.length })}</h2><a class="btn" href="consultation.html?id=${id}">${ic('steth')} ${p.awaiting ? tt('cons.new_initial') : tt('cons.new')}</a></div>
    ${p.awaiting ? `<p class="txt">${tt('cons.none_yet')}</p>` : ''}
    <!-- newest first, all collapsed; laboratory results over time are on the patient's Statistics view -->
    <div class="clist">${draft ? `<a class="ccard cdraft" href="consultation.html?id=${id}"><span class="ck">${ic('note')}</span>
        <span class="cs-t"><b>${tt('cs.draft_title')}</b> <span class="pill rs-draft">${tt('cs.st.draft')}</span><small>${tt('cs.draft_note', { t: ldate('M d, Y · h:i A', draft.at) })}</small></span>
        <span class="lnk">${tt('cs.draft_open')} ${tt('common.chev')}</span></a>` : ''}${p.consultations.map((c, i) => [c, i]).sort((a, b) => (b[0].at - a[0].at) || (b[1] - a[1])).map(([c]) => consultationCard(c, p)).join('')}</div>
  </section>

  <section class="tab list" id="t-rp" hidden>
    ${p.reports.map(r => `<a class="row pl ok" href="reports.html?p=${id}&amp;r=${r.id}" data-s="${h(lower(reportTitle(r)))}"><div class="who"><div class="ico">${ic('report')}</div><div><b>${h(reportTitle(r))}</b><small>${h(ldate('M d, Y', r.at))}</small></div></div><span></span><span></span><span>${tt('common.chev')}</span></a>`).join('') || empty('file.no_reports')}
  </section>

  <!-- Communication: five separate panels in a responsive grid (two columns on wide screens, one on small) -->
  <section class="tab" id="t-com" hidden>
    <div class="comgrid">
      <section class="cpanel" aria-labelledby="com-msg"><div class="bar"><h2 id="com-msg">${tt('com.messages')}</h2><a class="lnk" href="chat.html?p=${id}">${tt('com.open_chat')}</a></div>
        <div class="msgs preview">${chat.slice(-4).map(m => `<div class="b ${m[0]}"><p dir="auto">${h(m[1])}</p><small>${h(ldate('M d · h:i A', m[2]))}</small></div>`).join('') || empty('chat.start', { name: p.name })}</div></section>
      <section class="cpanel" aria-labelledby="com-req"><h2 id="com-req">${tt('com.requests')}</h2>
        <div class="reqs">${p.requests.map(r => { const n = notifs.find(x => x.id === r.id), st = n?.ack ? 'done' : r.urgent ? 'urgent' : 'open';
          return `<article class="reqcard rq-${st}"><div class="rq-h">${ic('calendar')}<b>${tt('n.request.' + r.kind)}</b><span class="pill ${st === 'done' ? 'b-ok' : st === 'urgent' ? 'b-ctrl' : 'b-new'}">${n?.ack ? tt('com.req_done') : tt('com.req_open')}</span></div>
            <small class="rq-at">${h(ldate('M d, Y · h:i A', r.at))}</small>${r.note ? `<p class="rq-note">${auto(r.note)}</p>` : ''}
            ${n?.ack ? '' : `<a class="btn sm" href="consultation.html?id=${id}">${tt('com.req_doc')}</a>`}</article>`; }).join('') || `<p class="txt">${tt('com.no_requests')}</p>`}</div></section>
      <section class="cpanel" aria-labelledby="com-send"><h2 id="com-send">${tt('com.send_ins')}</h2>
        <form class="ins" id="insForm">
          <label for="text">${tt('ins.label', { name: p.name })}</label>
          <textarea id="text" name="text" rows="4" dir="auto" required placeholder="${tt('ins.ph')}"></textarea>
          <button type="submit" class="btn">${tt('ins.send')}</button>
        </form></section>
      <section class="cpanel" aria-labelledby="com-sent"><h2 id="com-sent">${tt('ins.sent')}</h2>
        ${p.ins.length ? `<ul class="inslist">${p.ins.map(i => `<li>${ic('steth')}<div><p dir="auto">${h(i[0])}</p><small>${h(ldate('M d, Y · h:i A', i[1]))}</small></div></li>`).join('')}</ul>` : empty('ins.none')}</section>
    </div>
    <section class="cpanel" aria-labelledby="com-rm"><div class="bar"><h2 id="com-rm">${tt('tab.rm')}</h2><a class="btn ghost sm" href="reminders.html?p=${id}#new">${tt('file.set_rem')}</a></div>
      <div class="list">${rm.map(r => remRow(r)).join('') || empty('file.no_rem')}</div></section>
  </section>`);

  const ack = $('#ack');
  if (ack) ack.onclick = async () => { await ackNotification(id, alert.id); go(back); };
  $('#insForm').onsubmit = async e => {
    e.preventDefault();
    const text = $('#text').value.trim();
    if (!text) return;
    await addInstruction(id, text);
    go(url('patient.html', { id }, 't-com'));
  };
  // each dashboard wires only its own controls (date form, meal log), once at load; switching tabs only shows / hides
  glu.wire($('#t-glu')); nut.wire($('#t-nut'));
  wireTabLinks(); wireTips();
}
