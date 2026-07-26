#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20: new "Quantum Harmonic Oscillator" module
#
#   A fully responsive, high-DPI wavefunction visualiser for the 1-D quantum
#   harmonic oscillator. Features:
#     • Exact analytical wavefunctions (Hermite × Gaussian) for n = 0..5
#     • Real-time superposition time evolution with adaptive grid resolution
#     • Split-view canvas: energy-level diagram (top) + wavefunction (bottom)
#     • Classical turning points, ⟨x⟩ tracker, Re(ψ) / Im(ψ) overlays
#     • Presets: stationary states, 0+1 / 0+2 superpositions, coherent states
#     • Responsive canvas with devicePixelRatio scaling and dynamic grid density
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20-quantum-ho.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v20: new Quantum Harmonic Oscillator module ──"
mkdir -p "src/app/embed/quantum-harmonic-oscillator" "src/app/simulations/quantum-harmonic-oscillator" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/quantumHarmonicOscillator.ts"
cat > "src/lib/physics/quantumHarmonicOscillator.ts" << 'AFEOF'
export const HBAR = 1;
export const MASS = 1;
export const OMEGA = 1;
// In these natural units: characteristic length a = sqrt(HBAR/(MASS*OMEGA)) = 1
// Energy unit = HBAR * OMEGA = 1

export interface WavefunctionResult {
  re: number;
  im: number;
  prob: number;
}

export interface QHOParams {
  speed: number;
  xMax: number;
  eMax: number;
  nMax: number;
  showPotential: boolean;
  showEnergyLevels: boolean;
  showProbability: boolean;
  showReal: boolean;
  showImaginary: boolean;
  showClassicalTurning: boolean;
}

export interface QHOPreset {
  name: string;
  description: string;
  coeffs: number[];
  speed: number;
  xMax: number;
  eMax: number;
  nMax: number;
  showPotential: boolean;
  showEnergyLevels: boolean;
  showProbability: boolean;
  showReal: boolean;
  showImaginary: boolean;
  showClassicalTurning: boolean;
}

/** Hermite polynomial H_n(x) via recurrence relation. */
export function hermite(n: number, x: number): number {
  if (n === 0) return 1;
  if (n === 1) return 2 * x;
  let h0 = 1;
  let h1 = 2 * x;
  for (let i = 2; i <= n; i++) {
    const h2 = 2 * x * h1 - 2 * (i - 1) * h0;
    h0 = h1;
    h1 = h2;
  }
  return h1;
}

/** Factorial for small integers (n ≤ 10). */
export function factorial(n: number): number {
  let r = 1;
  for (let i = 2; i <= n; i++) r *= i;
  return r;
}

/** Stationary-state wavefunction ψ_n(x) for the 1-D QHO in natural units. */
export function stationaryPsi(n: number, x: number): number {
  const norm = 1 / Math.sqrt(Math.pow(2, n) * factorial(n) * Math.sqrt(Math.PI));
  return norm * hermite(n, x) * Math.exp(-x * x / 2);
}

/** Normalise a coefficient array so that Σ|c_n|² = 1. */
export function normalize(coeffs: number[]): number[] {
  const norm = Math.sqrt(coeffs.reduce((sum, c) => sum + c * c, 0));
  return norm > 1e-12 ? coeffs.map(c => c / norm) : coeffs.map(() => 0);
}

/** Time-evolved wavefunction ψ(x,t) = Σ c_n ψ_n(x) e^{-i n t} (global phase removed). */
export function wavefunction(x: number, coeffs: number[], time: number): WavefunctionResult {
  let re = 0;
  let im = 0;
  for (let n = 0; n < coeffs.length; n++) {
    if (coeffs[n] === 0) continue;
    const psi_n = stationaryPsi(n, x);
    const phase = -n * time;
    const c = coeffs[n];
    re += c * psi_n * Math.cos(phase);
    im += c * psi_n * Math.sin(phase);
  }
  return { re, im, prob: re * re + im * im };
}

/** Energy expectation value ⟨E⟩ = Σ c_n² (n + ½). */
export function energyExpectation(coeffs: number[]): number {
  return coeffs.reduce((sum, c, n) => sum + c * c * (n + 0.5), 0);
}

/** Classical turning points for a given energy: x = ±√(2E). */
export function classicalTurningPoints(energy: number): { left: number; right: number } {
  const x = Math.sqrt(2 * energy);
  return { left: -x, right: x };
}

