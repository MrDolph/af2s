#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v10: incline can now be pushed UP, plus a full
# toggleable weight-force diagram
#
#   1. INCLINE IS NOW BIDIRECTIONAL. Previously the incline could only slide
#      DOWN under gravity (or sit static) — there was no way to push a block
#      UP the slope. Added a new "Applied push (up-slope)" slider (0-100N).
#      The physics lib gained inclineDynamics(), a signed (+up/-down) model
#      that automatically flips friction to whichever side opposes the
#      actual or impending motion — so it correctly handles: sliding down
#      under gravity, sitting static in equilibrium, being pushed up against
#      gravity+friction, and decelerating back down after a push is released
#      mid-flight. inclineFriction() is gone; both call sites (canvas +
#      page) now use inclineDynamics() directly.
#
#   2. FULL WEIGHT VECTOR + COMPONENTS, ALL TOGGLEABLE. The incline canvas
#      previously only ever drew the along-slope component (mg sinθ) — the
#      actual vertical weight vector (mg, straight down) was never shown.
#      Added:
#        - The full weight vector mg, drawn as a true vertical line (not
#          rotated with the slope) — the real "line of force" of gravity.
#        - Its two components resolved against the incline: mg sinθ
#          (parallel to the surface) and mg cosθ (perpendicular into it).
#      Added a "Show forces" panel with independent toggle chips for
#      Weight, Components, Normal, Friction, and Applied force — for BOTH
#      the flat and incline tabs. Toggling visibility is purely cosmetic
#      and does not reset the running simulation (verified the toggle state
#      is deliberately excluded from the physics-reset effect).
#
#   3. The block on the incline now starts mid-slope (not near the top) so
#      there is visible room to travel in either direction, and gently stops
#      if it reaches the top or bottom of the drawn ramp instead of running
#      off-canvas.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v10-incline-bidirectional-forces.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v10: incline push-up + toggleable weight force diagram ──"
mkdir -p "src/app/embed/friction" "src/app/simulations/friction" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/friction.ts"
cat > "src/lib/physics/friction.ts" << 'AFEOF'
// ── Friction ──────────────────────────────────────────────────────────────────
// Static:  F_s ≤ μs·N  (matches the applied force until the limit)
// Kinetic: F_k = μk·N  (constant once sliding; μk < μs)
// On an incline the block slips when tanθ > μs  →  angle of repose θr = tan⁻¹μs.

export const G = 9.81;

export interface FlatResult {
  N: number;
  staticMax: number;
  friction: number;     // actual friction force right now
  netForce: number;
  acceleration: number;
  moving: boolean;
}

export function flatFriction(mass: number, applied: number, muS: number, muK: number): FlatResult {
  const N = mass * G;
  const staticMax = muS * N;
  if (applied <= staticMax) {
    // Static regime: friction exactly balances the applied force.
    return { N, staticMax, friction: applied, netForce: 0, acceleration: 0, moving: false };
  }
  const kinetic = muK * N;
  const net = applied - kinetic;
  return { N, staticMax, friction: kinetic, netForce: net, acceleration: net / mass, moving: true };
}

// ── Incline (bidirectional) ─────────────────────────────────────────────────────
// Positive direction = UP the slope throughout. An optional applied force
// (also up-slope-positive) lets the block be pushed UP against gravity, not
// just slide down under its own weight — friction automatically flips to
// whichever side opposes the actual (or impending) motion.
export interface InclineDynamicsResult {
  N: number;
  gravityAlong: number;   // mg sinθ — magnitude of weight's down-slope component
  gravityPerp: number;    // mg cosθ — magnitude of weight's into-slope component (== N at equilibrium)
  weight: number;         // mg — full weight magnitude
  appliedForce: number;   // signed, up-slope positive (as given)
  friction: number;       // signed, up-slope positive
  netForce: number;       // signed, up-slope positive
  acceleration: number;   // signed, up-slope positive
  moving: boolean;
  direction: 'up' | 'down' | 'static';
  staticMax: number;
  reposeAngle: number;    // tan⁻¹(μs) in degrees — the F=0 slipping threshold
}

