'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DiffractionCanvas, DiffractionMode } from '@/components/simulation/DiffractionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { firstMinimumAngle, spreadFraction, maxGratingOrder } from '@/lib/physics/diffraction';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<DiffractionMode, { title: string; icon: string; sub: string; eq: string }> = {
  'single-slit': { title: 'Single slit', icon: '🌊', sub: 'Spreading through a gap', eq: 'sinθ = λ/a' },
  grating:       { title: 'Diffraction grating', icon: '🎨', sub: 'Multiple slits — spectral orders', eq: 'd sinθ = nλ' },
};

const TEACHER_NOTES: Record<DiffractionMode, string[]> = {
  'single-slit': [
    'Diffraction is the spreading of a wave as it passes through a gap or around an edge — it happens to ALL waves (sound, water, light), not just light.',
    'The amount of spreading depends on the ratio λ/a (wavelength ÷ gap width). When the gap is comparable to or smaller than the wavelength, spreading is dramatic; when the gap is much bigger than the wavelength, the wave carries on mostly straight through.',
    'This is why you can hear someone through an open doorway even when you can\u2019t see them — sound wavelengths (metres) are comparable to doorway widths, so sound diffracts strongly, while light wavelengths (hundreds of nanometres) are far too small to diffract noticeably at that gap.',
    'The first minimum either side of the central bright band occurs at sinθ = λ/a — this is the standard single-slit diffraction formula at this level.',
    'Diffraction is direct evidence that light behaves as a WAVE — a stream of simple particles travelling in straight lines would never spread out behind a gap.',
  ],
  grating: [
    'A diffraction grating is many equally-spaced slits close together. Light from every slit interferes, producing sharp, bright fringes only at specific angles — far sharper than a single or double slit.',
    'Grating equation: d·sinθ = nλ, where d is the spacing between adjacent slits and n is the "order" (0, ±1, ±2, …).',
    'The n=0 order is undeviated (straight through, θ=0°) for ANY wavelength — this is why the central fringe of white light through a grating is white, not spread into a spectrum.',
    'Because sinθ depends on λ, different colours diffract to different angles for the same order — this is how gratings are used to split light into a spectrum in a spectrometer.',
    'Gratings with more lines per millimetre have a SMALLER slit spacing d, which — from the grating equation — spreads the orders out to LARGER angles.',
  ],
};

const EXERCISES: Record<DiffractionMode, { q: string; a: string }[]> = {
  'single-slit': [
    { q: 'Light of wavelength 600nm passes through a slit of width 1200nm. Find the angle to the first minimum.', a: 'sinθ = λ/a = 600/1200 = 0.5 → θ = 30°.' },
    { q: 'Explain why radio waves diffract strongly around hills but light does not.', a: 'Radio wavelengths can be metres to kilometres long — comparable to or bigger than a hill — so they diffract strongly. Light wavelengths (~500nm) are millions of times smaller than a hill, so diffraction around it is negligible.' },
    { q: 'A slit is made narrower while the wavelength stays the same. What happens to the diffraction pattern?', a: 'The λ/a ratio increases, so the central maximum and the angle to the first minimum both get WIDER — more spreading.' },
  ],
  grating: [
    { q: 'A grating has 400 lines per millimetre. Find the slit spacing d in nanometres.', a: 'd = 1mm/400 = 1/400 mm = 2500nm.' },
    { q: 'Using d=2000nm and λ=500nm, find the angle of the first-order (n=1) maximum.', a: 'sinθ = nλ/d = 500/2000 = 0.25 → θ = 14.5°.' },
    { q: 'Why does white light passed through a grating produce a spectrum at each order (except n=0)?', a: 'Each wavelength satisfies d sinθ = nλ at a different angle θ (since λ differs), so red, green, blue etc. all diffract to slightly different angles for the same order, spreading white light into its component colours — except at n=0, where sinθ=0 works for every λ, so all colours overlap and stay white.' },
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

export default function DiffractionPage() {
  const [mode, setMode] = useState<DiffractionMode>('single-slit');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [wavelengthNm, setWavelengthNm] = useState(550);
  const [slitWidthNm, setSlitWidthNm] = useState(1000);
  const [slitSpacingNm, setSlitSpacingNm] = useState(2000);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const minAngle = firstMinimumAngle(wavelengthNm, slitWidthNm);
  const spread = spreadFraction(wavelengthNm, slitWidthNm);
  const maxOrder = maxGratingOrder(wavelengthNm, slitSpacingNm);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Diffraction</h1>
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
            {(Object.keys(MODE_META) as DiffractionMode[]).map(m => (
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
                <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/diffraction"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, wavelength: wavelengthNm, width: slitWidthNm, spacing: slitSpacingNm }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Wavelength" unit="nm" value={wavelengthNm} min={400} max={700} step={10} set={setWavelengthNm} color="#6366f1" note="Visible light range" />
                {mode === 'single-slit' && (
                  <Slider label="Slit width (a)" unit="nm" value={slitWidthNm} min={200} max={3000} step={50} set={setSlitWidthNm} color="#f59e0b"
                    note="Narrower slit (or longer wavelength) → more spreading" />
                )}
                {mode === 'grating' && (
                  <Slider label="Slit spacing (d)" unit="nm" value={slitSpacingNm} min={500} max={5000} step={50} set={setSlitSpacingNm} color="#f59e0b"
                    note="Smaller spacing → orders spread to wider angles" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'single-slit' && <>
                    <StatRow label="λ/a ratio" value={(wavelengthNm / slitWidthNm).toFixed(3)} unit="" color="text-indigo-600" />
                    <StatRow label="First minimum" value={minAngle === null ? 'none (λ>a)' : minAngle.toFixed(1)} unit={minAngle === null ? '' : '°'} color="text-emerald-600" />
                    <StatRow label="Spread fraction" value={(spread * 100).toFixed(0)} unit="%" color="text-amber-600" />
                  </>}
                  {mode === 'grating' && <>
                    <StatRow label="Max order visible" value={`±${maxOrder}`} unit="" color="text-indigo-600" />
                    <StatRow label="n=1 angle" value={maxOrder >= 1 ? (Math.asin(wavelengthNm / slitSpacingNm) * 180 / Math.PI).toFixed(1) : '—'} unit={maxOrder >= 1 ? '°' : ''} color="text-emerald-600" />
                    <StatRow label="Lines per mm" value={(1e6 / slitSpacingNm).toFixed(0)} unit="" color="text-purple-600" />
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
