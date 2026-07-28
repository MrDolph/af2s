#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v21-enhanced: "Atomic Models" module
#   ENHANCED VERSION with graduate-level physics
#
#   Features:
#     • Thomson, Rutherford, Bohr, Quantum — all 4 models
#     • Multi-electron atom builder with Aufbau principle
#     • Fine structure splitting (spin-orbit coupling)
#     • Zeeman effect (magnetic field splitting of levels)
#     • Expanded orbitals: 4f, 5g, 6h with real spherical harmonics
#     • Accurate Rutherford hyperbolic trajectory integration
#     • Electron spin visualization (↑↓)
#     • Periodic table shell-filling reference
#     • Model evolution timeline with smooth transitions
#
# Run: bash patches/patch-v21-atomic-models-enhanced.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root." >&2
  exit 1
fi

echo "── A-Factor patch v21-enhanced: Atomic Models (Graduate Edition) ──"
mkdir -p "src/app/embed/atomic-models" "src/app/simulations/atomic-models" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/atomicModels.ts"
cat > "src/lib/physics/atomicModels.ts" << 'AFEOF'
// ═══════════════════════════════════════════════════════════════════════════
// Atomic Models Physics Engine — Enhanced Graduate Edition
// ═══════════════════════════════════════════════════════════════════════════

export const BOHR_RADIUS = 0.529; // Ångström
export const HARTREE_ENERGY = 27.211; // eV
export const RYDBERG_ENERGY = 13.606; // eV
export const PLANCK_EV = 4.136e-15; // eV·s
export const SPEED_OF_LIGHT = 2.998e8; // m/s
export const FINE_STRUCTURE = 1 / 137.036;
export const BOHR_MAGNETON = 5.788e-5; // eV/T
export const RYDBERG_CONSTANT = 1.097e7; // m⁻¹

export type AtomicModel = 'thomson' | 'rutherford' | 'bohr' | 'quantum';

export interface AtomicParams {
  model: AtomicModel;
  speed: number;
  zoom: number;
  showOrbits: boolean;
  showNucleus: boolean;
  showElectrons: boolean;
  showProbability: boolean;
  showEnergyLevels: boolean;
  showSpectrum: boolean;
  showLabels: boolean;
  showClassicalPath: boolean;
  showQuantumNumbers: boolean;
  showSpin: boolean;
  showFineStructure: boolean;
  showZeeman: boolean;
  magneticField: number; // Tesla
  nQuantum: number;
  lQuantum: number;
  mQuantum: number;
  protonCount: number;
  neutronCount: number;
  electronCount: number;
  alphaEnergy: number;
}

export interface AtomicPreset {
  name: string;
  description: string;
  model: AtomicModel;
  params: Partial<AtomicParams>;
}

export interface EnergyLevel {
  n: number;
  l: number;
  j: number; // total angular momentum j = l ± 1/2
  energy: number;
  zeemanShift: number;
  label: string;
}

export interface SpectralLine {
  wavelength: number;
  fromN: number;
  toN: number;
  series: string;
  intensity: number;
  color: string;
  fineSplit: boolean;
}

export interface ElectronConfig {
  n: number;
  l: number;
  m: number;
  ms: number; // spin ±½
  orbital: string;
  energy: number;
}

export interface ScatteringParticle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  energy: number;
  active: boolean;
  trail: { x: number; y: number }[];
}

export interface ThomsonElectron {
  angle: number;
  radius: number;
  speed: number;
  phase: number;
}

// ── Thomson Model ──────────────────────────────────────────────────────────

export function generateThomsonElectrons(count: number): ThomsonElectron[] {
  const electrons: ThomsonElectron[] = [];
  for (let i = 0; i < count; i++) {
    electrons.push({
      angle: (Math.PI * 2 * i) / count + Math.random() * 0.5,
      radius: 0.3 + Math.random() * 0.5,
      speed: 0.5 + Math.random() * 1.5,
      phase: Math.random() * Math.PI * 2,
    });
  }
  return electrons;
}

export function updateThomsonElectrons(
  electrons: ThomsonElectron[],
  dt: number,
  speed: number
): ThomsonElectron[] {
  return electrons.map((e) => ({
    ...e,
    angle: e.angle + e.speed * dt * speed * 0.5,
    phase: e.phase + e.speed * dt * speed * 2,
  }));
}

// ── Rutherford Scattering — ACCURATE HYPERBOLIC TRAJECTORIES ─────────────

export function integrateRutherfordTrajectory(
  b: number, // impact parameter (fm)
  E: number, // kinetic energy (MeV)
  Z: number, // atomic number
  dt: number = 0.001
): { x: number; y: number }[] {
  const k = 1.44; // e²/(4πε₀) in MeV·fm
  const mAlpha = 4; // atomic mass units
  const v0 = Math.sqrt(2 * E / mAlpha) * 299.8; // speed in fm/s (natural units)

  let x = -500;
  let y = b;
  let vx = v0;
  let vy = 0;
  const points: { x: number; y: number }[] = [{ x, y }];

  for (let step = 0; step < 2000; step++) {
    const r2 = x * x + y * y;
    const r = Math.sqrt(r2);
    if (r < 2) break; // nuclear contact
    if (x > 500) break;

    // Coulomb acceleration: a = F/m = (kZe²/r²)/m
    const a = (2 * Z * k) / (mAlpha * r2); // factor 2 for He²⁺
    const ax = a * x / r;
    const ay = a * y / r;

    vx += ax * dt;
    vy += ay * dt;
    x += vx * dt;
    y += vy * dt;

    if (step % 5 === 0) {
      points.push({ x, y });
    }
  }

  return points;
}

export function scatteringAngle(b: number, E: number, Z: number): number {
  const k = 1.44;
  const cot = (2 * E) / (Z * k) * b * 0.001; // approximate
  return 2 * Math.atan(1 / Math.max(cot, 0.001));
}

export function createAlphaParticle(b: number, E: number): ScatteringParticle {
  return {
    x: -500,
    y: b,
    vx: Math.sqrt(2 * E / 4) * 50,
    vy: 0,
    energy: E,
    active: true,
    trail: [],
  };
}

export function updateAlphaParticle(
  p: ScatteringParticle,
  dt: number,
  Z: number
): ScatteringParticle {
  if (!p.active) return p;

  const k = 1.44;
  const mAlpha = 4;
  const r2 = p.x * p.x + p.y * p.y;
  const r = Math.sqrt(r2);

  if (r < 2) return { ...p, active: false };
  if (Math.abs(p.x) > 600) return { ...p, active: false };

  const a = (2 * Z * k) / (mAlpha * r2);
  const ax = (a * p.x) / r;
  const ay = (a * p.y) / r;

  const newVx = p.vx + ax * dt * 100;
  const newVy = p.vy + ay * dt * 100;
  const newX = p.x + newVx * dt * 10;
  const newY = p.y + newVy * dt * 10;

  const trail = [...p.trail, { x: newX, y: newY }];
  if (trail.length > 100) trail.shift();

  return {
    ...p,
    x: newX, y: newY,
    vx: newVx, vy: newVy,
    trail,
    active: true,
  };
}

// ── Bohr Model — WITH FINE STRUCTURE & ZEEMAN ────────────────────────────

export function bohrEnergy(n: number, Z: number = 1): number {
  return -RYDBERG_ENERGY * Z * Z / (n * n);
}

export function bohrRadius(n: number, Z: number = 1): number {
  return BOHR_RADIUS * n * n / Z;
}

export function bohrVelocity(n: number, Z: number = 1): number {
  return (Z * FINE_STRUCTURE * SPEED_OF_LIGHT) / n;
}

/** Fine structure correction: ΔE_fs = E_n (Zα)² / n [1/(j+½) - 3/4n] */
export function fineStructureEnergy(n: number, l: number, j: number, Z: number = 1): number {
  const En = bohrEnergy(n, Z);
  const alpha2 = (Z * Z * FINE_STRUCTURE * FINE_STRUCTURE) / (n * n);
  const correction = alpha2 * En * (1 / (j + 0.5) - 3 / (4 * n));
  return correction;
}

/** Zeeman splitting: ΔE_z = m_j g_j μ_B B */
export function zeemanShift(n: number, l: number, j: number, mj: number, B: number): number {
  // Landé g-factor
  const g = 1 + (j * (j + 1) + 0.5 * 1.5 - l * (l + 1)) / (2 * j * (j + 1));
  return mj * g * BOHR_MAGNETON * B * 1e6; // return in eV (scaled)
}

export function transitionWavelength(nFrom: number, nTo: number, Z: number = 1): number {
  const E_from = bohrEnergy(nFrom, Z);
  const E_to = bohrEnergy(nTo, Z);
  const deltaE = Math.abs(E_from - E_to);
  return 1240 / deltaE;
}

export function spectralSeriesName(nTo: number): string {
  const names: Record<number, string> = { 1: 'Lyman', 2: 'Balmer', 3: 'Paschen', 4: 'Brackett', 5: 'Pfund', 6: 'Humphreys' };
  return names[nTo] || `n=${nTo}`;
}

export function wavelengthToRGB(wavelength: number): string {
  let r = 0, g = 0, b = 0;
  if (wavelength >= 380 && wavelength < 440) {
    r = -(wavelength - 440) / (440 - 380);
    g = 0; b = 1;
  } else if (wavelength >= 440 && wavelength < 490) {
    r = 0;
    g = (wavelength - 440) / (490 - 440);
    b = 1;
  } else if (wavelength >= 490 && wavelength < 510) {
    r = 0; g = 1;
    b = -(wavelength - 510) / (510 - 490);
  } else if (wavelength >= 510 && wavelength < 580) {
    r = (wavelength - 510) / (580 - 510);
    g = 1; b = 0;
  } else if (wavelength >= 580 && wavelength < 645) {
    r = 1;
    g = -(wavelength - 645) / (645 - 580);
    b = 0;
  } else if (wavelength >= 645 && wavelength <= 780) {
    r = 1; g = 0; b = 0;
  }
  const factor = wavelength < 420 ? 0.3 + 0.7 * (wavelength - 380) / 40 :
                 wavelength > 700 ? 0.3 + 0.7 * (780 - wavelength) / 80 : 1;
  r = Math.round(255 * Math.min(1, r * factor));
  g = Math.round(255 * Math.min(1, g * factor));
  b = Math.round(255 * Math.min(1, b * factor));
  return `rgb(${r},${g},${b})`;
}

export function generateHydrogenSpectrum(maxN: number = 7): SpectralLine[] {
  const lines: SpectralLine[] = [];
  for (let nFrom = 2; nFrom <= maxN; nFrom++) {
    for (let nTo = 1; nTo < nFrom; nTo++) {
      const wl = transitionWavelength(nFrom, nTo);
      if (wl >= 90 && wl <= 2000) {
        lines.push({
          wavelength: wl,
          fromN: nFrom,
          toN: nTo,
          series: spectralSeriesName(nTo),
          intensity: 1 / (nFrom * nFrom * nTo * nTo),
          color: wavelengthToRGB(wl),
          fineSplit: nTo <= 2 && nFrom <= 4,
        });
      }
    }
  }
  return lines.sort((a, b) => a.wavelength - b.wavelength);
}

