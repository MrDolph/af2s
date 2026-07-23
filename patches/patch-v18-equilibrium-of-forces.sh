#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v18: new "Equilibrium of Forces" module
#
#   Four topics, matching WAEC/NECO/IGCSE treatment of the subject:
#
#   STATIC & DYNAMIC EQUILIBRIUM — same ΣF=0 condition either way; the demo
#   shows a block with two opposing forces, toggling between "static"
#   (starts at rest) and "dynamic" (starts already moving) so the common
#   exam trap — assuming equilibrium means "not moving" — is directly
#   visible: balanced forces on a moving body just mean it continues at
#   constant velocity, it doesn't stop.
#
#   CONCURRENT (NON-PARALLEL) COPLANAR FORCES — an animated force-triangle
#   construction: two forces A and B are drawn tip-to-tail, then the
#   equilibrant closes the triangle back to the start, visually proving
#   "closed polygon = equilibrium". Verified the resultant/equilibrant maths
#   against a hand-checked 6-8-10 triangle and a right-angle case.
#
#   PARALLEL COPLANAR FORCES — a see-saw beam that rotates under net torque
#   and settles (via a damped 2nd-order step response) to level if balanced
#   or to a physical tilt limit if not, driven by the real principle of
#   moments (Σclockwise M = Σanticlockwise M). Verified the classic
#   20N×0.5m = 10N×1m lever-balance case numerically.
#
#   FLOATING BODIES — density, relative density, and Archimedes' principle.
#   A block genuinely bobs to its equilibrium floating depth using the same
#   damped step-response physics as the elasticity spring (small vertical
#   displacements from equilibrium are physically real SHM, restored by
#   buoyancy) — verified numerically (overshoots then settles within ~1s
#   for a representative wooden block). Denser-than-liquid objects sink
#   instead, at a rate tied to the real sinking acceleration a=g(1-ρ_liq/
#   ρ_obj), bounded to a watchable ~1-3s regardless of slider values.
#   Verified the classic "90% of an iceberg is underwater" result falls
#   straight out of the submerged-fraction formula.
#
#   All four canvases use wall-clock timing throughout (no fixed-frame-
#   increment bugs) and are wired to Run/Pause/Reset like every other
#   simulation in the app. Added to the simulations hub and given a full
#   embed route covering all four topics.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v18-equilibrium-of-forces.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v18: new Equilibrium of Forces module ──"
mkdir -p "src/app/embed/equilibrium" "src/app/simulations" "src/app/simulations/equilibrium-of-forces" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/equilibrium.ts"
cat > "src/lib/physics/equilibrium.ts" << 'AFEOF'
export const G = 9.81;

// ── Static vs dynamic equilibrium ────────────────────────────────────────────
// Both are defined by the SAME condition — net force = zero — the only
// difference is whether the body happens to be at rest (static) or moving
// at constant velocity (dynamic). A common exam trap: students assume
// "equilibrium" always means "not moving".
export interface ForceBalance { netForce: number; equilibrium: boolean; }
export function checkBalance(f1: number, f2: number): ForceBalance {
  const net = f1 - f2;
  return { netForce: +net.toFixed(3), equilibrium: Math.abs(net) < 0.05 };
}

// ── Concurrent (non-parallel) coplanar forces ────────────────────────────────
export interface Vec2 { x: number; y: number; }
export function forceComponents(mag: number, angleDeg: number): Vec2 {
  const rad = (angleDeg * Math.PI) / 180;
  return { x: mag * Math.cos(rad), y: mag * Math.sin(rad) };
}
export function resultant(forces: Vec2[]): Vec2 {
  return forces.reduce((acc, f) => ({ x: acc.x + f.x, y: acc.y + f.y }), { x: 0, y: 0 });
}
export function vecMagnitude(v: Vec2): number {
  return Math.sqrt(v.x * v.x + v.y * v.y);
}
export function vecAngleDeg(v: Vec2): number {
  return (Math.atan2(v.y, v.x) * 180) / Math.PI;
}
// The single extra force that would bring a set of forces into equilibrium
// — equal in magnitude, opposite in direction to their resultant.
export function equilibrant(forces: Vec2[]): Vec2 {
  const r = resultant(forces);
  return { x: -r.x, y: -r.y };
}

// ── Parallel coplanar forces / moments ───────────────────────────────────────
// position: signed distance from the pivot along the beam (m), negative =
// left of pivot, positive = right. force: magnitude acting downward (N).
export interface Weight { force: number; position: number; }
export function momentOf(w: Weight): number {
  return w.force * w.position; // + = clockwise (right side), − = anticlockwise (left side)
}
export function netMoment(weights: Weight[]): number {
  return weights.reduce((sum, w) => sum + momentOf(w), 0);
}
export function isBalanced(weights: Weight[], tolerance = 0.15): boolean {
  return Math.abs(netMoment(weights)) < tolerance;
}
// The force needed at a given position to balance a set of other weights —
// the classic "principle of moments" exam question, rearranged to solve
// for the unknown.
export function balancingForce(weights: Weight[], atPosition: number): number {
  if (Math.abs(atPosition) < 1e-6) return 0;
  return -netMoment(weights) / atPosition;
}

// ── Floating bodies — density, relative density, Archimedes' principle ──────
export const LIQUIDS = [
  { name: 'Water',     density: 1000 },
  { name: 'Seawater',  density: 1025 },
  { name: 'Oil',       density: 800 },
  { name: 'Glycerin',  density: 1260 },
  { name: 'Mercury',   density: 13600 },
] as const;

export function relativeDensity(objDensity: number, referenceDensity = 1000): number {
  return objDensity / referenceDensity;
}
// Fraction of the object's volume submerged at equilibrium — from
// Archimedes' principle, weight = upthrust: ρ_obj·V·g = ρ_liquid·V_sub·g,
// so V_sub/V = ρ_obj/ρ_liquid. Clamped at 1 (a denser object simply sinks
// to the bottom rather than "submerging more than 100%").
export function submergedFraction(objDensity: number, liquidDensity: number): number {
  return Math.min(1, objDensity / liquidDensity);
}
export function upthrust(liquidDensity: number, submergedVolume: number): number {
  return liquidDensity * G * submergedVolume;
}
export function willFloat(objDensity: number, liquidDensity: number): boolean {
  return objDensity < liquidDensity;
}
// Terminal sinking acceleration for an object denser than the liquid —
// gravity reduced by the constant upthrust once fully submerged:
// a = g(1 − ρ_liquid/ρ_object).
export function sinkingAcceleration(objDensity: number, liquidDensity: number): number {
  return G * (1 - liquidDensity / objDensity);
}

