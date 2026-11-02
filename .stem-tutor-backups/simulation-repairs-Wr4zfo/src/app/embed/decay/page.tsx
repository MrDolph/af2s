'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DecayCanvas, DecayGraph } from '@/components/simulation/DecayCanvas';
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

function DecayEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const showGraph = sp.get('graph') !== '0';

  const [n0, setN0] = useState(() => num(sp, 'n0', 400, 50, 900));
  const [halfLife, setHalfLife] = useState(() => num(sp, 'hl', 5, 1, 20));
  const [live, setLive] = useState({ t: 0, n: 400 });

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setLive({ t: 0, n: n0 });
  }, [n0]);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [n0, halfLife, reset]);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number, n: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setLive({ t, n });
    }
  }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DecayCanvas n0={n0} halfLife={halfLife} resetKey={resetKey}
        isRunning={isRunning} isPaused={isPaused} onTick={handleTick}
        width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showGraph && (
        <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
          <DecayGraph n0={n0} halfLife={halfLife} currentT={live.t} currentN={live.n} />
        </div>
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Initial nuclei N₀" unit="" value={n0} min={50} max={900} step={50} set={setN0} color="#6366f1" />
            <Slider label="Half-life T½" unit="s" value={halfLife} min={1} max={20} step={0.5} set={setHalfLife} color="#f59e0b" />
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DecayEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DecayEmbedInner />
    </Suspense>
  );
}