export function inclineDynamics(
  mass: number, thetaDeg: number, muS: number, muK: number, appliedForce: number, v: number
): InclineDynamicsResult {
  const th = (thetaDeg * Math.PI) / 180;
  const weight = mass * G;
  const N = weight * Math.cos(th);
  const gravityAlong = weight * Math.sin(th);   // always pulls down-slope
  const gravityPerp = N;
  const maxStatic = muS * N;
  const reposeAngle = (Math.atan(muS) * 180) / Math.PI;
  const nonFriction = appliedForce - gravityAlong; // net of applied (up +) and gravity (down −), excluding friction

  if (v === 0) {
    if (Math.abs(nonFriction) <= maxStatic) {
      return {
        N, gravityAlong, gravityPerp, weight, appliedForce, friction: -nonFriction, netForce: 0,
        acceleration: 0, moving: false, direction: 'static', staticMax: maxStatic, reposeAngle,
      };
    }
    const friction = -Math.sign(nonFriction) * maxStatic;
    const netForce = nonFriction + friction;
    const acceleration = netForce / mass;
    return {
      N, gravityAlong, gravityPerp, weight, appliedForce, friction, netForce, acceleration,
      moving: true, direction: acceleration > 0 ? 'up' : 'down', staticMax: maxStatic, reposeAngle,
    };
  }
  const friction = -Math.sign(v) * muK * N;
  const netForce = nonFriction + friction;
  const acceleration = netForce / mass;
  return {
    N, gravityAlong, gravityPerp, weight, appliedForce, friction, netForce, acceleration,
    moving: true, direction: v > 0 ? 'up' : 'down', staticMax: maxStatic, reposeAngle,
  };
}

// Friction-vs-applied-force curve: the classic ramp-then-plateau graph
// (flat-surface version, used by the flat-mode f–F graph).
export function frictionCurve(mass: number, muS: number, muK: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { F: +F.toFixed(2), f: +flatFriction(mass, F, muS, muK).friction.toFixed(2) };
  });
}
AFEOF

echo "  → src/components/simulation/FrictionCanvas.tsx"
cat > "src/components/simulation/FrictionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { flatFriction, inclineDynamics } from '@/lib/physics/friction';

export type FrictionMode = 'flat' | 'incline';

interface Props {
  mode: FrictionMode;
  mass: number;
  applied: number;          // N (flat mode push)
  angle: number;            // degrees (incline mode)
  appliedIncline: number;   // N — up-slope push (incline mode; 0 = gravity only)
  muS: number; muK: number;
  isRunning: boolean; isPaused: boolean;
  resetKey: number;
  // Per-arrow visibility — purely cosmetic, so these must NEVER appear in
  // the physics-reset effect's dependency list below (toggling one must not
  // restart the simulation).
  showWeight: boolean;
  showComponents: boolean; // incline only: mg sinθ (∥) and mg cosθ (⊥)
  showNormal: boolean;
  showFriction: boolean;
  showApplied: boolean;
  width?: number; height?: number;
}

function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, dx: number, dy: number, color: string, label: string, labelDy = -8) {
  const len = Math.hypot(dx, dy);
  if (len < 1) return;
  const ang = Math.atan2(dy, dx);
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + dx, y + dy); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x + dx, y + dy);
  ctx.lineTo(x + dx - 9 * Math.cos(ang - 0.4), y + dy - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(x + dx - 9 * Math.cos(ang + 0.4), y + dy - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dx, y + dy + labelDy);
  ctx.restore();
}

