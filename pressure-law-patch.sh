#!/bin/bash
# A-Factor STEM Studio — Pressure Law (Gay-Lussac) patch
# Run inside af2s/ folder: bash pressure-law-patch.sh
set -e
echo "Adding Pressure Law to Gas Laws simulation..."

# ── 1. Update gas-laws physics engine ─────────────────────────────────────────
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

// Pressure Law (Gay-Lussac): P1/T1 = P2/T2 (constant V, n)
export function pressureLawNewPressure(p1: number, t1: number, t2: number): number {
  return (p1 * t2) / t1;
}
export function pressureLawNewTemperature(p1: number, t1: number, p2: number): number {
  return (p2 * t1) / p1;
}

// Ideal gas: PV = nRT
export function idealGasPressure(n: number, t: number, v: number): number {
  return (n * R * t) / (v * 0.001); // v in L → m³
}

// Boyle's curve: P vs V at constant T
export function boyleCurve(
  n: number, temperature: number, vMin = 0.5, vMax = 10, steps = 60
): { v: number; p: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const v = vMin + (i / steps) * (vMax - vMin);
    return { v: +v.toFixed(3), p: +(idealGasPressure(n, temperature, v) / 1000).toFixed(2) };
  });
}

// Charles' curve: V vs T at constant P
export function charlesCurve(
  n: number, pressure: number, tMin = 100, tMax = 600, steps = 60
): { t: number; v: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    const v = (n * R * t) / (pressure * 1000) * 1000;
    return { t: +t.toFixed(0), v: +v.toFixed(3) };
  });
}

// Pressure Law curve: P vs T at constant V
export function pressureLawCurve(
  n: number, volume: number, tMin = 100, tMax = 600, steps = 60
): { t: number; p: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    const p = idealGasPressure(n, t, volume) / 1000;
    return { t: +t.toFixed(0), p: +p.toFixed(2) };
  });
}

// Particle speed proxy from temperature
export function particleSpeed(temperature: number, molarMass = 0.029): number {
  return Math.sqrt((3 * R * temperature) / molarMass);
}
EOF

# ── 2. Pressure Law Canvas component ──────────────────────────────────────────
cat > src/components/simulation/PressureLawCanvas.tsx << 'EOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface PressureLawCanvasProps {
  temperature: number; // K
  volume: number;      // L (fixed)
  moles: number;
  refTemp?: number;
  refPressure?: number;
  width?: number;
  height?: number;
}

const N = 40;
interface Particle { x: number; y: number; vx: number; vy: number; }

