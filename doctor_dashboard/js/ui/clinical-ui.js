// Clinical pieces shared by the patient file, Nutrition, Reports and the consultation form.
import { t, tt, tv, ldate, DF, ltr, iso, RTL } from '../core/i18n.js';
import { h, ic } from '../core/dom.js';
import { adherence, syncPayload } from '../core/medications.js';
import { PROTOCOLS } from '../core/protocols.js';
import { LABS, bmi } from '../core/record.js';
import { medDose, medSchedule, medLine, consKind, readingLabel } from './components.js';
import { targets, stRange } from '../core/clinical.js';

const dt = ts => ldate(DF.DATE_TIME, ts);
const para = s => (s ? `<p dir="auto">${h(s).replace(/\n/g, '<br>')}</p>` : `<p class="hint">—</p>`);

// ===== Time in the five ranges (bar + legend with goals) =====
export function tirSummary(bd, tg) {
  if (!bd) return `<p class="txt">${tt('glu.no_cgm')}</p>`;
  const B5 = { vhigh: ['> ' + tg.vhigh, 'lt', tg.tar2], high: [(tg.high + 1) + '–' + tg.vhigh, 'lt', tg.tar], in: [tg.low + '–' + tg.high, 'gt', tg.tir],
    low: [tg.vlow + '–' + (tg.low - 1), 'lt', tg.tbr], vlow: ['< ' + tg.vlow, 'lt', tg.tbr2] };
  return `<div class="tir"><div class="tirbar" role="img" aria-label="${tt('glu.tir_title')}">${Object.keys(B5).reverse().filter(k => bd.pct[k] > 0).map(k => `<i class="t-${k}" style="width:${Math.round(bd.pct[k] * 10) / 10}%" title="${h(t('glu.t.' + k) + ' ' + Math.round(bd.pct[k]) + '%')}"></i>`).join('')}</div>
    <div class="tirleg">${Object.entries(B5).map(([k, [rng, op, goal]]) => `<div><i class="sw t-${k}"></i><span>${tt('glu.t.' + k)} <small>${ltr(rng + ' mg/dL')}</small></span><b class="${bd.met[k] ? 'met' : 'miss'}">${Math.round(bd.pct[k])}%</b><small>${tt('glu.goal_' + op, { v: goal })} ${bd.met[k] ? '✓' : '✗'}</small></div>`).join('')}</div></div>`;
}

// ===== Protocol and targets =====
export function protocolBox(p) {
  const pr = PROTOCOLS[p.protocolId], tg = p.targets, c = [...p.consultations].reverse().find(x => x.targets || x.protocol);
  return `<div class="kv">
    <div><span>${tt('pf.type')}</span><b>${p.type ? h(tv('ptype.', p.type)) : `${tt('pf.type_unconfirmed')}${p.reportedType ? ' · ' + h(t('pat.reported_type', { v: tv('ptype.', p.reportedType) })) : ''}`}</b></div>
    <div><span>${tt('pf.protocol')}</span><b>${tt('prot.' + pr.id)} <small>v${h(pr.version)}</small></b>${pr.reviewed ? '' : `<span class="pill b-draft">${tt('prot.unreviewed')}</span>`}</div>
    <div><span>${tt('glu.target')}</span><b>${ltr(tg.low + '–' + tg.high + ' mg/dL')}</b></div>
    <div><span>${tt('pf.goals')}</span><b>${ltr(`TIR > ${tg.tir}% · TBR < ${tg.tbr}% · TAR < ${tg.tar}%`)}</b></div>
    <div><span>${tt('pf.targets_src')}</span><b>${p.indivTargets ? tt('pf.indiv', { d: ldate(DF.DATE, c.at) }) : p.awaiting ? tt('pf.default_await') : tt('pf.default')}</b></div>
  </div>`;
}

