// src/lib/physics/bjtTransistor.ts
// BJT Physics Engine — Circuit topologies, load lines, gain analysis

export type BjtTopology = 'common-emitter' | 'common-collector' | 'common-base';

export interface BjtParams {
  Vbe: number;
  Vce: number;
  temperature: number;
  material: 'Si' | 'Ge';
  beta: number;
  topology: BjtTopology;
  Vcc: number;
  Rb: number;
  Rc: number;
  Re: number;
  Rload: number;
}

export interface BjtState {
  region: 'cutoff' | 'active' | 'saturation';
  Ib: number;
  Ic: number;
  Ie: number;
  Vbc: number;
  alpha: number;
  VT: number;
  Vb: number;
  Ve: number;
  Vc: number;
  Av: number;
  Ai: number;
  Ap: number;
  Zin: number;
  Zout: number;
  Pdiss: number;
  Ic_sat: number;
  Vce_cutoff: number;
}

const kB = 8.617e-5;

export function computeBjtState(params: BjtParams): BjtState {
  const { Vbe, Vce, temperature, material, beta, topology, Vcc, Rb, Rc, Re, Rload } = params;
  const VT = kB * temperature;
  const alpha = beta / (beta + 1);
  const Vbc = Vbe - Vce;
  
  let region: 'cutoff' | 'active' | 'saturation';
  if (Vbe < (material === 'Si' ? 0.5 : 0.2)) {
    region = 'cutoff';
  } else if (Vbc < 0.3) {
    region = 'active';
  } else {
    region = 'saturation';
  }
  
  const Is = 1e-15;
  let Ib = 0, Ic = 0, Ie = 0;
  
  if (region === 'cutoff') {
    Ib = 0; Ic = 0; Ie = 0;
  } else if (region === 'active') {
    Ib = (Vcc - Vbe) / (Rb + (beta + 1) * Re);
    if (Ib < 0) Ib = 0;
    Ic = beta * Ib;
    Ie = (beta + 1) * Ib;
  } else {
    const Vcesat = 0.2;
    Ic = (Vcc - Vcesat) / (Rc + Re);
    Ib = Ic / beta * 2;
    Ie = Ic + Ib;
  }
  
  const Ve = Ie * Re;
  const Vb = Ve + Vbe;
  const Vc = Vcc - Ic * Rc;
  
  let Av = 0, Ai = 0, Zin = 0, Zout = 0;
  const gm = Ic / VT;
  const rpi = beta / gm;
  
  if (topology === 'common-emitter') {
    const Rl_eff = (Rc * Rload) / (Rc + Rload);
    Av = -gm * Rl_eff;
    Ai = beta * (Rc / (Rc + Rload));
    Zin = 1 / (1/rpi + 1/Rb);
    Zout = Rc;
  } else if (topology === 'common-collector') {
    const Re_eff = (Re * Rload) / (Re + Rload);
    Av = (gm * Re_eff) / (1 + gm * Re_eff);
    Ai = (beta + 1) * (Re / (Re + Rload));
    Zin = Rb;
    Zout = 1 / gm;
  } else if (topology === 'common-base') {
    const Rl_eff = (Rc * Rload) / (Rc + Rload);
    Av = gm * Rl_eff;
    Ai = alpha * (Rc / (Rc + Rload));
    Zin = 1 / gm;
    Zout = Rc;
  }
  
  const Ap = 10 * Math.log10(Math.abs(Av * Ai));
  const Pdiss = Ic * Vce;
  const Ic_sat = Vcc / (Rc + Re);
  const Vce_cutoff = Vcc;
  
  return {
    region, Ib: Ib * 1000, Ic, Ie, Vbc, alpha, VT,
    Vb, Ve, Vc, Av, Ai, Ap, Zin, Zout, Pdiss,
    Ic_sat, Vce_cutoff,
  };
}

