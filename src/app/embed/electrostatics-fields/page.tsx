'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CoulombsLawCanvas } from '@/components/simulation/CoulombsLawCanvas';
import { ElectricFieldCanvas, FieldConfiguration } from '@/components/simulation/ElectricFieldCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'coulomb' | 'field';

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

function ElectrostaticsFieldsEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => (sp.get('topic') === 'field' ? 'field' : 'coulomb'))();
  const showControls = sp.get('controls') !== '0';

  const [q1nC, setQ1nC] = useState(() => num(sp, 'q1', 20, -50, 50));
  const [q2nC, setQ2nC] = useState(() => num(sp, 'q2', 20, -50, 50));
  const [separationCm, setSeparationCm] = useState(() => num(sp, 'sep', 10, 5, 30));

  const [fieldConfig, setFieldConfig] = useState<FieldConfiguration>(() => {
    const c = sp.get('config');
    return c === 'single-negative' || c === 'dipole' || c === 'like-charges' ? c : 'single-positive';
  });
  const [testX] = useState(0.75);
  const [testY] = useState(0.3);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, q1nC, q2nC, separationCm, fieldConfig, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'coulomb' && (
        <CoulombsLawCanvas key={resetKey} q1nC={q1nC} q2nC={q2nC} initialSeparationCm={separationCm}
          isRunning={isRunning} isPaused={isPaused} width={640} height={260} />
      )}
      {topic === 'field' && (
        <ElectricFieldCanvas key={resetKey} configuration={fieldConfig} testX={testX} testY={testY}
          isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'coulomb' && <>
            <Slider label="Charge Q1" unit="nC" value={q1nC} min={-50} max={50} step={5} set={setQ1nC} color="#dc2626" />
            <Slider label="Charge Q2" unit="nC" value={q2nC} min={-50} max={50} step={5} set={setQ2nC} color="#2563eb" />
            <Slider label="Initial separation" unit="cm" value={separationCm} min={5} max={30} step={1} set={setSeparationCm} color="#6366f1" />
          </>}
          {topic === 'field' && (
            <div className="grid grid-cols-2 gap-2">
              {([
                ['single-positive', 'Single +'], ['single-negative', 'Single −'],
                ['dipole', 'Dipole (+/−)'], ['like-charges', 'Like charges'],
              ] as [FieldConfiguration, string][]).map(([cfg, label]) => (
                <button key={cfg} onClick={() => setFieldConfig(cfg)}
                  className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    fieldConfig === cfg ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{label}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElectrostaticsFieldsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElectrostaticsFieldsEmbedInner />
    </Suspense>
  );
}
