#!/bin/bash
# A-Factor STEM Studio — Newton's Laws simulation
# Run inside af2s/: bash newtons-laws-patch.sh
set -e
echo "Building Newton's Laws simulation..."

mkdir -p src/lib/physics
mkdir -p src/components/simulation
mkdir -p src/app/simulations/newtons-laws

# ── 1. Physics engine ─────────────────────────────────────────────────────────
cat > src/lib/physics/newtons-laws.ts << 'EOF'
export const g = 9.81; // m/s²

// ── First Law ─────────────────────────────────────────────────────────────────
export interface FirstLawState {
  x: number;       // position m
  v: number;       // velocity m/s
  time: number;
}
export function stepFirstLaw(
  state: FirstLawState,
  appliedForce: number,  // N (0 = inertia demo)
  mass: number,
  friction: number,      // coefficient 0–1
  dt: number
): FirstLawState {
  const normalForce = mass * g;
  const frictionForce = friction * normalForce * (state.v !== 0 ? -Math.sign(state.v) : 0);
  const netF = appliedForce + frictionForce;
  const a = netF / mass;
  const newV = state.v + a * dt;
  // Stop if friction kills motion and no force applied
  const stopped = appliedForce === 0 && Math.abs(newV) < 0.01 && Math.abs(state.v) < 0.5;
  return {
    x: state.x + (stopped ? 0 : state.v) * dt,
    v: stopped ? 0 : newV,
    time: state.time + dt,
  };
}

// ── Second Law ────────────────────────────────────────────────────────────────
export interface SecondLawParams {
  mass: number;          // kg
  appliedForce: number;  // N
  friction: number;      // coefficient 0–1
}
export interface SecondLawState {
  x: number; v: number; a: number; time: number;
  frictionForce: number; netForce: number;
}
export function getSecondLawAcceleration(p: SecondLawParams, v: number): number {
  const frictionF = p.friction * p.mass * g * (v !== 0 ? -Math.sign(v) : (p.appliedForce > 0 ? -1 : 1));
  const netF = p.appliedForce + frictionF;
  // Only apply friction if moving, or if static friction can't resist applied force
  const staticFrictionMax = p.friction * p.mass * g;
  if (v === 0 && Math.abs(p.appliedForce) <= staticFrictionMax) return 0;
  return netF / p.mass;
}
export function stepSecondLaw(
  state: SecondLawState, params: SecondLawParams, dt: number
): SecondLawState {
  const a = getSecondLawAcceleration(params, state.v);
  const newV = Math.max(0, state.v + a * dt); // block doesn't go backward in this demo
  const frictionF = params.friction * params.mass * g * (state.v !== 0 ? -1 : 0);
  return {
    x: state.x + state.v * dt,
    v: newV,
    a,
    time: state.time + dt,
    frictionForce: frictionF,
    netForce: params.appliedForce + frictionF,
  };
}
export function secondLawAnalytics(p: SecondLawParams) {
  const frictionF = p.friction * p.mass * g;
  const netF = Math.max(0, p.appliedForce - frictionF);
  const a = netF / p.mass;
  return { acceleration: +a.toFixed(3), netForce: +netF.toFixed(2), frictionForce: +frictionF.toFixed(2) };
}

// ── Third Law ─────────────────────────────────────────────────────────────────
export interface ThirdLawScenario {
  type: 'push' | 'rocket' | 'collision';
  mass1: number; mass2: number;
  force: number; // N
}
export function thirdLawAnalytics(s: ThirdLawScenario) {
  const a1 = s.force / s.mass1;
  const a2 = s.force / s.mass2;
  return { a1: +a1.toFixed(3), a2: +a2.toFixed(3), force: s.force };
}
EOF

# ── 2. Newton's 1st Law Canvas ────────────────────────────────────────────────
cat > src/components/simulation/NewtonsFirstCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { stepFirstLaw, FirstLawState } from '@/lib/physics/newtons-laws';

interface Props {
  mass: number; friction: number; initialVelocity: number;
  forceOn: boolean; appliedForce: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (s: FirstLawState) => void;
  width?: number; height?: number;
}

