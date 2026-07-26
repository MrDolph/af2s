'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { MagneticFieldCanvas, MagneticMode } from '@/components/simulation/MagneticFieldCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'straight-wire' | 'solenoid' | 'motor-effect';

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

function MagneticEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'solenoid' || t === 'motor-effect' ? t : 'straight-wire';
  })();
  const showControls = sp.get('controls') !== '0';

  const [current, setCurrent] = useState(() => num(sp, 'current', 5, 1, 20));
  const [currentOut, setCurrentOut] = useState(() => sp.get('out') !== '0');
  const [turnsPerMetre, setTurnsPerMetre] = useState(() => num(sp, 'turns', 1000, 200, 3000));
  const [fieldB, setFieldB] = useState(() => num(sp, 'field', 0.5, 0.1, 2));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, current, currentOut, turnsPerMetre, fieldB, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <MagneticFieldCanvas key={resetKey} mode={topic as MagneticMode} current={current} currentOut={currentOut}
        turnsPerMetre={turnsPerMetre} fieldB={fieldB}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Current" unit="A" value={current} min={1} max={20} step={1} set={setCurrent} color="#6366f1" />
          <div className="flex gap-2">
            {([true, false] as const).map(v => (
              <button key={String(v)} onClick={() => setCurrentOut(v)}
                className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                  currentOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                }`}>{v ? 'Out ⊙' : 'In ⊗'}</button>
            ))}
          </div>
          {topic === 'solenoid' && (
            <Slider label="Turns per metre" unit="n/m" value={turnsPerMetre} min={200} max={3000} step={100} set={setTurnsPerMetre} color="#f59e0b" />
          )}
          {topic === 'motor-effect' && (
            <Slider label="Field strength" unit="T" value={fieldB} min={0.1} max={2} step={0.1} set={setFieldB} color="#f59e0b" />
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function MagneticEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <MagneticEmbedInner />
    </Suspense>
  );
}