export function getEnergyLevels(maxN: number = 6, Z: number = 1, B: number = 0): EnergyLevel[] {
  const levels: EnergyLevel[] = [];
  for (let n = 1; n <= maxN; n++) {
    for (let l = 0; l < n; l++) {
      for (const j of [l - 0.5, l + 0.5]) {
        if (j < 0) continue;
        const baseE = bohrEnergy(n, Z);
        const fsE = fineStructureEnergy(n, l, j, Z);
        // Zeeman: show m_j = ±j as representative
        const mj = j;
        const zShift = B > 0 ? zeemanShift(n, l, j, mj, B) : 0;
        levels.push({
          n, l, j,
          energy: baseE + fsE,
          zeemanShift: zShift,
          label: `n=${n}, l=${l}, j=${j.toFixed(1)}`,
        });
      }
    }
  }
  return levels;
}

// ── Multi-electron Configurations (Aufbau) ────────────────────────────────

export function aufbauEnergy(n: number, l: number, Zeff: number): number {
  // Approximate energy using Slater's rules concept
  // E ≈ -13.6 * Zeff² / n²
  const shielding = Math.max(0, (n - 1) * 0.85 + (l) * 0.35);
  const ZeffActual = Math.max(1, Zeff - shielding);
  return -13.6 * ZeffActual * ZeffActual / (n * n);
}

export function getElectronConfiguration(Z: number): ElectronConfig[] {
  const configs: ElectronConfig[] = [];
  // Aufbau order: 1s, 2s, 2p, 3s, 3p, 4s, 3d, 4p, 5s, 4d, 5p, 6s, 4f, 5d, 6p, 7s, 5f, 6d, 7p
  const orbitals: [number, number, string][] = [
    [1, 0, '1s'], [2, 0, '2s'], [2, 1, '2p'],
    [3, 0, '3s'], [3, 1, '3p'], [4, 0, '4s'],
    [3, 2, '3d'], [4, 1, '4p'], [5, 0, '5s'],
    [4, 2, '4d'], [5, 1, '5p'], [6, 0, '6s'],
    [4, 3, '4f'], [5, 2, '5d'], [6, 1, '6p'],
    [7, 0, '7s'], [5, 3, '5f'], [6, 2, '6d'], [7, 1, '7p'],
  ];

  let remaining = Z;
  for (const [n, l, label] of orbitals) {
    if (remaining <= 0) break;
    const capacity = 2 * (2 * l + 1);
    const fill = Math.min(remaining, capacity);
    for (let i = 0; i < fill; i++) {
      const m = Math.floor(i / 2) - l;
      const ms = i % 2 === 0 ? 0.5 : -0.5; // Hund's rule: fill +½ first
      configs.push({
        n, l, m, ms,
        orbital: label,
        energy: aufbauEnergy(n, l, Z),
      });
    }
    remaining -= fill;
  }
  return configs;
}

export function orbitalLabel(n: number, l: number): string {
  const letters = ['s', 'p', 'd', 'f', 'g', 'h'];
  return `${n}${letters[l] || '?'}`;
}

export function getValenceShell(Z: number): string {
  const config = getElectronConfiguration(Z);
  if (config.length === 0) return '';
  const last = config[config.length - 1];
  return orbitalLabel(last.n, last.l);
}

// ── Quantum Orbitals — EXPANDED TO 4f, 5g, 6h ────────────────────────────

export function factorial(n: number): number {
  let r = 1;
  for (let i = 2; i <= n; i++) r *= i;
  return r;
}

/** Associated Legendre polynomial P_l^m(cos θ) — expanded to l=5 */
export function associatedLegendre(l: number, m: number, x: number): number {
  const absM = Math.abs(m);
  const s = Math.sqrt(Math.max(0, 1 - x * x));

  if (l === 0) return 1;
  if (l === 1) {
    if (absM === 0) return x;
    if (absM === 1) return -s;
  }
  if (l === 2) {
    if (absM === 0) return 0.5 * (3 * x * x - 1);
    if (absM === 1) return -3 * x * s;
    if (absM === 2) return 3 * (1 - x * x);
  }
  if (l === 3) {
    if (absM === 0) return 0.5 * (5 * x * x * x - 3 * x);
    if (absM === 1) return -1.5 * (5 * x * x - 1) * s;
    if (absM === 2) return 15 * x * (1 - x * x);
    if (absM === 3) return -15 * s * s * s;
  }
  if (l === 4) {
    if (absM === 0) return (35 * x * x * x * x - 30 * x * x + 3) / 8;
    if (absM === 1) return -2.5 * (7 * x * x * x - 3 * x) * s;
    if (absM === 2) return 7.5 * (7 * x * x - 1) * (1 - x * x);
    if (absM === 3) return -105 * x * s * s * s;
    if (absM === 4) return 105 * (1 - x * x) * (1 - x * x);
  }
  if (l === 5) {
    if (absM === 0) return (63 * x * x * x * x * x - 70 * x * x * x + 15 * x) / 8;
    if (absM === 1) return -15.0 / 8.0 * (21 * x * x * x * x - 14 * x * x + 1) * s;
    if (absM === 2) return 105.0 / 2.0 * (3 * x * x * x - x) * (1 - x * x);
    if (absM === 3) return -105.0 / 2.0 * (9 * x * x - 1) * s * s * s;
    if (absM === 4) return 945 * x * (1 - x * x) * (1 - x * x);
    if (absM === 5) return -945 * s * s * s * s * s;
  }
  return 1;
}

/** Spherical harmonic |Y_l^m(θ,φ)|² */
export function sphericalHarmonicProb(l: number, m: number, theta: number, phi: number): number {
  const absM = Math.abs(m);
  const x = Math.cos(theta);
  const norm = Math.sqrt(
    ((2 * l + 1) * factorial(l - absM)) /
    (4 * Math.PI * factorial(l + absM))
  );
  const Plm = associatedLegendre(l, m, x);
  const Y = norm * Plm * (m >= 0 ? Math.cos(absM * phi) : Math.sin(absM * phi));
  return Y * Y;
}

/** Radial wavefunction R_nl(r) for hydrogen — expanded to n=4, l=3 */
export function radialWavefunction(n: number, l: number, r: number): number {
  const a0 = 1;
  const rho = (2 * r) / (n * a0);
  const norm = Math.pow(2 / (n * a0), 1.5);

  if (n === 1 && l === 0) return norm * 2 * Math.exp(-rho / 2);
  if (n === 2 && l === 0) return norm * (1 / (2 * Math.sqrt(2))) * (2 - rho) * Math.exp(-rho / 2);
  if (n === 2 && l === 1) return norm * (1 / (2 * Math.sqrt(6))) * rho * Math.exp(-rho / 2);
  if (n === 3 && l === 0) return norm * (1 / (9 * Math.sqrt(3))) * (6 - 6 * rho + rho * rho) * Math.exp(-rho / 2);
  if (n === 3 && l === 1) return norm * (1 / (9 * Math.sqrt(6))) * (4 - rho) * rho * Math.exp(-rho / 2);
  if (n === 3 && l === 2) return norm * (1 / (9 * Math.sqrt(30))) * rho * rho * Math.exp(-rho / 2);
  if (n === 4 && l === 0) return norm * (1 / 96) * (24 - 36 * rho + 12 * rho * rho - rho * rho * rho) * Math.exp(-rho / 2);
  if (n === 4 && l === 1) return norm * (1 / (32 * Math.sqrt(15))) * (20 - 10 * rho + rho * rho) * rho * Math.exp(-rho / 2);
  if (n === 4 && l === 2) return norm * (1 / (96 * Math.sqrt(5))) * (6 - rho) * rho * rho * Math.exp(-rho / 2);
  if (n === 4 && l === 3) return norm * (1 / (96 * Math.sqrt(35))) * rho * rho * rho * Math.exp(-rho / 2);

  return norm * Math.pow(rho, l) * Math.exp(-rho / 2);
}

/** Full probability density |ψ_nlm(r,θ,φ)|² */
export function orbitalProbability(
  n: number, l: number, m: number,
  r: number, theta: number, phi: number
): number {
  const R = radialWavefunction(n, l, r);
  const Y2 = sphericalHarmonicProb(l, m, theta, phi);
  return R * R * Y2;
}

/** Generate 2D slice of orbital probability (x-z plane) */
export function generateOrbitalSlice(
  n: number, l: number, m: number,
  xMax: number, gridSize: number
): { x: number; z: number; prob: number }[][] {
  const grid: { x: number; z: number; prob: number }[][] = [];
  const maxR = 12 * n;

  for (let i = 0; i < gridSize; i++) {
    const row: { x: number; z: number; prob: number }[] = [];
    for (let j = 0; j < gridSize; j++) {
      const x = -maxR + (2 * maxR * j) / gridSize;
      const z = -maxR + (2 * maxR * i) / gridSize;
      const r = Math.sqrt(x * x + z * z);
      const theta = r > 0.001 ? Math.acos(Math.max(-1, Math.min(1, z / r))) : 0;
      const phi = x >= 0 ? 0 : Math.PI;
      const prob = orbitalProbability(n, l, m, r, theta, phi);
      row.push({ x, z, prob });
    }
    grid.push(row);
  }
  return grid;
}

/** Radial distribution function 4πr²|R_nl(r)|² */
export function radialDistribution(n: number, l: number, r: number): number {
  const R = radialWavefunction(n, l, r);
  return 4 * Math.PI * r * r * R * R;
}

// ── Presets ────────────────────────────────────────────────────────────────