export function NewtonsFirstCanvas({
  mass, friction, initialVelocity, forceOn, appliedForce,
  isRunning, isPaused, onTick, width = 680, height = 220,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stateRef = useRef<FirstLawState>({ x: 0, v: initialVelocity, time: 0 });
  const simRef = useRef({ mass, friction, initialVelocity, forceOn, appliedForce, isRunning, isPaused, onTick, width, height });
  simRef.current = { mass, friction, initialVelocity, forceOn, appliedForce, isRunning, isPaused, onTick, width, height };

  useEffect(() => {
    stateRef.current = { x: 0, v: initialVelocity, time: 0 };
  }, [initialVelocity, mass, friction, appliedForce]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, forceOn, appliedForce: F, mass: m, friction: mu, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p) {
      stateRef.current = stepFirstLaw(stateRef.current, forceOn ? F : 0, m, mu, 0.016);
      ot?.(stateRef.current);
    }

    const state = stateRef.current;
    ctx.clearRect(0, 0, W, H);

    // Ground
    const groundY = H - 50;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Surface texture (friction indicator)
    if (mu > 0.05) {
      ctx.save();
      for (let x = 0; x < W; x += 20) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 10, groundY + 8);
        ctx.strokeStyle = `rgba(148,163,184,${Math.min(mu * 1.5, 0.6)})`;
        ctx.lineWidth = 1; ctx.stroke();
      }
      ctx.restore();
    }

    // Friction label
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`μ = ${mu.toFixed(2)} ${mu === 0 ? '(frictionless)' : mu < 0.2 ? '(low friction)' : '(high friction)'}`, 10, H - 10);

    // Block position (wrap around canvas)
    const BLOCK_W = 60, BLOCK_H = 44;
    const rawX = (state.x * 60) % (W + BLOCK_W);
    const bx = rawX < -BLOCK_W ? W + rawX : rawX;
    const by = groundY - BLOCK_H;

    // Block shadow
    ctx.fillStyle = 'rgba(0,0,0,0.08)';
    ctx.fillRect(bx + 4, groundY - 4, BLOCK_W, 8);

    // Block body
    const blockGrad = ctx.createLinearGradient(bx, by, bx, by + BLOCK_H);
    blockGrad.addColorStop(0, '#818cf8'); blockGrad.addColorStop(1, '#4f46e5');
    ctx.fillStyle = blockGrad;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.stroke();

    // Mass label on block
    ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${m} kg`, bx + BLOCK_W / 2, by + BLOCK_H / 2 + 4);

    // Applied force arrow
    if (forceOn && F > 0) {
      const arrowLen = Math.min(F * 1.2, 80);
      const ax = bx + BLOCK_W, ay = by + BLOCK_H / 2;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax + arrowLen, ay);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + arrowLen, ay);
      ctx.lineTo(ax + arrowLen - 10, ay - 6); ctx.lineTo(ax + arrowLen - 10, ay + 6);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.fillStyle = '#10b981'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`F=${F}N`, ax + arrowLen / 2, ay - 8);
      ctx.restore();
    }

    // Velocity arrow
    if (Math.abs(state.v) > 0.1) {
      const arrowLen = Math.min(Math.abs(state.v) * 8, 70);
      const dir = Math.sign(state.v);
      const ax = bx + (dir > 0 ? BLOCK_W : 0), ay = by - 10;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax + dir * arrowLen, ay);
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + dir * arrowLen, ay);
      ctx.lineTo(ax + dir * (arrowLen - 8), ay - 5);
      ctx.lineTo(ax + dir * (arrowLen - 8), ay + 5);
      ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
      ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`v=${state.v.toFixed(1)} m/s`, ax + dir * arrowLen / 2, ay - 10);
      ctx.restore();
    }

    // State info
    ctx.fillStyle = '#475569'; ctx.font = '11px monospace'; ctx.textAlign = 'right';
    ctx.fillText(`t=${state.time.toFixed(1)}s  v=${state.v.toFixed(2)}m/s`, W - 10, 20);

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
EOF

# ── 3. Newton's 2nd Law Canvas ────────────────────────────────────────────────
cat > src/components/simulation/NewtonsSecondCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { stepSecondLaw, SecondLawState, SecondLawParams } from '@/lib/physics/newtons-laws';

interface Props {
  params: SecondLawParams;
  isRunning: boolean; isPaused: boolean;
  onTick?: (s: SecondLawState) => void;
  onComplete?: () => void;
  width?: number; height?: number;
}

const TRACK_LEN = 12; // metres shown

export function NewtonsSecondCanvas({ params, isRunning, isPaused, onTick, onComplete, width = 680, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stateRef = useRef<SecondLawState>({ x: 0, v: 0, a: 0, time: 0, frictionForce: 0, netForce: 0 });
  const doneRef = useRef(false);
  const simRef = useRef({ params, isRunning, isPaused, onTick, onComplete });
  simRef.current = { params, isRunning, isPaused, onTick, onComplete };

  useEffect(() => {
    stateRef.current = { x: 0, v: 0, a: 0, time: 0, frictionForce: 0, netForce: 0 };
    doneRef.current = false;
  }, [params]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, params: pm, onTick: ot, onComplete: oc } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const state = stateRef.current;

    if (r && !p && !doneRef.current) {
      const next = stepSecondLaw(state, pm, 0.016);
      stateRef.current = next;
      ot?.(next);
      if (next.x >= TRACK_LEN) { doneRef.current = true; oc?.(); }
    }

    ctx.clearRect(0, 0, W, H);

    // Track
    const groundY = H - 55;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Track scale marks
    const scale = (W - 80) / TRACK_LEN;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    for (let i = 0; i <= TRACK_LEN; i += 2) {
      const tx = 40 + i * scale;
      ctx.fillText(`${i}m`, tx, H - 8);
      ctx.beginPath(); ctx.moveTo(tx, groundY); ctx.lineTo(tx, groundY + 5);
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1; ctx.stroke();
    }

    // Friction texture
    if (pm.friction > 0.05) {
      for (let x = 0; x < W; x += 18) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 9, groundY + 7);
        ctx.strokeStyle = `rgba(148,163,184,${Math.min(pm.friction, 0.5)})`;
        ctx.lineWidth = 1; ctx.stroke();
      }
    }

    // Block
    const BLOCK_W = 56, BLOCK_H = 44;
    const bx = 40 + Math.min(state.x, TRACK_LEN) * scale - BLOCK_W / 2;
    const by = groundY - BLOCK_H;

    ctx.fillStyle = 'rgba(0,0,0,0.07)';
    ctx.fillRect(bx + 4, groundY - 4, BLOCK_W, 8);

    const bg = ctx.createLinearGradient(bx, by, bx, by + BLOCK_H);
    bg.addColorStop(0, '#818cf8'); bg.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${pm.mass}kg`, bx + BLOCK_W / 2, by + BLOCK_H / 2 + 4);

    const midY = by + BLOCK_H / 2;

    // Applied force arrow (green, rightward)
    if (pm.appliedForce > 0) {
      const fLen = Math.min(pm.appliedForce * 1.5, 90);
      const ax = bx + BLOCK_W;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, midY); ctx.lineTo(ax + fLen, midY);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + fLen, midY);
      ctx.lineTo(ax + fLen - 10, midY - 6); ctx.lineTo(ax + fLen - 10, midY + 6);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.fillStyle = '#10b981'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`F=${pm.appliedForce}N`, ax + fLen / 2, midY - 10);
      ctx.restore();
    }

    // Friction arrow (red, leftward) — only when moving
    if (state.v > 0.01 && pm.friction > 0) {
      const fLen = Math.min(pm.friction * pm.mass * 9.81 * 1.2, 70);
      const ax = bx;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, midY + 14); ctx.lineTo(ax - fLen, midY + 14);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax - fLen, midY + 14);
      ctx.lineTo(ax - fLen + 9, midY + 8); ctx.lineTo(ax - fLen + 9, midY + 20);
      ctx.closePath(); ctx.fillStyle = '#ef4444'; ctx.fill();
      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`f=${(pm.friction * pm.mass * 9.81).toFixed(1)}N`, ax - fLen / 2, midY + 30);
      ctx.restore();
    }

    // Net force label
    const netF = state.netForce;
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px monospace'; ctx.textAlign = 'left';
    ctx.fillText(`F_net=${netF.toFixed(1)}N  a=${state.a.toFixed(2)}m/s²  v=${state.v.toFixed(2)}m/s`, 10, 22);

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
EOF

