'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { WaveCanvas, WaveMode } from '@/components/simulation/WaveCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { waveSpeed, angularFreq, waveNumber, period } from '@/lib/physics/waves';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<WaveMode, { title: string; icon: string; sub: string; eq: string }> = {
  transverse:    { title: 'Transverse',     icon: '🌊', sub: 'Particles ⊥ to travel',       eq: 'y = A sin(kx − ωt)' },
  longitudinal:  { title: 'Longitudinal',   icon: '🔊', sub: 'Particles ∥ to travel',        eq: 'compressions & rarefactions' },
  superposition: { title: 'Superposition',  icon: '➕', sub: 'Two waves on one string',      eq: 'y = y₁ + y₂' },
  standing:      { title: 'Standing wave',  icon: '🎻', sub: 'Two opposite travelling waves', eq: 'y = 2A sin(kx)cos(ωt)' },
};

const TEACHER_NOTES: Record<WaveMode, string[]> = {
  transverse: [
    'Watch the red particle: it only moves UP and DOWN while the wave pattern moves RIGHT — the wave transports energy, not matter.',
    'v = fλ is the single most examined wave equation. The green bracket marks one wavelength.',
    'Doubling frequency at fixed speed halves the wavelength — try it with the sliders.',
    'Examples: water surface waves, waves on a string, ALL electromagnetic waves.',
    'The particle completes one full oscillation in exactly one period T = 1/f.',
  ],
  longitudinal: [
    'Particles vibrate ALONG the direction of travel — regions bunch up (compressions) and spread out (rarefactions).',
    'Sound is the classic longitudinal wave; it cannot travel through a vacuum because it needs particles.',
    'Wavelength = distance between successive compressions (or rarefactions).',
    'The same v = fλ applies — only the direction of particle vibration differs from transverse.',
    'Seismic P-waves are longitudinal; S-waves are transverse (and cannot pass the liquid outer core).',
  ],
  superposition: [
    'When two waves meet, displacements simply ADD: y = y₁ + y₂ — the principle of superposition.',
    'Same frequency, 0° phase → constructive interference (double amplitude). 180° → destructive (cancellation).',
    'Slightly different frequencies produce BEATS — watch the resultant swell and fade.',
    'The two component waves pass through each other unchanged after overlapping.',
    'This is the foundation of interference, diffraction patterns, and noise-cancelling headphones.',
  ],
  standing: [
    'Two identical waves travelling in OPPOSITE directions superpose into a standing wave: y = 2A sin(kx)cos(ωt).',
    'Nodes (red dots) never move — they are spaced λ/2 apart. Antinodes oscillate with amplitude 2A.',
    'A standing wave transports NO energy — energy is trapped between nodes.',
    'Stringed instruments work on standing waves: fixed ends must be nodes, so only certain λ fit.',
    'Fundamental frequency of a string of length L: λ = 2L, f₁ = v/2L.',
  ],
};

