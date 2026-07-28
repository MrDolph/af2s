#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v22: "Atomic Models" — CLARITY + RESPONSIVE + QUANTUM
#
#   Fixes:
#     • 3× larger visual elements, stronger glows, high-contrast canvas
#     • Fully responsive canvas (auto-sizes to container, DPR-aware)
#     • Mobile-first layout: collapsible controls, stacked panels, 44px touch targets
#     • Working quantum probability cloud with pulse animation + scan-line sweep
#     • Smooth Bohr orbit transitions with wavelength-colored photon emission
#     • Rutherford α-particles with glowing trails and Coulomb scattering
#     • Thomson electrons with phase-animated pulsing
#     • Live stats panel, spectrum bar, radial distribution graph
#
# Run: bash patches/patch-v22-atomic-models-clarity.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the project root." >&2
  exit 1
fi

echo "── Patch v22: Atomic Models — Clarity + Responsive + Quantum ──"
mkdir -p "src/app/embed/atomic-models" "src/app/simulations/atomic-models" "src/components/simulation" "src/lib/physics"

# ══════════════════════════════════════════════════════════════════════════════
# 1. Physics Engine
# ══════════════════════════════════════════════════════════════════════════════
echo "  → src/lib/physics/atomicModels.ts"
cat > "src/lib/physics/atomicModels.ts" << 'AFEOF'
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
  return { x: -600, y: b, vx: Math.sqrt(2 * E / 4) * 60, vy: 0, energy: E, active: true, trail: [] };
}

export function updateAlphaParticle(p: ScatteringParticle, dt: number, Z: number): ScatteringParticle {
  if (!p.active) return p;
  const k = 1.44, mAlpha = 4;
  const r2 = p.x * p.x + p.y * p.y;
  const r = Math.sqrt(r2);
  if (r < 2 || Math.abs(p.x) > 700) return { ...p, active: false };
  const a = (2 * Z * k) / (mAlpha * r2);
  const ax = (a * p.x) / r, ay = (a * p.y) / r;
  const newVx = p.vx + ax * dt * 120;
  const newVy = p.vy + ay * dt * 120;
  const newX = p.x + newVx * dt * 12;
  const newY = p.y + newVy * dt * 12;
  const trail = [...p.trail, { x: newX, y: newY }];
  if (trail.length > 80) trail.shift();
  return { ...p, x: newX, y: newY, vx: newVx, vy: newVy, trail, active: true };
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
AFEOF

# ══════════════════════════════════════════════════════════════════════════════
# 2. Canvas Component — COMPLETELY REWRITTEN
# ══════════════════════════════════════════════════════════════════════════════
echo "  → src/components/simulation/AtomicModelsCanvas.tsx"
cat > "src/components/simulation/AtomicModelsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  AtomicParams, BOHR_RADIUS,
  generateThomsonElectrons, updateThomsonElectrons,
  createAlphaParticle, updateAlphaParticle,
  bohrEnergy, bohrRadius, bohrVelocity, transitionWavelength,
  wavelengthToRGB, generateOrbitalSlice, radialDistribution,
  type ThomsonElectron, type ScatteringParticle,
} from '@/lib/physics/atomicModels';

interface Props {
  params: AtomicParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: { energy: number; radius: number; velocity: number; n: number; wavelength: number; shellConfig: string }) => void;
}