// Overview summary: type (confirmed or self-reported), target range and protocol with its review state; goals and
// the source of the targets in a collapsible "View protocol details" (same data as protocolBox)
export function protocolSummary(p, id) {
  const pr = PROTOCOLS[p.protocolId], tg = p.targets, c = [...p.consultations].reverse().find(x => x.targets || x.protocol);
  const dxC = p.consultations.find(x => x.dx?.type);   // the consultation that first documented the type
  const type = p.type ? `${h(tv('ptype.', p.type))} <span class="pill b-ok">${tt('pf.type_confirmed')}</span><small>${tt('pf.confirmed_at', { d: ldate(DF.DATE, dxC.at) })}</small>`
    : p.reportedType ? `${h(tv('ptype.', p.reportedType))} <span class="pill b-none">${tt('pf.type_self')}</span>` : tt('pf.type_unconfirmed');
  return `<div class="kv psum">
    <div><span>${tt('pf.type')}</span><b>${type}</b></div>
    <div><span>${tt('glu.target')}</span><b>${ltr(tg.low + '–' + tg.high + ' mg/dL')}</b></div>
    <div><span>${tt('pf.protocol')}</span><b>${tt('prot.' + pr.id)}</b>${pr.reviewed ? `<span class="pill b-ok">${tt('prot.reviewed')}</span>` : `<span class="pill b-draft">${tt('prot.unreviewed')}</span>`}</div>
  </div>
  <details class="pdet"><summary>${tt('pf.proto_details')}</summary><div class="kv">
    <div><span>${tt('pf.goals')}</span><b>${ltr(`TIR > ${tg.tir}% · TBR < ${tg.tbr}% · TAR < ${tg.tar}%`)}</b></div>
    <div><span>${tt('pf.targets_src')}</span><b>${p.indivTargets ? tt('pf.indiv', { d: ldate(DF.DATE, c.at) }) : p.awaiting ? tt('pf.default_await') : tt('pf.default')}</b></div>
    <div><span>${tt('pf.version')}</span><b>v${h(pr.version)}</b></div>
  </div><a class="lnk" href="consultation.html?id=${id}#targets">${tt('pf.edit_targets')}</a></details>`;
}
// Overview summary: current prescriptions (one line each) and the next follow-up, from the existing records only
export function treatmentSummary(p, t0) {
  const meds = p.regimen.active;
  const tx = meds.length ? `<ul class="txl">${meds.map(v => `<li><b dir="auto">${h(v.drug)}</b> <span>${h(medDose(v))}</span><small>${h(medSchedule(v))}</small></li>`).join('')}</ul>`
    : `<p class="txt">${tt('pf.no_tx')}</p>`;
  const fu = p.followUp ? `<b class="${p.followUp.at < t0 ? 'late' : ''}">${h(ldate(DF.FOLLOW_UP, p.followUp.at))}</b>${p.followUp.at < t0 ? ` <span class="pill b-ctrl">${tt('pf.overdue')}</span>` : ''}${p.followUp.notes ? `<small dir="auto">${h(p.followUp.notes)}</small>` : ''}`
    : p.awaiting ? `<span class="pill b-await">${tt('cons.awaiting')}</span>` : `<span>${tt('pf.no_fu')}</span>`;
  return `<div class="kv tsum"><div><span>${tt('pf.current_tx')}</span><div>${tx}</div></div><div><span>${tt('pf.next_fu')}</span><div class="fu">${fu}</div></div></div>`;
}