// ── Shared damped step-response (used by both the parallel-forces beam and
// the floating-body bob) ─────────────────────────────────────────────────────
// The step response of a critically-tunable damped 2nd-order system settling
// from 0 to a target value — physically genuine for a floating body (small
// vertical displacements from equilibrium behave like SHM restored by
// buoyancy, effective stiffness k = ρ_liquid·g·A) and a reasonable, honest
// approximation for a beam settling under net torque.
export function dampedStepResponse(t: number, target: number, k: number, mass: number, zeta = 0.35): number {
  if (mass <= 0 || k <= 0 || t <= 0) return 0;
  const omega = Math.sqrt(k / mass);
  if (zeta >= 1) return target * (1 - Math.exp(-omega * t));
  const omegaD = omega * Math.sqrt(1 - zeta * zeta);
  return target * (1 - Math.exp(-zeta * omega * t) * (Math.cos(omegaD * t) + (zeta * omega / omegaD) * Math.sin(omegaD * t)));
}
AFEOF

echo "  → src/components/simulation/StaticDynamicCanvas.tsx"
cat > "src/components/simulation/StaticDynamicCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { checkBalance } from '@/lib/physics/equilibrium';

interface Props {
  scenario: 'static' | 'dynamic';
  f1: number; f2: number; // opposing horizontal forces, N
  mass: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (v: number, x: number) => void;
  width?: number; height?: number;
}

function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, dir: 1 | -1, color: string, label: string) {
  if (len < 2) return;
  const ex = x + dir * len;
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, y); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(ex, y);
  ctx.lineTo(ex - dir * 9, y - 6); ctx.lineTo(ex - dir * 9, y + 6);
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dir * len / 2, y - 10);
  ctx.restore();
}

export function StaticDynamicCanvas({ scenario, f1, f2, mass, isRunning, isPaused, onTick, width = 660, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const x = useRef(0);
  const v = useRef(0);
  const simRef = useRef({ scenario, f1, f2, mass, isRunning, isPaused, onTick });
  simRef.current = { scenario, f1, f2, mass, isRunning, isPaused, onTick };

  const INITIAL_V = 1.6; // m/s — the "already moving" starting speed for the dynamic scenario

  useEffect(() => {
    x.current = 0;
    v.current = scenario === 'dynamic' ? INITIAL_V : 0;
    lastFrameRef.current = null;
  }, [scenario, f1, f2, mass]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;
    const groundY = H - 50;

    const bal = checkBalance(s.f1, s.f2);
    const a = bal.netForce / s.mass; // + = rightward net force

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      v.current += a * dt;
      x.current += v.current * dt;
      // Wrap so a genuinely unbalanced / constant-velocity block never
      // just runs off-screen forever.
      const wrapRange = 140;
      if (x.current > wrapRange) x.current = -wrapRange;
      if (x.current < -wrapRange) x.current = wrapRange;
    }
    s.onTick?.(v.current, x.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();

    const cx = W / 2 + x.current;
    const bw = 64, bh = 48;
    const by = groundY - bh;
    const midY = by + bh / 2;

    ctx.fillStyle = bal.equilibrium ? '#6366f1' : '#f59e0b';
    ctx.beginPath(); ctx.roundRect(cx - bw / 2, by, bw, bh, 6); ctx.fill();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.mass}kg`, cx, midY + 4);

    // Force arrows — right-pulling f1 (green), left-pulling f2 (red)
    forceArrow(ctx, cx + bw / 2, midY, Math.min(s.f1 * 3, 130), 1, '#10b981', `F₁=${s.f1}N`);
    forceArrow(ctx, cx - bw / 2, midY, Math.min(s.f2 * 3, 130), -1, '#ef4444', `F₂=${s.f2}N`);

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (bal.equilibrium) {
      ctx.fillStyle = '#059669';
      ctx.fillText(
        s.scenario === 'static'
          ? 'ΣF = 0 — STATIC EQUILIBRIUM: at rest, and stays at rest'
          : `ΣF = 0 — DYNAMIC EQUILIBRIUM: moving at a constant ${INITIAL_V.toFixed(1)} m/s`,
        W / 2, 24,
      );
    } else {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText(`NOT in equilibrium — ΣF = ${bal.netForce.toFixed(1)}N, a = ${a.toFixed(2)} m/s²`, W / 2, 24);
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`v = ${v.current.toFixed(2)} m/s`, 8, H - 10);

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

echo "  → src/components/simulation/ConcurrentForcesCanvas.tsx"
cat > "src/components/simulation/ConcurrentForcesCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { forceComponents, resultant, equilibrant, vecMagnitude, vecAngleDeg, Vec2 } from '@/lib/physics/equilibrium';

interface Props {
  magA: number; angleA: number;
  magB: number; angleB: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

const BUILD_DURATION = 1.6; // s — time to animate drawing the force triangle

function drawArrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, lw = 2.5, dashed = false) {
  const len = Math.hypot(x2 - x1, y2 - y1);
  if (len < 2) return;
  ctx.save();
  if (dashed) ctx.setLineDash([5, 4]);
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  ctx.setLineDash([]);
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 9 * Math.cos(ang - 0.4), y2 - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(x2 - 9 * Math.cos(ang + 0.4), y2 - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

export function ConcurrentForcesCanvas({ magA, angleA, magB, angleB, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const simRef = useRef({ magA, angleA, magB, angleB, isRunning, isPaused });
  simRef.current = { magA, angleA, magB, angleB, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [magA, angleA, magB, angleB]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, BUILD_DURATION);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const progress = s.isRunning ? t.current / BUILD_DURATION : 1; // fully built when idle, so it's never blank

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Screen y is flipped (down = positive) vs standard maths convention,
    // so negate y components consistently when converting to pixels.
    const PX_PER_N = 6;
    const A: Vec2 = forceComponents(s.magA, s.angleA);
    const B: Vec2 = forceComponents(s.magB, s.angleB);
    const R = resultant([A, B]);
    const Eq = equilibrant([A, B]);

    // ── Left panel: forces drawn from a common point of application ────────
    const originL = { x: W * 0.27, y: H * 0.6 };
    ctx.fillStyle = '#0f172a';
    ctx.beginPath(); ctx.arc(originL.x, originL.y, 4, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Body', originL.x, originL.y + 22);

    const seg1 = Math.min(progress / 0.4, 1);
    drawArrow(ctx, originL.x, originL.y, originL.x + A.x * PX_PER_N * seg1, originL.y - A.y * PX_PER_N * seg1, '#6366f1');
    if (seg1 > 0.3) {
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`A=${s.magA}N`, originL.x + A.x * PX_PER_N * 0.55, originL.y - A.y * PX_PER_N * 0.55 - 10);
    }
    const seg2 = Math.min(Math.max((progress - 0.4) / 0.4, 0), 1);
    drawArrow(ctx, originL.x, originL.y, originL.x + B.x * PX_PER_N * seg2, originL.y - B.y * PX_PER_N * seg2, '#10b981');
    if (seg2 > 0.3) {
      ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`B=${s.magB}N`, originL.x + B.x * PX_PER_N * 0.55, originL.y - B.y * PX_PER_N * 0.55 - 10);
    }
    const seg3 = Math.min(Math.max((progress - 0.8) / 0.2, 0), 1);
    if (seg3 > 0) {
      drawArrow(ctx, originL.x, originL.y, originL.x + Eq.x * PX_PER_N * seg3, originL.y - Eq.y * PX_PER_N * seg3, '#ef4444');
    }
    if (progress >= 1) {
      ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Equilibrant=${vecMagnitude(Eq).toFixed(1)}N`, originL.x + Eq.x * PX_PER_N * 0.55, originL.y - Eq.y * PX_PER_N * 0.55 + 16);
    }

    // ── Right panel: the force TRIANGLE (tip-to-tail construction) ─────────
    const originR = { x: W * 0.68, y: H * 0.32 };
    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('Force triangle (tip-to-tail):', originR.x - 90, 22);

    const aTip = { x: originR.x + A.x * PX_PER_N, y: originR.y - A.y * PX_PER_N };
    const abTip = { x: aTip.x + B.x * PX_PER_N, y: aTip.y - B.y * PX_PER_N };

    const tSeg1 = Math.min(progress / 0.4, 1);
    drawArrow(ctx, originR.x, originR.y, originR.x + A.x * PX_PER_N * tSeg1, originR.y - A.y * PX_PER_N * tSeg1, '#6366f1');
    const tSeg2 = Math.min(Math.max((progress - 0.4) / 0.4, 0), 1);
    drawArrow(ctx, aTip.x, aTip.y, aTip.x + B.x * PX_PER_N * tSeg2, aTip.y - B.y * PX_PER_N * tSeg2, '#10b981');
    const tSeg3 = Math.min(Math.max((progress - 0.8) / 0.2, 0), 1);
    if (tSeg3 > 0) {
      drawArrow(ctx, abTip.x, abTip.y, abTip.x + (originR.x - abTip.x) * tSeg3, abTip.y + (originR.y - abTip.y) * tSeg3, '#ef4444');
    }
    if (progress >= 1) {
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Closes exactly back to the start —', originR.x, H - 34);
      ctx.fillText('this is what "in equilibrium" looks like', originR.x, H - 20);
    }

    // Caption
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      `Resultant of A+B = ${vecMagnitude(R).toFixed(1)}N at ${vecAngleDeg(R).toFixed(0)}°  →  Equilibrant = ${vecMagnitude(Eq).toFixed(1)}N at ${vecAngleDeg(Eq).toFixed(0)}°`,
      W / 2, H - 8,
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