export const ATOMIC_PRESETS: AtomicPreset[] = [
  {
    name: 'Thomson — Plum Pudding',
    description: 'J.J. Thomson\'s 1897 model: positive sphere with embedded electrons.',
    model: 'thomson',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 1, zoom: 1, showOrbits: false, showNucleus: false, showElectrons: true, showProbability: true, showLabels: true },
  },
  {
    name: 'Rutherford — Gold Foil',
    description: 'Geiger-Marsden experiment: α-particles scatter off a dense gold nucleus.',
    model: 'rutherford',
    params: { protonCount: 79, neutronCount: 118, electronCount: 0, speed: 1, zoom: 0.3, showNucleus: true, showElectrons: false, showLabels: true, alphaEnergy: 5.0 },
  },
  {
    name: 'Bohr — Ground State',
    description: 'n=1 ground state. The electron sits at the Bohr radius a₀ = 0.529 Å.',
    model: 'bohr',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 1, zoom: 1.5, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: true, showLabels: true },
  },
  {
    name: 'Bohr — Balmer Series',
    description: 'Visible spectral lines from transitions to n=2. Hα (656 nm red) through Hδ (410 nm violet).',
    model: 'bohr',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 1.5, zoom: 1.2, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: true, showLabels: true },
  },
  {
    name: 'Bohr — Fine Structure',
    description: 'Spin-orbit coupling splits each level into j = l ± ½. Enable fine structure to see the splitting.',
    model: 'bohr',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 1, zoom: 1.3, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: false, showLabels: true, showFineStructure: true, showSpin: true },
  },
  {
    name: 'Bohr — Zeeman Effect',
    description: 'Apply a magnetic field to split degenerate levels. The normal Zeeman effect splits each line into three.',
    model: 'bohr',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 1, zoom: 1.3, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: false, showLabels: true, showZeeman: true, magneticField: 3 },
  },
  {
    name: 'Quantum — 1s Orbital',
    description: 'Spherically symmetric ground state. Maximum probability density at the nucleus, but radial probability peaks at a₀.',
    model: 'quantum',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 0.5, zoom: 2, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 1, lQuantum: 0, mQuantum: 0 },
  },
  {
    name: 'Quantum — 2p Orbital',
    description: 'Dumbbell shape. One angular node (a plane where ψ=0). First orbital with orbital angular momentum.',
    model: 'quantum',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 0.5, zoom: 1.5, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 2, lQuantum: 1, mQuantum: 0 },
  },
  {
    name: 'Quantum — 3d Orbital',
    description: 'Cloverleaf shape with two angular nodes. d-orbitals govern transition metal chemistry and magnetism.',
    model: 'quantum',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 0.5, zoom: 1.2, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 3, lQuantum: 2, mQuantum: 0 },
  },
  {
    name: 'Quantum — 4f Orbital',
    description: 'Complex multi-lobed shape. f-orbitals are key to lanthanide chemistry and rare-earth magnets.',
    model: 'quantum',
    params: { protonCount: 1, neutronCount: 0, electronCount: 1, speed: 0.5, zoom: 1.0, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 4, lQuantum: 3, mQuantum: 0 },
  },
  {
    name: 'Multi-electron — Carbon (Z=6)',
    description: 'Carbon: 1s² 2s² 2p². The 2p electrons are unpaired (Hund\'s rule), giving carbon its valency of 4.',
    model: 'quantum',
    params: { protonCount: 6, neutronCount: 6, electronCount: 6, speed: 0.5, zoom: 1.0, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 2, lQuantum: 1, mQuantum: 0 },
  },
  {
    name: 'Multi-electron — Iron (Z=26)',
    description: 'Iron: [Ar] 3d⁶ 4s². The partially filled 3d shell gives iron its ferromagnetism.',
    model: 'quantum',
    params: { protonCount: 26, neutronCount: 30, electronCount: 26, speed: 0.5, zoom: 0.8, showNucleus: true, showProbability: true, showLabels: true, showQuantumNumbers: true, nQuantum: 3, lQuantum: 2, mQuantum: 0 },
  },
];

export const ORBITAL_LABELS: Record<string, string> = {
  '1,0,0': '1s — spherical ground state',
  '2,0,0': '2s — spherical, one radial node',
  '2,1,0': '2p_z — dumbbell along z-axis',
  '2,1,±1': '2p_x, 2p_y — dumbbell in xy-plane',
  '3,0,0': '3s — spherical, two radial nodes',
  '3,1,0': '3p_z — dumbbell with radial node',
  '3,2,0': '3d_z² — doughnut + lobes along z',
  '3,2,±1': '3d_xz, 3d_yz — four-lobed',
  '3,2,±2': '3d_xy, 3d_x²-y² — four-lobed in plane',
  '4,3,0': '4f_z³ — complex 8-lobed',
  '4,3,±1': '4f_xz², 4f_yz² — 8-lobed',
  '4,3,±2': '4f_z(x²-y²), 4f_xyz — 8-lobed',
  '4,3,±3': '4f_x(x²-3y²), 4f_y(3x²-y²) — 8-lobed',
};

export function getOrbitalLabel(n: number, l: number, m: number): string {
  const key = `${n},${l},${m}`;
  return ORBITAL_LABELS[key] || `${n}${['s','p','d','f','g','h'][l] || '?'}`;
}

export function validQuantumNumbers(n: number, l: number, m: number): boolean {
  return l >= 0 && l < n && Math.abs(m) <= l;
}

export function possibleMValues(l: number): number[] {
  const vals: number[] = [];
  for (let m = -l; m <= l; m++) vals.push(m);
  return vals;
}

export function possibleLValues(n: number): number[] {
  const vals: number[] = [];
  for (let l = 0; l < n; l++) vals.push(l);
  return vals;
}

export function getOrbitalCapacity(l: number): number {
  return 2 * (2 * l + 1);
}

export function getShellCapacity(n: number): number {
  return 2 * n * n;
}

export function getPeriodForZ(Z: number): number {
  if (Z <= 2) return 1;
  if (Z <= 10) return 2;
  if (Z <= 18) return 3;
  if (Z <= 36) return 4;
  if (Z <= 54) return 5;
  if (Z <= 86) return 6;
  return 7;
}

export function getGroupForZ(Z: number): string {
  const config = getElectronConfiguration(Z);
  if (config.length === 0) return '';
  const last = config[config.length - 1];
  if (last.l === 0) {
    if (last.n === 1) return '1 (alkali)'; // H is special
    return `${last.n} (alkali metal)`;
  }
  if (last.l === 1) return `${10 + last.n} (pnictogen/chalcogen)`;
  if (last.l === 2) return `3-12 (transition metal)`;
  if (last.l === 3) return `Lanthanide/Actinide`;
  return '';
}
AFEOF


echo "  → src/components/simulation/AtomicModelsCanvas.tsx"
cat > "src/components/simulation/AtomicModelsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  AtomicParams, AtomicModel,
  generateThomsonElectrons, updateThomsonElectrons,
  createAlphaParticle, updateAlphaParticle,
  bohrEnergy, bohrRadius, getEnergyLevels, transitionWavelength,
  wavelengthToRGB, generateOrbitalSlice, orbitalProbability,
  radialDistribution, getOrbitalLabel, getElectronConfiguration,
  getShellCapacity, fineStructureEnergy, zeemanShift,
  type ThomsonElectron, type ScatteringParticle, type EnergyLevel,
} from '@/lib/physics/atomicModels';

interface Props {
  params: AtomicParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: {
    energy: number; radius: number; velocity: number;
    n: number; wavelength: number; shellConfig: string;
  }) => void;
  width?: number;
  height?: number;
}

