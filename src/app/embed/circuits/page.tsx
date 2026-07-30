'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CircuitCanvas, CircuitMode, FlowDisplay } from '@/components/simulation/CircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { NonOhmicDevice } from '@/lib/physics/circuits';

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

function CircuitsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): CircuitMode => {
    const m = sp.get('mode');
    return m === 'series' || m === 'parallel' || m === 'non-ohmic' ? m : 'ohm';
  })();
  const showControls = sp.get('controls') !== '0';

  const [V, setV] = useState(() => num(sp, 'V', 12, 1, 24));
  const [r1, setR1] = useState(() => num(sp, 'r1', 4, 1, 50));
  const [r2, setR2] = useState(() => num(sp, 'r2', 6, 1, 50));
  const [r3, setR3] = useState(() => num(sp, 'r3', 12, 1, 50));
  const [nonOhmicDevice, setNonOhmicDevice] = useState<NonOhmicDevice>('filament');
  const [flowDisplay, setFlowDisplay] = useState<FlowDisplay>('electron');

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [V, r1, r2, r3, nonOhmicDevice, flowDisplay, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
        nonOhmicDevice={nonOhmicDevice} flowDisplay={flowDisplay}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <div className="flex items-center gap-2 flex-wrap">
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
        <div className="flex rounded-lg border border-gray-200 overflow-hidden">
          {(['electron', 'conventional'] as const).map(f => (
            <button key={f} onClick={() => setFlowDisplay(f)}
              className={`px-2 py-2 text-xs font-medium transition ${
                flowDisplay === f ? 'bg-indigo-50 text-indigo-700' : 'bg-white text-gray-500'
              }`}>{f === 'electron' ? '● Electron' : '▶ Conventional'}</button>
          ))}
        </div>
      </div>
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
            {mode !== 'non-ohmic' && (
              <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
            )}
            {mode === 'non-ohmic' && (
              <Slider label="Reference R" unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
            )}
            {(mode === 'series' || mode === 'parallel') && <>
              <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
              <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
            </>}
          </div>
          {mode === 'non-ohmic' && (
            <div className="flex gap-1 mt-3">
              {(['filament', 'thermistor', 'diode'] as const).map(d => (
                <button key={d} onClick={() => setNonOhmicDevice(d)}
                  className={`px-2 py-1 rounded-md text-[10px] font-medium capitalize transition ${
                    nonOhmicDevice === d ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-500'
                  }`}>{d}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function CircuitsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <CircuitsEmbedInner />
    </Suspense>
  );
}
