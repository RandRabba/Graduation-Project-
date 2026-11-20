// Clinical record vocabulary used by the consultation form and its display. Pure data, no DOM.
export const CONS_KINDS = ['initial', 'follow_up', 'urgent'];
// The initial consultation is always face-to-face at the clinic; follow-ups can also be by phone or video
export const CONS_MODES = ['in_person', 'phone', 'video'];
export const CONDITIONS = ['hypertension', 'dyslipidemia', 'obesity', 'ckd', 'retinopathy', 'neuropathy', 'cvd', 'nafld', 'hypothyroidism'];
// Laboratory tests and their units
export const LABS = { hba1c: '%', fpg: 'mg/dL', egfr: 'mL/min/1.73m²', creat: 'mg/dL', uacr: 'mg/g', ldl: 'mg/dL', tg: 'mg/dL', ketones: 'mmol/L', alt: 'U/L', tsh: 'mIU/L' };
export const bmi = (w, hcm) => (w > 0 && hcm > 0 ? Math.round(w / ((hcm / 100) ** 2) * 10) / 10 : null);
