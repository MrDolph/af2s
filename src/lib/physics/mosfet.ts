// ═══════════════════════════════════════════════════════════════════════════
// MOSFET Physics Engine — Circuit topologies, load lines, gain analysis
// ═══════════════════════════════════════════════════════════════════════════

export type MosfetTopology = 'common-source' | 'common-drain' | 'common-gate';
export type MosfetType = 'nmos' | 'pmos';
export type MosfetRegion = 'cutoff' | 'triode' | 'saturation';

export interface MosfetParams {
  Vgs: number;
  Vds: number;
  Vth: number;
  temperature: number;
  type: MosfetType;
  W: number;
  L: number;
  tox: number;
  topology: MosfetTopology;
  Vdd: number;
  Rd: number;
  Rs: number;
  Rg: number;
  Rload: number;
}

export interface MosfetState {
  region: MosfetRegion;
  Id: number;
  Vov: number;
  Vdsat: number;
  gm: number;
  Cox: number;
  mu: number;
  lambda: number;
  channelCharge: number;
  Vg: number;
  Vs: number;
  Vd: number;
  Av: number;
  Ai: number;
  Zin: number;
  Zout: number;
  Pdiss: number;
  Id_sat: number;
  Vds_cutoff: number;
}

const EPS_SIO2 = 3.9 * 8.854e-12;

export function computeMosfetState(params: MosfetParams): MosfetState {
  const { Vgs, Vds, Vth, temperature, type, W, L, tox, topology, Vdd, Rd, Rs, Rg, Rload } = params;

  const Cox = (EPS_SIO2 / (tox * 1e-9)) * 1e15;
  const mu = 600 * Math.pow(300 / temperature, 1.5);
  const Vov = type === 'nmos' ? Math.max(0, Vgs - Vth) : Math.max(0, Vth - Vgs);

  let region: MosfetRegion;
  if (Vov <= 0) {
    region = 'cutoff';
  } else if (Math.abs(Vds) < Vov) {
    region = 'triode';
  } else {
    region = 'saturation';
  }

  const lambda = 0.02 / L;
  const k = mu * Cox * 1e-6;

  let Id = 0;
  if (region === 'cutoff') {
    Id = 0;
  } else if (region === 'triode') {
    Id = k * (W / L) * (Vov * Math.abs(Vds) - Vds * Vds / 2) * 1e-3;
  } else {
    Id = 0.5 * k * (W / L) * Vov * Vov * (1 + lambda * Math.abs(Vds)) * 1e-3;
  }

  const gm = region === 'saturation'
    ? k * (W / L) * Vov * 1e-3
    : region === 'triode'
      ? k * (W / L) * Math.abs(Vds) * 1e-3
      : 0;

  const channelCharge = region === 'cutoff' ? 0 : Math.min(1, Vov / 2);

  const Vs = type === 'nmos' ? Id * Rs : Vdd - Id * Rs;
  const Vd = type === 'nmos' ? Vdd - Id * Rd : Id * Rd;
  const Vg = type === 'nmos' ? Vs + Vgs : Vs - Vgs;

  let Av = 0, Ai = 0, Zin = 0, Zout = 0;
  const ro = Id > 0 ? 1 / (lambda * Id) : 1e12;

  if (topology === 'common-source') {
    const Rl_eff = (Rd * Rload) / (Rd + Rload);
    const Rd_ro = (Rd * ro) / (Rd + ro);
    Av = -gm * Rl_eff;
    Ai = -gm * Rl_eff * (Rg / Rl_eff);
    Zin = Rg;
    Zout = Rd_ro;
  } else if (topology === 'common-drain') {
    const Rs_eff = (Rs * Rload) / (Rs + Rload);
    Av = (gm * Rs_eff) / (1 + gm * Rs_eff);
    Ai = (1 + gm * Rs_eff) * (Rs / (Rs + Rload));
    Zin = Rg;
    Zout = 1 / gm;
  } else if (topology === 'common-gate') {
    const Rl_eff = (Rd * Rload) / (Rd + Rload);
    Av = gm * Rl_eff;
    Ai = 1;
    Zin = 1 / gm;
    Zout = Rd;
  }

  const Pdiss = Id * Math.abs(Vds);
  const Id_sat = Vdd / (Rd + Rs);
  const Vds_cutoff = Vdd;

  return {
    region,
    Id: Math.abs(Id),
    Vov,
    Vdsat: Vov,
    gm: Math.abs(gm),
    Cox: Cox / 1e6,
    mu,
    lambda,
    channelCharge,
    Vg,
    Vs,
    Vd,
    Av,
    Ai,
    Zin,
    Zout,
    Pdiss,
    Id_sat,
    Vds_cutoff,
  };
}