export function AtomicModelsCanvas({ params, isRunning, isPaused, onTick }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const wrapRef = useRef<HTMLDivElement | null>(null);
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
  const transitionRef = useRef<{ fromN: number; toN: number; progress: number } | null>(null);
  const photonsRef = useRef<{ x: number; y: number; angle: number; wavelength: number; life: number }[]>([]);
  const orbitalGridRef = useRef<{ x: number; z: number; prob: number }[][] | null>(null);
  const orbitalCacheKeyRef = useRef('');
  const quantumPulseRef = useRef(0);

  const getFont = () => 'var(--kimi-font-sans, system-ui, sans-serif)';

  const resize = useCallback(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = wrap.getBoundingClientRect();
    const w = Math.floor(rect.width);
    const h = Math.floor(rect.height);
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr;
      canvas.height = h * dpr;
    }
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    const ctx = canvas.getContext('2d');
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }, []);

  const drawStarfield = useCallback((ctx: CanvasRenderingContext2D, w: number, h: number, t: number) => {
    for (let i = 0; i < 50; i++) {
      const sx = ((i * 137.5 + t * 1.5) % w + w) % w;
      const sy = ((i * 89.7 + Math.sin(t * 0.08 + i) * 8) % h + h) % h;
      const br = 0.3 + 0.4 * Math.sin(t * 0.4 + i * 2.3);
      const sz = 0.6 + (i % 3) * 0.6;
      ctx.fillStyle = `rgba(255,255,255,${br * 0.3})`;
      ctx.beginPath(); ctx.arc(sx, sy, sz, 0, Math.PI * 2); ctx.fill();
    }
  }, []);

  const drawInfoBox = useCallback((ctx: CanvasRenderingContext2D, w: number, h: number, lines: string[]) => {
    const bw = Math.min(300, w * 0.42);
    const bh = lines.length * 17 + 18;
    const bx = w - bw - 12;
    const by = h - bh - 12;
    ctx.fillStyle = 'rgba(15,23,42,0.65)';
    ctx.fillRect(bx, by, bw, bh);
    ctx.strokeStyle = 'rgba(148,163,184,0.18)';
    ctx.strokeRect(bx, by, bw, bh);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '12px ' + getFont();
    ctx.textAlign = 'left';
    lines.forEach((line, i) => ctx.fillText(line, bx + 10, by + 18 + i * 17));
  }, []);

  const drawThomson = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.38 * p.zoom;
    const r = scale;
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    g.addColorStop(0, 'rgba(244,63,94,0.45)');
    g.addColorStop(0.5, 'rgba(244,63,94,0.18)');
    g.addColorStop(1, 'rgba(244,63,94,0.02)');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = 'rgba(244,63,94,0.35)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
    if (p.showLabels) {
      ctx.fillStyle = '#fb7185'; ctx.font = 'bold 14px ' + getFont(); ctx.textAlign = 'center';
      ctx.fillText('Positive charge sphere', cx, cy - r - 16);
    }
    if (p.showElectrons) {
      if (thomsonRef.current.length === 0) thomsonRef.current = generateThomsonElectrons(8);
      if (dt > 0) thomsonRef.current = updateThomsonElectrons(thomsonRef.current, dt, p.speed);
      thomsonRef.current.forEach((e, i) => {
        const ex = cx + Math.cos(e.angle) * e.radius * r;
        const ey = cy + Math.sin(e.angle) * e.radius * r * 0.65;
        const sz = 5 + Math.sin(e.phase) * 2;
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, sz * 4);
        glow.addColorStop(0, 'rgba(59,130,246,0.7)');
        glow.addColorStop(1, 'rgba(59,130,246,0)');
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(ex, ey, sz * 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#93c5fd'; ctx.beginPath(); ctx.arc(ex, ey, sz, 0, Math.PI * 2); ctx.fill();
        if (p.showLabels && i < 4) { ctx.fillStyle = '#cbd5e1'; ctx.font = '12px ' + getFont(); ctx.fillText('e⁻', ex + 12, ey - 6); }
      });
    }
    if (p.showLabels) drawInfoBox(ctx, w, h, ['J.J. Thomson (1897)', '• Atom = sphere of positive charge', '• Electrons embedded like raisins', '• Could NOT explain scattering data']);
  }, [drawInfoBox]);

  const drawRutherford = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.42 * p.zoom;
    if (p.showNucleus) {
      const nr = Math.max(5, scale * 0.045);
      const ng = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 4);
      ng.addColorStop(0, 'rgba(251,191,36,1)');
      ng.addColorStop(0.4, 'rgba(251,191,36,0.5)');
      ng.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = ng; ctx.beginPath(); ctx.arc(cx, cy, nr * 4, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nr, 0, Math.PI * 2); ctx.fill();
      if (p.showLabels) { ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 13px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText(`Nucleus (Z=${p.protonCount})`, cx, cy + nr + 20); }
    }
    if (dt > 0) {
      if (Math.random() < 0.04 * p.speed) { const b = (Math.random() - 0.5) * 400; scatterRef.current.push(createAlphaParticle(b, p.alphaEnergy || 5)); }
      scatterRef.current = scatterRef.current.map(part => updateAlphaParticle(part, dt, p.protonCount)).filter(part => part.active);
    }
    scatterRef.current.forEach(p => {
      if (p.trail.length > 1) {
        ctx.strokeStyle = 'rgba(244,63,94,0.4)'; ctx.lineWidth = 1.5; ctx.beginPath();
        p.trail.forEach((pt, i) => { const px = cx + pt.x * scale * 0.0018, py = cy + pt.y * scale * 0.0018; if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py); });
        ctx.stroke();
      }
      const px = cx + p.x * scale * 0.0018, py = cy + p.y * scale * 0.0018;
      const glow = ctx.createRadialGradient(px, py, 0, px, py, 10);
      glow.addColorStop(0, 'rgba(244,63,94,0.6)'); glow.addColorStop(1, 'rgba(244,63,94,0)');
      ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(px, py, 10, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#f43f5e'; ctx.beginPath(); ctx.arc(px, py, 4, 0, Math.PI * 2); ctx.fill();
    });
    if (p.showLabels) drawInfoBox(ctx, w, h, ['Ernest Rutherford (1911)', '• Most α pass through → atom is EMPTY', '• Some bounce back → nucleus is TINY', '• Classical problem: orbiting e⁻ radiates']);
  }, [drawInfoBox]);

  const drawBohr = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.20 * p.zoom;
    const maxN = 7, Z = p.protonCount || 1;
    if (p.showNucleus) {
      const nr = 7, ng = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 3);
      ng.addColorStop(0, 'rgba(251,191,36,0.9)'); ng.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = ng; ctx.beginPath(); ctx.arc(cx, cy, nr * 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nr, 0, Math.PI * 2); ctx.fill();
    }
    if (p.showEnergyLevels) {
      const eL = Math.min(55, w * 0.08), eT = 50, eH = h - 140, eMax = Math.abs(bohrEnergy(maxN, Z)) * 1.3;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; ctx.fillRect(eL - 10, eT - 10, 100, eH + 20);
      ctx.strokeStyle = 'rgba(148,163,184,0.18)'; ctx.strokeRect(eL - 10, eT - 10, 100, eH + 20);
      ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 12px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText('Energy (eV)', eL + 40, eT - 2);
      for (let n = 1; n <= maxN; n++) {
        const y = eT + eH - (Math.abs(bohrEnergy(n, Z)) / eMax) * eH;
        ctx.strokeStyle = 'rgba(99,102,241,0.45)'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(eL, y); ctx.lineTo(eL + 75, y); ctx.stroke();
        ctx.fillStyle = '#818cf8'; ctx.font = '11px ' + getFont(); ctx.textAlign = 'right'; ctx.fillText(`n=${n}`, eL - 5, y + 3);
        if (p.showFineStructure && n > 1) { ctx.strokeStyle = 'rgba(244,63,94,0.35)'; ctx.beginPath(); ctx.moveTo(eL, y - 3); ctx.lineTo(eL + 75, y - 3); ctx.stroke(); ctx.strokeStyle = 'rgba(59,130,246,0.35)'; ctx.beginPath(); ctx.moveTo(eL, y + 3); ctx.lineTo(eL + 75, y + 3); ctx.stroke(); }
      }
      if (p.showZeeman && p.magneticField > 0) { ctx.fillStyle = 'rgba(16,185,129,0.5)'; ctx.font = '11px ' + getFont(); ctx.textAlign = 'left'; ctx.fillText(`B = ${p.magneticField} T`, eL + 4, eT + eH + 16); }
    }
    if (p.showOrbits) {
      for (let n = 1; n <= maxN; n++) {
        const r = bohrRadius(n, Z) * scale * 0.14;
        ctx.strokeStyle = `rgba(99,102,241,${0.15 + 0.1 * (maxN - n) / maxN})`; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
        if (p.showLabels) { ctx.fillStyle = 'rgba(129,140,248,0.5)'; ctx.font = '11px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText(`n=${n}`, cx + r + 16, cy); }
      }
    }
    if (p.showElectrons) {
      if (dt > 0) {
        bohrPhaseRef.current += dt * p.speed * (2.2 / bohrNRef.current);
        if (!transitionRef.current && Math.random() < 0.01 * p.speed) {
          const fromN = bohrNRef.current, delta = Math.random() < 0.5 ? -1 : 1;
          const toN = Math.max(1, Math.min(maxN, fromN + delta * Math.floor(Math.random() * 2 + 1)));
          if (fromN !== toN) transitionRef.current = { fromN, toN, progress: 0 };
        }
        if (transitionRef.current) {
          transitionRef.current.progress += dt * p.speed * 2.2;
          if (transitionRef.current.progress >= 1) {
            bohrNRef.current = transitionRef.current.toN;
            photonsRef.current.push({ x: cx, y: cy, angle: Math.random() * Math.PI * 2, wavelength: transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z), life: 1 });
            transitionRef.current = null;
          }
        }
      }
      const curN = transitionRef.current ? transitionRef.current.fromN : bohrNRef.current;
      const tgtN = transitionRef.current ? transitionRef.current.toN : curN;
      const prog = transitionRef.current ? transitionRef.current.progress : 0;
      const rFrom = bohrRadius(curN, Z) * scale * 0.14, rTo = bohrRadius(tgtN, Z) * scale * 0.14;
      const curR = rFrom + (rTo - rFrom) * prog;
      const ex = cx + Math.cos(bohrPhaseRef.current) * curR, ey = cy + Math.sin(bohrPhaseRef.current) * curR;
      if (transitionRef.current) {
        const col = wavelengthToRGB(transitionWavelength(curN, tgtN, Z));
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, 28);
        glow.addColorStop(0, col.replace('rgb', 'rgba').replace(')', ', 0.5)'));
        glow.addColorStop(1, col.replace('rgb', 'rgba').replace(')', ', 0)'));
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(ex, ey, 28, 0, Math.PI * 2); ctx.fill();
      }
      const eg = ctx.createRadialGradient(ex, ey, 0, ex, ey, 14);
      eg.addColorStop(0, 'rgba(59,130,246,0.9)'); eg.addColorStop(1, 'rgba(59,130,246,0)');
      ctx.fillStyle = eg; ctx.beginPath(); ctx.arc(ex, ey, 14, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#93c5fd'; ctx.beginPath(); ctx.arc(ex, ey, 6, 0, Math.PI * 2); ctx.fill();
      if (p.showSpin) { ctx.strokeStyle = '#f43f5e'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(ex - 5, ey - 12); ctx.lineTo(ex + 5, ey - 12); ctx.stroke(); ctx.beginPath(); ctx.moveTo(ex, ey - 12); ctx.lineTo(ex, ey - 18); ctx.stroke(); ctx.beginPath(); ctx.moveTo(ex - 4, ey - 16); ctx.lineTo(ex, ey - 18); ctx.lineTo(ex + 4, ey - 16); ctx.stroke(); }
      if (p.showLabels) { ctx.fillStyle = '#cbd5e1'; ctx.font = '12px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText(`e⁻ n=${Math.round(curN + (tgtN - curN) * prog)}`, ex, ey - 18); }
    }
    if (dt > 0) { for (let i = photonsRef.current.length - 1; i >= 0; i--) { const p = photonsRef.current[i]; p.x += Math.cos(p.angle) * 220 * dt * params.speed; p.y += Math.sin(p.angle) * 220 * dt * params.speed; p.life -= dt * params.speed * 0.55; if (p.life <= 0) photonsRef.current.splice(i, 1); } }
    photonsRef.current.forEach(p => { const col = wavelengthToRGB(p.wavelength); ctx.globalAlpha = Math.max(0, p.life); ctx.strokeStyle = col; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(p.x - Math.cos(p.angle) * 12, p.y - Math.sin(p.angle) * 12); ctx.lineTo(p.x + Math.cos(p.angle) * 12, p.y + Math.sin(p.angle) * 12); ctx.stroke(); ctx.globalAlpha = 1; });
    if (p.showSpectrum) {
      const bY = h - 28, bW = w - 140, bX = 120;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; ctx.fillRect(bX - 5, bY - 14, bW + 10, 26);
      ctx.strokeStyle = 'rgba(148,163,184,0.2)'; ctx.strokeRect(bX - 5, bY - 14, bW + 10, 26);
      ctx.fillStyle = '#94a3b8'; ctx.font = '11px ' + getFont(); ctx.textAlign = 'left'; ctx.fillText('Spectrum (nm)', bX, bY - 18);
      for (let wl = 380; wl <= 780; wl += 40) { const xx = bX + ((wl - 380) / 400) * bW; ctx.fillStyle = wavelengthToRGB(wl); ctx.fillRect(xx, bY - 10, 4, 18); }
      photonsRef.current.forEach(p => { if (p.wavelength >= 380 && p.wavelength <= 780) { const xx = bX + ((p.wavelength - 380) / 400) * bW; ctx.fillStyle = wavelengthToRGB(p.wavelength); ctx.globalAlpha = Math.max(0, p.life); ctx.fillRect(xx - 2, bY - 14, 5, 24); ctx.globalAlpha = 1; } });
    }
    if (p.showLabels) drawInfoBox(ctx, w, h, ['Niels Bohr (1913)', '• Stationary states: no radiation', '• L = nℏ (quantized angular momentum)', '• Eₙ = -13.6 Z²/n² eV', '• ΔE = hν (photon emission/absorption)']);
    if (onTick) { const now = performance.now(); if (now - lastTickRef.current > 80) { lastTickRef.current = now; const n = bohrNRef.current; onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: bohrVelocity(n, Z) / SPEED_OF_LIGHT, n, wavelength: transitionRef.current ? transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z) : 0, shellConfig: '' }); } }
  }, [drawInfoBox, onTick, params.speed]);

  const drawQuantum = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.38 * p.zoom;
    const n = p.nQuantum || 1, l = p.lQuantum || 0, m = p.mQuantum || 0, Z = p.protonCount || 1;
    quantumPulseRef.current += dt * p.speed * 1.5;
    if (p.showNucleus) {
      const nr = 6, ng = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 3);
      ng.addColorStop(0, 'rgba(251,191,36,1)'); ng.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = ng; ctx.beginPath(); ctx.arc(cx, cy, nr * 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24'; ctx.beginPath(); ctx.arc(cx, cy, nr, 0, Math.PI * 2); ctx.fill();
      if (p.showLabels) { ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 12px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText(`Z=${Z}`, cx, cy + nr + 18); }
    }
    if (p.showProbability) {
      const cacheKey = `${n},${l},${m},${scale}`;
      if (orbitalCacheKeyRef.current !== cacheKey) { orbitalGridRef.current = generateOrbitalSlice(n, l, m, 60); orbitalCacheKeyRef.current = cacheKey; }
      const grid = orbitalGridRef.current;
      if (grid) {
        let maxP = 0; grid.forEach(row => row.forEach(pt => { if (pt.prob > maxP) maxP = pt.prob; }));
        const cellW = (scale * 2.6) / grid[0].length, cellH = (scale * 2.6) / grid.length;
        const pulse = 0.7 + 0.3 * Math.sin(quantumPulseRef.current);
        grid.forEach((row, ri) => { row.forEach((pt, ci) => { const prob = pt.prob / (maxP || 1); if (prob < 0.02) return; const px = cx + (pt.x / (10 * n)) * scale * 1.3, py = cy - (pt.z / (10 * n)) * scale * 1.3; const alpha = Math.min(0.65, prob * 2.5 * pulse); const hue = 200 + prob * 100 + Math.sin(quantumPulseRef.current + ci * 0.1) * 15; ctx.fillStyle = `hsla(${hue}, 90%, 60%, ${alpha})`; ctx.fillRect(px - cellW / 2, py - cellH / 2, cellW + 1, cellH + 1); }); });
        const scanY = cy - scale * 1.3 + ((Math.sin(quantumPulseRef.current * 0.5) * 0.5 + 0.5) * scale * 2.6);
        ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx - scale * 1.3, scanY); ctx.lineTo(cx + scale * 1.3, scanY); ctx.stroke();
      }
    }
    if (p.showProbability) {
      const px = w - 130, py = 45, pw = 110, ph = 110;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; ctx.fillRect(px - 6, py - 18, pw + 12, ph + 28);
      ctx.strokeStyle = 'rgba(148,163,184,0.15)'; ctx.strokeRect(px - 6, py - 18, pw + 12, ph + 28);
      ctx.fillStyle = '#94a3b8'; ctx.font = '11px ' + getFont(); ctx.textAlign = 'center'; ctx.fillText('Radial dist.', px + pw / 2, py - 6);
      const rMax = 10 * n; let maxD = 0; const samples: { r: number; d: number }[] = [];
      for (let i = 0; i <= 40; i++) { const r = (i / 40) * rMax, d = radialDistribution(n, l, r); samples.push({ r, d }); if (d > maxD) maxD = d; }
      ctx.strokeStyle = 'rgba(99,102,241,0.85)'; ctx.lineWidth = 2; ctx.beginPath();
      samples.forEach((s, i) => { const xx = px + (s.r / rMax) * pw, yy = py + ph - (s.d / (maxD || 1)) * ph; if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy); });
      ctx.stroke();
      const a0x = px + (n * n * BOHR_RADIUS / rMax) * pw;
      ctx.strokeStyle = 'rgba(244,63,94,0.5)'; ctx.setLineDash([3, 3]); ctx.beginPath(); ctx.moveTo(a0x, py); ctx.lineTo(a0x, py + ph); ctx.stroke(); ctx.setLineDash([]);
    }
    if (p.showLabels) { const labels = ['s', 'p', 'd', 'f']; drawInfoBox(ctx, w, h, ['Schrödinger (1926)', '• Ψ = probability amplitude', '• |Ψ|² = probability density', '• No orbit — only probability cloud', `• n=${n} l=${l} (${labels[l]}) m=${m}`]); }
    if (onTick) { const now = performance.now(); if (now - lastTickRef.current > 80) { lastTickRef.current = now; onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: 0, n, wavelength: 0, shellConfig: `${n}${['s','p','d','f'][l] || '?'}` }); } }
  }, [drawInfoBox, onTick]);

  const drawLoop = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current, p = s.params;
    resize();
    const rect = wrap.getBoundingClientRect(), w = rect.width, h = rect.height;
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) { if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05); lastFrameRef.current = timestamp; } else { lastFrameRef.current = timestamp ?? null; }
    if (dt > 0) timeRef.current += dt * p.speed;
    const t = timeRef.current;
    ctx.clearRect(0, 0, w, h); ctx.fillStyle = '#0b1021'; ctx.fillRect(0, 0, w, h);
    drawStarfield(ctx, w, h, t);
    const cx = w / 2, cy = h / 2;
    switch (p.model) { case 'thomson': drawThomson(ctx, cx, cy, w, h, dt, p); break; case 'rutherford': drawRutherford(ctx, cx, cy, w, h, dt, p); break; case 'bohr': drawBohr(ctx, cx, cy, w, h, dt, p); break; case 'quantum': drawQuantum(ctx, cx, cy, w, h, dt, p); break; }
    rafRef.current = requestAnimationFrame(drawLoop);
  }, [resize, drawStarfield, drawThomson, drawRutherford, drawBohr, drawQuantum]);

  useEffect(() => { resize(); rafRef.current = requestAnimationFrame(drawLoop); window.addEventListener('resize', resize); return () => { cancelAnimationFrame(rafRef.current); window.removeEventListener('resize', resize); }; }, [drawLoop, resize]);

  return (
    <div ref={wrapRef} style={{ width: '100%', position: 'relative', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--kimi-color-border-secondary, #e5e7eb)', background: '#0b1021', aspectRatio: '16 / 10', minHeight: 260 }}>
      <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />
    </div>
  );
}
AFEOF

# ══════════════════════════════════════════════════════════════════════════════
# 3. Main Simulation Page — Fully Responsive
# ══════════════════════════════════════════════════════════════════════════════
echo "  → src/app/simulations/atomic-models/page.tsx"
cat > "src/app/simulations/atomic-models/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  ATOMIC_PRESETS, AtomicParams, AtomicModel,
  generateHydrogenSpectrum,
  bohrEnergy, bohrRadius, bohrVelocity,
  validQuantumNumbers, possibleLValues, possibleMValues,
  getShellCapacity,
} from '@/lib/physics/atomicModels';

