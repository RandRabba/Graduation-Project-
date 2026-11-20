// ===== TEST DATA ONLY =====
// Not real patient information. Used only to try the dashboard before the FastAPI backend is connected.
// Loaded through js/data/api.js only when CONFIG.dataSource is 'mock' and CONFIG.testMode is true.
//
// Detailed single-patient scenarios (Sobhi only) for development and the unit tests, chosen with ?demo=<scenario>.
// The default demo (three patients) is js/data/mock/demo-patients.js. Scenarios:
//   all: Sobhi's complete history: Normal (days −21…−14) → Controlled (−13…−7) → Critical (−6…today)
//   ok / ctrl / crit: one phase for the whole 21 days
//   new: just registered and linked to the doctor, awaiting the initial face-to-face consultation
//
// NO STATUS IS SET BY HAND. A scenario only changes the inputs (meals, doses, treatment), and the dashboard
// calculates every status, statistic, alert and flag from the generated readings with the same clinical rules
// it will apply to backend data. The unit tests check that each scenario's calculated status matches its name.
//
// How the readings are generated (deterministic, identical on every load):
// - Sensor (CGM) reading every hour + a manual fasting reading each morning
// - Glucose = phase baseline + dawn rise + the rise after each logged meal (carbs × phase sensitivity,
//   peaking about 75 minutes after eating) + the effect of missed doses (missed bedtime insulin raises the
//   next morning; missed metformin raises the next hours) + noise
// - So the data contains real relationships between food, medication taking and glucose for the analytics
// - Treatment comes only from documented consultations (initial visit 22 days ago, then follow-ups);
//   doses are scheduled from the prescriptions and logged as taken/missed by phase adherence
// - Example day (yesterday) in every scenario except "new": 9:00 AM 110 normal → 1:00 PM 280 critical
//   (2 hours after a high-carb mansaf lunch) → 5:00 PM 195 controlled → 9:00 PM 120 normal
// - Times are relative to today and the latest reading is 50 minutes ago, so the data stays fresh
import { DAY, now as nowTs, today } from '../../core/time.js';
import { deriveRegimen, scheduledDoses, isInsulin } from '../../core/medications.js';
import { impactOf } from '../../core/clinical.js';

// Deterministic random numbers, so readings are identical on every load
function rng(seed) {
  let a = seed >>> 0;
  const next = () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  return (min, max) => min + Math.floor(next() * (max - min + 1));   // integer in [min, max]
}
// Rise after a meal, relative to its peak (1 at 75 minutes), over 6 hours
const mealCurve = hrs => (hrs <= 0 || hrs > 6 ? 0 : (hrs / 1.25) * Math.exp(1 - hrs / 1.25));
const dawn = h => (h >= 3 && h <= 8 ? 18 * Math.sin(Math.PI * (h - 3) / 5) : 0);

