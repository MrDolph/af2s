'use client';
import { useState, useCallback, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { QuantumHarmonicOscillatorCanvas } from '@/components/simulation/QuantumHarmonicOscillatorCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { PRESETS, QHOPreset, normalize, QHOParams } from '@/lib/physics/quantumHarmonicOscillator';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The quantum harmonic oscillator is the most important exactly solvable model in quantum mechanics. Its energy spectrum and wavefunctions appear in every sub-field, from molecular vibrations to quantum field theory.',
  'Energy levels are equally spaced: E_n = ℏω(n + ½). The ground-state energy ℏω/2 is called zero-point energy — a purely quantum effect with no classical analogue.',
  'Wavefunctions are Hermite polynomials multiplied by a Gaussian envelope. The number of nodes equals the quantum number n.',
  'Stationary states (pure n) have time-independent probability densities |ψ_n|². Only superpositions of different n produce time-dependent "motion".',
  'A coherent state is a special superposition that mimics classical oscillation: a Gaussian wave packet that swings back and forth without spreading. It is the quantum state closest to a classical particle.',
  'The classical turning points mark where a classical particle with the same energy would reverse direction. In quantum mechanics, there is non-zero probability of finding the particle beyond these points — quantum tunnelling.',
  'The expectation value ⟨x⟩ (white dot) shows the "average position". For a stationary state it is zero; for superpositions it oscillates, tracking the classical motion.',
];

const EXERCISES = [
  {
    q: 'Run the Ground state preset. Where is the particle most likely to be found? How does this differ from a classical particle at the same energy?',
    a: 'The probability peaks at the centre (x=0). A classical particle with E=½ℏω would be at rest at the bottom of the potential well, but a quantum particle has zero-point energy and is delocalised in a Gaussian packet.',
  },
  {
    q: 'Switch to the First excited state. Why is the probability zero at x=0?',
    a: 'The n=1 wavefunction is odd: ψ_1(x) ∝ x·e^{-x²/2}. It must pass through zero at the origin to maintain odd symmetry, so |ψ|² = 0 there.',
  },
  {
    q: 'Run the 0+1 superposition and enable Re(ψ) and Im(ψ). What happens to the probability density over time? Why?',
    a: 'The probability "sloshes" left and right. The two stationary states have different energies, so they accumulate a relative phase e^{-i(E_1-E_0)t/ℏ} = e^{-iωt}. This interference creates a time-dependent beating pattern.',
  },
  {
    q: 'Compare the 0+1 superposition with the Coherent state (α=2). Both oscillate, but what is the key visual difference?',
    a: 'The 0+1 superposition is a simple two-state interference that distorts as it moves. The coherent state contains many n states weighted just right so the Gaussian shape is preserved — it truly mimics a classical pendulum.',
  },
  {
    q: 'Enable classical turning points and compare the Ground state (n=0) with the Coherent state (α=3). How does the region of significant probability compare to the classical allowed region?',
    a: 'For n=0, the Gaussian tail extends noticeably beyond the turning points — quantum tunnelling is significant. For the large coherent state (α=3), the wave packet stays mostly inside the classical region, matching classical expectations.',
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="text-gray-400 font-normal">{unit}</span>
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => set(Number(e.target.value))}
        className="w-full"
        style={{ accentColor: color }}
      />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: {
  label: string; value: string; unit: string; color: string;
}) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>
        {value} <span className="text-gray-400 font-normal">{unit}</span>
      </span>
    </div>
  );
}

export default function QuantumHarmonicOscillatorPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [selectedPreset, setSelectedPreset] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB']);

  // Coefficients for n = 0..5
  const [c0, setC0] = useState(1);
  const [c1, setC1] = useState(0);
  const [c2, setC2] = useState(0);
  const [c3, setC3] = useState(0);
  const [c4, setC4] = useState(0);
  const [c5, setC5] = useState(0);

  const coeffs = useMemo(() => normalize([c0, c1, c2, c3, c4, c5]), [c0, c1, c2, c3, c4, c5]);

  const [speed, setSpeed] = useState(1);
  const [xMax, setXMax] = useState(5);
  const [eMax, setEMax] = useState(4.5);
  const [nMax, setNMax] = useState(5);
  const [showPotential, setShowPotential] = useState(true);
  const [showEnergyLevels, setShowEnergyLevels] = useState(true);
  const [showProbability, setShowProbability] = useState(true);
  const [showReal, setShowReal] = useState(false);
  const [showImaginary, setShowImaginary] = useState(false);
  const [showClassicalTurning, setShowClassicalTurning] = useState(true);

  const params: QHOParams = {
    speed,
    xMax,
    eMax,
    nMax,
    showPotential,
    showEnergyLevels,
    showProbability,
    showReal,
    showImaginary,
    showClassicalTurning,
  };

  const [liveStats, setLiveStats] = useState({
    energy: 0,
    x: 0,
    x2: 0,
    p: 0,
    p2: 0,
    leftTurn: 0,
    rightTurn: 0,
    maxProb: 0,
  });

  const applyPreset = useCallback((preset: QHOPreset, index: number) => {
    const [nc0, nc1, nc2, nc3, nc4, nc5] = preset.coeffs;
    setC0(nc0); setC1(nc1); setC2(nc2); setC3(nc3); setC4(nc4); setC5(nc5);
    setSpeed(preset.speed);
    setXMax(preset.xMax);
    setEMax(preset.eMax);
    setNMax(preset.nMax);
    setShowPotential(preset.showPotential);
    setShowEnergyLevels(preset.showEnergyLevels);
    setShowProbability(preset.showProbability);
    setShowReal(preset.showReal);
    setShowImaginary(preset.showImaginary);
    setShowClassicalTurning(preset.showClassicalTurning);
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
    setSelectedPreset(null);
    setLiveStats({
      energy: 0, x: 0, x2: 0, p: 0, p2: 0,
      leftTurn: 0, rightTurn: 0, maxProb: 0,
    });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({
      energy: 0, x: 0, x2: 0, p: 0, p2: 0,
      leftTurn: 0, rightTurn: 0, maxProb: 0,
    });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const deltaX = Math.sqrt(Math.max(0, liveStats.x2 - liveStats.x * liveStats.x));
  const deltaP = Math.sqrt(Math.max(0, liveStats.p2 - liveStats.p * liveStats.p));

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Quantum Mechanics — Exactly Solvable Models</p>
                <h1 className="text-lg font-semibold text-gray-900">Quantum Harmonic Oscillator</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map((c) => (
                  <button
                    key={c}
                    onClick={() =>
                      setActiveCurricula((p) =>
                        p.includes(c) ? p.filter((x) => x !== c) : [...p, c]
                      )
                    }
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c)
                        ? CC[c] + ' border-transparent'
                        : 'bg-white text-gray-400 border-gray-200'
                    }`}
                  >
                    {c}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">1-D potential well — Hermite polynomials — coherent states</span>
            <span className="text-sm font-semibold font-mono text-gray-900">Ĥ = p̂²/2m + ½mω²x̂²</span>
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESETS.map((preset, i) => {
              const isActive = selectedPreset === i;
              return (
                <button
                  key={i}
                  onClick={() => applyPreset(preset, i)}
                  className={`shrink-0 rounded-xl border-2 px-3 py-2.5 text-left transition min-w-[200px] ${
                    isActive
                      ? 'bg-indigo-600 border-white text-white shadow-lg'
                      : 'bg-white border-gray-200 text-gray-900 hover:border-indigo-300 hover:shadow-sm'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <p className={`text-xs font-bold ${isActive ? 'text-white' : 'text-indigo-700'}`}>
                      {preset.name}
                    </p>
                    {isActive && <span className="text-xs font-bold ml-2">✓</span>}
                  </div>
                  <p className={`text-[10px] mt-1 leading-relaxed ${isActive ? 'text-indigo-100' : 'text-gray-500'}`}>
                    {preset.description}
                  </p>
                </button>
              );
            })}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <QuantumHarmonicOscillatorCanvas
                  key={resetKey}
                  coeffs={coeffs}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  width={canvasSize.width}
                  height={canvasSize.height}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused((p) => !p)}
                  onReset={reset}
                />
                <EmbedButton
                  path="/embed/quantum-harmonic-oscillator"
                  title="Quantum Harmonic Oscillator — A-Factor STEM Studio"
                  params={{
                    c0, c1, c2, c3, c4, c5,
                    speed, xmax: xMax, emax: eMax,
                    potential: showPotential ? 1 : 0,
                    levels: showEnergyLevels ? 1 : 0,
                    prob: showProbability ? 1 : 0,
                    real: showReal ? 1 : 0,
                    imag: showImaginary ? 1 : 0,
                    turning: showClassicalTurning ? 1 : 0,
                  }}
                />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">State coefficients</p>
                    <Slider label="c₀ (n=0)" unit="" value={c0} min={0} max={1} step={0.01} set={setC0} color="#6366f1" />
                    <Slider label="c₁ (n=1)" unit="" value={c1} min={0} max={1} step={0.01} set={setC1} color="#8b5cf6" />
                    <Slider label="c₂ (n=2)" unit="" value={c2} min={0} max={1} step={0.01} set={setC2} color="#ec4899" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">State coefficients</p>
                    <Slider label="c₃ (n=3)" unit="" value={c3} min={0} max={1} step={0.01} set={setC3} color="#f43f5e" />
                    <Slider label="c₄ (n=4)" unit="" value={c4} min={0} max={1} step={0.01} set={setC4} color="#f59e0b" />
                    <Slider label="c₅ (n=5)" unit="" value={c5} min={0} max={1} step={0.01} set={setC5} color="#10b981" />
                  </div>
                </div>

                <div className="border-t border-gray-100 pt-3 space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <Slider label="Time speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" note="Animation speed factor" />
                    <Slider label="X-range" unit="a" value={xMax} min={3} max={12} step={0.5} set={setXMax} color="#10b981" note="Horizontal axis limit (× characteristic length)" />
                    <Slider label="E-range" unit="ℏω" value={eMax} min={2} max={8} step={0.5} set={setEMax} color="#ef4444" note="Energy axis limit" />
                    <Slider label="Levels shown" unit="" value={nMax} min={1} max={8} step={1} set={setNMax} color="#818cf8" note="Number of energy level lines" />
                  </div>

                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showPotential} onChange={(e) => setShowPotential(e.target.checked)} className="rounded" />
                      Potential V(x)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showEnergyLevels} onChange={(e) => setShowEnergyLevels(e.target.checked)} className="rounded" />
                      Energy levels
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />
                      |ψ|²
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showReal} onChange={(e) => setShowReal(e.target.checked)} className="rounded" />
                      Re(ψ)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showImaginary} onChange={(e) => setShowImaginary(e.target.checked)} className="rounded" />
                      Im(ψ)
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showClassicalTurning} onChange={(e) => setShowClassicalTurning(e.target.checked)} className="rounded" />
                      Classical turning points
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="⟨E⟩" value={liveStats.energy.toFixed(3)} unit="ℏω" color="text-indigo-600" />
                  <StatRow label="⟨x⟩" value={liveStats.x.toFixed(3)} unit="a" color="text-rose-500" />
                  <StatRow label="Δx" value={deltaX.toFixed(3)} unit="a" color="text-blue-500" />
                  <StatRow label="⟨p⟩" value={liveStats.p.toFixed(3)} unit="ℏ/a" color="text-emerald-600" />
                  <StatRow label="Δp" value={deltaP.toFixed(3)} unit="ℏ/a" color="text-purple-600" />
                  <StatRow label="Δx·Δp" value={(deltaX * deltaP).toFixed(3)} unit="ℏ" color="text-amber-600" />
                  <StatRow label="x_turn (left)" value={liveStats.leftTurn.toFixed(2)} unit="a" color="text-indigo-500" />
                  <StatRow label="x_turn (right)" value={liveStats.rightTurn.toFixed(2)} unit="a" color="text-amber-500" />
                  <StatRow label="max |ψ|²" value={liveStats.maxProb.toFixed(3)} unit="" color="text-pink-500" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map((c) => (
                    <span
                      key={c}
                      className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                        activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                      }`}
                    >
                      {c}
                    </span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>
                      {n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button
                        onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2"
                      >
                        <span>
                          <span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}
                        </span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>
                          {ex.a}
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