// ===== Medications =====
export function activeMedsTable(p, compact = false) {
  const t0 = Date.now() / 1000;
  if (!p.regimen.active.length) return `<p class="txt">${p.awaiting ? tt('med.none_await') : tt('med.none')}</p>`;
  return `<div class="tscroll"><table class="tbl"><thead><tr><th>${tt('med.col.drug')}</th><th>${tt('med.col.dose')}</th><th>${tt('med.col.schedule')}</th>${compact ? '' : `<th>${tt('med.col.start')}</th><th>${tt('med.col.duration')}</th><th>${tt('med.col.adh')}</th><th>${tt('med.col.sync')}</th>`}</tr></thead><tbody>
    ${p.regimen.active.map(v => { const a7 = adherence(p.doses, t0 - 7 * 86400, t0, v.rx), a14 = adherence(p.doses, t0 - 14 * 86400, t0, v.rx);
      return `<tr><td><b dir="auto">${h(v.drug)}</b><small>${h(t('route.' + v.route))}</small></td><td>${h(medDose(v))}</td><td>${h(medSchedule(v))}</td>${compact ? '' : `
        <td>${h(ldate(DF.DATE, v.start))}<small><a href="#c-${h(v.cid)}" data-goto="t-con">${tt('med.from_cons')}</a></small></td>
        <td>${v.end ? h(t('med.until', { d: ldate(DF.DATE, v.end) })) : tt('med.ongoing')}</td>
        <td>${a7.pct === null ? '—' : `<b>${a7.pct}%</b> <small>${tt('med.adh_7', { a: a7.taken, b: a7.scheduled })}</small><small>${tt('med.adh_14', { v: a14.pct ?? '—' })}</small>`}</td>
        <td><span class="pill b-sync">${tt('sync.pending')}</span></td>`}</tr>`; }).join('')}
  </tbody></table></div>`;
}
// Every prescription version, newest first, with what it replaced and why
export function medHistory(p) {
  const vs = [...p.regimen.versions].sort((a, b) => b.start - a.start || b.id.localeCompare(a.id));
  if (!vs.length) return `<p class="txt">${tt('med.no_history')}</p>`;
  const prevOf = v => p.regimen.versions.find(x => x.id === v.prev);
  const items = [];
  for (const v of vs) {
    if (v.stopCid) items.push({ at: v.end, html: `<li class="mh stop"><b>${tt('medact.stop')}: ${h(iso(v.drug))} ${h(medDose(v))}</b><small>${h(dt(v.end))} · <a href="#c-${h(v.stopCid)}" data-goto="t-con">${tt('med.from_cons')}</a></small>${v.stopReason ? `<p>${tt('med.reason')}: <span dir="auto">${h(v.stopReason)}</span></p>` : ''}</li>` });
    const pv = prevOf(v);
    items.push({ at: v.start, html: `<li class="mh ${v.act}"><b>${tt('medact.' + v.act)}: ${h(medLine(v))}</b> <span class="pill b-rx-${v.status}">${tt('rxst.' + v.status)}</span>
      <small>${h(dt(v.start))}${v.end ? ' → ' + h(ldate(DF.DATE, v.end)) : ''} · <a href="#c-${h(v.cid)}" data-goto="t-con">${tt('med.from_cons')}</a></small>
      ${pv ? `<p>${tt('med.prev')}: ${h(medDose(pv))} · ${h(medSchedule(pv))}</p>` : ''}${v.reason ? `<p>${tt('med.reason')}: <span dir="auto">${h(v.reason)}</span></p>` : ''}</li>` });
  }
  return `<ol class="mhist">${items.sort((a, b) => b.at - a.at).map(x => x.html).join('')}</ol>`;
}
export function syncPreview(p) {
  if (!p.regimen.active.length) return '';
  return `<details class="dtable"><summary>${tt('sync.preview')}</summary><p class="hint">${tt('sync.preview_note')}</p>
    <pre class="code" dir="ltr">${h(JSON.stringify(p.regimen.active.map(v => syncPayload(p.id, v)), null, 2))}</pre></details>`;
}

