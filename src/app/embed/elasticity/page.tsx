'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { WIRE_MATERIALS } from '@/lib/physics/elasticity';

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

function ElasticityEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): ElasticityMode => (sp.get('mode') === 'wire' ? 'wire' : 'hooke'))();
  const showControls = sp.get('controls') !== '0';

  const [load, setLoad] = useState(() => num(sp, 'load', 8, 0, 30));
  const [k, setK] = useState(() => num(sp, 'k', 200, 50, 500));
  const [elasticLimitF, setElasticLimitF] = useState(() => num(sp, 'limit', 15, 5, 25));

  const [matIdx, setMatIdx] = useState(() => Math.round(num(sp, 'mat', 0, 0, WIRE_MATERIALS.length - 1)));
  const [wireLength, setWireLength] = useState(() => num(sp, 'L', 2, 0.5, 5));
  const [wireDiamMm, setWireDiamMm] = useState(() => num(sp, 'd', 0.5, 0.1, 2));
  const [wireLoad, setWireLoad] = useState(() => num(sp, 'F', 60, 5, 200));
  const material = WIRE_MATERIALS[matIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [unloadKey, setUnloadKey] = useState(0);
  const [settled, setSettled] = useState(false);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setSettled(false);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, load, k, elasticLimitF, matIdx, wireLength, wireDiamMm, wireLoad, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ElasticityCanvas key={resetKey} mode={mode}
        load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
        wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
        breakingStressMPa={material.breakingStressMPa}
        isRunning={isRunning} isPaused={isPaused} unloadKey={unloadKey}
        onSettled={() => setSettled(true)}
        width={640} height={320} />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
        {mode === 'hooke' && settled && (
          <button onClick={() => { setUnloadKey(k => k + 1); setSettled(false); }}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
            Remove load
          </button>
        )}
      </div>
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {mode === 'hooke' ? <>
            <Slider label="Load" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
            <Slider label="Spring constant" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
            <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
          </> : <>
            <div className="flex flex-wrap gap-1.5">
              {WIRE_MATERIALS.map((m, i) => (
                <button key={m.name} onClick={() => setMatIdx(i)}
                  className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                    matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m.name}</button>
              ))}
            </div>
            <Slider label="Load" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
            <Slider label="Length" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
            <Slider label="Diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElasticityEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElasticityEmbedInner />
    </Suspense>
  );
}
