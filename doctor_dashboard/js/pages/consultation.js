// Document a consultation (?id=<patient>). The first one is the initial face-to-face assessment at the clinic.
// This form is the ONLY place where medication is started, changed or stopped, and every change needs a reason.
// Consultation records are not edited afterwards; a correction is documented as a new consultation.
import { mount } from '../ui/layout.js';
import { t, tt, tv, ldate, iso } from '../core/i18n.js';
import { $, $$, h, ic, qint, url } from '../core/dom.js';
import { now, toLocalInput, fromLocalInput, addDays, startOfDay } from '../core/time.js';
import { FREQ, TIMING, UNITS, ROUTES, DRUGS } from '../core/medications.js';
import { PROTOCOLS, DIABETES_TYPES, protocolsForType, defaultProtocolId } from '../core/protocols.js';
import { CONS_MODES, CONDITIONS, LABS, bmi } from '../core/record.js';
import { setFlash, local } from '../core/storage.js';
import { getPatients, addConsultation, getDoctor, TEST_ON } from '../data/api.js';
import { go } from '../ui/nav.js';
import { statusBlock, patientMeta, avatar, medDose, medSchedule, empty } from '../ui/components.js';

const all = await getPatients(), id = qint('id'), p = all[id];
const head = { page: 'patients', title: t('cons.form_title'), heading: t('cons.form_title'), sub: p ? p.name : '' };