/** Numerical expectation values computed from a spatial grid. */
export function computeExpectations(
  points: { x: number; re: number; im: number; prob: number }[]
): { x: number; x2: number; p: number; p2: number } {
  const N = points.length;
  if (N < 3) return { x: 0, x2: 0, p: 0, p2: 0 };

  const dx = points[1].x - points[0].x;
  let sumProb = 0;
  let sumX = 0;
  let sumX2 = 0;
  let sumP = 0;
  let sumP2 = 0;

  for (let i = 0; i < N; i++) {
    const { x, re, im, prob } = points[i];

    let dRedx = 0;
    let dImdx = 0;
    if (i === 0) {
      dRedx = (points[1].re - points[0].re) / dx;
      dImdx = (points[1].im - points[0].im) / dx;
    } else if (i === N - 1) {
      dRedx = (points[N - 1].re - points[N - 2].re) / dx;
      dImdx = (points[N - 1].im - points[N - 2].im) / dx;
    } else {
      dRedx = (points[i + 1].re - points[i - 1].re) / (2 * dx);
      dImdx = (points[i + 1].im - points[i - 1].im) / (2 * dx);
    }

    const pVal = re * dImdx - im * dRedx;
    const p2Val = dRedx * dRedx + dImdx * dImdx;
    const w = i === 0 || i === N - 1 ? 0.5 : 1.0;

    sumProb += w * prob;
    sumX += w * x * prob;
    sumX2 += w * x * x * prob;
    sumP += w * pVal;
    sumP2 += w * p2Val;
  }

  const norm = sumProb * dx;
  if (norm < 1e-12) return { x: 0, x2: 0, p: 0, p2: 0 };

  return {
    x: (sumX * dx) / norm,
    x2: (sumX2 * dx) / norm,
    p: (sumP * dx) / norm,
    p2: (sumP2 * dx) / norm,
  };
}

function coherentCoeffs(alpha: number): number[] {
  const raw: number[] = [];
  let sum = 0;
  for (let n = 0; n < 6; n++) {
    const c = Math.pow(alpha, n) / Math.sqrt(factorial(n));
    raw.push(c);
    sum += c * c;
  }
  const norm = Math.sqrt(sum);
  return raw.map(c => c / norm);
}

