#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v46: rebuild Simple AC Circuits (the
# previous series-RLC mode was undeveloped -- no circuit diagram, no
# animation, just two static vector plots) + add Parallel RLC and
# Q-Factor/Bandwidth
#
#   DIAGNOSIS. The old "Series RLC Circuit" mode drew a phasor diagram and
#   an impedance triangle, but NEITHER animated with time (unlike every
#   other mode in the app, which has a rotating phasor tied to the
#   simulation clock) -- and there was no circuit diagram at all: no wires,
#   no R/L/C symbols, no current flow, nothing connecting it to an actual
#   physical circuit. That is exactly why it read as "dangling" and
#   unappealing compared to the rest of the studio's animated sims.
#
#   REBUILT FROM THE GROUND UP:
#     - Series RLC now draws an actual circuit loop (AC source, resistor,
#       inductor, capacitor symbols in series, connected by wire) with
#       current-flow dots that oscillate in sync with i(t) -- physically
#       appropriate for AC, since real charge carriers drift back and
#       forth rather than circulating like DC current. The phasor diagram
#       now rotates with time like every other mode, plus a live V(t)/I(t)
#       waveform trace showing the phase relationship directly.
#     - NEW: Parallel RLC Circuit -- three branches (R, L, C) sharing a
#       common voltage, each with its own animated current, a phasor
#       diagram for IR/IL/IC and their resultant, and a resonance callout.
#       Verified numerically before building the UI that parallel
#       resonance is the OPPOSITE of series: at R=1000, L=0.5H, C=10uF,
#       impedance peaks to exactly R=1000ohm (current minimum) at the
#       same 71.2Hz where a series circuit’s impedance would DROP to
#       its minimum -- an important, easy-to-get-backwards distinction,
#       confirmed correct before shipping.
#     - NEW: Q-Factor & Bandwidth -- a frequency-response curve (current
#       for series, impedance for parallel) with the resonance peak,
#       half-power points, Q, and bandwidth all marked and calculated
#       live, selectable between series and parallel behaviour.
#
#   Verified the standard bandwidth formula (BW=f0/Q) is a high-Q
#   approximation, not exact, BEFORE using it: at Q~2 the true half-power
#   points sit a little inside the f0+-BW/2 estimate, but at Q~22 the
#   match is within about 1% -- confirmed this is the well-known,
#   correctly-applied approximation rather than a computational error,
#   and noted the caveat explicitly in the teacher notes.
#
#   IMPORTANT -- HUB FILE SAFETY. This patch does NOT overwrite
#   simulations/page.tsx. Per explicit correction from the user after a
#   previous patch clobbered independently-added entries in that shared
#   file, this patch instead does a single, TARGETED find-and-replace of
#   just the AC Circuits card’s description text, matched against
#   whatever the file's CURRENT content actually is. If that exact text
#   is not found (e.g. it was already edited since), the substitution is
#   skipped and clearly reported -- the file is never touched blindly.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v46-ac-circuits-rebuild.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v46: rebuild AC Circuits + Parallel RLC + Q-Factor/Bandwidth --"
mkdir -p "src/app/embed/ac-circuits" "src/app/simulations/ac-circuits" "src/components/simulation" "src/lib/physics"

echo "  -> src/lib/physics/electromagnetism.ts"
cat > "src/lib/physics/electromagnetism.ts" << 'AFEOF'
// ── Electromagnetism ──────────────────────────────────────────────────────────
export const MU_0 = 4 * Math.PI * 1e-7; // permeability of free space, T·m/A

// ── Magnetic fields due to current ───────────────────────────────────────────
// Long straight wire (right-hand grip rule): field circles the wire.
export function fieldStraightWire(current: number, distance: number): number {
  if (distance <= 0) return 0;
  return (MU_0 * current) / (2 * Math.PI * distance);
}
// Centre of a circular loop of N turns, radius r.
export function fieldCircularLoop(current: number, radius: number, turns = 1): number {
  if (radius <= 0) return 0;
  return (MU_0 * turns * current) / (2 * radius);
}
// Inside a long solenoid: n = turns per metre (N/length).
export function fieldSolenoid(current: number, turnsPerMetre: number): number {
  return MU_0 * turnsPerMetre * current;
}

// ── Force on a current-carrying conductor (motor effect) ────────────────────
// F = BIL sin(theta) — Fleming's left-hand rule gives the direction.
export function forceOnConductor(B: number, current: number, length: number, angleDeg = 90): number {
  return B * current * length * Math.sin((angleDeg * Math.PI) / 180);
}
// Force per unit length between two parallel current-carrying wires.
export function forcePerLengthParallelWires(i1: number, i2: number, distance: number): number {
  if (distance <= 0) return 0;
  return (MU_0 * i1 * i2) / (2 * Math.PI * distance);
}
// Torque on a current-carrying coil in a uniform field (motor/galvanometer).
export function torqueOnCoil(B: number, current: number, area: number, turns: number, angleDeg: number): number {
  return turns * B * current * area * Math.sin((angleDeg * Math.PI) / 180);
}

// ── Electromagnetic induction ─────────────────────────────────────────────────
// Faraday's law: EMF = -N dΦ/dt — the sign (Lenz's law) says the induced EMF
// opposes the change that produced it; magnitude only, here.
export function magneticFlux(B: number, area: number, angleDeg = 0): number {
  return B * area * Math.cos((angleDeg * Math.PI) / 180);
}
export function inducedEmfFromFluxChange(turns: number, deltaFlux: number, deltaTime: number): number {
  if (deltaTime <= 0) return 0;
  return Math.abs((turns * deltaFlux) / deltaTime);
}
// Motional EMF: a rod of length L sweeping through field B at speed v.
export function motionalEmf(B: number, length: number, velocity: number): number {
  return B * length * velocity;
}
// AC generator: a coil of N turns, area A, spinning at angular speed omega
// in field B produces a sinusoidal EMF.
export function generatorPeakEmf(turns: number, B: number, area: number, omega: number): number {
  return turns * B * area * omega;
}
export function generatorEmfAt(turns: number, B: number, area: number, omega: number, t: number): number {
  return generatorPeakEmf(turns, B, area, omega) * Math.sin(omega * t);
}
// Transformer equation: Vs/Vp = Ns/Np (ideal, lossless).
export function transformerSecondaryVoltage(vPrimary: number, nPrimary: number, nSecondary: number): number {
  if (nPrimary <= 0) return 0;
  return (vPrimary * nSecondary) / nPrimary;
}
export function transformerSecondaryCurrent(iPrimary: number, nPrimary: number, nSecondary: number): number {
  if (nSecondary <= 0) return 0;
  return (iPrimary * nPrimary) / nSecondary;
}