if (!p) {
  await mount(head, empty('common.not_found'));
} else {
  // Two consultation types only: Initial (first, face to face) or Follow-up. Urgency is a separate flag (c.urgent)
  const initial = p.awaiting, kinds = initial ? ['initial'] : ['follow_up'];
  const type0 = p.type ?? p.reportedType ?? 'Type 2', prot0 = p.protocolId ?? defaultProtocolId(type0);
  const tg0 = p.targets, dx0 = p.dx ?? { conditions: [] };
  const opt = (list, cur, key) => list.map(v => `<option value="${h(v)}"${v === cur ? ' selected' : ''}>${h(key ? t(key + v) : v)}</option>`).join('');
  const timingBoxes = (name, sel = []) => `<div class="checks">${Object.keys(TIMING).map(k => `<label><input type="checkbox" name="${name}" value="${k}"${sel.includes(k) ? ' checked' : ''}> ${tt('timing.' + k)}</label>`).join('')}</div>`;
  const doseFields = (pre, v = {}) => `
    <label>${tt('med.col.dose')}<input type="number" name="${pre}dose" min="0" step="any" value="${h(v.dose ?? '')}"></label>
    <label>${tt('med.unit')}<select name="${pre}unit">${opt(UNITS, v.unit ?? 'mg', 'unit.')}</select></label>
    <label>${tt('med.freq')}<select name="${pre}freq">${opt(FREQ, v.freq ?? 'once_daily', 'freq.')}</select></label>
    <label>${tt('med.days')}<input type="number" name="${pre}days" min="1" step="1" placeholder="${tt('med.ongoing')}" value="${h(v.days ?? '')}"></label>
    <div class="wide"><span class="lab">${tt('med.timing')}</span>${timingBoxes(pre + 'timing', v.timing ?? [])}</div>`;

  await mount(head, `
  <div class="card c-info head">${avatar(p.name, 'avatar big')}<div><b class="nm" dir="auto">${h(p.name)}</b><small>${h(patientMeta(p))}</small></div>${statusBlock(p)}</div>
  ${initial ? `<p class="infobox">${ic('steth')} ${tt('cf.initial_note')}</p>` : ''}
  <form class="cform" id="cf" novalidate>
    <p class="warn" id="err" hidden role="alert"></p>

    <fieldset><legend>1 · ${tt('cf.visit')}</legend>
      <label>${tt('cf.date')}<input type="datetime-local" name="at" required value="${toLocalInput(now())}" max="${toLocalInput(now() + 60)}"></label>
      <label>${tt('cf.kind')}<select name="kind">${opt(kinds, kinds[0], 'cons.kind.')}</select></label>
      <label>${tt('cf.mode')}<select name="mode"${initial ? ' disabled' : ''}>${opt(initial ? ['in_person'] : CONS_MODES, 'in_person', 'cons.mode.')}</select>
        ${initial ? `<small class="hint">${tt('cf.mode_initial')}</small>` : ''}</label>
      ${initial ? '' : `<label class="chk urg"><input type="checkbox" name="urgent"> ${tt('cs.urgent')}</label>`}
    </fieldset>

    <fieldset><legend>2 · ${tt('cs.reason')}</legend>
      <label class="wide">${tt('cf.complaint')}<textarea name="complaint" rows="2" dir="auto"></textarea></label>
      <label class="wide">${tt('cf.history')}<textarea name="history" rows="3" dir="auto" placeholder="${tt('cf.history_ph')}"></textarea></label>
    </fieldset>

    <fieldset><legend>3 · ${tt('cs.exam')}</legend>
      <label>${tt('cf.weight')} (${tt('u.kg')})<input type="number" name="weight" min="1" max="400" step="0.1"></label>
      <label>${tt('cf.height')} (${tt('u.cm')})<input type="number" name="height" min="50" max="250"></label>
      <label>${tt('cf.bmi')}<output id="bmi">—</output></label>
      <label>${tt('cf.bp')} (${tt('u.mmhg')})<span class="pair"><input type="number" name="sys" min="50" max="260" aria-label="${tt('cf.sys')}" placeholder="${tt('cf.sys')}"> / <input type="number" name="dia" min="30" max="160" aria-label="${tt('cf.dia')}" placeholder="${tt('cf.dia')}"></span></label>
      <label>${tt('cf.hr')} (${tt('u.bpm')})<input type="number" name="hr" min="20" max="250"></label>
      <label class="wide">${tt('cf.exam_notes')}<textarea name="exam_notes" rows="2" dir="auto" placeholder="${tt('cf.exam_ph')}"></textarea></label>
    </fieldset>

    <fieldset><legend>4 · ${tt('cs.dx')}</legend>
      <label>${tt('pf.type')} *<select name="type" required>${opt(DIABETES_TYPES, type0, 'ptype.')}</select>
        ${p.typeConfirmed ? '' : `<small class="hint">${tt('cf.type_reported', { v: tv('ptype.', p.reportedType ?? '') || '—' })}</small>`}</label>
      <label>${tt('cf.since')}<input type="number" name="since" min="1930" max="${new Date().getFullYear()}" value="${h(dx0.since ?? '')}"></label>
      <div class="wide"><span class="lab">${tt('cf.conditions')}</span><div class="checks">${CONDITIONS.map(k => `<label><input type="checkbox" name="cond" value="${k}"${dx0.conditions?.includes(k) ? ' checked' : ''}> ${tt('cond.' + k)}</label>`).join('')}</div></div>
      <label class="wide">${tt('cf.dx_notes')}<textarea name="dx_notes" rows="2" dir="auto">${h(dx0.notes ?? '')}</textarea></label>
    </fieldset>

    <fieldset><legend>5 · ${tt('cf.labs')}</legend>
      <div class="wide" id="labs"></div>
      <button type="button" class="btn ghost sm" id="addLab">+ ${tt('cf.add_lab')}</button>
    </fieldset>

    <fieldset><legend>6 · ${tt('cs.meds')}</legend>
      <p class="hint wide">${tt('cf.meds_hint')}</p>
      <div class="wide">${p.regimen.active.map(v => `<div class="medrow cur" data-rx="${h(v.rx)}">
        <div class="mhd"><b>${h(iso(v.drug))} ${h(medDose(v))}</b><small>${h(medSchedule(v))}</small>
          <select name="act-${h(v.rx)}" aria-label="${tt('cf.med_action')}">${['continue', 'change', 'stop'].map(a => `<option value="${a}">${tt('medact.' + a)}</option>`).join('')}</select></div>
        <div class="mchange" hidden>${doseFields(`c-${v.rx}-`, v)}</div>
        <label class="wide mreason" hidden>${tt('med.reason')} *<textarea name="reason-${h(v.rx)}" rows="2" dir="auto" placeholder="${tt('cf.reason_ph')}"></textarea></label>
      </div>`).join('') || `<p class="txt">${tt('cf.no_active')}</p>`}</div>
      <div class="wide" id="newMeds"></div>
      <button type="button" class="btn ghost sm" id="addMed">+ ${tt('cf.add_med')}</button>
      <datalist id="drugs">${DRUGS.map(d => `<option value="${h(d)}">`).join('')}</datalist>
    </fieldset>

    <fieldset id="targets"><legend>7 · ${tt('cf.targets')}</legend>
      <label>${tt('pf.protocol')}<select name="protocol" id="prot"></select><small class="hint">${tt('prot.unreviewed_long')}</small></label>
      <label>${tt('cf.t_low')}<input type="number" name="t_low" min="50" max="150" value="${tg0.low}"></label>
      <label>${tt('cf.t_high')}<input type="number" name="t_high" min="120" max="300" value="${tg0.high}"></label>
      <label>${tt('cf.t_tir')}<input type="number" name="t_tir" min="10" max="100" value="${tg0.tir}"></label>
      <label>${tt('cf.t_tbr')}<input type="number" name="t_tbr" min="0" max="20" step="0.5" value="${tg0.tbr}"></label>
      <small class="hint wide">${tt('cf.targets_hint')}</small>
    </fieldset>

    <fieldset><legend>8 · ${tt('cs.plan')} & ${tt('cs.fu')}</legend>
      <label class="wide">${tt('cf.plan')} *<textarea name="plan" rows="4" dir="auto" required placeholder="${tt('cf.plan_ph')}"></textarea></label>
      <label>${tt('cf.fu_date')}${initial ? ' *' : ''}<input type="datetime-local" name="fu_at" min="${toLocalInput(now())}" value="${toLocalInput(addDays(startOfDay(), 14) + 10 * 3600)}"></label>
      <label class="wide2">${tt('cf.fu_notes')}<input name="fu_notes" dir="auto"></label>
      <label class="wide">${tt('cf.notes')}<textarea name="notes" rows="2" dir="auto"></textarea></label>
    </fieldset>

    <label class="confirm"><input type="checkbox" name="confirm" required> <span>${initial ? tt('cf.confirm_initial') : tt('cf.confirm')}</span></label>
    <p class="hint">${TEST_ON ? tt('cf.saved_local') : tt('cf.saved_where')}</p>
    <div class="pact"><button type="submit" class="btn">${tt('cf.save')}</button><button type="button" class="btn ghost" id="draftBtn">${tt('cf.save_draft')}</button>
      <a class="btn ghost" href="patient.html?id=${id}#t-con">${tt('prof.cancel')}</a><small class="hint" id="draftSt" role="status"></small></div>
  </form>`);

  const form = $('#cf'), F = n => form.elements.namedItem(n);
  // BMI follows weight and height
  const upBmi = () => { $('#bmi').textContent = bmi(+F('weight').value, +F('height').value) ?? '—'; };
  F('weight').oninput = F('height').oninput = upBmi;
  // Protocol options follow the diabetes type; choosing one fills its default targets
  const fillProt = (keep) => {
    const ps = protocolsForType(F('type').value), cur = keep && ps.some(x => x.id === prot0) ? prot0 : ps[0].id;
    $('#prot').innerHTML = ps.map(x => `<option value="${x.id}"${x.id === cur ? ' selected' : ''}>${tt('prot.' + x.id)}</option>`).join('');
    if (!keep) setTargets(PROTOCOLS[cur].targets);
  };
  const setTargets = tg => { F('t_low').value = tg.low; F('t_high').value = tg.high; F('t_tir').value = tg.tir; F('t_tbr').value = tg.tbr; };
  F('type').onchange = () => fillProt(false);
  $('#prot').onchange = () => setTargets(PROTOCOLS[$('#prot').value].targets);
  fillProt(true);

  // Laboratory rows
  let nLab = 0;
  const addLab = () => { const i = nLab++;
    $('#labs').insertAdjacentHTML('beforeend', `<div class="labrow"><select name="lab-${i}" aria-label="${tt('cf.lab_test')}">${Object.keys(LABS).map(k => `<option value="${k}">${tt('lab.' + k)} (${h(LABS[k])})</option>`).join('')}</select>
      <input type="number" step="any" name="labv-${i}" aria-label="${tt('cf.lab_value')}" placeholder="${tt('cf.lab_value')}"><input type="date" name="labd-${i}" aria-label="${tt('cf.lab_date')}" value="${new Date().toISOString().slice(0, 10)}">
      <button type="button" class="lnk del" data-rm>${tt('rem.delete')}</button></div>`); };
  $('#addLab').onclick = addLab;
  if (initial) addLab();

  // Current medications: continue / change / stop
  $$('.medrow.cur').forEach(r => { const sel = r.querySelector('select'); sel.onchange = () => {
    r.querySelector('.mchange').hidden = sel.value !== 'change'; r.querySelector('.mreason').hidden = sel.value === 'continue'; }; });
  // New medications
  let nMed = 0;
  $('#addMed').onclick = () => { const i = nMed++;
    $('#newMeds').insertAdjacentHTML('beforeend', `<div class="medrow new" data-new="${i}"><div class="mhd"><b>${tt('cf.new_med')}</b><button type="button" class="lnk del" data-rm>${tt('rem.delete')}</button></div>
      <div class="mchange"><label class="wide2">${tt('med.col.drug')} *<input name="n-${i}-drug" list="drugs" dir="auto" required></label>
      <label>${tt('med.route')}<select name="n-${i}-route">${opt(ROUTES, 'oral', 'route.')}</select></label>${doseFields(`n-${i}-`)}
      <label class="wide">${tt('med.notes')}<input name="n-${i}-notes" dir="auto"></label></div>
      <label class="wide mreason">${tt('med.reason')} *<textarea name="n-${i}-reason" rows="2" dir="auto" placeholder="${tt('cf.reason_new_ph')}"></textarea></label></div>`); };
  form.addEventListener('click', e => { const b = e.target.closest('[data-rm]'); if (b) b.closest('.labrow, .medrow').remove(); });

  // Validation: one clear message, and the field concerned is marked and focused
  const err = (key, field) => {
    const el = $('#err'); el.textContent = t(key); el.hidden = false;
    $$('.cform .bad').forEach(x => { x.classList.remove('bad'); x.removeAttribute('aria-invalid'); });
    const fld = typeof field === 'string' ? F(field) : field;
    if (fld) { fld.classList.add('bad'); fld.setAttribute('aria-invalid', 'true'); fld.setAttribute('aria-describedby', 'err');
      fld.closest('fieldset, .medrow')?.scrollIntoView({ block: 'center' }); fld.focus({ preventScroll: true }); }
    else el.scrollIntoView({ block: 'center' });
  };
  form.addEventListener('input', e => { if (e.target.classList?.contains('bad')) { e.target.classList.remove('bad'); e.target.removeAttribute('aria-invalid'); } });

  // ===== Drafts: kept in this browser per patient until the consultation is saved or the draft is discarded =====
  // Every field, the added laboratory and medication rows, and the action chosen for each current medication
  const DKEY = `dms-cdraft-${id}`;
  const snapshot = () => ({ at: now(), labs: $$('.labrow').length, meds: $$('.medrow.new').length,
    v: [...form.elements].filter(x => x.name && x.name !== 'confirm' && x.type !== 'button' && x.type !== 'submit').map(x => [x.name, x.type === 'checkbox' ? (x.checked ? x.value : null) : x.value, x.type === 'checkbox']) });
  const saveDraft = manual => { local.set(DKEY, snapshot()); const s = $('#draftSt'); s.textContent = t('cf.draft_saved', { t: ldate('h:i A', now()) }); if (manual) s.focus?.(); };
  const restore = d => {
    for (let i = 0; i < d.labs; i++) addLab();
    for (let i = 0; i < d.meds; i++) $('#addMed').click();
    // the initial consultation starts with one empty lab row: keep the draft's count
    while ($$('.labrow').length > d.labs) $$('.labrow').at(-1).remove();
    const checks = new Set(d.v.filter(x => x[2] && x[1] !== null).map(x => x[0] + '=' + x[1]));
    for (const x of form.elements) {
      if (!x.name) continue;
      if (x.name === 'confirm') continue;
      if (x.type === 'checkbox') x.checked = checks.has(x.name + '=' + x.value);
      else { const hit = d.v.find(y => y[0] === x.name && !y[2]); if (hit) x.value = hit[1]; }
    }
    if (F('type')) fillProt(true);
    const pv = d.v.find(y => y[0] === 'protocol'); if (pv) { $('#prot').value = pv[1]; for (const k of ['t_low', 't_high', 't_tir', 't_tbr']) { const z = d.v.find(y => y[0] === k); if (z) F(k).value = z[1]; } }
    $$('.medrow.cur select').forEach(s => s.onchange?.()); upBmi();
  };
  const draft = local.get(DKEY, null);
  if (draft?.v) {
    restore(draft);
    $('#err').insertAdjacentHTML('beforebegin', `<p class="infobox draftbox" id="draftBox">${ic('note')} <span>${tt('cf.draft_restored', { t: ldate('M d, Y · h:i A', draft.at) })}</span>
      <button type="button" class="lnk" id="draftDel">${tt('cf.draft_discard')}</button></p>`);
    $('#draftDel').onclick = () => { local.set(DKEY, undefined); location.reload(); };
  }
  let dt0 = null;
  form.addEventListener('input', () => { clearTimeout(dt0); dt0 = setTimeout(() => saveDraft(false), 800); });
  form.addEventListener('change', () => { clearTimeout(dt0); dt0 = setTimeout(() => saveDraft(false), 300); });
  $('#draftBtn').onclick = () => saveDraft(true);
  const num = v => (v === '' || v === null || v === undefined ? null : Number(v));
  const doseOf = pre => ({ dose: num(F(pre + 'dose').value), unit: F(pre + 'unit').value, freq: F(pre + 'freq').value,
    days: num(F(pre + 'days').value), timing: $$(`[name="${pre}timing"]:checked`).map(x => x.value) });
  const doseOk = d => d.dose > 0 && (d.freq === 'as_needed' || d.timing.length > 0);

  form.onsubmit = async e => {
    e.preventDefault();
    const f = new FormData(form), at = fromLocalInput(String(f.get('at') ?? ''));
    if (!at || at > now() + 60) return err('cf.err.date', 'at');
    const plan = String(f.get('plan') ?? '').trim();
    if (!plan) return err('cf.err.plan', 'plan');
    const fuAt = fromLocalInput(String(f.get('fu_at') ?? ''));
    if (initial && !fuAt) return err('cf.err.fu', 'fu_at');
    if (fuAt && fuAt <= at) return err('cf.err.fu_after', 'fu_at');
    // Medication actions
    const meds = [];
    for (const v of p.regimen.active) {
      const act = f.get('act-' + v.rx), reason = String(f.get('reason-' + v.rx) ?? '').trim();
      if (act !== 'continue' && !reason) return err('cf.err.reason', 'reason-' + v.rx);
      if (act === 'change') { const d = doseOf(`c-${v.rx}-`); if (!doseOk(d)) return err('cf.err.dose', `c-${v.rx}-dose`); meds.push({ act, rx: v.rx, drug: v.drug, route: v.route, ...d, reason }); }
      else meds.push({ act, rx: v.rx, drug: v.drug, reason });
    }
    for (const r of $$('.medrow.new')) {
      const i = r.dataset.new, drug = String(f.get(`n-${i}-drug`) ?? '').trim(), reason = String(f.get(`n-${i}-reason`) ?? '').trim(), d = doseOf(`n-${i}-`);
      if (!drug) return err('cf.err.dose', `n-${i}-drug`);
      if (!doseOk(d)) return err('cf.err.dose', `n-${i}-dose`);
      if (!reason) return err('cf.err.reason', `n-${i}-reason`);
      meds.push({ act: 'start', rx: `rx-${Date.now().toString(36)}-${i}`, drug, route: f.get(`n-${i}-route`), ...d, notes: String(f.get(`n-${i}-notes`) ?? '').trim(), reason });
    }
    const labs = $$('.labrow').map(r => { const s = r.querySelector('select'), i = s.name.split('-')[1];
      return { test: s.value, v: num(f.get('labv-' + i)), at: Math.floor(Date.parse(f.get('labd-' + i)) / 1000) || at }; }).filter(l => l.v !== null);
    // Targets are stored only when they differ from the protocol defaults (individualized)
    const prot = String(f.get('protocol')), pd = PROTOCOLS[prot].targets;
    const tg = { low: num(f.get('t_low')), high: num(f.get('t_high')), tir: num(f.get('t_tir')), tbr: num(f.get('t_tbr')) };
    if (!(tg.low > 0 && tg.high > tg.low && tg.tir > 0 && tg.tir <= 100 && tg.tbr >= 0)) return err('cf.err.targets', !(tg.low > 0) ? 't_low' : !(tg.high > tg.low) ? 't_high' : !(tg.tir > 0 && tg.tir <= 100) ? 't_tir' : 't_tbr');
    if (!f.get('confirm')) return err('cf.err.confirm', 'confirm');
    const indiv = ['low', 'high', 'tir', 'tbr'].some(k => tg[k] !== pd[k]) ? tg : null;
    // by: the signed-in doctor who documents it; status: saved records are final (a draft stays in this browser)
    const c = { at, by: getDoctor().name || null, status: 'final', kind: f.get('kind'), mode: initial ? 'in_person' : f.get('mode'), ...(f.get('urgent') ? { urgent: true } : {}),
      complaint: String(f.get('complaint') ?? '').trim(), history: String(f.get('history') ?? '').trim(),
      exam: { weight: num(f.get('weight')), height: num(f.get('height')), sys: num(f.get('sys')), dia: num(f.get('dia')), hr: num(f.get('hr')), notes: String(f.get('exam_notes') ?? '').trim() },
      dx: { type: f.get('type'), since: num(f.get('since')), conditions: f.getAll('cond'), notes: String(f.get('dx_notes') ?? '').trim() },
      labs, protocol: prot, targets: indiv, meds, plan,
      followUp: fuAt ? { at: fuAt, notes: String(f.get('fu_notes') ?? '').trim() } : null, notes: String(f.get('notes') ?? '').trim() };
    await addConsultation(id, c);
    clearTimeout(dt0); local.set(DKEY, undefined);
    setFlash(meds.some(m => m.act !== 'continue') ? 'cf.saved_tx' : 'cf.saved');
    go(url('patient.html', { id }, 't-con'));
  };
}