const EXERCISES: Record<WaveMode, { q: string; a: string }[]> = {
  transverse: [
    { q: 'A wave has frequency 50Hz and wavelength 6.8m. Find its speed and period.', a: 'v=fλ=50×6.8=340 m/s. T=1/f=0.02s.' },
    { q: 'Radio waves (v=3×10⁸ m/s) at 100MHz — find the wavelength.', a: 'λ=v/f=3×10⁸/10⁸=3m.' },
    { q: 'A wave crest travels 15m in 3s while a particle completes 6 full oscillations. Find λ.', a: 'v=15/3=5 m/s. f=6/3=2Hz. λ=v/f=2.5m.' },
  ],
  longitudinal: [
    { q: 'Sound travels 660m in 2s. Adjacent compressions are 1.1m apart. Find the frequency.', a: 'v=660/2=330 m/s. λ=1.1m. f=v/λ=300Hz.' },
    { q: 'Why can light reach us from the Sun but sound cannot?', a: 'Light (transverse EM wave) needs no medium; sound (longitudinal mechanical) needs particles to compress — space is a vacuum.' },
    { q: 'An echo returns 0.6s after a clap, with v=340 m/s. How far is the wall?', a: 'Total path=340×0.6=204m. Distance=204/2=102m.' },
  ],
  superposition: [
    { q: 'Two waves of amplitude 3cm meet in phase. What is the resultant amplitude? And at 180°?', a: 'In phase: 3+3=6cm (constructive). Antiphase: 3−3=0 (destructive).' },
    { q: 'Two tuning forks of 256Hz and 260Hz sound together. What beat frequency is heard?', a: 'f_beat=|f₁−f₂|=4Hz — 4 loud-soft cycles per second.' },
    { q: 'State the principle of superposition.', a: 'When two or more waves meet at a point, the resultant displacement equals the vector sum of the individual displacements.' },
  ],
  standing: [
    { q: 'Adjacent nodes of a standing wave are 0.4m apart. Find the wavelength.', a: 'Node spacing=λ/2 → λ=0.8m.' },
    { q: 'A 0.6m string fixed at both ends vibrates in its fundamental mode with v=120 m/s. Find f₁.', a: 'λ=2L=1.2m. f₁=v/λ=120/1.2=100Hz.' },
    { q: 'How is a standing wave different from a travelling wave?', a: 'Standing: fixed nodes/antinodes, no energy transport, amplitude varies with position. Travelling: pattern moves, transports energy, every point oscillates with the same amplitude.' },
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

export default function WavesPage() {
  const [mode, setMode] = useState<WaveMode>('transverse');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [A, setA] = useState(1);
  const [f, setF] = useState(0.5);
  const [lambda, setLambda] = useState(2);
  const [A2, setA2] = useState(0.7);
  const [f2, setF2] = useState(0.5);
  const [phase2, setPhase2] = useState(0);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
  }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, A, f, lambda, A2, f2, phase2, reset]);

  const v = waveSpeed(f, lambda);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Wave motion</h1>
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
            {(Object.keys(MODE_META) as WaveMode[]).map(m => (
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
            <span className="text-xs text-gray-400 ml-2">v = fλ</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <WaveCanvas key={resetKey} mode={mode}
                  amplitude={A} frequency={f} wavelength={lambda}
                  amplitude2={A2} frequency2={f2} phase2={phase2}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/waves"
                  title={`${MODE_META[mode].title} wave — A-Factor STEM Studio`}
                  params={{ mode, A, f, lambda, A2, f2, phase2 }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Amplitude" unit="m" value={A} min={0.2} max={1.5} step={0.1} set={setA} color="#6366f1" />
                <Slider label="Frequency" unit="Hz" value={f} min={0.1} max={2} step={0.05} set={setF} color="#f59e0b" note="Slow enough to follow by eye" />
                <Slider label="Wavelength" unit="m" value={lambda} min={0.5} max={4} step={0.1} set={setLambda} color="#10b981" />
                {mode === 'superposition' && <>
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide pt-1">Second wave</p>
                  <Slider label="Amplitude A₂" unit="m" value={A2} min={0.1} max={1.5} step={0.1} set={setA2} color="#8b5cf6" />
                  <Slider label="Frequency f₂" unit="Hz" value={f2} min={0.1} max={2} step={0.05} set={setF2} color="#ef4444" note="Set slightly different from f for beats" />
                  <Slider label="Phase difference" unit="°" value={phase2} min={0} max={360} step={5} set={setPhase2} color="#0ea5e9" note="0° constructive · 180° destructive" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Wave speed v" value={v.toFixed(2)} unit="m/s" color="text-indigo-600" />
                  <StatRow label="Period T" value={period(f).toFixed(2)} unit="s" color="text-emerald-600" />
                  <StatRow label="Angular freq ω" value={angularFreq(f).toFixed(3)} unit="rad/s" color="text-amber-600" />
                  <StatRow label="Wave number k" value={waveNumber(lambda).toFixed(3)} unit="rad/m" color="text-rose-500" />
                  {mode === 'superposition' && <>
                    <StatRow label="Beat frequency" value={Math.abs(f - f2).toFixed(2)} unit="Hz" color="text-purple-600" />
                    <StatRow label="Max resultant" value={(A + A2).toFixed(2)} unit="m" color="text-gray-600" />
                  </>}
                  {mode === 'standing' && <>
                    <StatRow label="Node spacing" value={(lambda / 2).toFixed(2)} unit="m" color="text-purple-600" />
                    <StatRow label="Antinode amp." value={(2 * A).toFixed(2)} unit="m" color="text-gray-600" />
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