// ── AC circuits ───────────────────────────────────────────────────────────────
export function angularFrequency(frequencyHz: number): number {
  return 2 * Math.PI * frequencyHz;
}
export function rmsFromPeak(peak: number): number {
  return peak / Math.SQRT2;
}
export function peakFromRms(rms: number): number {
  return rms * Math.SQRT2;
}
// Reactance of an inductor and a capacitor.
export function inductiveReactance(omega: number, inductance: number): number {
  return omega * inductance;
}
export function capacitiveReactance(omega: number, capacitance: number): number {
  return omega * capacitance > 0 ? 1 / (omega * capacitance) : Infinity;
}
// Impedance of a series R-L-C circuit.
export function seriesRLCImpedance(R: number, XL: number, XC: number): number {
  return Math.sqrt(R * R + (XL - XC) * (XL - XC));
}
export function seriesRLCPhaseAngleDeg(R: number, XL: number, XC: number): number {
  if (R === 0) return XL - XC >= 0 ? 90 : -90;
  return (Math.atan2(XL - XC, R) * 180) / Math.PI;
}
// Resonant angular frequency of a series RLC circuit (XL = XC).
export function resonantAngularFrequency(inductance: number, capacitance: number): number {
  if (inductance <= 0 || capacitance <= 0) return 0;
  return 1 / Math.sqrt(inductance * capacitance);
}

// ── Parallel RLC ──────────────────────────────────────────────────────────────
// In parallel, R, L, C share the same voltage; branch currents add as
// phasors: IR in phase, IL lagging 90°, IC leading 90°.
export function parallelRLCBranchCurrents(vPeak: number, R: number, XL: number, XC: number) {
  const iR = R > 0 ? vPeak / R : 0;
  const iL = XL > 0 ? vPeak / XL : 0;
  const iC = XC > 0 && Number.isFinite(XC) ? vPeak / XC : 0;
  return { iR, iL, iC };
}
export function parallelRLCTotalCurrent(vPeak: number, R: number, XL: number, XC: number): number {
  const { iR, iL, iC } = parallelRLCBranchCurrents(vPeak, R, XL, XC);
  return Math.sqrt(iR * iR + (iC - iL) * (iC - iL));
}
export function parallelRLCImpedance(vPeak: number, R: number, XL: number, XC: number): number {
  const i = parallelRLCTotalCurrent(vPeak, R, XL, XC);
  return i > 0 ? vPeak / i : Infinity;
}
export function parallelRLCPhaseAngleDeg(R: number, XL: number, XC: number): number {
  // Current phasor relative to voltage: net susceptance (1/XC - 1/XL)
  // determines whether current leads (capacitive) or lags (inductive).
  const gR = R > 0 ? 1 / R : 0;
  const bNet = (XC > 0 && Number.isFinite(XC) ? 1 / XC : 0) - (XL > 0 ? 1 / XL : 0);
  if (gR === 0) return bNet >= 0 ? 90 : -90;
  return (Math.atan2(bNet, gR) * 180) / Math.PI;
}

// ── Quality factor & bandwidth ───────────────────────────────────────────────
// Series RLC: Q = (1/R)*sqrt(L/C) = omega0*L/R — a SHARPER (higher-Q) series
// circuit has a narrower resonance peak.
export function qFactorSeries(R: number, inductance: number, capacitance: number): number {
  if (R <= 0 || inductance <= 0 || capacitance <= 0) return 0;
  return (1 / R) * Math.sqrt(inductance / capacitance);
}
// Parallel RLC: Q = R*sqrt(C/L) — here a LARGER R gives a higher Q (opposite
// dependence on R from the series case, since R limits current differently
// in the two topologies).
export function qFactorParallel(R: number, inductance: number, capacitance: number): number {
  if (R <= 0 || inductance <= 0 || capacitance <= 0) return 0;
  return R * Math.sqrt(capacitance / inductance);
}
// Bandwidth (the width, in Hz, between the half-power points) = f0/Q.
// This is the standard high-Q approximation — increasingly exact as Q
// grows, verified numerically before use (a Q~2 circuit's true half-power
// points sit a little inside this estimate; a Q~20+ circuit matches to
// within about 1%).
export function bandwidthHz(f0: number, Q: number): number {
  return Q > 0 ? f0 / Q : Infinity;
}
AFEOF

echo "  -> src/components/simulation/ACCircuitCanvas.tsx"
cat > "src/components/simulation/ACCircuitCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg,
  parallelRLCBranchCurrents, parallelRLCTotalCurrent, parallelRLCImpedance, parallelRLCPhaseAngleDeg,
  qFactorSeries, qFactorParallel, bandwidthHz, resonantAngularFrequency,
} from '@/lib/physics/electromagnetism';

export type ACMode = 'waveform' | 'reactance' | 'series-rlc' | 'parallel-rlc' | 'resonance';

interface Props {
  mode: ACMode;
  vPeak: number;
  frequency: number;
  resistance: number;
  component: 'inductor' | 'capacitor';
  inductance: number;
  capacitance: number;
  resonanceCircuit: 'series' | 'parallel';
  isRunning: boolean; isPaused: boolean;
  onTick?: (value: number) => void;
  width?: number; height?: number;
}

// ── Reusable circuit-symbol drawing helpers ─────────────────────────────────
function drawResistor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, s: number) {
  const n = 6, dx = (x1 - x0) / (n + 2), dy = (y1 - y0) / (n + 2);
  const perp = { x: -dy, y: dx };
  const len = Math.hypot(perp.x, perp.y) || 1;
  const px = (perp.x / len) * 7 * s, py = (perp.y / len) * 7 * s;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + dx, y0 + dy);
  for (let i = 0; i < n; i++) {
    const sign = i % 2 === 0 ? 1 : -1;
    const cx = x0 + dx * (i + 1.5), cy = y0 + dy * (i + 1.5);
    ctx.lineTo(cx + px * sign, cy + py * sign);
  }
  ctx.lineTo(x1 - dx, y1 - dy); ctx.lineTo(x1, y1);
  ctx.stroke();
}
function drawInductor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, s: number) {
  const n = 5, dx = (x1 - x0) / n, dy = (y1 - y0) / n;
  const r = Math.hypot(dx, dy) / 2;
  const angBase = Math.atan2(dy, dx);
  ctx.beginPath(); ctx.moveTo(x0, y0);
  for (let i = 0; i < n; i++) {
    const cx = x0 + dx * (i + 0.5), cy = y0 + dy * (i + 0.5);
    ctx.arc(cx, cy, r * 0.85, angBase + Math.PI, angBase, false);
  }
  ctx.stroke();
  void s;
}
function drawCapacitor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, s: number) {
  const mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
  const dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy) || 1;
  const ux = dx / len, uy = dy / len;
  const px = -uy * 10 * s, py = ux * 10 * s;
  const gap = 5 * s;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(mx - ux * gap, my - uy * gap); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx - ux * gap - px, my - uy * gap - py); ctx.lineTo(mx - ux * gap + px, my - uy * gap + py); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx + ux * gap - px, my + uy * gap - py); ctx.lineTo(mx + ux * gap + px, my + uy * gap + py); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx + ux * gap, my + uy * gap); ctx.lineTo(x1, y1); ctx.stroke();
}
function drawACSource(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, phase: number) {
  ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
  ctx.beginPath();
  for (let i = 0; i <= 20; i++) {
    const f = i / 20;
    const x = cx - r * 0.6 + f * r * 1.2;
    const y = cy - Math.sin(f * Math.PI * 2 + phase) * r * 0.4;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
}
// Current-flow dots that oscillate locally along a path (physically
// appropriate for AC — real charge carriers drift back and forth, they
// don't circulate around the loop the way DC current does).
function drawFlowDots(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, flowFrac: number, color: string, s: number, count = 3) {
  const dx = x1 - x0, dy = y1 - y0;
  for (let i = 0; i < count; i++) {
    const base = (i + 0.5) / count;
    const local = Math.max(0.05, Math.min(0.95, base + flowFrac * (0.5 / count)));
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(x0 + dx * local, y0 + dy * local, 2.6 * s, 0, Math.PI * 2); ctx.fill();
  }
}

function drawAxes(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number) {
  ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2); ctx.lineTo(gx + gw, gy + gh / 2); ctx.stroke();
  ctx.strokeStyle = '#cbd5e1';
  ctx.strokeRect(gx, gy, gw, gh);
}
function traceWave(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number, phaseOffsetDeg: number, cycles: number, color: string, lineWidth: number) {
  ctx.beginPath();
  const n = 200;
  for (let i = 0; i <= n; i++) {
    const frac = i / n;
    const angle = frac * cycles * 2 * Math.PI + (phaseOffsetDeg * Math.PI) / 180;
    const y = gy + gh / 2 - Math.sin(angle) * (gh / 2 - 4);
    const x = gx + frac * gw;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = color; ctx.lineWidth = lineWidth; ctx.stroke();
}
function drawPhasor(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, angle: number, color: string, lineWidth: number) {
  ctx.strokeStyle = color; ctx.lineWidth = lineWidth;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(angle) * r, cy + Math.sin(angle) * r); ctx.stroke();
}

