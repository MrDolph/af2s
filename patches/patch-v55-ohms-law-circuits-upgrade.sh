#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v55: Ohm's Law & Circuits -- current
# divider clarity, electron/conventional flow toggle, non-ohmic
# conductors, collapsible teacher notes, and layout reorganisation
#
#   Does NOT touch simulations/page.tsx.
#
#   1. PARALLEL CURRENT DIVIDER, MADE UNMISTAKABLE. The underlying physics
#      was already correct (each branch's animated speed was already
#      proportional to that branch's real current, I=V/R per branch,
#      verified in the existing code before touching anything), but speed
#      alone can be a subtle visual cue. Now BOTH the speed and the
#      number of carrier dots in each branch scale with that branch's
#      current relative to the largest branch current -- the smallest
#      resistor's branch now visibly has more, faster-moving dots than
#      the largest resistor's branch, not just a subtle speed difference.
#
#   2. ELECTRON FLOW vs CONVENTIONAL CURRENT TOGGLE. Added a control that
#      switches between showing electron drift (amber dots, the
#      physically real direction) and conventional current (blue
#      arrowheads, the textbook + -> - direction) -- verified numerically
#      that the two directions are genuine mirror images of each other
#      along the same wire path, not just relabelled.
#
#   3. NON-OHMIC CONDUCTORS -- a new topic added alongside Ohm's law,
#      Series, and Parallel: filament lamp, thermistor (NTC), and diode,
#      each with a real, physically-motivated I-V model plotted against
#      a straight ohmic reference line for direct comparison. An initial
#      thermistor model (resistance falling as 1/(1+kI^2)) was verified
#      numerically to have a genuine negative-resistance region beyond a
#      critical current -- making it non-invertible and numerically
#      unstable for a live demo -- and was replaced with an always-
#      monotonic power-law model verified to give the correct concave-up
#      shape safely. The diode uses the standard exponential (Shockley)
#      equation, verified to show negligible current below ~0.6V then a
#      sharp rise, matching a real silicon diode's threshold behaviour.
#
#   4. Collapsible Teacher notes card, matching the pattern already
#      shipped for AC Circuits -- defaults to collapsed for a cleaner
#      first look at the page.
#
#   5. Parameters card moved to sit BELOW the Curriculum card (per this
#      specific request -- note this is a different position from the AC
#      Circuits page, where it was placed above Calculated instead).
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v55-ohms-law-circuits-upgrade.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v55: Ohm's Law & Circuits upgrade (no hub file changes) --"
mkdir -p "src/app/embed/circuits" "src/app/simulations/ohms-law" "src/components/simulation" "src/lib/physics"

echo "  -> src/lib/physics/circuits.ts"
cat > "src/lib/physics/circuits.ts" << 'AFEOF'
// ── Ohm's law & DC circuits ───────────────────────────────────────────────────
// V = IR.  P = VI = I²R = V²/R.

export function ohmCurrent(V: number, R: number) {
  return R > 0 ? V / R : 0;
}
export function power(V: number, I: number) {
  return V * I;
}

// ── Series: same current everywhere, voltages add ─────────────────────────────
export function seriesTotal(resistors: number[]) {
  return resistors.reduce((a, r) => a + r, 0);
}
export function seriesAnalysis(V: number, resistors: number[]) {
  const Rtotal = seriesTotal(resistors);
  const I = ohmCurrent(V, Rtotal);
  return {
    Rtotal,
    I,
    drops: resistors.map(R => I * R),   // voltage divider: V_i = I·R_i
    powers: resistors.map(R => I * I * R),
    Ptotal: V * I,
  };
}

// ── Parallel: same voltage everywhere, currents add ───────────────────────────
export function parallelTotal(resistors: number[]) {
  const invSum = resistors.reduce((a, r) => a + (r > 0 ? 1 / r : 0), 0);
  return invSum > 0 ? 1 / invSum : 0;
}
export function parallelAnalysis(V: number, resistors: number[]) {
  const Rtotal = parallelTotal(resistors);
  const branches = resistors.map(R => ohmCurrent(V, R)); // current divider: I_i = V/R_i
  const I = branches.reduce((a, i) => a + i, 0);
  return {
    Rtotal,
    I,
    branches,
    powers: resistors.map(R => (V * V) / R),
    Ptotal: V * I,
  };
}

// I–V characteristic points for a fixed resistance (straight line, slope 1/R).
export function ivLine(R: number, vMax: number, points = 50) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +ohmCurrent(v, R).toFixed(4) };
  });
}