export function getPreset(name: string): MosfetParams {
  const presets: Record<string, MosfetParams> = {
    'cs-cutoff':      { Vgs: 0.0,  Vds: 5.0,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-source', Vdd: 10, Rd: 2, Rs: 0.5, Rg: 1, Rload: 10 },
    'cs-active':      { Vgs: 2.0,  Vds: 5.0,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-source', Vdd: 10, Rd: 2, Rs: 0.5, Rg: 1, Rload: 10 },
    'cs-triode':      { Vgs: 2.0,  Vds: 0.5,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-source', Vdd: 10, Rd: 2, Rs: 0.5, Rg: 1, Rload: 10 },
    'cs-saturation':  { Vgs: 3.0,  Vds: 5.0,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-source', Vdd: 10, Rd: 2, Rs: 0.5, Rg: 1, Rload: 10 },
    'cd-follower':    { Vgs: 2.0,  Vds: 5.0,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-drain',  Vdd: 10, Rd: 0.1, Rs: 2, Rg: 1, Rload: 10 },
    'cg-active':      { Vgs: 2.0,  Vds: 5.0,  Vth: 0.7,  temperature: 300, type: 'nmos', W: 10, L: 1, tox: 10, topology: 'common-gate',    Vdd: 10, Rd: 2, Rs: 0.5, Rg: 0.1, Rload: 10 },
    'pmos-cs':        { Vgs: -2.0, Vds: -5.0, Vth: -0.7, temperature: 300, type: 'pmos', W: 10, L: 1, tox: 10, topology: 'common-source', Vdd: 10, Rd: 2, Rs: 0.5, Rg: 1, Rload: 10 },
    'short-channel':  { Vgs: 1.5,  Vds: 3.0,  Vth: 0.5,  temperature: 300, type: 'nmos', W: 10, L: 0.18, tox: 4, topology: 'common-source', Vdd: 5, Rd: 1, Rs: 0.2, Rg: 1, Rload: 5 },
  };
  return presets[name] || presets['cs-cutoff'];
}

export const PRESET_NAMES = [
  'cs-cutoff', 'cs-active', 'cs-triode', 'cs-saturation',
  'cd-follower', 'cg-active', 'pmos-cs', 'short-channel',
];

export const PRESET_LABELS: Record<string, string> = {
  'cs-cutoff': 'CS — Cutoff',
  'cs-active': 'CS — Active (Saturation)',
  'cs-triode': 'CS — Triode (Linear)',
  'cs-saturation': 'CS — Deep Saturation',
  'cd-follower': 'CD — Source Follower',
  'cg-active': 'CG — Active',
  'pmos-cs': 'PMOS — Common Source',
  'short-channel': 'Short Channel (180nm)',
};

export const REGION_COLORS: Record<MosfetRegion, string> = {
  cutoff: '#94a3b8',
  triode: '#60a5fa',
  saturation: '#4ade80',
};

export const REGION_DESCRIPTIONS: Record<MosfetRegion, string> = {
  cutoff: 'Vgs < Vth. No inversion layer. Transistor is OFF. Only tiny subthreshold leakage.',
  triode: 'Vgs > Vth and Vds < Vov. Channel is continuous. Acts as voltage-controlled resistor.',
  saturation: 'Vgs > Vth and Vds > Vov. Channel pinches off at drain. Current independent of Vds. Used for amplification.',
};

export const TOPOLOGY_DESCRIPTIONS: Record<MosfetTopology, string> = {
  'common-source': 'Voltage gain: high (Av = -gm·Rd). Current gain: high. Input Z: very high (Rg). Output Z: Rd. Phase: 180°. Most common amplifier.',
  'common-drain': 'Voltage gain: ≈1 (Av = gm·Rs/(1+gm·Rs)). Current gain: high. Input Z: very high. Output Z: low (1/gm). Phase: 0°. Source follower / buffer.',
  'common-gate': 'Voltage gain: high (Av = gm·Rd). Current gain: ≈1. Input Z: very low (1/gm). Output Z: Rd. Phase: 0°. RF / high-frequency amp.',
};

export function getOutputCurve(
  Vgs: number, Vth: number, type: MosfetType, W: number, L: number,
  tox: number, temperature: number, Vdd: number, Rd: number, steps: number = 100
): { vds: number; id: number }[] {
  const Cox = (EPS_SIO2 / (tox * 1e-9)) * 1e15;
  const mu = 600 * Math.pow(300 / temperature, 1.5);
  const k = mu * Cox * 1e-6;
  const lambda = 0.02 / L;
  const Vov = type === 'nmos' ? Math.max(0, Vgs - Vth) : Math.max(0, Vth - Vgs);
  const maxVds = Vdd;

  const data: { vds: number; id: number }[] = [];
  for (let i = 0; i <= steps; i++) {
    const vds = (i / steps) * maxVds;
    let id = 0;
    if (Vov <= 0) {
      id = 0;
    } else if (vds < Vov) {
      id = k * (W / L) * (Vov * vds - vds * vds / 2) * 1e-3;
    } else {
      id = 0.5 * k * (W / L) * Vov * Vov * (1 + lambda * vds) * 1e-3;
    }
    data.push({ vds, id: Math.abs(id) });
  }
  return data;
}

export function getLoadLine(Vdd: number, Rd: number, steps: number = 100): { vds: number; id: number }[] {
  const data: { vds: number; id: number }[] = [];
  for (let i = 0; i <= steps; i++) {
    const vds = (i / steps) * Vdd;
    const id = (Vdd - vds) / Rd;
    data.push({ vds, id: Math.max(0, id) });
  }
  return data;
}

export interface PracticeProblem {
  id: string;
  question: string;
  given: string[];
  find: string;
  answer: string;
  solution: string[];
  topology: MosfetTopology;
}

export const PRACTICE_PROBLEMS: PracticeProblem[] = [
  {
    id: 'cs-1',
    topology: 'common-source',
    question: 'Design a common-source amplifier with the following specifications.',
    given: ['Vdd = 10V', 'Rd = 2kΩ', 'Rg = 1MΩ', 'Vth = 0.7V', "k'n(W/L) = 1mA/V²"],
    find: 'Find Vgs for Id = 1mA and the resulting voltage gain Av.',
    answer: 'Vgs = 2.11V, Av = -4.0 V/V',
    solution: [
      "In saturation: Id = 0.5·k'n·(Vgs - Vth)²",
      "1mA = 0.5·1mA/V²·(Vgs - 0.7)²",
      '(Vgs - 0.7)² = 2 → Vgs - 0.7 = 1.41 → Vgs = 2.11V',
      "gm = k'n·(Vgs - Vth) = 1mA/V² · 1.41V = 1.41mS",
      'Av = -gm·Rd = -1.41mS · 2kΩ = -2.83 V/V',
      'Note: With channel-length modulation, gain is slightly lower.',
    ],
  },
  {
    id: 'cs-2',
    topology: 'common-source',
    question: 'A common-source NMOS amplifier operates in saturation.',
    given: ['Vgs = 2.0V', 'Vth = 0.7V', 'Vdd = 5V', 'Rd = 5kΩ', "k'n = 0.5mA/V²", 'W/L = 4'],
    find: 'Find Id, Vds, gm, and Av.',
    answer: 'Id = 1.69mA, Vds = 3.45V, gm = 2.6mS, Av = -13.0 V/V',
    solution: [
      'Vov = Vgs - Vth = 2.0 - 0.7 = 1.3V',
      "Id = 0.5·k'n·(W/L)·Vov² = 0.5·0.5·4·(1.3)² = 1.69mA",
      'Vds = Vdd - Id·Rd = 5 - 1.69mA·5kΩ = 5 - 8.45 = -3.45V',
      'Wait: Id_sat = Vdd/Rd = 5/5k = 1mA. Since 1.69mA > 1mA, transistor would be in triode.',
      'For valid saturation: choose Rd = 2kΩ: Vds = 5 - 3.38 = 1.62V > Vov = 1.3V ✓',
      "gm = k'n·(W/L)·Vov = 0.5·4·1.3 = 2.6mS",
      'Av = -gm·Rd = -2.6mS·2kΩ = -5.2 V/V',
    ],
  },
  {
    id: 'cd-1',
    topology: 'common-drain',
    question: 'A source follower (common-drain) has the following parameters.',
    given: ['Vdd = 10V', 'Rs = 2kΩ', 'Rg = 1MΩ', 'Vgs = 2V', 'Vth = 0.7V', 'gm = 2mS'],
    find: 'Find the voltage gain Av and output impedance Zout.',
    answer: 'Av = 0.8 V/V, Zout = 500Ω',
    solution: [
      'For common-drain: Av = gm·Rs / (1 + gm·Rs)',
      'Av = 2mS·2kΩ / (1 + 2mS·2kΩ) = 4 / (1 + 4) = 4/5 = 0.8 V/V',
      'Zout = 1/gm = 1/2mS = 500Ω',
      'The gain is less than 1 but close to it, providing buffering.',
    ],
  },
  {
    id: 'cg-1',
    topology: 'common-gate',
    question: 'A common-gate amplifier is designed for RF applications.',
    given: ['Vdd = 5V', 'Rd = 3kΩ', 'gm = 3mS', 'Rload = 10kΩ'],
    find: 'Find Av, Zin, and Zout.',
    answer: 'Av = 6.92 V/V, Zin = 333Ω, Zout = 3kΩ',
    solution: [
      'Rl_eff = Rd || Rload = 3kΩ || 10kΩ = (3·10)/(3+10) = 2.31kΩ',
      'Av = gm·Rl_eff = 3mS · 2.31kΩ = 6.92 V/V',
      'Zin = 1/gm = 1/3mS = 333Ω',
      'Zout = Rd = 3kΩ',
      'Low input impedance makes it suitable for RF where source impedance is 50Ω.',
    ],
  },
  {
    id: 'cs-3',
    topology: 'common-source',
    question: 'Determine the operating region of an NMOS transistor.',
    given: ['Vgs = 1.5V', 'Vds = 0.3V', 'Vth = 0.7V'],
    find: 'Operating region and Vov.',
    answer: 'Region: Triode, Vov = 0.8V',
    solution: [
      'Vov = Vgs - Vth = 1.5 - 0.7 = 0.8V',
      'Check: Vds = 0.3V < Vov = 0.8V',
      'Since Vgs > Vth (1.5 > 0.7) and Vds < Vov (0.3 < 0.8), the transistor is in TRIODE (linear) region.',
      'In triode, the channel is continuous from source to drain.',
    ],
  },
];