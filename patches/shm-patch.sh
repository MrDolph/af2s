#!/bin/bash
# A-Factor STEM Studio — SHM & Oscillations
# Run inside af2s/: bash shm-patch.sh
set -e
echo "Building SHM & Oscillations simulation..."

mkdir -p src/lib/physics
mkdir -p src/components/simulation
mkdir -p src/app/simulations/oscillations

# ── 1. SHM Physics Engine ─────────────────────────────────────────────────────
cat > src/lib/physics/shm.ts << 'EOF'
export const g = 9.81;

// ── Core SHM equations ────────────────────────────────────────────────────────
// x(t) = A cos(ωt + φ)
// v(t) = -Aω sin(ωt + φ)
// a(t) = -Aω² cos(ωt + φ) = -ω²x

export function shmDisplacement(A: number, omega: number, t: number, phi = 0) {
  return A * Math.cos(omega * t + phi);
}
export function shmVelocity(A: number, omega: number, t: number, phi = 0) {
  return -A * omega * Math.sin(omega * t + phi);
}
export function shmAcceleration(A: number, omega: number, t: number, phi = 0) {
  return -A * omega * omega * Math.cos(omega * t + phi);
}
export function shmKE(m: number, v: number) { return 0.5 * m * v * v; }
export function shmPE(k: number, x: number) { return 0.5 * k * x * x; }
export function shmTE(m: number, A: number, omega: number) { return 0.5 * m * A * A * omega * omega; }

// ── Simple Pendulum ───────────────────────────────────────────────────────────
export function pendulumOmega(L: number, grav = g) { return Math.sqrt(grav / L); }
export function pendulumPeriod(L: number, grav = g) { return 2 * Math.PI * Math.sqrt(L / grav); }
export function pendulumAngle(A_rad: number, omega: number, t: number) {
  return A_rad * Math.cos(omega * t);
}

// ── Loaded Spring ─────────────────────────────────────────────────────────────
export function springOmega(k: number, m: number) { return Math.sqrt(k / m); }
export function springPeriod(k: number, m: number) { return 2 * Math.PI * Math.sqrt(m / k); }
export function springStaticExtension(m: number, k: number) { return (m * g) / k; }

// ── Conical Pendulum ──────────────────────────────────────────────────────────
export function conicalPendulumOmega(L: number, theta_rad: number) {
  // T cosθ = mg, T sinθ = mω²r, r = L sinθ → ω² = g/(L cosθ)
  return Math.sqrt(g / (L * Math.cos(theta_rad)));
}
export function conicalPendulumPeriod(L: number, theta_rad: number) {
  return 2 * Math.PI / conicalPendulumOmega(L, theta_rad);
}
export function conicalPendulumTension(m: number, theta_rad: number) {
  return (m * g) / Math.cos(theta_rad);
}
export function conicalPendulumRadius(L: number, theta_rad: number) {
  return L * Math.sin(theta_rad);
}
export function conicalPendulumSpeed(L: number, theta_rad: number) {
  const r = conicalPendulumRadius(L, theta_rad);
  const omega = conicalPendulumOmega(L, theta_rad);
  return r * omega;
}

// ── Physical Pendulum ─────────────────────────────────────────────────────────
// T = 2π√(I/mgd) where I = moment of inertia about pivot, d = distance pivot to CoM
export function physicalPendulumPeriod(I: number, m: number, d: number) {
  return 2 * Math.PI * Math.sqrt(I / (m * g * d));
}
// Uniform rod pivoted at one end: I = mL²/3, d = L/2
export function rodPendulumPeriod(L: number) {
  const I = (1 / 3) * 1 * L * L; // m=1 for ratio
  return 2 * Math.PI * Math.sqrt(I / (1 * g * L / 2));
}
// Equivalent simple pendulum length: L_eq = I/(md)
export function equivalentLength(I: number, m: number, d: number) {
  return I / (m * d);
}

// ── Bifilar Suspension ────────────────────────────────────────────────────────
// T = 2π × (l/d) × √(2I/mg) where l=wire length, d=half-separation, I=moment about vertical axis
// For uniform rod: I = mL²/12
export function bifilarPeriod(l: number, d: number, m: number, I: number) {
  return (2 * Math.PI * l / d) * Math.sqrt(I / (m * g * l));
  // simplified: T = 2π√(Il/(mgd²))  → T = (2π/d)√(Il/(mg))
}
export function bifilarPeriodSimple(m: number, L_rod: number, l_wire: number, d_sep: number) {
  const I = m * L_rod * L_rod / 12;
  return 2 * Math.PI * Math.sqrt(I * l_wire / (m * g * d_sep * d_sep));
}

// ── Cantilever ────────────────────────────────────────────────────────────────
// Deflection: y = WL³/(3EI) where E=Young's modulus, I=second moment of area
// For rectangular beam: I_beam = bh³/12
// Period of vibration: T = 2π√(m_eff/k_beam), k_beam = 3EI/L³
export function cantileverStiffness(E: number, b: number, h: number, L: number) {
  const I_beam = (b * h * h * h) / 12;
  return (3 * E * I_beam) / (L * L * L);
}
export function cantileverDeflection(W: number, E: number, b: number, h: number, L: number) {
  return W / cantileverStiffness(E, b, h, L);
}
export function cantileverPeriod(m: number, E: number, b: number, h: number, L: number) {
  const k = cantileverStiffness(E, b, h, L);
  return 2 * Math.PI * Math.sqrt(m / k);
}

// ── Generate SHM graph data ───────────────────────────────────────────────────
export function generateSHMData(
  A: number, omega: number, m: number, k: number,
  cycles = 3, points = 200
) {
  const T = (2 * Math.PI) / omega;
  const totalTime = cycles * T;
  return Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * totalTime;
    const x = shmDisplacement(A, omega, t);
    const v = shmVelocity(A, omega, t);
    const a = shmAcceleration(A, omega, t);
    const ke = shmKE(m, v);
    const pe = shmPE(k, x);
    return { t: +t.toFixed(3), x: +x.toFixed(4), v: +v.toFixed(4), a: +a.toFixed(4), ke: +ke.toFixed(4), pe: +pe.toFixed(4), te: +(ke + pe).toFixed(4) };
  });
}
EOF

