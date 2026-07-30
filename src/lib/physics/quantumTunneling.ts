// ═══════════════════════════════════════════════════════════════════════════
// 1D Quantum Tunneling Physics Engine — Split-Step Fourier Method
// ═══════════════════════════════════════════════════════════════════════════

export const HBAR_EV_FS = 0.6582119; // ℏ in eV·fs
export const K_FACTOR = 5.788;       // ℏ²/2mℏ  =>  Å²/fs for m=1
export const V_FACTOR = 1.519;       // 1/ℏ     =>  1/(eV·fs)

export interface Complex { re: number; im: number; }

export type PotentialType = 'barrier' | 'well' | 'step' | 'double' | 'triangular';

export interface TunnelingParams {
  potentialType: PotentialType;
  particleEnergy: number;   // eV
  barrierHeight: number;    // eV  (magnitude; sign handled by type)
  barrierWidth: number;     // Å
  barrierPosition: number;  // Å from left edge
  packetWidth: number;      // Å  (σ of Gaussian)
  particleMass: number;     // electron masses
  speed: number;
  zoom: number;
  showPotential: boolean;
  showProbability: boolean;
  showRealPart: boolean;
  showImaginaryPart: boolean;
  showPhase: boolean;
  showClassical: boolean;
  showEnergyLine: boolean;
  autoRestart: boolean;
}

export interface TunnelingPreset {
  name: string;
  description: string;
  params: Partial<TunnelingParams>;
}

export interface TunnelingStats {
  energy: number;
  momentum: number;
  barrierHeight: number;
  barrierWidth: number;
  theoreticalT: number;
  measuredT: number;
  measuredR: number;
  wavelength: number;
  decayConstant: number;
  time: number;
}

// ── Complex FFT (Cooley-Tukey, power-of-2) ───────────────────────────────

export function fft(signal: Complex[], inverse = false): void {
  const n = signal.length;
  if (n <= 1) return;

  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      const tmp = signal[i];
      signal[i] = signal[j];
      signal[j] = tmp;
    }
  }

  for (let len = 2; len <= n; len <<= 1) {
    const ang = (2 * Math.PI / len) * (inverse ? 1 : -1);
    const wlen_re = Math.cos(ang);
    const wlen_im = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let w_re = 1, w_im = 0;
      for (let j = 0; j < len / 2; j++) {
        const u = signal[i + j];
        const v_re = signal[i + j + len / 2].re * w_re - signal[i + j + len / 2].im * w_im;
        const v_im = signal[i + j + len / 2].re * w_im + signal[i + j + len / 2].im * w_re;
        signal[i + j] = { re: u.re + v_re, im: u.im + v_im };
        signal[i + j + len / 2] = { re: u.re - v_re, im: u.im - v_im };
        const nw_re = w_re * wlen_re - w_im * wlen_im;
        const nw_im = w_re * wlen_im + w_im * wlen_re;
        w_re = nw_re; w_im = nw_im;
      }
    }
  }

  if (inverse) {
    for (let i = 0; i < n; i++) {
      signal[i].re /= n;
      signal[i].im /= n;
    }
  }
}

// ── Wave Packet Initialization ───────────────────────────────────────────

export function initWavePacket(x0: number, k0: number, sigma: number, x: number[], dx: number): Complex[] {
  const N = x.length;
  const psi: Complex[] = [];
  let norm = 0;
  const prefactor = Math.pow(2 * Math.PI * sigma * sigma, -0.25);
  for (let i = 0; i < N; i++) {
    const gauss = prefactor * Math.exp(-((x[i] - x0) * (x[i] - x0)) / (4 * sigma * sigma));
    const re = gauss * Math.cos(k0 * x[i]);
    const im = gauss * Math.sin(k0 * x[i]);
    psi.push({ re, im });
    norm += (re * re + im * im) * dx;
  }
  const f = Math.sqrt(norm);
  for (let i = 0; i < N; i++) {
    psi[i].re /= f;
    psi[i].im /= f;
  }
  return psi;
}

// ── Potential Builders ───────────────────────────────────────────────────