// ===== One documented consultation: a compact expandable card (collapsed by default) =====
// Summary: type (Initial / Follow-up), date and time, medication changes, follow-up. Expanded, the record in clinical
// order: reason for visit → examination and vital signs → diagnosis and conditions → laboratory results →
// medication changes with their reasons → treatment plan (with protocol and targets) → follow-up → clinical notes.
// Read-only: records are never edited here (a correction is a new consultation).
export function consultationCard(c, p, open = false) {
  const e = c.exam ?? {}, b = bmi(e.weight, e.height), meds = c.meds ?? [];
  const changed = meds.filter(m => m.act !== 'continue'), kept = meds.filter(m => m.act === 'continue');
  const V = p.regimen.versions;
  const vOf = m => V.find(x => x.id === `${m.rx}@${c.id}`) ?? V.find(x => x.rx === m.rx) ?? m;
  // Version in effect just before this consultation (for "previous" doses); null when not documented
  const before = m => V.filter(x => x.rx === m.rx && x.start < c.at).sort((a, b) => b.start - a.start)[0] ?? null;
  const ND = `<em class="nd">${tt('cs.not_doc')}</em>`;
  const sched = v => (v ? [v.route ? t('route.' + v.route) : null, medSchedule(v)].filter(Boolean).join(' · ') : null);
  // One medication decision: action, name, previous → new dose (only what is documented), route and schedule, reason
  const medRow = m => {
    const v = vOf(m), now0 = V.find(x => x.id === `${m.rx}@${c.id}`), prev = m.act === 'change' ? (V.find(x => x.id === now0?.prev) ?? null) : before(m);
    const drug = iso(v.drug ?? m.drug ?? prev?.drug ?? m.rx);
    const dose = m.act === 'start' ? `<span class="dnew">${h(medDose(v))}</span>`
      : m.act === 'change' ? `<span class="dprev">${prev ? h(medDose(prev)) : ND}</span> <span class="arr" aria-hidden="true">${RTL ? '←' : '→'}</span> <span class="dnew">${now0 ? h(medDose(now0)) : ND}</span>`
      : m.act === 'stop' ? `<span class="dprev">${prev ? h(medDose(prev)) : ND}</span> <span class="arr" aria-hidden="true">${RTL ? '←' : '→'}</span> <span class="dstop">${tt('medact.stop')}</span>`
      : (prev ? `${h(medDose(prev))} <small>(${tt('cs.unchanged')})</small>` : ND);
    const doseLbl = m.act === 'change' || m.act === 'stop' ? 'cs.dose_change' : 'med.col.dose';
    const sc = sched(m.act === 'change' ? now0 : m.act === 'stop' || m.act === 'continue' ? prev : v);
    const why = m.reason ? `<span dir="auto">${h(m.reason)}</span>` : m.act === 'continue' ? '' : ND;
    return `<li class="mrx a-${m.act}"><div class="mrx-h"><span class="act">${tt('medact.' + m.act)}</span><b class="drug">${h(drug)}</b></div>
      <dl class="mrx-d"><div><dt>${tt(doseLbl)}</dt><dd>${dose}</dd></div><div><dt>${tt('cs.route_sched')}</dt><dd>${sc ? h(sc) : ND}</dd></div>
        ${why ? `<div class="w"><dt>${tt('cs.reason_l')}</dt><dd>${why}</dd></div>` : ''}</dl></li>`;
  };
  // Saved records are final (they are not edited afterwards); a record sent as a draft by the backend says so
  const st = c.status === 'draft' ? 'draft' : 'final';
  const FU_ST = ['scheduled', 'completed', 'cancelled'];
  const vital = (k, v) => `<div><span>${tt(k)}</span><b>${v ?? '—'}</b></div>`;
  const sec = (key, body) => `<section class="cs"><h4>${tt(key)}</h4><div>${body}</div></section>`;
  const none = `<p class="hint">—</p>`;
  return `<details class="ccard k-${c.kind === 'initial' ? 'initial' : 'follow_up'}" id="c-${h(c.id)}"${open ? ' open' : ''}>
    <summary><span class="ck">${ic('steth')}</span>
      <span class="cs-t"><b>${h(consKind(c.kind))}</b> <span class="pill rs-${st}">${tt('cs.st.' + st)}</span>${c.urgent ? ` <span class="pill b-ctrl">${tt('cs.urgent')}</span>` : ''}<small>${h(dt(c.at))} · ${tt('cons.mode.' + c.mode)}</small></span>
      <span class="cs-m">${changed.length ? `<span class="chg">${ic('pill')} ${(changed.length === 1 ? tt('cons.n_changes_one') : tt('cons.n_changes', { n: changed.length }))}</span>` : `<small>${tt('cons.no_changes')}</small>`}
        ${c.followUp?.at ? `<small>${tt('cs.fu_on', { d: ldate(DF.DATE, c.followUp.at) })}</small>` : ''}</span></summary>
    <div class="cdoc">
      <p class="cmeta"><span>${tt('cs.status')}: <b>${tt('cs.st.' + st)}</b></span><span>${c.by ? tt('cs.by', { n: c.by }) : `${tt('cs.by_l')}: ${ND}`}</span></p>
      ${sec('cs.reason', `${c.complaint ? para(c.complaint) : none}${c.history ? `<h5>${tt('cf.history')}</h5>${para(c.history)}` : ''}`)}
      ${sec('cs.exam', `<div class="kv sm">${vital('cf.weight', e.weight ? ltr(e.weight) + ' ' + tt('u.kg') : null)}${vital('cf.height', e.height ? ltr(e.height) + ' ' + tt('u.cm') : null)}
        ${vital('cf.bmi', b)}${vital('cf.bp', e.sys ? ltr(e.sys + '/' + e.dia) + ' ' + tt('u.mmhg') : null)}${vital('cf.hr', e.hr ? ltr(e.hr) + ' ' + tt('u.bpm') : null)}</div>${e.notes ? para(e.notes) : ''}`)}
      ${sec('cs.dx', c.dx ? `<p><b>${h(tv('ptype.', c.dx.type))}</b>${c.dx.since ? ' · ' + tt('cf.since_v', { y: c.dx.since }) : ''}</p>
        ${c.dx.conditions?.length ? `<p class="chips">${c.dx.conditions.map(k => `<span>${tt('cond.' + k)}</span>`).join('')}</p>` : ''}${c.dx.notes ? para(c.dx.notes) : ''}` : none)}
      ${sec('cs.labs', c.labs?.length ? `<table class="tbl sm"><tbody>${c.labs.map(l => `<tr><td>${tt('lab.' + l.test)}</td><td><b>${ltr(l.v + ' ' + (LABS[l.test] ?? ''))}</b></td><td><small>${h(ldate(DF.DATE, l.at))}</small></td></tr>`).join('')}</tbody></table>` : none)}
      ${sec('cs.meds', `${changed.length ? `<ul class="mrxlist">${changed.map(medRow).join('')}</ul>` : `<p>${tt('cons.no_changes')}</p>`}
        ${kept.length ? `<ul class="mrxlist kept">${kept.map(medRow).join('')}</ul>` : ''}`)}
      ${sec('cs.plan', `${para(c.plan)}<p class="tgt"><small>${c.protocol ? tt('prot.' + c.protocol) : ''}${c.targets ? ' · ' + ltr(`${c.targets.low}–${c.targets.high} mg/dL · TIR > ${c.targets.tir}% · TBR < ${c.targets.tbr}%`) : c.protocol ? ' · ' + tt('cf.targets_default') : ''}</small></p>`)}
      ${sec('cs.fu', c.followUp?.at ? `<p><b>${h(ldate(DF.FOLLOW_UP, c.followUp.at))}</b>${FU_ST.includes(c.followUp.status) ? ` <span class="pill fu-${c.followUp.status}">${tt('cs.fu_st.' + c.followUp.status)}</span>` : ''}</p>
        ${c.followUp.notes ? `<p><span class="lbl2">${tt('cs.fu_reason')}:</span> <span dir="auto">${h(c.followUp.notes)}</span></p>` : ''}` : none)}
      ${c.notes ? sec('cf.notes', para(c.notes)) : ''}
    </div></details>`;
}

