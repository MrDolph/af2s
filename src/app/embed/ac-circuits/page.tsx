'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'waveform' | 'reactance' | 'rlc-circuit';

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

function ACEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'reactance' || t === 'rlc-circuit' ? t : 'waveform';
  })();
  const showControls = sp.get('controls') !== '0';

  const [vPeak, setVPeak] = useState(() => num(sp, 'v', 20, 5, 50));
  const [frequency, setFrequency] = useState(() => num(sp, 'f', 2, 0.5, 5));
  const [resistance, setResistance] = useState(() => num(sp, 'r', 100, 10, 500));
  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance] = useState(0.5);
  const [capacitance] = useState(10);
  const [rlcFrequency, setRlcFrequency] = useState(50);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, reset]);

  const effFrequency = topic === 'rlc-circuit' ? rlcFrequency : frequency;

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
        vPeak={vPeak} frequency={effFrequency} resistance={resistance}
        component={component} inductance={inductance} capacitance={capacitance * 1e-6}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
          {topic === 'waveform' && (
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
          )}
          {topic === 'reactance' && <>
            <div className="flex gap-2">
              {(['inductor', 'capacitor'] as const).map(c => (
                <button key={c} onClick={() => setComponent(c)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{c}</button>
              ))}
            </div>
            <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
          </>}
          {topic === 'rlc-circuit' && <>
            <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b" />
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ACEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ACEmbedInner />
    </Suspense>
  );
}
