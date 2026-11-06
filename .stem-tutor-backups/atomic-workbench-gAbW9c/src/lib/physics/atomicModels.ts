// ═══════════════════════════════════════════════════════════════════════════
// Atomic Models Physics Engine — v22 Clarity Edition
// ═══════════════════════════════════════════════════════════════════════════

export const BOHR_RADIUS = 0.529; // Ångström
export const RYDBERG_ENERGY = 13.606; // eV
export const FINE_STRUCTURE = 1 / 137.036;
export const SPEED_OF_LIGHT = 2.998e8; // m/s
export const BOHR_MAGNETON = 5.788e-5; // eV/T

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
  showSpin: boolean;
  showFineStructure: boolean;
  showZeeman: boolean;
  magneticField: number;
  nQuantum: number;
  lQuantum: number;
  mQuantum: number;
  protonCount: number;
  neutronCount: number;
  electronCount: number;
  alphaEnergy: number;
}

export interface ThomsonElectron {
  angle: number;
  radius: number;
  speed: number;
  phase: number;
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

export interface SpectralLine {
  wavelength: number;
  fromN: number;
  toN: number;
  series: string;
  intensity: number;
  color: string;
}

export function generateThomsonElectrons(count: number): ThomsonElectron[] {
  const electrons: ThomsonElectron[] = [];
  for (let i = 0; i < count; i++) {
    electrons.push({
      angle: (Math.PI * 2 * i) / count + Math.random() * 0.8,
      radius: 0.25 + Math.random() * 0.55,
      speed: 0.4 + Math.random() * 1.2,
      phase: Math.random() * Math.PI * 2,
    });
  }
  return electrons;
}

export function updateThomsonElectrons(electrons: ThomsonElectron[], dt: number, speed: number): ThomsonElectron[] {
  return electrons.map((e) => ({
    ...e,
    angle: e.angle + e.speed * dt * speed * 0.6,
    phase: e.phase + e.speed * dt * speed * 2.5,
  }));
}

export function createAlphaParticle(b: number, E: number): ScatteringParticle {
  return { x: -600, y: b, vx: Math.sqrt(2 * E / 4) * 28, vy: 0, energy: E, active: true, trail: [] };
}

export function updateAlphaParticle(
  p: ScatteringParticle,
  dt: number,
  Z: number
): ScatteringParticle {
  if (!p.active) return p;

  // Tuned for visible, physically intuitive Rutherford scattering:
  // k is increased so Coulomb repulsion dominates for close approaches.
  const k = 18.0;        // effective Coulomb constant (tuned for visual clarity)
  const mAlpha = 4;
  const softening = 2.0; // prevents 1/r² singularity; simulates finite nuclear size

  // Only deactivate when the particle is far off-screen.
  // CRITICAL FIX: removed the old `r < 2` check that killed particles
  // before they could rebound.
  if (Math.abs(p.x) > 750 || Math.abs(p.y) > 500) {
    return { ...p, active: false };
  }

  // Sub-step integration: prevents high-velocity particles from
  // "jumping" through the nucleus in a single frame.
  const steps = 4;
  const sdt = dt / steps;
  let x = p.x,
    y = p.y,
    vx = p.vx,
    vy = p.vy;

  for (let i = 0; i < steps; i++) {
    const r2 = x * x + y * y;
    const r = Math.sqrt(r2 + softening * softening);

    // Coulomb repulsion: both alpha (+2e) and nucleus (+Ze) are positive.
    const a = (2 * Z * k) / (mAlpha * r * r);

    // Acceleration vector points radially outward (repulsive).
    const ax = (a * x) / r;
    const ay = (a * y) / r;

    vx += ax * sdt * 120;
    vy += ay * sdt * 120;
    x += vx * sdt * 12;
    y += vy * sdt * 12;
  }

  const trail = [...p.trail, { x, y }];
  if (trail.length > 120) trail.shift(); // longer trails to show full rebound arc

  return { ...p, x, y, vx, vy, trail, active: true };
}

export function bohrEnergy(n: number, Z: number = 1): number {
  return -RYDBERG_ENERGY * Z * Z / (n * n);
}

export function bohrRadius(n: number, Z: number = 1): number {
  return BOHR_RADIUS * n * n / Z;
}

export function bohrVelocity(n: number, Z: number = 1): number {
  return (Z * FINE_STRUCTURE * SPEED_OF_LIGHT) / n;
}

export function transitionWavelength(nFrom: number, nTo: number, Z: number = 1): number {
  const deltaE = Math.abs(bohrEnergy(nFrom, Z) - bohrEnergy(nTo, Z));
  return 1240 / deltaE;
}

export function spectralSeriesName(nTo: number): string {
  const names: Record<number, string> = { 1: 'Lyman', 2: 'Balmer', 3: 'Paschen', 4: 'Brackett', 5: 'Pfund', 6: 'Humphreys' };
  return names[nTo] || `n=${nTo}`;
}

export function wavelengthToRGB(wavelength: number): string {
  let r = 0, g = 0, b = 0;
  if (wavelength >= 380 && wavelength < 440) { r = -(wavelength - 440) / 60; g = 0; b = 1; }
  else if (wavelength >= 440 && wavelength < 490) { r = 0; g = (wavelength - 440) / 50; b = 1; }
  else if (wavelength >= 490 && wavelength < 510) { r = 0; g = 1; b = -(wavelength - 510) / 20; }
  else if (wavelength >= 510 && wavelength < 580) { r = (wavelength - 510) / 70; g = 1; b = 0; }
  else if (wavelength >= 580 && wavelength < 645) { r = 1; g = -(wavelength - 645) / 65; b = 0; }
  else if (wavelength >= 645 && wavelength <= 780) { r = 1; g = 0; b = 0; }
  const factor = wavelength < 420 ? 0.3 + 0.7 * (wavelength - 380) / 40 : wavelength > 700 ? 0.3 + 0.7 * (780 - wavelength) / 80 : 1;
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
        lines.push({ wavelength: wl, fromN: nFrom, toN: nTo, series: spectralSeriesName(nTo), intensity: 1 / (nFrom * nFrom * nTo * nTo), color: wavelengthToRGB(wl) });
      }
    }
  }
  return lines.sort((a, b) => a.wavelength - b.wavelength);
}

