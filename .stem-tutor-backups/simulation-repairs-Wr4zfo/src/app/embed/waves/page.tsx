'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { WaveCanvas, WaveMode } from '@/components/simulation/WaveCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function WavesEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): WaveMode => {
    const m = sp.get('mode');
    return m === 'longitudinal' || m === 'superposition' || m === 'standing' ? m : 'transverse';
  })();
  const showControls = sp.get('controls') !== '0';

  const [A, setA] = useState(() => num(sp, 'A', 1, 0.2, 1.5));
  const [f, setF] = useState(() => num(sp, 'f', 0.5, 0.1, 2));
  const [lambda, setLambda] = useState(() => num(sp, 'lambda', 2, 0.5, 4));
  const [A2, setA2] = useState(() => num(sp, 'A2', 0.7, 0.1, 1.5));
  const [f2, setF2] = useState(() => num(sp, 'f2', 0.5, 0.1, 2));
  const [phase2, setPhase2] = useState(() => num(sp, 'phase2', 0, 0, 360));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [A, f, lambda, A2, f2, phase2, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <WaveCanvas key={resetKey} mode={mode}
        amplitude={A} frequency={f} wavelength={lambda}
        amplitude2={A2} frequency2={f2} phase2={phase2}
        isRunning={isRunning} isPaused={isPaused} width={660} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Amplitude" unit="m" value={A} min={0.2} max={1.5} step={0.1} set={setA} color="#6366f1" />
            <Slider label="Frequency" unit="Hz" value={f} min={0.1} max={2} step={0.05} set={setF} color="#f59e0b" />
            <Slider label="Wavelength" unit="m" value={lambda} min={0.5} max={4} step={0.1} set={setLambda} color="#10b981" />
            {mode === 'superposition' && <>
              <Slider label="Amplitude A₂" unit="m" value={A2} min={0.1} max={1.5} step={0.1} set={setA2} color="#8b5cf6" />
              <Slider label="Frequency f₂" unit="Hz" value={f2} min={0.1} max={2} step={0.05} set={setF2} color="#ef4444" />
              <Slider label="Phase difference" unit="°" value={phase2} min={0} max={360} step={5} set={setPhase2} color="#0ea5e9" />
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function WavesEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <WavesEmbedInner />
    </Suspense>
  );
}