export const PRESETS: QHOPreset[] = [
  {
    name: 'Ground state',
    description: 'The n=0 Gaussian — minimum uncertainty, no nodes, probability peaks at the centre.',
    coeffs: [1, 0, 0, 0, 0, 0],
    speed: 1, xMax: 5, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'First excited',
    description: 'n=1 has a single node at x=0 and odd symmetry. The particle is never found at the centre.',
    coeffs: [0, 1, 0, 0, 0, 0],
    speed: 1, xMax: 5, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'Second excited',
    description: 'n=2 has two nodes and even symmetry. The probability density shows three distinct peaks.',
    coeffs: [0, 0, 1, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: '0+1 superposition',
    description: 'An equal mix of ground and first excited states. Watch the probability "slosh" left and right — the quantum analogue of classical oscillation.',
    coeffs: [0.7071, 0.7071, 0, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: true, showClassicalTurning: true,
  },
  {
    name: '0+2 superposition',
    description: 'Ground plus second excited. The probability "breathes" in place — expanding and contracting while staying centred.',
    coeffs: [0.7071, 0, 0.7071, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: true, showClassicalTurning: true,
  },
  {
    name: 'Coherent state (α=2)',
    description: 'A minimum-uncertainty wave packet that oscillates back and forth like a classical particle while keeping its shape.',
    coeffs: coherentCoeffs(2),
    speed: 1, xMax: 8, eMax: 5.5, nMax: 6,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'Coherent state (α=3)',
    description: 'A larger coherent state with higher energy. The wave packet swings further from the centre with greater amplitude.',
    coeffs: coherentCoeffs(3),
    speed: 1, xMax: 10, eMax: 6.5, nMax: 7,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: false, showClassicalTurning: true,
  },
];
AFEOF

echo "  → src/components/simulation/QuantumHarmonicOscillatorCanvas.tsx"
cat > "src/components/simulation/QuantumHarmonicOscillatorCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  QHOParams, normalize, wavefunction, computeExpectations,
  energyExpectation, classicalTurningPoints,
  type WavefunctionResult,
} from '@/lib/physics/quantumHarmonicOscillator';

interface Props {
  coeffs: number[];
  params: QHOParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: {
    energy: number;
    x: number;
    x2: number;
    p: number;
    p2: number;
    leftTurn: number;
    rightTurn: number;
    maxProb: number;
  }) => void;
  width?: number;
  height?: number;
}

interface GridPoint extends WavefunctionResult {
  x: number;
}

export function QuantumHarmonicOscillatorCanvas({
  coeffs,
  params,
  isRunning,
  isPaused,
  onTick,
  width = 660,
  height = 420,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, coeffs, isRunning, isPaused, onTick });
  propsRef.current = { params, coeffs, isRunning, isPaused, onTick };

  // Reset time when coefficients change
  const coeffsRef = useRef(coeffs);
  useEffect(() => {
    const prev = coeffsRef.current;
    const changed =
      prev.length !== coeffs.length ||
      prev.some((c, i) => Math.abs(c - coeffs[i]) > 1e-6);
    if (changed) {
      timeRef.current = 0;
      coeffsRef.current = [...coeffs];
    }
  }, [coeffs]);

  const draw = useCallback(
    (timestamp?: number) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const s = propsRef.current;

      const dpr = window.devicePixelRatio || 1;
      const displayW = width;
      const displayH = height;

      // Super-responsive: adapt internal resolution to device pixel ratio
      if (
        canvas.width !== Math.floor(displayW * dpr) ||
        canvas.height !== Math.floor(displayH * dpr)
      ) {
        canvas.width = Math.floor(displayW * dpr);
        canvas.height = Math.floor(displayH * dpr);
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      // Physics time step
      let dt = 0;
      if (s.isRunning && !s.isPaused && timestamp !== undefined) {
        if (lastFrameRef.current !== null) {
          dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
        }
        lastFrameRef.current = timestamp;
      } else {
        lastFrameRef.current = timestamp ?? null;
      }
      if (dt > 0) {
        timeRef.current += dt * s.params.speed;
      }
      const t = timeRef.current;

      // Clear
      ctx.clearRect(0, 0, displayW, displayH);
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(0, 0, displayW, displayH);

      // Compute wavefunction on adaptive grid
      const xMax = s.params.xMax;
      const gridN = Math.min(1200, Math.max(200, Math.floor(displayW * 1.5)));
      const points: GridPoint[] = [];
      const normCoeffs = normalize(s.coeffs);
      for (let i = 0; i <= gridN; i++) {
        const x = -xMax + (i / gridN) * (2 * xMax);
        points.push({ x, ...wavefunction(x, normCoeffs, t) });
      }

      // Expectation values
      const exps = computeExpectations(points);
      const energy = energyExpectation(normCoeffs);
      const { left, right } = classicalTurningPoints(energy);
      const maxProb = Math.max(...points.map((p) => p.prob));

      // Throttled stats callback
      if (s.onTick && timestamp !== undefined) {
        const now = performance.now();
        if (now - lastTickRef.current > 80) {
          lastTickRef.current = now;
          s.onTick({
            energy,
            ...exps,
            leftTurn: left,
            rightTurn: right,
            maxProb,
          });
        }
      }

      // Layout
      const padL = 52;
      const padR = 16;
      const padT = 16;
      const padB = 36;
      const plotW = displayW - padL - padR;
      const plotH = displayH - padT - padB;
      const mapX = (x: number) => padL + ((x + xMax) / (2 * xMax)) * plotW;

      // ── Energy diagram (top 40 %) ─────────────────────────────────────────
      const eMax = s.params.eMax;
      const energyH = plotH * 0.40;
      const eTop = padT;
      const eBottom = padT + energyH;
      const mapE = (E: number) => eBottom - (E / eMax) * energyH;

      // Potential V(x) = ½ x²
      if (s.params.showPotential) {
        ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let px = 0; px <= plotW; px += 2) {
          const x = -xMax + (px / plotW) * (2 * xMax);
          const V = 0.5 * x * x;
          if (V > eMax) continue;
          const py = mapE(V);
          if (px === 0) ctx.moveTo(mapX(x), py);
          else ctx.lineTo(mapX(x), py);
        }
        ctx.stroke();
      }

      // Energy levels
      if (s.params.showEnergyLevels) {
        for (let n = 0; n < s.params.nMax; n++) {
          const E = n + 0.5;
          if (E > eMax) break;
          const y = mapE(E);
          ctx.strokeStyle = 'rgba(99, 102, 241, 0.35)';
          ctx.setLineDash([3, 3]);
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(mapX(-xMax), y);
          ctx.lineTo(mapX(xMax), y);
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.fillStyle = '#818cf8';
          ctx.font = '10px system-ui';
          ctx.textAlign = 'right';
          ctx.fillText(`n=${n}  E=${E.toFixed(1)}ℏω`, mapX(-xMax) - 6, y + 3);
        }
      }

      // ── Wavefunction diagram (bottom 58 %) ────────────────────────────────
      const wfTop = eBottom + 8;
      const wfH = displayH - padB - wfTop;
      const xAxisY = wfTop + wfH * 0.55;
      const probScale = wfH * 0.50;
      const waveScale = wfH * 0.40;

      // X-axis
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(mapX(-xMax), xAxisY);
      ctx.lineTo(mapX(xMax), xAxisY);
      ctx.stroke();

      // Classical turning points
      if (s.params.showClassicalTurning && energy > 0) {
        ctx.strokeStyle = 'rgba(16, 185, 129, 0.35)';
        ctx.setLineDash([6, 4]);
        ctx.lineWidth = 1;
        for (const sign of [-1, 1]) {
          const xT = sign * Math.sqrt(2 * energy);
          if (Math.abs(xT) <= xMax) {
            ctx.beginPath();
            ctx.moveTo(mapX(xT), wfTop);
            ctx.lineTo(mapX(xT), displayH - padB);
            ctx.stroke();
          }
        }
        ctx.setLineDash([]);
        ctx.fillStyle = '#10b981';
        ctx.font = '9px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('classical turning points', mapX(0), displayH - padB + 14);
      }

      // |ψ|² — filled area
      if (s.params.showProbability) {
        ctx.fillStyle = 'rgba(244, 63, 94, 0.18)';
        ctx.beginPath();
        ctx.moveTo(mapX(-xMax), xAxisY);
        for (const p of points) {
          ctx.lineTo(mapX(p.x), xAxisY - p.prob * probScale);
        }
        ctx.lineTo(mapX(xMax), xAxisY);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = '#f43f5e';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].prob * probScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }

      // Re(ψ)
      if (s.params.showReal) {
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].re * waveScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }

      // Im(ψ)
      if (s.params.showImaginary) {
        ctx.strokeStyle = '#f59e0b';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 2]);
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].im * waveScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // ⟨x⟩ expectation indicator
      const xExp = exps.x;
      if (Math.abs(xExp) <= xMax) {
        ctx.fillStyle = '#f8fafc';
        ctx.beginPath();
        ctx.arc(mapX(xExp), xAxisY, 5, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#64748b';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(mapX(xExp), xAxisY, 5, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Axis labels
      ctx.fillStyle = '#64748b';
      ctx.font = '10px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText('Position x (units of √(ℏ/mω))', mapX(0), displayH - 8);

      ctx.save();
      ctx.translate(14, xAxisY);
      ctx.rotate(-Math.PI / 2);
      ctx.textAlign = 'center';
      ctx.fillText('Amplitude', 0, 0);
      ctx.restore();

      // Legend
      const legendX = displayW - padR - 100;
      const legendY = wfTop + 10;
      ctx.font = '10px system-ui';
      ctx.textAlign = 'left';
      let ly = legendY;
      if (s.params.showProbability) {
        ctx.fillStyle = '#f43f5e';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('|ψ|²', legendX + 14, ly + 9);
        ly += 16;
      }
      if (s.params.showReal) {
        ctx.fillStyle = '#3b82f6';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Re(ψ)', legendX + 14, ly + 9);
        ly += 16;
      }
      if (s.params.showImaginary) {
        ctx.fillStyle = '#f59e0b';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Im(ψ)', legendX + 14, ly + 9);
        ly += 16;
      }

      // Status
      ctx.font = 'bold 11px system-ui';
      ctx.textAlign = 'center';
      if (!s.isRunning) {
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Press Run to start time evolution', displayW / 2, 28);
      } else if (s.isPaused) {
        ctx.fillStyle = '#f59e0b';
        ctx.fillText('⏸ Paused', displayW / 2, 28);
      } else {
        ctx.fillStyle = '#10b981';
        ctx.fillText('● Evolving', displayW / 2, 28);
      }

      rafRef.current = requestAnimationFrame(draw);
    },
    [width, height]
  );

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="w-full rounded-xl border border-gray-700 bg-slate-900"
      style={{ display: 'block' }}
    />
  );
}
AFEOF