// ── Non-ohmic conductors ──────────────────────────────────────────────────────
// These use simplified but always-monotonic, numerically-stable models
// (a power law for the lamp/thermistor, the standard exponential diode
// equation) chosen specifically to reliably reproduce the correct
// QUALITATIVE shape taught at this level — a curved, concave-down or
// concave-up I–V graph rather than a straight ohmic line — while
// remaining safe to invert and animate. An earlier resistance-vs-current
// model for the thermistor (R falling as 1/(1+kI²)) was tried and
// rejected: verified numerically that it has a genuine negative-
// resistance region beyond a critical current, making V(I) non-monotonic
// and impossible to invert reliably for a live demo.
export type NonOhmicDevice = 'filament' | 'diode' | 'thermistor';

// Filament lamp: resistance RISES as it self-heats, so current grows
// SLOWER than linearly with voltage (concave down).
export function filamentLampCurrent(V: number, c: number): number {
  return V > 0 ? c * Math.pow(V, 0.55) : 0;
}
// Thermistor (NTC): resistance FALLS as it self-heats, so current grows
// FASTER than linearly with voltage (concave up).
export function thermistorCurrent(V: number, c: number): number {
  return V > 0 ? c * Math.pow(V, 1.5) : 0;
}
// Diode: negligible current below the threshold voltage, then a sharp
// exponential rise (the standard Shockley diode equation). Reverse bias
// (V<0) is treated as an ideal block (I=0) for this teaching demo.
export function diodeCurrent(V: number, Is = 1e-9, n = 1.8, Vt = 0.026): number {
  if (V <= 0) return 0;
  return Is * (Math.exp(V / (n * Vt)) - 1);
}
// A single reference constant so the lamp/thermistor curves cross the
// ohmic reference line at a shared, fair comparison point.
export function nonOhmicCalibration(refR: number, refV: number) {
  const refI = ohmCurrent(refV, refR);
  return {
    cLamp: refI / Math.pow(refV, 0.55),
    cTherm: refI / Math.pow(refV, 1.5),
  };
}
export function nonOhmicCurrent(device: NonOhmicDevice, V: number, cLamp: number, cTherm: number): number {
  if (device === 'filament') return filamentLampCurrent(V, cLamp);
  if (device === 'thermistor') return thermistorCurrent(V, cTherm);
  return diodeCurrent(V);
}
export function nonOhmicIVLine(device: NonOhmicDevice, vMax: number, cLamp: number, cTherm: number, points = 60) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +nonOhmicCurrent(device, v, cLamp, cTherm).toFixed(6) };
  });
}
AFEOF

echo "  -> src/components/simulation/CircuitCanvas.tsx"
cat > "src/components/simulation/CircuitCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  seriesAnalysis, parallelAnalysis, ohmCurrent,
  nonOhmicCurrent, nonOhmicCalibration, NonOhmicDevice,
} from '@/lib/physics/circuits';

export type CircuitMode = 'ohm' | 'series' | 'parallel' | 'non-ohmic';
export type FlowDisplay = 'electron' | 'conventional';

interface Props {
  mode: CircuitMode;
  voltage: number;
  r1: number; r2: number; r3: number;
  nonOhmicDevice: NonOhmicDevice;
  flowDisplay: FlowDisplay;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draw a resistor zig-zag along a horizontal segment.
function drawResistor(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, label: string, value: number, vertical = false) {
  const teeth = 6, amp = 7;
  ctx.save();
  ctx.translate(x, y);
  if (vertical) ctx.rotate(Math.PI / 2);
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(0, 0);
  const seg = len / (teeth + 1);
  ctx.lineTo(seg / 2, 0);
  for (let i = 0; i < teeth; i++) {
    ctx.lineTo(seg / 2 + seg * i + seg / 2, i % 2 === 0 ? -amp : amp);
  }
  ctx.lineTo(len - seg / 2, 0); ctx.lineTo(len, 0);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  if (vertical) ctx.fillText(`${label}=${value}Ω`, x + 24, y + len / 2 + 3);
  else ctx.fillText(`${label}=${value}Ω`, x + len / 2, y - 14);
  ctx.restore();
}

// Filament lamp symbol: circle with a filament cross inside — the
// standard, recognisable IEC-style lamp symbol.
function drawLamp(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, glow: number) {
  const cx = x + len / 2, r = 16;
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(cx - r, y); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + r, y); ctx.lineTo(x + len, y); ctx.stroke();
  ctx.save();
  if (glow > 0.05) {
    const glowGrad = ctx.createRadialGradient(cx, y, 2, cx, y, r * 2.2);
    glowGrad.addColorStop(0, `rgba(250,204,21,${Math.min(0.6, glow * 0.6)})`);
    glowGrad.addColorStop(1, 'rgba(250,204,21,0)');
    ctx.fillStyle = glowGrad;
    ctx.beginPath(); ctx.arc(cx, y, r * 2.2, 0, Math.PI * 2); ctx.fill();
  }
  ctx.fillStyle = glow > 0.05 ? `rgba(255,251,235,1)` : '#f8fafc';
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, y, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = glow > 0.05 ? '#f59e0b' : '#94a3b8'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(cx - r * 0.55, y - r * 0.55); ctx.lineTo(cx + r * 0.55, y + r * 0.55); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx - r * 0.55, y + r * 0.55); ctx.lineTo(cx + r * 0.55, y - r * 0.55); ctx.stroke();
  ctx.restore();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('Filament lamp', cx, y - r - 8);
}