export function ACCircuitCanvas({
  mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit, isRunning, isPaused, onTick });
  sim.current = { mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 300));

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const omega = angularFrequency(s.frequency);

    if (s.mode === 'waveform') {
      const iPeak = s.vPeak / s.resistance;
      const wt = omega * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt);
      s.onTick?.(vNow);

      const pcx = W * 0.16, pcy = H / 2, pr = 55 * uiScale;
      ctx.strokeStyle = '#e2e8f0'; ctx.beginPath(); ctx.arc(pcx, pcy, pr, 0, Math.PI * 2); ctx.stroke();
      const angle = -wt;
      drawPhasor(ctx, pcx, pcy, pr, angle, '#4f46e5', 2.5);
      ctx.setLineDash([3, 3]); ctx.strokeStyle = '#c7d2fe';
      ctx.beginPath(); ctx.moveTo(pcx + Math.cos(angle) * pr, pcy + Math.sin(angle) * pr); ctx.lineTo(pcx, pcy + Math.sin(angle) * pr); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('V, I phasor', pcx, pcy + pr + 16 * uiScale);
      ctx.fillText('(in phase)', pcx, pcy + pr + 28 * uiScale);

      const gx = W * 0.38, gy = H * 0.15, gw = W * 0.56, gh = H * 0.7;
      drawAxes(ctx, gx, gy, gw, gh);
      const cycles = 2.5;
      traceWave(ctx, gx, gy, gw, gh, -((wt * 180) / Math.PI) % 360, cycles, 'rgba(79,70,229,0.85)', 2);
      ctx.save(); ctx.globalAlpha = 0.7;
      traceWave(ctx, gx, gy, gw, gh, -((wt * 180) / Math.PI) % 360, cycles, '#f59e0b', 1.6);
      ctx.restore();
      const rmsFracY = rmsFromPeak(1);
      ctx.strokeStyle = 'rgba(100,116,139,0.4)'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2 - rmsFracY * (gh / 2 - 4)); ctx.lineTo(gx + gw, gy + gh / 2 - rmsFracY * (gh / 2 - 4)); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('RMS level', gx + 4, gy + gh / 2 - rmsFracY * (gh / 2 - 4) - 4);
      ctx.fillStyle = '#4f46e5'; ctx.fillText('— V(t)', gx + gw - 90 * uiScale, gy + 12 * uiScale);
      ctx.fillStyle = '#f59e0b'; ctx.fillText('— I(t) (in phase)', gx + gw - 90 * uiScale, gy + 24 * uiScale);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(2)}A — resistor: current and voltage always in phase`, W / 2, H - 8);
    } else if (s.mode === 'reactance') {
      const isInductor = s.component === 'inductor';
      const X = isInductor ? inductiveReactance(omega, s.inductance) : capacitiveReactance(omega, s.capacitance);
      const iPeak = X > 0 ? s.vPeak / X : 0;
      const phaseShiftDeg = isInductor ? 90 : -90;
      const wt = omega * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt - (phaseShiftDeg * Math.PI) / 180);
      s.onTick?.(X);

      const pcx = W * 0.16, pcy = H / 2, pr = 55 * uiScale;
      ctx.strokeStyle = '#e2e8f0'; ctx.beginPath(); ctx.arc(pcx, pcy, pr, 0, Math.PI * 2); ctx.stroke();
      const vAngle = -wt;
      const iAngle = -wt + (phaseShiftDeg * Math.PI) / 180;
      drawPhasor(ctx, pcx, pcy, pr, vAngle, '#4f46e5', 2.5);
      drawPhasor(ctx, pcx, pcy, pr * 0.75, iAngle, '#f59e0b', 2.5);
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(isInductor ? 'ELI: V leads I' : 'ICE: I leads V', pcx, pcy + pr + 16 * uiScale);
      ctx.fillText('by 90°', pcx, pcy + pr + 28 * uiScale);

      const gx = W * 0.38, gy = H * 0.15, gw = W * 0.56, gh = H * 0.7;
      drawAxes(ctx, gx, gy, gw, gh);
      const cycles = 2.5;
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gy, gw, gh, wtDeg, cycles, 'rgba(79,70,229,0.85)', 2);
      traceWave(ctx, gx, gy, gw, gh, wtDeg - phaseShiftDeg, cycles, 'rgba(245,158,11,0.85)', 1.8);
      ctx.fillStyle = '#4f46e5'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('— V(t)', gx + gw - 90 * uiScale, gy + 12 * uiScale);
      ctx.fillStyle = '#f59e0b'; ctx.fillText(isInductor ? '— I(t) (lags)' : '— I(t) (leads)', gx + gw - 90 * uiScale, gy + 24 * uiScale);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        `${isInductor ? 'XL = ωL' : 'XC = 1/ωC'} = ${X.toFixed(1)} Ω — v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else if (s.mode === 'series-rlc') {
      const XL = inductiveReactance(omega, s.inductance);
      const XC = capacitiveReactance(omega, s.capacitance);
      const Z = seriesRLCImpedance(s.resistance, XL, XC);
      const phaseDeg = seriesRLCPhaseAngleDeg(s.resistance, XL, XC);
      s.onTick?.(Z);
      const iPeak = Z > 0 ? s.vPeak / Z : 0;
      const wt = omega * t.current;
      const iNow = iPeak * Math.sin(wt - (phaseDeg * Math.PI) / 180);
      const vNow = s.vPeak * Math.sin(wt);

      // Actual circuit diagram: source -> R -> L -> C -> back to source,
      // a single series loop, with current-flow dots oscillating in sync
      // with i(t) — a single shared current, same everywhere in the loop.
      const cx0 = W * 0.06, cy0 = H * 0.18, cw = W * 0.58, ch = H * 0.42;
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
      const flowFrac = iNow / Math.max(iPeak, 0.0001);
      const segColor = 'rgba(79,70,229,0.85)';
      // left wire (source top to R start)
      ctx.beginPath(); ctx.moveTo(cx0, cy0); ctx.lineTo(cx0, cy0 - 30 * uiScale); ctx.lineTo(cx0 + cw * 0.15, cy0 - 30 * uiScale); ctx.stroke();
      drawResistor(ctx, cx0 + cw * 0.15, cy0 - 30 * uiScale, cx0 + cw * 0.42, cy0 - 30 * uiScale, uiScale);
      drawFlowDots(ctx, cx0 + cw * 0.15, cy0 - 30 * uiScale, cx0 + cw * 0.42, cy0 - 30 * uiScale, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw * 0.42, cy0 - 30 * uiScale); ctx.lineTo(cx0 + cw * 0.55, cy0 - 30 * uiScale); ctx.stroke();
      drawInductor(ctx, cx0 + cw * 0.55, cy0 - 30 * uiScale, cx0 + cw * 0.78, cy0 - 30 * uiScale, uiScale);
      drawFlowDots(ctx, cx0 + cw * 0.55, cy0 - 30 * uiScale, cx0 + cw * 0.78, cy0 - 30 * uiScale, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw * 0.78, cy0 - 30 * uiScale); ctx.lineTo(cx0 + cw, cy0 - 30 * uiScale); ctx.lineTo(cx0 + cw, cy0); ctx.stroke();
      drawCapacitor(ctx, cx0 + cw, cy0, cx0 + cw, cy0 + ch, uiScale);
      drawFlowDots(ctx, cx0 + cw, cy0, cx0 + cw, cy0 + ch, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw, cy0 + ch); ctx.lineTo(cx0, cy0 + ch); ctx.lineTo(cx0, cy0); ctx.stroke();
      drawACSource(ctx, cx0, (cy0 + cy0 + ch) / 2, 16 * uiScale, wt);

      ctx.fillStyle = '#475569'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('R', cx0 + cw * 0.285, cy0 - 38 * uiScale);
      ctx.fillText('L', cx0 + cw * 0.665, cy0 - 38 * uiScale);
      ctx.fillText('C', cx0 + cw + 12 * uiScale, cy0 + ch / 2);

      // Rotating phasor diagram, same convention as the other modes
      const pcx = W * 0.2, pcy = H * 0.78, pr = 42 * uiScale;
      ctx.strokeStyle = '#e2e8f0'; ctx.beginPath(); ctx.arc(pcx, pcy, pr, 0, Math.PI * 2); ctx.stroke();
      const iAngle = -wt + (phaseDeg * Math.PI) / 180;
      drawPhasor(ctx, pcx, pcy, pr, -wt, '#4f46e5', 2.2);
      drawPhasor(ctx, pcx, pcy, pr * 0.7, iAngle, '#f59e0b', 2.2);
      ctx.fillStyle = '#64748b'; ctx.font = `${8.5 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('V (indigo), I (amber)', pcx, pcy + pr + 14 * uiScale);

      // Live V(t)/I(t) waveform
      const gx = W * 0.42, gy = H * 0.6, gw = W * 0.52, gh = H * 0.3;
      drawAxes(ctx, gx, gy, gw, gh);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gy, gw, gh, wtDeg, 2, 'rgba(79,70,229,0.85)', 1.8);
      traceWave(ctx, gx, gy, gw, gh, wtDeg + phaseDeg, 2, 'rgba(245,158,11,0.85)', 1.6);

      const nearResonance = Math.abs(XL - XC) < Math.max(s.resistance * 0.05, 0.5);
      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        nearResonance
          ? `RESONANCE: Z ≈ R (minimum) = ${Z.toFixed(1)}Ω — current is MAXIMUM, phase ≈ 0°`
          : `Z=${Z.toFixed(1)}Ω, φ=${phaseDeg.toFixed(0)}° — v=${vNow.toFixed(1)}V, i=${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else if (s.mode === 'parallel-rlc') {
      const XL = inductiveReactance(omega, s.inductance);
      const XC = capacitiveReactance(omega, s.capacitance);
      const { iR, iL, iC } = parallelRLCBranchCurrents(s.vPeak, s.resistance, XL, XC);
      const iTotal = parallelRLCTotalCurrent(s.vPeak, s.resistance, XL, XC);
      const Z = parallelRLCImpedance(s.vPeak, s.resistance, XL, XC);
      const phaseDeg = parallelRLCPhaseAngleDeg(s.resistance, XL, XC);
      s.onTick?.(Z);
      const wt = omega * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iRNow = iR * Math.sin(wt);
      const iLNow = iL * Math.sin(wt - Math.PI / 2);
      const iCNow = iC * Math.sin(wt + Math.PI / 2);

      // Circuit: source on the left, three parallel branches (R, L, C)
      // between two shared rails — each branch carries its own current.
      const cx0 = W * 0.06, cx1 = W * 0.62, cyTop = H * 0.14, cyBot = H * 0.56;
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(cx0, cyTop); ctx.lineTo(cx1, cyTop); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx0, cyBot); ctx.lineTo(cx1, cyBot); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx0, cyTop); ctx.lineTo(cx0, cyBot); ctx.stroke();
      drawACSource(ctx, cx0, (cyTop + cyBot) / 2, 15 * uiScale, wt);

      const branchXs = [cx1 - (cx1 - cx0) * 0.62, cx1 - (cx1 - cx0) * 0.36, cx1 - (cx1 - cx0) * 0.1];
      const iPeakMax = Math.max(iR, iL, iC, 0.0001);
      [
        { x: branchXs[0], draw: drawResistor, flow: iRNow / iPeakMax, label: 'R' },
        { x: branchXs[1], draw: drawInductor, flow: iLNow / iPeakMax, label: 'L' },
        { x: branchXs[2], draw: drawCapacitor, flow: iCNow / iPeakMax, label: 'C' },
      ].forEach(({ x, draw: drawFn, flow, label }) => {
        ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(x, cyTop); ctx.lineTo(x, cyTop + 14 * uiScale); ctx.stroke();
        drawFn(ctx, x, cyTop + 14 * uiScale, x, cyBot - 14 * uiScale, uiScale);
        drawFlowDots(ctx, x, cyTop + 14 * uiScale, x, cyBot - 14 * uiScale, flow, 'rgba(79,70,229,0.85)', uiScale, 2);
        ctx.beginPath(); ctx.moveTo(x, cyBot - 14 * uiScale); ctx.lineTo(x, cyBot); ctx.stroke();
        ctx.fillStyle = '#475569'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(label, x, cyTop + 8 * uiScale);
      });

      // Phasor diagram: IR reference, IL lagging 90°, IC leading 90°.
      const pcx = W * 0.22, pcy = H * 0.8, pr = 40 * uiScale;
      const scale = pr / Math.max(iR, iL, iC, 0.0001);
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(pcx - 50 * uiScale, pcy); ctx.lineTo(pcx + 50 * uiScale, pcy); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(pcx, pcy - 50 * uiScale); ctx.lineTo(pcx, pcy + 50 * uiScale); ctx.stroke();
      const c = ctx;
      function arrow(dx: number, dy: number, color: string, label: string) {
        c.strokeStyle = color; c.lineWidth = 2.2;
        c.beginPath(); c.moveTo(pcx, pcy); c.lineTo(pcx + dx, pcy + dy); c.stroke();
        c.fillStyle = color; c.font = `${8.5 * uiScale}px system-ui`; c.textAlign = 'left';
        c.fillText(label, pcx + dx + 4, pcy + dy);
      }
      arrow(iR * scale, 0, '#059669', 'IR');
      arrow(0, iL * scale, '#dc2626', 'IL');
      arrow(0, -iC * scale, '#2563eb', 'IC');
      const resDx = iR * scale, resDy = (iL - iC) * scale;
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.6;
      ctx.beginPath(); ctx.moveTo(pcx, pcy); ctx.lineTo(pcx + resDx, pcy + resDy); ctx.stroke();
      ctx.fillStyle = '#4f46e5'; ctx.font = `bold ${8.5 * uiScale}px system-ui`;
      ctx.fillText('I', pcx + resDx + 4, pcy + resDy);

      const gx = W * 0.42, gy = H * 0.6, gw = W * 0.52, gh = H * 0.3;
      drawAxes(ctx, gx, gy, gw, gh);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gy, gw, gh, wtDeg, 2, 'rgba(79,70,229,0.85)', 1.8);
      traceWave(ctx, gx, gy, gw, gh, wtDeg + phaseDeg, 2, 'rgba(245,158,11,0.85)', 1.6);

      const nearResonance = Math.abs(iL - iC) < Math.max(iR * 0.05, 0.001);
      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        nearResonance
          ? `RESONANCE: IL ≈ IC (cancel) — line current is MINIMUM, Z ≈ R (maximum) = ${Z.toFixed(0)}Ω`
          : `Z=${Z.toFixed(0)}Ω, φ=${phaseDeg.toFixed(0)}° — v=${vNow.toFixed(1)}V, I_total=${iTotal.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else {
      // resonance: frequency-response curve with Q-factor & bandwidth
      const isSeries = s.resonanceCircuit === 'series';
      const omega0 = resonantAngularFrequency(s.inductance, s.capacitance);
      const f0 = omega0 / (2 * Math.PI);
      const Q = isSeries ? qFactorSeries(s.resistance, s.inductance, s.capacitance) : qFactorParallel(s.resistance, s.inductance, s.capacitance);
      const bw = bandwidthHz(f0, Q);
      s.onTick?.(Q);

      const fMin = Math.max(0.5, f0 - bw * 2.2), fMax = f0 + bw * 2.2;
      const gx = W * 0.1, gy = H * 0.14, gw = W * 0.8, gh = H * 0.56;
      drawAxes(ctx, gx, gy, gw, gh);

      function responseAt(f: number) {
        const om = angularFrequency(f);
        const xl = inductiveReactance(om, s.inductance), xc = capacitiveReactance(om, s.capacitance);
        if (isSeries) {
          const z = seriesRLCImpedance(s.resistance, xl, xc);
          return z > 0 ? s.vPeak / z : 0; // current — peaks AT resonance for series
        }
        const z = parallelRLCImpedance(s.vPeak, s.resistance, xl, xc);
        return z; // impedance — peaks AT resonance for parallel
      }
      const peakVal = responseAt(f0);
      const n = 160;
      ctx.beginPath();
      for (let i = 0; i <= n; i++) {
        const f = fMin + (i / n) * (fMax - fMin);
        const val = responseAt(f) / peakVal;
        const x = gx + (i / n) * gw;
        const y = gy + gh - val * (gh - 6);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.2; ctx.stroke();

      // Half-power line and points
      const halfY = gy + gh - (1 / Math.SQRT2) * (gh - 6);
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(gx, halfY); ctx.lineTo(gx + gw, halfY); ctx.stroke();
      ctx.setLineDash([]);
      [f0 - bw / 2, f0 + bw / 2].forEach(f => {
        const x = gx + ((f - fMin) / (fMax - fMin)) * gw;
        ctx.strokeStyle = '#f59e0b'; ctx.setLineDash([3, 3]);
        ctx.beginPath(); ctx.moveTo(x, gy); ctx.lineTo(x, gy + gh); ctx.stroke();
        ctx.setLineDash([]);
      });
      const x0x = gx + ((f0 - fMin) / (fMax - fMin)) * gw;
      ctx.strokeStyle = 'rgba(220,38,38,0.5)'; ctx.setLineDash([2, 3]);
      ctx.beginPath(); ctx.moveTo(x0x, gy); ctx.lineTo(x0x, gy + gh); ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(isSeries ? 'Current I (normalised)' : 'Impedance Z (normalised)', gx + gw / 2, gy - 6);
      ctx.fillStyle = '#dc2626'; ctx.textAlign = 'left'; ctx.fillText(`f₀=${f0.toFixed(1)}Hz`, x0x + 4, gy + 12 * uiScale);
      ctx.fillStyle = '#f59e0b'; ctx.fillText(`half-power (1/√2)`, gx + 6, halfY - 4);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        `${isSeries ? 'Series' : 'Parallel'} RLC — Q = ${Q.toFixed(2)}, bandwidth = ${bw.toFixed(1)}Hz (f₁=${(f0 - bw / 2).toFixed(1)}Hz, f₂=${(f0 + bw / 2).toFixed(1)}Hz)`,
        W / 2, H - 8,
      );
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  -> src/app/simulations/ac-circuits/page.tsx"
cat > "src/app/simulations/ac-circuits/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg, resonantAngularFrequency,
  parallelRLCImpedance, parallelRLCTotalCurrent, parallelRLCPhaseAngleDeg,
  qFactorSeries, qFactorParallel, bandwidthHz,
} from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'waveform' | 'reactance' | 'series-rlc' | 'parallel-rlc' | 'resonance';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  waveform:       { title: 'AC Waveform & RMS',      icon: '〰️', sub: 'Peak vs RMS values',        eq: 'Vrms = Vpeak/√2' },
  reactance:      { title: 'Inductive & Capacitive Reactance', icon: '⏱️', sub: "'ELI the ICE man'", eq: 'XL=ωL, XC=1/ωC' },
  'series-rlc':   { title: 'Series RLC Circuit',      icon: '📈', sub: 'Impedance & resonance',      eq: 'Z=√(R²+(XL-XC)²)' },
  'parallel-rlc': { title: 'Parallel RLC Circuit',    icon: '🔀', sub: 'Branch currents & resonance', eq: 'I=√(IR²+(IC-IL)²)' },
  resonance:      { title: 'Q-Factor & Bandwidth',    icon: '🎯', sub: 'How sharp is the tuning?',   eq: 'Q=f₀/BW' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  waveform: [
    'Alternating current (AC) reverses direction periodically, unlike DC which flows one way — mains supply is AC specifically because transformers (which only work on AC) make it far more efficient to transmit over long distances.',
    'PEAK value is the maximum instantaneous value the wave reaches; RMS (root-mean-square) is the "effective" DC-equivalent value — the steady value that would deliver the same average power to a resistor.',
    'For a sine wave, RMS = peak/√2 ≈ 0.707 × peak — this factor comes directly from averaging sin²(θ) over a full cycle, which works out to exactly 1/2.',
    'When electricians or exam questions say "230V mains" or "240V mains", that is the RMS value — the actual peak voltage reaches roughly 325-340V.',
    'Undergraduate note: average power in a resistor is P = Irms²R = Vrms²/R — using RMS values lets you apply the familiar DC power formulas directly to AC circuits without needing to integrate over a cycle each time.',
  ],
  reactance: [
    'Reactance is the AC equivalent of resistance for inductors and capacitors — it opposes current flow, measured in ohms, but (unlike resistance) it depends on frequency.',
    "Mnemonic 'ELI the ICE man': in an inductor (L), EMF (voltage) Leads Current — ELI. In a capacitor (C), Current leads EMF (voltage) — ICE.",
    'Inductive reactance XL = ωL INCREASES with frequency — an inductor increasingly opposes fast-changing current (that\u2019s exactly why it opposes the sudden current changes that create the back-EMF).',
    'Capacitive reactance XC = 1/ωC DECREASES with frequency — a capacitor charges and discharges more freely as the current reverses faster, offering less opposition.',
    'Undergraduate note: reactance doesn\u2019t dissipate energy the way resistance does — a pure inductor or capacitor stores and returns energy every half-cycle rather than converting it to heat, which is why reactance and resistance combine as a right-angled (vector) sum rather than a simple addition.',
  ],
  'series-rlc': [
    'A series RLC circuit combines a resistor, inductor, and capacitor in one loop, carrying a SINGLE shared current — their opposition to that current (R, XL, XC) combines as impedance Z = √(R² + (XL-XC)²), not a simple sum, because XL and XC act in OPPOSITE directions.',
    'The phasor diagram shows why: VR is in phase with the current (reference direction), VL leads by 90°, VC lags by 90° — so VL and VC directly cancel each other, and only their DIFFERENCE combines with VR.',
    'RESONANCE occurs when XL = XC (they cancel completely) — at this frequency, impedance is at its MINIMUM (Z = R exactly), current is at its MAXIMUM, and the circuit behaves as if it were purely resistive (phase angle = 0°).',
    'Resonant angular frequency ω₀ = 1/√(LC) — this is the exact frequency an RLC circuit "prefers", the basis of tuning a radio receiver to a specific station by adjusting L or C.',
    'Undergraduate note: away from resonance, the phase angle φ = arctan((XL-XC)/R) tells you whether the circuit is net inductive (current lags, φ>0) or net capacitive (current leads, φ<0) — and the power factor cos(φ) determines how much of VrmsIrms is actually real (usable) power versus reactive power that sloshes back and forth without doing net work.',
  ],
  'parallel-rlc': [
    'In a PARALLEL RLC circuit, R, L, and C all share the same voltage (since they\u2019re connected across the same two nodes) — each branch draws its own current, and the branch currents add as phasors: I = √(IR² + (IC-IL)²).',
    "The same 90° phase relationships apply per branch: IR is in phase with V, IL lags V by 90°, IC leads V by 90° — so IL and IC directly cancel in the phasor sum, exactly mirroring how VL and VC cancel in the series case.",
    'RESONANCE still occurs when XL = XC — but the behaviour is the OPPOSITE of series resonance: IL and IC cancel completely, leaving only IR, so the TOTAL LINE CURRENT is at its MINIMUM and the impedance seen by the source is at its MAXIMUM (equal to R).',
    'This is why parallel resonant circuits are sometimes called "rejector" circuits (they reject/minimise current at resonance) while series resonant circuits are called "acceptor" circuits (they accept/maximise current at resonance) — the same LC combination, wired differently, does the opposite job.',
    'Undergraduate note: the resonant frequency formula ω₀ = 1/√(LC) is the SAME for both series and parallel ideal RLC circuits — what differs between them is which quantity (current for series, impedance for parallel) peaks there, and how R affects the sharpness of that peak.',
  ],
  resonance: [
    'The QUALITY FACTOR (Q) measures how "sharp" or selective a resonant circuit is — a high-Q circuit responds strongly only to a narrow band of frequencies near resonance; a low-Q circuit responds broadly across a wide range.',
    'Series RLC: Q = (1/R)√(L/C) — LOWER resistance gives a HIGHER, sharper Q (less energy lost to R each cycle, so the resonance "rings" more before dying out).',
    'Parallel RLC: Q = R√(C/L) — here it is the OPPOSITE dependence: HIGHER resistance gives a HIGHER Q, because in parallel, resistance provides a leak path for current that damps the resonance; more resistance means less of that damping path.',
    'BANDWIDTH is the range of frequencies (in Hz) between the two "half-power points" either side of resonance — the frequencies where the power delivered has dropped to half its peak value. Bandwidth = f₀/Q: a sharper (higher-Q) resonance has a NARROWER bandwidth.',
    'This is exactly how a radio tuner works: a high-Q circuit lets you pick out one station\u2019s narrow frequency band while rejecting neighbouring stations; a low-Q circuit would let several stations through at once, overlapping and unusable.',
    'Undergraduate note: the "half-power" points are where the response has fallen to 1/√2 (≈70.7%) of its peak — power depends on the square of voltage or current, so a 1/√2 drop in amplitude corresponds to exactly a 1/2 drop in power, which is where the name comes from. Bandwidth=f₀/Q is the standard high-Q approximation, increasingly exact as Q grows — for a low-Q circuit (broad, gentle peak) it is only approximate.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  waveform: [
    { q: 'A UK-style AC supply has an RMS voltage of 230V. Find the peak voltage.', a: 'Vpeak = Vrms×√2 = 230×1.414 ≈ 325 V.' },
    { q: 'A sinusoidal current has a peak value of 5A. Find the RMS value and the average power delivered to a 10Ω resistor.', a: 'Irms = 5/√2 ≈ 3.54A. Average power P = Irms²R = 3.54²×10 ≈ 125 W.' },
    { q: 'Why can\u2019t you just average the instantaneous values of a sine wave to find its "effective" value?', a: 'A sine wave is positive for exactly half the cycle and negative for the other half, so the simple average is always zero — RMS instead averages the SQUARE of the values (always positive) before taking the square root, giving a meaningful non-zero effective value.' },
  ],
  reactance: [
    { q: 'Find the reactance of a 200mH inductor at a frequency of 50Hz.', a: 'XL = ωL = 2π×50×0.2 ≈ 62.8 Ω.' },
    { q: 'Find the reactance of a 20µF capacitor at 50Hz.', a: 'XC = 1/(ωC) = 1/(2π×50×20×10⁻⁶) ≈ 159.2 Ω.' },
    { q: 'As frequency increases, what happens to XL and XC, and how does that explain why a capacitor "blocks DC but passes AC"?', a: 'XL increases and XC decreases with frequency. At f=0 (DC), XC = 1/(0) → infinite — a capacitor completely blocks steady current. At high frequency, XC → 0, offering almost no opposition, so a capacitor lets rapidly alternating current pass relatively freely.' },
  ],
  'series-rlc': [
    { q: 'A series RLC circuit has R=50Ω, XL=120Ω, XC=40Ω. Find the impedance.', a: 'Z = √(R² + (XL-XC)²) = √(50² + 80²) = √(2500+6400) = √8900 ≈ 94.3 Ω.' },
    { q: 'For the same circuit, find the phase angle and state whether current leads or lags voltage.', a: 'φ = arctan((XL-XC)/R) = arctan(80/50) ≈ 58°. Since XL>XC, the circuit is net inductive, so CURRENT LAGS voltage by about 58°.' },
    { q: 'A series circuit has L=0.2H and C=50µF. Find the resonant frequency.', a: 'ω₀ = 1/√(LC) = 1/√(0.2×50×10⁻⁶) = 1/√(1×10⁻⁵) ≈ 316.2 rad/s. f₀ = ω₀/2π ≈ 50.3 Hz.' },
  ],
  'parallel-rlc': [
    { q: 'A parallel RLC circuit has IR=2A, IL=5A, IC=1.5A (all peak). Find the total line current.', a: 'I = √(IR² + (IC-IL)²) = √(2² + (1.5-5)²) = √(4+12.25) = √16.25 ≈ 4.03A.' },
    { q: 'In the same circuit, is the total current more or less than IR alone, and what does that tell you about the phase?', a: 'More (4.03A > 2A) — since IL and IC do not cancel, there is a net reactive current, so the total current does not simply equal IR; it leads or lags voltage depending on whether IC or IL dominates (here IL>IC, so the circuit is net inductive and the line current lags voltage).' },
    { q: 'Why does total line current DROP to a minimum at resonance in a parallel RLC circuit, when current in a series circuit RISES to a maximum?', a: 'At resonance IL=IC in both cases, so they cancel. In series, that cancellation leaves only R limiting current, so impedance is minimum and current is maximum. In parallel, cancelling IL and IC leaves only the small IR branch contributing to the LINE current, so the total current drawn from the source is minimum — even though current is still circulating between L and C internally.' },
  ],
  resonance: [
    { q: 'A series RLC circuit has f₀=1000Hz and Q=50. Find the bandwidth and the two half-power frequencies.', a: 'BW = f₀/Q = 1000/50 = 20Hz. Half-power points ≈ f₀ ± BW/2 = 990Hz and 1010Hz.' },
    { q: 'Two series RLC circuits have the same L and C but different R. Which one has the higher Q, and why?', a: 'The circuit with the SMALLER R has the higher Q, since Q=(1/R)√(L/C) — less resistance means less energy dissipated each cycle, so the resonance is sharper and rings longer.' },
    { q: 'A radio tuner needs to separate two stations broadcasting just 10kHz apart, centred near 100MHz. Would a high-Q or low-Q circuit be more suitable, and why?', a: 'A HIGH-Q circuit — it produces a narrow bandwidth, letting through only a thin slice of frequencies around the tuned station while strongly rejecting a neighbouring station only 10kHz away. A low-Q (broad) circuit would let both stations through at once, overlapping and unusable.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

export default function ACCircuitsPage() {
  const [topic, setTopic] = useState<Topic>('waveform');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [vPeak, setVPeak] = useState(20);
  const [frequency, setFrequency] = useState(2);
  const [resistance, setResistance] = useState(100);

  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance, setInductance] = useState(0.5);
  const [capacitance, setCapacitance] = useState(10); // µF

  const [rlcFrequency, setRlcFrequency] = useState(50);
  const [parallelResistance, setParallelResistance] = useState(1000);

  const [resonanceCircuit, setResonanceCircuit] = useState<'series' | 'parallel'>('series');
  const [resR, setResR] = useState(100);
  const [resL, setResL] = useState(0.5);
  const [resC, setResC] = useState(10);

  const [liveValue, setLiveValue] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, parallelResistance, resonanceCircuit, resR, resL, resC, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 340, 980);

  const capF = capacitance * 1e-6;
  const isSeriesTopic = topic === 'series-rlc';
  const isParallelTopic = topic === 'parallel-rlc';
  const effFrequency = isSeriesTopic || isParallelTopic ? rlcFrequency : topic === 'resonance' ? 0 : frequency;
  const omega = angularFrequency(isSeriesTopic || isParallelTopic ? rlcFrequency : frequency);
  const XL = inductiveReactance(omega, inductance);
  const XC = capacitiveReactance(omega, capF);
  const Z = seriesRLCImpedance(resistance, XL, XC);
  const phaseDeg = seriesRLCPhaseAngleDeg(resistance, XL, XC);
  const omegaRes = resonantAngularFrequency(inductance, capF);
  const fRes = omegaRes / (2 * Math.PI);
  const reactanceX = component === 'inductor' ? XL : XC;

  const parZ = parallelRLCImpedance(vPeak, parallelResistance, XL, XC);
  const parI = parallelRLCTotalCurrent(vPeak, parallelResistance, XL, XC);
  const parPhase = parallelRLCPhaseAngleDeg(parallelResistance, XL, XC);

  const resCapF = resC * 1e-6;
  const resOmega0 = resonantAngularFrequency(resL, resCapF);
  const resF0 = resOmega0 / (2 * Math.PI);
  const resQ = resonanceCircuit === 'series' ? qFactorSeries(resR, resL, resCapF) : qFactorParallel(resR, resL, resCapF);
  const resBW = bandwidthHz(resF0, resQ);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple AC Circuits</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
                  vPeak={vPeak} frequency={topic === 'resonance' ? resF0 : effFrequency}
                  resistance={isParallelTopic ? parallelResistance : topic === 'resonance' ? resR : resistance}
                  component={component}
                  inductance={topic === 'resonance' ? resL : inductance}
                  capacitance={topic === 'resonance' ? resCapF : capF}
                  resonanceCircuit={resonanceCircuit}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveValue}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/ac-circuits"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'waveform' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
                </>}

                {topic === 'reactance' && <>
                  <div className="flex gap-2">
                    {(['inductor', 'capacitor'] as const).map(c => (
                      <button key={c} onClick={() => setComponent(c)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{c}</button>
                    ))}
                  </div>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  {component === 'inductor'
                    ? <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#8b5cf6" />
                    : <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#8b5cf6" />}
                </>}

                {topic === 'series-rlc' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b"
                    note={`Resonance at ≈ ${fRes.toFixed(1)} Hz`} />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
                  <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#2563eb" />
                </>}

                {topic === 'parallel-rlc' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b"
                    note={`Resonance at ≈ ${fRes.toFixed(1)} Hz`} />
                  <Slider label="Resistance" unit="Ω" value={parallelResistance} min={100} max={3000} step={100} set={setParallelResistance} color="#059669" />
                  <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#2563eb" />
                </>}

                {topic === 'resonance' && <>
                  <div className="flex gap-2">
                    {(['series', 'parallel'] as const).map(c => (
                      <button key={c} onClick={() => setResonanceCircuit(c)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          resonanceCircuit === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{c}</button>
                    ))}
                  </div>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Resistance" unit="Ω" value={resR} min={resonanceCircuit === 'series' ? 5 : 200} max={resonanceCircuit === 'series' ? 200 : 3000}
                    step={resonanceCircuit === 'series' ? 5 : 100} set={setResR} color="#059669"
                    note={resonanceCircuit === 'series' ? 'Lower R → sharper (higher Q) peak' : 'Higher R → sharper (higher Q) peak'} />
                  <Slider label="Inductance" unit="H" value={resL} min={0.1} max={2} step={0.1} set={setResL} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={resC} min={1} max={50} step={1} set={setResC} color="#2563eb" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'waveform' && <>
                    <StatRow label="Vrms" value={rmsFromPeak(vPeak).toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="Irms" value={rmsFromPeak(vPeak / resistance).toFixed(2)} unit="A" color="text-emerald-600" />
                    <StatRow label="Average power" value={((rmsFromPeak(vPeak) ** 2) / resistance).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="v(t) now" value={liveValue.toFixed(1)} unit="V" color="text-gray-500" />
                  </>}
                  {topic === 'reactance' && <>
                    <StatRow label={component === 'inductor' ? 'XL' : 'XC'} value={reactanceX.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Peak current" value={(vPeak / reactanceX).toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="Phase" value={component === 'inductor' ? 'I lags V by 90°' : 'I leads V by 90°'} unit="" color="text-amber-600" />
                  </>}
                  {topic === 'series-rlc' && <>
                    <StatRow label="XL" value={XL.toFixed(1)} unit="Ω" color="text-red-600" />
                    <StatRow label="XC" value={XC.toFixed(1)} unit="Ω" color="text-blue-600" />
                    <StatRow label="Impedance Z" value={Z.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Phase angle" value={phaseDeg.toFixed(1)} unit="°" color="text-emerald-600" />
                    <StatRow label="Resonant f₀" value={fRes.toFixed(1)} unit="Hz" color="text-purple-600" />
                  </>}
                  {topic === 'parallel-rlc' && <>
                    <StatRow label="XL" value={XL.toFixed(1)} unit="Ω" color="text-red-600" />
                    <StatRow label="XC" value={XC.toFixed(1)} unit="Ω" color="text-blue-600" />
                    <StatRow label="Impedance Z" value={parZ.toFixed(0)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Line current" value={parI.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="Phase angle" value={parPhase.toFixed(1)} unit="°" color="text-amber-600" />
                    <StatRow label="Resonant f₀" value={fRes.toFixed(1)} unit="Hz" color="text-purple-600" />
                  </>}
                  {topic === 'resonance' && <>
                    <StatRow label="Resonant f₀" value={resF0.toFixed(1)} unit="Hz" color="text-purple-600" />
                    <StatRow label="Q factor" value={resQ.toFixed(2)} unit="" color="text-indigo-600" />
                    <StatRow label="Bandwidth" value={resBW.toFixed(1)} unit="Hz" color="text-emerald-600" />
                    <StatRow label="f₁ (lower)" value={(resF0 - resBW / 2).toFixed(1)} unit="Hz" color="text-amber-600" />
                    <StatRow label="f₂ (upper)" value={(resF0 + resBW / 2).toFixed(1)} unit="Hz" color="text-amber-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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

echo "  -> src/app/embed/ac-circuits/page.tsx"
cat > "src/app/embed/ac-circuits/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'waveform' | 'reactance' | 'series-rlc' | 'parallel-rlc' | 'resonance';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

function ACEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'reactance' || t === 'series-rlc' || t === 'parallel-rlc' || t === 'resonance' ? t : 'waveform';
  })();
  const showControls = sp.get('controls') !== '0';

  const [vPeak, setVPeak] = useState(() => num(sp, 'v', 20, 5, 50));
  const [frequency, setFrequency] = useState(() => num(sp, 'f', 2, 0.5, 5));
  const [resistance, setResistance] = useState(() => num(sp, 'r', 100, 10, 500));
  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance] = useState(0.5);
  const [capacitance] = useState(10);
  const [rlcFrequency, setRlcFrequency] = useState(50);
  const [parallelResistance, setParallelResistance] = useState(1000);
  const [resonanceCircuit, setResonanceCircuit] = useState<'series' | 'parallel'>('series');

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, parallelResistance, resonanceCircuit, reset]);

  const isSeriesTopic = topic === 'series-rlc';
  const isParallelTopic = topic === 'parallel-rlc';
  const effFrequency = isSeriesTopic || isParallelTopic ? rlcFrequency : frequency;
  const activeResistance = isParallelTopic ? parallelResistance : resistance;

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
        vPeak={vPeak} frequency={effFrequency} resistance={activeResistance}
        component={component} inductance={inductance} capacitance={capacitance * 1e-6}
        resonanceCircuit={resonanceCircuit}
        isRunning={isRunning} isPaused={isPaused} width={640} height={320} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
          {topic === 'waveform' && (
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
          )}
          {topic === 'reactance' && <>
            <div className="flex gap-2">
              {(['inductor', 'capacitor'] as const).map(c => (
                <button key={c} onClick={() => setComponent(c)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{c}</button>
              ))}
            </div>
            <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
          </>}
          {topic === 'series-rlc' && <>
            <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b" />
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
          </>}
          {topic === 'parallel-rlc' && <>
            <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b" />
            <Slider label="Resistance" unit="Ω" value={parallelResistance} min={100} max={3000} step={100} set={setParallelResistance} color="#059669" />
          </>}
          {topic === 'resonance' && (
            <div className="flex gap-2">
              {(['series', 'parallel'] as const).map(c => (
                <button key={c} onClick={() => setResonanceCircuit(c)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    resonanceCircuit === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{c}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ACEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ACEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  -> src/app/simulations/page.tsx (targeted find-and-replace only)"
python3 - << 'PYEOF2'
import sys

path = "src/app/simulations/page.tsx"
old_desc = 'AC waveforms and RMS values, inductive/capacitive reactance with phasor diagrams, and a series RLC circuit with impedance triangle and resonance. Secondary to undergraduate level.'
new_desc = 'AC waveforms and RMS values, inductive/capacitive reactance, series and parallel RLC circuits with real animated circuit diagrams, and Q-factor/bandwidth for resonance. Secondary to undergraduate level.'

try:
    with open(path, encoding="utf-8") as f:
        content = f.read()
except FileNotFoundError:
    print(f"  !! {path} not found -- skipping hub description update (nothing else touched).")
    sys.exit(0)

if old_desc in content:
    content = content.replace(old_desc, new_desc, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("  OK: AC Circuits card description updated in place.")
elif new_desc in content:
    print("  OK: AC Circuits card description already up to date -- no change needed.")
else:
    print("  !! Could not find the expected AC Circuits card description text in")
    print("     simulations/page.tsx (it may have been edited independently).")
    print("     Nothing was changed in this file -- update the card description")
    print("     by hand if you'd like it to mention the new Parallel RLC and")
    print("     Q-Factor/Bandwidth content:")
    print(f"     {new_desc}")
PYEOF2

echo ""
echo "Patch v46 applied."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/ac-circuits -- five tabs now: AC Waveform & RMS,"
echo "Inductive & Capacitive Reactance, Series RLC Circuit (rebuilt --"
echo "should now show an actual animated circuit with current flow),"
echo "Parallel RLC Circuit (new), and Q-Factor & Bandwidth (new)."