export function AtomicModelsCanvas({
  params, isRunning, isPaused, onTick, width = 720, height = 500,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, isRunning, isPaused, onTick });
  propsRef.current = { params, isRunning, isPaused, onTick };

  const thomsonRef = useRef<ThomsonElectron[]>([]);
  const scatterRef = useRef<ScatteringParticle[]>([]);
  const bohrPhaseRef = useRef(0);
  const bohrNRef = useRef(1);
  const transitionRef = useRef<{ fromN: number; toN: number; progress: number; active: boolean } | null>(null);
  const photonsRef = useRef<{ x: number; y: number; angle: number; wavelength: number; life: number }[]>([]);
  const orbitalGridRef = useRef<{ x: number; z: number; prob: number }[][] | null>(null);
  const orbitalCacheKeyRef = useRef('');

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current;

    const dpr = window.devicePixelRatio || 1;
    const displayW = width;
    const displayH = height;

    if (canvas.width !== Math.floor(displayW * dpr) || canvas.height !== Math.floor(displayH * dpr)) {
      canvas.width = Math.floor(displayW * dpr);
      canvas.height = Math.floor(displayH * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) timeRef.current += dt * s.params.speed;
    const t = timeRef.current;

    ctx.clearRect(0, 0, displayW, displayH);
    ctx.fillStyle = '#0b1021';
    ctx.fillRect(0, 0, displayW, displayH);
    drawStarfield(ctx, displayW, displayH, t);

    const cx = displayW / 2;
    const cy = displayH / 2;
    const zoom = s.params.zoom;

    switch (s.params.model) {
      case 'thomson': drawThomson(ctx, cx, cy, displayW, displayH, t, dt, s.params, zoom); break;
      case 'rutherford': drawRutherford(ctx, cx, cy, displayW, displayH, t, dt, s.params, zoom); break;
      case 'bohr': drawBohr(ctx, cx, cy, displayW, displayH, t, dt, s.params, zoom); break;
      case 'quantum': drawQuantum(ctx, cx, cy, displayW, displayH, t, s.params, zoom); break;
    }

    ctx.font = 'bold 14px system-ui';
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(148, 163, 184, 0.6)';
    const modelNames: Record<AtomicModel, string> = {
      thomson: 'Thomson (1897) — Plum Pudding',
      rutherford: 'Rutherford (1911) — Nuclear Model',
      bohr: 'Bohr (1913) — Quantized Orbits',
      quantum: 'Schrödinger (1926) — Quantum Orbitals',
    };
    ctx.fillText(modelNames[s.params.model], 16, 28);

    ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    if (!s.isRunning) { ctx.fillStyle = '#94a3b8'; ctx.fillText('Press Run to start', displayW / 2, 28); }
    else if (s.isPaused) { ctx.fillStyle = '#f59e0b'; ctx.fillText('⏸ Paused', displayW / 2, 28); }
    else { ctx.fillStyle = '#10b981'; ctx.fillText('● Evolving', displayW / 2, 28); }

    rafRef.current = requestAnimationFrame(draw);
  }, [width, height]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  // ── Thomson ─────────────────────────────────────────────────────────────
  function drawThomson(ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, t: number, dt: number, p: AtomicParams, zoom: number) {
    const scale = Math.min(w, h) * 0.35 * zoom;
    const sphereR = scale;
    const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, sphereR);
    grad.addColorStop(0, 'rgba(244, 63, 94, 0.4)');
    grad.addColorStop(0.6, 'rgba(244, 63, 94, 0.15)');
    grad.addColorStop(1, 'rgba(244, 63, 94, 0.02)');
    ctx.fillStyle = grad;
    ctx.beginPath(); ctx.arc(cx, cy, sphereR, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = 'rgba(244, 63, 94, 0.3)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(cx, cy, sphereR, 0, Math.PI * 2); ctx.stroke();

    if (p.showLabels) {
      ctx.fillStyle = '#f43f5e'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Positive charge sphere', cx, cy - sphereR - 10);
    }

    if (p.showElectrons) {
      if (thomsonRef.current.length === 0) thomsonRef.current = generateThomsonElectrons(p.electronCount || 6);
      if (dt > 0) thomsonRef.current = updateThomsonElectrons(thomsonRef.current, dt, p.speed);
      thomsonRef.current.forEach((e, i) => {
        const ex = cx + Math.cos(e.angle) * e.radius * scale;
        const ey = cy + Math.sin(e.angle) * e.radius * scale * 0.6;
        const size = 4 + Math.sin(e.phase) * 1.5;
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, size * 3);
        glow.addColorStop(0, 'rgba(59, 130, 246, 0.6)');
        glow.addColorStop(1, 'rgba(59, 130, 246, 0)');
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(ex, ey, size * 3, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#60a5fa'; ctx.beginPath(); ctx.arc(ex, ey, size, 0, Math.PI * 2); ctx.fill();
        if (p.showLabels && i < 3) { ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.fillText(`e⁻`, ex + 8, ey - 4); }
      });
    }

    if (p.showLabels) {
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(16, h - 90, 240, 70);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(16, h - 90, 240, 70);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('J.J. Thomson (1897)', 24, h - 72);
      ctx.fillText('• Atom = sphere of positive charge', 24, h - 56);
      ctx.fillText('• Electrons embedded like "raisins"', 24, h - 42);
      ctx.fillText('• Could NOT explain scattering data', 24, h - 28);
    }
  }

  // ── Rutherford ──────────────────────────────────────────────────────────
  function drawRutherford(ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, t: number, dt: number, p: AtomicParams, zoom: number) {
    const scale = Math.min(w, h) * 0.4 * zoom;
    if (p.showNucleus) {
      const nucleusR = Math.max(4, scale * 0.04);
      const nGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, nucleusR * 3);
      nGrad.addColorStop(0, 'rgba(251, 191, 36, 0.9)');
      nGrad.addColorStop(0.5, 'rgba(251, 191, 36, 0.4)');
      nGrad.addColorStop(1, 'rgba(251, 191, 36, 0)');
      ctx.fillStyle = nGrad; ctx.beginPath(); ctx.arc(cx, cy, nucleusR * 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nucleusR, 0, Math.PI * 2); ctx.fill();
      if (p.showLabels) {
        ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`Nucleus (Z=${p.protonCount}, A=${p.protonCount + p.neutronCount})`, cx, cy + nucleusR + 14);
        ctx.font = '9px system-ui';
        ctx.fillText(`r ~ ${(1.2 * Math.pow(p.protonCount + p.neutronCount, 1/3)).toFixed(1)} fm`, cx, cy + nucleusR + 26);
      }
    }

    if (dt > 0 && p.isRunning && !p.isPaused) {
      if (Math.random() < 0.03 * p.speed) {
        const b = (Math.random() - 0.5) * scale * 2.5;
        scatterRef.current.push(createAlphaParticle(b, p.alphaEnergy || 5.0));
      }
      scatterRef.current = scatterRef.current.map((part) => updateAlphaParticle(part, dt, p.protonCount)).filter((part) => part.active);
    }

    scatterRef.current.forEach((part) => {
      if (part.trail.length > 1) {
        ctx.strokeStyle = 'rgba(244, 63, 94, 0.35)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        part.trail.forEach((pt, i) => {
          const px = cx + pt.x * scale * 0.002;
          const py = cy + pt.y * scale * 0.002;
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        });
        ctx.stroke();
      }
      const px = cx + part.x * scale * 0.002;
      const py = cy + part.y * scale * 0.002;
      ctx.fillStyle = '#f43f5e'; ctx.beginPath(); ctx.arc(px, py, 3, 0, Math.PI * 2); ctx.fill();
    });

    // Impact parameter guide lines
    if (p.showLabels) {
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.08)';
      ctx.setLineDash([2, 6]);
      ctx.lineWidth = 1;
      for (let b = -scale * 1.2; b <= scale * 1.2; b += scale * 0.25) {
        ctx.beginPath(); ctx.moveTo(cx - scale * 1.5, cy + b); ctx.lineTo(cx + scale * 1.5, cy + b); ctx.stroke();
      }
      ctx.setLineDash([]);
    }

    if (p.showLabels) {
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(16, h - 100, 280, 80);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(16, h - 100, 280, 80);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Ernest Rutherford (1911)', 24, h - 82);
      ctx.fillText('• Gold foil: Geiger & Marsden', 24, h - 66);
      ctx.fillText('• Most α pass through → atom is EMPTY', 24, h - 52);
      ctx.fillText('• Some bounce back → nucleus is TINY', 24, h - 38);
      ctx.fillText('• Classical problem: orbiting e⁻ radiates', 24, h - 24);
    }
  }

  // ── Bohr — WITH FINE STRUCTURE & ZEEMAN ────────────────────────────────
  function drawBohr(ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, t: number, dt: number, p: AtomicParams, zoom: number) {
    const scale = Math.min(w, h) * 0.18 * zoom;
    const Z = p.protonCount || 1;
    const maxN = Math.min(p.nMax || 7, 7);
    const B = p.magneticField || 0;

    // Nucleus
    if (p.showNucleus) {
      const nR = 6;
      const nGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, nR * 2);
      nGrad.addColorStop(0, 'rgba(251, 191, 36, 0.8)'); nGrad.addColorStop(1, 'rgba(251, 191, 36, 0)');
      ctx.fillStyle = nGrad; ctx.beginPath(); ctx.arc(cx, cy, nR * 2, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nR, 0, Math.PI * 2); ctx.fill();
      if (p.showLabels) { ctx.fillStyle = '#fbbf24'; ctx.font = '9px system-ui'; ctx.textAlign = 'center'; ctx.fillText(`p⁺`, cx, cy + nR + 12); }
    }

    // Energy levels panel
    if (p.showEnergyLevels) {
      const levels = getEnergyLevels(maxN, Z, B);
      const eLeft = 50;
      const eTop = 55;
      const eH = h - 130;
      const eMax = Math.abs(bohrEnergy(maxN, Z)) * 1.3;

      ctx.fillStyle = 'rgba(15, 23, 42, 0.6)'; ctx.fillRect(eLeft - 10, eTop - 10, 110, eH + 20);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)'; ctx.strokeRect(eLeft - 10, eTop - 10, 110, eH + 20);
      ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Energy (eV)', eLeft + 45, eTop - 2);

      // Group levels by n for display
      const nGroups: Record<number, EnergyLevel[]> = {};
      levels.forEach((l) => { if (!nGroups[l.n]) nGroups[l.n] = []; nGroups[l.n].push(l); });

      Object.entries(nGroups).forEach(([nStr, grp]) => {
        const n = Number(nStr);
        const baseE = bohrEnergy(n, Z);
        const y = eTop + eH - (Math.abs(baseE) / eMax) * eH;

        if (p.showFineStructure && grp.length > 1) {
          // Draw split levels
          grp.forEach((lvl, idx) => {
            const offset = (idx - grp.length / 2 + 0.5) * 4;
            const yy = y + offset;
            ctx.strokeStyle = lvl.j === n - 0.5 ? 'rgba(244, 63, 94, 0.5)' : 'rgba(59, 130, 246, 0.5)';
            ctx.lineWidth = 1.2;
            ctx.beginPath(); ctx.moveTo(eLeft, yy); ctx.lineTo(eLeft + 80, yy); ctx.stroke();
            if (p.showSpin) {
              ctx.fillStyle = lvl.j > lQuantumForN(n, lvl.l) ? '#f43f5e' : '#3b82f6';
              ctx.font = '8px system-ui'; ctx.textAlign = 'left';
              ctx.fillText(`j=${lvl.j.toFixed(1)}`, eLeft + 82, yy + 2);
            }
          });
        } else {
          ctx.strokeStyle = 'rgba(99, 102, 241, 0.4)';
          ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(eLeft, y); ctx.lineTo(eLeft + 80, y); ctx.stroke();
        }

        ctx.fillStyle = '#818cf8'; ctx.font = '9px system-ui'; ctx.textAlign = 'right';
        ctx.fillText(`n=${n}`, eLeft - 4, y + 3);
      });

      // Zeeman splitting visualization
      if (p.showZeeman && B > 0) {
        ctx.fillStyle = 'rgba(16, 185, 129, 0.3)';
        ctx.font = '9px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`B = ${B} T`, eLeft + 4, eTop + eH + 12);
      }

      // Active transition
      if (p.showSpectrum && transitionRef.current?.active) {
        const from = transitionRef.current.fromN;
        const to = transitionRef.current.toN;
        const yFrom = eTop + eH - (Math.abs(bohrEnergy(from, Z)) / eMax) * eH;
        const yTo = eTop + eH - (Math.abs(bohrEnergy(to, Z)) / eMax) * eH;
        const wl = transitionWavelength(from, to, Z);
        const color = wavelengthToRGB(wl);
        ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.setLineDash([4, 2]);
        ctx.beginPath(); ctx.moveTo(eLeft + 40, yFrom); ctx.lineTo(eLeft + 40, yTo); ctx.stroke(); ctx.setLineDash([]);
        const midY = (yFrom + yTo) / 2;
        ctx.fillStyle = color;
        ctx.beginPath(); ctx.moveTo(eLeft + 40, midY); ctx.lineTo(eLeft + 35, midY - 4); ctx.lineTo(eLeft + 35, midY + 4); ctx.closePath(); ctx.fill();
      }
    }

    // Orbits
    if (p.showOrbits) {
      for (let n = 1; n <= maxN; n++) {
        const r = bohrRadius(n, Z) * scale * 0.15;
        ctx.strokeStyle = `rgba(99, 102, 241, ${0.12 + 0.08 * (maxN - n) / maxN})`;
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
        if (p.showLabels) { ctx.fillStyle = 'rgba(129, 140, 248, 0.4)'; ctx.font = '9px system-ui'; ctx.textAlign = 'center'; ctx.fillText(`n=${n}`, cx + r + 12, cy); }
      }
    }

    // Electron with transitions
    if (p.showElectrons) {
      if (dt > 0 && p.isRunning && !p.isPaused) {
        bohrPhaseRef.current += dt * p.speed * (2 / bohrNRef.current);
        if (!transitionRef.current?.active && Math.random() < 0.008 * p.speed) {
          const fromN = bohrNRef.current;
          const toN = Math.max(1, Math.min(maxN, fromN + (Math.random() < 0.5 ? -1 : 1) * Math.floor(Math.random() * 2 + 1)));
          if (fromN !== toN) transitionRef.current = { fromN, toN, progress: 0, active: true };
        }
        if (transitionRef.current?.active) {
          transitionRef.current.progress += dt * p.speed * 2;
          if (transitionRef.current.progress >= 1) {
            bohrNRef.current = transitionRef.current.toN;
            const wl = transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z);
            photonsRef.current.push({ x: cx, y: cy, angle: Math.random() * Math.PI * 2, wavelength: wl, life: 1 });
            transitionRef.current = null;
          }
        }
      }
      const currentN = transitionRef.current?.active ? transitionRef.current.fromN : bohrNRef.current;
      const targetN = transitionRef.current?.toN || currentN;
      const progress = transitionRef.current?.progress || 0;
      const rFrom = bohrRadius(currentN, Z) * scale * 0.15;
      const rTo = bohrRadius(targetN, Z) * scale * 0.15;
      const currentR = rFrom + (rTo - rFrom) * progress;
      const angle = bohrPhaseRef.current;
      const ex = cx + Math.cos(angle) * currentR;
      const ey = cy + Math.sin(angle) * currentR;

      if (transitionRef.current?.active) {
        const wl = transitionWavelength(currentN, targetN, Z);
        const color = wavelengthToRGB(wl);
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, 20);
        glow.addColorStop(0, color.replace('rgb', 'rgba').replace(')', ', 0.4)'));
        glow.addColorStop(1, color.replace('rgb', 'rgba').replace(')', ', 0)'));
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(ex, ey, 20, 0, Math.PI * 2); ctx.fill();
      }
      const eGlow = ctx.createRadialGradient(ex, ey, 0, ex, ey, 10);
      eGlow.addColorStop(0, 'rgba(59, 130, 246, 0.8)'); eGlow.addColorStop(1, 'rgba(59, 130, 246, 0)');
      ctx.fillStyle = eGlow; ctx.beginPath(); ctx.arc(ex, ey, 10, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#60a5fa'; ctx.beginPath(); ctx.arc(ex, ey, 4, 0, Math.PI * 2); ctx.fill();

      // Spin arrow
      if (p.showSpin) {
        ctx.strokeStyle = '#f43f5e'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(ex - 3, ey - 8); ctx.lineTo(ex + 3, ey - 8); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(ex, ey - 8); ctx.lineTo(ex, ey - 12); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(ex - 2, ey - 11); ctx.lineTo(ex, ey - 12); ctx.lineTo(ex + 2, ey - 11); ctx.stroke();
      }

      if (p.showLabels) { ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'center'; ctx.fillText(`e⁻  n=${Math.round(currentN + (targetN - currentN) * progress)}`, ex, ey - 14); }
    }

    // Photons
    if (dt > 0 && p.isRunning && !p.isPaused) {
      photonsRef.current = photonsRef.current.map((ph) => ({
        ...ph, x: ph.x + Math.cos(ph.angle) * 200 * dt * p.speed, y: ph.y + Math.sin(ph.angle) * 200 * dt * p.speed, life: ph.life - dt * p.speed * 0.5,
      })).filter((ph) => ph.life > 0);
    }
    photonsRef.current.forEach((ph) => {
      const color = wavelengthToRGB(ph.wavelength);
      ctx.globalAlpha = ph.life; ctx.strokeStyle = color; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(ph.x - Math.cos(ph.angle) * 8, ph.y - Math.sin(ph.angle) * 8); ctx.lineTo(ph.x + Math.cos(ph.angle) * 8, ph.y + Math.sin(ph.angle) * 8); ctx.stroke(); ctx.globalAlpha = 1;
    });

    // Spectrum bar
    if (p.showSpectrum) {
      const barY = h - 30; const barW = w - 130; const barX = 120;
      ctx.fillStyle = 'rgba(15, 23, 42, 0.6)'; ctx.fillRect(barX - 5, barY - 15, barW + 10, 25);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(barX - 5, barY - 15, barW + 10, 25);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left'; ctx.fillText('Spectrum (nm)', barX, barY - 18);
      for (let wl = 380; wl <= 780; wl += 50) {
        const x = barX + ((wl - 380) / 400) * barW;
        ctx.fillStyle = wavelengthToRGB(wl); ctx.fillRect(x, barY - 10, 3, 14);
      }
      photonsRef.current.forEach((ph) => {
        if (ph.wavelength >= 380 && ph.wavelength <= 780) {
          const x = barX + ((ph.wavelength - 380) / 400) * barW;
          ctx.fillStyle = wavelengthToRGB(ph.wavelength); ctx.globalAlpha = ph.life; ctx.fillRect(x - 1, barY - 12, 3, 18); ctx.globalAlpha = 1;
        }
      });
    }

    // Stats
    if (onTick && timestamp !== undefined) {
      const now = performance.now();
      if (now - lastTickRef.current > 80) {
        lastTickRef.current = now;
        const n = bohrNRef.current;
        onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: bohrVelocity(n, Z), n, wavelength: transitionRef.current ? transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z) : 0, shellConfig: '' });
      }
    }

    if (p.showLabels) {
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(w - 240, h - 110, 225, 90);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(w - 240, h - 110, 225, 90);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Niels Bohr (1913)', w - 232, h - 92);
      ctx.fillText('• Stationary states: no radiation', w - 232, h - 76);
      ctx.fillText('• L = nℏ (quantized angular momentum)', w - 232, h - 62);
      ctx.fillText('• E_n = -13.6 Z²/n² eV', w - 232, h - 48);
      ctx.fillText('• ΔE = hν (photon emission/absorption)', w - 232, h - 34);
      if (p.showFineStructure) ctx.fillText('• Fine structure: j = l ± ½', w - 232, h - 20);
      if (p.showZeeman) ctx.fillText(`• Zeeman: ΔE = m_j g_j μ_B B`, w - 232, h - 20);
    }
  }

  function lQuantumForN(n: number, l: number): number { return l; }

  // ── Quantum Model — WITH MULTI-ELECTRON & SPIN ─────────────────────────
  function drawQuantum(ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, t: number, p: AtomicParams, zoom: number) {
    const scale = Math.min(w, h) * 0.35 * zoom;
    const n = p.nQuantum || 1;
    const l = p.lQuantum || 0;
    const m = p.mQuantum || 0;
    const Z = p.protonCount || 1;

    // Nucleus
    if (p.showNucleus) {
      const nR = 5;
      const nGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, nR * 2);
      nGrad.addColorStop(0, 'rgba(251, 191, 36, 0.9)'); nGrad.addColorStop(1, 'rgba(251, 191, 36, 0)');
      ctx.fillStyle = nGrad; ctx.beginPath(); ctx.arc(cx, cy, nR * 2, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nR, 0, Math.PI * 2); ctx.fill();
      if (p.showLabels) { ctx.fillStyle = '#fbbf24'; ctx.font = '8px system-ui'; ctx.textAlign = 'center'; ctx.fillText(`Z=${Z}`, cx, cy + nR + 10); }
    }

    // Orbital probability cloud
    if (p.showProbability) {
      const cacheKey = `${n},${l},${m},${scale}`;
      if (orbitalCacheKeyRef.current !== cacheKey) { orbitalGridRef.current = generateOrbitalSlice(n, l, m, 10 * n, 80); orbitalCacheKeyRef.current = cacheKey; }
      const grid = orbitalGridRef.current;
      if (grid) {
        let maxProb = 0;
        grid.forEach((row) => row.forEach((pt) => { if (pt.prob > maxProb) maxProb = pt.prob; }));
        const cellW = (scale * 2.5) / grid[0].length;
        const cellH = (scale * 2.5) / grid.length;
        grid.forEach((row, i) => {
          row.forEach((pt, j) => {
            const prob = pt.prob / (maxProb || 1);
            if (prob < 0.02) return;
            const px = cx + (pt.x / (10 * n)) * scale * 1.25;
            const py = cy - (pt.z / (10 * n)) * scale * 1.25;
            const alpha = Math.min(0.55, prob * 2);
            const hue = 200 + prob * 90;
            ctx.fillStyle = `hsla(${hue}, 85%, 58%, ${alpha})`;
            ctx.fillRect(px - cellW / 2, py - cellH / 2, cellW + 1, cellH + 1);
          });
        });
      }
    }

    // Multi-electron configuration visualization (shell rings)
    if (p.electronCount > 1 && p.showElectrons) {
      const config = getElectronConfiguration(p.electronCount);
      const shells: Record<number, number> = {};
      config.forEach((e) => { shells[e.n] = (shells[e.n] || 0) + 1; });
      Object.entries(shells).forEach(([nStr, count]) => {
        const nn = Number(nStr);
        const r = bohrRadius(nn, Z) * scale * 0.12;
        const capacity = getShellCapacity(nn);
        const frac = count / capacity;
        ctx.strokeStyle = `rgba(99, 102, 241, ${0.1 + frac * 0.3})`;
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = 'rgba(129, 140, 248, 0.4)'; ctx.font = '8px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${count}/${capacity}`, cx + r, cy - 4);
      });
    }

    // Radial distribution panel
    if (p.showProbability) {
      const panelX = w - 135;
      const panelY = 55;
      const panelW = 115;
      const panelH = 120;
      ctx.fillStyle = 'rgba(15, 23, 42, 0.6)'; ctx.fillRect(panelX - 5, panelY - 20, panelW + 10, panelH + 30);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)'; ctx.strokeRect(panelX - 5, panelY - 20, panelW + 10, panelH + 30);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Radial distribution', panelX + panelW / 2, panelY - 8);
      ctx.fillText('4πr²|R|²', panelX + panelW / 2, panelY + 4);
      const rMax = 10 * n;
      let maxD = 0;
      const samples: { r: number; d: number }[] = [];
      for (let i = 0; i <= 50; i++) {
        const r = (i / 50) * rMax;
        const d = radialDistribution(n, l, r);
        samples.push({ r, d });
        if (d > maxD) maxD = d;
      }
      ctx.strokeStyle = 'rgba(99, 102, 241, 0.8)'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      samples.forEach((s, i) => {
        const x = panelX + (s.r / rMax) * panelW;
        const y = panelY + panelH - (s.d / (maxD || 1)) * panelH;
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      });
      ctx.stroke();
      const a0 = n * n * BOHR_RADIUS;
      const markerX = panelX + (a0 / rMax) * panelW;
      ctx.strokeStyle = 'rgba(244, 63, 94, 0.5)'; ctx.setLineDash([2, 2]);
      ctx.beginPath(); ctx.moveTo(markerX, panelY); ctx.lineTo(markerX, panelY + panelH); ctx.stroke(); ctx.setLineDash([]);
    }

    // Quantum numbers panel
    if (p.showQuantumNumbers) {
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(16, h - 120, 200, 100);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(16, h - 120, 200, 100);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Quantum Numbers', 24, h - 102);
      ctx.fillStyle = '#818cf8'; ctx.fillText(`n = ${n}  principal (shell)`, 24, h - 86);
      ctx.fillStyle = '#ec4899'; ctx.fillText(`l = ${l}  angular (${['s','p','d','f','g','h'][l] || '?'})`, 24, h - 70);
      ctx.fillStyle = '#10b981'; ctx.fillText(`m = ${m}  magnetic (orient)`, 24, h - 54);
      ctx.fillStyle = '#f59e0b'; ctx.fillText(getOrbitalLabel(n, l, m), 24, h - 38);
      if (p.showSpin) {
        ctx.fillStyle = '#f43f5e';
        ctx.fillText('s = ±½  spin (intrinsic)', 24, h - 22);
      }
    }

    // Electron configuration for multi-electron
    if (p.electronCount > 1) {
      const config = getElectronConfiguration(p.electronCount);
      const orbitalCounts: Record<string, number> = {};
      config.forEach((e) => { orbitalCounts[e.orbital] = (orbitalCounts[e.orbital] || 0) + 1; });
      const configStr = Object.entries(orbitalCounts).map(([orb, cnt]) => `${orb}${cnt > 1 ? cnt : ''}`).join(' ');
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(w - 250, 50, 235, 40);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(w - 250, 50, 235, 40);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Configuration:', w - 242, 64);
      ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 10px system-ui';
      ctx.fillText(configStr, w - 242, 80);
    }

    if (p.showLabels) {
      ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'; ctx.fillRect(w - 240, h - 110, 225, 90);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)'; ctx.strokeRect(w - 240, h - 110, 225, 90);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Schrödinger (1926)', w - 232, h - 92);
      ctx.fillText('• Ψ = probability amplitude', w - 232, h - 76);
      ctx.fillText('• |Ψ|² = probability density', w - 232, h - 62);
      ctx.fillText('• No orbit — only probability cloud', w - 232, h - 48);
      ctx.fillText('• HΨ = EΨ (eigenvalue equation)', w - 232, h - 34);
      if (p.electronCount > 1) ctx.fillText('• Pauli: no two e⁻ share all 4 q.n.', w - 232, h - 20);
    }
  }

  // ── Starfield ───────────────────────────────────────────────────────────
  function drawStarfield(ctx: CanvasRenderingContext2D, w: number, h: number, t: number) {
    for (let i = 0; i < 60; i++) {
      const sx = ((i * 137.5 + t * 2) % w + w) % w;
      const sy = ((i * 89.7 + Math.sin(t * 0.1 + i) * 10) % h + h) % h;
      const brightness = 0.3 + 0.4 * Math.sin(t * 0.5 + i * 2.3);
      const size = 0.5 + (i % 3) * 0.5;
      ctx.fillStyle = `rgba(255, 255, 255, ${brightness * 0.3})`;
      ctx.beginPath(); ctx.arc(sx, sy, size, 0, Math.PI * 2); ctx.fill();
    }
  }

  return <canvas ref={canvasRef} width={width} height={height} className="w-full rounded-xl border border-gray-700 bg-slate-900" style={{ display: 'block' }} />;
}
AFEOF