export function PressureLawCanvas({
  temperature, volume, moles,
  refTemp = 300, refPressure = 200,
  width = 340, height = 320,
}: PressureLawCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);

  const sim = useRef({ temperature, volume, moles, refTemp, refPressure, width, height });
  sim.current = { temperature, volume, moles, refTemp, refPressure, width, height };

  const CX = width / 2;
  const CWIDTH = 110;
  const CLEFT = CX - CWIDTH / 2;
  const CRIGHT = CX + CWIDTH / 2;
  const CTOP = 40;
  const CBOTTOM = height - 50;
  const CHEIGHT = CBOTTOM - CTOP;

  useEffect(() => {
    particles.current = Array.from({ length: N }, () => ({
      x: CLEFT + 8 + Math.random() * (CWIDTH - 16),
      y: CTOP + 8 + Math.random() * (CHEIGHT - 16),
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
    }));
  }, []); // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { temperature: temp, refTemp: rT, refPressure: rP, width: w, height: h } = sim.current;

    const currentPressure = (rP * temp) / rT;
    const heat = Math.min((temp - 100) / 500, 1);
    const speedFactor = Math.sqrt(temp / 300);

    ctx.clearRect(0, 0, w, h);

    // Container — rigid walls (fixed volume)
    const fillR = Math.round(219 + heat * 36);
    const fillG = Math.round(234 - heat * 114);
    const fillB = Math.round(254 - heat * 154);
    ctx.fillStyle = `rgba(${fillR},${fillG},${fillB},0.3)`;
    ctx.fillRect(CLEFT, CTOP, CWIDTH, CHEIGHT);

    // Thick rigid walls to show volume is fixed
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 4;
    ctx.strokeRect(CLEFT, CTOP, CWIDTH, CHEIGHT);

    // "Fixed" label on walls
    ctx.fillStyle = '#94a3b8';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText('fixed walls', CX, CTOP - 8);

    // Pressure gauge on right wall
    const gaugeH = CHEIGHT - 20;
    const gaugeFill = Math.min((currentPressure / (rP * 3)) * gaugeH, gaugeH);
    const gaugeX = CRIGHT + 16;
    ctx.fillStyle = '#f1f5f9';
    ctx.fillRect(gaugeX, CTOP + 10, 12, gaugeH);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.strokeRect(gaugeX, CTOP + 10, 12, gaugeH);

    const gaugeGrad = ctx.createLinearGradient(0, CTOP + 10 + gaugeH, 0, CTOP + 10);
    gaugeGrad.addColorStop(0, '#10b981');
    gaugeGrad.addColorStop(0.5, '#f59e0b');
    gaugeGrad.addColorStop(1, '#ef4444');
    ctx.fillStyle = gaugeGrad;
    ctx.fillRect(gaugeX, CTOP + 10 + gaugeH - gaugeFill, 12, gaugeFill);

    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('P', gaugeX + 2, CTOP - 2);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui';
    ctx.fillText(`${currentPressure.toFixed(0)} kPa`, gaugeX - 2, CBOTTOM + 20);

    // Particles
    for (const p of particles.current) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x < CLEFT + 5)   { p.x = CLEFT + 5;   p.vx = Math.abs(p.vx); }
      if (p.x > CRIGHT - 5)  { p.x = CRIGHT - 5;  p.vx = -Math.abs(p.vx); }
      if (p.y < CTOP + 5)    { p.y = CTOP + 5;    p.vy = Math.abs(p.vy); }
      if (p.y > CBOTTOM - 5) { p.y = CBOTTOM - 5; p.vy = -Math.abs(p.vy); }

      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${Math.round(99 + heat * 120)},102,${Math.round(241 - heat * 141)},0.85)`;
      ctx.fill();
    }

    // Temperature label
    ctx.fillStyle = '#64748b'; ctx.font = '11px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`T = ${temp} K`, CLEFT, h - 8);
    ctx.fillText(`V = fixed`, CLEFT, h + 8);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CBOTTOM, CHEIGHT, CLEFT, CRIGHT, CWIDTH, CTOP]);

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

# ── 3. Update GasLawGraph to include P-T graph ────────────────────────────────
cat > src/components/simulation/GasLawGraph.tsx << 'EOF'
'use client';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ReferenceDot, ResponsiveContainer, Label,
} from 'recharts';
import { boyleCurve, charlesCurve, pressureLawCurve } from '@/lib/physics/gas-laws';

interface GasLawGraphProps {
  law: 'boyle' | 'charles' | 'pressure';
  currentV: number;
  currentP: number;
  currentT: number;
  moles: number;
}

export function GasLawGraph({ law, currentV, currentP, currentT, moles }: GasLawGraphProps) {
  if (law === 'boyle') {
    const data = boyleCurve(moles, currentT);
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
          <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} kPa`, 'Pressure']} labelFormatter={(v) => `Volume: ${v} L`} />
          <Line type="monotone" dataKey="p" stroke="#6366f1" strokeWidth={2} dot={false} />
          <ReferenceDot x={+currentV.toFixed(2)} y={+currentP.toFixed(2)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (law === 'charles') {
    const data = charlesCurve(moles, currentP);
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
          <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} L`, 'Volume']} labelFormatter={(t) => `Temp: ${t} K`} />
          <Line type="monotone" dataKey="v" stroke="#10b981" strokeWidth={2} dot={false} />
          <ReferenceDot x={currentT} y={+charlesCurve(moles, currentP, currentT, currentT, 1)[0]?.v?.toFixed(2) ?? 0} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  // Pressure Law: P vs T
  const data = pressureLawCurve(moles, currentV);
  const currentPonCurve = +(data.find(d => d.t === currentT)?.p ?? currentP).toFixed(2);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" domain={[100, 600]} tick={{ fontSize: 11 }}>
          <Label value="Temperature (K)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 11 }}>
          <Label value="Pressure (kPa)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
        </YAxis>
        <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} kPa`, 'Pressure']} labelFormatter={(t) => `Temp: ${t} K`} />
        <Line type="monotone" dataKey="p" stroke="#ef4444" strokeWidth={2} dot={false} />
        <ReferenceDot x={currentT} y={currentPonCurve} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