// ===== Meal log: compact rows, details on demand =====
const IMPCL = { low: 'ok', moderate: 'ctrl', high: 'crit' };
export function mealLog(meals, { patients = null, limit = 20, id = 'mlog' } = {}) {
  if (!meals.length) return `<p class="empty">${tt('meals.none')}</p>`;
  const row = (m, i) => { const d = Number.isFinite(m.after) ? m.after - m.before : null;
    return `<details class="mrow ${IMPCL[m.imp] ?? 'none'}"${i >= limit ? ' hidden data-more' : ''} data-s="${h((m.name + ' ' + m.items.join(' ')).toLocaleLowerCase())}">
      <summary><span class="mt"><b dir="auto">${h(m.name)}</b><small>${patients ? `${h(patients[m.pid]?.name ?? '')} · ` : ''}${h(tv('mealtype.', m.type))} · ${h(ldate(DF.DATE_TIME, m.at))}</small></span>
        <span class="mc"><b>${h(m.carbs)}</b> ${tt('unit.g')}<small>${tt('meals.carbs')}</small></span><span class="mc"><b>${h(m.kcal)}</b><small>${tt('meals.kcal')}</small></span>
        <span class="mg">${ltr(`${m.before} → ${m.after ?? '…'}`)}<small>${d === null ? tt('meals.pending') : ltr((d >= 0 ? '+' : '') + d + ' mg/dL')}</small></span>
        <span>${m.imp ? `<span class="pill b-${IMPCL[m.imp]}">${tt('imp.' + m.imp)}</span>` : `<span class="pill b-none">${tt('imp.none')}</span>`}</span></summary>
      <div class="mdet"><div class="chips"><span><b>${h(m.protein)} ${tt('unit.g')}</b> ${tt('meals.protein')}</span><span><b>${h(m.fat)} ${tt('unit.g')}</b> ${tt('meals.fat')}</span>
        <span>${tt('meals.src_' + (m.src ?? 'cgm'))}</span></div><div class="tags">${m.items.map(i => `<span dir="auto">${h(i)}</span>`).join('')}</div></div></details>`; };
  return `<div class="mlog" id="${id}">${meals.map(row).join('')}</div>${meals.length > limit ? `<button class="btn ghost sm" data-showall="${id}">${tt('meals.show_all', { n: meals.length })}</button>` : ''}`;
}
export function wireMealLog() {
  document.querySelectorAll('[data-showall]').forEach(b => b.onclick = () => {
    document.querySelectorAll(`#${b.dataset.showall} [data-more]`).forEach(x => { x.hidden = false; }); b.remove(); });
}
// Links inside the patient file that jump to another tab (e.g. a medication → its consultation)
export function wireTabLinks() {
  document.querySelectorAll('[data-goto]').forEach(a => a.addEventListener('click', e => {
    const b = document.querySelector(`.tabs button[data-tab="${a.dataset.goto}"]`); if (!b) return;
    e.preventDefault(); b.click();
    const target = document.querySelector(a.getAttribute('href'));
    if (target) { target.open = true; target.scrollIntoView({ block: 'start' }); }
  }));
}