# ── 4. Newton's 3rd Law Canvas ────────────────────────────────────────────────
cat > src/components/simulation/NewtonsThirdCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback, useState } from 'react';

interface Props {
  mass1: number; mass2: number; force: number;
  scenario: 'push' | 'rocket' | 'collision';
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function NewtonsThirdCanvas({ mass1, mass2, force, scenario, isRunning, isPaused, width = 680, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const simRef = useRef({ mass1, mass2, force, scenario, isRunning, isPaused, width, height });
  simRef.current = { mass1, mass2, force, scenario, isRunning, isPaused, width, height };

  useEffect(() => { t.current = 0; }, [mass1, mass2, force, scenario]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass1: m1, mass2: m2, force: F, scenario: sc, isRunning: r, isPaused: p } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p) t.current += 0.016;

    const a1 = F / m1; // acceleration of object 1 (reaction)
    const a2 = F / m2; // acceleration of object 2 (action)

    ctx.clearRect(0, 0, W, H);

    const groundY = H - 50;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    const cx = W / 2;
    const dt = t.current;
    const BLOCK_H = 48;

    if (sc === 'push') {
      // Two people/objects pushing off each other from the centre
      const x1 = cx - 40 - 0.5 * a1 * dt * dt * 30;  // moves left
      const x2 = cx + 40 + 0.5 * a2 * dt * dt * 30;   // moves right
      const by = groundY - BLOCK_H;

      // Object 1 (left)
      ctx.fillStyle = '#6366f1'; ctx.beginPath();
      ctx.roundRect(x1 - 52, by, 52, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, x1 - 26, by + BLOCK_H / 2 + 4);

      // Object 2 (right)
      ctx.fillStyle = '#10b981'; ctx.beginPath();
      ctx.roundRect(x2, by, 52, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.textAlign = 'center';
      ctx.fillText(`${m2}kg`, x2 + 26, by + BLOCK_H / 2 + 4);

      // Force arrows
      const midY = by + BLOCK_H / 2;
      const fLen = Math.min(F * 1.5, 70);
      // Reaction on obj1 (leftward)
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x1 - 52, midY); ctx.lineTo(x1 - 52 - fLen, midY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(x1 - 52 - fLen, midY);
      ctx.lineTo(x1 - 52 - fLen + 9, midY - 5); ctx.lineTo(x1 - 52 - fLen + 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`−F=${F}N`, x1 - 52 - fLen / 2, midY - 10);

      // Action on obj2 (rightward)
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x2 + 52, midY); ctx.lineTo(x2 + 52 + fLen, midY); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x2 + 52 + fLen, midY);
      ctx.lineTo(x2 + 52 + fLen - 9, midY - 5); ctx.lineTo(x2 + 52 + fLen - 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`+F=${F}N`, x2 + 52 + fLen / 2, midY - 10);

      ctx.fillStyle = '#6366f1'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`a₁=${a1.toFixed(2)} m/s² ←`, x1 - 26, by - 8);
      ctx.fillStyle = '#10b981';
      ctx.fillText(`a₂=${a2.toFixed(2)} m/s² →`, x2 + 26, by - 8);
    }

    if (sc === 'rocket') {
      const rocketX = 80 + 0.5 * a2 * dt * dt * 40;
      const by = groundY - 60;
      // Rocket body
      ctx.fillStyle = '#6366f1';
      ctx.beginPath(); ctx.roundRect(rocketX, by, 70, 50, 8); ctx.fill();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(rocketX + 70, by + 25);
      ctx.lineTo(rocketX + 90, by + 10); ctx.lineTo(rocketX + 90, by + 40); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, rocketX + 35, by + 28);

      // Exhaust
      const exhaustLen = Math.min(F * 2, 100);
      const ey = by + 25;
      for (let i = 0; i < 5; i++) {
        const jitter = (Math.sin(t.current * 20 + i) * 6);
        ctx.fillStyle = `rgba(${200 + i * 10},${100 - i * 15},30,${0.8 - i * 0.12})`;
        ctx.beginPath();
        ctx.ellipse(rocketX - 10 - i * exhaustLen / 5, ey + jitter, exhaustLen / 5 * (1 - i * 0.15), 8 - i, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      // Thrust force arrow
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX, ey); ctx.lineTo(rocketX - 50, ey); ctx.stroke();
      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Thrust (reaction)`, rocketX - 25, ey - 10);
      // Rocket motion arrow
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX + 90, ey); ctx.lineTo(rocketX + 130, ey); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(rocketX + 130, ey);
      ctx.lineTo(rocketX + 120, ey - 5); ctx.lineTo(rocketX + 120, ey + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`Motion (action)`, rocketX + 110, ey - 12);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px monospace'; ctx.textAlign = 'left';
      ctx.fillText(`a=${a2.toFixed(2)} m/s²`, 10, 20);
    }

    if (sc === 'collision') {
      const B1W = 56, B2W = 56;
      const startGap = 240;
      const x1 = cx - startGap / 2 - B1W + Math.min(0.5 * a1 * dt * dt * 60, startGap / 2 - 4);
      const x2 = cx + startGap / 2 - Math.min(0.5 * a2 * dt * dt * 60, startGap / 2 - 4);
      const by = groundY - BLOCK_H;
      const midY = by + BLOCK_H / 2;

      ctx.fillStyle = '#6366f1'; ctx.beginPath(); ctx.roundRect(x1, by, B1W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, x1 + B1W / 2, by + BLOCK_H / 2 + 4);
      ctx.fillStyle = '#10b981'; ctx.beginPath(); ctx.roundRect(x2, by, B2W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.fillText(`${m2}kg`, x2 + B2W / 2, by + BLOCK_H / 2 + 4);

      // Force arrows
      const fLen = Math.min(F * 1.2, 60);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x1, midY); ctx.lineTo(x1 - fLen, midY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(x1 - fLen, midY);
      ctx.lineTo(x1 - fLen + 9, midY - 5); ctx.lineTo(x1 - fLen + 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`−F`, x1 - fLen / 2, midY - 10);

      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x2 + B2W, midY); ctx.lineTo(x2 + B2W + fLen, midY); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x2 + B2W + fLen, midY);
      ctx.lineTo(x2 + B2W + fLen - 9, midY - 5); ctx.lineTo(x2 + B2W + fLen - 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`+F`, x2 + B2W + fLen / 2, midY - 10);

      ctx.fillStyle = '#475569'; ctx.font = '10px monospace'; ctx.textAlign = 'center';
      ctx.fillText(`Equal and opposite forces — F₁₂ = −F₂₁ = ${F}N`, W / 2, groundY + 20);
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
EOF

# ── 5. Real-time graph ────────────────────────────────────────────────────────
cat > src/components/simulation/NewtonsGraph.tsx << 'EOF'
'use client';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label } from 'recharts';

interface DataPoint { t: number; v: number; a: number; x: number; }

interface Props {
  data: DataPoint[];
  show: 'v' | 'a' | 'x';
}

const CONFIG = {
  v: { color: '#6366f1', label: 'Velocity (m/s)', yLabel: 'v (m/s)' },
  a: { color: '#f59e0b', label: 'Acceleration (m/s²)', yLabel: 'a (m/s²)' },
  x: { color: '#10b981', label: 'Displacement (m)', yLabel: 'x (m)' },
};

export function NewtonsGraph({ data, show }: Props) {
  const cfg = CONFIG[show];
  return (
    <ResponsiveContainer width="100%" height={180}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={['dataMin', 'dataMax']}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={cfg.yLabel} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <Line type="monotone" dataKey={show} stroke={cfg.color} strokeWidth={2} dot={false} name={cfg.label} />
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

# ── 6. Main Newton's Laws page ────────────────────────────────────────────────
cat > src/app/simulations/newtons-laws/page.tsx << 'EOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { NewtonsFirstCanvas } from '@/components/simulation/NewtonsFirstCanvas';
import { NewtonsSecondCanvas } from '@/components/simulation/NewtonsSecondCanvas';
import { NewtonsThirdCanvas } from '@/components/simulation/NewtonsThirdCanvas';
import { NewtonsGraph } from '@/components/simulation/NewtonsGraph';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { secondLawAnalytics, thirdLawAnalytics, FirstLawState, SecondLawState } from '@/lib/physics/newtons-laws';

type Law = '1st' | '2nd' | '3rd';
type GraphType = 'v' | 'a' | 'x';
type Scenario3 = 'push' | 'rocket' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META = {
  '1st': { title: "Newton's 1st law", sub: 'Law of inertia', eq: 'ΣF = 0 → v = constant', color: '#6366f1' },
  '2nd': { title: "Newton's 2nd law", sub: 'Law of acceleration', eq: 'F = ma', color: '#10b981' },
  '3rd': { title: "Newton's 3rd law", sub: 'Law of action & reaction', eq: 'F₁₂ = −F₂₁', color: '#f59e0b' },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  '1st': [
    "An object stays at rest or moves at constant velocity unless a net external force acts on it.",
    "Inertia is the resistance to change in motion — heavier objects have more inertia.",
    "On a frictionless surface (μ=0), a moving block never stops. On Earth, friction provides the net force.",
    "Common misconception: students think a moving object needs a continuous force to keep moving. It doesn't — only to accelerate it.",
    "Demonstrate: set initial velocity, then toggle friction on/off mid-animation to show inertia.",
  ],
  '2nd': [
    "F = ma: net force equals mass times acceleration. Doubling force doubles acceleration; doubling mass halves it.",
    "Net force, not applied force, causes acceleration. Subtract friction: F_net = F_applied − μmg.",
    "The F-a relationship is linear — the graph of a vs F (constant m) is a straight line through the origin.",
    "Unit check: 1 Newton = 1 kg·m/s². If m=2kg and a=3m/s², F_net=6N.",
    "Show students: with enough friction, a block won't move even with applied force (static friction ≥ F_applied).",
  ],
  '3rd': [
    "For every action there is an equal and opposite reaction — the forces act on DIFFERENT objects.",
    "Common exam trap: students cancel action-reaction pairs. They can't — they act on different bodies.",
    "Rocket propulsion: hot gas is pushed backward (action), rocket is pushed forward (reaction).",
    "The forces are always equal in magnitude — but accelerations differ because masses differ (a = F/m).",
    "Walking: you push the ground backward (action), the ground pushes you forward (reaction).",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  '1st': [
    { q: "A 5kg block moves at 10 m/s on a frictionless surface. What net force is needed to maintain this speed?", a: "Zero — by Newton's 1st law, no net force is needed to maintain constant velocity. ΣF = 0." },
    { q: "A 10kg block is pushed at 4 m/s and then released on a surface with μ = 0.3. Find the deceleration. (g=10 m/s²)", a: "Friction = μmg = 0.3×10×10 = 30N. a = F/m = 30/10 = 3 m/s² deceleration." },
    { q: "Why do passengers lurch forward when a bus brakes suddenly?", a: "Passengers tend to continue moving at the bus's original speed (inertia) while the bus decelerates. The seat provides no forward force, so they lurch forward relative to the bus." },
  ],
  '2nd': [
    { q: "A 4kg block is pushed with 20N on a surface with μ = 0.25. Find the acceleration. (g=10 m/s²)", a: "Friction = 0.25×4×10 = 10N. F_net = 20−10 = 10N. a = 10/4 = 2.5 m/s²" },
    { q: "A force of 30N gives a 6kg object an acceleration of 4 m/s². Find the frictional force.", a: "F_net = ma = 6×4 = 24N. Friction = F_applied − F_net = 30−24 = 6N" },
    { q: "How long does it take a 3kg block to reach 12 m/s if pushed with 15N on a frictionless surface?", a: "a = F/m = 15/3 = 5 m/s². t = v/a = 12/5 = 2.4s" },
  ],
  '3rd': [
    { q: "A 70kg person stands on a 500kg boat and pushes the boat with 100N. Find both accelerations.", a: "Both experience 100N. Person: a=100/70=1.43 m/s² backward. Boat: a=100/500=0.2 m/s² forward." },
    { q: "A rocket of mass 2000kg expels gas producing 40,000N thrust. Find the rocket's acceleration.", a: "a = F/m = 40000/2000 = 20 m/s². (Ignoring gravity and changing mass for simplicity.)" },
    { q: "Why does a gun recoil when fired? Use Newton's 3rd Law.", a: "The gun exerts force on bullet (action, bullet moves forward). Bullet exerts equal and opposite force on gun (reaction, gun recoils backward). Forces equal, but gun's larger mass means smaller acceleration." },
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

export default function NewtonsLawsPage() {
  const [law, setLaw] = useState<Law>('1st');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [graphData, setGraphData] = useState<{ t: number; v: number; a: number; x: number }[]>([]);
  const [graphType, setGraphType] = useState<GraphType>('v');

  // 1st law params
  const [mass1, setMass1] = useState(5);
  const [friction1, setFriction1] = useState(0);
  const [initV, setInitV] = useState(5);
  const [forceOn, setForceOn] = useState(false);
  const [force1, setForce1] = useState(10);

  // 2nd law params
  const [mass2, setMass2] = useState(5);
  const [applied, setApplied] = useState(30);
  const [friction2, setFriction2] = useState(0.2);

  // 3rd law params
  const [mass3a, setMass3a] = useState(5);
  const [mass3b, setMass3b] = useState(10);
  const [force3, setForce3] = useState(20);
  const [scenario3, setScenario3] = useState<Scenario3>('push');

  const secAnalytics = secondLawAnalytics({ mass: mass2, appliedForce: applied, friction: friction2 });
  const thdAnalytics = thirdLawAnalytics({ type: scenario3, mass1: mass3a, mass2: mass3b, force: force3 });

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setGraphData([]);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [law, mass1, friction1, initV, force1, mass2, applied, friction2, mass3a, mass3b, force3, scenario3, reset]);

  const handle1stTick = useCallback((s: FirstLawState) => {
    setGraphData(d => [...d.slice(-120), { t: +s.time.toFixed(2), v: +s.v.toFixed(3), a: 0, x: +s.x.toFixed(3) }]);
  }, []);

  const handle2ndTick = useCallback((s: SecondLawState) => {
    setGraphData(d => [...d.slice(-120), { t: +s.time.toFixed(2), v: +s.v.toFixed(3), a: +s.a.toFixed(3), x: +s.x.toFixed(3) }]);
  }, []);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Newton's laws of motion</h1>
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

          {/* Law tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(['1st', '2nd', '3rd'] as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-4 py-2 rounded-lg text-xs font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {LAW_META[l].title}
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{LAW_META[law].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{LAW_META[law].eq}</span>
          </div>

          {/* Main layout */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Col 1: Canvas + controls + sliders */}
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {law === '1st' && (
                  <NewtonsFirstCanvas
                    key={resetKey} mass={mass1} friction={friction1}
                    initialVelocity={initV} forceOn={forceOn} appliedForce={force1}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle1stTick}
                    width={660} height={200}
                  />
                )}
                {law === '2nd' && (
                  <NewtonsSecondCanvas
                    key={resetKey} params={{ mass: mass2, appliedForce: applied, friction: friction2 }}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle2ndTick}
                    onComplete={() => { setIsComplete(true); setIsRunning(false); }}
                    width={660} height={220}
                  />
                )}
                {law === '3rd' && (
                  <NewtonsThirdCanvas
                    key={resetKey} mass1={mass3a} mass2={mass3b} force={force3}
                    scenario={scenario3} isRunning={isRunning} isPaused={isPaused}
                    width={660} height={220}
                  />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
              </div>

              {/* Graph (1st and 2nd law only) */}
              {law !== '3rd' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-3">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Live graph</p>
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg">
                      {(['v', 'a', 'x'] as GraphType[]).map(g => (
                        <button key={g} onClick={() => setGraphType(g)}
                          className={`px-3 py-1 rounded-md text-xs font-medium transition ${
                            graphType === g ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{g === 'v' ? 'Velocity' : g === 'a' ? 'Acceleration' : 'Displacement'}</button>
                      ))}
                    </div>
                  </div>
                  <NewtonsGraph data={graphData} show={graphType} />
                </div>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {law === '1st' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass1} min={1} max={20} step={0.5} set={setMass1} color="#6366f1" />
                    <Slider label="Initial velocity" unit="m/s" value={initV} min={0} max={20} step={0.5} set={setInitV} color="#f59e0b" />
                    <Slider label="Friction coefficient μ" unit="" value={friction1} min={0} max={0.8} step={0.01} set={setFriction1} color="#ef4444" note="0 = frictionless surface" />
                    <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                      <div>
                        <p className="text-xs font-medium text-gray-700">Applied force</p>
                        <p className="text-[10px] text-gray-400">Toggle to show Newton's 1st law</p>
                      </div>
                      <button onClick={() => setForceOn(f => !f)}
                        className={`relative w-11 h-6 rounded-full transition ${forceOn ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                        <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${forceOn ? 'translate-x-5' : ''}`} />
                      </button>
                    </div>
                    {forceOn && (
                      <Slider label="Force" unit="N" value={force1} min={1} max={50} step={1} set={setForce1} color="#10b981" />
                    )}
                  </>
                )}

                {law === '2nd' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass2} min={1} max={20} step={0.5} set={setMass2} color="#6366f1" />
                    <Slider label="Applied force" unit="N" value={applied} min={1} max={100} step={1} set={setApplied} color="#10b981" />
                    <Slider label="Friction coefficient μ" unit="" value={friction2} min={0} max={0.8} step={0.01} set={setFriction2} color="#ef4444" note="0 = frictionless" />
                  </>
                )}

                {law === '3rd' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['push', 'rocket', 'collision'] as Scenario3[]).map(s => (
                        <button key={s} onClick={() => setScenario3(s)}
                          className={`py-1.5 rounded-lg text-xs font-medium capitalize transition ${
                            scenario3 === s ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{s}</button>
                      ))}
                    </div>
                    <Slider label="Object 1 mass" unit="kg" value={mass3a} min={1} max={50} step={1} set={setMass3a} color="#6366f1" />
                    <Slider label="Object 2 mass" unit="kg" value={mass3b} min={1} max={50} step={1} set={setMass3b} color="#10b981" />
                    <Slider label="Interaction force" unit="N" value={force3} min={5} max={100} step={5} set={setForce3} color="#f59e0b" />
                  </>
                )}
              </div>
            </div>

            {/* Col 2: Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {law === '1st' && [
                    { l: 'Mass', v: `${mass1} kg`, c: 'text-indigo-600' },
                    { l: 'Initial velocity', v: `${initV} m/s`, c: 'text-amber-600' },
                    { l: 'Friction (μ)', v: friction1.toFixed(2), c: 'text-red-500' },
                    { l: 'Friction force', v: `${(friction1 * mass1 * 9.81).toFixed(1)} N`, c: 'text-red-400' },
                    { l: 'Net force', v: forceOn ? `${(force1 - friction1 * mass1 * 9.81).toFixed(1)} N` : `${(friction1 * mass1 * 9.81 * -1).toFixed(1)} N`, c: 'text-gray-700' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '2nd' && [
                    { l: 'Applied force', v: `${applied} N`, c: 'text-emerald-600' },
                    { l: 'Friction force', v: `${secAnalytics.frictionForce} N`, c: 'text-red-500' },
                    { l: 'Net force', v: `${secAnalytics.netForce} N`, c: 'text-indigo-600' },
                    { l: 'Acceleration', v: `${secAnalytics.acceleration} m/s²`, c: 'text-amber-600' },
                    { l: 'F = ma check', v: `${secAnalytics.netForce} = ${mass2}×${secAnalytics.acceleration}`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '3rd' && [
                    { l: 'Action force', v: `${force3} N`, c: 'text-emerald-600' },
                    { l: 'Reaction force', v: `−${force3} N`, c: 'text-red-500' },
                    { l: `a₁ (${mass3a}kg)`, v: `${thdAnalytics.a1.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: `a₂ (${mass3b}kg)`, v: `${thdAnalytics.a2.toFixed(2)} m/s²`, c: 'text-amber-600' },
                    { l: 'Force equal?', v: 'Yes — always', c: 'text-emerald-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Curriculum */}
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

            {/* Col 3: Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[law].map((ex, i) => (
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
EOF

# ── 7. Add to simulations hub ─────────────────────────────────────────────────
echo ""
echo "✅ Newton's Laws simulation complete!"
echo ""
echo "Files written:"
echo "  src/lib/physics/newtons-laws.ts"
echo "  src/components/simulation/NewtonsFirstCanvas.tsx"
echo "  src/components/simulation/NewtonsSecondCanvas.tsx"
echo "  src/components/simulation/NewtonsThirdCanvas.tsx"
echo "  src/components/simulation/NewtonsGraph.tsx"
echo "  src/app/simulations/newtons-laws/page.tsx"
echo ""
echo "Visit: http://localhost:3000/simulations/newtons-laws"
echo ""
echo "Also update /simulations/page.tsx:"
echo "  Change Newton's 2nd law href to '/simulations/newtons-laws'"
echo "  Change status from 'coming' to 'live'"