export function getPreset(name: string): BjtParams {
  const presets: Record<string, BjtParams> = {
    'ce-cutoff':       { Vbe: 0.0,  Vce: 5.0,  temperature: 300, material: 'Si', beta: 100, topology: 'common-emitter', Vcc: 10, Rb: 100, Rc: 2, Re: 0.5, Rload: 10 },
    'ce-active':       { Vbe: 0.7,  Vce: 5.0,  temperature: 300, material: 'Si', beta: 100, topology: 'common-emitter', Vcc: 10, Rb: 100, Rc: 2, Re: 0.5, Rload: 10 },
    'ce-saturation':   { Vbe: 0.85, Vce: 0.2,  temperature: 300, material: 'Si', beta: 100, topology: 'common-emitter', Vcc: 10, Rb: 10,  Rc: 2, Re: 0.5, Rload: 10 },
    'cc-emitter-follower': { Vbe: 0.7, Vce: 5.0, temperature: 300, material: 'Si', beta: 100, topology: 'common-collector', Vcc: 10, Rb: 100, Rc: 0.1, Re: 2, Rload: 10 },
    'cb-active':       { Vbe: 0.7,  Vce: 5.0,  temperature: 300, material: 'Si', beta: 100, topology: 'common-base', Vcc: 10, Rb: 10,  Rc: 2, Re: 0.5, Rload: 10 },
    'germanium-ce':    { Vbe: 0.3,  Vce: 5.0,  temperature: 300, material: 'Ge', beta: 80,  topology: 'common-emitter', Vcc: 10, Rb: 100, Rc: 2, Re: 0.5, Rload: 10 },
    'high-beta-ce':    { Vbe: 0.7,  Vce: 5.0,  temperature: 300, material: 'Si', beta: 300, topology: 'common-emitter', Vcc: 10, Rb: 300, Rc: 2, Re: 0.5, Rload: 10 },
    'high-temp-ce':    { Vbe: 0.7,  Vce: 5.0,  temperature: 400, material: 'Si', beta: 100, topology: 'common-emitter', Vcc: 10, Rb: 100, Rc: 2, Re: 0.5, Rload: 10 },
  };
  return presets[name] || presets['ce-cutoff'];
}

export const PRESET_NAMES = [
  'ce-cutoff', 'ce-active', 'ce-saturation',
  'cc-emitter-follower', 'cb-active',
  'germanium-ce', 'high-beta-ce', 'high-temp-ce',
];

export const PRESET_LABELS: Record<string, string> = {
  'ce-cutoff': 'CE — Cutoff',
  'ce-active': 'CE — Active (Amplifier)',
  'ce-saturation': 'CE — Saturation',
  'cc-emitter-follower': 'CC — Emitter Follower',
  'cb-active': 'CB — Active',
  'germanium-ce': 'Ge — Common Emitter',
  'high-beta-ce': 'High β CE (β=300)',
  'high-temp-ce': 'High Temp CE (400K)',
};

export const REGION_COLORS: Record<string, string> = {
  cutoff: '#94a3b8', active: '#4ade80', saturation: '#f87171',
};

export const REGION_DESCRIPTIONS: Record<string, string> = {
  cutoff: 'Both junctions reverse biased. No carrier injection. Transistor is OFF. Ic ≈ 0.',
  active: 'EB forward, CB reverse. Base current controls collector current: Ic = β·Ib. Used for voltage amplification.',
  saturation: 'Both junctions forward biased. Vce ≈ 0.2V. Transistor is fully ON — acts as closed switch.',
};

export const TOPOLOGY_DESCRIPTIONS: Record<string, string> = {
  'common-emitter': 'Voltage gain: high. Current gain: β. Input Z: moderate. Output Z: high. Phase: 180°. Most common amplifier.',
  'common-collector': 'Voltage gain: ≈1. Current gain: β+1. Input Z: high. Output Z: low. Phase: 0°. Used as buffer/impedance matcher.',
  'common-base': 'Voltage gain: high. Current gain: ≈1. Input Z: very low. Output Z: high. Phase: 0°. Used in RF amplifiers.',
};