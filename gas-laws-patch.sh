#!/bin/bash
# A-Factor STEM Studio — Gas Laws simulation patch
# Run inside af2s/ folder: bash gas-laws-patch.sh
set -e
echo "Writing Gas Laws simulation files..."

mkdir -p src/components/simulation
mkdir -p src/lib/physics
mkdir -p src/app/simulations/gas-laws

# ── 1. Physics engine ─────────────────────────────────────────────────────────
cat > src/lib/physics/gas-laws.ts << 'EOF'
export interface GasState {
  pressure: number;    // kPa
  volume: number;      // L
  temperature: number; // K
  moles: number;       // mol
}

export const R = 8.314; // J/(mol·K)

// Boyle's Law: P1V1 = P2V2 (constant T, n)
export function boyleNewPressure(p1: number, v1: number, v2: number): number {
  return (p1 * v1) / v2;
}
export function boyleNewVolume(p1: number, v1: number, p2: number): number {
  return (p1 * v1) / p2;
}

// Charles' Law: V1/T1 = V2/T2 (constant P, n)
export function charlesNewVolume(v1: number, t1: number, t2: number): number {
  return (v1 * t2) / t1;
}

// Ideal gas: PV = nRT
export function idealGasPressure(n: number, t: number, v: number): number {
  return (n * R * t) / (v * 0.001); // v in L → m³
}

// Generate Boyle's curve: P vs V at constant T
export function boyleCurve(
  n: number,
  temperature: number,
  vMin = 0.5,
  vMax = 10,
  steps = 60
): { v: number; p: number }[] {
  const points = [];
  for (let i = 0; i <= steps; i++) {
    const v = vMin + (i / steps) * (vMax - vMin);
    const p = idealGasPressure(n, temperature, v) / 1000; // Pa → kPa
    points.push({ v, p });
  }
  return points;
}

// Generate Charles' curve: V vs T at constant P
export function charlesCurve(
  n: number,
  pressure: number, // kPa
  tMin = 100,
  tMax = 600,
  steps = 60
): { t: number; v: number }[] {
  const points = [];
  for (let i = 0; i <= steps; i++) {
    const t = tMin + (i / steps) * (tMax - tMin);
    const v = (n * R * t) / (pressure * 1000) * 1000; // m³ → L
    points.push({ t, v });
  }
  return points;
}

// Particle speed from temperature (Maxwell-Boltzmann proxy)
export function particleSpeed(temperature: number, molarMass = 0.029): number {
  return Math.sqrt((3 * R * temperature) / molarMass);
}
EOF

# ── 2. Boyle's Law Canvas ─────────────────────────────────────────────────────
cat > src/components/simulation/BoylesCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback, useState } from 'react';
import { boyleCurve, idealGasPressure } from '@/lib/physics/gas-laws';

interface BoylesCanvasProps {
  volume: number;       // L (0.5 – 10)
  temperature: number;  // K
  moles: number;
  width?: number;
  height?: number;
}

const N = 40; // number of particles

interface Particle { x: number; y: number; vx: number; vy: number; r: number; }

function randomParticles(count: number, cx: number, cy: number, pistonY: number, bottom: number): Particle[] {
  return Array.from({ length: count }, () => ({
    x: cx - 50 + Math.random() * 100,
    y: pistonY + 8 + Math.random() * (bottom - pistonY - 16),
    vx: (Math.random() - 0.5) * 3,
    vy: (Math.random() - 0.5) * 3,
    r: 4,
  }));
}

