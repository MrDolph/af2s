'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
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

function HeatEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): HeatMode => {
    const m = sp.get('mode');
    return m === 'convection' || m === 'radiation' ? m : 'conduction';
  })();
  const showControls = sp.get('controls') !== '0';
  const [hotTemp, setHotTemp] = useState(() => num(sp, 'hot', 90, 30, 120));
  const [coldTemp, setColdTemp] = useState(() => num(sp, 'cold', 20, 0, 40));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
          <Slider label="Cold temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
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