export function buildPotential(type: PotentialType, x: number[], height: number, width: number, position: number): number[] {
  const N = x.length;
  const V = new Array(N).fill(0);
  switch (type) {
    case 'barrier':
      for (let i = 0; i < N; i++) if (x[i] >= position && x[i] <= position + width) V[i] = height;
      break;
    case 'well':
      for (let i = 0; i < N; i++) if (x[i] >= position && x[i] <= position + width) V[i] = -height;
      break;
    case 'step':
      for (let i = 0; i < N; i++) if (x[i] >= position) V[i] = height;
      break;
    case 'double': {
      const gap = width * 0.8;
      for (let i = 0; i < N; i++) {
        if (x[i] >= position && x[i] <= position + width) V[i] = height;
        else if (x[i] >= position + width + gap && x[i] <= position + 2 * width + gap) V[i] = height;
      }
      break;
    }
    case 'triangular':
      for (let i = 0; i < N; i++) {
        if (x[i] >= position && x[i] <= position + width) {
          V[i] = height * (1 - (x[i] - position) / width);
        }
      }
      break;
  }
  return V;
}

// ── Split-Step Time Evolution ────────────────────────────────────────────

export function evolveStep(psi: Complex[], V: number[], k: number[], dt: number, m: number): Complex[] {
  const N = psi.length;
  // ½ position
  for (let i = 0; i < N; i++) {
    const phase = -0.5 * V_FACTOR * V[i] * dt;
    const c = Math.cos(phase), s = Math.sin(phase);
    const re = psi[i].re * c - psi[i].im * s;
    const im = psi[i].re * s + psi[i].im * c;
    psi[i] = { re, im };
  }
  fft(psi, false);
  // momentum
  for (let i = 0; i < N; i++) {
    const phase = -(K_FACTOR / m) * k[i] * k[i] * dt;
    const c = Math.cos(phase), s = Math.sin(phase);
    const re = psi[i].re * c - psi[i].im * s;
    const im = psi[i].re * s + psi[i].im * c;
    psi[i] = { re, im };
  }
  fft(psi, true);
  // ½ position
  for (let i = 0; i < N; i++) {
    const phase = -0.5 * V_FACTOR * V[i] * dt;
    const c = Math.cos(phase), s = Math.sin(phase);
    const re = psi[i].re * c - psi[i].im * s;
    const im = psi[i].re * s + psi[i].im * c;
    psi[i] = { re, im };
  }
  return psi;
}

// ── Absorbing Boundaries ─────────────────────────────────────────────────

export function applyAbsorbingBoundary(psi: Complex[], x: number[], L: number, strength = 3): void {
  const N = psi.length;
  const width = L * 0.08;
  for (let i = 0; i < N; i++) {
    let damp = 1;
    if (x[i] < width) {
      damp = Math.exp(-strength * ((width - x[i]) / width) * ((width - x[i]) / width));
    } else if (x[i] > L - width) {
      damp = Math.exp(-strength * ((x[i] - (L - width)) / width) * ((x[i] - (L - width)) / width));
    }
    psi[i].re *= damp;
    psi[i].im *= damp;
  }
}

// ── Measurements ─────────────────────────────────────────────────────────

export function measureProbabilities(psi: Complex[], x: number[], barrierPos: number, barrierWidth: number, dx: number) {
  let left = 0, right = 0, middle = 0;
  const N = psi.length;
  for (let i = 0; i < N; i++) {
    const p = psi[i].re * psi[i].re + psi[i].im * psi[i].im;
    if (x[i] < barrierPos) left += p * dx;
    else if (x[i] > barrierPos + barrierWidth) right += p * dx;
    else middle += p * dx;
  }
  return { left, right, middle, total: left + right + middle };
}

// ── Analytical Transmission ──────────────────────────────────────────────

export function analyticalTransmission(E: number, V0: number, w: number, m: number): number {
  if (E <= 0 || V0 <= 0 || w <= 0) return E > V0 ? 1 : 0;
  const k = 0.512 * Math.sqrt(m * E);
  if (E > V0) {
    const k2 = 0.512 * Math.sqrt(m * (E - V0));
    const sinTerm = Math.sin(k2 * w);
    const denom = 1 + (V0 * V0 * sinTerm * sinTerm) / (4 * E * (E - V0));
    return 1 / denom;
  } else if (Math.abs(E - V0) < 0.005) {
    return 1 / (1 + m * V0 * w * w / 2);
  } else {
    const kappa = 0.512 * Math.sqrt(m * (V0 - E));
    const sinhTerm = Math.sinh(kappa * w);
    const denom = 1 + (V0 * V0 * sinhTerm * sinhTerm) / (4 * E * (V0 - E));
    return Math.min(1, Math.max(0, 1 / denom));
  }
}

