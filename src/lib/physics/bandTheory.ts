// ═══════════════════════════════════════════════════════════════════════════
// Energy Band Theory Physics Engine
// ═══════════════════════════════════════════════════════════════════════════

export type MaterialType = 'insulator' | 'semiconductor' | 'conductor';
export type DopingType = 'intrinsic' | 'n-type' | 'p-type';

export interface Material {
  name: string;
  symbol: string;
  bandGap: number;      // eV
  type: MaterialType;
  fermiLevel: number;   // eV (relative to valence band top = 0)
  color: string;
  latticeConstant: number; // Å
}

export interface BandTheoryParams {
  material: string;
  temperature: number;  // K
  dopingType: DopingType;
  dopingConcentration: number; // log10(cm^-3), 10-20
  showElectrons: boolean;
  showHoles: boolean;
  showFermiLevel: boolean;
  showBandGap: boolean;
  showThermalEnergy: boolean;
  showDOS: boolean;
  animateCarriers: boolean;
  speed: number;
  zoom: number;
}

export interface Carrier {
  x: number;
  y: number;
  vx: number;
  vy: number;
  band: 'valence' | 'conduction';
  type: 'electron' | 'hole';
  energy: number;
}

export interface BandTheoryStats {
  bandGap: number;
  temperature: number;
  kT: number;
  fermiLevel: number;
  intrinsicConc: number;
  electronConc: number;
  holeConc: number;
  conductivity: string;
}

export const MATERIALS: Record<string, Material> = {
  diamond: { name: 'Diamond (C)', symbol: 'C', bandGap: 5.5, type: 'insulator', fermiLevel: 2.75, color: '#94a3b8', latticeConstant: 3.57 },
  silicon: { name: 'Silicon (Si)', symbol: 'Si', bandGap: 1.12, type: 'semiconductor', fermiLevel: 0.56, color: '#64748b', latticeConstant: 5.43 },
  germanium: { name: 'Germanium (Ge)', symbol: 'Ge', bandGap: 0.67, type: 'semiconductor', fermiLevel: 0.335, color: '#71717a', latticeConstant: 5.66 },
  gaas: { name: 'Gallium Arsenide', symbol: 'GaAs', bandGap: 1.42, type: 'semiconductor', fermiLevel: 0.71, color: '#52525b', latticeConstant: 5.65 },
  copper: { name: 'Copper (Cu)', symbol: 'Cu', bandGap: 0, type: 'conductor', fermiLevel: 7.0, color: '#b45309', latticeConstant: 3.61 },
  sodium: { name: 'Sodium (Na)', symbol: 'Na', bandGap: 0, type: 'conductor', fermiLevel: 3.2, color: '#78716c', latticeConstant: 4.29 },
};

// Boltzmann constant in eV/K
const KB_EV = 8.617e-5;
// Effective density of states (cm^-3) at 300K
const NC_300 = 2.8e19;
const NV_300 = 1.04e19;

export function kT_eV(T: number): number {
  return KB_EV * T;
}

/** Fermi-Dirac distribution f(E) = 1 / (exp((E-Ef)/kT) + 1) */
export function fermiDirac(E: number, Ef: number, T: number): number {
  if (T <= 0) return E < Ef ? 1 : E > Ef ? 0 : 0.5;
  const arg = (E - Ef) / (KB_EV * T);
  // Clamp to avoid overflow
  if (arg > 40) return 0;
  if (arg < -40) return 1;
  return 1 / (1 + Math.exp(arg));
}

/** Intrinsic carrier concentration ni = sqrt(Nc*Nv) * exp(-Eg/2kT) */
export function intrinsicConcentration(Eg: number, T: number): number {
  if (T <= 0) return 0;
  const nc = NC_300 * Math.pow(T / 300, 1.5);
  const nv = NV_300 * Math.pow(T / 300, 1.5);
  return Math.sqrt(nc * nv) * Math.exp(-Eg / (2 * KB_EV * T));
}

/** Non-degenerate, fully ionised-dopant teaching approximation.
 * Low-temperature freeze-out and degenerate doping need a fuller model.
 */