export function BoylesCanvas({ volume, temperature, moles, width = 340, height = 320 }: BoylesCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);
  const simRef = useRef({ volume, temperature, moles, width, height });
  simRef.current = { volume, temperature, moles, width, height };

  const CX = width / 2;
  const CYLINDER_W = 120;
  const CYLINDER_LEFT = CX - CYLINDER_W / 2;
  const CYLINDER_RIGHT = CX + CYLINDER_W / 2;
  const CYLINDER_TOP = 20;
  const CYLINDER_BOTTOM = height - 40;
  const CYLINDER_H = CYLINDER_BOTTOM - CYLINDER_TOP;

  const getPistonY = useCallback((vol: number) => {
    const fillFraction = Math.min(vol / 10, 1);
    return CYLINDER_BOTTOM - fillFraction * CYLINDER_H;
  }, [CYLINDER_BOTTOM, CYLINDER_H]);

  // Init particles
  useEffect(() => {
    const pistonY = getPistonY(volume);
    particles.current = randomParticles(N, CX, (pistonY + CYLINDER_BOTTOM) / 2, pistonY, CYLINDER_BOTTOM);
  }, []);  // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { volume: vol, temperature: temp, moles: n, width: w, height: h } = simRef.current;

    const pistonY = getPistonY(vol);
    const pressure = idealGasPressure(n, temp, vol) / 1000;
    const speedFactor = Math.sqrt(temp / 300);

    ctx.clearRect(0, 0, w, h);

    // Cylinder walls
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(CYLINDER_LEFT, pistonY, CYLINDER_W, CYLINDER_BOTTOM - pistonY);
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.strokeRect(CYLINDER_LEFT, pistonY, CYLINDER_W, CYLINDER_BOTTOM - pistonY);

    // Piston
    const grad = ctx.createLinearGradient(CYLINDER_LEFT, 0, CYLINDER_RIGHT, 0);
    grad.addColorStop(0, '#6366f1');
    grad.addColorStop(1, '#818cf8');
    ctx.fillStyle = grad;
    ctx.fillRect(CYLINDER_LEFT, pistonY - 12, CYLINDER_W, 14);
    ctx.strokeStyle = '#4338ca';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(CYLINDER_LEFT, pistonY - 12, CYLINDER_W, 14);

    // Piston handle
    ctx.fillStyle = '#4338ca';
    ctx.fillRect(CX - 6, CYLINDER_TOP, 12, pistonY - 12 - CYLINDER_TOP);

    // Pressure label
    ctx.fillStyle = '#4338ca';
    ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${pressure.toFixed(1)} kPa`, CX, pistonY - 18);

    // Update + draw particles
    const ps = particles.current;
    for (const p of ps) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x - p.r < CYLINDER_LEFT)  { p.x = CYLINDER_LEFT + p.r;  p.vx = Math.abs(p.vx); }
      if (p.x + p.r > CYLINDER_RIGHT) { p.x = CYLINDER_RIGHT - p.r; p.vx = -Math.abs(p.vx); }
      if (p.y - p.r < pistonY)        { p.y = pistonY + p.r;        p.vy = Math.abs(p.vy); }
      if (p.y + p.r > CYLINDER_BOTTOM){ p.y = CYLINDER_BOTTOM - p.r; p.vy = -Math.abs(p.vy); }

      const heat = Math.min(((temp - 100) / 500), 1);
      const r = Math.round(99 + heat * 120);
      const b = Math.round(180 - heat * 120);
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${r},120,${b},0.8)`;
      ctx.fill();
    }

    // Volume label
    ctx.fillStyle = '#64748b';
    ctx.font = '11px system-ui';
    ctx.textAlign = 'left';
    ctx.fillText(`V = ${vol.toFixed(1)} L`, CYLINDER_RIGHT + 8, (pistonY + CYLINDER_BOTTOM) / 2);
    ctx.fillText(`T = ${temp} K`, CYLINDER_RIGHT + 8, (pistonY + CYLINDER_BOTTOM) / 2 + 16);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CYLINDER_BOTTOM, CYLINDER_LEFT, CYLINDER_RIGHT, CYLINDER_TOP, getPistonY]);

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

# ── 3. Charles' Law Canvas ────────────────────────────────────────────────────
cat > src/components/simulation/CharlesCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { charlesNewVolume } from '@/lib/physics/gas-laws';

interface CharlesCanvasProps {
  temperature: number; // K
  pressure: number;    // kPa
  moles: number;
  refTemp?: number;    // reference temperature
  refVolume?: number;  // reference volume at refTemp
  width?: number;
  height?: number;
}

const N = 40;
interface Particle { x: number; y: number; vx: number; vy: number; }

