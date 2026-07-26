'use client';
import { Suspense, useState, useCallback, useRef, useMemo } from 'react';
import { useSearchParams } from 'next/navigation';
import { QuantumHarmonicOscillatorCanvas } from '@/components/simulation/QuantumHarmonicOscillatorCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { QHOParams, normalize } from '@/lib/physics/quantumHarmonicOscillator';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key);
  return v !== null ? v === '1' : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="font-normal text-gray-400">{unit}</span>
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

function QuantumHOEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [c0, setC0] = useState(() => num(sp, 'c0', 1, 0, 1));
  const [c1, setC1] = useState(() => num(sp, 'c1', 0, 0, 1));
  const [c2, setC2] = useState(() => num(sp, 'c2', 0, 0, 1));
  const [c3, setC3] = useState(() => num(sp, 'c3', 0, 0, 1));
  const [c4, setC4] = useState(() => num(sp, 'c4', 0, 0, 1));
  const [c5, setC5] = useState(() => num(sp, 'c5', 0, 0, 1));

  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [xMax, setXMax] = useState(() => num(sp, 'xmax', 5, 3, 12));
  const [eMax, setEMax] = useState(() => num(sp, 'emax', 4.5, 2, 8));
  const [nMax, setNMax] = useState(() => num(sp, 'nmax', 5, 1, 8));

  const [showPotential, setShowPotential] = useState(() => bool(sp, 'potential', true));
  const [showEnergyLevels, setShowEnergyLevels] = useState(() => bool(sp, 'levels', true));
  const [showProbability, setShowProbability] = useState(() => bool(sp, 'prob', true));
  const [showReal, setShowReal] = useState(() => bool(sp, 'real', false));
  const [showImaginary, setShowImaginary] = useState(() => bool(sp, 'imag', false));
  const [showClassicalTurning, setShowClassicalTurning] = useState(() => bool(sp, 'turning', true));

  const coeffs = useMemo(() => normalize([c0, c1, c2, c3, c4, c5]), [c0, c1, c2, c3, c4, c5]);

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

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => {
    setIsRunning(false);
    setIsPaused(false);
    setResetKey((k) => k + 1);
  }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <QuantumHarmonicOscillatorCanvas
        key={resetKey}
        coeffs={coeffs}
        params={params}
        isRunning={isRunning}
        isPaused={isPaused}
        width={640}
        height={400}
      />
      <SimulationControls
        isRunning={isRunning}
        isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused((p) => !p)}
        onReset={reset}
      />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="c₀" unit="" value={c0} min={0} max={1} step={0.01} set={setC0} color="#6366f1" />
          <Slider label="c₁" unit="" value={c1} min={0} max={1} step={0.01} set={setC1} color="#8b5cf6" />
          <Slider label="c₂" unit="" value={c2} min={0} max={1} step={0.01} set={setC2} color="#ec4899" />
          <Slider label="c₃" unit="" value={c3} min={0} max={1} step={0.01} set={setC3} color="#f43f5e" />
          <Slider label="c₄" unit="" value={c4} min={0} max={1} step={0.01} set={setC4} color="#f59e0b" />
          <Slider label="c₅" unit="" value={c5} min={0} max={1} step={0.01} set={setC5} color="#10b981" />
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <Slider label="X-range" unit="a" value={xMax} min={3} max={12} step={0.5} set={setXMax} color="#10b981" />
          <Slider label="E-range" unit="ℏω" value={eMax} min={2} max={8} step={0.5} set={setEMax} color="#ef4444" />
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showPotential} onChange={(e) => setShowPotential(e.target.checked)} className="rounded" />
              Potential
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showEnergyLevels} onChange={(e) => setShowEnergyLevels(e.target.checked)} className="rounded" />
              Levels
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
              Turning pts
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function QuantumHOEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <QuantumHOEmbedInner />
    </Suspense>
  );
}