function factorial(n: number): number { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; }

function associatedLegendre(l: number, m: number, x: number): number {
  const am = Math.abs(m), s = Math.sqrt(Math.max(0, 1 - x * x));
  if (l === 0) return 1;
  if (l === 1) { if (am === 0) return x; if (am === 1) return -s; }
  if (l === 2) { if (am === 0) return 0.5 * (3 * x * x - 1); if (am === 1) return -3 * x * s; if (am === 2) return 3 * (1 - x * x); }
  if (l === 3) { if (am === 0) return 0.5 * (5 * x * x * x - 3 * x); if (am === 1) return -1.5 * (5 * x * x - 1) * s; if (am === 2) return 15 * x * (1 - x * x); if (am === 3) return -15 * s * s * s; }
  return 1;
}

function sphericalHarmonicProb(l: number, m: number, theta: number, phi: number): number {
  const am = Math.abs(m), x = Math.cos(theta);
  const norm = Math.sqrt(((2 * l + 1) * factorial(l - am)) / (4 * Math.PI * factorial(l + am)));
  const Plm = associatedLegendre(l, m, x);
  const Y = norm * Plm * (m >= 0 ? Math.cos(am * phi) : Math.sin(am * phi));
  return Y * Y;
}

function radialWavefunction(n: number, l: number, r: number): number {
  const a0 = 1, rho = (2 * r) / (n * a0), norm = Math.pow(2 / (n * a0), 1.5);
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

export function orbitalProbability(n: number, l: number, m: number, r: number, theta: number, phi: number): number {
  const R = radialWavefunction(n, l, r), Y2 = sphericalHarmonicProb(l, m, theta, phi);
  return R * R * Y2;
}

export function generateOrbitalSlice(n: number, l: number, m: number, gridSize: number): { x: number; z: number; prob: number }[][] {
  const maxR = 10 * n, grid: { x: number; z: number; prob: number }[][] = [];
  for (let i = 0; i < gridSize; i++) {
    const row: { x: number; z: number; prob: number }[] = [];
    for (let j = 0; j < gridSize; j++) {
      const xx = -maxR + (2 * maxR * j) / gridSize, zz = -maxR + (2 * maxR * i) / gridSize;
      const r = Math.sqrt(xx * xx + zz * zz), theta = r > 0.001 ? Math.acos(Math.max(-1, Math.min(1, zz / r))) : 0, phi = xx >= 0 ? 0 : Math.PI;
      row.push({ x: xx, z: zz, prob: orbitalProbability(n, l, m, r, theta, phi) });
    }
    grid.push(row);
  }
  return grid;
}

export function radialDistribution(n: number, l: number, r: number): number {
  const R = radialWavefunction(n, l, r);
  return 4 * Math.PI * r * r * R * R;
}

export interface AtomicPreset {
  name: string;
  description: string;
  model: AtomicModel;
  params: Partial<AtomicParams>;
}

export const ATOMIC_PRESETS: AtomicPreset[] = [
  { name: 'Thomson — Plum Pudding', description: 'Positive sphere with embedded electrons.', model: 'thomson', params: { protonCount: 1, electronCount: 1, speed: 1, zoom: 1, showElectrons: true, showLabels: true } },
  { name: 'Rutherford — Gold Foil', description: 'α-particles scatter off a dense nucleus.', model: 'rutherford', params: { protonCount: 79, zoom: 0.3, showNucleus: true, showLabels: true, alphaEnergy: 5 } },
  { name: 'Bohr — Ground State', description: 'n=1 at the Bohr radius a₀ = 0.529 Å.', model: 'bohr', params: { protonCount: 1, zoom: 1.5, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: true, showLabels: true } },
  { name: 'Bohr — Balmer Series', description: 'Visible lines from transitions to n=2.', model: 'bohr', params: { protonCount: 1, speed: 1.5, zoom: 1.2, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showSpectrum: true, showLabels: true } },
  { name: 'Bohr — Fine Structure', description: 'Spin-orbit coupling splits j = l ± ½.', model: 'bohr', params: { protonCount: 1, zoom: 1.3, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showLabels: true, showFineStructure: true, showSpin: true } },
  { name: 'Bohr — Zeeman Effect', description: 'Magnetic field splits degenerate levels.', model: 'bohr', params: { protonCount: 1, zoom: 1.3, showOrbits: true, showNucleus: true, showElectrons: true, showEnergyLevels: true, showLabels: true, showZeeman: true, magneticField: 3 } },
  { name: 'Quantum — 1s Orbital', description: 'Spherically symmetric ground state.', model: 'quantum', params: { protonCount: 1, zoom: 2, showNucleus: true, showProbability: true, showLabels: true, nQuantum: 1, lQuantum: 0, mQuantum: 0 } },
  { name: 'Quantum — 2p Orbital', description: 'Dumbbell shape with one angular node.', model: 'quantum', params: { protonCount: 1, zoom: 1.5, showNucleus: true, showProbability: true, showLabels: true, nQuantum: 2, lQuantum: 1, mQuantum: 0 } },
  { name: 'Quantum — 3d Orbital', description: 'Cloverleaf with two angular nodes.', model: 'quantum', params: { protonCount: 1, zoom: 1.2, showNucleus: true, showProbability: true, showLabels: true, nQuantum: 3, lQuantum: 2, mQuantum: 0 } },
  { name: 'Quantum — 4f Orbital', description: 'Complex multi-lobed f-orbital.', model: 'quantum', params: { protonCount: 1, zoom: 1.0, showNucleus: true, showProbability: true, showLabels: true, nQuantum: 4, lQuantum: 3, mQuantum: 0 } },
];

export function validQuantumNumbers(n: number, l: number, m: number): boolean {
  return l >= 0 && l < n && Math.abs(m) <= l;
}

export function possibleLValues(n: number): number[] {
  const vals: number[] = [];
  for (let i = 0; i < n; i++) vals.push(i);
  return vals;
}

export function possibleMValues(l: number): number[] {
  const vals: number[] = [];
  for (let i = -l; i <= l; i++) vals.push(i);
  return vals;
}

export function getShellCapacity(n: number): number {
  return 2 * n * n;
}