// ===== Why a glucose alert was generated: the rule that fired and the readings of the episode =====
// Read-only view of the same alert (core/clinical.js deriveAlerts or the backend); nothing is recalculated
// differently. An episode = the readings in the same state from its start (a.at) to its end (a.end).
export function alertBasis(p, a, open = false) {
  const tg = targets(p), end = a.end ?? a.at;
  const lowSide = a.st === 'low' || (a.st === 'crit' && a.v < tg.low);
  const same = r => (a.st === 'crit' ? r.st === 'crit' && (r.v < tg.low) === lowSide : r.st === a.st);
  // a single-reading alert is that one reading (a manual reading); a longer episode is consecutive sensor readings
  const rs = (a.n > 1 ? p.readings.filter(r => r.src === 'cgm' && r.at >= a.at && r.at <= end && same(r))
    : p.readings.filter(r => r.at === a.at && r.v === a.v).slice(0, 1)).sort((x, y) => x.at - y.at);
  const rule = a.st === 'ctrl' ? t('ab.rule_ctrl', { v: tg.high }) : t(a.st === 'crit' ? 'ab.rule_l2' : 'ab.rule', { r: stRange(a.st, tg, a.v) });
  return `<details class="abasis"${open ? ' open' : ''}><summary>${tt('ab.title')} · ${h(rule)} · ${tt('ab.n', { n: rs.length })}</summary>
    <div class="tscroll"><table class="tbl sm"><thead><tr><th>${tt('ab.c.time')}</th><th>mg/dL</th><th>${tt('ab.c.src')}</th><th>${tt('ab.c.class')}</th></tr></thead>
    <tbody>${rs.map(r => `<tr><td>${h(ldate(DF.DATE_TIME, r.at))}</td><td><b class="r-${r.st}">${h(r.v)}</b></td><td>${tt(r.src === 'cgm' ? 'glu.sensor' : 'glu.manual')}</td><td>${h(readingLabel(r.st))} ${ltr('(' + stRange(r.st, tg, r.v) + ')')}</td></tr>`).join('')}</tbody></table></div></details>`;
}