// Diode symbol: triangle in the direction of conventional current flow,
// with a bar at the tip (cathode).
function drawDiode(ctx: CanvasRenderingContext2D, x: number, y: number, len: number) {
  const cx = x + len / 2, half = 12;
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(cx - half, y); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + half, y); ctx.lineTo(x + len, y); ctx.stroke();
  ctx.fillStyle = '#f8fafc'; ctx.strokeStyle = '#475569';
  ctx.beginPath();
  ctx.moveTo(cx - half, y - half); ctx.lineTo(cx - half, y + half); ctx.lineTo(cx + half, y); ctx.closePath();
  ctx.fill(); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + half, y - half); ctx.lineTo(cx + half, y + half); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('Diode', cx, y - half - 10);
}

function drawBattery(ctx: CanvasRenderingContext2D, x: number, y: number, V: number) {
  ctx.save();
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  // long plate (+) and short plate (−)
  ctx.beginPath(); ctx.moveTo(x, y - 16); ctx.lineTo(x, y + 16); ctx.stroke();
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(x + 10, y - 8); ctx.lineTo(x + 10, y + 8); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('+', x - 8, y - 20);
  ctx.fillText('−', x + 18, y - 20);
  ctx.fillText(`${V}V`, x + 5, y + 32);
  ctx.restore();
}

// A wire path is a list of points; charge carriers travel along it,
// distance parameterised by arc length so their SPEED on screen ∝ actual
// current.
type Path = { pts: [number, number][]; length: number; segLens: number[] };
function makePath(pts: [number, number][]): Path {
  const segLens: number[] = [];
  let length = 0;
  for (let i = 1; i < pts.length; i++) {
    const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1];
    const l = Math.hypot(dx, dy);
    segLens.push(l); length += l;
  }
  return { pts, length, segLens };
}
function pointAt(path: Path, dist: number): [number, number] {
  let d = ((dist % path.length) + path.length) % path.length;
  for (let i = 0; i < path.segLens.length; i++) {
    if (d <= path.segLens[i]) {
      const f = path.segLens[i] === 0 ? 0 : d / path.segLens[i];
      const [x1, y1] = path.pts[i], [x2, y2] = path.pts[i + 1];
      return [x1 + (x2 - x1) * f, y1 + (y2 - y1) * f];
    }
    d -= path.segLens[i];
  }
  return path.pts[path.pts.length - 1];
}
function drawWire(ctx: CanvasRenderingContext2D, path: Path) {
  ctx.save();
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(path.pts[0][0], path.pts[0][1]);
  path.pts.slice(1).forEach(p => ctx.lineTo(p[0], p[1]));
  ctx.stroke();
  ctx.restore();
}
// Draws either electron flow (amber dots, physically correct drift
// direction) or conventional current (blue arrowheads, the textbook +→−
// direction — the OPPOSITE way along the same path) depending on
// flowDisplay. Dot/arrow count and speed both scale with current, so a
// bigger current reads as visibly "more" as well as "faster" — speed
// alone can be a subtle cue; density makes the difference unmistakable.
function drawCarriers(
  ctx: CanvasRenderingContext2D, path: Path, t: number, current: number, maxCurrent: number,
  flowDisplay: FlowDisplay,
) {
  if (current <= 0.0005) return;
  const frac = Math.max(0.12, Math.min(1, current / Math.max(maxCurrent, 0.0001)));
  const speed = Math.min(30 + current * 22, 170);
  const count = Math.max(3, Math.round(4 + frac * 12));
  const dir = flowDisplay === 'electron' ? 1 : -1;
  ctx.save();
  for (let i = 0; i < count; i++) {
    const d = dir * t * speed + (i / count) * path.length;
    const [x, y] = pointAt(path, d);
    if (flowDisplay === 'electron') {
      ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2);
      ctx.fillStyle = '#f59e0b'; ctx.fill();
    } else {
      // small arrowhead pointing along the conventional-current direction
      const dNext = dir * (t * speed + 0.6) + (i / count) * path.length;
      const [x2, y2] = pointAt(path, dNext);
      const ang = Math.atan2(y2 - y, x2 - x);
      ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
      ctx.fillStyle = '#2563eb';
      ctx.beginPath(); ctx.moveTo(4, 0); ctx.lineTo(-3, -2.6); ctx.lineTo(-3, 2.6); ctx.closePath(); ctx.fill();
      ctx.restore();
    }
  }
  ctx.restore();
}

