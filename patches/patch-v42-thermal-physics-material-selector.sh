#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v42: complete the existing Thermal Physics
# module (conduction, convection, radiation) — found and fixed a real gap
# where the material selector referenced in the teacher notes didn't
# actually exist in the UI
#
#   CONTEXT. Investigated before building anything new: a full "Modes of
#   heat transfer" module already existed (conduction, convection,
#   radiation, each with teacher notes, exercises, and an animated
#   canvas) — likely from an earlier session, predating this one. Rather
#   than assume it needed a rebuild, reviewed it in detail first.
#
#   FOUND. The physics module (heat.ts) already had a fully verified
#   MATERIALS array (Copper, Aluminium, Steel, Glass, Brick, Wood, Air
#   with correct thermal conductivities) and a conductionRate() function
#   — completely unused anywhere in the page or canvas. The teacher notes
#   for conduction explicitly say "try both in the material list" —
#   referencing a feature that didn't exist in the UI at all. There was
#   also no live Q/t = kAΔT/L calculation shown anywhere, despite that
#   being the entire quantitative point of the conduction topic and
#   exactly what the exercises ask students to compute by hand.
#
#   FIXED.
#     - Added a material selector (all 7 materials from the existing
#       physics module) plus cross-sectional area and rod-length sliders
#       for conduction mode.
#     - Added a live "Rate Q/t = kAΔT/L" calculation to the Calculated
#       panel, using the actual conductionRate() function — verified
#       numerically against the default sliders (107.8W for copper vs
#       0.0067W for air at identical dimensions, correctly illustrating
#       the roughly 16,000x difference in conductivity).
#     - Made the conduction canvas's vibration-wave propagation speed
#       depend on the selected material's real k value (log-scaled, since
#       k spans four orders of magnitude from air to copper) — verified
#       numerically to give a watchable spread from ~0.4s for copper to
#       ~4.2s for air, so switching materials now visibly changes how
#       fast the "message" travels along the rod, not just a number in a
#       table.
#     - Cleaned up a small piece of dead code in convection mode (an
#       unused, voided variable) left over from an earlier draft.
#
#   Both the main page and its embed route were updated consistently.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v42-thermal-physics-material-selector.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v42: complete Thermal Physics (material selector + live rate) --"
mkdir -p "src/app/embed/heat" "src/app/simulations/heat-transfer" "src/components/simulation"

echo "  -> src/components/simulation/HeatTransferCanvas.tsx"
cat > "src/components/simulation/HeatTransferCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type HeatMode = 'conduction' | 'convection' | 'radiation';

interface Props {
  mode: HeatMode;
  hotTemp: number;    // °C
  coldTemp: number;   // °C
  materialK: number;  // W/mK — conduction mode only, drives propagation speed
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Temperature → colour (blue 0° → red 100°+)
function tempColor(tc: number, alpha = 1): string {
  const t = Math.min(1, Math.max(0, tc / 120));
  const r = Math.round(59 + t * (239 - 59));
  const g = Math.round(130 - t * (130 - 68));
  const b = Math.round(246 - t * (246 - 68));
  return `rgba(${r},${g},${b},${alpha})`;
}

function flame(ctx: CanvasRenderingContext2D, x: number, y: number, t: number) {
  ctx.save();
  for (let i = 0; i < 3; i++) {
    const wob = Math.sin(t * 7 + i * 2) * 3;
    const h = 20 + i * -5 + Math.sin(t * 9 + i) * 3;
    ctx.beginPath();
    ctx.moveTo(x - 8 + i * 8 + wob, y);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob - 5, y - h / 2, x - 8 + i * 8 + wob, y - h);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob + 5, y - h / 2, x - 8 + i * 8 + wob, y);
    ctx.fillStyle = i === 1 ? '#f59e0b' : '#ef4444';
    ctx.globalAlpha = 0.85;
    ctx.fill();
  }
  ctx.restore();
}