export function FrictionCanvas({
  mode, mass, applied, angle, appliedIncline, muS, muK, isRunning, isPaused, resetKey,
  showWeight, showComponents, showNormal, showFriction, showApplied,
  width = 640, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const posRef = useRef(0);   // metres travelled (incline: signed, +up / flat: forward only)
  const velRef = useRef(0);   // m/s (incline: signed, +up)
  const tRef = useRef(0);
  const sim = useRef({
    mode, mass, applied, angle, appliedIncline, muS, muK, isRunning, isPaused,
    showWeight, showComponents, showNormal, showFriction, showApplied,
  });
  sim.current = {
    mode, mass, applied, angle, appliedIncline, muS, muK, isRunning, isPaused,
    showWeight, showComponents, showNormal, showFriction, showApplied,
  };

  // Only genuine physics parameters reset the run — visibility toggles are
  // deliberately excluded so switching an arrow on/off never interrupts the
  // simulation in progress.
  useEffect(() => {
    posRef.current = 0; velRef.current = 0; tRef.current = 0;
    lastFrameRef.current = null;
  }, [mode, mass, applied, angle, appliedIncline, muS, muK, resetKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const SCALE = 1.4; // px per N for arrows

    if (s.mode === 'flat') {
      const r = flatFriction(s.mass, s.applied, s.muS, s.muK);
      // Wall-clock physics integration once sliding
      if (dt > 0 && r.moving) {
        velRef.current += r.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const groundY = H - 70;
      const bw = 70, bh = 48;
      const px = 60 + ((posRef.current * 40) % (W - 180)); // wraps to stay on screen
      // Ground with texture ∝ μ
      ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, 70);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      const rough = 6 + s.muS * 20;
      for (let x = 4; x < W; x += rough) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 4, groundY + 5); ctx.stroke();
      }
      // Block
      ctx.fillStyle = r.moving ? '#f59e0b' : '#6366f1';
      ctx.fillRect(px, groundY - bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass} kg`, px + bw / 2, groundY - bh / 2 + 4);
      const cx = px + bw / 2, cy = groundY - bh / 2;
      // Forces
      if (s.showApplied) {
        forceArrow(ctx, px + bw, cy, Math.min(s.applied * SCALE, 150), 0, '#059669', `F = ${s.applied.toFixed(0)}N`, -10);
      }
      if (s.showFriction) {
        forceArrow(ctx, px, cy, -Math.min(r.friction * SCALE, 150), 0, '#ef4444', `f = ${r.friction.toFixed(1)}N`, -10);
      }
      if (s.showNormal) {
        forceArrow(ctx, cx, groundY - bh, 0, -Math.min(r.N * SCALE * 0.5, 70), '#3b82f6', `N`, -6);
      }
      if (s.showWeight) {
        forceArrow(ctx, cx, groundY, 0, Math.min(r.N * SCALE * 0.5, 60), '#8b5cf6', `mg = ${r.N.toFixed(1)}N`, 14);
      }
      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (!r.moving) {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — friction matches F exactly (limit: μsN = ${r.staticMax.toFixed(1)}N)`, W / 2, 28);
      } else {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING — kinetic friction μkN = ${r.friction.toFixed(1)}N,  a = ${r.acceleration.toFixed(2)} m/s²`, W / 2, 28);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   distance = ${posRef.current.toFixed(1)} m   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
    }

    if (s.mode === 'incline') {
      const d = inclineDynamics(s.mass, s.angle, s.muS, s.muK, s.appliedIncline, velRef.current);
      if (dt > 0 && d.moving) {
        velRef.current += d.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const th = (s.angle * Math.PI) / 180;
      const baseX = 60, baseY = H - 50;
      const slopeLen = Math.min((W - 140) / Math.cos(th), (H - 110) / Math.max(Math.sin(th), 0.05));
      const topX = baseX + slopeLen * Math.cos(th);
      const topY = baseY - slopeLen * Math.sin(th);
      // Hill
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.lineTo(topX, baseY); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(baseX - 40, baseY); ctx.lineTo(W, baseY); ctx.stroke();
      // Angle arc
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(baseX, baseY, 34, -th, 0); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`θ = ${s.angle}°`, baseX + 40, baseY - 8);

      // Block starts mid-slope so it has visible room to travel BOTH up and
      // down depending on whether the applied push beats gravity.
      const startFrac = 0.45;
      const marginPx = 30;
      const maxUpM = (slopeLen * (1 - startFrac) - marginPx) / 30;
      const maxDownM = (slopeLen * startFrac - marginPx) / 30;
      if (posRef.current > maxUpM) { posRef.current = maxUpM; velRef.current = 0; }
      if (posRef.current < -maxDownM) { posRef.current = -maxDownM; velRef.current = 0; }

      const along = startFrac * slopeLen + posRef.current * 30;
      const bx = baseX + along * Math.cos(th);
      const by = baseY - along * Math.sin(th);
      const bw = 54, bh = 36;
      ctx.save();
      ctx.translate(bx, by); ctx.rotate(-th);
      ctx.fillStyle = d.direction === 'static' ? '#6366f1' : '#f59e0b';
      ctx.fillRect(-bw / 2, -bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, 0, -bh / 2 + 3);
      ctx.restore();

      // Direction vectors: dirDown = down-slope, dirUp = up-slope,
      // dirN = outward normal (away from surface), dirInto = into the slope.
      const c0x = bx, c0y = by - bh / 2;
      const dirDown: [number, number] = [-Math.cos(th), Math.sin(th)];
      const dirUp: [number, number] = [Math.cos(th), -Math.sin(th)];
      const dirN: [number, number] = [-Math.sin(th), -Math.cos(th)];
      const dirInto: [number, number] = [Math.sin(th), Math.cos(th)];

      // Full weight — drawn straight down in TRUE vertical (screen-space),
      // not rotated with the incline: this is the actual "line of force" of
      // gravity, independent of the surface it happens to rest on.
      if (s.showWeight) {
        forceArrow(ctx, c0x, c0y, 0, Math.min(d.weight * SCALE * 0.5, 90), '#8b5cf6', `mg = ${d.weight.toFixed(1)}N`, 16);
      }
      // The two components of that same weight, resolved along and
      // perpendicular to the incline surface — this is what the vertical
      // weight vector actually "splits into" once you tilt the surface.
      if (s.showComponents) {
        forceArrow(ctx, c0x, c0y, dirDown[0] * Math.min(d.gravityAlong * SCALE, 110), dirDown[1] * Math.min(d.gravityAlong * SCALE, 110), '#a855f7', `mg sinθ = ${d.gravityAlong.toFixed(1)}N`, -8);
        forceArrow(ctx, c0x, c0y, dirInto[0] * Math.min(d.gravityPerp * SCALE * 0.5, 70), dirInto[1] * Math.min(d.gravityPerp * SCALE * 0.5, 70), '#c084fc', `mg cosθ = ${d.gravityPerp.toFixed(1)}N`, 16);
      }
      if (s.showFriction && Math.abs(d.friction) > 0.05) {
        const fDir = d.friction >= 0 ? dirUp : dirDown;
        forceArrow(ctx, c0x, c0y, fDir[0] * Math.min(Math.abs(d.friction) * SCALE, 110), fDir[1] * Math.min(Math.abs(d.friction) * SCALE, 110), '#ef4444', `f = ${Math.abs(d.friction).toFixed(1)}N`, 14);
      }
      if (s.showNormal) {
        forceArrow(ctx, c0x, c0y, dirN[0] * Math.min(d.N * SCALE * 0.5, 70), dirN[1] * Math.min(d.N * SCALE * 0.5, 70), '#3b82f6', 'N', -6);
      }
      if (s.showApplied && s.appliedIncline > 0) {
        forceArrow(ctx, c0x, c0y, dirUp[0] * Math.min(s.appliedIncline * SCALE, 110), dirUp[1] * Math.min(s.appliedIncline * SCALE, 110), '#059669', `F = ${s.appliedIncline.toFixed(0)}N`, -8);
      }

      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (d.direction === 'static') {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — forces balanced (slips at θr = ${d.reposeAngle.toFixed(1)}° with no push)`, W / 2, 22);
      } else if (d.direction === 'down') {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING DOWN — a = g(sinθ − μk cosθ) = ${d.acceleration.toFixed(2)} m/s²`, W / 2, 22);
      } else {
        ctx.fillStyle = '#059669';
        ctx.fillText(`MOVING UP — a = ${d.acceleration.toFixed(2)} m/s² ${s.appliedIncline > 0 ? '(pushed against gravity + friction)' : ''}`, W / 2, 22);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
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

echo "  → src/app/simulations/friction/page.tsx"
cat > "src/app/simulations/friction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { flatFriction, inclineDynamics, frictionCurve } from '@/lib/physics/friction';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<FrictionMode, { title: string; icon: string; sub: string; eq: string }> = {
  flat:    { title: 'Flat surface', icon: '➡️', sub: 'Push a block along the ground', eq: 'f ≤ μsN,  f = μkN once sliding' },
  incline: { title: 'Inclined plane', icon: '⛰️', sub: 'A block on a slope',           eq: 'tanθr = μs' },
};

const TEACHER_NOTES: Record<FrictionMode, string[]> = {
  flat: [
    'Static friction is NOT fixed — it exactly matches the applied force, up to a maximum of μsN. Push harder within that limit and friction grows to match; nothing moves.',
    'Once the applied force exceeds μsN, the block breaks free and KINETIC friction takes over — μk is always a little LESS than μs, which is why things "jerk" into motion.',
    'Friction is independent of the contact area and (to a good approximation) of speed — but always proportional to the normal reaction N.',
    'N = mg only holds here because the surface is flat and the push is horizontal — on a slope, or with an angled push, N changes.',
    'Real applications: brake pads (want HIGH μ), ice skates and ball bearings (want LOW μ), why worn tyres skid more easily.',
  ],
  incline: [
    'The angle at which a block JUST starts to slide is the angle of repose θr, where tanθr = μs — a clean way to measure friction experimentally.',
    'On the slope, the FULL weight mg acts straight down — resolve it into two components relative to the incline: mg sinθ (down the slope, drives sliding) and mg cosθ (into the slope, balanced by the normal reaction N).',
    'Below θr the block is static and friction exactly balances mg sinθ. Above it, friction is capped at μkN and the block slides down: a = g(sinθ − μk cosθ).',
    'Pushing a block UP the slope needs the applied force to overcome BOTH mg sinθ and friction — and once moving, friction switches to act DOWN the slope, opposing the upward push, so more force is needed to keep it moving up than to just hold it in place.',
    'This is literally how a plumb-line/tilt-table experiment measures μs for sand, wood, or rubber in a school lab.',
    'A steeper slope always needs a HIGHER μ to prevent sliding — this is why steep roofs need rougher tiles.',
  ],
};

const EXERCISES: Record<FrictionMode, { q: string; a: string }[]> = {
  flat: [
    { q: 'A 10kg block has μs=0.4. What is the maximum static friction force before it starts to slide?', a: 'N=mg=10×9.81=98.1N. F_s,max=μsN=0.4×98.1=39.2N.' },
    { q: 'A 5kg box needs 20N to start moving and 15N to keep it moving at constant velocity. Find μs and μk.', a: 'N=5×9.81=49.05N. μs=20/49.05=0.41. μk=15/49.05=0.31.' },
    { q: 'A 2kg block slides with μk=0.25 under a 15N push. Find its acceleration.', a: 'f=μkN=0.25×2×9.81=4.9N. Net=15−4.9=10.1N. a=10.1/2=5.05 m/s².' },
  ],
  incline: [
    { q: 'A block just begins to slide on a slope at 22°. Find μs.', a: 'μs = tan22° ≈ 0.40.' },
    { q: 'A 4kg block sits on a 35° slope with μs=0.5. Does it slide? Show your working.', a: 'mg sinθ = 4×9.81×sin35° ≈ 22.5N. μs·mg cosθ = 0.5×4×9.81×cos35° ≈ 16.1N. Since 22.5N > 16.1N, YES it slides.' },
    { q: 'A block slides down a 40° slope with μk=0.2. Find its acceleration.', a: 'a = g(sinθ − μk cosθ) = 9.81(sin40° − 0.2cos40°) ≈ 9.81(0.643−0.153) ≈ 4.81 m/s².' },
    { q: 'A 5kg block on a 30° slope (μs=0.4, μk=0.3) is pushed with a 60N force up the slope. Find the acceleration.', a: 'mg sinθ=5×9.81×sin30°=24.5N. N=5×9.81×cos30°=42.5N. Kinetic friction=0.3×42.5=12.7N (acts down-slope, opposing the push). Net=60−24.5−12.7=22.8N. a=22.8/5≈4.56 m/s² up the slope.' },
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

function ToggleChip({ label, active, onClick, color }: { label: string; active: boolean; onClick: () => void; color: string }) {
  return (
    <button onClick={onClick}
      className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
        active ? 'border-transparent text-white' : 'border-gray-200 bg-white text-gray-400'
      }`}
      style={active ? { backgroundColor: color } : undefined}>
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${active ? 'bg-white' : 'bg-gray-300'}`} />
      {label}
    </button>
  );
}

function FrictionGraph({ mass, muS, muK, applied }: { mass: number; muS: number; muK: number; applied: number }) {
  const fMax = mass * 9.81 * muS * 2.2;
  const data = useMemo(() => frictionCurve(mass, muS, muK, fMax), [mass, muS, muK, fMax]);
  const r = flatFriction(mass, applied, muS, muK);
  const staticLimit = muS * mass * 9.81;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="F" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Applied force F (N)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Friction f (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'f']} labelFormatter={f => `F=${Number(f).toFixed(1)}N`} />
        <Line type="linear" dataKey="f" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={staticLimit} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'μsN', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(applied, fMax)} y={r.friction} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function FrictionPage() {
  const [mode, setMode] = useState<FrictionMode>('flat');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [mass, setMass] = useState(5);
  const [applied, setApplied] = useState(25);
  const [angle, setAngle] = useState(35);
  const [appliedIncline, setAppliedIncline] = useState(0); // 0 = gravity only (slides down if steep enough)
  const [muS, setMuS] = useState(0.4);
  const [muK, setMuK] = useState(0.3);

  // Force-arrow visibility — purely cosmetic, shared across both modes so a
  // preference carries over when switching tabs.
  const [showWeight, setShowWeight] = useState(true);
  const [showComponents, setShowComponents] = useState(true);
  const [showNormal, setShowNormal] = useState(true);
  const [showFriction, setShowFriction] = useState(true);
  const [showApplied, setShowApplied] = useState(true);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, mass, applied, angle, appliedIncline, muS, muK, reset]);

  const flat = flatFriction(mass, applied, muS, muK);
  const inc = inclineDynamics(mass, angle, muS, muK, appliedIncline, 0);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Friction</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as FrictionMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
                  appliedIncline={appliedIncline} muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
                  showWeight={showWeight} showComponents={showComponents} showNormal={showNormal}
                  showFriction={showFriction} showApplied={showApplied}
                  width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/friction"
                  title={`${MODE_META[mode].title} friction — A-Factor STEM Studio`}
                  params={{ mode, mass, applied, angle, appliedIncline, muS, muK }} />
              </div>

              {mode === 'flat' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Friction vs applied force</p>
                  <FrictionGraph mass={mass} muS={muS} muK={muK} applied={applied} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Friction RISES to match F (static), then plateaus at μkN once sliding
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Show forces</p>
                <div className="flex flex-wrap gap-1.5">
                  <ToggleChip label="Weight (mg)" active={showWeight} onClick={() => setShowWeight(v => !v)} color="#8b5cf6" />
                  {mode === 'incline' && (
                    <ToggleChip label="Components (∥ & ⊥)" active={showComponents} onClick={() => setShowComponents(v => !v)} color="#a855f7" />
                  )}
                  <ToggleChip label="Normal (N)" active={showNormal} onClick={() => setShowNormal(v => !v)} color="#3b82f6" />
                  <ToggleChip label="Friction (f)" active={showFriction} onClick={() => setShowFriction(v => !v)} color="#ef4444" />
                  <ToggleChip label="Applied (F)" active={showApplied} onClick={() => setShowApplied(v => !v)} color="#059669" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
                {mode === 'flat' && (
                  <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
                )}
                {mode === 'incline' && (
                  <>
                    <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                    <Slider label="Applied push (up-slope)" unit="N" value={appliedIncline} min={0} max={100} step={1} set={setAppliedIncline} color="#059669"
                      note="0 = gravity only. Push past mg sinθ + friction to send the block UP the slope." />
                  </>
                )}
                <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
                <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" note="μk is kept ≤ μs, as it always is physically" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'flat' && <>
                    <StatRow label="Normal reaction N" value={flat.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="Max static friction" value={flat.staticMax.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Current friction" value={flat.friction.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="State" value={flat.moving ? 'sliding' : 'static'} unit="" color="text-rose-500" />
                    <StatRow label="Acceleration" value={flat.acceleration.toFixed(2)} unit="m/s²" color="text-purple-600" />
                  </>}
                  {mode === 'incline' && <>
                    <StatRow label="Weight (mg)" value={inc.weight.toFixed(1)} unit="N" color="text-violet-600" />
                    <StatRow label="Normal reaction N" value={inc.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="mg sinθ (∥ to slope)" value={inc.gravityAlong.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="mg cosθ (⊥ to slope)" value={inc.gravityPerp.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="Max static friction" value={inc.staticMax.toFixed(1)} unit="N" color="text-rose-500" />
                    <StatRow label="Angle of repose" value={inc.reposeAngle.toFixed(1)} unit="°" color="text-purple-600" />
                    <StatRow label="At rest, would…" value={inc.direction === 'static' ? 'stay still' : inc.direction === 'up' ? 'move up' : 'slide down'} unit="" color="text-gray-600" />
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
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
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

echo "  → src/app/embed/friction/page.tsx"
cat > "src/app/embed/friction/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function ToggleChip({ label, active, onClick, color }: { label: string; active: boolean; onClick: () => void; color: string }) {
  return (
    <button onClick={onClick}
      className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
        active ? 'border-transparent text-white' : 'border-gray-200 bg-white text-gray-400'
      }`}
      style={active ? { backgroundColor: color } : undefined}>
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${active ? 'bg-white' : 'bg-gray-300'}`} />
      {label}
    </button>
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

function FrictionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): FrictionMode => (sp.get('mode') === 'incline' ? 'incline' : 'flat'))();
  const showControls = sp.get('controls') !== '0';

  const [mass, setMass] = useState(() => num(sp, 'mass', 5, 1, 20));
  const [applied, setApplied] = useState(() => num(sp, 'applied', 25, 0, 80));
  const [angle, setAngle] = useState(() => num(sp, 'angle', 35, 0, 60));
  const [appliedIncline, setAppliedIncline] = useState(() => num(sp, 'push', 0, 0, 100));
  const [muS, setMuS] = useState(() => num(sp, 'muS', 0.4, 0.05, 1));
  const [muK, setMuK] = useState(() => num(sp, 'muK', 0.3, 0.05, 1));

  const [showWeight, setShowWeight] = useState(true);
  const [showComponents, setShowComponents] = useState(true);
  const [showNormal, setShowNormal] = useState(true);
  const [showFriction, setShowFriction] = useState(true);
  const [showApplied, setShowApplied] = useState(true);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mass, applied, angle, appliedIncline, muS, muK, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
        appliedIncline={appliedIncline} muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
        showWeight={showWeight} showComponents={showComponents} showNormal={showNormal}
        showFriction={showFriction} showApplied={showApplied}
        width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <>
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Show forces</p>
            <div className="flex flex-wrap gap-1.5">
              <ToggleChip label="Weight (mg)" active={showWeight} onClick={() => setShowWeight(v => !v)} color="#8b5cf6" />
              {mode === 'incline' && (
                <ToggleChip label="Components" active={showComponents} onClick={() => setShowComponents(v => !v)} color="#a855f7" />
              )}
              <ToggleChip label="Normal (N)" active={showNormal} onClick={() => setShowNormal(v => !v)} color="#3b82f6" />
              <ToggleChip label="Friction (f)" active={showFriction} onClick={() => setShowFriction(v => !v)} color="#ef4444" />
              <ToggleChip label="Applied (F)" active={showApplied} onClick={() => setShowApplied(v => !v)} color="#059669" />
            </div>
          </div>
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
            <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
            {mode === 'flat'
              ? <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
              : <>
                  <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                  <Slider label="Push up-slope" unit="N" value={appliedIncline} min={0} max={100} step={1} set={setAppliedIncline} color="#059669" />
                </>}
            <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
            <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" />
          </div>
        </>
      )}
      <PoweredBy />
    </div>
  );
}

export default function FrictionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <FrictionEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v10 applied — 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/friction -> Inclined plane tab. Push slider above 0"
echo "and the block should climb; toggle each force chip on/off without the"
echo "sim resetting."