# ── 2. SHM Graph ──────────────────────────────────────────────────────────────
cat > src/components/simulation/SHMGraph.tsx << 'EOF'
'use client';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label, ReferenceLine } from 'recharts';
import { generateSHMData } from '@/lib/physics/shm';

type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

interface Props {
  A: number; omega: number; m: number; k: number;
  mode: GraphMode; currentT?: number;
}

export function SHMGraph({ A, omega, m, k, mode, currentT = 0 }: Props) {
  const data = generateSHMData(A, omega, m, k);

  if (mode === 'phase') {
    // Phase space: v vs x
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={[-A * 1.1, A * 1.1]}>
            <Label value="Displacement x (m)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Velocity v (m/s)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
          <Line type="monotone" dataKey="v" stroke="#6366f1" strokeWidth={2} dot={false} />
          <ReferenceLine x={0} stroke="#e2e8f0" />
          <ReferenceLine y={0} stroke="#e2e8f0" />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (mode === 'energy') {
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
            <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Energy (J)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4), '']} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
          <Legend wrapperStyle={{ fontSize: 10 }} />
          <Line type="monotone" dataKey="ke" stroke="#f59e0b" strokeWidth={2} dot={false} name="KE" />
          <Line type="monotone" dataKey="pe" stroke="#6366f1" strokeWidth={2} dot={false} name="PE" />
          <Line type="monotone" dataKey="te" stroke="#10b981" strokeWidth={1.5} dot={false} strokeDasharray="5 3" name="Total E" />
          {currentT > 0 && <ReferenceLine x={currentT} stroke="#ef4444" strokeDasharray="3 3" />}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  const keyMap = { displacement: 'x', velocity: 'v', acceleration: 'a' };
  const colorMap = { displacement: '#6366f1', velocity: '#10b981', acceleration: '#f59e0b' };
  const labelMap = { displacement: 'Displacement (m)', velocity: 'Velocity (m/s)', acceleration: 'Acceleration (m/s²)' };
  const dataKey = keyMap[mode as keyof typeof keyMap];
  const color = colorMap[mode as keyof typeof colorMap];

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={labelMap[mode as keyof typeof labelMap]} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} dot={false} />
        {currentT > 0 && <ReferenceLine x={currentT} stroke="#ef4444" strokeDasharray="3 3" />}
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

# ── 3. Simple Pendulum Canvas ─────────────────────────────────────────────────
cat > src/components/simulation/PendulumCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { pendulumOmega, pendulumAngle } from '@/lib/physics/shm';

interface Props {
  length: number; amplitude: number; gravity: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

export function PendulumCanvas({ length, amplitude, gravity, mass, isRunning, isPaused, onTick, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const trailRef = useRef<[number, number][]>([]);
  const sim = useRef({ length, amplitude, gravity, mass, isRunning, isPaused, onTick });
  sim.current = { length, amplitude, gravity, mass, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; trailRef.current = []; }, [length, amplitude, gravity, mass]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, amplitude: A_deg, gravity: grav, mass: m, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const A_rad = A_deg * Math.PI / 180;
    const omega = pendulumOmega(L, grav);

    if (r && !p) { tRef.current += 0.016; }

    const theta = pendulumAngle(A_rad, omega, tRef.current);
    const pivotX = W / 2, pivotY = 40;
    const scale = Math.min((H - 80) / L, 280);
    const bobX = pivotX + Math.sin(theta) * L * scale;
    const bobY = pivotY + Math.cos(theta) * L * scale;
    const v = -A_rad * omega * Math.sin(omega * tRef.current);
    ot?.(tRef.current, theta, v);

    // Trail
    trailRef.current.push([bobX, bobY]);
    if (trailRef.current.length > 80) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);

    // Background
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling mount
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);
    ctx.fillStyle = '#94a3b8';
    ctx.beginPath(); ctx.arc(pivotX, 12, 6, 0, Math.PI * 2); ctx.fill();