export function HeatTransferCanvas({ mode, hotTemp, coldTemp, materialK, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const warmthRef = useRef(0); // radiation target warming 0→1
  const sim = useRef({ mode, hotTemp, coldTemp, materialK, isRunning, isPaused });
  sim.current = { mode, hotTemp, coldTemp, materialK, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null; warmthRef.current = 0;
  }, [mode, hotTemp, coldTemp, materialK]);

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
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'conduction') {
      // Metal rod, hot left → cold right; particles vibrate harder where hotter.
      const rodY = H / 2 - 20, rodH = 56, rodX = 80, rodW = W - 160;
      const grad = ctx.createLinearGradient(rodX, 0, rodX + rodW, 0);
      grad.addColorStop(0, tempColor(s.hotTemp, 0.35));
      grad.addColorStop(1, tempColor(s.coldTemp, 0.35));
      ctx.fillStyle = grad;
      ctx.fillRect(rodX, rodY, rodW, rodH);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.strokeRect(rodX, rodY, rodW, rodH);
      // Particles: fixed lattice positions, vibration amplitude ∝ local T.
      // Energy passes along WITHOUT the particles migrating — that is conduction.
      // The wave of vibration spreads left→right at a rate tied to the
      // material's actual thermal conductivity (log-scaled, since k spans
      // four orders of magnitude from air to copper) — verified
      // numerically to give a watchable spread from ~0.4s for copper to
      // ~4s for air, so switching materials visibly changes how fast the
      // "message" travels, not just a number in a table.
      const logK = Math.log10(Math.max(s.materialK, 0.001));
      const speedFactor = 0.5 + Math.max(0, Math.min(1, (logK - Math.log10(0.02)) / (Math.log10(400) - Math.log10(0.02)))) * 5.5;
      const cols = 22, rows = 3;
      for (let c = 0; c < cols; c++) {
        const frac = c / (cols - 1);
        const localT = s.hotTemp + (s.coldTemp - s.hotTemp) * frac;
        // The "wave" of vibration spreads left→right over time
        const reached = t * speedFactor * 4 > frac * 10;
        const amp = reached ? 1.5 + (localT / 120) * 5 : 1;
        for (let r = 0; r < rows; r++) {
          const x0 = rodX + 16 + c * ((rodW - 32) / (cols - 1));
          const y0 = rodY + 14 + r * ((rodH - 28) / (rows - 1));
          const jx = Math.sin(t * (9 + c) + r * 2) * amp;
          const jy = Math.cos(t * (11 + c * 0.7) + r) * amp;
          ctx.beginPath(); ctx.arc(x0 + jx, y0 + jy, 3.4, 0, Math.PI * 2);
          ctx.fillStyle = tempColor(localT); ctx.fill();
        }
      }
      flame(ctx, rodX + 8, rodY + rodH + 44, t);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`HOT ${s.hotTemp}°C`, rodX + 20, rodY - 10);
      ctx.fillText(`COLD ${s.coldTemp}°C`, rodX + rodW - 24, rodY - 10);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText(`k = ${s.materialK} W/mK — particles vibrate harder and pass energy along, they do NOT move down the rod`, W / 2, H - 26);
    }

    if (s.mode === 'convection') {
      // Beaker of fluid with a circulation loop; heated at bottom-left.
      const bw = Math.min(260, W * 0.72), bx = W / 2 - bw / 2, by = 50, bh = H - 130;
      ctx.fillStyle = 'rgba(186,230,253,0.4)';
      ctx.fillRect(bx, by, bw, bh);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(bx, by); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by);
      ctx.stroke();
      // Particles circulate on an ellipse: rise on the heated left, sink right.
      const cxm = bx + bw / 2, cym = by + bh / 2;
      const rx = bw / 2 - 30, ry = bh / 2 - 24;
      const N = 26;
      for (let i = 0; i < N; i++) {
        const phase = (i / N) * Math.PI * 2 + t * 0.8;
        // parametric loop: angle 0 = bottom-left rising
        const px = cxm - Math.cos(phase) * rx;
        const py = cym + Math.sin(phase) * ry;
        const yFrac = (py - by) / bh;            // 0 top … 1 bottom
        const localT = s.hotTemp * (1 - yFrac) * 0.4 + (yFrac > 0.7 && px < cxm ? s.hotTemp : s.coldTemp + (s.hotTemp - s.coldTemp) * (1 - yFrac) * 0.6);
        ctx.beginPath(); ctx.arc(px, py, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = tempColor(Math.min(localT, 110)); ctx.fill();
      }
      // Loop arrows
      ctx.save();
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.ellipse(cxm, cym, rx, ry, 0, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('warm, less dense → RISES', bx - 4, cym - 8);
      ctx.fillStyle = '#3b82f6';
      ctx.fillText('cool, denser → SINKS', bx + bw + 6, cym - 8);
      flame(ctx, bx + 50, by + bh + 44, t);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('A convection current: the FLUID ITSELF moves, carrying the energy', W / 2, H - 26);
    }

    if (s.mode === 'radiation') {
      // Heater/Sun on the left radiating across a vacuum to an object.
      const sx = 90, sy = H / 2 - 12;
      warmthRef.current = Math.min(1, warmthRef.current + dt * 0.12 * (s.hotTemp / 100));
      // Sun
      const sun = ctx.createRadialGradient(sx, sy, 4, sx, sy, 34);
      sun.addColorStop(0, '#fde047'); sun.addColorStop(1, '#f59e0b');
      ctx.beginPath(); ctx.arc(sx, sy, 30, 0, Math.PI * 2);
      ctx.fillStyle = sun; ctx.fill();
      // Rays: wavy IR arrows travelling right
      ctx.save();
      ctx.strokeStyle = '#f97316'; ctx.lineWidth = 1.6;
      for (let r = -2; r <= 2; r++) {
        const y0 = sy + r * 26;
        const speed = 130;
        const head = (t * speed) % (W - 220);
        ctx.beginPath();
        for (let d = 0; d <= head; d += 4) {
          const x = sx + 40 + d;
          const y = y0 + Math.sin(d * 0.25 - t * 6) * 5;
          if (d === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }
      ctx.restore();
      // Vacuum label
      ctx.fillStyle = '#94a3b8'; ctx.font = 'italic 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('VACUUM — no particles needed', W / 2, 40);
      // Object warming up
      const ox = W - 130, oy = H / 2 - 40, ow = 60, oh = 80;
      const objT = s.coldTemp + (s.hotTemp - s.coldTemp) * warmthRef.current * 0.7;
      ctx.fillStyle = tempColor(objT, 0.8);
      ctx.fillRect(ox, oy, ow, oh);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.strokeRect(ox, oy, ow, oh);
      ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui';
      ctx.fillText(`${objT.toFixed(0)}°C`, ox + ow / 2, oy + oh / 2 + 4);
      ctx.fillText('absorber', ox + ow / 2, oy + oh + 16);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('Infrared electromagnetic waves — the ONLY mode that crosses empty space (Sun → Earth)', W / 2, H - 26);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`t = ${t.toFixed(1)}s`, 8, H - 8);

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

echo "  -> src/app/simulations/heat-transfer/page.tsx"
cat > "src/app/simulations/heat-transfer/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { celsiusToKelvin, radiatedPower, netRadiation, conductionRate, MATERIALS } from '@/lib/physics/heat';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<HeatMode, { title: string; icon: string; sub: string; eq: string }> = {
  conduction: { title: 'Conduction', icon: '🔗', sub: 'Solids — particle to particle', eq: 'Q/t = kAΔT/L' },
  convection: { title: 'Convection', icon: '🌀', sub: 'Fluids — bulk movement',        eq: 'warm rises, cool sinks' },
  radiation:  { title: 'Radiation',  icon: '☀️', sub: 'EM waves — needs no medium',    eq: 'P = εσAT⁴' },
};

const TEACHER_NOTES: Record<HeatMode, string[]> = {
  conduction: [
    'Particles do NOT travel down the rod — they vibrate in place and pass energy to their neighbours, like a row of people jiggling a rope.',
    'Metals conduct well because free (delocalised) electrons carry energy quickly through the lattice; non-metals lack these free electrons.',
    'Rate of heat flow: Q/t = kAΔT/L — bigger area or ΔT speeds it up, a thicker (longer) barrier slows it down. This is exactly why we use thick walls and small windows to keep buildings warm.',
    'Compare copper (k≈385) with glass (k≈0.8): copper conducts about 480 times faster — try both in the material list.',
    'Trapped air (double glazing, wool, fur) is a poor conductor and makes an excellent insulator, precisely because it has such a low k.',
  ],
  convection: [
    'Unlike conduction, the medium ITSELF moves in convection — warm fluid expands, becomes less dense, and rises; cooler, denser fluid sinks to replace it, setting up a convection current.',
    'This only happens in fluids (liquids and gases) — solids cannot flow, so they never convect.',
    'Real examples: sea breezes (land heats faster than sea by day), the radiator in a room (warms air rises, circulates the whole room), boiling water in a pot.',
    'Convection needs gravity (or an equivalent force) to drive the density difference — it does not work in free-fall / microgravity.',
    'The hotter the source, the faster and more vigorous the circulation — watch the particle loop speed up as you raise the temperature.',
  ],
  radiation: [
    'Radiation is the only mode of heat transfer that needs NO medium — infrared electromagnetic waves cross the vacuum of space, which is how the Sun warms the Earth.',
    'Stefan–Boltzmann law: P = εσAT⁴ — power radiated depends on the FOURTH power of absolute temperature, so a small temperature rise causes a huge jump in radiated power.',
    'Dull, black (matte) surfaces are good absorbers AND good emitters (high emissivity ε); shiny, silvered surfaces are poor absorbers/emitters — why vacuum flasks are silvered and radiators are painted matte black.',
    'All objects above 0 K radiate; the object also absorbs radiation from its surroundings, so the NET transfer depends on the temperature difference (T⁴ − T₀⁴).',
    'Applications: thermal imaging cameras detect the infrared radiated by warm bodies; a car left in the sun heats up mainly by absorbed solar radiation.',
  ],
};

const EXERCISES: Record<HeatMode, { q: string; a: string }[]> = {
  conduction: [
    { q: 'A copper bar (k=385 W/mK) of area 0.002m² and length 0.5m has a 60°C temperature difference across it. Find the rate of heat flow.', a: 'Q/t = kAΔT/L = 385×0.002×60/0.5 = 92.4 W.' },
    { q: 'Why do metal spoons feel colder to touch than wooden ones at the same room temperature?', a: 'Metal has much higher thermal conductivity, so it conducts heat away from your hand much faster than wood, feeling colder even though both are at the same temperature.' },
    { q: 'A wall has half the thickness of another identical wall. How does the rate of heat conduction compare?', a: 'Q/t ∝ 1/L, so halving the thickness DOUBLES the rate of heat loss.' },
  ],
  convection: [
    { q: 'Explain, using convection, why a radiator is placed near the floor rather than the ceiling.', a: 'Air warmed by the radiator becomes less dense and rises, setting up a convection current that circulates warm air throughout the whole room from the bottom up.' },
    { q: 'Why does a hot air balloon rise?', a: 'The burner heats the air inside, making it less dense than the surrounding cooler air, so the balloon experiences a net upward (buoyant) force — exactly like a convection current.' },
    { q: 'Why can convection not occur in a solid?', a: 'Convection requires bulk movement of particles; particles in a solid are fixed in place and cannot flow to create a circulation current.' },
  ],
  radiation: [
    { q: 'A black surface of area 0.01m² at 500K radiates into surroundings at 300K. Find the net power radiated. (σ = 5.67×10⁻⁸ W/m²K⁴, ε=1)', a: 'P = εσA(T⁴−T₀⁴) = 5.67e-8×0.01×(500⁴−300⁴) = 5.67e-10×(6.25e10−8.1e9) ≈ 30.7 W.' },
    { q: 'Why are the pipes of a solar water heater usually painted matte black?', a: 'Matte black surfaces are excellent absorbers of radiation, maximising the energy absorbed from sunlight to heat the water.' },
    { q: 'A star doubles in absolute temperature. By what factor does its radiated power increase?', a: 'P ∝ T⁴, so doubling T increases power by 2⁴ = 16 times.' },
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

export default function HeatTransferPage() {
  const [mode, setMode] = useState<HeatMode>('conduction');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [hotTemp, setHotTemp] = useState(90);
  const [coldTemp, setColdTemp] = useState(20);
  const [materialIdx, setMaterialIdx] = useState(0); // Copper by default
  const [areaCm2, setAreaCm2] = useState(20);
  const [lengthCm, setLengthCm] = useState(50);
  const material = MATERIALS[materialIdx];

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, materialIdx, areaCm2, lengthCm, reset]);

  const Thot = celsiusToKelvin(hotTemp), Tcold = celsiusToKelvin(coldTemp);

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
                <p className="text-xs text-gray-400 mb-0.5">Thermal physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Modes of heat transfer</h1>
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
            {(Object.keys(MODE_META) as HeatMode[]).map(m => (
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
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp} materialK={material.k}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/heat"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, hot: hotTemp, cold: coldTemp }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
                <Slider label="Cold / surroundings temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
                {mode === 'conduction' && <>
                  <div className="pt-2 border-t border-gray-100 space-y-1.5">
                    <span className="text-xs text-gray-500">Material</span>
                    <div className="grid grid-cols-2 gap-1.5">
                      {MATERIALS.map((m, i) => (
                        <button key={m.name} onClick={() => setMaterialIdx(i)}
                          className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            materialIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>{m.name}</button>
                      ))}
                    </div>
                    <p className="text-[10px] text-gray-400">k = {material.k} W/mK</p>
                  </div>
                  <Slider label="Cross-sectional area" unit="cm²" value={areaCm2} min={1} max={100} step={1} set={setAreaCm2} color="#8b5cf6" />
                  <Slider label="Rod length" unit="cm" value={lengthCm} min={5} max={150} step={5} set={setLengthCm} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="ΔT" value={(hotTemp - coldTemp).toFixed(0)} unit="°C" color="text-indigo-600" />
                  {mode === 'conduction' && <>
                    <StatRow label="Rate Q/t = kAΔT/L" value={conductionRate(material.k, areaCm2 / 1e4, hotTemp - coldTemp, lengthCm / 100).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Material" value={material.name} unit="" color="text-purple-600" />
                    <StatRow label="Direction" value="hot → cold" unit="always" color="text-amber-600" />
                  </>}
                  {mode === 'radiation' && <>
                    <StatRow label="Hot object radiates" value={radiatedPower(1, 0.01, Thot).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Net transfer" value={netRadiation(1, 0.01, Thot, Tcold).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="T⁴ ratio" value={Math.pow(Thot / Tcold, 4).toFixed(1)} unit="×" color="text-rose-500" />
                  </>}
                  {mode === 'convection' && (
                    <StatRow label="Direction" value="hot → cold" unit="always" color="text-emerald-600" />
                  )}
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

echo "  -> src/app/embed/heat/page.tsx"
cat > "src/app/embed/heat/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { MATERIALS } from '@/lib/physics/heat';

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

function HeatEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): HeatMode => {
    const m = sp.get('mode');
    return m === 'convection' || m === 'radiation' ? m : 'conduction';
  })();
  const showControls = sp.get('controls') !== '0';
  const [hotTemp, setHotTemp] = useState(() => num(sp, 'hot', 90, 30, 120));
  const [coldTemp, setColdTemp] = useState(() => num(sp, 'cold', 20, 0, 40));
  const [materialIdx, setMaterialIdx] = useState(() => {
    const i = MATERIALS.findIndex(m => m.name === sp.get('material'));
    return i >= 0 ? i : 0;
  });
  const material = MATERIALS[materialIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, materialIdx, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp} materialK={material.k}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
          <Slider label="Cold temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
          {mode === 'conduction' && (
            <div className="grid grid-cols-2 gap-1.5">
              {MATERIALS.map((m, i) => (
                <button key={m.name} onClick={() => setMaterialIdx(i)}
                  className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    materialIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m.name}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function HeatEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <HeatEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "Patch v42 applied -- 3 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/heat-transfer -> Conduction tab. You should now"
echo "see a material selector (Copper, Aluminium, Steel, Glass, Brick,"
echo "Wood, Air) plus area/length sliders, and a live 'Rate Q/t' value in"
echo "the Calculated panel. Switching materials should visibly change how"
echo "fast the vibration wave travels along the rod on Run."
