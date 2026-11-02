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

/** Electron concentration in conduction band */
export function electronConcentration(Eg: number, Ef: number, T: number, Nd: number): number {
  const ni = intrinsicConcentration(Eg, T);
  if (T <= 0) return Nd;
  // Approximate: n = Nd + ni²/Nd for n-type, or ni for intrinsic
  if (Nd > ni * 100) return Nd;
  return Math.sqrt(ni * ni / 4 + Nd * Nd) + ni * ni / (2 * Nd || ni);
}

/** Hole concentration in valence band */
export function holeConcentration(Eg: number, Ef: number, T: number, Na: number): number {
  const ni = intrinsicConcentration(Eg, T);
  if (T <= 0) return Na;
  if (Na > ni * 100) return Na;
  return Math.sqrt(ni * ni / 4 + Na * Na) + ni * ni / (2 * Na || ni);
}

/** Fermi level position for doped semiconductor (approximate) */
export function dopedFermiLevel(Eg: number, T: number, dopingType: DopingType, conc: number): number {
  if (dopingType === 'intrinsic') return Eg / 2;
  const ni = intrinsicConcentration(Eg, T);
  const kT = KB_EV * T;
  if (dopingType === 'n-type') {
    // Ef = Ec - kT ln(Nc/Nd)
    const nc = NC_300 * Math.pow(T / 300, 1.5);
    return Eg - kT * Math.log(nc / conc);
  } else {
    // Ef = Ev + kT ln(Nv/Na)
    const nv = NV_300 * Math.pow(T / 300, 1.5);
    return kT * Math.log(nv / conc);
  }
}

/** Generate carriers for visualization */
export function generateCarriers(
  material: Material,
  T: number,
  dopingType: DopingType,
  dopingConc: number, // actual cm^-3
  count: number = 80
): Carrier[] {
  const carriers: Carrier[] = [];
  const Eg = material.bandGap;
  const isConductor = material.type === 'conductor';

  // For conductors, all electrons are free (no gap)
  if (isConductor) {
    for (let i = 0; i < count; i++) {
      carriers.push({
        x: Math.random() * 60,
        y: -0.2 - Math.random() * 0.8, // in conduction band region
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 0.5,
        band: 'conduction',
        type: 'electron',
        energy: material.fermiLevel + Math.random() * 2,
      });
    }
    return carriers;
  }

  const Ef = dopedFermiLevel(Eg, T, dopingType, dopingConc);
  const kT = KB_EV * T;

  // Valence band electrons (filled states)
  const valenceCount = Math.floor(count * 0.7);
  for (let i = 0; i < valenceCount; i++) {
    const E = -Math.random() * 1.5; // below valence band top (0)
    const occupied = 1 - fermiDirac(E, Ef, T); // hole probability = 1 - f(E)
    if (occupied > 0.3) {
      carriers.push({
        x: Math.random() * 60,
        y: E * 0.3, // scale for visual
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.2,
        band: 'valence',
        type: 'electron',
        energy: E,
      });
    }
    // Holes appear where electrons are missing
    if (occupied < 0.7) {
      carriers.push({
        x: Math.random() * 60,
        y: E * 0.3,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.2,
        band: 'valence',
        type: 'hole',
        energy: E,
      });
    }
  }

  // Conduction band electrons (thermally excited + doped)
  const ni = intrinsicConcentration(Eg, T);
  const nConc = dopingType === 'n-type' ? Math.max(dopingConc, ni) : ni;
  const excitationFrac = Math.min(0.5, nConc / 1e18);
  const condCount = Math.max(1, Math.floor(count * excitationFrac * 10));

  for (let i = 0; i < condCount; i++) {
    const E = Eg + Math.random() * 1.0;
    carriers.push({
      x: Math.random() * 60,
      y: Eg + Math.random() * 0.5,
      vx: (Math.random() - 0.5) * 3,
      vy: (Math.random() - 0.5) * 0.5,
      band: 'conduction',
      type: 'electron',
      energy: E,
    });
  }

  // Donor/acceptor ions visualization
  if (dopingType === 'n-type' && T > 50) {
    const donorCount = Math.min(15, Math.floor(dopingConc / 1e16));
    for (let i = 0; i < donorCount; i++) {
      carriers.push({
        x: Math.random() * 60,
        y: Eg - 0.05,
        vx: 0, vy: 0,
        band: 'conduction',
        type: 'electron',
        energy: Eg - 0.05,
      });
    }
  }

  return carriers;
}

/** Update carrier positions with thermal motion */
export function updateCarriers(carriers: Carrier[], dt: number, T: number, speed: number): Carrier[] {
  const thermalV = Math.sqrt(T / 300) * speed;
  return carriers.map((c) => ({
    ...c,
    x: (c.x + c.vx * dt * thermalV * 20 + 60) % 60,
    y: c.y + c.vy * dt * thermalV * 2,
    vx: c.vx + (Math.random() - 0.5) * dt * thermalV * 5,
    vy: c.vy + (Math.random() - 0.5) * dt * thermalV * 2,
  }));
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