    // Trail
    if (trailRef.current.length > 1) {
      ctx.save();
      for (let i = 1; i < trailRef.current.length; i++) {
        const alpha = i / trailRef.current.length;
        ctx.beginPath();
        ctx.moveTo(trailRef.current[i-1][0], trailRef.current[i-1][1]);
        ctx.lineTo(trailRef.current[i][0], trailRef.current[i][1]);
        ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.5})`;
        ctx.lineWidth = 1.5; ctx.stroke();
      }
      ctx.restore();
    }

    // String
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Bob shadow
    ctx.beginPath(); ctx.ellipse(bobX + 3, bobY + 3, 14, 5, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // Bob
    const bobR = Math.max(8, Math.min(m * 3, 18));
    const bobG = ctx.createRadialGradient(bobX - 3, bobY - 3, 1, bobX, bobY, bobR);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, bobR, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vScale = Math.min(Math.abs(v) * 30, 50);
      const vx = Math.cos(theta) * Math.sign(v) * vScale;
      const vy = -Math.sin(theta) * Math.sign(v) * vScale;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX + vx, bobY + vy); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      const angle = Math.atan2(vy, vx);
      ctx.beginPath(); ctx.moveTo(bobX + vx, bobY + vy);
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle - 0.4), bobY + vy - 7 * Math.sin(angle - 0.4));
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle + 0.4), bobY + vy - 7 * Math.sin(angle + 0.4));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(pivotX, pivotY + L * scale);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Labels
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`L=${L}m  A=${A_deg}°  T=${(2*Math.PI/omega).toFixed(2)}s`, 8, H - 8);
    ctx.fillText(`θ=${(theta * 180 / Math.PI).toFixed(1)}°`, 8, H - 22);

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

# ── 4. Spring Canvas ──────────────────────────────────────────────────────────
cat > src/components/simulation/SpringCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { springOmega, shmDisplacement, shmVelocity, springStaticExtension } from '@/lib/physics/shm';

interface Props {
  k: number; mass: number; amplitude: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

function drawSpring(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, coils = 10) {
  const coilW = 18;
  const segH = (y2 - y1) / (coils * 2 + 2);
  ctx.beginPath();
  ctx.moveTo(x, y1);
  ctx.lineTo(x, y1 + segH);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + coilW, y1 + segH + (2 * i + 1) * segH);
    ctx.lineTo(x - coilW, y1 + segH + (2 * i + 2) * segH);
  }
  ctx.lineTo(x, y2 - segH);
  ctx.lineTo(x, y2);
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();
}

export function SpringCanvas({ k, mass, amplitude, isRunning, isPaused, onTick, width = 280, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const trailRef = useRef<number[]>([]);
  const sim = useRef({ k, mass, amplitude, isRunning, isPaused, onTick });
  sim.current = { k, mass, amplitude, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; trailRef.current = []; }, [k, mass, amplitude]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { k: K, mass: m, amplitude: A, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const omega = springOmega(K, m);
    const staticExt = springStaticExtension(m, K);

    if (r && !p) tRef.current += 0.016;

    const x = shmDisplacement(A, omega, tRef.current); // displacement from equilibrium
    const v = shmVelocity(A, omega, tRef.current);
    ot?.(tRef.current, x, v);

    trailRef.current.push(x);
    if (trailRef.current.length > 60) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cx = W / 2;
    const ceilingY = 20;
    const equilY = H / 2 + 20;
    const scale = 100; // px per metre

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);

    // Spring
    const springBottom = equilY + x * scale;
    drawSpring(ctx, cx, ceilingY + 12, springBottom - 30);

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx - 50, equilY); ctx.lineTo(cx + 50, equilY);
    ctx.strokeStyle = 'rgba(99,102,241,0.35)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('equilibrium', cx + 36, equilY + 4);

    // Mass block
    const blockW = 60, blockH = 44;
    const bx = cx - blockW / 2;
    const by = springBottom - 20;
    const bg = ctx.createLinearGradient(bx, by, bx, by + blockH);
    bg.addColorStop(0, '#818cf8'); bg.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${m}kg`, cx, by + blockH / 2 + 4);

    // Displacement arrow
    if (Math.abs(x) > 0.005) {
      const arrowX = cx + blockW / 2 + 16;
      const startY = equilY;
      const endY = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(arrowX, startY); ctx.lineTo(arrowX, endY); ctx.stroke();
      const dir = Math.sign(x);
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(arrowX, endY);
      ctx.lineTo(arrowX - 4, endY - dir * 8); ctx.lineTo(arrowX + 4, endY - dir * 8);
      ctx.closePath(); ctx.fill();
      ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`x=${x.toFixed(3)}m`, arrowX + 6, (startY + endY) / 2);
      ctx.restore();
    }

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vLen = Math.min(Math.abs(v) * 40, 50);
      const dir = Math.sign(v);
      const vy1 = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1);
      ctx.lineTo(cx - blockW / 2 - 14, vy1 + dir * vLen); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1 + dir * vLen);
      ctx.lineTo(cx - blockW / 2 - 20, vy1 + dir * (vLen - 8));
      ctx.lineTo(cx - blockW / 2 - 8, vy1 + dir * (vLen - 8));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`k=${K} N/m  T=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

    // Mini trail (right side waveform)
    if (trailRef.current.length > 2) {
      ctx.save();
      const trailX = W - 35;
      const trailScale = 25;
      ctx.strokeStyle = 'rgba(99,102,241,0.6)'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      trailRef.current.forEach((tx, i) => {
        const ty = equilY + tx * trailScale;
        const px = trailX - (trailRef.current.length - 1 - i) * 0.5;
        if (i === 0) ctx.moveTo(px, ty); else ctx.lineTo(px, ty);
      });
      ctx.stroke();
      ctx.restore();
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

# ── 5. Conical Pendulum Canvas ────────────────────────────────────────────────
cat > src/components/simulation/ConicalPendulumCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { conicalPendulumOmega, conicalPendulumRadius, conicalPendulumTension } from '@/lib/physics/shm';

interface Props {
  length: number; theta_deg: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function ConicalPendulumCanvas({ length, theta_deg, mass, isRunning, isPaused, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const phiRef = useRef(0);
  const sim = useRef({ length, theta_deg, mass, isRunning, isPaused });
  sim.current = { length, theta_deg, mass, isRunning, isPaused };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, theta_deg: th, mass: m, isRunning: r, isPaused: p } = sim.current;
    const W = canvas.width, H = canvas.height;
    const theta = th * Math.PI / 180;
    const omega = conicalPendulumOmega(L, theta);
    const r_circ = conicalPendulumRadius(L, theta);
    const T = conicalPendulumTension(m, theta);

    if (r && !p) phiRef.current += omega * 0.016;

    const cx = W / 2, cy = 50;
    const scale = Math.min((H - 100) / L, 200);
    const vertLen = L * Math.cos(theta) * scale;
    const bobX = cx + r_circ * scale * Math.cos(phiRef.current);
    const bobY = cy + vertLen;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);
    ctx.fillStyle = '#94a3b8'; ctx.beginPath(); ctx.arc(cx, 12, 5, 0, Math.PI * 2); ctx.fill();

    // Orbit circle (ellipse for perspective)
    ctx.save();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.ellipse(cx, bobY, r_circ * scale, r_circ * scale * 0.25, 0, 0, Math.PI * 2);
    ctx.stroke(); ctx.setLineDash([]); ctx.restore();

    // Shadow on orbit
    const shadowX = cx + r_circ * scale * Math.cos(phiRef.current);
    ctx.beginPath(); ctx.ellipse(shadowX, bobY + 4, 10, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // String
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Vertical dashed line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(cx, bobY + 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Angle arc
    ctx.beginPath();
    ctx.arc(cx, 12, 28, Math.PI / 2, Math.PI / 2 + theta);
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`θ=${th}°`, cx + 6, 12 + 38);

    // Bob
    const bobG = ctx.createRadialGradient(bobX - 2, bobY - 2, 1, bobX, bobY, 12);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, 12, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Force vectors (from bob)
    // Tension component (along string, upward-inward)
    const Tscale = Math.min(T * 8, 55);
    const Tx = cx - bobX; const Ty = cy + 12 - bobY;
    const Tmag = Math.sqrt(Tx * Tx + Ty * Ty);
    ctx.save();
    ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY);
    ctx.lineTo(bobX + Tx / Tmag * Tscale, bobY + Ty / Tmag * Tscale); ctx.stroke();
    ctx.fillStyle = '#10b981'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`T=${T.toFixed(1)}N`, bobX + Tx / Tmag * Tscale * 0.6, bobY + Ty / Tmag * Tscale * 0.6 - 6);
    ctx.restore();

    // Weight (downward)
    const W_n = m * 9.81;
    const Wscale = Math.min(W_n * 8, 45);
    ctx.save();
    ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX, bobY + Wscale); ctx.stroke();
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.moveTo(bobX, bobY + Wscale);
    ctx.lineTo(bobX - 4, bobY + Wscale - 7); ctx.lineTo(bobX + 4, bobY + Wscale - 7);
    ctx.closePath(); ctx.fill();
    ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`mg=${W_n.toFixed(1)}N`, bobX + 6, bobY + Wscale / 2);
    ctx.restore();

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`r=${r_circ.toFixed(2)}m  T_period=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

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