export function CharlesCanvas({
  temperature, pressure, moles, refTemp = 300, refVolume = 3,
  width = 340, height = 320,
}: CharlesCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);
  const simRef = useRef({ temperature, pressure, moles, refTemp, refVolume, width, height });
  simRef.current = { temperature, pressure, moles, refTemp, refVolume, width, height };

  const CX = width / 2;
  const CYLINDER_W = 100;
  const CYLINDER_LEFT = CX - CYLINDER_W / 2;
  const CYLINDER_RIGHT = CX + CYLINDER_W / 2;
  const CYLINDER_BOTTOM = height - 40;
  const MAX_H = CYLINDER_BOTTOM - 30;

  const getGasTop = useCallback((temp: number) => {
    const vol = charlesNewVolume(refVolume, refTemp, temp);
    const fraction = Math.min(vol / (refVolume * 2.5), 1);
    return CYLINDER_BOTTOM - fraction * MAX_H;
  }, [CYLINDER_BOTTOM, MAX_H, refTemp, refVolume]);

  useEffect(() => {
    particles.current = Array.from({ length: N }, () => ({
      x: CYLINDER_LEFT + 8 + Math.random() * (CYLINDER_W - 16),
      y: getGasTop(temperature) + 8 + Math.random() * (CYLINDER_BOTTOM - getGasTop(temperature) - 16),
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
    }));
  }, []); // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { temperature: temp, width: w, height: h } = simRef.current;

    const gasTop = getGasTop(temp);
    const gasH = CYLINDER_BOTTOM - gasTop;
    const speedFactor = Math.sqrt(temp / 300);
    const heat = Math.min((temp - 100) / 600, 1);

    ctx.clearRect(0, 0, w, h);

    // Gas fill with temperature colour
    const r = Math.round(219 + heat * 36);
    const g = Math.round(234 - heat * 114);
    const b = Math.round(254 - heat * 154);
    ctx.fillStyle = `rgba(${r},${g},${b},0.35)`;
    ctx.fillRect(CYLINDER_LEFT, gasTop, CYLINDER_W, gasH);

    // Cylinder walls (open top = piston moves up)
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(CYLINDER_LEFT, 20);
    ctx.lineTo(CYLINDER_LEFT, CYLINDER_BOTTOM);
    ctx.lineTo(CYLINDER_RIGHT, CYLINDER_BOTTOM);
    ctx.lineTo(CYLINDER_RIGHT, 20);
    ctx.stroke();

    // Piston (floats at gas top)
    const pg = ctx.createLinearGradient(CYLINDER_LEFT, 0, CYLINDER_RIGHT, 0);
    pg.addColorStop(0, '#6366f1'); pg.addColorStop(1, '#818cf8');
    ctx.fillStyle = pg;
    ctx.fillRect(CYLINDER_LEFT, gasTop - 10, CYLINDER_W, 12);
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 1.5;
    ctx.strokeRect(CYLINDER_LEFT, gasTop - 10, CYLINDER_W, 12);

    // Update + draw particles
    for (const p of particles.current) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x < CYLINDER_LEFT + 4)    { p.x = CYLINDER_LEFT + 4;    p.vx = Math.abs(p.vx); }
      if (p.x > CYLINDER_RIGHT - 4)   { p.x = CYLINDER_RIGHT - 4;   p.vx = -Math.abs(p.vx); }
      if (p.y < gasTop + 4)           { p.y = gasTop + 4;           p.vy = Math.abs(p.vy); }
      if (p.y > CYLINDER_BOTTOM - 4)  { p.y = CYLINDER_BOTTOM - 4;  p.vy = -Math.abs(p.vy); }

      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${Math.round(99 + heat*120)},102,${Math.round(241 - heat*141)},0.85)`;
      ctx.fill();
    }

    // Labels
    ctx.fillStyle = '#4338ca'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${(charlesNewVolume(refVolume, refTemp, temp)).toFixed(2)} L`, CX, gasTop - 16);
    ctx.fillStyle = '#64748b'; ctx.font = '11px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`T = ${temp} K`, CYLINDER_RIGHT + 8, CYLINDER_BOTTOM - 20);
    ctx.fillText(`P = const`, CYLINDER_RIGHT + 8, CYLINDER_BOTTOM - 4);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CYLINDER_BOTTOM, CYLINDER_LEFT, CYLINDER_RIGHT, MAX_H, getGasTop]);

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