echo "  → src/app/simulations/quantum-harmonic-oscillator/page.tsx"
cat > "src/app/simulations/quantum-harmonic-oscillator/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { QuantumHarmonicOscillatorCanvas } from '@/components/simulation/QuantumHarmonicOscillatorCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { PRESETS, QHOPreset, normalize, QHOParams } from '@/lib/physics/quantumHarmonicOscillator';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The quantum harmonic oscillator is the most important exactly solvable model in quantum mechanics. Its energy spectrum and wavefunctions appear in every sub-field, from molecular vibrations to quantum field theory.',
  'Energy levels are equally spaced: E_n = ℏω(n + ½). The ground-state energy ℏω/2 is called zero-point energy — a purely quantum effect with no classical analogue.',
  'Wavefunctions are Hermite polynomials multiplied by a Gaussian envelope. The number of nodes equals the quantum number n.',
  'Stationary states (pure n) have time-independent probability densities |ψ_n|². Only superpositions of different n produce time-dependent "motion".',
  'A coherent state is a special superposition that mimics classical oscillation: a Gaussian wave packet that swings back and forth without spreading. It is the quantum state closest to a classical particle.',
  'The classical turning points mark where a classical particle with the same energy would reverse direction. In quantum mechanics, there is non-zero probability of finding the particle beyond these points — quantum tunnelling.',
  'The expectation value ⟨x⟩ (white dot) shows the "average position". For a stationary state it is zero; for superpositions it oscillates, tracking the classical motion.',
];

