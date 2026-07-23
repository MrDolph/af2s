#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v15: fix collision reset bug + full revamp of
# "Consequences of Newton's laws"
#
#   1. COLLISION RESET BUG (root cause found & fixed). collParams was an
#      unmemoized object recreated every render. The instant onComplete
#      fired — right at the impact→after transition — it triggered
#      setCollResult/setIsComplete/setIsRunning, the page re-rendered, a
#      NEW collParams reference was created, and CollisionCanvas's
#      phase-reset effect (which depends on [params]) fired at exactly that
#      moment — resetting the whole sequence right when it should show the
#      result. Same root cause as the earlier Newton's 2nd law "vibrating
#      block" bug. Fixed with useMemo.
#
#      Also rewrote CollisionCanvas itself: it never used wall-clock timing,
#      and the impact-phase transition used a raw setTimeout completely
#      decoupled from pause state. Positions are now a pure function of
#      elapsed time (no drift, exact pause/resume) — verified numerically
#      that all three phases (before/impact/after) connect with zero
#      position jump across a range of mass/velocity combinations, and
#      caught + fixed my own pacing regression (first pass was ~48x too
#      slow — needed the same px-per-second scale the old frame-based code
#      had baked in).
#
#   2. WEIGHTLESSNESS AND PROPULSION HAD NO ACTUAL SIMULATION. Both were
#      static info panels with Run/Pause/Reset explicitly hidden — nothing
#      to run. Built two real animated canvases from scratch:
#        - WeightlessnessCanvas: stationary-vs-free-falling chambers side by
#          side. The falling chamber's scale reads exactly 0N the instant
#          it starts moving, at every altitude preset — correctly showing
#          that weightlessness is about falling, not "low gravity".
#        - PropulsionCanvas: a real launch, with thrust-scaled exhaust flame,
#          a starfield that streams faster as speed increases, and
#          acceleration that visibly climbs through the burn as fuel mass
#          drops (a = thrust/mass, mass falling). Added rocketStateAt() to
#          the physics lib — an exact implementation of the Tsiolkovsky
#          rocket equation — plus adaptive time-compression so any slider
#          combination (a 45,000-second burn included) plays out in about
#          18 watchable real seconds, verified across the slider extremes.
#      Both are now wired into Run/Pause/Reset like every other topic, with
#      live stats fed back into the Results panel. Existing supplementary
#      content (comparison cards, altitude presets, momentum-conservation
#      note) was kept, now presented alongside the real simulation instead
#      of being the entire "simulation".
#
#   3. Fixed the same frame-based (not wall-clock) timing bug in
#      ElevatorCanvas and WalkingCanvas that's been fixed everywhere else
#      in this app, and made WalkingCanvas loop instead of freezing at the
#      wall.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v15-consequences-revamp.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v15: collision fix + consequences-of-motion revamp ──"
mkdir -p "src/app/simulations/consequences-of-motion" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/consequences.ts"
cat > "src/lib/physics/consequences.ts" << 'AFEOF'
export const g = 9.81;

// ── Elevator ──────────────────────────────────────────────────────────────────
export type ElevatorState = 'rest' | 'accel-up' | 'constant-up' | 'decel-up' | 'accel-down' | 'constant-down' | 'decel-down' | 'freefall';

export function apparentWeight(mass: number, acceleration: number): number {
  return mass * (g + acceleration); // N, acceleration positive=up
}

export function elevatorAcceleration(state: ElevatorState, a: number): number {
  switch (state) {
    case 'accel-up':    return +a;
    case 'decel-up':    return -a;
    case 'accel-down':  return -a;
    case 'decel-down':  return +a;
    case 'freefall':    return -g;
    default:            return 0;
  }
}

// ── Collision ─────────────────────────────────────────────────────────────────
export interface CollisionParams {
  m1: number; u1: number; // mass kg, initial velocity m/s
  m2: number; u2: number;
  type: 'elastic' | 'inelastic' | 'perfectly-inelastic';
  e?: number; // coefficient of restitution (0-1)
}

export function solveCollision(p: CollisionParams) {
  const { m1, u1, m2, u2, type } = p;
  const e = type === 'elastic' ? 1 : type === 'perfectly-inelastic' ? 0 : (p.e ?? 0.5);

  // Conservation of momentum: m1u1 + m2u2 = m1v1 + m2v2
  // Coefficient of restitution: e = (v2 - v1) / (u1 - u2)
  const v2 = (m1 * u1 * (1 + e) + u2 * (m2 - e * m1)) / (m1 + m2);
  const v1 = e * (u2 - u1) + v2;

  const keBefore = 0.5 * m1 * u1 * u1 + 0.5 * m2 * u2 * u2;
  const keAfter  = 0.5 * m1 * v1 * v1 + 0.5 * m2 * v2 * v2;
  const momentumBefore = m1 * u1 + m2 * u2;
  const momentumAfter  = m1 * v1 + m2 * v2;

  return {
    v1: +v1.toFixed(3), v2: +v2.toFixed(3),
    keBefore: +keBefore.toFixed(2), keAfter: +keAfter.toFixed(2),
    keLost: +(keBefore - keAfter).toFixed(2),
    momentumBefore: +momentumBefore.toFixed(3),
    momentumAfter: +momentumAfter.toFixed(3),
    impulse: +(m1 * (v1 - u1)).toFixed(3),
  };
}

// ── Propulsion ────────────────────────────────────────────────────────────────
export function rocketAnalytics(m: number, exhaustSpeed: number, massFlowRate: number) {
  const thrust = exhaustSpeed * massFlowRate; // N
  const a = thrust / m;
  return { thrust: +thrust.toFixed(1), acceleration: +a.toFixed(3) };
}

// Rocket state at time t, accounting for the mass lost as fuel burns — this
// is the actual reason rocket acceleration climbs through a launch even
// though the engine's thrust stays constant: a = thrust / m(t), and m(t)
// keeps falling. Velocity follows the Tsiolkovsky rocket equation
// v(t) = v_e · ln(m0/m(t)), which is exact for constant exhaust speed and
// constant mass flow rate (no gravity/drag — this demo is framed as deep
// space / momentum conservation, not a full launch trajectory).
export interface RocketState {
  t: number;
  mass: number;
  v: number;
  thrust: number;
  acceleration: number;
  fuelRemaining: number;
  fuelFraction: number; // 0..1
  burnedOut: boolean;
  burnTime: number;
}
export function rocketBurnTime(fuelMass: number, massFlowRate: number): number {
  return massFlowRate > 0 ? fuelMass / massFlowRate : Infinity;
}
export function rocketStateAt(
  t: number, dryMass: number, fuelMass: number, exhaustSpeed: number, massFlowRate: number
): RocketState {
  const m0 = dryMass + fuelMass;
  const burnTime = rocketBurnTime(fuelMass, massFlowRate);
  const tBurn = Math.min(t, burnTime);
  const massBurned = massFlowRate * tBurn;
  const mass = m0 - massBurned;
  const burnedOut = t >= burnTime;
  const thrust = burnedOut ? 0 : exhaustSpeed * massFlowRate;
  const acceleration = burnedOut ? 0 : thrust / mass;
  const v = exhaustSpeed * Math.log(m0 / mass); // same value once burned out (mass frozen at dryMass)
  return {
    t, mass, v, thrust, acceleration,
    fuelRemaining: fuelMass - massBurned,
    fuelFraction: fuelMass > 0 ? (fuelMass - massBurned) / fuelMass : 0,
    burnedOut, burnTime,
  };
}