# ── 4. Real-time Graph component ──────────────────────────────────────────────
cat > src/components/simulation/GasLawGraph.tsx << 'EOF'
'use client';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ReferenceDot, ResponsiveContainer, Label,
} from 'recharts';
import { boyleCurve, charlesCurve } from '@/lib/physics/gas-laws';

interface GasLawGraphProps {
  law: 'boyle' | 'charles';
  currentV: number;
  currentP: number;
  currentT: number;
  moles: number;
}

export function GasLawGraph({ law, currentV, currentP, currentT, moles }: GasLawGraphProps) {
  if (law === 'boyle') {
    const data = boyleCurve(moles, currentT).map(d => ({ v: +d.v.toFixed(2), p: +d.p.toFixed(2) }));
    return (
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="v" type="number" domain={[0.5, 10]} tick={{ fontSize: 11 }}>
            <Label value="Volume (L)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 11 }}>
            <Label value="Pressure (kPa)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
          </YAxis>
          <Tooltip formatter={(v: number) => [`${v} kPa`, 'Pressure']} labelFormatter={v => `Volume: ${v} L`} />
          <Line type="monotone" dataKey="p" stroke="#6366f1" strokeWidth={2} dot={false} />
          <ReferenceDot x={+currentV.toFixed(2)} y={+currentP.toFixed(2)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  const data = charlesCurve(moles, currentP).map(d => ({ t: +d.t.toFixed(0), v: +d.v.toFixed(2) }));
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" domain={[100, 600]} tick={{ fontSize: 11 }}>
          <Label value="Temperature (K)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 11 }}>
          <Label value="Volume (L)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
        </YAxis>
        <Tooltip formatter={(v: number) => [`${v} L`, 'Volume']} labelFormatter={t => `Temp: ${t} K`} />
        <Line type="monotone" dataKey="v" stroke="#10b981" strokeWidth={2} dot={false} />
        <ReferenceDot x={currentT} y={+(charlesCurve(moles, currentP, currentT, currentT, 1)[0]?.v ?? 0).toFixed(2)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

# ── 5. Main Gas Laws page ──────────────────────────────────────────────────────
cat > src/app/simulations/gas-laws/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import { idealGasPressure, charlesNewVolume } from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];

const TEACHER_NOTES = {
  boyle: [
    "Boyle's Law states that at constant temperature, pressure and volume are inversely proportional: P₁V₁ = P₂V₂.",
    "The P-V graph is a hyperbola — halving the volume doubles the pressure.",
    "Real gases deviate from this at very high pressures or low temperatures.",
    "Ask students: what happens to the particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law states that at constant pressure, volume is directly proportional to absolute temperature: V₁/T₁ = V₂/T₂.",
    "Temperature MUST be in Kelvin — the law breaks down with Celsius.",
    "The V-T graph is a straight line that, if extended, passes through absolute zero (0 K, −273°C).",
    "Ask students: why do hot air balloons rise? How does a car tyre behave in summer vs winter?",
  ],
};

const EXERCISES = {
  boyle: [
    { q: "A gas occupies 4 L at 200 kPa. What is its volume at 400 kPa? (constant T)", a: "2 L — P₁V₁ = P₂V₂ → (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa has volume 8 L. Find the pressure when V = 2 L.", a: "400 kPa — (100×8)/2 = 400 kPa" },
    { q: "Why does a sealed syringe become harder to push as you compress the gas inside?", a: "Reducing volume increases pressure — more collisions per unit area." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. What volume does it occupy at 600 K? (constant P)", a: "6 L — V₁/T₁ = V₂/T₂ → (3×600)/300 = 6 L" },
    { q: "A balloon has volume 2 L at 27°C. Find its volume at 127°C.", a: "First convert: T₁=300K, T₂=400K. V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin when using Charles' Law?", a: "Kelvin starts at absolute zero — the true zero of molecular motion. Celsius gives wrong ratios." },
  ],
};

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);        // L
  const [temperature, setTemperature] = useState(300); // K
  const [pressure, setPressure] = useState(200);  // kPa
  const [moles] = useState(0.1);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState<string[]>(['WAEC', 'IGCSE']);

  const derivedPressure = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedVolume = charlesNewVolume(3, 300, temperature);

  const toggleCurriculum = (c: string) =>
    setActiveCurricula(prev => prev.includes(c) ? prev.filter(x => x !== c) : [...prev, c]);

  return (
    <main className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white px-6 py-4">
        <div className="mx-auto max-w-7xl flex items-center justify-between">
          <div>
            <a href="/" className="text-xs text-gray-400 hover:text-indigo-600 transition">← A-Factor</a>
            <h1 className="text-lg font-semibold text-gray-900 mt-0.5">Gas Laws</h1>
          </div>
          <div className="flex gap-2">
            {CURRICULA.map(c => (
              <button key={c} onClick={() => toggleCurriculum(c)}
                className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                  activeCurricula.includes(c)
                    ? 'bg-indigo-600 text-white border-indigo-600'
                    : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'
                }`}>{c}</button>
            ))}
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl px-6 py-6">

        {/* Law selector tabs */}
        <div className="flex gap-1 mb-6 bg-gray-100 p-1 rounded-xl w-fit">
          {(['boyle', 'charles'] as Law[]).map(l => (
            <button key={l} onClick={() => setLaw(l)}
              className={`px-5 py-2 rounded-lg text-sm font-medium transition ${
                law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
              }`}>
              {l === 'boyle' ? "Boyle's Law (P-V)" : "Charles' Law (V-T)"}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_1fr_300px]">

          {/* Left: Canvas */}
          <div className="space-y-3">
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                {law === 'boyle' ? 'Gas compression (constant T)' : 'Gas expansion (constant P)'}
              </p>
              {law === 'boyle'
                ? <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={300} height={300} />
                : <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={300} height={300} />
              }
            </div>

            {/* Sliders */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

              {law === 'boyle' && (
                <>
                  <div className="space-y-1.5">
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Volume</span>
                      <span className="font-medium text-gray-800 tabular-nums">{volume.toFixed(1)} L</span>
                    </div>
                    <input type="range" min="0.5" max="10" step="0.1" value={volume}
                      onChange={e => setVolume(Number(e.target.value))}
                      className="w-full" style={{ accentColor: '#6366f1' }} />
                    <div className="flex justify-between text-[10px] text-gray-300"><span>0.5 L</span><span>10 L</span></div>
                  </div>
                  <div className="space-y-1.5">
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Temperature (constant)</span>
                      <span className="font-medium text-gray-800 tabular-nums">{temperature} K</span>
                    </div>
                    <input type="range" min="200" max="600" step="10" value={temperature}
                      onChange={e => setTemperature(Number(e.target.value))}
                      className="w-full" style={{ accentColor: '#f59e0b' }} />
                    <div className="flex justify-between text-[10px] text-gray-300"><span>200 K</span><span>600 K</span></div>
                  </div>
                  <div className="rounded-xl bg-indigo-50 px-4 py-3 text-sm text-indigo-800">
                    <span className="font-medium">P = </span>{derivedPressure.toFixed(1)} kPa
                    <span className="text-indigo-400 ml-2 text-xs">↑ as volume decreases</span>
                  </div>
                </>
              )}

              {law === 'charles' && (
                <>
                  <div className="space-y-1.5">
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Temperature</span>
                      <span className="font-medium text-gray-800 tabular-nums">{temperature} K ({temperature - 273}°C)</span>
                    </div>
                    <input type="range" min="100" max="600" step="10" value={temperature}
                      onChange={e => setTemperature(Number(e.target.value))}
                      className="w-full" style={{ accentColor: '#f59e0b' }} />
                    <div className="flex justify-between text-[10px] text-gray-300"><span>100 K</span><span>600 K</span></div>
                  </div>
                  <div className="space-y-1.5">
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Pressure (constant)</span>
                      <span className="font-medium text-gray-800 tabular-nums">{pressure} kPa</span>
                    </div>
                    <input type="range" min="50" max="500" step="10" value={pressure}
                      onChange={e => setPressure(Number(e.target.value))}
                      className="w-full" style={{ accentColor: '#10b981' }} />
                    <div className="flex justify-between text-[10px] text-gray-300"><span>50 kPa</span><span>500 kPa</span></div>
                  </div>
                  <div className="rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
                    <span className="font-medium">V = </span>{derivedVolume.toFixed(2)} L
                    <span className="text-emerald-400 ml-2 text-xs">↑ as temperature increases</span>
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Middle: Graph */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">
              {law === 'boyle' ? 'P–V graph (Boyle\'s Law)' : 'V–T graph (Charles\' Law)'}
            </p>
            <p className="text-xs text-gray-400 mb-4">
              {law === 'boyle'
                ? 'Hyperbolic curve — constant temperature isotherm. Yellow dot = current state.'
                : 'Straight line through origin (0 K) — yellow dot = current state.'}
            </p>
            <GasLawGraph
              law={law}
              currentV={volume}
              currentP={derivedPressure}
              currentT={temperature}
              moles={moles}
            />

            {/* Key equation */}
            <div className="mt-4 rounded-xl border border-gray-100 bg-gray-50 p-3 text-center">
              <p className="text-xs text-gray-400 mb-1">Key relationship</p>
              <p className="text-base font-semibold text-gray-900">
                {law === 'boyle' ? 'P₁V₁ = P₂V₂' : 'V₁/T₁ = V₂/T₂'}
              </p>
              <p className="text-xs text-gray-400 mt-1">
                {law === 'boyle' ? 'at constant T and n' : 'at constant P and n (T in Kelvin)'}
              </p>
            </div>

            {/* Curriculum coverage */}
            <div className="mt-4">
              <p className="text-xs text-gray-400 mb-2">Curriculum coverage</p>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                    activeCurricula.includes(c)
                      ? 'bg-indigo-100 text-indigo-700'
                      : 'bg-gray-100 text-gray-400'
                  }`}>{c}</span>
                ))}
              </div>
            </div>
          </div>

          {/* Right: Teacher notes + exercises */}
          <div className="space-y-4">

            {/* Teacher notes */}
            <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-sm">📋</span>
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide">Teacher notes</p>
              </div>
              <ul className="space-y-2">
                {TEACHER_NOTES[law].map((note, i) => (
                  <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                    <span className="text-amber-400 mt-0.5 shrink-0">•</span>
                    {note}
                  </li>
                ))}
              </ul>
            </div>

            {/* Student exercises */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-sm">✏️</span>
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">Student exercises</p>
              </div>
              <div className="space-y-2">
                {EXERCISES[law].map((ex, i) => (
                  <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                    <button
                      onClick={() => setOpenEx(openEx === i ? null : i)}
                      className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2"
                    >
                      <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                      <span className="text-gray-300 shrink-0">{openEx === i ? '▲' : '▼'}</span>
                    </button>
                    {openEx === i && (
                      <div className="px-3 py-2 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                        <span className="font-medium">Answer: </span>{ex.a}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* Real world connections */}
            <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
              <p className="text-xs font-medium text-indigo-600 uppercase tracking-wide mb-2">Real world</p>
              {law === 'boyle' ? (
                <ul className="space-y-1.5 text-xs text-indigo-800">
                  <li className="flex gap-2"><span>🤿</span> Scuba diving — gas expands as diver ascends</li>
                  <li className="flex gap-2"><span>🩺</span> Breathing — lungs expand to reduce pressure</li>
                  <li className="flex gap-2"><span>💉</span> Syringes — drawing back piston creates low pressure</li>
                </ul>
              ) : (
                <ul className="space-y-1.5 text-xs text-indigo-800">
                  <li className="flex gap-2"><span>🎈</span> Hot air balloons — heat expands gas, reduces density</li>
                  <li className="flex gap-2"><span>🚗</span> Car tyres — overinflate in summer heat</li>
                  <li className="flex gap-2"><span>🍞</span> Bread rising — CO₂ expands in oven heat</li>
                </ul>
              )}
            </div>
          </div>

        </div>
      </div>
    </main>
  );
}
EOF

# ── 6. Add nav link to main page ───────────────────────────────────────────────
echo ""
echo "✅ Gas Laws simulation complete!"
echo ""
echo "Files written:"
echo "  src/lib/physics/gas-laws.ts"
echo "  src/components/simulation/BoylesCanvas.tsx"
echo "  src/components/simulation/CharlesCanvas.tsx"
echo "  src/components/simulation/GasLawGraph.tsx"
echo "  src/app/simulations/gas-laws/page.tsx"
echo ""
echo "Install recharts if not already installed:"
echo "  npm install recharts"
echo ""
echo "Then visit: http://localhost:3000/simulations/gas-laws"