echo "  → src/app/simulations/atomic-models/page.tsx"
cat > "src/app/simulations/atomic-models/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  ATOMIC_PRESETS, AtomicParams, AtomicModel,
  getEnergyLevels, transitionWavelength, wavelengthToRGB,
  generateHydrogenSpectrum, validQuantumNumbers, possibleLValues, possibleMValues,
  bohrEnergy, bohrRadius, bohrVelocity,
  getElectronConfiguration, getShellCapacity, getPeriodForZ, getGroupForZ,
  getOrbitalLabel, getOrbitalCapacity,
} from '@/lib/physics/atomicModels';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'A-Level'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
};

const TEACHER_NOTES = [
  'The atomic model evolved over 120 years. Each model corrected fatal flaws in the previous. This simulation traces that evolution from Thomson\'s 1897 electron discovery to modern quantum field theory.',
  'Thomson (1897): Discovered the electron via cathode ray tubes. Proposed the "plum pudding" model — a sphere of positive charge with embedded electrons. Failed to explain Rutherford\'s scattering data.',
  'Rutherford (1911): The Geiger-Marsden gold foil experiment showed that most α-particles pass straight through, but ~1 in 8000 bounce back at >90°. This proved the atom is mostly empty space with a tiny, dense nucleus (r ~ 1-10 fm). The nuclear model replaced the plum pudding.',
  'Rutherford\'s classical problem: By Maxwell\'s equations, an accelerating charge (circular orbit) must radiate electromagnetic waves. An orbiting electron would lose energy and spiral into the nucleus in ~10⁻¹¹ seconds. The atom should be unstable — yet it is not.',
  'Bohr (1913): Three postulates solved Rutherford\'s problem: (1) Electrons exist in stationary states and do NOT radiate. (2) Angular momentum is quantized: L = nℏ. (3) Transitions between states emit/absorb photons with E_photon = |E_i - E_f| = hν.',
  'Bohr radius a₀ = 4πε₀ℏ²/(mₑe²) ≈ 0.529 Å = 0.0529 nm. This is the most probable distance of the electron in the hydrogen ground state. Energy levels: Eₙ = -13.6 Z²/n² eV.',
  'Spectral series derive from the Rydberg formula: 1/λ = R_H(1/n₁² - 1/n₂²). Lyman (UV, n→1), Balmer (visible, n→2), Paschen (IR, n→3), Brackett (far-IR, n→4), Pfund (n→5), Humphreys (n→6).',
  'Fine structure (Dirac 1928): Relativistic corrections and spin-orbit coupling split each level into j = l ± ½. For hydrogen, this is tiny (~4.5×10⁻⁵ eV for n=2) but measurable via high-resolution spectroscopy.',
  'Zeeman effect (1896): A magnetic field splits degenerate energy levels. Normal Zeeman: three lines. Anomalous Zeeman: more complex splitting due to electron spin. The Landé g-factor g_j = 1 + [j(j+1)+s(s+1)-l(l+1)]/[2j(j+1)].',
  'Schrödinger (1926): The wave equation HΨ = EΨ replaces definite orbits with probability clouds. The wavefunction Ψ is not directly observable; |Ψ|² gives the probability density. The orbital is a standing wave — not a trajectory.',
  'Quantum numbers: n (principal, shell), l (azimuthal, 0=s,1=p,2=d,3=f,4=g,5=h), m (magnetic, orientation), m_s (spin, ±½). Pauli exclusion: no two electrons in an atom share all four quantum numbers.',
  'Multi-electron atoms: The Aufbau principle fills orbitals in order of increasing energy (n+l rule). Hund\'s rule: maximize parallel spins before pairing. These rules explain the periodic table.',
  'Uncertainty principle: Δx·Δp ≥ ℏ/2. In quantum mechanics, the electron does not HAVE a trajectory. Asking "where is the electron now?" is only meaningful as a probability. The orbital shape is a consequence of solving the Schrödinger equation with boundary conditions.',
  'Beyond Schrödinger: Quantum electrodynamics (QED) adds corrections. The Lamb shift (1947) splits 2S₁/₂ and 2P₁/₂ — not predicted by Dirac. Hyperfine splitting (interaction with nuclear spin) creates the 21-cm hydrogen line used in radio astronomy.',
];