// ── Free fall / weightlessness ───────────────────────────────────────────────
// Distance fallen under constant acceleration gValue, starting from rest.
export function freeFallDistance(t: number, gValue: number): number {
  return 0.5 * gValue * t * t;
}

// ── Impulse ───────────────────────────────────────────────────────────────────
export function impulse(force: number, time: number) {
  return force * time;
}
export function impulseMomentum(mass: number, u: number, v: number) {
  return mass * (v - u); // = impulse
}
AFEOF

echo "  → src/components/simulation/CollisionCanvas.tsx"
cat > "src/components/simulation/CollisionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { CollisionParams, solveCollision } from '@/lib/physics/consequences';

interface Props {
  params: CollisionParams;
  isRunning: boolean; isPaused: boolean;
  onComplete?: (result: ReturnType<typeof solveCollision>) => void;
  width?: number; height?: number;
}

const BW = 64;
const X1_START = 80;
const X2_START = 500;
const IMPACT_FLASH_DURATION = 0.3; // s — bodies stay visually in contact for this long
// px per (m/s) per second of wall-clock time — tuned to match the pacing of
// the original frame-based animation (which moved u*0.8px every frame,
// ~48px/s at 60fps) now that motion is driven by real elapsed time instead.
const PX_PER_MPS = 48;

type Phase = 'before' | 'impact' | 'after';