export function carrierConcentrations(Eg: number, T: number, doping: DopingType, conc: number) {
  const ni = intrinsicConcentration(Eg, T);
  if (T <= 0) return { n: 0, p: 0, ni: 0 };
  const dop = doping === 'intrinsic' ? 0 : Math.max(0, conc);
  const majority = (dop + Math.hypot(dop, 2 * ni)) / 2;
  const minority = majority > 0 ? ni * ni / majority : 0;
  return doping === 'p-type' ? { n: minority, p: majority, ni } : { n: majority, p: minority, ni };
}
export function electronConcentration(Eg: number, Ef: number, T: number, Nd: number) {
  return carrierConcentrations(Eg, T, 'n-type', Nd).n;
}
export function holeConcentration(Eg: number, Ef: number, T: number, Na: number) {
  return carrierConcentrations(Eg, T, 'p-type', Na).p;
}
export function dopedFermiLevel(Eg: number, T: number, doping: DopingType, conc: number) {
  if (T <= 0) return Eg / 2;
  const { n } = carrierConcentrations(Eg, T, doping, conc);
  const nc = NC_300 * Math.pow(T / 300, 1.5);
  return n > 0 ? Eg + kT_eV(T) * Math.log(n / nc) : Eg / 2;
}
/** Sampled states, with carrier counts amplified logarithmically for visibility. */
export function generateCarriers(material: Material, T: number, doping: DopingType, conc: number, count = 80): Carrier[] {
  const result: Carrier[] = [];
  function add(type: 'electron' | 'hole', band: 'valence' | 'conduction', energy: number) {
    result.push({x: Math.random()*60, y: energy, energy, vx: (Math.random()-.5)*2, vy: 0, band, type});
  }
  if (material.type === 'conductor') {
    for (let i=0;i<count;i++) add('electron','conduction', Math.random()*material.fermiLevel);
    return result;
  }
  const { n, p } = carrierConcentrations(material.bandGap,T,doping,conc);
  const sampleCount = (c: number) => c < 1 ? 0 : Math.min(40, Math.max(1, Math.round(Math.log10(c)*2)));
  // A filled valence band contains electrons, not holes. Missing states are hollow.
  for(let i=0;i<Math.floor(count*.7);i++) add('electron','valence',-0.05-Math.random()*1.8);
  for(let i=0;i<sampleCount(n);i++) add('electron','conduction',material.bandGap + Math.min(1.8,-Math.log(Math.max(Math.random(),1e-8))*kT_eV(T)));
  for(let i=0;i<sampleCount(p);i++) add('hole','valence',-Math.min(1.8,0.03-Math.log(Math.max(Math.random(),1e-8))*kT_eV(T)));
  return result;
}
/** Thermal motion of conduction electrons; energies stay in their allowed band.
 * Hollow markers denote sampled vacancies, rather than independent particles.
 */
export function updateCarriers(carriers: Carrier[], dt: number, T: number, speed: number): Carrier[] {
  const v = Math.sqrt(Math.max(0,T)/300)*speed;
  return carriers.map(c => c.type === 'electron' && c.band === 'conduction'
    ? {...c,x:(c.x+c.vx*dt*v*20+60)%60} : c);
}

export interface BandTheoryPreset {
  name: string;
  description: string;
  params: Partial<BandTheoryParams>;
}

export const BAND_PRESETS: BandTheoryPreset[] = [
  {
    name: 'Diamond — Insulator',
    description: 'Eg = 5.5 eV. At room temperature, virtually zero electrons in conduction band.',
    params: { material: 'diamond', temperature: 300, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showHoles: true, showFermiLevel: true, showBandGap: true },
  },
  {
    name: 'Silicon — Intrinsic',
    description: 'Eg = 1.12 eV. ni ≈ 1.5×10¹⁰ cm⁻³ at 300 K. Fermi level near mid-gap.',
    params: { material: 'silicon', temperature: 300, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showHoles: true, showFermiLevel: true, showBandGap: true },
  },
  {
    name: 'Silicon — Heated',
    description: 'At 600 K, thermal energy kT ≈ 0.052 eV. Many electrons excited across gap.',
    params: { material: 'silicon', temperature: 600, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showHoles: true, showFermiLevel: true, showThermalEnergy: true },
  },
  {
    name: 'Silicon — n-type Doped',
    description: 'Phosphorus donors at 10¹⁶ cm⁻³. Fermi level shifts toward conduction band.',
    params: { material: 'silicon', temperature: 300, dopingType: 'n-type', dopingConcentration: 16, showElectrons: true, showHoles: true, showFermiLevel: true, showBandGap: true },
  },
  {
    name: 'Silicon — p-type Doped',
    description: 'Boron acceptors at 10¹⁶ cm⁻³. Fermi level shifts toward valence band.',
    params: { material: 'silicon', temperature: 300, dopingType: 'p-type', dopingConcentration: 16, showElectrons: true, showHoles: true, showFermiLevel: true, showBandGap: true },
  },
  {
    name: 'Germanium — Smaller Gap',
    description: 'Eg = 0.67 eV. Higher intrinsic carrier concentration than Si at same T.',
    params: { material: 'germanium', temperature: 300, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showHoles: true, showFermiLevel: true },
  },
  {
    name: 'GaAs — Direct Gap',
    description: 'Eg = 1.42 eV. Direct bandgap = efficient photon emission for LEDs/lasers.',
    params: { material: 'gaas', temperature: 300, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showHoles: true, showFermiLevel: true, showBandGap: true },
  },
  {
    name: 'Copper — Conductor',
    description: 'No band gap. Valence and conduction bands overlap. Electrons are always free.',
    params: { material: 'copper', temperature: 300, dopingType: 'intrinsic', dopingConcentration: 10, showElectrons: true, showFermiLevel: true, showBandGap: false },
  },
];

export function materialTypeLabel(type: MaterialType): string {
  return type === 'insulator' ? 'Insulator' : type === 'semiconductor' ? 'Semiconductor' : 'Conductor';
}

export function getConductivityDescription(mat: Material, T: number, doping: DopingType, conc: number): string {
  if (mat.type === 'conductor') return 'Very high — free electrons always available';
  if (mat.type === 'insulator') return T > 1000 ? 'Slightly conductive at high T' : 'Essentially zero';
  const ni = intrinsicConcentration(mat.bandGap, T);
  const dop = Math.pow(10, conc);
  const total = doping === 'intrinsic' ? ni : dop;
  if (total > 1e17) return 'High — degenerately doped';
  if (total > 1e14) return 'Moderate — extrinsic conduction';
  if (total > 1e10) return 'Low — intrinsic conduction';
  return 'Very low — freeze-out regime';
}