export function CircuitCanvas({
  mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay,
  isRunning, isPaused, width = 640, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay, isRunning, isPaused });
  sim.current = { mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — carrier drift speed on screen stays proportional
    // to the actual current at any display refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const L = 70, R = W - 70, T = 60, B = H - 50;

    if (s.mode === 'ohm') {
      const I = ohmCurrent(s.voltage, s.r1);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, rX, T, rLen, 'R', s.r1);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, I, I, s.flowDisplay);
      // Ammeter bubble
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${I.toFixed(2)}A`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'non-ohmic') {
      const { cLamp, cTherm } = nonOhmicCalibration(s.r1, 12);
      const I = nonOhmicCurrent(s.nonOhmicDevice, s.voltage, cLamp, cTherm);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      if (s.nonOhmicDevice === 'filament') drawLamp(ctx, rX, T, rLen, I / Math.max(0.01, ohmCurrent(24, s.r1)));
      else if (s.nonOhmicDevice === 'diode') drawDiode(ctx, rX, T, rLen);
      else drawResistor(ctx, rX, T, rLen, 'Rth', Math.round(s.voltage / Math.max(I, 0.0001)));
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, I, Math.max(I, 0.5), s.flowDisplay);
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${(I * 1000).toFixed(I > 0.05 ? 0 : 2)}${I > 0.05 ? 'mA' : 'A'}`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'series') {
      const a = seriesAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const rLen = 90, gap = (R - L - 3 * rLen) / 4;
      const xs = [L + gap, L + gap * 2 + rLen, L + gap * 3 + rLen * 2];
      const loop = makePath([[L, B], [L, T], ...xs.flatMap((x): [number, number][] => [[x, T], [x + rLen, T]]), [R, T], [R, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, xs[0], T, rLen, 'R₁', s.r1);
      drawResistor(ctx, xs[1], T, rLen, 'R₂', s.r2);
      drawResistor(ctx, xs[2], T, rLen, 'R₃', s.r3);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, a.I, a.I, s.flowDisplay);
      // Voltage drop labels under each resistor — the divider in action.
      ctx.save();
      ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      xs.forEach((x, i) => ctx.fillText(`${a.drops[i].toFixed(2)}V`, x + rLen / 2, T + 22));
      ctx.restore();
    }

    if (s.mode === 'parallel') {
      const a = parallelAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const maxBranch = Math.max(...a.branches, 0.0001);
      const bx1 = L + 90, bx2 = R - 90;
      const rows = [T, (T + B) / 2 - 10, B - 60];
      const rLen = bx2 - bx1 - 60;
      // Main loop through the top branch, plus each branch loop.
      const branchPaths = rows.map(y => makePath([
        [L, B], [L, y], [bx1, y], [bx1 + 30, y], [bx1 + 30 + rLen, y], [bx2, y], [R, y], [R, B], [L, B],
      ]));
      // Rails
      ctx.save(); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(L, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(R, B); ctx.lineTo(R, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(R, B); ctx.stroke();
      rows.forEach(y => { ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke(); });
      ctx.restore();
      const labels = ['R₁', 'R₂', 'R₃'], vals = [s.r1, s.r2, s.r3];
      rows.forEach((y, i) => {
        drawResistor(ctx, bx1 + 30, y, rLen, labels[i], vals[i]);
        // Carriers per branch — BOTH speed and density scale with that
        // branch's own current relative to the largest branch current,
        // so the current-divider effect (smallest R -> largest I) is
        // unmistakable, not just a subtle speed difference.
        drawCarriers(ctx, branchPaths[i], t, a.branches[i], maxBranch, s.flowDisplay);
        ctx.save();
        ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`${a.branches[i].toFixed(2)}A`, bx2 + 6, y - 6);
        ctx.restore();
      });
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(
      s.flowDisplay === 'electron'
        ? '● electron flow (speed & density ∝ current) — the ACTUAL direction charge carriers move'
        : '▶ conventional current (+ → −) — the direction used in circuit analysis, OPPOSITE to electron flow',
      8, H - 8,
    );

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

echo "  -> src/app/simulations/ohms-law/page.tsx"
cat > "src/app/simulations/ohms-law/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, Legend } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CircuitCanvas, CircuitMode, FlowDisplay } from '@/components/simulation/CircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  ohmCurrent, seriesAnalysis, parallelAnalysis, ivLine,
  nonOhmicCalibration, nonOhmicIVLine, nonOhmicCurrent, NonOhmicDevice,
} from '@/lib/physics/circuits';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<CircuitMode, { title: string; icon: string; sub: string; eq: string }> = {
  ohm:        { title: "Ohm's law",      icon: '⚡', sub: 'Single resistor',            eq: 'V = IR' },
  series:     { title: 'Series',         icon: '🔗', sub: 'Same current, voltages add', eq: 'R = R₁+R₂+R₃' },
  parallel:   { title: 'Parallel',       icon: '🪜', sub: 'Same voltage, currents add', eq: '1/R = 1/R₁+1/R₂+1/R₃' },
  'non-ohmic': { title: 'Non-ohmic',     icon: '📉', sub: 'V = IR does NOT hold',       eq: 'I ≠ kV' },
};

const TEACHER_NOTES: Record<CircuitMode, string[]> = {
  ohm: [
    'V = IR only holds for OHMIC conductors — the I–V graph is a straight line through the origin whose slope is 1/R.',
    'The carrier animation shows drift speed ∝ current: double the voltage, double the speed.',
    'Conventional current flows + → −, but the electrons physically drift the opposite way — try the flow-direction toggle to see both.',
    'Power dissipated P = VI = I²R = V²/R — a resistor converts electrical energy to heat.',
    'Try the sliders on the I–V graph: the operating point always sits on the line for a fixed R.',
  ],
  series: [
    'The SAME current flows through every component — there is only one path.',
    'Voltages divide in proportion to resistance: V₁/V₂ = R₁/R₂ (the potential divider).',
    'Total resistance is always LARGER than the largest single resistor.',
    'One broken component breaks the whole circuit — why old fairy lights all went out together.',
    'Check: the three voltage drops on the canvas always sum to the supply voltage.',
  ],
  parallel: [
    'Every branch gets the FULL supply voltage; the currents divide instead.',
    'The current divider: the SMALLEST resistance takes the LARGEST current, and the LARGEST resistance takes the smallest — watch both the electron speed AND how many dots are moving in each branch.',
    'Total resistance is always SMALLER than the smallest single resistor.',
    'House wiring is parallel: every appliance gets mains voltage, and one failing does not kill the rest.',
    'Check: branch currents on the canvas always sum to the total from the battery.',
  ],
  'non-ohmic': [
    'A NON-OHMIC conductor does NOT obey V = IR with a constant R — its I–V graph is curved, not a straight line, because its resistance itself changes as current flows.',
    'Filament lamp: as current flows, the filament heats up and its resistance RISES — so current grows more SLOWLY than voltage at higher V (the curve bends toward the V-axis, concave down).',
    'Thermistor (NTC — negative temperature coefficient): the opposite happens — resistance FALLS as it heats, so current grows FASTER than voltage at higher V (concave up).',
    'Diode: current is essentially ZERO below a threshold voltage (~0.6-0.7V for silicon), then rises very steeply — a diode only conducts easily in ONE direction, which is exactly why it is used to convert AC to DC.',
    'Undergraduate note: these curves are simplified, always-well-behaved teaching models chosen to show the correct QUALITATIVE shape (concave up/down, or a sharp threshold) rather than an exact material-specific derivation — a real filament\u2019s resistance-vs-temperature relationship and a real diode\u2019s reverse-bias behaviour are each their own, more detailed topics.',
  ],
};

const EXERCISES: Record<CircuitMode, { q: string; a: string }[]> = {
  ohm: [
    { q: 'A 12V battery drives a current of 3A through a resistor. Find R and the power dissipated.', a: 'R=V/I=12/3=4Ω. P=VI=12×3=36W.' },
    { q: 'The I–V graph of a conductor is a straight line of slope 0.25 A/V. Find its resistance.', a: 'Slope = 1/R → R = 1/0.25 = 4Ω.' },
    { q: 'An electric kettle rated 2000W runs on 230V mains. Find the current and its resistance.', a: 'I=P/V=2000/230≈8.7A. R=V/I=230/8.7≈26.4Ω.' },
  ],
  series: [
    { q: 'R₁=2Ω, R₂=3Ω, R₃=5Ω in series with a 20V battery. Find the current and V across R₂.', a: 'R=10Ω. I=20/10=2A. V₂=IR₂=2×3=6V.' },
    { q: 'Two resistors in series carry 0.5A. If V₁=3V and the supply is 9V, find R₂.', a: 'V₂=9−3=6V. R₂=V₂/I=6/0.5=12Ω.' },
    { q: 'Why does adding a resistor in series always reduce the current?', a: 'Total R increases (R = ΣRᵢ), and I = V/R with fixed V, so I falls.' },
  ],
  parallel: [
    { q: 'R₁=6Ω and R₂=3Ω in parallel across 12V. Find each branch current and the total.', a: 'I₁=12/6=2A, I₂=12/3=4A. Total I=6A (and R=2Ω checks: 12/2=6A).' },
    { q: 'Find the combined resistance of 4Ω, 6Ω and 12Ω in parallel.', a: '1/R=1/4+1/6+1/12=3/12+2/12+1/12=6/12 → R=2Ω.' },
    { q: 'Two equal resistors R in parallel — what is the combined resistance?', a: 'R/2. Equal resistors in parallel halve the resistance.' },
  ],
  'non-ohmic': [
    { q: 'A filament lamp and a fixed resistor have the same resistance at their normal operating voltage. At a LOWER voltage, which passes more current?', a: 'The filament lamp — its resistance is lower when cold (not yet heated by the current), so at a lower voltage it briefly behaves like a smaller resistor than the fixed one it was compared to.' },
    { q: 'A silicon diode has almost zero current until about 0.6V, then rises steeply. What circuit-level use does this threshold behaviour enable?', a: 'It lets the diode act as a one-way valve for current (rectification) and as a way to fix a nearly-constant voltage drop across it once conducting — both used throughout electronics, e.g. converting AC to DC.' },
    { q: 'Why can\u2019t a single fixed value of R describe a non-ohmic conductor across its whole I–V graph?', a: 'Because its resistance (V/I at each point) genuinely CHANGES as the operating point moves along the curve — R is only a true constant for a straight-line, ohmic I–V graph through the origin.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

// I–V characteristic with the live operating point sitting ON the line.
function IVGraph({ R, V }: { R: number; V: number }) {
  const vMax = 24;
  const data = useMemo(() => ivLine(R, vMax), [R]);
  const I = ohmCurrent(V, R);
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="v" type="number" tick={{ fontSize: 10 }} domain={[0, vMax]}>
          <Label value="Voltage V (V)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Current I (A)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3) + ' A']} labelFormatter={v => `V=${v}V`} />
        <Line type="monotone" dataKey="i" stroke="#6366f1" strokeWidth={2} dot={false} />
        <ReferenceDot x={V} y={I} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

// Non-ohmic comparison graph: the selected device's curve alongside a
// straight ohmic reference line, so the curvature (or sharp threshold)
// is immediately visible against a known-linear baseline.
function NonOhmicGraph({ device, refR, V }: { device: NonOhmicDevice; refR: number; V: number }) {
  const vMax = device === 'diode' ? 1 : 24;
  const { cLamp, cTherm } = useMemo(() => nonOhmicCalibration(refR, 12), [refR]);
  const ohmicData = useMemo(() => ivLine(refR, vMax), [refR, vMax]);
  const deviceData = useMemo(() => nonOhmicIVLine(device, vMax, cLamp, cTherm), [device, vMax, cLamp, cTherm]);
  const merged = ohmicData.map((d, i) => ({ v: d.v, ohmic: d.i, device: deviceData[i]?.i ?? 0 }));
  const I = nonOhmicCurrent(device, Math.min(V, vMax), cLamp, cTherm);
  const deviceLabel = device === 'filament' ? 'Filament lamp' : device === 'diode' ? 'Diode' : 'Thermistor';
  return (
    <ResponsiveContainer width="100%" height={210}>
      <LineChart data={merged} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="v" type="number" tick={{ fontSize: 10 }} domain={[0, vMax]}>
          <Label value="Voltage V (V)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Current I (A)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4) + ' A']} labelFormatter={v => `V=${v}V`} />
        <Legend wrapperStyle={{ fontSize: 10 }} />
        <Line type="monotone" dataKey="ohmic" name="Ohmic (fixed R)" stroke="#94a3b8" strokeWidth={1.5} strokeDasharray="4 3" dot={false} />
        <Line type="monotone" dataKey="device" name={deviceLabel} stroke="#dc2626" strokeWidth={2.2} dot={false} />
        <ReferenceDot x={Math.min(V, vMax)} y={I} r={6} fill="#dc2626" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function OhmsLawPage() {
  const [mode, setMode] = useState<CircuitMode>('ohm');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [showParams, setShowParams] = useState(true);
  const [showTeacherNotes, setShowTeacherNotes] = useState(false);

  const [V, setV] = useState(12);
  const [r1, setR1] = useState(4);
  const [r2, setR2] = useState(6);
  const [r3, setR3] = useState(12);
  const [nonOhmicDevice, setNonOhmicDevice] = useState<NonOhmicDevice>('filament');
  const [flowDisplay, setFlowDisplay] = useState<FlowDisplay>('electron');

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
  }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, V, r1, r2, r3, nonOhmicDevice, flowDisplay, reset]);

  const ser = seriesAnalysis(V, [r1, r2, r3]);
  const par = parallelAnalysis(V, [r1, r2, r3]);
  const I1 = ohmCurrent(V, r1);
  const { cLamp, cTherm } = nonOhmicCalibration(r1, 12);
  const Inon = nonOhmicCurrent(nonOhmicDevice, mode === 'non-ohmic' && nonOhmicDevice === 'diode' ? Math.min(V, 1) : V, cLamp, cTherm);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity</p>
                <h1 className="text-lg font-semibold text-gray-900">Ohm&apos;s law &amp; circuits</h1>
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
            {(Object.keys(MODE_META) as CircuitMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            {mode !== 'non-ohmic' && <span className="text-xs text-gray-400 ml-2">P = VI = I²R = V²/R</span>}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
                  nonOhmicDevice={nonOhmicDevice} flowDisplay={flowDisplay}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2 flex-wrap">
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                  <div className="flex rounded-lg border border-gray-200 overflow-hidden">
                    {(['electron', 'conventional'] as const).map(f => (
                      <button key={f} onClick={() => setFlowDisplay(f)}
                        className={`px-2.5 py-2 text-xs font-medium transition ${
                          flowDisplay === f ? 'bg-indigo-50 text-indigo-700' : 'bg-white text-gray-500 hover:bg-gray-50'
                        }`}>{f === 'electron' ? '● Electron flow' : '▶ Conventional I'}</button>
                    ))}
                  </div>
                </div>
                <EmbedButton path="/embed/circuits"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, V, r1, r2, r3 }} />
              </div>

              {mode === 'ohm' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">I–V characteristic</p>
                  <IVGraph R={r1} V={V} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Straight line through the origin — the red dot is the current operating point (slope = 1/R)
                  </p>
                </div>
              )}

              {mode === 'non-ohmic' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">I–V characteristic</p>
                    <div className="flex gap-1">
                      {(['filament', 'thermistor', 'diode'] as const).map(d => (
                        <button key={d} onClick={() => setNonOhmicDevice(d)}
                          className={`px-2 py-1 rounded-md text-[10px] font-medium capitalize transition ${
                            nonOhmicDevice === d ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                          }`}>{d}</button>
                      ))}
                    </div>
                  </div>
                  <NonOhmicGraph device={nonOhmicDevice} refR={r1} V={V} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Red curve = the non-ohmic device; grey dashed line = an ohmic resistor for comparison — same R at V=12V
                  </p>
                </div>
              )}
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'ohm' && <>
                    <StatRow label="Current I" value={I1.toFixed(3)} unit="A" color="text-indigo-600" />
                    <StatRow label="Power P" value={(V * I1).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Charge in 60s" value={(I1 * 60).toFixed(1)} unit="C" color="text-amber-600" />
                    <StatRow label="Energy in 60s" value={(V * I1 * 60).toFixed(0)} unit="J" color="text-rose-500" />
                  </>}
                  {mode === 'series' && <>
                    <StatRow label="Total R" value={ser.Rtotal.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Current I" value={ser.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="V across R₁" value={ser.drops[0].toFixed(2)} unit="V" color="text-amber-600" />
                    <StatRow label="V across R₂" value={ser.drops[1].toFixed(2)} unit="V" color="text-rose-500" />
                    <StatRow label="V across R₃" value={ser.drops[2].toFixed(2)} unit="V" color="text-purple-600" />
                    <StatRow label="Total power" value={ser.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                  {mode === 'parallel' && <>
                    <StatRow label="Total R" value={par.Rtotal.toFixed(2)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Total current" value={par.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="I through R₁" value={par.branches[0].toFixed(3)} unit="A" color="text-amber-600" />
                    <StatRow label="I through R₂" value={par.branches[1].toFixed(3)} unit="A" color="text-rose-500" />
                    <StatRow label="I through R₃" value={par.branches[2].toFixed(3)} unit="A" color="text-purple-600" />
                    <StatRow label="Total power" value={par.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                  {mode === 'non-ohmic' && <>
                    <StatRow label="Device" value={nonOhmicDevice} unit="" color="text-indigo-600" />
                    <StatRow label="Current at this V" value={(Inon * (nonOhmicDevice === 'diode' ? 1000 : 1)).toFixed(nonOhmicDevice === 'diode' ? 3 : 3)} unit={nonOhmicDevice === 'diode' ? 'mA' : 'A'} color="text-emerald-600" />
                    <StatRow label="Apparent R (V/I)" value={Inon > 0.0001 ? (Math.min(V, nonOhmicDevice === 'diode' ? 1 : V) / Inon).toFixed(1) : '∞'} unit="Ω" color="text-amber-600" />
                    <StatRow label="Obeys V=IR?" value="NO" unit="(R not constant)" color="text-rose-500" />
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

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                  <button onClick={() => setShowParams(p => !p)}
                    className="text-xs font-medium text-indigo-600 hover:text-indigo-700 flex items-center gap-1">
                    {showParams ? 'Hide' : 'Show'}
                    <span className={`transition-transform ${showParams ? 'rotate-180' : ''}`}>▾</span>
                  </button>
                </div>
                {showParams && <>
                  <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
                  {mode !== 'non-ohmic' && (
                    <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
                  )}
                  {mode === 'non-ohmic' && (
                    <Slider label="Reference R (for comparison)" unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
                  )}
                  {(mode === 'series' || mode === 'parallel') && <>
                    <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
                    <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
                  </>}
                </>}
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-xs font-medium text-amber-700 uppercase tracking-wide">📋 Teacher notes</p>
                  <button onClick={() => setShowTeacherNotes(p => !p)}
                    className="text-xs font-medium text-amber-700 hover:text-amber-800 flex items-center gap-1">
                    {showTeacherNotes ? 'Hide' : 'Show'}
                    <span className={`transition-transform ${showTeacherNotes ? 'rotate-180' : ''}`}>▾</span>
                  </button>
                </div>
                {showTeacherNotes && (
                  <ul className="space-y-2">
                    {TEACHER_NOTES[mode].map((n, i) => (
                      <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                        <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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

echo "  -> src/app/embed/circuits/page.tsx"
cat > "src/app/embed/circuits/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CircuitCanvas, CircuitMode, FlowDisplay } from '@/components/simulation/CircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { NonOhmicDevice } from '@/lib/physics/circuits';

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

function CircuitsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): CircuitMode => {
    const m = sp.get('mode');
    return m === 'series' || m === 'parallel' || m === 'non-ohmic' ? m : 'ohm';
  })();
  const showControls = sp.get('controls') !== '0';

  const [V, setV] = useState(() => num(sp, 'V', 12, 1, 24));
  const [r1, setR1] = useState(() => num(sp, 'r1', 4, 1, 50));
  const [r2, setR2] = useState(() => num(sp, 'r2', 6, 1, 50));
  const [r3, setR3] = useState(() => num(sp, 'r3', 12, 1, 50));
  const [nonOhmicDevice, setNonOhmicDevice] = useState<NonOhmicDevice>('filament');
  const [flowDisplay, setFlowDisplay] = useState<FlowDisplay>('electron');

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [V, r1, r2, r3, nonOhmicDevice, flowDisplay, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
        nonOhmicDevice={nonOhmicDevice} flowDisplay={flowDisplay}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <div className="flex items-center gap-2 flex-wrap">
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
        <div className="flex rounded-lg border border-gray-200 overflow-hidden">
          {(['electron', 'conventional'] as const).map(f => (
            <button key={f} onClick={() => setFlowDisplay(f)}
              className={`px-2 py-2 text-xs font-medium transition ${
                flowDisplay === f ? 'bg-indigo-50 text-indigo-700' : 'bg-white text-gray-500'
              }`}>{f === 'electron' ? '● Electron' : '▶ Conventional'}</button>
          ))}
        </div>
      </div>
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
            {mode !== 'non-ohmic' && (
              <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
            )}
            {mode === 'non-ohmic' && (
              <Slider label="Reference R" unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
            )}
            {(mode === 'series' || mode === 'parallel') && <>
              <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
              <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
            </>}
          </div>
          {mode === 'non-ohmic' && (
            <div className="flex gap-1 mt-3">
              {(['filament', 'thermistor', 'diode'] as const).map(d => (
                <button key={d} onClick={() => setNonOhmicDevice(d)}
                  className={`px-2 py-1 rounded-md text-[10px] font-medium capitalize transition ${
                    nonOhmicDevice === d ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-500'
                  }`}>{d}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function CircuitsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <CircuitsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "Patch v55 applied -- 4 files written. simulations/page.tsx was NOT touched."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/ohms-law -- five tabs now: Ohm's law, Series,"
echo "Parallel, and the new Non-ohmic tab (with a Filament/Thermistor/"
echo "Diode selector and comparison graph). Try the Electron/Conventional"
echo "flow toggle on any tab, and check the Parallel tab -- the smallest"
echo "resistor's branch should now visibly have both more AND faster"
echo "dots than the largest resistor's branch."