export function CollisionCanvas({ params, isRunning, isPaused, onComplete, width = 680, height = 220 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);           // wall-clock time since this run started/reset
  const tImpact = useRef(0);     // the value of t at the moment of impact
  const phase = useRef<Phase>('before');
  const completedRef = useRef(false);
  const result = useRef(solveCollision(params));
  const simRef = useRef({ params, isRunning, isPaused, onComplete });
  simRef.current = { params, isRunning, isPaused, onComplete };

  useEffect(() => {
    phase.current = 'before';
    t.current = 0;
    tImpact.current = 0;
    completedRef.current = false;
    lastFrameRef.current = null;
    result.current = solveCollision(params);
  }, [params]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { params: p, isRunning: r, isPaused: pa, onComplete: oc } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const groundY = H - 50;

    // Real wall-clock dt, gated on running/paused exactly like every other
    // canvas in the app — this also means the impact flash duration and the
    // moment onComplete fires both correctly freeze while paused, instead of
    // the old setTimeout (which kept counting down regardless of pause and
    // was the root of the sequence "skipping ahead" unpredictably).
    let dt = 0;
    if (r && !pa && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        t.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Position is always a pure function of elapsed time (not an
    // accumulator), so there's no drift and pausing/resuming is exact.
    let x1: number, x2: number;
    if (phase.current === 'before') {
      x1 = X1_START + p.u1 * PX_PER_MPS * t.current;
      x2 = X2_START + p.u2 * PX_PER_MPS * t.current;
      if (dt > 0 && x1 + BW >= x2) {
        phase.current = 'impact';
        tImpact.current = t.current;
        result.current = solveCollision(p);
        // Clamp to the exact contact point so the flash starts flush against
        // both bodies rather than with a visible last-frame overlap.
        x2 = x1 + BW;
      }
    } else if (phase.current === 'impact') {
      x1 = X1_START + p.u1 * PX_PER_MPS * tImpact.current;
      x2 = x1 + BW; // frozen in contact during the flash
      if (t.current - tImpact.current >= IMPACT_FLASH_DURATION) {
        phase.current = 'after';
        if (!completedRef.current) { completedRef.current = true; oc?.(result.current); }
      }
    } else {
      const tAfter = t.current - tImpact.current - IMPACT_FLASH_DURATION;
      const xImpact = X1_START + p.u1 * PX_PER_MPS * tImpact.current + BW; // shared contact point
      x1 = xImpact - BW + result.current.v1 * PX_PER_MPS * tAfter;
      x2 = xImpact + result.current.v2 * PX_PER_MPS * tAfter;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    const by = groundY - 56;
    const midY = by + 28;

    // Impact flash
    if (phase.current === 'impact') {
      ctx.fillStyle = 'rgba(251,191,36,0.35)';
      ctx.beginPath(); ctx.arc(x1 + BW / 2, midY, 50, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('IMPACT!', x1 + BW / 2, midY - 55);
    }

    // Block 1
    const bg1 = ctx.createLinearGradient(x1, by, x1, by + 56);
    bg1.addColorStop(0, '#818cf8'); bg1.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg1;
    ctx.beginPath(); ctx.roundRect(x1, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x1, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m1}kg`, x1 + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u1} m/s` : `v=${result.current.v1.toFixed(1)} m/s`, x1 + BW / 2, midY + 10);

    // Block 2
    const bg2 = ctx.createLinearGradient(x2, by, x2, by + 56);
    bg2.addColorStop(0, '#34d399'); bg2.addColorStop(1, '#059669');
    ctx.fillStyle = bg2;
    ctx.beginPath(); ctx.roundRect(x2, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#047857'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x2, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m2}kg`, x2 + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u2} m/s` : `v=${result.current.v2.toFixed(1)} m/s`, x2 + BW / 2, midY + 10);

    // Velocity arrows before impact
    if (phase.current === 'before') {
      [{ x: x1, v: p.u1, w: BW }, { x: x2, v: p.u2, w: BW }].forEach(b => {
        if (Math.abs(b.v) < 0.01) return;
        const dir = Math.sign(b.v);
        const ax = dir > 0 ? b.x + b.w : b.x;
        const arrowLen = Math.min(Math.abs(b.v) * 10, 60);
        ctx.save();
        ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(ax, midY - 30); ctx.lineTo(ax + dir * arrowLen, midY - 30); ctx.stroke();
        ctx.fillStyle = '#f59e0b';
        ctx.beginPath(); ctx.moveTo(ax + dir * arrowLen, midY - 30);
        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 35);
        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 25);
        ctx.closePath(); ctx.fill();
        ctx.restore();
      });

      // Warn if the bodies are not actually on a collision course, so the
      // "before" phase doesn't just run forever with no explanation.
      if (p.u1 - p.u2 <= 0) {
        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Not closing — body 1 is not catching up to body 2 (raise u₁ or lower u₂)', W / 2, 20);
      }
    }

    // Type label
    ctx.fillStyle = '#6366f1'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`${p.type} collision`, 10, 18);
    if (phase.current === 'after') {
      ctx.fillStyle = '#10b981';
      ctx.fillText(`p: ${result.current.momentumBefore.toFixed(1)} → ${result.current.momentumAfter.toFixed(1)} kg·m/s  |  KE lost: ${result.current.keLost.toFixed(1)} J`, 10, H - 12);
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

echo "  → src/components/simulation/ElevatorCanvas.tsx"
cat > "src/components/simulation/ElevatorCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { apparentWeight, elevatorAcceleration, ElevatorState, g } from '@/lib/physics/consequences';

interface Props {
  mass: number;
  elevState: ElevatorState;
  manualAccel: number;
  isRunning: boolean;
  isPaused: boolean;
  width?: number; height?: number;
}

export function ElevatorCanvas({ mass, elevState, manualAccel, isRunning, isPaused, width = 500, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const yRef = useRef(220);
  const vyRef = useRef(0);
  const timeRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ mass, elevState, manualAccel, isRunning, isPaused });
  simRef.current = { mass, elevState, manualAccel, isRunning, isPaused };

  useEffect(() => {
    yRef.current = 220; vyRef.current = 0; timeRef.current = 0; lastFrameRef.current = null;
  }, [elevState, mass, manualAccel]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass: m, elevState: st, manualAccel: ma, isRunning: r, isPaused: p } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const accel = elevatorAcceleration(st, ma);
    const Wapp = apparentWeight(m, accel);
    const Wtrue = m * g;

    let dt = 0;
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      vyRef.current += accel * dt * 60; // px/s (60 = same visual scale as before)
      yRef.current -= vyRef.current * dt;
      // Clamp
      if (yRef.current < 60) { yRef.current = 60; vyRef.current = 0; }
      if (yRef.current > H - 80) { yRef.current = H - 80; vyRef.current = 0; }
      timeRef.current += dt;
    }

    ctx.clearRect(0, 0, W, H);

    // Building background
    ctx.fillStyle = '#f1f5f9';
    ctx.fillRect(60, 20, W - 120, H - 40);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.strokeRect(60, 20, W - 120, H - 40);

    // Floor lines
    for (let fl = 0; fl < 6; fl++) {
      const fy = 20 + fl * (H - 40) / 5;
      ctx.beginPath(); ctx.moveTo(60, fy); ctx.lineTo(W - 60, fy);
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.stroke();
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${5 - fl}F`, 62, fy + 12);
    }

    // Elevator cables
    ctx.beginPath();
    ctx.moveTo(W / 2 - 20, 20); ctx.lineTo(W / 2 - 20, yRef.current);
    ctx.moveTo(W / 2 + 20, 20); ctx.lineTo(W / 2 + 20, yRef.current);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.stroke();

    // Elevator box
    const EW = 120, EH = 80;
    const ex = W / 2 - EW / 2;
    const ey = yRef.current;

    // Elevator body
    ctx.fillStyle = '#e0e7ff';
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.roundRect(ex, ey, EW, EH, 6);
    ctx.fill(); ctx.stroke();

    // Door lines
    ctx.strokeStyle = '#818cf8'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(W / 2, ey + 10); ctx.lineTo(W / 2, ey + EH - 10);
    ctx.stroke();

    // Person inside
    const px = W / 2, py = ey + EH - 30;
    // Body
    ctx.fillStyle = '#4f46e5';
    ctx.beginPath(); ctx.ellipse(px, py - 10, 8, 14, 0, 0, Math.PI * 2); ctx.fill();
    // Head
    ctx.fillStyle = '#f9a8d4';
    ctx.beginPath(); ctx.arc(px, py - 28, 9, 0, Math.PI * 2); ctx.fill();

    // Scale under feet
    ctx.fillStyle = '#1e293b';
    ctx.beginPath(); ctx.roundRect(px - 16, py + 4, 32, 8, 3); ctx.fill();
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${Wapp.toFixed(0)}N`, px, py + 11);

    // Velocity arrow on elevator
    if (Math.abs(vyRef.current) > 0.3) {
      const dir = vyRef.current > 0 ? -1 : 1; // canvas y inverted
      const arrowY = ey + EH / 2;
      const arrowX = ex - 20;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(arrowX, arrowY); ctx.lineTo(arrowX, arrowY + dir * 30);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(arrowX, arrowY + dir * 30);
      ctx.lineTo(arrowX - 5, arrowY + dir * 20);
      ctx.lineTo(arrowX + 5, arrowY + dir * 20);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.restore();
    }

    // Info panel (right)
    const ix = W - 50;
    const infos = [
      { l: 'True weight', v: `${Wtrue.toFixed(1)} N`, c: '#64748b' },
      { l: 'Apparent weight', v: `${Wapp.toFixed(1)} N`, c: Wapp > Wtrue ? '#10b981' : Wapp < Wtrue ? '#ef4444' : '#6366f1' },
      { l: 'Acceleration', v: `${accel.toFixed(2)} m/s²`, c: '#f59e0b' },
      { l: 'State', v: st.replace('-', ' '), c: '#6366f1' },
    ];
    infos.forEach((info, i) => {
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'right';
      ctx.fillText(info.l, ix, 40 + i * 32);
      ctx.fillStyle = info.c; ctx.font = 'bold 12px system-ui';
      ctx.fillText(info.v, ix, 54 + i * 32);
    });

    // Weightlessness indicator
    if (st === 'freefall' || Wapp < 1) {
      ctx.fillStyle = 'rgba(239,68,68,0.15)';
      ctx.fillRect(ex, ey, EW, EH);
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('WEIGHTLESS', W / 2, ey - 8);
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

echo "  → src/components/simulation/WalkingCanvas.tsx"
cat > "src/components/simulation/WalkingCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  isRunning: boolean; isPaused: boolean;
  frictionEnabled: boolean; surfaceMass: number;
  width?: number; height?: number;
}

export function WalkingCanvas({ isRunning, isPaused, frictionEnabled, width = 680, height = 220 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const xRef = useRef(100);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ isRunning, isPaused, frictionEnabled });
  simRef.current = { isRunning, isPaused, frictionEnabled };

  useEffect(() => { tRef.current = 0; xRef.current = 100; lastFrameRef.current = null; }, [frictionEnabled]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, frictionEnabled: fr } = simRef.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      tRef.current += dt * 1.5; // matches the original leg-swing pacing
      if (fr) {
        xRef.current += dt * 108; // ~1.8px/frame at 60fps, now real-time
        if (xRef.current > W - 100) xRef.current = 100; // loop back for a continuous demo
      }
    }

    const t = tRef.current;
    const x = xRef.current;
    const groundY = H - 50;

    ctx.clearRect(0, 0, W, H);

    // Sky
    ctx.fillStyle = '#f0f6ff'; ctx.fillRect(0, 0, W, groundY);
    // Ground
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Surface label
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    if (!fr) {
      ctx.fillText('ICE — frictionless (no grip, no walking)', W / 2, H - 10);
      // Ice texture
      for (let ix = 0; ix < W; ix += 30) {
        ctx.strokeStyle = 'rgba(147,197,253,0.5)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(ix, groundY); ctx.lineTo(ix + 15, groundY + 8); ctx.stroke();
      }
    } else {
      ctx.fillText('Normal ground — friction provides forward push', W / 2, H - 10);
    }

    // Walking person (stick figure with leg animation)
    const py = groundY;
    const legAngle = Math.sin(t * 4) * 0.5;

    // Body
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x, py - 80); ctx.lineTo(x, py - 40); ctx.stroke();
    // Head
    ctx.fillStyle = '#f9a8d4'; ctx.beginPath(); ctx.arc(x, py - 92, 12, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#ec4899'; ctx.lineWidth = 1.5; ctx.stroke();
    // Arms
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, py - 70); ctx.lineTo(x + Math.cos(legAngle + 1) * 25, py - 50);
    ctx.moveTo(x, py - 70); ctx.lineTo(x - Math.cos(legAngle + 1) * 25, py - 50);
    ctx.stroke();
    // Legs
    const legLen = 35;
    const footAngle = legAngle * 0.8;
    ctx.beginPath();
    ctx.moveTo(x, py - 40);
    ctx.lineTo(x + Math.sin(footAngle) * legLen, py - 10);
    ctx.lineTo(x + Math.sin(footAngle) * legLen + 10, py);
    ctx.moveTo(x, py - 40);
    ctx.lineTo(x - Math.sin(footAngle) * legLen, py - 10);
    ctx.lineTo(x - Math.sin(footAngle) * legLen + 10, py);
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5; ctx.stroke();

    // Force arrows
    if (fr && r) {
      const pushY = py - 10;
      // Foot pushes ground backward (action) — red arrow leftward from foot
      const footX = x + Math.sin(footAngle) * legLen + 10;
      ctx.save();
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(footX, pushY); ctx.lineTo(footX - 55, pushY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(footX - 55, pushY);
      ctx.lineTo(footX - 45, pushY - 5); ctx.lineTo(footX - 45, pushY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Foot on ground', footX - 28, pushY - 8);
      ctx.fillText('(action ←)', footX - 28, pushY + 14);

      // Ground pushes person forward (reaction) — green arrow rightward on person
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(x - 30, py - 45); ctx.lineTo(x + 35, py - 45); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x + 35, py - 45);
      ctx.lineTo(x + 25, py - 50); ctx.lineTo(x + 25, py - 40);
      ctx.closePath(); ctx.fill();
      ctx.fillText('Ground on person', x + 5, py - 52);
      ctx.fillText('(reaction →)', x + 5, py - 35);
      ctx.restore();
    }

    if (!fr && r) {
      // Feet slipping
      ctx.fillStyle = '#ef4444'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('No friction → no reaction force → cannot walk!', x, py - 110);
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

echo "  → src/components/simulation/PropulsionCanvas.tsx"
cat > "src/components/simulation/PropulsionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { rocketStateAt, rocketBurnTime } from '@/lib/physics/consequences';

interface Props {
  rocketMass: number; fuelFraction: number; exhaustSpeed: number; massFlowRate: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (simTime: number, v: number, burnedOut: boolean) => void;
  width?: number; height?: number;
}

const TARGET_REAL_SECONDS = 18; // any slider combination plays out in about this long

interface Star { x: number; y: number; speed: number; }

export function PropulsionCanvas({
  rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick,
  width = 660, height = 260,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const simTime = useRef(0);       // compressed "mission" time fed into the physics
  const starsRef = useRef<Star[]>([]);
  const simRef = useRef({ rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick });
  simRef.current = { rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick };

  useEffect(() => {
    simTime.current = 0;
    lastFrameRef.current = null;
    starsRef.current = Array.from({ length: 40 }, () => ({
      x: Math.random(), y: Math.random(), speed: 0.4 + Math.random() * 0.8,
    }));
  }, [rocketMass, fuelFraction, exhaustSpeed, massFlowRate]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { rocketMass: m, fuelFraction: ff, exhaustSpeed: ve, massFlowRate: mdot, isRunning: r, isPaused: pa, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const dryMass = m * (1 - ff);
    const fuelMass = m * ff;
    const burnTime = rocketBurnTime(fuelMass, mdot);
    const compression = Math.max(1, burnTime / TARGET_REAL_SECONDS);

    if (r && !pa && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        const realDt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        simTime.current += realDt * compression;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const state = rocketStateAt(simTime.current, dryMass, fuelMass, ve, mdot);
    ot?.(state.t, state.v, state.burnedOut);

    // ── Scene ──────────────────────────────────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, '#0f172a'); sky.addColorStop(1, '#1e293b');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);

    // Starfield streams past faster as speed increases — a visual proxy for
    // "the rocket is now moving faster" without needing it to fly off-screen
    // at velocities that can reach thousands of m/s.
    const streamSpeed = 0.002 + Math.min(state.v / 3000, 1) * 0.03;
    ctx.fillStyle = 'white';
    starsRef.current.forEach(s => {
      if (r && !pa) {
        s.x -= streamSpeed * s.speed;
        if (s.x < 0) { s.x = 1; s.y = Math.random(); }
      }
      const size = 0.8 + s.speed;
      ctx.globalAlpha = 0.5 + s.speed * 0.4;
      ctx.fillRect(s.x * W, s.y * H, size, size);
    });
    ctx.globalAlpha = 1;

    // Rocket, centred, nose pointing right
    const cx = W * 0.42, cy = H / 2;
    const bodyW = 70, bodyH = 34;

    // Exhaust flame — length/intensity track current thrust, vanishes at burnout
    if (!state.burnedOut && r) {
      const flameLen = 20 + (state.thrust / (ve * mdot || 1)) * 55;
      const flicker = Math.sin(simTime.current * 24) * 4;
      const grad = ctx.createLinearGradient(cx - bodyW / 2, cy, cx - bodyW / 2 - flameLen, cy);
      grad.addColorStop(0, 'rgba(253,224,71,0.95)');
      grad.addColorStop(0.5, 'rgba(251,146,60,0.85)');
      grad.addColorStop(1, 'rgba(239,68,68,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(cx - bodyW / 2, cy - 10);
      ctx.lineTo(cx - bodyW / 2 - flameLen - flicker, cy);
      ctx.lineTo(cx - bodyW / 2, cy + 10);
      ctx.closePath(); ctx.fill();
    }

    // Body
    const bodyGrad = ctx.createLinearGradient(cx, cy - bodyH / 2, cx, cy + bodyH / 2);
    bodyGrad.addColorStop(0, '#e0e7ff'); bodyGrad.addColorStop(1, '#a5b4fc');
    ctx.fillStyle = bodyGrad;
    ctx.beginPath();
    ctx.roundRect(cx - bodyW / 2, cy - bodyH / 2, bodyW, bodyH, 6);
    ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 1.5; ctx.stroke();
    // Nose cone
    ctx.fillStyle = '#818cf8';
    ctx.beginPath();
    ctx.moveTo(cx + bodyW / 2, cy - bodyH / 2);
    ctx.lineTo(cx + bodyW / 2 + 22, cy);
    ctx.lineTo(cx + bodyW / 2, cy + bodyH / 2);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#312e81'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${state.mass.toFixed(0)}kg`, cx, cy + 4);

    // Fuel gauge
    const gx = 16, gy = H - 26, gw = 90, gh = 8;
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw, gh, 4); ctx.fill();
    ctx.fillStyle = state.fuelFraction > 0.2 ? '#34d399' : '#f87171';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw * Math.max(0, state.fuelFraction), gh, 4); ctx.fill();
    ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Fuel ${(state.fuelFraction * 100).toFixed(0)}%`, gx, gy - 4);

    // HUD
    ctx.textAlign = 'right';
    const hud = [
      `T+${state.t.toFixed(1)}s`,
      `v = ${state.v.toFixed(1)} m/s`,
      `a = ${state.acceleration.toFixed(2)} m/s²`,
      `Thrust = ${state.thrust.toFixed(0)} N`,
    ];
    ctx.font = 'bold 10px monospace'; ctx.fillStyle = '#e0e7ff';
    hud.forEach((line, i) => ctx.fillText(line, W - 12, 18 + i * 15));

    if (state.burnedOut) {
      ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui'; ctx.fillStyle = '#fbbf24';
      ctx.fillText('🔥 Engine cutoff — coasting at constant velocity (Newton\u2019s 1st Law)', W / 2, H - 10);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/WeightlessnessCanvas.tsx"
cat > "src/components/simulation/WeightlessnessCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { freeFallDistance } from '@/lib/physics/consequences';

interface Props {
  mass: number;      // kg
  gValue: number;     // m/s² — local gravity at the selected altitude
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, distance: number) => void;
  width?: number; height?: number;
}

function drawChamber(
  ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number,
  fallOffset: number, scaleReading: number, label: string, weightless: boolean,
) {
  // Shaft
  ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1.5;
  ctx.strokeRect(x, y, w, h);
  ctx.fillStyle = '#f8fafc'; ctx.fillRect(x, y, w, h);

  const boxW = w * 0.6, boxH = 60;
  const bx = x + (w - boxW) / 2;
  const by = y + 10 + fallOffset;

  // Cabin
  ctx.fillStyle = weightless ? '#fee2e2' : '#e0e7ff';
  ctx.strokeStyle = weightless ? '#ef4444' : '#6366f1';
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.roundRect(bx, by, boxW, boxH, 6); ctx.fill(); ctx.stroke();

  // Person: floats mid-cabin if weightless, stands on the scale otherwise
  const px = bx + boxW / 2;
  const py = weightless ? by + boxH / 2 - 6 : by + boxH - 26;
  ctx.fillStyle = '#4f46e5';
  ctx.beginPath(); ctx.ellipse(px, py, 7, 12, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#f9a8d4';
  ctx.beginPath(); ctx.arc(px, py - 17, 8, 0, Math.PI * 2); ctx.fill();
  // Arms out if floating, at sides if standing
  ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2;
  ctx.beginPath();
  if (weightless) {
    ctx.moveTo(px, py - 4); ctx.lineTo(px - 16, py - 12);
    ctx.moveTo(px, py - 4); ctx.lineTo(px + 16, py - 12);
  } else {
    ctx.moveTo(px, py - 4); ctx.lineTo(px - 9, py + 6);
    ctx.moveTo(px, py - 4); ctx.lineTo(px + 9, py + 6);
  }
  ctx.stroke();

  // Scale, fixed to the cabin floor
  const sy = by + boxH - 10;
  ctx.fillStyle = '#1e293b';
  ctx.beginPath(); ctx.roundRect(bx + boxW / 2 - 16, sy, 32, 8, 3); ctx.fill();
  ctx.fillStyle = weightless ? '#ef4444' : '#059669';
  ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${scaleReading.toFixed(0)}N`, bx + boxW / 2, sy + 20);

  ctx.fillStyle = '#64748b'; ctx.font = 'bold 10px system-ui';
  ctx.fillText(label, x + w / 2, y - 6);
  if (weightless && fallOffset > 2) {
    ctx.fillStyle = '#ef4444'; ctx.font = 'bold 9px system-ui';
    ctx.fillText('WEIGHTLESS', x + w / 2, by - 4);
  }
}

export function WeightlessnessCanvas({ mass, gValue, isRunning, isPaused, onTick, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const landed = useRef(false);
  const simRef = useRef({ mass, gValue, isRunning, isPaused, onTick });
  simRef.current = { mass, gValue, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; landed.current = false; lastFrameRef.current = null; }, [mass, gValue]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass: m, gValue: gv, isRunning: r, isPaused: pa, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !pa && !landed.current && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const chamberH = H - 30;
    const maxDropPx = chamberH - 80;
    const dropDistanceM = freeFallDistance(t.current, gv);
    // Visual pixel scale chosen so a representative drop (Earth g, ~2s) just
    // about reaches the bottom of the shaft — purely for legibility, not a
    // literal 1:1 metre mapping.
    const pxPerMetre = maxDropPx / Math.max(freeFallDistance(2.2, 9.81), 1);
    const fallOffset = Math.min(dropDistanceM * pxPerMetre, maxDropPx);
    if (fallOffset >= maxDropPx && !landed.current) landed.current = true;

    ot?.(t.current, dropDistanceM);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, W, H);

    const gap = 16;
    const chamberW = (W - gap * 3) / 2;

    // Left: stationary reference — always shows true weight.
    drawChamber(ctx, gap, 24, chamberW, chamberH, 0, m * 9.81, 'Stationary (on Earth)', false);

    // Right: free-falling — reads 0N the instant it starts moving, by
    // definition of free fall, regardless of how large gv is.
    const falling = t.current > 0;
    drawChamber(ctx, gap * 2 + chamberW, 24, chamberW, chamberH, fallOffset, falling ? 0 : m * 9.81,
      landed.current ? 'Landed' : 'Free falling', falling && !landed.current);

    // Context readout
    ctx.fillStyle = '#475569'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`g at this altitude = ${gv.toFixed(2)} m/s²  (${(gv / 9.81 * 100).toFixed(0)}% of Earth surface)`, 10, H - 6);
    ctx.textAlign = 'right';
    ctx.fillText(`fallen ${dropDistanceM.toFixed(1)} m in ${t.current.toFixed(1)}s`, W - 10, H - 6);

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

echo "  → src/app/simulations/consequences-of-motion/page.tsx"
cat > "src/app/simulations/consequences-of-motion/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useEffect, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ElevatorCanvas } from '@/components/simulation/ElevatorCanvas';
import { WeightlessnessCanvas } from '@/components/simulation/WeightlessnessCanvas';
import { WalkingCanvas } from '@/components/simulation/WalkingCanvas';
import { PropulsionCanvas } from '@/components/simulation/PropulsionCanvas';
import { CollisionCanvas } from '@/components/simulation/CollisionCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  apparentWeight, solveCollision, rocketAnalytics, rocketStateAt,
  ElevatorState, CollisionParams, g,
} from '@/lib/physics/consequences';

type Topic = 'elevator' | 'weightlessness' | 'walking' | 'propulsion' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; law: string }> = {
  elevator:       { title: 'Elevator / Lift',      icon: '🛗', sub: 'Apparent weight and Newton\'s 2nd Law', law: 'R = m(g + a)' },
  weightlessness: { title: 'Weightlessness',        icon: '🚀', sub: 'Zero apparent weight in free fall and orbit', law: 'W_app = 0 when a = −g' },
  walking:        { title: 'Walking',               icon: '🚶', sub: 'Newton\'s 3rd Law — action and reaction', law: 'F_foot = −F_ground' },
  propulsion:     { title: 'Propulsion',            icon: '🛸', sub: 'Rockets, jets — momentum conservation', law: 'Thrust = v_e × ṁ' },
  collision:      { title: 'Collision & Impact',    icon: '💥', sub: 'Elastic vs inelastic — impulse-momentum', law: 'J = Δp = FΔt' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  elevator: [
    "Apparent weight = R = m(g + a). When a > 0 (accelerating up), R > mg — person feels heavier.",
    "When a < 0 (accelerating down), R < mg — person feels lighter. When a = −g (free fall), R = 0.",
    "The scale reads apparent weight, not true weight. This is what WAEC/IGCSE questions actually ask for.",
    "Common exam trap: during constant speed (a=0), the person feels exactly their true weight regardless of how fast they're going.",
    "Deceleration at the top of an upward journey = acceleration downward → lighter feeling, not heavier.",
  ],
  weightlessness: [
    "True weightlessness only exists at infinite distance from all masses. Everything else is apparent weightlessness.",
    "Astronauts in the ISS aren't weightless — they're in constant free fall (orbiting). g ≈ 8.8 m/s² at ISS altitude.",
    "An object in free fall experiences zero apparent weight because both the person and the scale accelerate at g.",
    "Apparent weightlessness can be experienced in a falling lift, a parabolic flight path, or orbital trajectory.",
    "JUPEB/IGCSE: distinguish carefully between 'gravitational field strength', 'weight', and 'apparent weight'.",
  ],
  walking: [
    "Walking is entirely powered by Newton's 3rd Law. Your foot pushes backward on the ground; ground pushes you forward.",
    "Without friction, there is no reaction force and you cannot walk — demonstrated by trying to walk on ice.",
    "The forward force on a person is the ground's reaction — it's an external force that accelerates the person.",
    "Common misconception: students think the push from the foot makes you move. It's the ground's reaction that moves you.",
    "Swimming: hand/foot pushes water backward (action), water pushes swimmer forward (reaction). Same principle.",
  ],
  propulsion: [
    "Rocket thrust = exhaust speed × mass flow rate (T = v_e × ṁ). Nothing to 'push against' — momentum conservation.",
    "As fuel burns, rocket mass decreases → same thrust gives increasing acceleration (a = T/m, m decreasing).",
    "Jet engines work in atmosphere (air provides reaction mass). Rockets carry their own oxidiser — work in vacuum.",
    "Specific impulse: efficiency measure for rockets. Higher exhaust velocity = more efficient propulsion.",
    "Conservation of momentum: before = 0 (at rest). After = rocket momentum + exhaust momentum. Always sums to 0.",
  ],
  collision: [
    "Momentum is always conserved in collisions (no external forces). Kinetic energy may or may not be conserved.",
    "Elastic collision: KE conserved (e=1). Inelastic: KE lost (e<1). Perfectly inelastic: objects stick together (e=0).",
    "Impulse = change in momentum = FΔt. Increasing contact time (crumple zones, airbags) reduces peak force.",
    "The impulse-momentum theorem is why cars have airbags — same Δp, longer Δt, smaller F on passenger.",
    "WAEC exam: most collision questions just apply p_before = p_after. Check if KE is asked separately.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  elevator: [
    { q: "A 60kg person stands in a lift accelerating upward at 2 m/s². Find their apparent weight. (g=10)", a: "R = m(g+a) = 60×(10+2) = 60×12 = 720 N. True weight = 600 N." },
    { q: "A 70kg person is in a lift decelerating at 3 m/s² while moving upward. Find apparent weight. (g=10)", a: "Decelerating upward means a = −3 m/s². R = 70×(10−3) = 70×7 = 490 N." },
    { q: "A scale reads 0 N for a 50kg person in a lift. What is happening?", a: "The lift is in free fall (a = −g = −10 m/s²). R = m(g + a) = 50×(10−10) = 0 N. Apparent weightlessness." },
  ],
  weightlessness: [
    { q: "Why do astronauts in the ISS float, even though gravity still acts on them?", a: "The ISS is in continuous free fall (orbiting). Both astronauts and station fall toward Earth at the same rate, so there's no normal force between them — apparent weightlessness." },
    { q: "A 80kg person is in a freely falling lift. What does a scale beneath them read?", a: "0 N — both person and scale fall at g, so no contact force exists between them." },
    { q: "Is there gravity on the Moon? Explain apparent weightlessness vs true weightlessness.", a: "Yes — g_moon ≈ 1.6 m/s². Astronauts have weight on the Moon but feel about 1/6 of Earth weight. True weightlessness only exists at infinite distance from all masses." },
  ],
  walking: [
    { q: "Explain why you cannot walk on a perfectly frictionless surface using Newton's Laws.", a: "When you push your foot backward, the ground needs friction to push back. Without friction, no reaction force acts forward on you, so by Newton's 1st Law, you don't move." },
    { q: "A 70kg person accelerates from rest to 2 m/s in 1s while walking. Find the average forward friction force.", a: "F = ma = 70 × (2/1) = 140 N forward (provided by ground friction as reaction to foot's push)." },
    { q: "Swimming: identify the action and reaction forces when a swimmer pushes off a wall.", a: "Action: swimmer pushes wall backward with force F. Reaction: wall pushes swimmer forward with equal force F. Swimmer accelerates; wall (attached to Earth) doesn't noticeably move." },
  ],
  propulsion: [
    { q: "A rocket of mass 5000 kg ejects gas at 2000 m/s at a rate of 10 kg/s. Find thrust and initial acceleration.", a: "Thrust = v_e × ṁ = 2000 × 10 = 20,000 N. a = F/m = 20000/5000 = 4 m/s²." },
    { q: "Why do rockets work in the vacuum of space but car engines don't?", a: "Rockets carry their own fuel AND oxidiser, ejecting exhaust backward. Cars need atmospheric oxygen to combust fuel. In vacuum, no air = no combustion for a car engine." },
    { q: "A 2 kg toy rocket is at rest. It ejects 0.5 kg of gas at 40 m/s. Find the rocket's speed after.", a: "Momentum conservation: 0 = 1.5 × v_rocket − 0.5 × 40. v_rocket = 20/1.5 ≈ 13.3 m/s." },
  ],
  collision: [
    { q: "A 3kg ball at 6 m/s hits a stationary 1kg ball. They stick together. Find their common velocity.", a: "Perfectly inelastic: (3×6 + 1×0) = (3+1)×v. v = 18/4 = 4.5 m/s." },
    { q: "A 0.1kg bullet at 400 m/s embeds in a 4.9kg block at rest. Find the block's velocity after.", a: "(0.1×400) = (0.1+4.9)×v. v = 40/5 = 8 m/s." },
    { q: "An airbag increases impact time from 0.01s to 0.1s for a 70kg person decelerating from 15 m/s to 0. Compare forces.", a: "Impulse = Δp = 70×15 = 1050 N·s. Without bag: F = 1050/0.01 = 105,000 N. With bag: F = 1050/0.1 = 10,500 N — 10× less force." },
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

export default function ConsequencesPage() {
  const [topic, setTopic] = useState<Topic>('elevator');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  // Elevator params
  const [elevMass, setElevMass] = useState(60);
  const [elevState, setElevState] = useState<ElevatorState>('rest');
  const [elevAccel, setElevAccel] = useState(3);

  // Weightlessness
  const [wlHeight, setWlHeight] = useState(400); // km orbit

  // Walking
  const [frictionEnabled, setFrictionEnabled] = useState(true);

  // Propulsion
  const [rocketMass, setRocketMass] = useState(5000);
  const [exhaustSpeed, setExhaustSpeed] = useState(2000);
  const [massFlowRate, setMassFlowRate] = useState(10);
  const [fuelFraction, setFuelFraction] = useState(0.6);
  const [liveRocket, setLiveRocket] = useState({ t: 0, v: 0, burnedOut: false });

  // Weightlessness — live readout from the falling chamber
  const [liveFall, setLiveFall] = useState({ t: 0, distance: 0 });

  // Collision
  const [collM1, setCollM1] = useState(3);
  const [collM2, setCollM2] = useState(2);
  const [collU1, setCollU1] = useState(6);
  const [collU2, setCollU2] = useState(0);
  const [collType, setCollType] = useState<CollisionParams['type']>('perfectly-inelastic');
  const [collE, setCollE] = useState(0.6);
  const [collResult, setCollResult] = useState<ReturnType<typeof solveCollision> | null>(null);

  // Stable object identity: without this, the instant the collision finishes
  // (onComplete calling setCollResult/setIsComplete/setIsRunning) the page
  // re-renders and recreates this object with a new reference. Since
  // CollisionCanvas's phase-reset effect depends on [params], that new
  // reference retriggers it at the exact moment impact transitions to
  // "after" — resetting the whole sequence right when it should be showing
  // the post-collision result. Same root cause as the earlier Newton's 2nd
  // law "vibrating block" bug.
  const collParams: CollisionParams = useMemo(
    () => ({ m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType, e: collE }),
    [collM1, collM2, collU1, collU2, collType, collE]
  );
  const rocketA = rocketAnalytics(rocketMass, exhaustSpeed, massFlowRate);
  const rocketDryMass = rocketMass * (1 - fuelFraction);
  const rocketFuelMass = rocketMass * fuelFraction;
  const rocketBurnout = rocketStateAt(1e9, rocketDryMass, rocketFuelMass, exhaustSpeed, massFlowRate); // final state after full burn
  const elevAppW = apparentWeight(elevMass, elevState === 'freefall' ? -g : elevState.includes('up') ? (elevState.includes('accel') ? elevAccel : elevState.includes('decel') ? -elevAccel : 0) : elevState.includes('down') ? (elevState.includes('accel') ? -elevAccel : elevState.includes('decel') ? elevAccel : 0) : 0);
  const collRes = solveCollision(collParams);

  // Orbit g
  const orbitG = g * Math.pow(6371 / (6371 + wlHeight), 2);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setCollResult(null);
    setLiveRocket({ t: 0, v: 0, burnedOut: false });
    setLiveFall({ t: 0, distance: 0 });
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, elevMass, elevState, elevAccel, frictionEnabled, rocketMass, exhaustSpeed, massFlowRate, fuelFraction, wlHeight, collM1, collM2, collU1, collU2, collType, collE, reset]);

  // Elevator is a tall, portrait-ish shaft; walking/collision are wide
  // and short — pick the matching base aspect before scaling up.
  const consBase = topic === 'elevator' ? { w: 500, h: 320 } : { w: 660, h: 200 };
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, consBase.w, consBase.h, 900);

  const lastTickRef = useRef(0);
  const handleRocketTick = useCallback((t: number, v: number, burnedOut: boolean) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveRocket({ t, v, burnedOut });
  }, []);
  const handleFallTick = useCallback((t: number, distance: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveFall({ t, distance });
  }, []);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Applications of Newton&apos;s Laws</p>
                <h1 className="text-lg font-semibold text-gray-900">Consequences of motion</h1>
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

          {/* Topic tabs — scrollable on mobile */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span>
                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].law}</span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + controls + params */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">

                {topic === 'elevator' && (
                  <ElevatorCanvas key={resetKey} mass={elevMass} elevState={elevState}
                    manualAccel={elevAccel} isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'weightlessness' && (
                  <WeightlessnessCanvas key={resetKey} mass={elevMass} gValue={orbitG}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleFallTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'walking' && (
                  <WalkingCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    frictionEnabled={frictionEnabled} surfaceMass={70}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'propulsion' && (
                  <PropulsionCanvas key={resetKey} rocketMass={rocketMass} fuelFraction={fuelFraction}
                    exhaustSpeed={exhaustSpeed} massFlowRate={massFlowRate}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleRocketTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'collision' && (
                  <CollisionCanvas key={resetKey} params={collParams}
                    isRunning={isRunning} isPaused={isPaused}
                    onComplete={r => { setCollResult(r); setIsComplete(true); setIsRunning(false); }}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              {/* Supplementary content: kept as extra explanatory context
                  alongside the real animated canvas above, not a substitute
                  for it. */}
              {topic === 'weightlessness' && (
                <div className="space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    {[
                      { label: 'On Earth surface', gv: 9.81, color: 'bg-red-50 border-red-200', textColor: 'text-red-700', icon: '🌍' },
                      { label: `At ${wlHeight}km orbit`, gv: orbitG, color: 'bg-blue-50 border-blue-200', textColor: 'text-blue-700', icon: '🛸' },
                      { label: 'Deep space', gv: 0, color: 'bg-purple-50 border-purple-200', textColor: 'text-purple-700', icon: '🪐' },
                    ].map(s => (
                      <div key={s.label} className={`rounded-xl border ${s.color} p-4 text-center`}>
                        <span className="text-2xl block mb-2">{s.icon}</span>
                        <p className="text-xs text-gray-500 mb-1">{s.label}</p>
                        <p className={`text-lg font-bold ${s.textColor}`}>{s.gv.toFixed(2)} m/s²</p>
                        <p className="text-xs font-medium mt-2 text-gray-600">
                          {s.gv < 0.1 ? '✓ No gravity to fall under' : s.gv < 5 ? 'Weaker gravity' : 'Full gravity — still weightless if falling'}
                        </p>
                      </div>
                    ))}
                  </div>
                  <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-4 text-center">
                    <p className="text-xs text-indigo-500 mb-1">Key insight</p>
                    <p className="text-sm text-indigo-800 leading-relaxed">
                      At {wlHeight}km altitude, g = {orbitG.toFixed(2)} m/s² — gravity is still {(orbitG / 9.81 * 100).toFixed(0)}% of Earth surface gravity.
                      The falling chamber above reads 0N the instant it starts moving, at every altitude — astronauts float not because gravity is absent, but because they (and their station) are in continuous free fall.
                    </p>
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
                    {[
                      { label: 'ISS orbit', h: 400 }, { label: 'GPS orbit', h: 20200 },
                      { label: 'GEO orbit', h: 35786 }, { label: 'Moon orbit', h: 384400 },
                    ].map(o => (
                      <button key={o.label} onClick={() => setWlHeight(o.h)}
                        className={`rounded-xl border p-3 transition text-xs ${wlHeight === o.h ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white border-gray-200 text-gray-600 hover:border-gray-300'}`}>
                        <p className="font-medium">{o.label}</p>
                        <p className="opacity-70">{o.h < 1000 ? `${o.h}km` : `${(o.h / 1000).toFixed(0)}k km`}</p>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {topic === 'propulsion' && (
                <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-3 text-xs text-indigo-800">
                  <p className="font-medium mb-1">Momentum conservation</p>
                  <p>Before launch: total momentum = 0. Ejecting exhaust backward at {exhaustSpeed} m/s gives the rocket equal momentum forward — no external force needed, which is why rockets (unlike jets) work in a vacuum. Thrust stays constant, but as fuel burns the rocket&apos;s mass falls, so acceleration a = thrust/mass keeps climbing through the burn.</p>
                </div>
              )}

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
                {topic === 'propulsion' && liveRocket.burnedOut && (
                  <span className="text-xs font-medium text-amber-600">🔥 Engine cutoff — coasting</span>
                )}
              </div>

              {/* Params */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'elevator' && (
                  <>
                    <Slider label="Mass" unit="kg" value={elevMass} min={10} max={150} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Acceleration magnitude" unit="m/s²" value={elevAccel} min={0.5} max={9.8} step={0.1} set={setElevAccel} color="#f59e0b" />
                    <div>
                      <p className="text-xs text-gray-500 mb-2">Elevator state</p>
                      <div className="grid grid-cols-2 gap-1.5">
                        {([
                          ['rest', 'At rest'], ['accel-up', 'Accelerating ↑'],
                          ['constant-up', 'Constant speed ↑'], ['decel-up', 'Decelerating ↑'],
                          ['accel-down', 'Accelerating ↓'], ['constant-down', 'Constant speed ↓'],
                          ['decel-down', 'Decelerating ↓'], ['freefall', '🆘 Free fall'],
                        ] as [ElevatorState, string][]).map(([s, l]) => (
                          <button key={s} onClick={() => setElevState(s)}
                            className={`px-2 py-2 rounded-lg text-xs font-medium border transition ${
                              elevState === s
                                ? s === 'freefall' ? 'bg-red-500 text-white border-red-500' : 'bg-indigo-600 text-white border-indigo-600'
                                : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
                            }`}>{l}</button>
                        ))}
                      </div>
                    </div>
                  </>
                )}

                {topic === 'weightlessness' && (
                  <>
                    <Slider label="Person mass" unit="kg" value={elevMass} min={40} max={120} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Orbit altitude" unit="km" value={wlHeight} min={200} max={400000} step={100} set={setWlHeight} color="#8b5cf6" />
                  </>
                )}

                {topic === 'walking' && (
                  <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                    <div>
                      <p className="text-xs font-medium text-gray-700">Ground friction</p>
                      <p className="text-[10px] text-gray-400">{frictionEnabled ? 'Normal ground — walking works' : 'Frictionless ice — cannot walk'}</p>
                    </div>
                    <button onClick={() => setFrictionEnabled(f => !f)}
                      className={`relative w-11 h-6 rounded-full transition ${frictionEnabled ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                      <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${frictionEnabled ? 'translate-x-5' : ''}`} />
                    </button>
                  </div>
                )}

                {topic === 'propulsion' && (
                  <>
                    <Slider label="Rocket mass (total)" unit="kg" value={rocketMass} min={500} max={50000} step={500} set={setRocketMass} color="#6366f1" />
                    <Slider label="Fuel fraction" unit="" value={fuelFraction} min={0.2} max={0.9} step={0.05} set={setFuelFraction} color="#8b5cf6" note={`${rocketFuelMass.toFixed(0)}kg fuel, ${rocketDryMass.toFixed(0)}kg dry mass`} />
                    <Slider label="Exhaust speed" unit="m/s" value={exhaustSpeed} min={200} max={5000} step={100} set={setExhaustSpeed} color="#f59e0b" />
                    <Slider label="Mass flow rate" unit="kg/s" value={massFlowRate} min={1} max={100} step={1} set={setMassFlowRate} color="#10b981" />
                  </>
                )}

                {topic === 'collision' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['elastic', 'inelastic', 'perfectly-inelastic'] as CollisionParams['type'][]).map(t => (
                        <button key={t} onClick={() => setCollType(t)}
                          className={`py-2 rounded-lg text-[10px] font-medium transition ${
                            collType === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{t === 'perfectly-inelastic' ? 'Stick together' : t.charAt(0).toUpperCase() + t.slice(1)}</button>
                      ))}
                    </div>
                    <Slider label="Mass 1 (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
                    <Slider label="Velocity 1" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
                    <Slider label="Mass 2 (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
                    <Slider label="Velocity 2" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
                    {collType === 'inelastic' && (
                      <Slider label="Coefficient of restitution (e)" unit="" value={collE} min={0.01} max={0.99} step={0.01} set={setCollE} color="#f59e0b" note="0 = stick together, 1 = elastic" />
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Results</p>
                <div className="space-y-2">
                  {topic === 'elevator' && [
                    { l: 'True weight', v: `${(elevMass * g).toFixed(1)} N`, c: 'text-gray-600' },
                    { l: 'Apparent weight', v: `${elevAppW.toFixed(1)} N`, c: elevAppW > elevMass * g ? 'text-emerald-600' : elevAppW < elevMass * g ? 'text-red-500' : 'text-indigo-600' },
                    { l: 'Difference', v: `${(elevAppW - elevMass * g).toFixed(1)} N`, c: 'text-amber-600' },
                    { l: 'Scale reads', v: `${(elevAppW / g).toFixed(2)} kg`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'weightlessness' && [
                    { l: 'True weight (Earth)', v: `${(elevMass * 9.81).toFixed(0)} N`, c: 'text-gray-600' },
                    { l: `g at ${wlHeight}km`, v: `${orbitG.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: 'Weight at altitude', v: `${(elevMass * orbitG).toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Apparent (falling)', v: '0 N (free fall)', c: 'text-red-500' },
                    { l: 'Fall time (live)', v: `${liveFall.t.toFixed(1)} s`, c: 'text-gray-600' },
                    { l: 'Fallen (live)', v: `${liveFall.distance.toFixed(1)} m`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'walking' && [
                    { l: 'Reaction force', v: frictionEnabled ? 'Present ✓' : 'None ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Locomotion', v: frictionEnabled ? 'Possible ✓' : 'Impossible ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Action', v: 'Foot pushes back', c: 'text-gray-600' },
                    { l: 'Reaction', v: frictionEnabled ? 'Ground pushes forward' : 'No reaction', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'propulsion' && [
                    { l: 'Thrust (at launch)', v: `${rocketA.thrust.toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Acceleration (at launch)', v: `${rocketA.acceleration.toFixed(3)} m/s²`, c: 'text-indigo-600' },
                    { l: 'T = v_e × ṁ', v: `${exhaustSpeed}×${massFlowRate}=${rocketA.thrust.toFixed(0)}`, c: 'text-gray-600' },
                    { l: 'Burnout speed', v: `${rocketBurnout.v.toFixed(0)} m/s`, c: 'text-purple-600' },
                    { l: 'Live speed', v: `${liveRocket.v.toFixed(0)} m/s`, c: 'text-emerald-600' },
                    { l: 'Live status', v: liveRocket.burnedOut ? 'Coasting (Newton 1st)' : liveRocket.t > 0 ? 'Burning' : 'Ready', c: liveRocket.burnedOut ? 'text-amber-600' : 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'collision' && [
                    { l: 'v₁ after', v: `${collRes.v1.toFixed(2)} m/s`, c: 'text-indigo-600' },
                    { l: 'v₂ after', v: `${collRes.v2.toFixed(2)} m/s`, c: 'text-emerald-600' },
                    { l: 'p before', v: `${collRes.momentumBefore.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'p after', v: `${collRes.momentumAfter.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'KE lost', v: `${collRes.keLost.toFixed(2)} J`, c: collRes.keLost < 0.01 ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Impulse', v: `${collRes.impulse.toFixed(2)} N·s`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
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

            {/* Teacher notes + exercises */}
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
                        <span><span className="font-medium text-indigo-600">Q{i+1}.</span> {ex.q}</span>
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

echo ""
echo "✓ Patch v15 applied — 7 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/consequences-of-motion"
echo "  - Collision tab: run it several times with different masses/speeds —"
echo "    it should play through before -> IMPACT -> after cleanly, never"
echo "    snapping back to the start on its own."
echo "  - Weightlessness tab: press Run, watch the right-hand chamber fall"
echo "    and its scale read 0N immediately."
echo "  - Propulsion tab: press Run, watch the rocket's acceleration/speed"
echo "    climb through the burn, then "Engine cutoff" at burnout."