# ── 6. Physical Pendulum Canvas ───────────────────────────────────────────────
cat > src/components/simulation/PhysicalPendulumCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { physicalPendulumPeriod, pendulumPeriod } from '@/lib/physics/shm';

interface Props {
  length: number; mass: number; pivotFraction: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function PhysicalPendulumCanvas({ length, mass, pivotFraction, isRunning, isPaused, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const sim = useRef({ length, mass, pivotFraction, isRunning, isPaused });
  sim.current = { length, mass, pivotFraction, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; }, [length, mass, pivotFraction]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, mass: m, pivotFraction: pf, isRunning: r, isPaused: p } = sim.current;
    const W = canvas.width, H = canvas.height;

    // Pivot at fraction pf along rod from top
    const d = L * (0.5 - pf) + L * pf; // distance from pivot to CoM
    const dFromTop = pf * L; // pivot position from top of rod
    const dToCoM = L / 2 - dFromTop; // pivot to CoM (positive = CoM below pivot)
    const d_actual = Math.abs(dToCoM) < 0.001 ? 0.001 : Math.abs(dToCoM);
    // I about pivot = mL²/12 + m*d²
    const I_cm = m * L * L / 12;
    const I_pivot = I_cm + m * d_actual * d_actual;
    const T_phys = physicalPendulumPeriod(I_pivot, m, d_actual);
    const T_simple = pendulumPeriod(L);
    const omega_phys = 2 * Math.PI / T_phys;

    if (r && !p) tRef.current += 0.016;

    const A_rad = 0.25; // fixed amplitude
    const theta = A_rad * Math.cos(omega_phys * tRef.current);

    const pivotX = W / 2, pivotY = 60;
    const scale = Math.min((H - 100) / L, 180);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);

    // Rod (rotated)
    const rodTopX = pivotX - Math.sin(theta) * dFromTop * scale;
    const rodTopY = pivotY - Math.cos(theta) * dFromTop * scale;
    const rodBotX = pivotX + Math.sin(theta) * (L - dFromTop) * scale;
    const rodBotY = pivotY + Math.cos(theta) * (L - dFromTop) * scale;