# ── 4. Full updated Gas Laws page with all 3 laws ─────────────────────────────
cat > src/app/simulations/gas-laws/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { PressureLawCanvas } from '@/components/simulation/PressureLawCanvas';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import { idealGasPressure, charlesNewVolume, pressureLawNewPressure } from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles' | 'pressure';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META = {
  boyle: {
    title: "Boyle's Law",
    subtitle: "P–V (constant T)",
    equation: "P₁V₁ = P₂V₂",
    condition: "constant T and n",
    color: "indigo",
    graphLabel: "P–V graph",
    graphDesc: "Hyperbolic curve at constant T. Yellow dot = current state.",
  },
  charles: {
    title: "Charles' Law",
    subtitle: "V–T (constant P)",
    equation: "V₁/T₁ = V₂/T₂",
    condition: "constant P and n, T in Kelvin",
    color: "emerald",
    graphLabel: "V–T graph",
    graphDesc: "Straight line through 0 K. Yellow dot = current state.",
  },
  pressure: {
    title: "Pressure Law",
    subtitle: "P–T (constant V)",
    equation: "P₁/T₁ = P₂/T₂",
    condition: "constant V and n, T in Kelvin",
    color: "red",
    graphLabel: "P–T graph",
    graphDesc: "Straight line through 0 K — pressure rises with temperature at fixed volume.",
  },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  boyle: [
    "Boyle's Law: at constant temperature, pressure and volume are inversely proportional: P₁V₁ = P₂V₂.",
    "The P-V graph is a hyperbola — each curve is called an isotherm (constant temperature line).",
    "Changing the temperature slider draws a new isotherm — higher T isotherms sit above lower ones.",
    "Real gases deviate from this at very high pressures or near their condensation point.",
    "Ask students: what happens to gas particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law: at constant pressure, volume is directly proportional to absolute temperature: V₁/T₁ = V₂/T₂.",
    "Temperature MUST be in Kelvin — the law breaks down with Celsius because 0°C ≠ zero molecular motion.",
    "The V-T graph is a straight line that, extended, passes through absolute zero (0 K, −273°C).",
    "This is how absolute zero was first estimated — by extrapolating Charles' Law graphs.",
    "Ask: why do hot air balloons rise? Why does a car tyre overinflate in summer?",
  ],
  pressure: [
    "The Pressure Law (Gay-Lussac's Law): at constant volume, pressure is proportional to absolute temperature: P₁/T₁ = P₂/T₂.",
    "The P-T graph is a straight line through the origin (0 K) — just like Charles' Law but for pressure.",
    "This is what happens inside a sealed rigid container like a pressure cooker or aerosol can when heated.",
    "NEVER heat a sealed rigid container beyond its rated pressure — this law explains why it's dangerous.",
    "Together, Boyle's, Charles', and the Pressure Law combine into the ideal gas law: PV = nRT.",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  boyle: [
    { q: "A gas occupies 4 L at 200 kPa. What is its volume at 400 kPa? (constant T)", a: "2 L — P₁V₁ = P₂V₂ → (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa has volume 8 L. Find the pressure when V = 2 L.", a: "400 kPa — (100×8)/2 = 400 kPa" },
    { q: "Why does a sealed syringe become harder to push as you compress the gas?", a: "Reducing volume increases collision rate per unit area — pressure rises." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. What volume at 600 K? (constant P)", a: "6 L — V₂ = V₁T₂/T₁ = (3×600)/300 = 6 L" },
    { q: "A balloon has volume 2 L at 27°C. Find its volume at 127°C.", a: "T₁=300K, T₂=400K → V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin when using Charles' Law?", a: "Kelvin starts at absolute zero — the true zero of molecular motion. Celsius gives wrong ratios." },
  ],
  pressure: [
    { q: "A gas in a rigid container is at 150 kPa and 300 K. Find pressure at 600 K.", a: "300 kPa — P₂ = P₁T₂/T₁ = (150×600)/300 = 300 kPa" },
    { q: "An aerosol can has pressure 250 kPa at 20°C. What is the pressure at 60°C?", a: "T₁=293K, T₂=333K → P₂ = (250×333)/293 = 284 kPa" },
    { q: "Why is it dangerous to throw an aerosol can into a fire?", a: "Fixed volume means rising temperature causes pressure to rise — eventually exceeding the can's rated limit and causing explosion." },
  ],
};

const REAL_WORLD: Record<Law, { icon: string; text: string }[]> = {
  boyle: [
    { icon: '🤿', text: 'Scuba diving — gas in lungs expands as diver ascends to lower pressure.' },
    { icon: '🩺', text: 'Breathing — diaphragm lowers to increase lung volume, reducing pressure so air flows in.' },
    { icon: '💉', text: 'Syringes — pulling back the piston reduces pressure to draw in fluid.' },
  ],
  charles: [
    { icon: '🎈', text: 'Hot air balloons — burner heats air, increasing volume and reducing density.' },
    { icon: '🚗', text: 'Car tyres — warm summer air makes tyres feel firmer (volume can expand slightly).' },
    { icon: '🍞', text: 'Bread rising — CO₂ bubbles expand in the oven heat, giving bread its texture.' },
  ],
  pressure: [
    { icon: '🥘', text: 'Pressure cooker — sealed fixed volume means steam pressure rises with temperature, cooking food faster.' },
    { icon: '🚗', text: 'Car tyres again — after a long drive, tyre temperature rises, increasing pressure (volume is fixed by the rim).' },
    { icon: '💣', text: 'Aerosol cans — rigid container means heating raises pressure dangerously; never incinerate.' },
    { icon: '🌡️', text: 'Gas thermometers — measure temperature by reading pressure change in a fixed-volume container.' },
  ],
};

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);
  const [temperature, setTemperature] = useState(300);
  const [pressure, setPressure] = useState(200);
  const moles = 0.1;
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE']);

  // Derived values
  const derivedPressureBoyle = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedVolumeCharles = charlesNewVolume(3, 300, temperature);
  const derivedPressurePL = pressureLawNewPressure(200, 300, temperature);

  const toggleC = (c: string) =>
    setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c]);

  const meta = LAW_META[law];

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Header */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Thermal physics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Gas laws</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c} onClick={() => toggleC(c)}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c)
                        ? CURRICULUM_COLORS[c] + ' border-transparent'
                        : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5 space-y-4">

          {/* Law selector tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-full sm:w-fit overflow-x-auto">
            {(Object.keys(LAW_META) as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-4 sm:px-5 py-2 rounded-lg text-xs sm:text-sm font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {LAW_META[l].title}
              </button>
            ))}
          </div>

          {/* Key equation pill */}
          <div className="inline-flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Key equation</span>
            <span className="text-sm font-semibold text-gray-900 font-mono">{meta.equation}</span>
            <span className="text-xs text-gray-400">{meta.condition}</span>
          </div>

          {/* Ideal gas law reminder */}
          <div className="rounded-xl border border-indigo-100 bg-indigo-50 px-4 py-3 flex flex-wrap items-center gap-3">
            <span className="text-xs text-indigo-500 font-medium">Combined ideal gas law</span>
            <span className="text-sm font-semibold text-indigo-800 font-mono">PV = nRT</span>
            <span className="text-xs text-indigo-400">Boyle + Charles + Pressure Law unified</span>
          </div>

          {/* Main 3-col layout */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">

            {/* Canvas + sliders */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                  {law === 'boyle' ? 'Compression (constant T)' :
                   law === 'charles' ? 'Expansion (constant P)' :
                   'Rigid container (constant V)'}
                </p>
                {law === 'boyle' && <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={280} height={260} />}
                {law === 'charles' && <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={280} height={260} />}
                {law === 'pressure' && <PressureLawCanvas temperature={temperature} volume={volume} moles={moles} width={280} height={260} />}
              </div>

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Adjust</p>

                {law === 'boyle' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature (constant)</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                      <input type="range" min="200" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="rounded-xl bg-indigo-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-indigo-700">P = {derivedPressureBoyle.toFixed(1)} kPa</span>
                      <span className="text-indigo-400 text-xs ml-2">↑ as V decreases</span>
                    </div>
                  </>
                )}

                {law === 'charles' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Pressure (constant)</span><span className="font-medium tabular-nums">{pressure} kPa</span></div>
                      <input type="range" min="50" max="500" step="10" value={pressure} onChange={e => setPressure(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                    </div>
                    <div className="rounded-xl bg-emerald-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-emerald-700">V = {derivedVolumeCharles.toFixed(2)} L</span>
                      <span className="text-emerald-400 text-xs ml-2">↑ as T increases</span>
                    </div>
                  </>
                )}

                {law === 'pressure' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume (constant)</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="rounded-xl bg-red-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-red-700">P = {derivedPressurePL.toFixed(1)} kPa</span>
                      <span className="text-red-400 text-xs ml-2">↑ as T increases</span>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Graph */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">{meta.graphLabel}</p>
              <p className="text-xs text-gray-400 mb-4">{meta.graphDesc}</p>
              <GasLawGraph
                law={law}
                currentV={volume}
                currentP={law === 'boyle' ? derivedPressureBoyle : law === 'pressure' ? derivedPressurePL : pressure}
                currentT={temperature}
                moles={moles}
              />

              {/* Real world */}
              <div className="mt-4 rounded-xl border border-indigo-100 bg-indigo-50 p-3">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                <ul className="space-y-1.5">
                  {REAL_WORLD[law].map((r, i) => (
                    <li key={i} className="text-xs text-indigo-800 flex gap-2 leading-relaxed">
                      <span className="shrink-0">{r.icon}</span>{r.text}
                    </li>
                  ))}
                </ul>
              </div>

              {/* Curriculum tags */}
              <div className="mt-4">
                <p className="text-xs text-gray-400 mb-1.5">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 md:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
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
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-base leading-none">{openEx === i ? '▲' : '▼'}</span>
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
echo "✅ Pressure Law added to Gas Laws!"
echo ""
echo "Files updated:"
echo "  src/lib/physics/gas-laws.ts        — pressureLawCurve + pressureLawNewPressure"
echo "  src/components/simulation/PressureLawCanvas.tsx  — new rigid container canvas"
echo "  src/components/simulation/GasLawGraph.tsx        — P-T graph added"
echo "  src/app/simulations/gas-laws/page.tsx            — 3-tab layout"
echo ""
echo "Visit: http://localhost:3000/simulations/gas-laws"