export function wkbTransmission(E: number, V: number[], x: number[], dx: number, m: number): number {
  if (E <= 0) return 0;
  let integral = 0;
  for (let i = 0; i < V.length; i++) {
    if (V[i] > E) integral += Math.sqrt(V[i] - E) * dx;
  }
  if (integral <= 0) return 1;
  const kappa = 0.512 * Math.sqrt(m);
  return Math.exp(-2 * kappa * integral);
}

export function getDecayConstant(E: number, V0: number, m: number): number {
  if (E >= V0) return 0;
  return 0.512 * Math.sqrt(m * Math.max(0, V0 - E));
}

export function getWavelength(E: number, m: number): number {
  if (E <= 0) return 0;
  return (2 * Math.PI) / (0.512 * Math.sqrt(m * E));
}

// ── Presets ──────────────────────────────────────────────────────────────

export const TUNNELING_PRESETS: TunnelingPreset[] = [
  {
    name: 'Electron Tunneling',
    description: 'Classic quantum tunneling: 1 eV electron vs 2 eV barrier, 2 Å wide. Transmission ~15%.',
    params: { potentialType: 'barrier', particleEnergy: 1, barrierHeight: 2, barrierWidth: 2, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1, showPotential: true, showProbability: true, showRealPart: true, showEnergyLine: true },
  },
  {
    name: 'Thick Barrier',
    description: 'Double the width to 4 Å. Transmission drops exponentially to <1%. Watch the evanescent wave decay inside.',
    params: { potentialType: 'barrier', particleEnergy: 1, barrierHeight: 2, barrierWidth: 4, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1.5, showPotential: true, showProbability: true, showEnergyLine: true },
  },
  {
    name: 'Above the Barrier',
    description: 'E = 3 eV > V₀ = 2 eV. Classically T = 100%, but quantum interference creates oscillations in transmission vs energy.',
    params: { potentialType: 'barrier', particleEnergy: 3, barrierHeight: 2, barrierWidth: 3, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1, showPotential: true, showProbability: true, showRealPart: true, showEnergyLine: true },
  },
  {
    name: 'Resonant Tunneling',
    description: 'Double barrier. At certain energies the inter-barrier well supports quasi-bound states, giving T ≈ 1. Tune E to find resonance.',
    params: { potentialType: 'double', particleEnergy: 0.9, barrierHeight: 2, barrierWidth: 1.5, barrierPosition: 22, packetWidth: 2, particleMass: 1, speed: 0.8, showPotential: true, showProbability: true, showEnergyLine: true },
  },
  {
    name: 'Quantum Well Scattering',
    description: 'A potential well (V < 0) attracts the particle. Partial reflection persists even when E > 0; transmission peaks at resonances.',
    params: { potentialType: 'well', particleEnergy: 1, barrierHeight: 3, barrierWidth: 3, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1, showPotential: true, showProbability: true, showEnergyLine: true },
  },
  {
    name: 'Field Emission (STM)',
    description: 'Triangular barrier simulating an STM tip. The electric field tilts the barrier, enabling tunneling at lower energies.',
    params: { potentialType: 'triangular', particleEnergy: 0.5, barrierHeight: 3, barrierWidth: 4, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1, showPotential: true, showProbability: true, showEnergyLine: true },
  },
  {
    name: 'Heavy Particle (Classical)',
    description: 'Mass = 10 mₑ. De Broglie wavelength shrinks; wave packet behaves more classically. Tunneling is exponentially suppressed.',
    params: { potentialType: 'barrier', particleEnergy: 1, barrierHeight: 2, barrierWidth: 2, barrierPosition: 25, packetWidth: 0.8, particleMass: 10, speed: 1, showPotential: true, showProbability: true, showClassical: true, showEnergyLine: true },
  },
  {
    name: 'Step Potential',
    description: 'Semi-infinite step: E = 1.5 eV, V = 2 eV. Wave penetrates as an evanescent decay, then reflects completely.',
    params: { potentialType: 'step', particleEnergy: 1.5, barrierHeight: 2, barrierWidth: 10, barrierPosition: 25, packetWidth: 1.5, particleMass: 1, speed: 1, showPotential: true, showProbability: true, showEnergyLine: true },
  },
];