    ctx.save();
    // Rod body
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 12;
    ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(rodTopX, rodTopY); ctx.lineTo(rodBotX, rodBotY); ctx.stroke();
    // CoM dot
    const comX = pivotX + Math.sin(theta) * dToCoM * scale;
    const comY = pivotY + Math.cos(theta) * dToCoM * scale;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(comX, comY, 5, 0, Math.PI * 2); ctx.fill();
    // Pivot point
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'white';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 3, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY - 10); ctx.lineTo(pivotX, H - 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Legend
    ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('● Centre of mass', 8, H - 36);
    ctx.fillStyle = '#ef4444'; ctx.fillText('● Pivot point', 8, H - 24);
    ctx.fillStyle = '#64748b';
    ctx.fillText(`T_physical=${T_phys.toFixed(3)}s  T_simple=${T_simple.toFixed(3)}s`, 8, H - 8);

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

# ── 7. Bifilar/Cantilever Canvas ──────────────────────────────────────────────
cat > src/components/simulation/BifilarCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { bifilarPeriodSimple, cantileverStiffness } from '@/lib/physics/shm';

type Mode = 'bifilar' | 'cantilever';

interface Props {
  mode: Mode; mass: number; rodLength: number;
  wireLength: number; separation: number;
  beamLength: number; beamWidth: number; beamHeight: number;
  youngModulus: number; load: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function BifilarCanvas({
  mode, mass, rodLength, wireLength, separation,
  beamLength, beamWidth, beamHeight, youngModulus, load,
  isRunning, isPaused, width = 380, height = 300
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const sim = useRef({ mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused });
  sim.current = { mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; }, [mode, mass, rodLength, wireLength, separation, beamLength, beamHeight, youngModulus, load]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused) tRef.current += 0.016;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'bifilar') {
      const T = bifilarPeriodSimple(s.mass, s.rodLength, s.wireLength, s.separation / 2);
      const omega = 2 * Math.PI / T;
      const phi = 0.3 * Math.sin(omega * tRef.current); // torsion angle

      const cx = W / 2, ceilY = 20;
      const rodY = ceilY + s.wireLength * 80;
      const rodHalfL = s.rodLength * 60;

      // Ceiling
      ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 60, 0, 120, 12);

      // Wires (twisted perspective)
      const w1x = cx - s.separation * 40 * Math.cos(phi);
      const w2x = cx + s.separation * 40 * Math.cos(phi);
      const rodLeft  = cx - rodHalfL * Math.cos(phi);
      const rodRight = cx + rodHalfL * Math.cos(phi);

      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(cx - s.separation * 40, ceilY + 12); ctx.lineTo(rodLeft, rodY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx + s.separation * 40, ceilY + 12); ctx.lineTo(rodRight, rodY); ctx.stroke();

      // Attachment points on ceiling
      ctx.fillStyle = '#475569';
      ctx.beginPath(); ctx.arc(cx - s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx + s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();

      // Rod (rotating)
      const rodThick = 10;
      ctx.save();
      ctx.fillStyle = '#4f46e5';
      ctx.beginPath();
      ctx.moveTo(rodLeft, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY + rodThick / 2);
      ctx.lineTo(rodLeft, rodY + rodThick / 2);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      // Mass label
      ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, cx, rodY + 4);
      ctx.restore();

      // Angle indicator
      ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`φ=${(phi * 180 / Math.PI).toFixed(1)}°`, cx, rodY + 30);
      ctx.fillStyle = '#64748b';
      ctx.fillText(`T=${T.toFixed(3)}s  I=mL²/12=${(s.mass * s.rodLength ** 2 / 12).toFixed(3)} kg·m²`, cx, H - 8);

    } else {
      // Cantilever
      const k = cantileverStiffness(s.youngModulus * 1e9, s.beamWidth / 100, s.beamHeight / 100, s.beamLength);
      const deflection = s.load / k; // metres
      const dispPx = Math.min(deflection * 2000, 80); // pixels
      const omega_c = Math.sqrt(k / s.mass);

      // Static + dynamic deflection
      const dynamicPx = s.isRunning ? dispPx + 0.3 * dispPx * Math.sin(omega_c * tRef.current) : dispPx;

      const wallX = 40, beamY = H / 2 - 10;
      const beamLenPx = W - 100;
      const beamThPx = Math.max(8, s.beamHeight * 8);

      // Wall
      ctx.fillStyle = '#94a3b8';
      ctx.fillRect(0, beamY - 40, wallX, 80);
      for (let y = beamY - 40; y < beamY + 40; y += 10) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(wallX - 5, y + 5); ctx.stroke();
      }

      // Beam (slightly curved for deflection)
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(wallX, beamY);
      const tipX = wallX + beamLenPx;
      const tipY = beamY + dynamicPx;
      // Cubic Bezier for beam deflection shape
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.6, beamY,
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7,
        tipX, tipY
      );
      ctx.lineTo(tipX, tipY + beamThPx);
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7 + beamThPx,
        wallX + beamLenPx * 0.6, beamY + beamThPx,
        wallX, beamY + beamThPx
      );
      ctx.closePath();
      const beamGrad = ctx.createLinearGradient(0, beamY, 0, beamY + beamThPx);
      beamGrad.addColorStop(0, '#818cf8'); beamGrad.addColorStop(1, '#4f46e5');
      ctx.fillStyle = beamGrad; ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      ctx.restore();

      // Load (hanging weight)
      if (s.load > 0) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(tipX, tipY + beamThPx); ctx.lineTo(tipX, tipY + beamThPx + 25); ctx.stroke();
        ctx.fillStyle = '#ef4444';
        ctx.beginPath(); ctx.roundRect(tipX - 20, tipY + beamThPx + 25, 40, 28, 4); ctx.fill();
        ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load}N`, tipX, tipY + beamThPx + 42);
      }

      // Deflection arrow
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(tipX + 18, beamY); ctx.lineTo(tipX + 18, tipY); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`δ=${deflection.toFixed(4)}m`, tipX + 22, (beamY + tipY) / 2 + 4);

      // Fixed end label
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Fixed end', wallX / 2, beamY - 50);
      ctx.fillText(`k=${k.toFixed(0)} N/m  T=${(2*Math.PI/omega_c).toFixed(3)}s`, W / 2, H - 8);
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

# ── 8. Main Oscillations page ─────────────────────────────────────────────────
cat > src/app/simulations/oscillations/page.tsx << 'EOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { BifilarCanvas } from '@/components/simulation/BifilarCanvas';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import {
  pendulumOmega, pendulumPeriod,
  springOmega, springPeriod, springStaticExtension,
  conicalPendulumOmega, conicalPendulumPeriod, conicalPendulumTension, conicalPendulumSpeed,
  physicalPendulumPeriod, rodPendulumPeriod,
  bifilarPeriodSimple, cantileverStiffness, cantileverDeflection, cantileverPeriod,
  generateSHMData,
} from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical' | 'bifilar';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  pendulum: { title: 'Simple pendulum',       icon: '⏱️', sub: 'SHM for small angles', eq: 'T = 2π√(L/g)' },
  spring:   { title: 'Loaded spring',         icon: '🌀', sub: 'Mass-spring system',    eq: 'T = 2π√(m/k)' },
  conical:  { title: 'Conical pendulum',      icon: '🔄', sub: 'Circular motion + tension', eq: 'ω² = g/(L cosθ)' },
  physical: { title: 'Physical pendulum',     icon: '📏', sub: 'Extended rigid body',   eq: 'T = 2π√(I/mgd)' },
  bifilar:  { title: 'Bifilar / Cantilever',  icon: '🏗️', sub: 'Torsion & beam flexure', eq: 'T = 2π√(Il/mgd²)' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  pendulum: [
    "Period T = 2π√(L/g) is INDEPENDENT of mass and amplitude (for small angles < 15°).",
    "This independence of mass is why a pendulum makes a good clock — it keeps time regardless of the bob.",
    "For large amplitudes, the period increases — the small-angle approximation (sinθ ≈ θ) breaks down.",
    "On the Moon (g=1.6 m/s²), the same pendulum runs ~2.5× slower. The gravity slider demonstrates this.",
    "A seconds pendulum (T=2s) has length L = g/π² ≈ 0.993m — almost exactly 1 metre.",
  ],
  spring: [
    "T = 2π√(m/k): period increases with mass, decreases with spring stiffness. Mass affects it; length does not.",
    "The static extension x₀ = mg/k gives the equilibrium position. SHM occurs about this point.",
    "Hooke's Law F = kx and SHM are directly linked: F = −kx gives a = −(k/m)x → ω² = k/m.",
    "Energy: at equilibrium (x=0) all energy is KE. At amplitude (x=A) all energy is PE. Total E = ½mω²A² always.",
    "The phase space graph (v vs x) is an ellipse — a perfect circle if axes are scaled to same range.",
  ],
  conical: [
    "The bob moves in a horizontal circle — this is NOT SHM, but links circular motion to pendulums.",
    "Key equations: T cosθ = mg (vertical), T sinθ = mω²r (horizontal). Dividing: tanθ = ω²r/g.",
    "As ω increases, θ increases (bob rises). As θ → 90°, r → L and ω → ∞ (impossible in practice).",
    "Period decreases as angle increases: T = 2π√(L cosθ / g). Faster spin = shorter period.",
    "Good link to centripetal force: the horizontal component of tension provides centripetal force.",
  ],
  physical: [
    "A physical pendulum uses the full rigid-body rotation: T = 2π√(I/mgd) where I is about the pivot.",
    "For a uniform rod pivoted at the end: I = mL²/3, d = L/2 → T = 2π√(2L/3g). Compare to simple T = 2π√(L/g).",
    "The physical pendulum always has a longer period than the simple pendulum of the same length.",
    "There are two pivot points that give the same period — the 'centre of oscillation' concept used in precision timing.",
    "The equivalent simple pendulum length L_eq = I/(md). This is what IGCSE/JUPEB exam questions test.",
  ],
  bifilar: [
    "Bifilar suspension: a rod hung by two parallel wires undergoes TORSIONAL oscillation (twisting).",
    "T = (2π/d)√(Il/mg) where d = half wire separation, l = wire length, I = moment of inertia.",
    "Used to measure moment of inertia experimentally: measure T, know l and d, solve for I.",
    "Cantilever beam: one end fixed, free end deflects under load. Stiffness k = 3EI/L³.",
    "Cantilever vibration period T = 2π√(m_eff/k). The effective mass ≈ 0.24 × beam mass + tip mass.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  pendulum: [
    { q: "A pendulum has period 2s on Earth (g=9.81 m/s²). Find its length.", a: "T=2π√(L/g) → L=g(T/2π)²=9.81×(2/2π)²=9.81×0.1013=0.993m ≈ 1m" },
    { q: "A 2m pendulum is taken to a planet where g=4 m/s². Find the new period.", a: "T=2π√(L/g)=2π√(2/4)=2π×0.707=4.44s" },
    { q: "Why does doubling the mass of a pendulum bob not change its period?", a: "Both restoring force and inertia scale with mass, so they cancel in the period equation T=2π√(L/g) — mass doesn't appear." },
  ],
  spring: [
    { q: "A 0.5kg mass on a spring of k=200 N/m. Find period and frequency.", a: "T=2π√(m/k)=2π√(0.5/200)=2π×0.05=0.314s. f=1/T=3.18Hz" },
    { q: "A spring extends 0.05m under a 2kg load (g=10 m/s²). Find k and the SHM period.", a: "k=F/x=mg/x=20/0.05=400 N/m. T=2π√(2/400)=2π×0.0707=0.444s" },
    { q: "A spring-mass system has total energy 0.4J and amplitude 0.1m. Find the spring constant k.", a: "E=½kA² → k=2E/A²=2×0.4/0.01=80 N/m" },
  ],
  conical: [
    { q: "A conical pendulum of length 0.5m makes angle 30° with vertical. Find ω and period. (g=10)", a: "ω=√(g/Lcosθ)=√(10/0.5×cos30°)=√(10/0.433)=√23.1=4.81 rad/s. T=2π/ω=1.31s" },
    { q: "Find the tension in the string of a 0.2kg bob at θ=45°. (g=10)", a: "T=mg/cosθ=0.2×10/cos45°=2/0.707=2.83N" },
    { q: "As the angular velocity of a conical pendulum increases, what happens to the angle θ?", a: "θ increases — the bob rises outward. Since ω²=g/(Lcosθ), larger ω requires smaller cosθ, meaning larger θ." },
  ],
  physical: [
    { q: "A uniform rod of length 1.2m and mass 0.5kg is pivoted at one end. Find the period. (g=9.81)", a: "I=mL²/3=0.5×1.44/3=0.24 kg·m². d=L/2=0.6m. T=2π√(I/mgd)=2π√(0.24/0.5×9.81×0.6)=2π×0.285=1.79s" },
    { q: "Compare this to a simple pendulum of the same length.", a: "T_simple=2π√(1.2/9.81)=2π×0.350=2.20s. The physical pendulum (1.79s) is FASTER — its effective length is 2L/3=0.8m, shorter than L." },
    { q: "What is the equivalent simple pendulum length for a uniform rod pivoted at one end?", a: "L_eq=I/(md)=(mL²/3)/(m×L/2)=2L/3. For L=1.2m: L_eq=0.8m." },
  ],
  bifilar: [
    { q: "A 2kg rod (L=0.6m) hangs on wires of length 1m, separation 0.4m. Find the period.", a: "I=mL²/12=2×0.36/12=0.06 kg·m². T=2π√(Il/mgd²)=2π√(0.06×1/2×9.81×0.04)=2π√(0.0765)=2π×0.277=1.74s" },
    { q: "A cantilever beam: E=200GPa, b=30mm, h=5mm, L=0.5m. Find stiffness k.", a: "I_beam=bh³/12=0.03×(0.005)³/12=3.125×10⁻¹⁰m⁴. k=3EI/L³=3×200×10⁹×3.125×10⁻¹⁰/0.125=1500 N/m" },
    { q: "Why is bifilar suspension used to measure moment of inertia experimentally?", a: "The period T=(2π/d)√(Il/mg) can be rearranged to I=mgd²T²/(4π²l). By measuring T and knowing all other quantities, I is found without needing to integrate over the shape." },
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

export default function OscillationsPage() {
  const [topic, setTopic] = useState<Topic>('pendulum');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);
  const [graphMode, setGraphMode] = useState<GraphMode>('displacement');
  const [currentT, setCurrentT] = useState(0);

  // Pendulum params
  const [pendL, setPendL] = useState(1.0);
  const [pendA, setPendA] = useState(15);
  const [pendG, setPendG] = useState(9.81);
  const [pendM, setPendM] = useState(0.5);

  // Spring params
  const [spK, setSpK] = useState(50);
  const [spM, setSpM] = useState(1.0);
  const [spA, setSpA] = useState(0.1);

  // Conical params
  const [conL, setConL] = useState(0.8);
  const [conTheta, setConTheta] = useState(30);
  const [conM, setConM] = useState(0.3);

  // Physical pendulum params
  const [physL, setPhysL] = useState(1.0);
  const [physM, setPhysM] = useState(0.5);
  const [physPF, setPhysPF] = useState(0); // pivot fraction from top (0=top end, 0.5=centre)

  // Bifilar/Cantilever params
  const [bifMode, setBifMode] = useState<'bifilar' | 'cantilever'>('bifilar');
  const [bifM, setBifM] = useState(2);
  const [bifL, setBifL] = useState(0.6);
  const [bifWire, setBifWire] = useState(1.0);
  const [bifSep, setBifSep] = useState(0.3);
  const [cantL, setCantL] = useState(0.5);
  const [cantH, setCantH] = useState(10); // mm
  const [cantLoad, setCantLoad] = useState(5);

  // Derived analytics
  const pendOmega = pendulumOmega(pendL, pendG);
  const pendT = pendulumPeriod(pendL, pendG);
  const spOmega = springOmega(spK, spM);
  const spT = springPeriod(spK, spM);
  const spStaticX = springStaticExtension(spM, spK);
  const conOmega = conicalPendulumOmega(conL, conTheta * Math.PI / 180);
  const conT = conicalPendulumPeriod(conL, conTheta * Math.PI / 180);
  const conTens = conicalPendulumTension(conM, conTheta * Math.PI / 180);
  const conSpeed = conicalPendulumSpeed(conL, conTheta * Math.PI / 180);
  const physI = physM * physL * physL / 3; // rod pivoted at end approx
  const physD = physL / 2;
  const physT_actual = physicalPendulumPeriod(physI, physM, physD);
  const physT_simple = rodPendulumPeriod(physL);
  const bifT = bifilarPeriodSimple(bifM, bifL, bifWire, bifSep / 2);
  const cantK = cantileverStiffness(200e9, 0.03, cantH / 1000, cantL);
  const cantDef = cantileverDeflection(cantLoad, 200e9, 0.03, cantH / 1000, cantL);
  const cantT = cantileverPeriod(1, 200e9, 0.03, cantH / 1000, cantL);

  // Graph data
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA : 0.2;
  const graphOmega = topic === 'pendulum' ? pendOmega :
                     topic === 'spring' ? spOmega : 2;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM : 1;
  const graphK = topic === 'pendulum' ? pendM * pendOmega * pendOmega :
                 topic === 'spring' ? spK : 4;

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, bifM, bifL, bifWire, bifSep, cantL, cantH, cantLoad, bifMode, reset]);

  const handleTick = useCallback((t: number) => setCurrentT(t), []);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Oscillations</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple Harmonic Motion</h1>
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

          {/* Topic tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); setGraphMode('displacement'); }}
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
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
            {topic !== 'conical' && (
              <span className="text-xs text-gray-400 ml-2">a = −ω²x &nbsp;|&nbsp; x = A cos(ωt)</span>
            )}
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + graph + controls + sliders */}
            <div className="space-y-3 min-w-0">

              {/* Canvas */}
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'pendulum' && (
                  <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA}
                    gravity={pendG} mass={pendM}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={380} height={300} />
                )}
                {topic === 'spring' && (
                  <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={280} height={320} />
                )}
                {topic === 'conical' && (
                  <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta}
                    mass={conM} isRunning={isRunning} isPaused={isPaused}
                    width={380} height={300} />
                )}
                {topic === 'physical' && (
                  <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM}
                    pivotFraction={physPF} isRunning={isRunning} isPaused={isPaused}
                    width={380} height={300} />
                )}
                {topic === 'bifilar' && (
                  <div className="space-y-2">
                    <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
                      {(['bifilar', 'cantilever'] as const).map(m => (
                        <button key={m} onClick={() => setBifMode(m)}
                          className={`px-4 py-1.5 rounded-lg text-xs font-medium transition capitalize ${
                            bifMode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{m}</button>
                      ))}
                    </div>
                    <BifilarCanvas key={`${resetKey}-${bifMode}`}
                      mode={bifMode} mass={bifM} rodLength={bifL}
                      wireLength={bifWire} separation={bifSep}
                      beamLength={cantL} beamWidth={30} beamHeight={cantH}
                      youngModulus={200} load={cantLoad}
                      isRunning={isRunning} isPaused={isPaused}
                      width={380} height={280} />
                  </div>
                )}
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
              </div>

              {/* Graph */}
              {topic !== 'conical' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Graph</p>
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg overflow-x-auto">
                      {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
                        <button key={gm} onClick={() => setGraphMode(gm)}
                          className={`shrink-0 px-2.5 py-1 rounded-md text-[10px] font-medium transition ${
                            graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>
                          {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase (v–x)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK}
                    mode={graphMode} currentT={currentT} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    {graphMode === 'displacement' && 'Cosine wave — starts at +A, returns to +A each period T'}
                    {graphMode === 'velocity' && 'Sine wave — 90° ahead of displacement. Maximum at x=0'}
                    {graphMode === 'acceleration' && 'Cosine wave — always opposite to displacement (a = −ω²x)'}
                    {graphMode === 'energy' && 'KE and PE exchange; total energy E = ½mω²A² = constant (dashed)'}
                    {graphMode === 'phase' && 'Ellipse in phase space — SHM traces a closed orbit'}
                  </p>
                </div>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'pendulum' && <>
                  <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
                  <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" note="Keep < 15° for accurate SHM" />
                  <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" note="Does not affect period" />
                  <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" note="Moon=1.6  Earth=9.81  Jupiter=24.8" />
                </>}

                {topic === 'spring' && <>
                  <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
                  <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" note="Must be less than static extension" />
                </>}

                {topic === 'conical' && <>
                  <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
                  <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
                  <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
                </>}

                {topic === 'physical' && <>
                  <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
                  <Slider label="Pivot position (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" note="0 = top end, 0.5 = centre (infinite period)" />
                </>}

                {topic === 'bifilar' && bifMode === 'bifilar' && <>
                  <Slider label="Rod mass" unit="kg" value={bifM} min={0.5} max={5} step={0.1} set={setBifM} color="#6366f1" />
                  <Slider label="Rod length" unit="m" value={bifL} min={0.2} max={1.5} step={0.05} set={setBifL} color="#f59e0b" />
                  <Slider label="Wire length" unit="m" value={bifWire} min={0.3} max={2} step={0.05} set={setBifWire} color="#10b981" />
                  <Slider label="Wire separation (2d)" unit="m" value={bifSep} min={0.1} max={0.8} step={0.02} set={setBifSep} color="#8b5cf6" />
                </>}

                {topic === 'bifilar' && bifMode === 'cantilever' && <>
                  <Slider label="Beam length" unit="m" value={cantL} min={0.1} max={1} step={0.05} set={setCantL} color="#6366f1" />
                  <Slider label="Beam height (thickness)" unit="mm" value={cantH} min={2} max={20} step={1} set={setCantH} color="#f59e0b" />
                  <Slider label="End load" unit="N" value={cantLoad} min={0} max={50} step={1} set={setCantLoad} color="#ef4444" />
                </>}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'pendulum' && [
                    { l: 'Angular freq ω', v: `${pendOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${pendT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/pendT).toFixed(3)} Hz`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(pendA * Math.PI/180 * pendL * pendOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Max acceleration', v: `${(pendA * Math.PI/180 * pendL * pendOmega**2).toFixed(3)} m/s²`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'spring' && [
                    { l: 'Angular freq ω', v: `${spOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${spT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Static extension', v: `${spStaticX.toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(spA * spOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Total energy', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-purple-600' },
                    { l: 'Max KE = Max PE', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'conical' && [
                    { l: 'Angular velocity ω', v: `${conOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${conT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Orbital radius r', v: `${(conL * Math.sin(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'String tension T', v: `${conTens.toFixed(3)} N`, c: 'text-rose-500' },
                    { l: 'Orbital speed v', v: `${conSpeed.toFixed(3)} m/s`, c: 'text-purple-600' },
                    { l: 'Vertical height', v: `${(conL * Math.cos(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'physical' && [
                    { l: 'I (about pivot)', v: `${physI.toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period (physical)', v: `${physT_actual.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Period (simple, same L)', v: `${physT_simple.toFixed(3)} s`, c: 'text-amber-600' },
                    { l: 'Equiv. simple length', v: `${(physI/(physM*physD)).toFixed(3)} m`, c: 'text-rose-500' },
                    { l: 'Ratio T_phys/T_simple', v: `${(physT_actual/physT_simple).toFixed(3)}`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'bifilar' && [
                    { l: 'I (rod)', v: `${(bifM*bifL**2/12).toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${bifT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/bifT).toFixed(3)} Hz`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'cantilever' && [
                    { l: 'Stiffness k', v: `${cantK.toFixed(0)} N/m`, c: 'text-indigo-600' },
                    { l: 'Deflection δ', v: `${(cantDef*1000).toFixed(2)} mm`, c: 'text-emerald-600' },
                    { l: 'Nat. frequency', v: `${(1/cantT).toFixed(2)} Hz`, c: 'text-amber-600' },
                    { l: 'Period T', v: `${cantT.toFixed(3)} s`, c: 'text-rose-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
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
EOF

echo ""
echo "✅ SHM & Oscillations complete!"
echo ""
echo "Files written:"
echo "  src/lib/physics/shm.ts"
echo "  src/components/simulation/SHMGraph.tsx"
echo "  src/components/simulation/PendulumCanvas.tsx"
echo "  src/components/simulation/SpringCanvas.tsx"
echo "  src/components/simulation/ConicalPendulumCanvas.tsx"
echo "  src/components/simulation/PhysicalPendulumCanvas.tsx"
echo "  src/components/simulation/BifilarCanvas.tsx"
echo "  src/app/simulations/oscillations/page.tsx"
echo ""
echo "Visit: http://localhost:3000/simulations/oscillations"