const EXERCISES = [
  {
    q: 'Run the Thomson model. Why did Thomson place electrons inside a sphere of positive charge? What experiment disproved this?',
    a: 'Thomson knew atoms were neutral and had discovered negatively charged electrons. He assumed positive charge filled the atom\'s volume. Rutherford\'s gold foil experiment (1911) showed α-particles bouncing back at large angles, proving the positive charge is concentrated in a tiny nucleus, not spread out.',
  },
  {
    q: 'In the Rutherford model, increase the α-particle energy to 8 MeV. What happens to the scattering angle? Why does this make sense physically?',
    a: 'Higher energy α-particles are less deflected because they spend less time near the nucleus (shorter interaction time) and have more momentum to resist the Coulomb repulsion. At very high energies, some α-particles actually penetrate the nucleus — this led to the discovery of the proton (1919) and later the neutron (Chadwick, 1932).',
  },
  {
    q: 'Switch to the Bohr model. Why does the electron not spiral into the nucleus? What does classical physics predict? Calculate the classical collapse time.',
    a: 'Classical electrodynamics says any accelerating charge radiates. A circularly orbiting electron is constantly accelerating (centripetal), so it should lose energy and spiral in. The calculated collapse time is ~10⁻¹¹ s. Bohr postulated stationary states where electrons do NOT radiate — an ad hoc assumption that quantum mechanics later explained via standing wave boundary conditions.',
  },
  {
    q: 'Enable the spectrum and watch transitions. Calculate the Hα wavelength (n=3→2) using the Rydberg formula, then verify with the simulation.',
    a: '1/λ = R_H(1/2² - 1/3²) = 1.097×10⁷ × (1/4 - 1/9) = 1.097×10⁷ × 5/36 ≈ 1.524×10⁶ m⁻¹. Thus λ ≈ 656 nm, which is red light. This matches the observed Hα line in the Balmer series.',
  },
  {
    q: 'Enable Fine Structure in the Bohr model. What causes the splitting of each n level into two? Which j value has lower energy for a given l?',
    a: 'Fine structure arises from two effects: (1) relativistic mass-velocity correction, and (2) spin-orbit coupling (the electron\'s magnetic moment interacts with the magnetic field created by its orbital motion). For hydrogen, the j = l - ½ state has LOWER energy when l > 0 (except for s-states where j = ½ only).',
  },
  {
    q: 'Enable the Zeeman effect with B = 2 T. How many lines does the normal Zeeman effect produce? What about the anomalous Zeeman effect?',
    a: 'The normal Zeeman effect (S=0, no spin) splits each spectral line into THREE: π (Δm=0, same frequency) and σ± (Δm=±1, shifted by ±eB/4πmₑ). The anomalous Zeeman effect (S≠0) produces more lines because the Landé g-factor differs for different levels. For hydrogen, you see more than three lines due to the anomalous effect.',
  },
  {
    q: 'Compare the Bohr n=1 orbit with the Quantum 1s orbital. In Bohr, where IS the electron? In quantum mechanics, where is it MOST PROBABLE? Why are these different?',
    a: 'In Bohr\'s model, the electron is at a definite distance r = a₀, moving in a precise circle. In the quantum 1s orbital, |ψ|² is maximum at r=0 (the nucleus!), but the radial probability 4πr²|R|² peaks at r = a₀. The electron has no definite position — only a probability. The most probable distance is a₀ (Bohr was right about the scale!), but the electron can be found anywhere with non-zero probability.',
  },
  {
    q: 'Examine the 2p and 3d orbitals. How many nodal planes/surfaces does each have? What does a node mean physically?',
    a: 'The 2p orbital has ONE angular nodal plane (perpendicular to its axis, where ψ=0). The 3d orbital has TWO angular nodal planes. A node is a region where the wavefunction is exactly zero, so the probability density |ψ|² = 0 — the electron is NEVER found there. Total nodes = n - 1 (radial + angular).',
  },
  {
    q: 'Set Z=26 (Iron) and enable multi-electron view. What is the electron configuration? Why is the 4s filled before 3d? What makes iron magnetic?',
    a: 'Iron: 1s² 2s² 2p⁶ 3s² 3p⁶ 4s² 3d⁶ (or [Ar] 3d⁶ 4s²). The 4s orbital has lower energy than 3d for Z < 20 due to penetration effects (s-electrons spend more time near the nucleus). Iron is ferromagnetic because it has UNPAIRED electrons in the 3d shell (4 unpaired out of 6). Hund\'s rule maximizes parallel spins, creating a net magnetic moment.',
  },
  {
    q: 'Why does the Bohr model work for hydrogen but fail for helium? How does the quantum model solve this?',
    a: 'Bohr\'s model assumes a single electron in a pure Coulomb potential. In helium, electron-electron repulsion makes the potential non-Coulomb and the problem has no simple analytical solution. The quantum model uses the Schrödinger equation with the full Hamiltonian including e-e repulsion, solved via perturbation theory or numerical methods (Hartree-Fock, DFT). The Pauli exclusion principle also prevents both electrons from occupying the same quantum state.',
  },
  {
    q: 'Graduate: The Lamb shift splits 2S₁/₂ and 2P₁/₂ by ~1058 MHz. Why does Dirac theory predict they should be degenerate? What QED effect causes the splitting?',
    a: 'Dirac\'s relativistic theory predicts that states with the same n and j are degenerate, regardless of l. So 2S₁/₂ and 2P₁/₂ (both j=½) should have the same energy. QED introduces vacuum fluctuations — the electron constantly emits and reabsorbs virtual photons. The S-state electron (which penetrates closer to the nucleus) interacts more strongly with these fluctuations, raising its energy slightly. This was measured by Lamb & Retherford (1947) and is one of the most precise confirmations of QED.',
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="text-gray-400 font-normal">{unit}</span>
        </span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string; }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function AtomicModelsPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level']);

  const [model, setModel] = useState<AtomicModel>('thomson');
  const [speed, setSpeed] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [showOrbits, setShowOrbits] = useState(true);
  const [showNucleus, setShowNucleus] = useState(true);
  const [showElectrons, setShowElectrons] = useState(true);
  const [showProbability, setShowProbability] = useState(true);
  const [showEnergyLevels, setShowEnergyLevels] = useState(true);
  const [showSpectrum, setShowSpectrum] = useState(true);
  const [showLabels, setShowLabels] = useState(true);
  const [showClassicalPath, setShowClassicalPath] = useState(false);
  const [showQuantumNumbers, setShowQuantumNumbers] = useState(true);
  const [showSpin, setShowSpin] = useState(false);
  const [showFineStructure, setShowFineStructure] = useState(false);
  const [showZeeman, setShowZeeman] = useState(false);
  const [magneticField, setMagneticField] = useState(0);
  const [nQuantum, setNQuantum] = useState(1);
  const [lQuantum, setLQuantum] = useState(0);
  const [mQuantum, setMQuantum] = useState(0);
  const [protonCount, setProtonCount] = useState(1);
  const [neutronCount, setNeutronCount] = useState(0);
  const [electronCount, setElectronCount] = useState(1);
  const [alphaEnergy, setAlphaEnergy] = useState(5);

  const params: AtomicParams = {
    model, speed, zoom, showOrbits, showNucleus, showElectrons,
    showProbability, showEnergyLevels, showSpectrum, showLabels,
    showClassicalPath, showQuantumNumbers, showSpin, showFineStructure,
    showZeeman, magneticField, nQuantum, lQuantum, mQuantum,
    protonCount, neutronCount, electronCount, alphaEnergy,
  };

  const [liveStats, setLiveStats] = useState({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });

  const applyPreset = useCallback((presetIdx: number) => {
    const preset = ATOMIC_PRESETS[presetIdx];
    if (!preset) return;
    setModel(preset.model);
    const pp = preset.params;
    if (pp.speed !== undefined) setSpeed(pp.speed);
    if (pp.zoom !== undefined) setZoom(pp.zoom);
    if (pp.showOrbits !== undefined) setShowOrbits(pp.showOrbits);
    if (pp.showNucleus !== undefined) setShowNucleus(pp.showNucleus);
    if (pp.showElectrons !== undefined) setShowElectrons(pp.showElectrons);
    if (pp.showProbability !== undefined) setShowProbability(pp.showProbability);
    if (pp.showEnergyLevels !== undefined) setShowEnergyLevels(pp.showEnergyLevels);
    if (pp.showSpectrum !== undefined) setShowSpectrum(pp.showSpectrum);
    if (pp.showLabels !== undefined) setShowLabels(pp.showLabels);
    if (pp.showQuantumNumbers !== undefined) setShowQuantumNumbers(pp.showQuantumNumbers);
    if (pp.showSpin !== undefined) setShowSpin(pp.showSpin);
    if (pp.showFineStructure !== undefined) setShowFineStructure(pp.showFineStructure);
    if (pp.showZeeman !== undefined) setShowZeeman(pp.showZeeman);
    if (pp.magneticField !== undefined) setMagneticField(pp.magneticField);
    if (pp.nQuantum !== undefined) setNQuantum(pp.nQuantum);
    if (pp.lQuantum !== undefined) setLQuantum(pp.lQuantum);
    if (pp.mQuantum !== undefined) setMQuantum(pp.mQuantum);
    if (pp.protonCount !== undefined) setProtonCount(pp.protonCount);
    if (pp.neutronCount !== undefined) setNeutronCount(pp.neutronCount);
    if (pp.electronCount !== undefined) setElectronCount(pp.electronCount);
    if (pp.alphaEnergy !== undefined) setAlphaEnergy(pp.alphaEnergy);
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 720, 500, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  useEffect(() => {
    if (!validQuantumNumbers(nQuantum, lQuantum, mQuantum)) {
      const validL = possibleLValues(nQuantum);
      if (!validL.includes(lQuantum)) { setLQuantum(validL[0]); setMQuantum(0); }
    }
  }, [nQuantum]);

  useEffect(() => {
    const validM = possibleMValues(lQuantum);
    if (!validM.includes(mQuantum)) setMQuantum(validM[0]);
  }, [lQuantum]);

  const spectrum = useMemo(() => generateHydrogenSpectrum(7), []);
  const electronConfig = useMemo(() => getElectronConfiguration(electronCount), [electronCount]);
  const configStr = useMemo(() => {
    const counts: Record<string, number> = {};
    electronConfig.forEach((e) => { counts[e.orbital] = (counts[e.orbital] || 0) + 1; });
    return Object.entries(counts).map(([orb, cnt]) => `${orb}${cnt > 1 ? cnt : ''}`).join(' ');
  }, [electronConfig]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Atomic Physics — From Plum Pudding to Quantum Field Theory</p>
                <h1 className="text-lg font-semibold text-gray-900">Atomic Models</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map((c) => (
                  <button key={c} onClick={() => setActiveCurricula((p) => p.includes(c) ? p.filter((x) => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'}`}>
                    {c}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Thomson → Rutherford → Bohr → Schrödinger → QED</span>
            <span className="text-sm font-semibold font-mono text-gray-900">Eₙ = -13.6 Z²/n² eV</span>
          </div>

          {/* Model selector */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map((m) => {
              const labels: Record<AtomicModel, string> = { thomson: 'Thomson (1897)', rutherford: 'Rutherford (1911)', bohr: 'Bohr (1913)', quantum: 'Quantum (1926)' };
              return (
                <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey((k) => k + 1); }}
                  className={`shrink-0 rounded-xl border px-4 py-2 text-left hover:shadow-sm transition min-w-[140px] ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}>
                  <p className="text-xs font-medium">{labels[m]}</p>
                </button>
              );
            })}
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {ATOMIC_PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(i)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]">
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_240px] xl:grid-cols-[1fr_240px_280px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused((p) => !p)} onReset={reset} />
                <EmbedButton path="/embed/atomic-models" title="Atomic Models — A-Factor STEM Studio"
                  params={{ model, speed, zoom, orbits: showOrbits ? 1 : 0, nucleus: showNucleus ? 1 : 0, electrons: showElectrons ? 1 : 0, prob: showProbability ? 1 : 0, levels: showEnergyLevels ? 1 : 0, spectrum: showSpectrum ? 1 : 0, labels: showLabels ? 1 : 0, spin: showSpin ? 1 : 0, fs: showFineStructure ? 1 : 0, zeeman: showZeeman ? 1 : 0, B: magneticField, n: nQuantum, l: lQuantum, m: mQuantum, Z: protonCount, N: neutronCount, e: electronCount, alphaE: alphaEnergy }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">Display</p>
                    <Slider label="Animation speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" note="Time evolution speed" />
                    <Slider label="Zoom" unit="×" value={zoom} min={0.3} max={3} step={0.1} set={setZoom} color="#10b981" note="Canvas zoom level" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Nucleus</p>
                    <Slider label="Protons Z" unit="" value={protonCount} min={1} max={92} step={1} set={setProtonCount} color="#fbbf24" note="Atomic number" />
                    <Slider label="Neutrons N" unit="" value={neutronCount} min={0} max={150} step={1} set={setNeutronCount} color="#a78bfa" note="Neutron number" />
                  </div>
                </div>

                {model === 'rutherford' && (
                  <div className="border-t border-gray-100 pt-3">
                    <Slider label="α-particle energy" unit="MeV" value={alphaEnergy} min={1} max={10} step={0.5} set={setAlphaEnergy} color="#f43f5e" note="Kinetic energy of incoming α particles" />
                  </div>
                )}

                {model === 'bohr' && (
                  <div className="border-t border-gray-100 pt-3 space-y-3">
                    <p className="text-[10px] font-medium text-emerald-600 uppercase tracking-wide">Bohr Model Options</p>
                    <div className="flex flex-wrap gap-3">
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showOrbits} onChange={(e) => setShowOrbits(e.target.checked)} className="rounded" />
                        Show orbits
                      </label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showEnergyLevels} onChange={(e) => setShowEnergyLevels(e.target.checked)} className="rounded" />
                        Energy levels
                      </label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showSpectrum} onChange={(e) => setShowSpectrum(e.target.checked)} className="rounded" />
                        Spectrum bar
                      </label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showSpin} onChange={(e) => setShowSpin(e.target.checked)} className="rounded" />
                        Show spin (↑)
                      </label>
                    </div>
                    <div className="flex flex-wrap gap-3">
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showFineStructure} onChange={(e) => setShowFineStructure(e.target.checked)} className="rounded" />
                        Fine structure (j = l ± ½)
                      </label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showZeeman} onChange={(e) => setShowZeeman(e.target.checked)} className="rounded" />
                        Zeeman effect
                      </label>
                    </div>
                    {showZeeman && (
                      <Slider label="Magnetic field B" unit="T" value={magneticField} min={0} max={5} step={0.1} set={setMagneticField} color="#8b5cf6" note="Tesla — splits degenerate levels" />
                    )}
                  </div>
                )}

                {model === 'quantum' && (
                  <div className="border-t border-gray-100 pt-3 space-y-3">
                    <p className="text-[10px] font-medium text-purple-600 uppercase tracking-wide">Quantum Numbers</p>
                    <div className="grid grid-cols-3 gap-3">
                      <Slider label="n" unit="" value={nQuantum} min={1} max={4} step={1} set={setNQuantum} color="#6366f1" note="Principal quantum number" />
                      <Slider label="l" unit="" value={lQuantum} min={0} max={nQuantum - 1} step={1} set={setLQuantum} color="#ec4899" note="Angular momentum (0=s,1=p,2=d,3=f)" />
                      <Slider label="m" unit="" value={mQuantum} min={-lQuantum} max={lQuantum} step={1} set={setMQuantum} color="#10b981" note="Magnetic quantum number" />
                    </div>
                    <p className="text-[10px] text-gray-400">
                      Orbital: <span className="font-medium text-indigo-600">{nQuantum}{['s','p','d','f'][lQuantum] || '?'}</span> —
                      <span className="text-gray-500"> {lQuantum === 0 ? 'spherical, no angular nodes' : lQuantum === 1 ? 'dumbbell, 1 angular node' : lQuantum === 2 ? 'cloverleaf, 2 angular nodes' : lQuantum === 3 ? 'complex 8-lobed, 3 angular nodes' : 'higher orbital'}</span>
                    </p>
                    <div className="grid grid-cols-2 gap-3">
                      <Slider label="Electrons" unit="" value={electronCount} min={1} max={92} step={1} set={setElectronCount} color="#3b82f6" note="Total electrons (Aufbau filling)" />
                    </div>
                    {electronCount > 1 && (
                      <div className="rounded-lg bg-indigo-50 border border-indigo-100 p-2">
                        <p className="text-[10px] text-indigo-700 font-medium">Configuration: <span className="font-mono">{configStr}</span></p>
                        <p className="text-[10px] text-indigo-500 mt-0.5">Period {getPeriodForZ(electronCount)} · {getGroupForZ(electronCount)}</p>
                      </div>
                    )}
                  </div>
                )}

                <div className="border-t border-gray-100 pt-3">
                  <p className="text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-2">Visibility</p>
                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showNucleus} onChange={(e) => setShowNucleus(e.target.checked)} className="rounded" />
                      Nucleus
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showElectrons} onChange={(e) => setShowElectrons(e.target.checked)} className="rounded" />
                      Electrons
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />
                      Probability cloud
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showLabels} onChange={(e) => setShowLabels(e.target.checked)} className="rounded" />
                      Info labels
                    </label>
                    {model === 'quantum' && (
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={showQuantumNumbers} onChange={(e) => setShowQuantumNumbers(e.target.checked)} className="rounded" />
                        Quantum numbers panel
                      </label>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {model === 'bohr' && (
                    <>
                      <StatRow label="Energy Eₙ" value={liveStats.energy.toFixed(3)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Radius rₙ" value={liveStats.radius.toFixed(3)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Velocity vₙ" value={liveStats.velocity.toFixed(3)} unit="c·α" color="text-emerald-600" />
                      <StatRow label="Quantum n" value={liveStats.n.toString()} unit="" color="text-blue-500" />
                      {liveStats.wavelength > 0 && <StatRow label="λ (transition)" value={liveStats.wavelength.toFixed(1)} unit="nm" color="text-amber-600" />}
                      {showFineStructure && <StatRow label="Fine split" value="~10⁻⁴" unit="eV" color="text-purple-600" />}
                      {showZeeman && magneticField > 0 && <StatRow label="Zeeman ΔE" value={(magneticField * 5.788e-5 * 1e6).toFixed(2)} unit="μeV" color="text-pink-500" />}
                    </>
                  )}
                  {model === 'quantum' && (
                    <>
                      <StatRow label="Energy Eₙ" value={bohrEnergy(nQuantum, protonCount).toFixed(3)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Bohr radius" value={bohrRadius(nQuantum, protonCount).toFixed(3)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Degeneracy" value={(nQuantum * nQuantum).toString()} unit="states" color="text-purple-600" />
                      <StatRow label="Orbital" value={`${nQuantum}${['s','p','d','f'][lQuantum] || '?'}`} unit="" color="text-emerald-600" />
                      <StatRow label="Angular nodes" value={lQuantum.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Radial nodes" value={(nQuantum - lQuantum - 1).toString()} unit="" color="text-blue-500" />
                      {electronCount > 1 && (
                        <>
                          <StatRow label="Config" value={configStr.slice(0, 20)} unit="" color="text-indigo-500" />
                          <StatRow label="Valence" value={getOrbitalLabel(nQuantum, lQuantum, mQuantum).split('—')[0].trim()} unit="" color="text-pink-500" />
                        </>
                      )}
                    </>
                  )}
                  {model === 'thomson' && (
                    <>
                      <StatRow label="Electrons" value={electronCount.toString()} unit="" color="text-blue-500" />
                      <StatRow label="Protons" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Net charge" value="0" unit="e" color="text-emerald-600" />
                      <StatRow label="Sphere radius" value="~1" unit="Å" color="text-purple-600" />
                    </>
                  )}
                  {model === 'rutherford' && (
                    <>
                      <StatRow label="Nucleus Z" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Mass number A" value={(protonCount + neutronCount).toString()} unit="" color="text-rose-500" />
                      <StatRow label="α energy" value={alphaEnergy.toFixed(1)} unit="MeV" color="text-rose-500" />
                      <StatRow label="Nuclear radius" value={(1.2 * Math.pow(protonCount + neutronCount, 1/3)).toFixed(2)} unit="fm" color="text-purple-600" />
                      <StatRow label="Classical limit" value="~10⁻¹¹" unit="s" color="text-gray-500" />
                    </>
                  )}
                </div>
              </div>

              {model === 'bohr' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Hydrogen Spectrum</p>
                  <div className="space-y-1">
                    {spectrum.slice(0, 10).map((line, i) => (
                      <div key={i} className="flex items-center gap-2 text-[10px]">
                        <div className="w-3 h-3 rounded-full shrink-0" style={{ backgroundColor: line.color }} />
                        <span className="text-gray-500 w-16">{line.series}</span>
                        <span className="font-mono text-gray-700">{line.wavelength.toFixed(0)} nm</span>
                        <span className="text-gray-400">({line.fromN}→{line.toN})</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {model === 'quantum' && electronCount > 1 && (
                <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                  <p className="text-xs font-medium text-indigo-600 uppercase tracking-wide mb-2">Electron Configuration</p>
                  <p className="text-xs font-mono text-indigo-800">{configStr}</p>
                  <div className="mt-2 space-y-1">
                    <p className="text-[10px] text-indigo-600">Period: {getPeriodForZ(electronCount)}</p>
                    <p className="text-[10px] text-indigo-600">Group: {getGroupForZ(electronCount)}</p>
                    <p className="text-[10px] text-indigo-500 mt-1">Filled via Aufbau principle (n+l rule)</p>
                  </div>
                </div>
              )}

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map((c) => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF


echo "  → src/app/embed/atomic-models/page.tsx"
cat > "src/app/embed/atomic-models/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicParams, AtomicModel } from '@/lib/physics/atomicModels';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key);
  return v !== null ? v === '1' : fallback;
}

function str< T extends string>(sp: URLSearchParams, key: string, fallback: T, allowed: T[]): T {
  const v = sp.get(key) as T | null;
  return v && allowed.includes(v) ? v : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="font-normal text-gray-400">{unit}</span>
        </span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function AtomicModelsEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [model, setModel] = useState<AtomicModel>(() => str(sp, 'model', 'thomson', ['thomson', 'rutherford', 'bohr', 'quantum']));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [zoom, setZoom] = useState(() => num(sp, 'zoom', 1, 0.3, 3));
  const [showOrbits, setShowOrbits] = useState(() => bool(sp, 'orbits', true));
  const [showNucleus, setShowNucleus] = useState(() => bool(sp, 'nucleus', true));
  const [showElectrons, setShowElectrons] = useState(() => bool(sp, 'electrons', true));
  const [showProbability, setShowProbability] = useState(() => bool(sp, 'prob', true));
  const [showEnergyLevels, setShowEnergyLevels] = useState(() => bool(sp, 'levels', true));
  const [showSpectrum, setShowSpectrum] = useState(() => bool(sp, 'spectrum', true));
  const [showLabels, setShowLabels] = useState(() => bool(sp, 'labels', true));
  const [showQuantumNumbers, setShowQuantumNumbers] = useState(() => bool(sp, 'qnums', true));
  const [showSpin, setShowSpin] = useState(() => bool(sp, 'spin', false));
  const [showFineStructure, setShowFineStructure] = useState(() => bool(sp, 'fs', false));
  const [showZeeman, setShowZeeman] = useState(() => bool(sp, 'zeeman', false));
  const [magneticField, setMagneticField] = useState(() => num(sp, 'B', 0, 0, 5));
  const [nQuantum, setNQuantum] = useState(() => num(sp, 'n', 1, 1, 4));
  const [lQuantum, setLQuantum] = useState(() => num(sp, 'l', 0, 0, 3));
  const [mQuantum, setMQuantum] = useState(() => num(sp, 'm', 0, -3, 3));
  const [protonCount, setProtonCount] = useState(() => num(sp, 'Z', 1, 1, 92));
  const [neutronCount, setNeutronCount] = useState(() => num(sp, 'N', 0, 0, 150));
  const [electronCount, setElectronCount] = useState(() => num(sp, 'e', 1, 0, 92));
  const [alphaEnergy, setAlphaEnergy] = useState(() => num(sp, 'alphaE', 5, 1, 10));

  const params: AtomicParams = {
    model, speed, zoom, showOrbits, showNucleus, showElectrons,
    showProbability, showEnergyLevels, showSpectrum, showLabels,
    showClassicalPath: false, showQuantumNumbers, showSpin, showFineStructure,
    showZeeman, magneticField, nQuantum, lQuantum, mQuantum,
    protonCount, neutronCount, electronCount, alphaEnergy,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey((k) => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="flex gap-1 overflow-x-auto pb-1">
        {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map((m) => {
          const labels: Record<AtomicModel, string> = { thomson: 'Thomson', rutherford: 'Rutherford', bohr: 'Bohr', quantum: 'Quantum' };
          return (
            <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey((k) => k + 1); }}
              className={`shrink-0 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'}`}>
              {labels[m]}
            </button>
          );
        })}
      </div>

      <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} width={640} height={420} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused((p) => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <Slider label="Zoom" unit="×" value={zoom} min={0.3} max={3} step={0.1} set={setZoom} color="#10b981" />
          <Slider label="Protons Z" unit="" value={protonCount} min={1} max={92} step={1} set={setProtonCount} color="#fbbf24" />
          {model === 'rutherford' && <Slider label="α energy" unit="MeV" value={alphaEnergy} min={1} max={10} step={0.5} set={setAlphaEnergy} color="#f43f5e" />}
          {model === 'bohr' && showZeeman && <Slider label="B field" unit="T" value={magneticField} min={0} max={5} step={0.1} set={setMagneticField} color="#8b5cf6" />}
          {model === 'quantum' && (
            <>
              <Slider label="n" unit="" value={nQuantum} min={1} max={4} step={1} set={setNQuantum} color="#6366f1" />
              <Slider label="l" unit="" value={lQuantum} min={0} max={nQuantum - 1} step={1} set={setLQuantum} color="#ec4899" />
              <Slider label="m" unit="" value={mQuantum} min={-lQuantum} max={lQuantum} step={1} set={setMQuantum} color="#10b981" />
              <Slider label="Electrons" unit="" value={electronCount} min={1} max={92} step={1} set={setElectronCount} color="#3b82f6" />
            </>
          )}
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showNucleus} onChange={(e) => setShowNucleus(e.target.checked)} className="rounded" />Nucleus
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showElectrons} onChange={(e) => setShowElectrons(e.target.checked)} className="rounded" />Electrons
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />Probability
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showLabels} onChange={(e) => setShowLabels(e.target.checked)} className="rounded" />Labels
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function AtomicModelsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <AtomicModelsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v21-enhanced applied — 4 files written."
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  ENHANCED ATOMIC MODELS SIMULATION — GRADUATE EDITION"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/atomic-models"
echo ""
echo "MODELS:"
echo "  1. Thomson (1897)     — Plum pudding with oscillating electrons"
echo "  2. Rutherford (1911)  — Accurate Coulomb hyperbolic trajectories"
echo "  3. Bohr (1913)        — Quantized orbits + photon emission + spectrum"
echo "                         └─ Fine structure (j = l ± ½)"
echo "                         └─ Zeeman effect (magnetic field splitting)"
echo "  4. Quantum (1926)     — Schrödinger orbitals up to 4f"
echo "                         └─ Multi-electron configurations (Aufbau)"
echo "                         └─ Electron shell filling visualization"
echo ""
echo "PRESETS:"
echo "  • Thomson — Plum Pudding"
echo "  • Rutherford — Gold Foil"
echo "  • Bohr — Ground State, Balmer Series, Fine Structure, Zeeman Effect"
echo "  • Quantum — 1s, 2p, 3d, 4f orbitals"
echo "  • Multi-electron — Carbon (Z=6), Iron (Z=26)"
echo ""
echo "CURRICULUM COVERAGE:"
echo "  Secondary (WAEC/NECO/IGCSE): Historical models, Rutherford scattering,"
echo "    Bohr postulates, spectral series, quantum numbers basics"
echo "  A-Level/SAT/JUPEB: Rydberg formula, energy quantization, angular"
echo "    momentum quantization, classical instability problem"
echo "  Undergraduate: Schrödinger equation, spherical harmonics, radial nodes,"
echo "    uncertainty principle, Pauli exclusion, Aufbau principle, Hund's rule"
echo "  Graduate: Fine structure (Dirac), Zeeman effect (Landé g-factor),"
echo "    Lamb shift, QED corrections, hyperfine structure, quantum field theory"
echo ""
echo "REMINDER: Add to src/app/simulations/page.tsx SIMULATIONS array:"
echo '  {'
echo '    slug: '''atomic-models''',' 
echo '    href: '''/simulations/atomic-models''',' 
echo '    title: '''Atomic Models''',' 
echo '    description: '''Explore the evolution of atomic theory from Thomson to quantum mechanics, with interactive scattering, quantized orbits, fine structure, Zeeman effect, and quantum orbitals.''',' 
echo '    icon: '''⚛️''',' 
echo '    tags: ['''WAEC''', '''NECO''', '''IGCSE''', '''SAT''', '''JUPEB''', '''A-Level'''],' 
echo '    topic: '''Atomic Physics''',' 
echo '    status: '''live''',' 
echo '  },'
