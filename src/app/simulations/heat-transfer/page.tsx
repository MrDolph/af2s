'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { celsiusToKelvin, radiatedPower, netRadiation } from '@/lib/physics/heat';
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

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, reset]);

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
                <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp}
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
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="ΔT" value={(hotTemp - coldTemp).toFixed(0)} unit="°C" color="text-indigo-600" />
                  {mode === 'radiation' && <>
                    <StatRow label="Hot object radiates" value={radiatedPower(1, 0.01, Thot).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Net transfer" value={netRadiation(1, 0.01, Thot, Tcold).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="T⁴ ratio" value={Math.pow(Thot / Tcold, 4).toFixed(1)} unit="×" color="text-rose-500" />
                  </>}
                  {mode !== 'radiation' && (
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