const EXERCISES = [
  {
    q: 'Run the Ground state preset. Where is the particle most likely to be found? How does this differ from a classical particle at the same energy?',
    a: 'The probability peaks at the centre (x=0). A classical particle with E=½ℏω would be at rest at the bottom of the potential well, but a quantum particle has zero-point energy and is delocalised in a Gaussian packet.',
  },
  {
    q: 'Switch to the First excited state. Why is the probability zero at x=0?',
    a: 'The n=1 wavefunction is odd: ψ_1(x) ∝ x·e^{-x²/2}. It must pass through zero at the origin to maintain odd symmetry, so |ψ|² = 0 there.',
  },
  {
    q: 'Run the 0+1 superposition and enable Re(ψ) and Im(ψ). What happens to the probability density over time? Why?',
    a: 'The probability "sloshes" left and right. The two stationary states have different energies, so they accumulate a relative phase e^{-i(E_1-E_0)t/ℏ} = e^{-iωt}. This interference creates a time-dependent beating pattern.',
  },
  {
    q: 'Compare the 0+1 superposition with the Coherent state (α=2). Both oscillate, but what is the key visual difference?',
    a: 'The 0+1 superposition is a simple two-state interference that distorts as it moves. The coherent state contains many n states weighted just right so the Gaussian shape is preserved — it truly mimics a classical pendulum.',
  },
  {
    q: 'Enable classical turning points and compare the Ground state (n=0) with the Coherent state (α=3). How does the region of significant probability compare to the classical allowed region?',
    a: 'For n=0, the Gaussian tail extends noticeably beyond the turning points — quantum tunnelling is significant. For the large coherent state (α=3), the wave packet stays mostly inside the classical region, matching classical expectations.',
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
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => set(Number(e.target.value))}
        className="w-full"
        style={{ accentColor: color }}
      />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: {
  label: string; value: string; unit: string; color: string;
}) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>
        {value} <span className="text-gray-400 font-normal">{unit}</span>
      </span>
    </div>
  );
}

export default function QuantumHarmonicOscillatorPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB']);

  // Coefficients for n = 0..5
  const [c0, setC0] = useState(1);
  const [c1, setC1] = useState(0);
  const [c2, setC2] = useState(0);
  const [c3, setC3] = useState(0);
  const [c4, setC4] = useState(0);
  const [c5, setC5] = useState(0);

  const coeffs = useMemo(() => normalize([c0, c1, c2, c3, c4, c5]), [c0, c1, c2, c3, c4, c5]);

  const [speed, setSpeed] = useState(1);
  const [xMax, setXMax] = useState(5);
  const [eMax, setEMax] = useState(4.5);
  const [nMax, setNMax] = useState(5);
  const [showPotential, setShowPotential] = useState(true);
  const [showEnergyLevels, setShowEnergyLevels] = useState(true);
  const [showProbability, setShowProbability] = useState(true);
  const [showReal, setShowReal] = useState(false);
  const [showImaginary, setShowImaginary] = useState(false);
  const [showClassicalTurning, setShowClassicalTurning] = useState(true);

  const params: QHOParams = {
    speed,
    xMax,
    eMax,
    nMax,
    showPotential,
    showEnergyLevels,
    showProbability,
    showReal,
    showImaginary,
    showClassicalTurning,
  };

  const [liveStats, setLiveStats] = useState({
    energy: 0,
    x: 0,
    x2: 0,
    p: 0,
    p2: 0,
    leftTurn: 0,
    rightTurn: 0,
    maxProb: 0,
  });

  const applyPreset = useCallback((preset: QHOPreset) => {
    const [nc0, nc1, nc2, nc3, nc4, nc5] = preset.coeffs;
    setC0(nc0); setC1(nc1); setC2(nc2); setC3(nc3); setC4(nc4); setC5(nc5);
    setSpeed(preset.speed);
    setXMax(preset.xMax);
    setEMax(preset.eMax);
    setNMax(preset.nMax);
    setShowPotential(preset.showPotential);
    setShowEnergyLevels(preset.showEnergyLevels);
    setShowProbability(preset.showProbability);
    setShowReal(preset.showReal);
    setShowImaginary(preset.showImaginary);
    setShowClassicalTurning(preset.showClassicalTurning);
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({
      energy: 0, x: 0, x2: 0, p: 0, p2: 0,
      leftTurn: 0, rightTurn: 0, maxProb: 0,
    });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({
      energy: 0, x: 0, x2: 0, p: 0, p2: 0,
      leftTurn: 0, rightTurn: 0, maxProb: 0,
    });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const deltaX = Math.sqrt(Math.max(0, liveStats.x2 - liveStats.x * liveStats.x));
  const deltaP = Math.sqrt(Math.max(0, liveStats.p2 - liveStats.p * liveStats.p));

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Quantum Mechanics — Exactly Solvable Models</p>
                <h1 className="text-lg font-semibold text-gray-900">Quantum Harmonic Oscillator</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map((c) => (
                  <button
                    key={c}
                    onClick={() =>
                      setActiveCurricula((p) =>
                        p.includes(c) ? p.filter((x) => x !== c) : [...p, c]
                      )
                    }
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c)
                        ? CC[c] + ' border-transparent'
                        : 'bg-white text-gray-400 border-gray-200'
                    }`}
                  >
                    {c}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">1-D potential well — Hermite polynomials — coherent states</span>
            <span className="text-sm font-semibold font-mono text-gray-900">Ĥ = p̂²/2m + ½mω²x̂²</span>
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESETS.map((preset, i) => (
              <button
                key={i}
                onClick={() => applyPreset(preset)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]"
              >
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <QuantumHarmonicOscillatorCanvas
                  key={resetKey}
                  coeffs={coeffs}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  width={canvasSize.width}
                  height={canvasSize.height}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused((p) => !p)}
                  onReset={reset}
                />
                <EmbedButton
                  path="/embed/quantum-harmonic-oscillator"
                  title="Quantum Harmonic Oscillator — A-Factor STEM Studio"
                  params={{
                    c0, c1, c2, c3, c4, c5,
                    speed, xmax: xMax, emax: eMax,
                    potential: showPotential ? 1 : 0,
                    levels: showEnergyLevels ? 1 : 0,
                    prob: showProbability ? 1 : 0,
                    real: showReal ? 1 : 0,
                    imag: showImaginary ? 1 : 0,
                    turning: showClassicalTurning ? 1 : 0,
                  }}
                />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">State coefficients</p>
                    <Slider label="c₀ (n=0)" unit="" value={c0} min={0} max={1} step={0.01} set={setC0} color="#6366f1" />
                    <Slider label="c₁ (n=1)" unit="" value={c1} min={0} max={1} step={0.01} set={setC1} color="#8b5cf6" />
                    <Slider label="c₂ (n=2)" unit="" value={c2} min={0} max={1} step={0.01} set={setC2} color="#ec4899" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">State coefficients</p>
                    <Slider label="c₃ (n=3)" unit="" value={c3} min={0} max={1} step={0.01} set={setC3} color="#f43f5e" />
                    <Slider label="c₄ (n=4)" unit="" value={c4} min={0} max={1} step={0.01} set={setC4} color="#f59e0b" />
                    <Slider label="c₅ (n=5)" unit="" value={c5} min={0} max={1} step={0.01} set={setC5} color="#10b981" />
                  </div>
                </div>

                <div className="border-t border-gray-100 pt-3 space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <Slider label="Time speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" note="Animation speed factor" />
                    <Slider label="X-range" unit="a" value={xMax} min={3} max={12} step={0.5} set={setXMax} color="#10b981" note="Horizontal axis limit (× characteristic length)" />
                    <Slider label="E-range" unit="ℏω" value={eMax} min={2} max={8} step={0.5} set={setEMax} color="#ef4444" note="Energy axis limit" />
                    <Slider label="Levels shown" unit="" value={nMax} min={1} max={8} step={1} set={setNMax} color="#818cf8" note="Number of energy level lines" />
                  </div>

                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showPotential} onChange={(e) => setShowPotential(e.target.checked)} className="rounded" />
                      Potential V(x)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showEnergyLevels} onChange={(e) => setShowEnergyLevels(e.target.checked)} className="rounded" />
                      Energy levels
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />
                      |ψ|²
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showReal} onChange={(e) => setShowReal(e.target.checked)} className="rounded" />
                      Re(ψ)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showImaginary} onChange={(e) => setShowImaginary(e.target.checked)} className="rounded" />
                      Im(ψ)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showClassicalTurning} onChange={(e) => setShowClassicalTurning(e.target.checked)} className="rounded" />
                      Classical turning points
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="⟨E⟩" value={liveStats.energy.toFixed(3)} unit="ℏω" color="text-indigo-600" />
                  <StatRow label="⟨x⟩" value={liveStats.x.toFixed(3)} unit="a" color="text-rose-500" />
                  <StatRow label="Δx" value={deltaX.toFixed(3)} unit="a" color="text-blue-500" />
                  <StatRow label="⟨p⟩" value={liveStats.p.toFixed(3)} unit="ℏ/a" color="text-emerald-600" />
                  <StatRow label="Δp" value={deltaP.toFixed(3)} unit="ℏ/a" color="text-purple-600" />
                  <StatRow label="Δx·Δp" value={(deltaX * deltaP).toFixed(3)} unit="ℏ" color="text-amber-600" />
                  <StatRow label="x_turn (left)" value={liveStats.leftTurn.toFixed(2)} unit="a" color="text-indigo-500" />
                  <StatRow label="x_turn (right)" value={liveStats.rightTurn.toFixed(2)} unit="a" color="text-amber-500" />
                  <StatRow label="max |ψ|²" value={liveStats.maxProb.toFixed(3)} unit="" color="text-pink-500" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map((c) => (
                    <span
                      key={c}
                      className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                        activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                      }`}
                    >
                      {c}
                    </span>
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
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>
                      {n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button
                        onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2"
                      >
                        <span>
                          <span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}
                        </span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>
                          {ex.a}
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

echo "  → src/app/embed/quantum-harmonic-oscillator/page.tsx"
cat > "src/app/embed/quantum-harmonic-oscillator/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useRef, useMemo } from 'react';
import { useSearchParams } from 'next/navigation';
import { QuantumHarmonicOscillatorCanvas } from '@/components/simulation/QuantumHarmonicOscillatorCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { QHOParams, normalize } from '@/lib/physics/quantumHarmonicOscillator';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key);
  return v !== null ? v === '1' : fallback;
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
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => set(Number(e.target.value))}
        className="w-full"
        style={{ accentColor: color }}
      />
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

function QuantumHOEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [c0, setC0] = useState(() => num(sp, 'c0', 1, 0, 1));
  const [c1, setC1] = useState(() => num(sp, 'c1', 0, 0, 1));
  const [c2, setC2] = useState(() => num(sp, 'c2', 0, 0, 1));
  const [c3, setC3] = useState(() => num(sp, 'c3', 0, 0, 1));
  const [c4, setC4] = useState(() => num(sp, 'c4', 0, 0, 1));
  const [c5, setC5] = useState(() => num(sp, 'c5', 0, 0, 1));

  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [xMax, setXMax] = useState(() => num(sp, 'xmax', 5, 3, 12));
  const [eMax, setEMax] = useState(() => num(sp, 'emax', 4.5, 2, 8));
  const [nMax, setNMax] = useState(() => num(sp, 'nmax', 5, 1, 8));

  const [showPotential, setShowPotential] = useState(() => bool(sp, 'potential', true));
  const [showEnergyLevels, setShowEnergyLevels] = useState(() => bool(sp, 'levels', true));
  const [showProbability, setShowProbability] = useState(() => bool(sp, 'prob', true));
  const [showReal, setShowReal] = useState(() => bool(sp, 'real', false));
  const [showImaginary, setShowImaginary] = useState(() => bool(sp, 'imag', false));
  const [showClassicalTurning, setShowClassicalTurning] = useState(() => bool(sp, 'turning', true));

  const coeffs = useMemo(() => normalize([c0, c1, c2, c3, c4, c5]), [c0, c1, c2, c3, c4, c5]);

  const params: QHOParams = {
    speed,
    xMax,
    eMax,
    nMax,
    showPotential,
    showEnergyLevels,
    showProbability,
    showReal,
    showImaginary,
    showClassicalTurning,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => {
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
  }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <QuantumHarmonicOscillatorCanvas
        key={resetKey}
        coeffs={coeffs}
        params={params}
        isRunning={isRunning}
        isPaused={isPaused}
        width={640}
        height={400}
      />
      <SimulationControls
        isRunning={isRunning}
        isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused((p) => !p)}
        onReset={reset}
      />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="c₀" unit="" value={c0} min={0} max={1} step={0.01} set={setC0} color="#6366f1" />
          <Slider label="c₁" unit="" value={c1} min={0} max={1} step={0.01} set={setC1} color="#8b5cf6" />
          <Slider label="c₂" unit="" value={c2} min={0} max={1} step={0.01} set={setC2} color="#ec4899" />
          <Slider label="c₃" unit="" value={c3} min={0} max={1} step={0.01} set={setC3} color="#f43f5e" />
          <Slider label="c₄" unit="" value={c4} min={0} max={1} step={0.01} set={setC4} color="#f59e0b" />
          <Slider label="c₅" unit="" value={c5} min={0} max={1} step={0.01} set={setC5} color="#10b981" />
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <Slider label="X-range" unit="a" value={xMax} min={3} max={12} step={0.5} set={setXMax} color="#10b981" />
          <Slider label="E-range" unit="ℏω" value={eMax} min={2} max={8} step={0.5} set={setEMax} color="#ef4444" />
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showPotential} onChange={(e) => setShowPotential(e.target.checked)} className="rounded" />
              Potential
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showEnergyLevels} onChange={(e) => setShowEnergyLevels(e.target.checked)} className="rounded" />
              Levels
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />
              |ψ|²
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showReal} onChange={(e) => setShowReal(e.target.checked)} className="rounded" />
              Re(ψ)
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showImaginary} onChange={(e) => setShowImaginary(e.target.checked)} className="rounded" />
              Im(ψ)
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showClassicalTurning} onChange={(e) => setShowClassicalTurning(e.target.checked)} className="rounded" />
              Turning pts
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function QuantumHOEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <QuantumHOEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v20 applied — 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/quantum-harmonic-oscillator"
echo "  - Try the presets: Ground state, Coherent state, 0+1 superposition"
echo "  - Enable Re(ψ) and Im(ψ) to see the complex wavefunction oscillate"
echo "  - Watch the classical turning points vs the quantum probability"
echo ""
echo "REMINDER: Add the simulation to src/app/simulations/page.tsx SIMULATIONS array:"
echo '  {'
echo '    slug: '\''quantum-harmonic-oscillator'\'',' 
echo '    href: '\''/simulations/quantum-harmonic-oscillator'\'',' 
echo '    title: '\''Quantum Harmonic Oscillator'\'',' 
echo '    description: '\''Visualise quantum wavefunctions, superpositions, and coherent states in the exactly solvable QHO potential.'\'',' 
echo '    icon: '\''⚛️'\'',' 
echo '    tags: ['\''IGCSE'\'', '\''SAT'\'', '\''JUPEB'\''],' 
echo '    topic: '\''Quantum Mechanics'\'',' 
echo '    status: '\''live'\'',' 
echo '  },'
