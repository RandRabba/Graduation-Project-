// Monitoring protocols by diabetes type. CONFIGURABLE DEFAULTS, NOT CLINICALLY APPROVED.
//
// Every protocol below must be reviewed and signed off by the responsible clinical team before real use
// (`reviewed: false` makes the dashboard say so wherever a protocol is shown). When the backend exists it
// should serve the approved protocols (GET /protocols) and this file becomes only the offline fallback.
//
// A protocol sets the default targets and the evaluation rules for a diabetes type. At a consultation the
// doctor picks the protocol and can individualize the targets; the individualized targets always win.
// Sources for the default numbers: international consensus on CGM time in range (Battelino et al.,
// Diabetes Care 2019) and the ADA Standards of Care.
import { DEFAULT_TG } from './clinical.js';

export const PROTOCOLS = {
  't1-default': {
    id: 't1-default', type: 'Type 1', version: '0.1-draft', reviewed: false,
    targets: { ...DEFAULT_TG },
    rules: {
      aboveTargetAlerts: 'always',  // insulin is always part of Type 1 care
      ketoneFlagAbove: 250,         // flag for the clinician to consider ketone assessment
      hypoFlagBelow: 54,
      minAdherence: 90,
      fastingHigh: 130,     // ADA preprandial target 80–130 mg/dL
    },
  },
  't2-default': {
    id: 't2-default', type: 'Type 2', version: '0.1-draft', reviewed: false,
    targets: { ...DEFAULT_TG },
    rules: { aboveTargetAlerts: 'insulin', ketoneFlagAbove: null, hypoFlagBelow: 54, minAdherence: 80, fastingHigh: 130 },
  },
  // Older or high-risk adults (consensus): in range >50%, below 70 <1%, above 250 <10%
  't2-older': {
    id: 't2-older', type: 'Type 2', version: '0.1-draft', reviewed: false,
    targets: { ...DEFAULT_TG, tir: 50, tbr: 1, tar: 50, tar2: 10 },
    rules: { aboveTargetAlerts: 'insulin', ketoneFlagAbove: null, hypoFlagBelow: 54, minAdherence: 80, fastingHigh: 130 },
  },
};
export const DIABETES_TYPES = ['Type 1', 'Type 2'];
export const protocolsForType = type => Object.values(PROTOCOLS).filter(p => p.type === type);
export const defaultProtocolId = type => (type === 'Type 1' ? 't1-default' : 't2-default');

// Protocol of a patient: the one chosen at the latest consultation, otherwise the default for the type,
// otherwise the Type 2 default (before the initial consultation the type is not confirmed)
export function protocolOf(p) {
  return PROTOCOLS[p?.protocolId] ?? PROTOCOLS[defaultProtocolId(p?.type)];
}
// Targets in effect: protocol defaults, then the individualized targets from the latest consultation
export function effectiveTargets(protocol, individual) {
  const tg = { ...protocol.targets };
  for (const [k, v] of Object.entries(individual ?? {})) if (Number.isFinite(v)) tg[k] = v;
  return tg;
}
