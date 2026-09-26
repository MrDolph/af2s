// src/lib/physics/pnJunction.ts
// PN Junction Physics Engine — Depletion, rectification, AC/DC conversion

export interface MaterialParams {
  Na: number;
  Nd: number;
  temperature: number;
  appliedBias: number;
  material: 'Si' | 'Ge' | 'GaAs';
  circuitMode: 'diode' | 'half-wave' | 'full-wave';
  Vin: number;
  Rload: number;
  freq: number;
}

export interface JunctionState {
  Vbi: number;
  Wp: number;
  Wn: number;
  Wtotal: number;
  Emax: number;
  currentDensity: number;
  electronConcP: number;
  holeConcN: number;
  fermiLevelP: number;
  fermiLevelN: number;
  Id: number;
  Vd: number;
  Pout: number;
  efficiency: number;
  ripple: number;
  Vdc: number;
}

const MATERIAL_PROPS: Record<string, { Eg: number; ni: number; er: number }> = {
  Si:   { Eg: 1.12, ni: 1.5e10,  er: 11.7 },
  Ge:   { Eg: 0.67, ni: 2.4e13,  er: 16.0 },
  GaAs: { Eg: 1.42, ni: 1.8e6,   er: 12.9 },
};

const kB = 8.617e-5;
const q = 1.602e-19;
const eps0 = 8.854e-14;

export function computeJunctionState(params: MaterialParams): JunctionState {
  const { Na, Nd, temperature, appliedBias, material, circuitMode, Vin, Rload } = params;
  const props = MATERIAL_PROPS[material];
  const { Eg, ni, er } = props;
  
  const VT = kB * temperature;
  const Vbi = VT * Math.log((Na * Nd) / (ni * ni));
  const Veff = Math.max(Vbi + appliedBias, 0.01);
  
  const eps = eps0 * er;
  const Wtotal = Math.sqrt((2 * eps * Veff / q) * (1/Na + 1/Nd)) * 1e7;
  const Wp = Wtotal * (Nd / (Na + Nd));
  const Wn = Wtotal * (Na / (Na + Nd));
  const Emax = (2 * Veff) / (Wtotal * 1e-7);
  
  const electronConcP = (ni * ni) / Na;
  const holeConcN = (ni * ni) / Nd;
  
  const Dn = 25, Dp = 10;
  const Ln = Math.sqrt(Dn * 1e-3);
  const Lp = Math.sqrt(Dp * 1e-3);
  const Js = q * ((Dn * electronConcP / Ln) + (Dp * holeConcN / Lp));
  const currentDensity = Js * (Math.exp(appliedBias / VT) - 1);
  
  const fermiLevelP = -VT * Math.log(Na / ni);
  const fermiLevelN = VT * Math.log(Nd / ni);
  
  const Is = 1e-12;
  const Vd = appliedBias > 0 ? Math.min(appliedBias, 0.85) : appliedBias;
  const Id = appliedBias > 0 
    ? Is * (Math.exp(Vd / VT) - 1) * 1000 
    : -Is * 1000;
  
  let Pout = 0, efficiency = 0, ripple = 0, Vdc = 0;
  if (circuitMode === 'half-wave') {
    Vdc = (Vin - 0.7) / Math.PI;
    Pout = (Vdc * Vdc) / Rload * 1000;
    efficiency = 40.6;
    ripple = 121;
  } else if (circuitMode === 'full-wave') {
    Vdc = 2 * (Vin - 0.7) / Math.PI;
    Pout = (Vdc * Vdc) / Rload * 1000;
    efficiency = 81.2;
    ripple = 48.2;
  } else {
    Vdc = appliedBias;
    Pout = Math.abs(Id * Vd);
  }
  
  return {
    Vbi, Wp, Wn, Wtotal, Emax, currentDensity,
    electronConcP, holeConcN, fermiLevelP, fermiLevelN,
    Id, Vd, Pout, efficiency, ripple, Vdc,
  };
}

export function getPreset(name: string): MaterialParams {
  const presets: Record<string, MaterialParams> = {
    equilibrium:   { Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0, material: 'Si', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
    'forward-bias':{ Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0.7, material: 'Si', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
    'reverse-bias':{ Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: -5, material: 'Si', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
    'half-wave':   { Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0, material: 'Si', circuitMode: 'half-wave', Vin: 10, Rload: 1000, freq: 50 },
    'full-wave':   { Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0, material: 'Si', circuitMode: 'full-wave', Vin: 10, Rload: 1000, freq: 50 },
    'heavy-doping':{ Na: 1e18, Nd: 1e18, temperature: 300, appliedBias: 0, material: 'Si', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
    germanium:     { Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0, material: 'Ge', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
    gaas:          { Na: 1e16, Nd: 1e16, temperature: 300, appliedBias: 0, material: 'GaAs', circuitMode: 'diode', Vin: 5, Rload: 1000, freq: 50 },
  };
  return presets[name] || presets.equilibrium;
}

export const PRESET_NAMES = [
  'equilibrium', 'forward-bias', 'reverse-bias', 'half-wave',
  'full-wave', 'heavy-doping', 'germanium', 'gaas',
];

export const PRESET_LABELS: Record<string, string> = {
  equilibrium: 'Equilibrium (No Bias)',
  'forward-bias': 'Forward Bias (+0.7V)',
  'reverse-bias': 'Reverse Bias (-5V)',
  'half-wave': 'Half-Wave Rectifier',
  'full-wave': 'Full-Wave Bridge Rectifier',
  'heavy-doping': 'Heavy Doping (10¹⁸ cm⁻³)',
  germanium: 'Germanium Junction',
  gaas: 'GaAs Junction',
};