export function buildSampleData({ lang = 'en', scenario = 'all' } = {}) {
  const t0 = today(), now = nowTs();
  const at = (day, hour) => Math.floor(t0 + day * DAY + hour * 3600);   // negative day = days ago
  const dayOf = ts => Math.floor((ts - t0) / DAY);
  const L = (en, ar) => (lang === 'ar' ? ar : en);
  const lastAt = now - 50 * 60;                                         // latest reading (current state)
  // Example day: the full day before the latest reading (yesterday; the day before when it is just after midnight)
  const ex = lastAt < t0 ? -2 : -1;
  const isNew = scenario === 'new';

  // Registration data from the Patient App. The diabetes type is self-reported until the initial consultation
  const patients = {
    // No caregiver: the test patient has none on record (no placeholder contact details are shown)
    1: { name: L('Sobhi', 'صبحي'), age: 52, sex: 'M', reportedType: 'Type 2', linkedAt: isNew ? at(-2, 16) : at(-24, 11),
      focus_day: at(ex, 0) },
  };

  // Phase inputs. base: glucose without meals; sens: mg/dL rise per gram of carbs at the peak;
  // clamp: sensor limits of the phase; adh: share of doses taken; snack: chance of an afternoon snack
  const P = {
    ok: { base: 104, sens: 0.95, noise: 9, clamp: [76, 172], adh: 0.96, snack: 0.15, latest: 118, seed: 41 },
    ctrl: { base: 146, sens: 1.25, noise: 12, clamp: [96, 244], adh: 0.86, snack: 0.35, latest: 204, seed: 42 },
    crit: { base: 168, sens: 1.45, noise: 16, clamp: [40, 400], adh: 0.62, snack: 0.6, latest: 318, seed: 43 },
    new: { base: 150, sens: 1.2, noise: 10, clamp: [80, 260], adh: 0, snack: 0.3, latest: 196, seed: 44 },
  };
  const phaseOf = d => (scenario === 'all' ? (d <= -14 ? 'ok' : d <= -7 ? 'ctrl' : 'crit') : scenario);
  // Events are written in each phase's own days and moved to where the phase sits in "all"
  const SHIFT = scenario === 'all' ? { ok: -14, ctrl: -7, crit: 0 } : { [scenario]: 0 };
  const WIN = scenario === 'all' ? { ok: [-21, -14], ctrl: [-13, -7], crit: [-6, 0] } : { [scenario]: [-21, 0] };
  const keys = Object.keys(SHIFT), final = keys[keys.length - 1];
  // Time of a phase event, or null when it falls outside the phase (future events only for the last phase)
  const ev = (k, ts) => {
    if (!(k in SHIFT) || ts === null) return null;
    const t = ts + SHIFT[k] * DAY, d = dayOf(t), [a, b] = WIN[k];
    return d >= a && (d <= b || (k === final && t > now)) ? t : null;
  };

  // ===== Menus: [en, ar, carbs, kcal, protein, fat, items] =====
  const M = (en, ar, carbs, kcal, protein, fat, items) => ({ name: L(en, ar), carbs, kcal, protein, fat, items: items.map(([e, a]) => L(e, a)) });
  const healthy = {
    breakfast: [M('Oats with milk and nuts', 'شوفان بالحليب والمكسرات', 38, 320, 12, 9, [['Oats', 'شوفان'], ['Milk', 'حليب'], ['Walnuts', 'جوز']]),
      M('Labneh with vegetables', 'لبنة مع خضار', 32, 340, 14, 14, [['Labneh', 'لبنة'], ['Cucumber', 'خيار'], ['Tomato', 'بندورة'], ['Whole-wheat bread', 'خبز قمح كامل']]),
      M('Boiled eggs with whole-wheat bread', 'بيض مسلوق مع خبز قمح كامل', 28, 310, 16, 12, [['Boiled eggs', 'بيض مسلوق'], ['Whole-wheat bread', 'خبز قمح كامل'], ['Olives', 'زيتون']])],
    lunch: [M('Grilled chicken with brown rice', 'دجاج مشوي مع أرز بني', 42, 480, 36, 12, [['Grilled chicken', 'دجاج مشوي'], ['Brown rice', 'أرز بني'], ['Green salad', 'سلطة خضراء']]),
      M('Lentil soup with salad', 'شوربة عدس مع سلطة', 40, 360, 18, 7, [['Lentils', 'عدس'], ['Carrot', 'جزر'], ['Cucumber salad', 'سلطة خيار']]),
      M('Grilled fish with vegetables', 'سمك مشوي مع خضار', 30, 420, 34, 14, [['Grilled fish', 'سمك مشوي'], ['Roasted vegetables', 'خضار مشوية'], ['Lemon', 'ليمون']])],
    dinner: [M('Greek salad with chicken', 'سلطة يونانية مع دجاج', 22, 380, 30, 18, [['Chicken', 'دجاج'], ['Feta cheese', 'جبنة فيتا'], ['Vegetables', 'خضار']]),
      M('Yogurt with cucumber and bread', 'لبن مع خيار وخبز', 30, 260, 12, 7, [['Yogurt', 'لبن'], ['Cucumber', 'خيار'], ['Whole-wheat bread', 'خبز قمح كامل']]),
      M('Vegetable omelette', 'عجة بالخضار', 18, 300, 18, 16, [['Eggs', 'بيض'], ['Peppers', 'فلفل'], ['Onion', 'بصل']])],
    snack: [M('Apple', 'تفاحة', 25, 95, 0, 0, [['Apple', 'تفاح']]), M('Handful of almonds', 'حفنة لوز', 6, 170, 6, 15, [['Almonds', 'لوز']])],
  };
  const heavy = {
    breakfast: [M('Falafel sandwich', 'ساندويش فلافل', 70, 560, 16, 24, [['Falafel', 'فلافل'], ['Pita bread', 'خبز عربي'], ['Tahini', 'طحينة']]),
      M('Foul with pita bread', 'فول مع خبز عربي', 62, 480, 20, 14, [['Fava beans', 'فول'], ['Pita bread', 'خبز عربي'], ['Olive oil', 'زيت زيتون']]),
      M('Zaatar manakish', 'مناقيش زعتر', 58, 450, 10, 18, [['Manakish dough', 'عجينة مناقيش'], ['Zaatar', 'زعتر'], ['Olive oil', 'زيت زيتون']])],
    lunch: [M('Chicken kabsa', 'كبسة دجاج', 85, 720, 34, 22, [['White rice', 'أرز أبيض'], ['Chicken', 'دجاج'], ['Yogurt', 'لبن']]),
      M('Rice with okra stew', 'أرز مع بامية', 78, 640, 24, 20, [['White rice', 'أرز أبيض'], ['Okra stew', 'بامية'], ['Lamb', 'لحم خروف']]),
      M('Chicken shawarma wrap', 'شاورما دجاج', 66, 610, 32, 26, [['Pita bread', 'خبز عربي'], ['Chicken shawarma', 'شاورما دجاج'], ['Garlic sauce', 'ثومية']])],
    dinner: [M('Lentil soup with bread', 'شوربة عدس مع خبز', 52, 430, 18, 9, [['Lentils', 'عدس'], ['Bread', 'خبز'], ['Lemon', 'ليمون']]),
      M('Hummus with pita bread', 'حمص مع خبز عربي', 55, 470, 15, 20, [['Hummus', 'حمص'], ['Pita bread', 'خبز عربي'], ['Olive oil', 'زيت زيتون']]),
      M('Cheese sandwich', 'ساندويش جبنة', 45, 400, 16, 18, [['White bread', 'خبز أبيض'], ['White cheese', 'جبنة بيضاء']])],
    snack: [M('Dates', 'تمر', 36, 140, 1, 0, [['Dates', 'تمر']]), M('Biscuits with sweet tea', 'بسكويت مع شاي بالسكر', 32, 210, 3, 8, [['Biscuits', 'بسكويت'], ['Sweet tea', 'شاي بالسكر']])],
  };
  const veryHeavy = {
    breakfast: [M('White bread with jam', 'خبز أبيض مع مربى', 60, 410, 8, 9, [['White bread', 'خبز أبيض'], ['Jam', 'مربى'], ['Sweet tea', 'شاي بالسكر']]),
      M('Sweet pastries with tea', 'معجنات حلوة مع شاي', 72, 520, 8, 22, [['Croissant', 'كرواسون'], ['Sweet tea', 'شاي بالسكر']]),
      M('Zaatar manakish with sweet tea', 'مناقيش زعتر مع شاي بالسكر', 70, 520, 10, 18, [['Manakish dough', 'عجينة مناقيش'], ['Zaatar', 'زعتر'], ['Sweet tea', 'شاي بالسكر']])],
    lunch: [M('Maqluba with rice', 'مقلوبة بالأرز', 110, 860, 30, 34, [['White rice', 'أرز أبيض'], ['Fried eggplant', 'باذنجان مقلي'], ['Chicken', 'دجاج']]),
      M('Musakhan', 'مسخن', 88, 820, 36, 40, [['Taboon bread', 'خبز طابون'], ['Chicken', 'دجاج'], ['Onions', 'بصل'], ['Olive oil', 'زيت زيتون']]),
      M('Chicken kabsa', 'كبسة دجاج', 95, 780, 34, 24, [['White rice', 'أرز أبيض'], ['Chicken', 'دجاج']])],
    dinner: [M('Pizza', 'بيتزا', 90, 780, 30, 30, [['Pizza dough', 'عجينة بيتزا'], ['Cheese', 'جبنة'], ['Sausage', 'نقانق']]),
      M('Fried potatoes with bread', 'بطاطا مقلية مع خبز', 85, 690, 10, 32, [['Fried potatoes', 'بطاطا مقلية'], ['Bread', 'خبز']]),
      M('Chicken shawarma wrap', 'شاورما دجاج', 66, 610, 32, 26, [['Pita bread', 'خبز عربي'], ['Chicken shawarma', 'شاورما دجاج'], ['Garlic sauce', 'ثومية']])],
    snack: [M('Knafeh', 'كنافة', 95, 690, 14, 32, [['Semolina dough', 'عجينة السميد'], ['Sweet cheese', 'جبنة حلوة'], ['Sugar syrup', 'قطر']]),
      M('Qatayef', 'قطايف', 70, 520, 9, 22, [['Qatayef', 'قطايف'], ['Walnuts', 'جوز'], ['Sugar syrup', 'قطر']]),
      M('Soft drink', 'مشروب غازي', 39, 150, 0, 0, [['Soft drink', 'مشروب غازي']])],
  };
  const MENU = { ok: healthy, ctrl: heavy, crit: veryHeavy, new: heavy };

  // ===== Consultations (face-to-face clinic visits) and the treatment they prescribe =====
  const C = [];
  const dx = { type: 'Type 2', since: 2016, conditions: ['hypertension', 'dyslipidemia', 'obesity'],
    notes: L('Type 2 diabetes with hypertension and dyslipidemia. No known retinopathy or nephropathy.', 'سكري من النوع الثاني مع ارتفاع ضغط الدم واضطراب الدهون. لا يوجد اعتلال شبكية أو كلية معروف.') };
  const cont = (rx, drug) => ({ act: 'continue', rx, drug, reason: '' });
  if (!isNew) {
    C.push({ id: 'c-init', at: at(-22, 10), kind: 'initial', mode: 'in_person',
      complaint: L('Referred for diabetes management. Increasing fatigue and thirst over the last 2 months.', 'محوَّل لمتابعة السكري. تعب وعطش متزايد خلال الشهرين الماضيين.'),
      history: L('Type 2 diabetes since 2016 on metformin. Hypertension since 2019. Father has type 2 diabetes. Non-smoker. No previous hospital admissions for diabetes.',
        'سكري من النوع الثاني منذ 2016 على الميتفورمين. ارتفاع ضغط الدم منذ 2019. الأب مصاب بالسكري من النوع الثاني. غير مدخن. لا دخول سابق للمستشفى بسبب السكري.'),
      exam: { weight: 88, height: 172, sys: 138, dia: 86, hr: 78,
        notes: L('Feet: no ulcers, monofilament sensation intact. Referred for retinal screening.', 'القدمان: لا تقرحات، الإحساس سليم بفحص الخيط. تحويل لفحص الشبكية.') },
      dx, labs: [{ test: 'hba1c', v: 8.6, at: at(-24, 9) }, { test: 'fpg', v: 168, at: at(-24, 9) }, { test: 'egfr', v: 82, at: at(-24, 9) },
        { test: 'creat', v: 1.0, at: at(-24, 9) }, { test: 'ldl', v: 128, at: at(-24, 9) }, { test: 'uacr', v: 18, at: at(-24, 9) }],
      protocol: 't2-default', targets: null,
      meds: [
        { act: 'start', rx: 'rx-met', drug: 'Metformin', dose: 1000, unit: 'mg', route: 'oral', freq: 'twice_daily', timing: ['with_breakfast', 'with_dinner'], days: null,
          reason: L('Continued from previous treatment, verified at the initial assessment', 'استمرار العلاج السابق بعد التحقق منه في التقييم الأولي') },
        { act: 'start', rx: 'rx-gla', drug: 'Insulin glargine', dose: 14, unit: 'units', route: 'subcutaneous', freq: 'once_daily', timing: ['bedtime'], days: null,
          reason: L('HbA1c 8.6% above target despite metformin', 'الهيموغلوبين السكري 8.6% فوق الهدف رغم الميتفورمين') }],
      plan: L('Start basal insulin 14 units at bedtime and review fasting glucose at follow-up. CGM sensor fitted for continuous monitoring. Dietitian referral for carbohydrate counting. Walk 30 minutes daily.',
        'بدء الإنسولين القاعدي 14 وحدة قبل النوم ومراجعة السكر الصائم في المتابعة. تركيب حساس مراقبة مستمرة. تحويل لأخصائي تغذية لحساب الكربوهيدرات. المشي 30 دقيقة يومياً.'),
      followUp: { at: null, notes: L('Review CGM data and fasting glucose', 'مراجعة بيانات الحساس والسكر الصائم') }, notes: '' });
    const phaseCons = {
      ok: { at: at(-4, 10), kind: 'follow_up', complaint: L('Routine review. No symptoms of hypoglycaemia.', 'مراجعة دورية. لا أعراض هبوط سكر.'),
        exam: { weight: 87, height: 172, sys: 132, dia: 82, hr: 74, notes: '' }, labs: [],
        meds: [cont('rx-met', 'Metformin'), cont('rx-gla', 'Insulin glargine')],
        plan: L('Good control on the current treatment. Continue the same doses and meal plan.', 'سيطرة جيدة على العلاج الحالي. الاستمرار بنفس الجرعات والنظام الغذائي.'),
        fu: [at(10, 10), L('Routine follow-up', 'متابعة دورية')] },
      ctrl: { at: at(-2, 10), kind: 'follow_up', complaint: L('Higher readings after lunch; fasting readings around 160.', 'قراءات مرتفعة بعد الغداء؛ قراءات الصيام حوالي 160.'),
        exam: { weight: 89, height: 172, sys: 136, dia: 84, hr: 80, notes: '' }, labs: [{ test: 'fpg', v: 162 }],
        meds: [cont('rx-met', 'Metformin'), { act: 'change', rx: 'rx-gla', dose: 16,
          reason: L('Fasting glucose about 160 mg/dL and time above range over 25% for 7 days', 'السكر الصائم حوالي 160 والوقت فوق النطاق أكثر من 25% لمدة 7 أيام') }],
        plan: L('Increase bedtime glargine to 16 units. Reduce rice and bread portions at lunch and walk 20 minutes after meals. Send fasting readings for 3 days.',
          'رفع الغلارجين قبل النوم إلى 16 وحدة. تقليل كميات الأرز والخبز في الغداء والمشي 20 دقيقة بعد الوجبات. إرسال قراءات الصيام لمدة 3 أيام.'),
        fu: [at(5, 10), L('Review the effect of the dose change', 'مراجعة أثر تعديل الجرعة')] },
      crit: { at: at(-3, 9), kind: 'urgent', complaint: L('Night-time lows (48–51 mg/dL) and very high readings after meals. Reports missed doses.', 'هبوط ليلي (48–51) وقراءات مرتفعة جداً بعد الوجبات. يذكر نسيان جرعات.'),
        exam: { weight: 89, height: 172, sys: 142, dia: 88, hr: 92, notes: L('Alert, mildly dehydrated, no signs of ketoacidosis.', 'واعٍ، جفاف خفيف، لا علامات حماض كيتوني.') },
        labs: [{ test: 'ketones', v: 0.4 }, { test: 'hba1c', v: 9.1 }],
        meds: [cont('rx-met', 'Metformin'), { act: 'change', rx: 'rx-gla', dose: 12,
          reason: L('Night-time hypoglycaemia below 54 mg/dL on the current basal dose', 'هبوط سكر ليلي أقل من 54 على الجرعة القاعدية الحالية') }],
        plan: L('Reduce bedtime glargine to 12 units. Recheck manually when the sensor reads above 300 and test ketones; go to the emergency department if above 300 with vomiting or drowsiness. Carry 15 g of fast-acting sugar. Dietitian review of high-carbohydrate meals and evening snacks. Adherence counselling.',
          'خفض الغلارجين قبل النوم إلى 12 وحدة. إعادة القياس يدوياً عند قراءة الحساس فوق 300 وفحص الكيتونات؛ التوجه للطوارئ إذا كانت فوق 300 مع تقيؤ أو نعاس. حمل 15 غ من السكر سريع المفعول. مراجعة أخصائي التغذية للوجبات عالية الكربوهيدرات. إرشاد حول الالتزام بالأدوية.'),
        fu: [at(1, 9), L('Urgent clinic visit: review lows and adherence', 'زيارة عاجلة: مراجعة الهبوط والالتزام')] },
    };
    for (const k of keys) {
      const c = phaseCons[k], t = ev(k, c.at);
      if (t === null) continue;
      C.push({ id: `c-${k}`, at: t, kind: c.kind, mode: 'in_person', complaint: c.complaint, history: '', exam: c.exam, dx, protocol: 't2-default', targets: null,
        labs: c.labs.map(l => ({ ...l, at: t })), meds: c.meds, plan: c.plan, followUp: { at: c.fu[0] + SHIFT[k] * DAY, notes: c.fu[1] }, notes: '' });
    }
    // Each planned follow-up took place at the next consultation; the last one stays planned
    C.sort((a, b) => a.at - b.at);
    for (let i = 0; i < C.length - 1; i++) C[i].followUp.at = C[i + 1].at;
  }

  // ===== Doses from the prescriptions, taken or missed by phase adherence =====
  const lows = { crit: [[-7, 3.3, 51], [-3, 2.8, 48], [-1, 4.0, 62]] };
  const lowEvents = keys.flatMap(k => (lows[k] ?? []).map(([d, h, v]) => [ev(k, at(d, h)), v]).filter(([t]) => t !== null));
  const safeNights = new Set(lowEvents.map(([t]) => dayOf(t) - 1));   // the insulin before a low was taken
  const regimen = deriveRegimen(C, now);
  const doses = scheduledDoses(regimen.versions, at(-21, 0), lastAt).map(s => {
    const r = rng(Math.floor(s.at / 60)), k = phaseOf(dayOf(s.at));
    return { ...s, taken: (s.slot === 'bedtime' && safeNights.has(dayOf(s.at))) || r(0, 999) < P[k].adh * 1000 };
  });
  const verOf = id => regimen.versions.find(v => v.id === id);
  // Missed bedtime insulin raises glucose for the next 16 hours; other missed doses for 10 hours
  const missed = doses.filter(d => !d.taken).map(d => (isInsulin(verOf(d.ver)) ? [d.at, 16, 38] : [d.at, 10, 14]));
  const missEffect = ts => missed.reduce((s, [a, hrs, mag]) => s + (ts > a && ts < a + hrs * 3600 ? mag * Math.min(1, (ts - a) / 7200) : 0), 0);

  // ===== Meals =====
  const first = isNew ? -1 : -21, meals = [];
  for (let d = first; d <= 0; d++) {
    const k = phaseOf(d), r = rng(P[k].seed * 7919 + d + 500), menu = MENU[k];
    const pick = type => menu[type][r(0, menu[type].length - 1)];
    const slots = [['breakfast', 7.5 + r(0, 60) / 60], ['lunch', 13 + r(0, 60) / 60], ['dinner', 19 + r(0, 90) / 60]];
    if (r(0, 99) < P[k].snack * 100) slots.push(['snack', 16.5 + r(0, 60) / 60]);
    if (d === ex && !isNew) {   // the example day
      slots.length = 0;
      meals.push({ ...M('Labneh with cucumber', 'لبنة مع خيار', 22, 260, 12, 12, [['Labneh', 'لبنة'], ['Cucumber', 'خيار'], ['Pita bread', 'خبز عربي']]), id: 'ex-b', type: 'breakfast', at: at(ex, 7.5) },
        { ...M('Mansaf with rice', 'منسف بالأرز', 98, 840, 40, 36, [['White rice', 'أرز أبيض'], ['Lamb', 'لحم خروف'], ['Jameed sauce', 'جميد'], ['Shrak bread', 'خبز شراك']]), id: 'ex-l', type: 'lunch', at: at(ex, 11) },
        { ...M('Yogurt salad', 'سلطة لبن', 18, 220, 10, 8, [['Yogurt', 'لبن'], ['Cucumber', 'خيار'], ['Mint', 'نعنع']]), id: 'ex-d', type: 'dinner', at: at(ex, 19.5) });
    }
    for (const [type, hr] of slots) {
      const m = pick(type), f = 0.9 + r(0, 20) / 100, ts = at(d, hr);
      if (ts < lastAt) meals.push({ ...m, carbs: Math.round(m.carbs * f), kcal: Math.round(m.kcal * f), id: `m${d}-${type}`, type, at: ts });
    }
  }

  // ===== Glucose =====
  const model = ts => {
    const d = dayOf(ts), k = phaseOf(d), h = (ts - at(d, 0)) / 3600;
    let v = P[k].base + dawn(h) + missEffect(ts);
    for (const m of meals) if (m.at < ts && m.at > ts - 6 * 3600) v += P[phaseOf(dayOf(m.at))].sens * m.carbs * mealCurve((ts - m.at) / 3600);
    return v;
  };
  // Example day 8 AM – 10 PM follows set values (the 280 at 1 PM is the manual reading after the mansaf)
  const KP = [[8, 126], [9, 110], [10, 112], [11, 116], [12, 205], [13, 276], [14, 262], [15, 238], [16, 214], [17, 195], [18, 170], [19, 148], [20, 136], [21, 120], [22, 118]];
  const kp = h => { for (let i = 1; i < KP.length; i++) if (h <= KP[i][0]) { const [h0, v0] = KP[i - 1], [h1, v1] = KP[i]; return v0 + (v1 - v0) * (h - h0) / (h1 - h0); } return KP.at(-1)[1]; };
  const exDay = ts => !isNew && dayOf(ts) === ex && (ts - at(ex, 0)) / 3600 >= 8 && (ts - at(ex, 0)) / 3600 <= 22;
  const glu = ts => (exDay(ts) ? kp((ts - at(ex, 0)) / 3600) : model(ts));

  let R = [];
  for (let d = first; d <= 0; d++) {
    const k = phaseOf(d), pp = P[k], r = rng(pp.seed * 104729 + d + 500);
    const clamp = v => Math.max(pp.clamp[0], Math.min(pp.clamp[1], Math.round(v)));
    if (!isNew) for (let hr = 0; hr < 24; hr++) {
      const ts = at(d, hr + r(0, 10) / 60);
      if (exDay(at(d, hr))) R.push({ id: `g${d}-${hr}`, v: kp(hr), at: at(d, hr), src: 'cgm', type: 'RBS' });
      else R.push({ id: `g${d}-${hr}`, v: clamp(glu(ts) + r(-pp.noise, pp.noise)), at: ts, src: 'cgm', type: 'RBS' });
    }
    const fts = at(d, 7 + r(0, 20) / 60);
    R.push({ id: `f${d}`, v: clamp(glu(fts) + r(-6, 6)), at: fts, src: 'manual', type: 'FBS' });
    // Without a sensor ("new"), the patient checks manually 2 hours after lunch and dinner
    if (isNew) for (const m of meals.filter(x => dayOf(x.at) === d && x.type !== 'breakfast'))
      R.push({ id: `p${m.id}`, v: clamp(glu(m.at + 7200) + r(-8, 8)), at: m.at + 7200, src: 'manual', type: 'PPBS' });
  }
  if (!isNew) R.push({ id: 'ex-ppbs', v: 280, at: at(ex, 13), src: 'manual', type: 'PPBS' });
  // Night-time lows of the critical phase: the sensor dips around each event
  lowEvents.forEach(([t, v], i) => {
    for (const x of R) if (x.src === 'cgm' && Math.abs(x.at - t) < 5400) x.v = Math.round(x.v + (v - x.v) * (1 - Math.abs(x.at - t) / 5400));
    R.push({ id: `low${i}`, v, at: t, src: 'cgm', type: 'RBS' });
  });
  // Latest reading sets the current state; the last 3 hours lead up to it
  const latest = P[phaseOf(0)].latest;
  R = R.filter(x => x.at < lastAt);
  for (const x of R) if (x.src === 'cgm' && x.at > lastAt - 10800 && !exDay(x.at)) x.v = Math.round(x.v + (latest - x.v) * (1 - (lastAt - x.at) / 10800));
  R.push({ id: 'latest', v: latest, at: lastAt, src: isNew ? 'manual' : 'cgm', type: 'RBS' });
  R.sort((a, b) => a.at - b.at);

  // Glucose before and 2 hours after each meal, from the same glucose curve as the readings
  const near = ts => { const x = R.filter(r => Math.abs(r.at - ts) <= 1800).sort((a, b) => Math.abs(a.at - ts) - Math.abs(b.at - ts))[0]; return x ? x.v : Math.round(glu(ts)); };
  for (const m of meals) {
    m.before = near(m.at);
    m.after = m.id === 'ex-l' ? 280 : m.at + 7200 <= lastAt ? near(m.at + 7200) : null;
    m.imp = m.after === null ? null : impactOf(m.after - m.before);
    m.src = isNew ? 'manual' : 'cgm';
  }
  meals.sort((a, b) => b.at - a.at);

  // ===== Messages, instructions, requests and reminders (phase events) =====
  const ins = {
    ok: [[L('Good control. Continue basal insulin 14 units at bedtime and metformin 1000 mg twice daily.', 'سيطرة جيدة. استمر على الإنسولين القاعدي 14 وحدة قبل النوم والميتفورمين 1000 ملغ مرتين يومياً.'), at(-3, 10)],
      [L('Keep checking your fasting glucose every morning.', 'استمر في قياس السكر الصائم كل صباح.'), at(-12, 9)]],
    ctrl: [[L('Increase basal insulin from 14 to 16 units at bedtime and send me your fasting readings for 3 days.', 'ارفع الإنسولين القاعدي من 14 إلى 16 وحدة قبل النوم وأرسل لي قراءات الصيام لمدة 3 أيام.'), at(-2, 10.5)],
      [L('Reduce rice and bread portions at lunch and walk 20 minutes after meals.', 'قلل كمية الأرز والخبز في الغداء وامشِ 20 دقيقة بعد الوجبات.'), at(-9, 11)]],
    crit: [[L('Urgent: recheck glucose manually and test ketones. If above 300 with vomiting or drowsiness, go to the emergency department.', 'عاجل: أعد قياس السكر يدوياً وافحص الكيتونات. إذا كان فوق 300 مع تقيؤ أو نعاس شديد توجه إلى الطوارئ.'), lastAt + 1200],
      [L('After the night-time low, reduce bedtime insulin to 12 units and always carry 15 g of fast-acting sugar.', 'بعد الهبوط الليلي، خفّض إنسولين النوم إلى 12 وحدة واحمل دائماً 15 غ من السكر سريع المفعول.'), at(-3, 9.5)]],
    new: [],
  };
  const chat = {
    ok: [['patient', L('Good morning doctor, my fasting reading was 112 today and I feel fine.', 'صباح الخير دكتورة، قراءة الصيام اليوم 112 وأشعر أنني بخير.'), at(-1, 8.5)],
      ['doctor', L('Excellent. Your readings are in range most of the time. Keep the same doses and routine.', 'ممتاز. قراءاتك ضمن النطاق معظم الوقت. استمر على نفس الجرعات والروتين.'), at(-1, 9)]],
    ctrl: [['doctor', L('Your readings after lunch are often above 200. How are your meals?', 'قراءاتك بعد الغداء غالباً فوق 200. كيف هي وجباتك؟'), at(-2, 12)],
      ['patient', L('I have been eating rice and bread at lunch. My fasting is around 160.', 'كنت آكل أرزاً وخبزاً في الغداء. قراءة الصيام حوالي 160.'), at(-2, 13)],
      ['doctor', L('Reduce the portions and take 16 units at bedtime, as we agreed at the clinic.', 'قلل الكميات وخذ 16 وحدة قبل النوم كما اتفقنا في العيادة.'), at(-2, 13.5)],
      ['patient', L('OK doctor. My latest sensor reading is 204.', 'حاضر دكتورة. آخر قراءة من الحساس 204.'), lastAt + 600]],
    crit: [['patient', L('Doctor, my sensor shows 318 and I feel very thirsty and tired.', 'دكتورة، الحساس يظهر 318 وأشعر بعطش شديد وتعب.'), lastAt + 300],
      ['doctor', L('Please recheck manually now, test ketones if you have strips, and drink water. Do not skip your insulin.', 'أعد القياس يدوياً الآن، وافحص الكيتونات إن توفرت الشرائط، واشرب الماء. لا تترك جرعة الإنسولين.'), lastAt + 900],
      ['patient', L('The manual reading is 305. Two nights ago I also had a low.', 'القراءة اليدوية 305. وقبل ليلتين انخفض السكر أيضاً.'), lastAt + 1800]],
    new: [['patient', L('Hello doctor, I registered in the app and linked my account to your clinic. When can I come for my first visit?', 'مرحباً دكتورة، سجلت في التطبيق وربطت حسابي بعيادتك. متى يمكنني الحضور لأول زيارة؟'), at(-1, 18)]],
  };
  const req = {
    ctrl: [['rq-ctrl', at(-1, 12), 'follow_up', false, L('Asks to bring the follow-up visit earlier.', 'يطلب تقديم موعد المتابعة.')]],
    crit: [['rq-crit', lastAt + 2100, 'urgent', true, L('Asks for the earliest clinic appointment: feeling unwell with high readings.', 'يطلب أقرب موعد في العيادة: يشعر بتوعك مع قراءات مرتفعة.')]],
    new: [['rq-new', at(-1, 18), 'initial', false, L('Requests the first clinic appointment after registering.', 'يطلب أول موعد في العيادة بعد التسجيل.')]],
  };
  // Glucose check reminders: [type, title, time, repeat, source, status]. Medication and visit reminders
  // come from the prescriptions and the planned follow-up (data/api.js)
  const rem = {
    ok: [['glu', L('Fasting glucose check', 'قياس السكر الصائم'), at(1, 7), 'daily', 'system', 'up']],
    ctrl: [['glu', L('Fasting glucose check, send results', 'قياس السكر الصائم وإرسال النتيجة'), at(1, 7), 'daily', 'doctor', 'up'],
      ['glu', L('Glucose check 2 hours after lunch', 'قياس السكر بعد الغداء بساعتين'), at(-1, 15), 'daily', 'system', 'missed']],
    crit: [['glu', L('Check glucose every 2 hours', 'قياس السكر كل ساعتين'), now + 3600, 'daily', 'doctor', 'up'],
      ['glu', L('Recheck after critical reading', 'إعادة القياس بعد القراءة الحرجة'), at(-1, 15), 'once', 'system', 'done']],
    new: [['glu', L('Fasting glucose check', 'قياس السكر الصائم'), at(1, 7), 'daily', 'system', 'up']],
  };
  // Times relative to now (lastAt + …) are already in the last phase; the others move with their phase
  const place = (k, ts) => (ts > at(-1, 23.99) && k === final ? ts : ev(k, ts));
  const insOut = [], chatOut = [], reqOut = [], remOut = [];
  for (const k of keys) {
    for (const [text, ts] of ins[k]) { const t = place(k, ts); if (t !== null && t <= now) insOut.push([text, t]); }
    for (const [who, text, ts] of chat[k]) { const t = place(k, ts); if (t !== null && t <= now) chatOut.push([who, text, t]); }
    for (const [id, ts, kind, urgent, note] of req[k] ?? []) { const t = place(k, ts); if (t !== null && t <= now) reqOut.push({ id, at: t, kind, urgent, note }); }
    rem[k].forEach((x, i) => { const t = x[2] > now ? (k === final ? x[2] : null) : ev(k, x[2]);
      if (t !== null) remOut.push({ id: `s${k}${i}`, pid: 1, type: x[0], title: x[1], at: t, rep: x[3], src: x[4], st: x[5] }); });
  }
  chatOut.sort((a, b) => a[2] - b[2]);
  insOut.sort((a, b) => b[1] - a[1]);

  return { patients, readings: { 1: R }, meals: { 1: meals }, consultations: { 1: C }, doses: { 1: doses },
    requests: { 1: reqOut }, ins: { 1: insOut }, chat: { 1: chatOut }, reminders: remOut };
}