const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
};

const TEACHER_NOTES = [
  'The atomic model evolved over 120 years. Each model corrected fatal flaws in the previous.',
  'Thomson (1897): Discovered the electron. Proposed the "plum pudding" model.',
  'Rutherford (1911): Gold foil experiment proved atom is mostly empty space with a tiny nucleus.',
  'Bohr (1913): Stationary states, quantized angular momentum L = nℏ, photon emission ΔE = hν.',
  'Schrödinger (1926): Wavefunction Ψ gives probability amplitudes. |Ψ|² is probability density.',
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number; step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
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
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level']);
  const [mobileControlsOpen, setMobileControlsOpen] = useState(false);

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
    model, speed, zoom, showOrbits, showNucleus, showElectrons, showProbability,
    showEnergyLevels, showSpectrum, showLabels, showSpin, showFineStructure,
    showZeeman, magneticField, nQuantum, lQuantum, mQuantum,
    protonCount, neutronCount, electronCount, alphaEnergy,
  };

  const [liveStats, setLiveStats] = useState({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

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
    setResetKey(k => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
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
  const modelLabels: Record<AtomicModel, string> = { thomson: 'Thomson (1897)', rutherford: 'Rutherford (1911)', bohr: 'Bohr (1913)', quantum: 'Quantum (1926)' };

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
                {Object.keys(CC).map(c => (
                  <button key={c} onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
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
            <span className="text-xs text-gray-400">Thomson → Rutherford → Bohr → Schrödinger</span>
            <span className="text-sm font-semibold font-mono text-gray-900">Eₙ = -13.6 Z²/n² eV</span>
          </div>

          <div className="flex gap-2 overflow-x-auto pb-1">
            {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map(m => (
              <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey(k => k + 1); }}
                className={`shrink-0 rounded-xl border px-4 py-2 text-left hover:shadow-sm transition min-w-[140px] ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}>
                <p className="text-xs font-medium">{modelLabels[m]}</p>
              </button>
            ))}
          </div>

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
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/atomic-models" title="Atomic Models"
                  params={{ model, speed, zoom, orbits: showOrbits ? 1 : 0, nucleus: showNucleus ? 1 : 0, electrons: showElectrons ? 1 : 0, prob: showProbability ? 1 : 0, levels: showEnergyLevels ? 1 : 0, spectrum: showSpectrum ? 1 : 0, labels: showLabels ? 1 : 0, spin: showSpin ? 1 : 0, fs: showFineStructure ? 1 : 0, zeeman: showZeeman ? 1 : 0, B: magneticField, n: nQuantum, l: lQuantum, m: mQuantum, Z: protonCount, N: neutronCount, e: electronCount, alphaE: alphaEnergy }} />
              </div>

              {/* Mobile controls toggle */}
              <button onClick={() => setMobileControlsOpen(o => !o)} className="lg:hidden w-full py-2.5 text-sm font-medium rounded-xl border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 transition">
                {mobileControlsOpen ? 'Hide controls ▲' : 'Show controls ▼'}
              </button>

              <div className={`rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4 ${mobileControlsOpen ? '' : 'hidden lg:block'}`}>
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
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showOrbits} onChange={e => setShowOrbits(e.target.checked)} className="rounded" /> Show orbits</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showEnergyLevels} onChange={e => setShowEnergyLevels(e.target.checked)} className="rounded" /> Energy levels</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showSpectrum} onChange={e => setShowSpectrum(e.target.checked)} className="rounded" /> Spectrum bar</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showSpin} onChange={e => setShowSpin(e.target.checked)} className="rounded" /> Show spin (↑)</label>
                    </div>
                    <div className="flex flex-wrap gap-3">
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showFineStructure} onChange={e => setShowFineStructure(e.target.checked)} className="rounded" /> Fine structure (j = l ± ½)</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showZeeman} onChange={e => setShowZeeman(e.target.checked)} className="rounded" /> Zeeman effect</label>
                    </div>
                    {showZeeman && <Slider label="Magnetic field B" unit="T" value={magneticField} min={0} max={5} step={0.1} set={setMagneticField} color="#8b5cf6" note="Tesla — splits degenerate levels" />}
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
                    <p className="text-[10px] text-gray-400">Orbital: <span className="font-medium text-indigo-600">{nQuantum}{['s','p','d','f'][lQuantum] || '?'}</span> — <span className="text-gray-500">{lQuantum === 0 ? 'spherical, no angular nodes' : lQuantum === 1 ? 'dumbbell, 1 angular node' : lQuantum === 2 ? 'cloverleaf, 2 angular nodes' : lQuantum === 3 ? 'complex 8-lobed, 3 angular nodes' : 'higher orbital'}</span></p>
                  </div>
                )}

                <div className="border-t border-gray-100 pt-3">
                  <p className="text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-2">Visibility</p>
                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showNucleus} onChange={e => setShowNucleus(e.target.checked)} className="rounded" /> Nucleus</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showElectrons} onChange={e => setShowElectrons(e.target.checked)} className="rounded" /> Electrons</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showProbability} onChange={e => setShowProbability(e.target.checked)} className="rounded" /> Probability cloud</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showLabels} onChange={e => setShowLabels(e.target.checked)} className="rounded" /> Info labels</label>
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
                      <StatRow label="Energy Eₙ" value={liveStats.energy.toFixed(2)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Radius rₙ" value={liveStats.radius.toFixed(2)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Velocity vₙ" value={liveStats.velocity.toFixed(4)} unit="c·α" color="text-emerald-600" />
                      <StatRow label="Quantum n" value={liveStats.n.toString()} unit="" color="text-blue-500" />
                      {liveStats.wavelength > 0 && <StatRow label="λ (transition)" value={liveStats.wavelength.toFixed(1)} unit="nm" color="text-amber-600" />}
                      {showFineStructure && <StatRow label="Fine split" value="~10⁻⁴" unit="eV" color="text-purple-600" />}
                      {showZeeman && magneticField > 0 && <StatRow label="Zeeman ΔE" value={(magneticField * 5.788e-5 * 1e6).toFixed(2)} unit="μeV" color="text-pink-500" />}
                    </>
                  )}
                  {model === 'quantum' && (
                    <>
                      <StatRow label="Energy Eₙ" value={bohrEnergy(nQuantum, protonCount).toFixed(2)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Bohr radius" value={bohrRadius(nQuantum, protonCount).toFixed(2)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Degeneracy" value={(nQuantum * nQuantum).toString()} unit="states" color="text-purple-600" />
                      <StatRow label="Orbital" value={`${nQuantum}${['s','p','d','f'][lQuantum] || '?'}`} unit="" color="text-emerald-600" />
                      <StatRow label="Angular nodes" value={lQuantum.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Radial nodes" value={(nQuantum - lQuantum - 1).toString()} unit="" color="text-blue-500" />
                    </>
                  )}
                  {model === 'thomson' && (
                    <>
                      <StatRow label="Electrons" value={electronCount.toString()} unit="" color="text-blue-500" />
                      <StatRow label="Protons" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Net charge" value="0" unit="e" color="text-emerald-600" />
                    </>
                  )}
                  {model === 'rutherford' && (
                    <>
                      <StatRow label="Nucleus Z" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Mass number A" value={(protonCount + neutronCount).toString()} unit="" color="text-rose-500" />
                      <StatRow label="α energy" value={alphaEnergy.toFixed(1)} unit="MeV" color="text-rose-500" />
                      <StatRow label="Nuclear radius" value={(1.2 * Math.pow(protonCount + neutronCount, 1/3)).toFixed(2)} unit="fm" color="text-purple-600" />
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

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {Object.keys(CC).map(c => <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>)}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2"><span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}</li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

# ══════════════════════════════════════════════════════════════════════════════
# 4. Embed Page — Responsive
# ══════════════════════════════════════════════════════════════════════════════
echo "  → src/app/embed/atomic-models/page.tsx"
cat > "src/app/embed/atomic-models/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicParams, AtomicModel } from '@/lib/physics/atomicModels';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}
function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key); return v !== null ? v === '1' : fallback;
}
function str<T extends string>(sp: URLSearchParams, key: string, fallback: T, allowed: T[]): T {
  const v = sp.get(key) as T | null;
  return v && allowed.includes(v) ? v : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number; step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
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
  const [showSpin, setShowSpin] = useState(() => bool(sp, 'spin', false));
  const [showFineStructure, setShowFineStructure] = useState(() => bool(sp, 'fs', false));
  const [showZeeman, setShowZeeman] = useState(() => bool(sp, 'zeeman', false));
  const [magneticField, setMagneticField] = useState(() => num(sp, 'B', 0, 0, 5));
  const [nQuantum, setNQuantum] = useState(() => num(sp, 'n', 1, 1, 4));
  const [lQuantum, setLQuantum] = useState(() => num(sp, 'l', 0, 0, 3));
  const [mQuantum, setMQuantum] = useState(() => num(sp, 'm', 0, -3, 3));
  const [protonCount, setProtonCount] = useState(() => num(sp, 'Z', 1, 1, 92));
  const [alphaEnergy, setAlphaEnergy] = useState(() => num(sp, 'alphaE', 5, 1, 10));

  const params: AtomicParams = {
    model, speed, zoom, showOrbits, showNucleus, showElectrons, showProbability,
    showEnergyLevels, showSpectrum, showLabels, showSpin, showFineStructure, showZeeman,
    magneticField, nQuantum, lQuantum, mQuantum, protonCount, neutronCount: 0,
    electronCount: 1, alphaEnergy,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="flex gap-1 overflow-x-auto pb-1">
        {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map(m => {
          const labels: Record<AtomicModel, string> = { thomson: 'Thomson', rutherford: 'Rutherford', bohr: 'Bohr', quantum: 'Quantum' };
          return (
            <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey(k => k + 1); }}
              className={`shrink-0 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'}`}>
              {labels[m]}
            </button>
          );
        })}
      </div>

      <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />

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
            </>
          )}
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showNucleus} onChange={e => setShowNucleus(e.target.checked)} className="rounded" />Nucleus</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showElectrons} onChange={e => setShowElectrons(e.target.checked)} className="rounded" />Electrons</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showProbability} onChange={e => setShowProbability(e.target.checked)} className="rounded" />Probability</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showLabels} onChange={e => setShowLabels(e.target.checked)} className="rounded" />Labels</label>
          </div>
        </div>
      )}
      <p className="text-center text-[10px] text-gray-400">Powered by <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">A-Factor STEM Studio</a></p>
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

# ══════════════════════════════════════════════════════════════════════════════
# Footer
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "✓ Patch v22 applied — 4 files written."
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  ATOMIC MODELS SIMULATION — v22 CLARITY + RESPONSIVE + QUANTUM"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/atomic-models"
echo ""
echo "FIXES:"
echo "  • 3× larger elements, stronger glows, high-contrast canvas"
echo "  • Fully responsive canvas (auto-sizes to container, DPR-aware)"
echo "  • Mobile-first: collapsible controls, stacked panels, 44px touch targets"
echo "  • Working quantum probability cloud with pulse + scan-line animation"
echo "  • Smooth Bohr orbit transitions with wavelength-colored photons"
echo "  • Rutherford α-particles with glowing trails"
echo "  • Thomson electrons with phase-animated pulsing"
echo ""