echo "  → src/components/simulation/ParallelForcesCanvas.tsx"
cat > "src/components/simulation/ParallelForcesCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { netMoment, isBalanced, dampedStepResponse, Weight } from '@/lib/physics/equilibrium';

interface Props {
  weights: Weight[]; // position in metres from pivot, force in N
  isRunning: boolean; isPaused: boolean;
  onTick?: (angleDeg: number, netM: number) => void;
  width?: number; height?: number;
}

const MAX_TILT_DEG = 26; // the beam physically stops here (hits the ground/supports)
const BEAM_HALF_LEN_M = 2.2; // metres represented by the beam's visible half-length

export function ParallelForcesCanvas({ weights, isRunning, isPaused, onTick, width = 660, height = 280 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const simRef = useRef({ weights, isRunning, isPaused, onTick });
  simRef.current = { weights, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [weights]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const netM = netMoment(s.weights);
    const balanced = isBalanced(s.weights);
    // Beam settles toward its rotational limit (or stays level if balanced)
    // with the same damped 2nd-order response used for the floating body —
    // "mass"/"stiffness" here are just pacing constants tuned to settle in
    // under a second, not literal moment-of-inertia values.
    const targetDeg = balanced ? 0 : Math.sign(netM) * MAX_TILT_DEG;
    const angleDeg = s.isRunning
      ? dampedStepResponse(t.current, targetDeg, 40, 1, 0.55)
      : 0;
    s.onTick?.(angleDeg, netM);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const pivotX = W / 2, pivotY = H * 0.62;
    const pxPerM = Math.min((W / 2 - 40) / BEAM_HALF_LEN_M, 110);
    const angleRad = (angleDeg * Math.PI) / 180;

    // Fulcrum (triangle support)
    ctx.fillStyle = '#64748b';
    ctx.beginPath();
    ctx.moveTo(pivotX, pivotY);
    ctx.lineTo(pivotX - 22, pivotY + 40);
    ctx.lineTo(pivotX + 22, pivotY + 40);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.fillRect(pivotX - 60, pivotY + 40, 120, 8);

    // Beam, rotated about the pivot
    const beamHalfPx = BEAM_HALF_LEN_M * pxPerM;
    const x1 = pivotX - Math.cos(angleRad) * beamHalfPx, y1 = pivotY - Math.sin(angleRad) * beamHalfPx;
    const x2 = pivotX + Math.cos(angleRad) * beamHalfPx, y2 = pivotY + Math.sin(angleRad) * beamHalfPx;
    ctx.strokeStyle = '#92400e'; ctx.lineWidth = 10; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    ctx.strokeStyle = '#b45309'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();

    // Metre scale ticks
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    for (let m = -2; m <= 2; m++) {
      if (m === 0) continue;
      const bx = pivotX + Math.cos(angleRad) * m * pxPerM;
      const by = pivotY + Math.sin(angleRad) * m * pxPerM;
      ctx.fillText(`${m}m`, bx, by - 12);
    }

    // Weights hanging at their positions along the beam
    s.weights.forEach((w, i) => {
      const bx = pivotX + Math.cos(angleRad) * w.position * pxPerM;
      const by = pivotY + Math.sin(angleRad) * w.position * pxPerM;
      const hookLen = 22;
      ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx, by + hookLen); ctx.stroke();
      const r = 12 + Math.min(w.force, 40) * 0.25;
      const color = ['#6366f1', '#10b981', '#f59e0b'][i % 3];
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.arc(bx, by + hookLen + r, r, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${w.force}N`, bx, by + hookLen + r + 3);
      ctx.fillStyle = '#334155'; ctx.font = '9px system-ui';
      ctx.fillText(`${w.position >= 0 ? '+' : ''}${w.position}m`, bx, by + hookLen + 2 * r + 14);
    });

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (balanced) {
      ctx.fillStyle = '#059669';
      ctx.fillText('BALANCED — sum of clockwise moments = sum of anticlockwise moments', W / 2, 20);
    } else {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText(`UNBALANCED — net moment = ${netM.toFixed(2)} N·m (tips ${netM > 0 ? 'clockwise ↷' : 'anticlockwise ↶'})`, W / 2, 20);
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Σ(F × d): ${s.weights.map(w => `${w.force}×${w.position}`).join(' + ')} = ${netM.toFixed(2)} N·m`, 8, H - 10);

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

echo "  → src/components/simulation/FloatingBodyCanvas.tsx"
cat > "src/components/simulation/FloatingBodyCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { submergedFraction, sinkingAcceleration, upthrust, willFloat, dampedStepResponse, G } from '@/lib/physics/equilibrium';

interface Props {
  objDensity: number;   // kg/m³
  liquidDensity: number;
  liquidName: string;
  blockHeight: number;  // m (visual/physics height of the block)
  isRunning: boolean; isPaused: boolean;
  onTick?: (submergedFrac: number, settled: boolean) => void;
  width?: number; height?: number;
}

export const BLOCK_WIDTH_M = 0.3;
const PX_PER_M = 260;

export function FloatingBodyCanvas({
  objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick,
  width = 640, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sunkDepth = useRef(0); // for the sinking case: distance fallen below the surface
  const settled = useRef(false);
  const simRef = useRef({ objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick });
  simRef.current = { objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick };

  useEffect(() => {
    t.current = 0; sunkDepth.current = 0; settled.current = false; lastFrameRef.current = null;
  }, [objDensity, liquidDensity, blockHeight]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const floats = willFloat(s.objDensity, s.liquidDensity);
    const surfaceY = H * 0.4;
    const containerBottom = H - 20;
    const maxSinkPx = containerBottom - surfaceY - 20;

    let submergedPx: number; // how much of the block is below the surface line, in px
    if (floats) {
      const eqSubmergedM = s.blockHeight * submergedFraction(s.objDensity, s.liquidDensity);
      const eqSubmergedPx = eqSubmergedM * PX_PER_M;
      const mass = s.objDensity * BLOCK_WIDTH_M * s.blockHeight;
      const kEff = s.liquidDensity * G * BLOCK_WIDTH_M;
      submergedPx = s.isRunning ? dampedStepResponse(t.current, eqSubmergedPx, kEff, mass) : 0;
      if (dt > 0) t.current += dt;
      if (!settled.current && Math.abs(submergedPx - eqSubmergedPx) < eqSubmergedPx * 0.02) settled.current = true;
    } else {
      // A literal SI-accurate fall would either finish in a blink (dense
      // objects) or take unrealistically long (barely-denser ones) inside
      // a small stylised container. Instead, approach the container floor
      // exponentially, with a rate tied to the real sinking acceleration —
      // so denser objects still visibly sink faster than barely-denser
      // ones, bounded to a watchable ~1-3s range regardless of slider values.
      const rate = 0.5 + (Math.abs(sinkingAcceleration(s.objDensity, s.liquidDensity)) / G) * 2;
      if (dt > 0 && !settled.current) {
        t.current += dt;
        sunkDepth.current = maxSinkPx * (1 - Math.exp(-t.current * rate));
        if (sunkDepth.current >= maxSinkPx * 0.98) { sunkDepth.current = maxSinkPx; settled.current = true; }
      }
      submergedPx = Math.min(s.blockHeight * PX_PER_M, sunkDepth.current + s.blockHeight * PX_PER_M);
    }
    s.onTick?.(floats ? Math.min(submergedPx / (s.blockHeight * PX_PER_M), 1) : 1, settled.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Container
    const contL = W * 0.18, contR = W * 0.82;
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(contL, 20); ctx.lineTo(contL, containerBottom); ctx.lineTo(contR, containerBottom); ctx.lineTo(contR, 20); ctx.stroke();

    // Liquid
    ctx.fillStyle = 'rgba(96,165,250,0.35)';
    ctx.fillRect(contL, surfaceY, contR - contL, containerBottom - surfaceY);
    ctx.strokeStyle = 'rgba(59,130,246,0.6)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(contL, surfaceY); ctx.lineTo(contR, surfaceY); ctx.stroke();
    ctx.fillStyle = '#2563eb'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`${s.liquidName} (ρ=${s.liquidDensity} kg/m³)`, contL + 8, surfaceY - 8);

    // Block
    const blockWpx = BLOCK_WIDTH_M * PX_PER_M;
    const blockHpx = s.blockHeight * PX_PER_M;
    const bx = (contL + contR) / 2 - blockWpx / 2;
    const by = surfaceY + submergedPx - blockHpx;
    ctx.fillStyle = floats ? '#a78bfa' : '#94a3b8';
    ctx.fillRect(bx, by, blockWpx, blockHpx);
    ctx.strokeStyle = floats ? '#7c3aed' : '#475569'; ctx.lineWidth = 2;
    ctx.strokeRect(bx, by, blockWpx, blockHpx);
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`ρ=${s.objDensity}`, bx + blockWpx / 2, by + blockHpx / 2 + 4);

    // Upthrust / weight arrows once the run has started
    if (s.isRunning) {
      const V = BLOCK_WIDTH_M * s.blockHeight;
      const Vsub = BLOCK_WIDTH_M * (submergedPx / PX_PER_M);
      const U = upthrust(s.liquidDensity, Vsub);
      const Wt = s.objDensity * G * V;
      const cx0 = bx + blockWpx / 2;
      const scaleN = 30 / Math.max(Wt, U, 1);
      // Weight (down, red)
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx0 - 14, by + blockHpx); ctx.lineTo(cx0 - 14, by + blockHpx + Wt * scaleN); ctx.stroke();
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`W=${Wt.toFixed(0)}N`, cx0 - 14, by + blockHpx + Wt * scaleN + 12);
      // Upthrust (up, blue)
      ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx0 + 14, by + blockHpx); ctx.lineTo(cx0 + 14, by + blockHpx - U * scaleN); ctx.stroke();
      ctx.fillStyle = '#2563eb';
      ctx.fillText(`U=${U.toFixed(0)}N`, cx0 + 14, by + blockHpx - U * scaleN - 6);
    }

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (floats) {
      ctx.fillStyle = '#059669';
      ctx.fillText(`FLOATS — ${(submergedFraction(s.objDensity, s.liquidDensity) * 100).toFixed(0)}% submerged at equilibrium (Archimedes: weight = upthrust)`, W / 2, 20);
    } else {
      ctx.fillStyle = '#dc2626';
      ctx.fillText(`SINKS — object denser than the liquid, upthrust can never equal its weight`, W / 2, 20);
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

echo "  → src/app/simulations/equilibrium-of-forces/page.tsx"
cat > "src/app/simulations/equilibrium-of-forces/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { StaticDynamicCanvas } from '@/components/simulation/StaticDynamicCanvas';
import { ConcurrentForcesCanvas } from '@/components/simulation/ConcurrentForcesCanvas';
import { ParallelForcesCanvas } from '@/components/simulation/ParallelForcesCanvas';
import { FloatingBodyCanvas, BLOCK_WIDTH_M } from '@/components/simulation/FloatingBodyCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  checkBalance, forceComponents, resultant, equilibrant, vecMagnitude, vecAngleDeg,
  netMoment, isBalanced, relativeDensity, submergedFraction, willFloat, upthrust,
  LIQUIDS, Weight,
} from '@/lib/physics/equilibrium';

type Topic = 'static-dynamic' | 'concurrent' | 'parallel' | 'floating';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  'static-dynamic': { title: 'Static & dynamic', icon: '⚖️', sub: 'Equilibrium at rest vs at constant velocity', eq: 'ΣF = 0' },
  concurrent:       { title: 'Concurrent forces', icon: '📐', sub: 'Non-parallel coplanar forces on a point', eq: 'ΣFx = 0, ΣFy = 0' },
  parallel:         { title: 'Parallel forces',   icon: '⚡', sub: 'Moments — the principle of moments', eq: 'Σ(clockwise M) = Σ(anticlockwise M)' },
  floating:         { title: 'Floating bodies',   icon: '🛟', sub: 'Density, relative density, upthrust', eq: 'Upthrust = weight of fluid displaced' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  'static-dynamic': [
    'Equilibrium means the resultant (net) force is zero — it does NOT mean the object is at rest. A common exam trap.',
    'STATIC equilibrium: net force = 0 AND the object is at rest (stays at rest).',
    'DYNAMIC equilibrium: net force = 0 but the object is already moving — it continues at constant velocity (Newton\u2019s 1st law).',
    'If the forces are unbalanced, the object accelerates — it does not matter whether it started at rest or already moving.',
    'Real examples of dynamic equilibrium: a car at cruising speed (driving force = resistive forces), a skydiver at terminal velocity (weight = air resistance).',
  ],
  concurrent: [
    'Concurrent forces act through the SAME point. For equilibrium, they must form a CLOSED polygon when drawn tip-to-tail — if there\u2019s a gap, that gap IS the resultant.',
    'Equivalently: resolve every force into x and y components — for equilibrium, ΣFx = 0 AND ΣFy = 0 separately.',
    'The equilibrant is the single extra force that would balance the others — equal in magnitude, exactly opposite in direction to the resultant.',
    'For just TWO forces in equilibrium: they must be equal in magnitude and exactly opposite in direction (180° apart) — the simplest case of the polygon rule.',
    'For THREE concurrent forces in equilibrium, a very common WAEC technique is Lami\u2019s theorem: each force is proportional to the sine of the angle between the other two.',
  ],
  parallel: [
    'The principle of moments: for equilibrium, the sum of clockwise moments about any point equals the sum of anticlockwise moments about that same point.',
    'Moment (torque) = force × perpendicular distance from the pivot. Bigger force OR bigger distance both increase the turning effect — this is why a spanner with a longer handle needs less force.',
    'A see-saw balances when W1×d1 = W2×d2 — a heavier person must sit closer to the pivot to balance a lighter person farther away.',
    'For a beam to be in COMPLETE equilibrium, moments must balance AND the total upward force (from the pivot/supports) must equal the total downward force (the weights) — two separate conditions.',
    'Choosing WHICH point to take moments about is a free choice in the maths — but choosing the pivot (or an unknown force\u2019s point of application) often eliminates an unknown and simplifies the equation.',
  ],
  floating: [
    'Archimedes\u2019 principle: the upthrust on a body in a fluid equals the weight of the fluid it displaces.',
    'A floating object displaces EXACTLY its own weight of fluid — that\u2019s why upthrust = weight for a floating body, giving zero net force (equilibrium).',
    'Relative density = density of a substance ÷ density of water. It has no units, and is numerically identical to density measured in g/cm³.',
    'An object floats if its density is LESS than the liquid\u2019s density, and sinks if its density is GREATER — equal densities give neutral buoyancy (stays wherever placed, fully submerged).',
    'Ships made of steel float because their overall SHAPE (hollow hull) gives them a low average density, even though steel itself is far denser than water — density of the whole object matters, not the material alone.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  'static-dynamic': [
    { q: 'A car travels at a constant 60 km/h on a straight, flat road. What can you say about the resultant force on it?', a: 'It is zero — constant velocity means the car is in dynamic equilibrium, so the driving force exactly equals the total resistive forces (friction + air resistance).' },
    { q: 'A book rests on a table. Name the two forces in equilibrium and state their relationship.', a: 'Weight (down) and the normal reaction from the table (up). They are equal in magnitude and opposite in direction, giving a zero resultant — static equilibrium.' },
    { q: 'Explain why "equilibrium" and "at rest" are not the same thing, using an example.', a: 'Equilibrium only requires zero resultant force. A parachutist falling at terminal velocity is in equilibrium (weight = air resistance) but is clearly not at rest — this is dynamic equilibrium.' },
  ],
  concurrent: [
    { q: 'Two forces of 6N and 8N act at right angles to each other at a point. Find their resultant.', a: 'R = √(6²+8²) = √(36+64) = √100 = 10N (a 3-4-5 triangle scaled up).' },
    { q: 'A force of 10N acts at 0° and a second force of 10N acts at 180°. Are they in equilibrium? Explain.', a: 'Yes — equal magnitude, exactly opposite direction, so their resultant is zero. This is the equilibrium condition for two concurrent forces.' },
    { q: 'Three forces of equal magnitude act on a point, all in equilibrium. What must be true about the angles between them?', a: 'They must be arranged symmetrically at 120° to each other (like the letter Y) — this is the only way three equal forces can form a closed triangle.' },
  ],
  parallel: [
    { q: 'A 40N weight sits 0.6m from a pivot on one side of a beam. Find the weight needed 0.8m from the pivot on the other side to balance it.', a: 'Principle of moments: 40×0.6 = W×0.8. W = 24/0.8 = 30N.' },
    { q: 'A spanner has a handle 0.25m long. What force is needed to produce a moment of 15N·m on a bolt?', a: 'M = F×d, so F = M/d = 15/0.25 = 60N.' },
    { q: 'Two children sit on a see-saw: a 300N child 1.5m from the pivot, and a 450N child on the other side. How far from the pivot must the second child sit to balance?', a: '300×1.5 = 450×d. d = 450/450 = 1m.' },
  ],
  floating: [
    { q: 'A block of density 800 kg/m³ floats in water (1000 kg/m³). What fraction of its volume is submerged?', a: 'Fraction submerged = ρ_object/ρ_liquid = 800/1000 = 0.8 = 80%.' },
    { q: 'An object has a relative density of 2.7. What is its actual density?', a: 'Relative density = density/density of water, so density = 2.7×1000 = 2700 kg/m³ (this is aluminium).' },
    { q: 'A 500 cm³ block of wood (density 600 kg/m³) floats in water. Find the upthrust acting on it.', a: 'At equilibrium, upthrust = weight = mg = (0.6 kg/m³ × 0.0005 m³ shortcut: mass=600×0.0005=0.3kg) × 9.81 ≈ 2.94N.' },
    { q: 'Explain, using density, why a steel ship floats but a solid steel block sinks.', a: 'The ship\u2019s hollow hull encloses a large volume of air, giving the ship as a whole a much lower AVERAGE density than solid steel — low enough to be less than water\u2019s density, so it floats. A solid steel block has no such air space, so its density (about 7800 kg/m³) stays far above water\u2019s and it sinks.' },
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

export default function EquilibriumOfForcesPage() {
  const [topic, setTopic] = useState<Topic>('static-dynamic');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  // Static / dynamic
  const [scenario, setScenario] = useState<'static' | 'dynamic'>('static');
  const [sdF1, setSdF1] = useState(15);
  const [sdF2, setSdF2] = useState(15);
  const [sdMass, setSdMass] = useState(5);
  const [liveSd, setLiveSd] = useState({ v: 0 });

  // Concurrent
  const [magA, setMagA] = useState(10);
  const [angleA, setAngleA] = useState(0);
  const [magB, setMagB] = useState(10);
  const [angleB, setAngleB] = useState(90);

  // Parallel / moments
  const [w1Force, setW1Force] = useState(20);
  const [w1Pos, setW1Pos] = useState(-0.6);
  const [w2Force, setW2Force] = useState(20);
  const [w2Pos, setW2Pos] = useState(0.6);
  const weights: Weight[] = [{ force: w1Force, position: w1Pos }, { force: w2Force, position: w2Pos }];
  const [liveTilt, setLiveTilt] = useState(0);

  // Floating
  const [objDensity, setObjDensity] = useState(600);
  const [liqIdx, setLiqIdx] = useState(0);
  const [blockHeight, setBlockHeight] = useState(0.2);
  const liquid = LIQUIDS[liqIdx];
  const [liveSubmerged, setLiveSubmerged] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
    setLiveSd({ v: 0 }); setLiveTilt(0); setLiveSubmerged(0);
  }, []);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, scenario, sdF1, sdF2, sdMass, magA, angleA, magB, angleB, w1Force, w1Pos, w2Force, w2Pos, objDensity, liqIdx, blockHeight, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, topic === 'floating' ? 300 : topic === 'concurrent' ? 300 : 260, 900);

  const lastTickRef = useRef(0);
  const handleSdTick = useCallback((v: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveSd({ v });
  }, []);
  const handleTiltTick = useCallback((angleDeg: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveTilt(angleDeg);
  }, []);
  const handleFloatTick = useCallback((frac: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveSubmerged(frac);
  }, []);

  const sdBal = checkBalance(sdF1, sdF2);
  const A = forceComponents(magA, angleA);
  const B = forceComponents(magB, angleB);
  const R = resultant([A, B]);
  const Eq = equilibrant([A, B]);
  const netM = netMoment(weights);
  const balanced = isBalanced(weights);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Equilibrium of forces</h1>
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
                {topic === 'static-dynamic' && (
                  <StaticDynamicCanvas key={resetKey} scenario={scenario} f1={sdF1} f2={sdF2} mass={sdMass}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleSdTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'concurrent' && (
                  <ConcurrentForcesCanvas key={resetKey} magA={magA} angleA={angleA} magB={magB} angleB={angleB}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'parallel' && (
                  <ParallelForcesCanvas key={resetKey} weights={weights}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleTiltTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'floating' && (
                  <FloatingBodyCanvas key={resetKey} objDensity={objDensity} liquidDensity={liquid.density}
                    liquidName={liquid.name} blockHeight={blockHeight}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleFloatTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/equilibrium"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'static-dynamic' ? { topic, scenario, f1: sdF1, f2: sdF2, mass: sdMass }
                    : topic === 'concurrent' ? { topic, magA, angleA, magB, angleB }
                    : topic === 'parallel' ? { topic, w1f: w1Force, w1p: w1Pos, w2f: w2Force, w2p: w2Pos }
                    : { topic, density: objDensity, liquid: liqIdx, h: blockHeight }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'static-dynamic' && <>
                  <div className="flex gap-2">
                    {(['static', 'dynamic'] as const).map(sc => (
                      <button key={sc} onClick={() => setScenario(sc)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          scenario === sc ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{sc}</button>
                    ))}
                  </div>
                  <Slider label="Force F₁ (right-pulling)" unit="N" value={sdF1} min={0} max={30} step={0.5} set={setSdF1} color="#10b981" />
                  <Slider label="Force F₂ (left-pulling)" unit="N" value={sdF2} min={0} max={30} step={0.5} set={setSdF2} color="#ef4444" />
                  <Slider label="Mass" unit="kg" value={sdMass} min={1} max={20} step={0.5} set={setSdMass} color="#6366f1" />
                </>}

                {topic === 'concurrent' && <>
                  <Slider label="Force A" unit="N" value={magA} min={1} max={20} step={0.5} set={setMagA} color="#6366f1" />
                  <Slider label="Angle A" unit="°" value={angleA} min={0} max={359} step={1} set={setAngleA} color="#818cf8" />
                  <Slider label="Force B" unit="N" value={magB} min={1} max={20} step={0.5} set={setMagB} color="#10b981" />
                  <Slider label="Angle B" unit="°" value={angleB} min={0} max={359} step={1} set={setAngleB} color="#34d399" note="0° = along +x axis, measured anticlockwise" />
                </>}

                {topic === 'parallel' && <>
                  <Slider label="Weight 1" unit="N" value={w1Force} min={0} max={50} step={1} set={setW1Force} color="#6366f1" />
                  <Slider label="Position 1" unit="m" value={w1Pos} min={-2} max={2} step={0.1} set={setW1Pos} color="#818cf8" note="Negative = left of pivot" />
                  <Slider label="Weight 2" unit="N" value={w2Force} min={0} max={50} step={1} set={setW2Force} color="#10b981" />
                  <Slider label="Position 2" unit="m" value={w2Pos} min={-2} max={2} step={0.1} set={setW2Pos} color="#34d399" note="Positive = right of pivot" />
                </>}

                {topic === 'floating' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {LIQUIDS.map((l, i) => (
                      <button key={l.name} onClick={() => setLiqIdx(i)}
                        className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                          liqIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{l.name} ({l.density})</button>
                    ))}
                  </div>
                  <Slider label="Object density" unit="kg/m³" value={objDensity} min={100} max={12000} step={50} set={setObjDensity} color="#a78bfa" />
                  <Slider label="Block height" unit="m" value={blockHeight} min={0.05} max={0.4} step={0.01} set={setBlockHeight} color="#f59e0b" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'static-dynamic' && <>
                    <StatRow label="Net force" value={sdBal.netForce.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="State" value={sdBal.equilibrium ? 'equilibrium' : 'unbalanced'} unit="" color={sdBal.equilibrium ? 'text-emerald-600' : 'text-amber-600'} />
                    <StatRow label="Acceleration" value={(sdBal.netForce / sdMass).toFixed(2)} unit="m/s²" color="text-rose-500" />
                    <StatRow label="Live speed" value={liveSd.v.toFixed(2)} unit="m/s" color="text-purple-600" />
                  </>}
                  {topic === 'concurrent' && <>
                    <StatRow label="Resultant |R|" value={vecMagnitude(R).toFixed(2)} unit="N" color="text-indigo-600" />
                    <StatRow label="Resultant angle" value={vecAngleDeg(R).toFixed(1)} unit="°" color="text-emerald-600" />
                    <StatRow label="Equilibrant |E|" value={vecMagnitude(Eq).toFixed(2)} unit="N" color="text-rose-500" />
                    <StatRow label="Equilibrant angle" value={vecAngleDeg(Eq).toFixed(1)} unit="°" color="text-purple-600" />
                  </>}
                  {topic === 'parallel' && <>
                    <StatRow label="Net moment" value={netM.toFixed(2)} unit="N·m" color="text-indigo-600" />
                    <StatRow label="State" value={balanced ? 'balanced' : 'unbalanced'} unit="" color={balanced ? 'text-emerald-600' : 'text-amber-600'} />
                    <StatRow label="Live tilt" value={liveTilt.toFixed(1)} unit="°" color="text-purple-600" />
                  </>}
                  {topic === 'floating' && <>
                    <StatRow label="Relative density" value={relativeDensity(objDensity).toFixed(2)} unit="" color="text-indigo-600" />
                    <StatRow label="Will it float?" value={willFloat(objDensity, liquid.density) ? 'yes' : 'no — sinks'} unit="" color={willFloat(objDensity, liquid.density) ? 'text-emerald-600' : 'text-red-500'} />
                    <StatRow label="Submerged fraction" value={(submergedFraction(objDensity, liquid.density) * 100).toFixed(0)} unit="%" color="text-purple-600" />
                    <StatRow label="Live submerged" value={(liveSubmerged * 100).toFixed(0)} unit="%" color="text-amber-600" />
                    <StatRow label="Upthrust (floating)" value={upthrust(liquid.density, BLOCK_WIDTH_M * blockHeight * submergedFraction(objDensity, liquid.density)).toFixed(1)} unit="N" color="text-rose-500" />
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

echo "  → src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'photoelectric-effect',
    href: '/simulations/photoelectric-effect',
    title: 'Photoelectric effect',
    description: "Fire light at a metal plate and test Einstein's equation hf = φ + KEmax.",
    icon: '💡',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'de-broglie',
    href: '/simulations/de-broglie',
    title: 'De Broglie hypothesis',
    description: 'See matter waves in action: λ = h/mv for particles from electrons to cricket balls.',
    icon: '〰️',
    tags: ['IGCSE', 'JUPEB', 'SAT'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'x-rays',
    href: '/simulations/x-rays',
    title: 'X-rays',
    description: 'Explore X-ray tube production, the continuous spectrum, and the Duane–Hunt limit.',
    icon: '🩻',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'friction',
    href: '/simulations/friction',
    title: 'Friction',
    description: 'Static vs kinetic friction on flat and inclined surfaces, with the angle of repose.',
    icon: '🧱',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'heat-transfer',
    href: '/simulations/heat-transfer',
    title: 'Modes of heat transfer',
    description: 'Conduction, convection, and radiation compared side by side with live particle animation.',
    icon: '🔥',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'elasticity',
    href: '/simulations/elasticity',
    title: 'Elasticity',
    description: "Hooke's law with a loaded spring, and Young's modulus for a stretched wire.",
    icon: '🪢',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'equilibrium-of-forces',
    href: '/simulations/equilibrium-of-forces',
    title: 'Equilibrium of forces',
    description: 'Static & dynamic equilibrium, coplanar forces, moments, and floating bodies.',
    icon: '⚖️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

export default function SimulationsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visibleSims = selectedTopic === 'All'
    ? SIMULATIONS
    : SIMULATIONS.filter(sim => sim.topic === selectedTopic);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => {
              const count = t === 'All' ? SIMULATIONS.length : SIMULATIONS.filter(sim => sim.topic === t).length;
              const active = selectedTopic === t;
              return (
                <button key={t} onClick={() => setSelectedTopic(t)}
                  className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${
                    active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                  }`}>
                  {t}
                  <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Cards grid */}
          {visibleSims.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-gray-200 py-16 text-center">
              <p className="text-sm text-gray-400">No simulations in {selectedTopic} yet.</p>
            </div>
          ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visibleSims.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>
          )}

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/embed/equilibrium/page.tsx"
cat > "src/app/embed/equilibrium/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { StaticDynamicCanvas } from '@/components/simulation/StaticDynamicCanvas';
import { ConcurrentForcesCanvas } from '@/components/simulation/ConcurrentForcesCanvas';
import { ParallelForcesCanvas } from '@/components/simulation/ParallelForcesCanvas';
import { FloatingBodyCanvas } from '@/components/simulation/FloatingBodyCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { LIQUIDS, Weight } from '@/lib/physics/equilibrium';

type Topic = 'static-dynamic' | 'concurrent' | 'parallel' | 'floating';

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

function EquilibriumEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'concurrent' || t === 'parallel' || t === 'floating' ? t : 'static-dynamic';
  })();
  const showControls = sp.get('controls') !== '0';

  const [scenario, setScenario] = useState<'static' | 'dynamic'>(() => (sp.get('scenario') === 'dynamic' ? 'dynamic' : 'static'));
  const [sdF1, setSdF1] = useState(() => num(sp, 'f1', 15, 0, 30));
  const [sdF2, setSdF2] = useState(() => num(sp, 'f2', 15, 0, 30));
  const [sdMass, setSdMass] = useState(() => num(sp, 'mass', 5, 1, 20));

  const [magA, setMagA] = useState(() => num(sp, 'magA', 10, 1, 20));
  const [angleA, setAngleA] = useState(() => num(sp, 'angleA', 0, 0, 359));
  const [magB, setMagB] = useState(() => num(sp, 'magB', 10, 1, 20));
  const [angleB, setAngleB] = useState(() => num(sp, 'angleB', 90, 0, 359));

  const [w1Force, setW1Force] = useState(() => num(sp, 'w1f', 20, 0, 50));
  const [w1Pos, setW1Pos] = useState(() => num(sp, 'w1p', -0.6, -2, 2));
  const [w2Force, setW2Force] = useState(() => num(sp, 'w2f', 20, 0, 50));
  const [w2Pos, setW2Pos] = useState(() => num(sp, 'w2p', 0.6, -2, 2));
  const weights: Weight[] = [{ force: w1Force, position: w1Pos }, { force: w2Force, position: w2Pos }];

  const [objDensity, setObjDensity] = useState(() => num(sp, 'density', 600, 100, 12000));
  const [liqIdx, setLiqIdx] = useState(() => Math.round(num(sp, 'liquid', 0, 0, LIQUIDS.length - 1)));
  const [blockHeight, setBlockHeight] = useState(() => num(sp, 'h', 0.2, 0.05, 0.4));
  const liquid = LIQUIDS[liqIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, scenario, sdF1, sdF2, sdMass, magA, angleA, magB, angleB, w1Force, w1Pos, w2Force, w2Pos, objDensity, liqIdx, blockHeight, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'static-dynamic' && (
        <StaticDynamicCanvas key={resetKey} scenario={scenario} f1={sdF1} f2={sdF2} mass={sdMass}
          isRunning={isRunning} isPaused={isPaused} width={640} height={240} />
      )}
      {topic === 'concurrent' && (
        <ConcurrentForcesCanvas key={resetKey} magA={magA} angleA={angleA} magB={magB} angleB={angleB}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'parallel' && (
        <ParallelForcesCanvas key={resetKey} weights={weights}
          isRunning={isRunning} isPaused={isPaused} width={640} height={260} />
      )}
      {topic === 'floating' && (
        <FloatingBodyCanvas key={resetKey} objDensity={objDensity} liquidDensity={liquid.density}
          liquidName={liquid.name} blockHeight={blockHeight}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'static-dynamic' && <>
            <div className="flex gap-2">
              {(['static', 'dynamic'] as const).map(sc => (
                <button key={sc} onClick={() => setScenario(sc)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    scenario === sc ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{sc}</button>
              ))}
            </div>
            <Slider label="Force F1" unit="N" value={sdF1} min={0} max={30} step={0.5} set={setSdF1} color="#10b981" />
            <Slider label="Force F2" unit="N" value={sdF2} min={0} max={30} step={0.5} set={setSdF2} color="#ef4444" />
            <Slider label="Mass" unit="kg" value={sdMass} min={1} max={20} step={0.5} set={setSdMass} color="#6366f1" />
          </>}
          {topic === 'concurrent' && <>
            <Slider label="Force A" unit="N" value={magA} min={1} max={20} step={0.5} set={setMagA} color="#6366f1" />
            <Slider label="Angle A" unit="°" value={angleA} min={0} max={359} step={1} set={setAngleA} color="#818cf8" />
            <Slider label="Force B" unit="N" value={magB} min={1} max={20} step={0.5} set={setMagB} color="#10b981" />
            <Slider label="Angle B" unit="°" value={angleB} min={0} max={359} step={1} set={setAngleB} color="#34d399" />
          </>}
          {topic === 'parallel' && <>
            <Slider label="Weight 1" unit="N" value={w1Force} min={0} max={50} step={1} set={setW1Force} color="#6366f1" />
            <Slider label="Position 1" unit="m" value={w1Pos} min={-2} max={2} step={0.1} set={setW1Pos} color="#818cf8" />
            <Slider label="Weight 2" unit="N" value={w2Force} min={0} max={50} step={1} set={setW2Force} color="#10b981" />
            <Slider label="Position 2" unit="m" value={w2Pos} min={-2} max={2} step={0.1} set={setW2Pos} color="#34d399" />
          </>}
          {topic === 'floating' && <>
            <div className="flex flex-wrap gap-1.5">
              {LIQUIDS.map((l, i) => (
                <button key={l.name} onClick={() => setLiqIdx(i)}
                  className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                    liqIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{l.name}</button>
              ))}
            </div>
            <Slider label="Object density" unit="kg/m³" value={objDensity} min={100} max={12000} step={50} set={setObjDensity} color="#a78bfa" />
            <Slider label="Block height" unit="m" value={blockHeight} min={0.05} max={0.4} step={0.01} set={setBlockHeight} color="#f59e0b" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function EquilibriumEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <EquilibriumEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v18 applied — 8 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/equilibrium-of-forces — all four tabs:"
echo "  - Static & dynamic: toggle static/dynamic, unbalance the forces"
echo "  - Concurrent: watch the force triangle build and close"
echo "  - Parallel: unbalance the see-saw and watch it tip"
echo "  - Floating: try a few densities/liquids, some should float, some sink"
