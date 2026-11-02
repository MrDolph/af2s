'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { InductionCanvas, InductionMode } from '@/components/simulation/InductionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'faraday-lenz' | 'ac-generator' | 'transformer';

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

function InductionEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'ac-generator' || t === 'transformer' ? t : 'faraday-lenz';
  })();
  const showControls = sp.get('controls') !== '0';

  const [turns, setTurns] = useState(() => num(sp, 'turns', 8, 2, 20));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 2, 0.5, 5));
  const [magnetPoleOut, setMagnetPoleOut] = useState(true);

  const [genFieldB, setGenFieldB] = useState(0.3);
  const [genArea] = useState(0.02);
  const [genOmega, setGenOmega] = useState(3);

  const [primaryTurns, setPrimaryTurns] = useState(500);
  const [secondaryTurns, setSecondaryTurns] = useState(100);
  const [primaryVoltage] = useState(240);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, turns, speed, magnetPoleOut, genFieldB, genOmega, primaryTurns, secondaryTurns, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <InductionCanvas key={resetKey} mode={topic as InductionMode}
        turns={turns} speed={speed} magnetPoleOut={magnetPoleOut}
        fieldB={genFieldB} coilArea={genArea} omega={genOmega}
        primaryTurns={primaryTurns} secondaryTurns={secondaryTurns} primaryVoltage={primaryVoltage}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'faraday-lenz' && <>
            <Slider label="Coil turns" unit="" value={turns} min={2} max={20} step={1} set={setTurns} color="#6366f1" />
            <Slider label="Oscillation speed" unit="rad/s" value={speed} min={0.5} max={5} step={0.5} set={setSpeed} color="#f59e0b" />
            <div className="flex gap-2">
              {([true, false] as const).map(v => (
                <button key={String(v)} onClick={() => setMagnetPoleOut(v)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    magnetPoleOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{v ? 'N faces coil' : 'S faces coil'}</button>
              ))}
            </div>
          </>}
          {topic === 'ac-generator' && <>
            <Slider label="Field strength" unit="T" value={genFieldB} min={0.1} max={1} step={0.05} set={setGenFieldB} color="#f59e0b" />
            <Slider label="Angular speed" unit="rad/s" value={genOmega} min={1} max={10} step={0.5} set={setGenOmega} color="#8b5cf6" />
          </>}
          {topic === 'transformer' && <>
            <Slider label="Primary turns" unit="" value={primaryTurns} min={50} max={1000} step={50} set={setPrimaryTurns} color="#6366f1" />
            <Slider label="Secondary turns" unit="" value={secondaryTurns} min={50} max={1000} step={50} set={setSecondaryTurns} color="#2563eb" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function InductionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <InductionEmbedInner />
    </Suspense>
  );
}
