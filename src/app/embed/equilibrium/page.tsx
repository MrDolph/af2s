'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { StaticDynamicCanvas } from '@/components/simulation/StaticDynamicCanvas';
import { ConcurrentForcesCanvas } from '@/components/simulation/ConcurrentForcesCanvas';
import { ParallelForcesCanvas } from '@/components/simulation/ParallelForcesCanvas';
import { FloatingBodyCanvas } from '@/components/simulation/FloatingBodyCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { LIQUIDS, Weight } from '@/lib/physics/equilibrium';

type Topic = 'static-dynamic' | 'concurrent' | 'parallel' | 'floating';

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

function EquilibriumEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'concurrent' || t === 'parallel' || t === 'floating' ? t : 'static-dynamic';
  })();
  const showControls = sp.get('controls') !== '0';

  const [scenario, setScenario] = useState<'static' | 'dynamic'>(() => (sp.get('scenario') === 'dynamic' ? 'dynamic' : 'static'));
  const [sdF1, setSdF1] = useState(() => num(sp, 'f1', 15, 0, 30));
  const [sdF2, setSdF2] = useState(() => num(sp, 'f2', 15, 0, 30));
  const [sdMass, setSdMass] = useState(() => num(sp, 'mass', 5, 1, 20));

  const [magA, setMagA] = useState(() => num(sp, 'magA', 10, 1, 20));
  const [angleA, setAngleA] = useState(() => num(sp, 'angleA', 0, 0, 359));
  const [magB, setMagB] = useState(() => num(sp, 'magB', 10, 1, 20));
  const [angleB, setAngleB] = useState(() => num(sp, 'angleB', 90, 0, 359));

  const [w1Force, setW1Force] = useState(() => num(sp, 'w1f', 20, 0, 50));
  const [w1Pos, setW1Pos] = useState(() => num(sp, 'w1p', -0.6, -2, 2));
  const [w2Force, setW2Force] = useState(() => num(sp, 'w2f', 20, 0, 50));
  const [w2Pos, setW2Pos] = useState(() => num(sp, 'w2p', 0.6, -2, 2));
  const weights: Weight[] = [{ force: w1Force, position: w1Pos }, { force: w2Force, position: w2Pos }];

  const [objDensity, setObjDensity] = useState(() => num(sp, 'density', 600, 100, 12000));
  const [liqIdx, setLiqIdx] = useState(() => Math.round(num(sp, 'liquid', 0, 0, LIQUIDS.length - 1)));
  const [blockHeight, setBlockHeight] = useState(() => num(sp, 'h', 0.2, 0.05, 0.4));
  const liquid = LIQUIDS[liqIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, scenario, sdF1, sdF2, sdMass, magA, angleA, magB, angleB, w1Force, w1Pos, w2Force, w2Pos, objDensity, liqIdx, blockHeight, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'static-dynamic' && (
        <StaticDynamicCanvas key={resetKey} scenario={scenario} f1={sdF1} f2={sdF2} mass={sdMass}
          isRunning={isRunning} isPaused={isPaused} width={640} height={240} />
      )}
      {topic === 'concurrent' && (
        <ConcurrentForcesCanvas key={resetKey} magA={magA} angleA={angleA} magB={magB} angleB={angleB}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'parallel' && (
        <ParallelForcesCanvas key={resetKey} weights={weights}
          isRunning={isRunning} isPaused={isPaused} width={640} height={260} />
      )}
      {topic === 'floating' && (
        <FloatingBodyCanvas key={resetKey} objDensity={objDensity} liquidDensity={liquid.density}
          liquidName={liquid.name} blockHeight={blockHeight}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'static-dynamic' && <>
            <div className="flex gap-2">
              {(['static', 'dynamic'] as const).map(sc => (
                <button key={sc} onClick={() => setScenario(sc)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    scenario === sc ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{sc}</button>
              ))}
            </div>
            <Slider label="Force F1" unit="N" value={sdF1} min={0} max={30} step={0.5} set={setSdF1} color="#10b981" />
            <Slider label="Force F2" unit="N" value={sdF2} min={0} max={30} step={0.5} set={setSdF2} color="#ef4444" />
            <Slider label="Mass" unit="kg" value={sdMass} min={1} max={20} step={0.5} set={setSdMass} color="#6366f1" />
          </>}
          {topic === 'concurrent' && <>
            <Slider label="Force A" unit="N" value={magA} min={1} max={20} step={0.5} set={setMagA} color="#6366f1" />
            <Slider label="Angle A" unit="°" value={angleA} min={0} max={359} step={1} set={setAngleA} color="#818cf8" />
            <Slider label="Force B" unit="N" value={magB} min={1} max={20} step={0.5} set={setMagB} color="#10b981" />
            <Slider label="Angle B" unit="°" value={angleB} min={0} max={359} step={1} set={setAngleB} color="#34d399" />
          </>}
          {topic === 'parallel' && <>
            <Slider label="Weight 1" unit="N" value={w1Force} min={0} max={50} step={1} set={setW1Force} color="#6366f1" />
            <Slider label="Position 1" unit="m" value={w1Pos} min={-2} max={2} step={0.1} set={setW1Pos} color="#818cf8" />
            <Slider label="Weight 2" unit="N" value={w2Force} min={0} max={50} step={1} set={setW2Force} color="#10b981" />
            <Slider label="Position 2" unit="m" value={w2Pos} min={-2} max={2} step={0.1} set={setW2Pos} color="#34d399" />
          </>}
          {topic === 'floating' && <>
            <div className="flex flex-wrap gap-1.5">
              {LIQUIDS.map((l, i) => (
                <button key={l.name} onClick={() => setLiqIdx(i)}
                  className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                    liqIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{l.name}</button>
              ))}
            </div>
            <Slider label="Object density" unit="kg/m³" value={objDensity} min={100} max={12000} step={50} set={setObjDensity} color="#a78bfa" />
            <Slider label="Block height" unit="m" value={blockHeight} min={0.05} max={0.4} step={0.01} set={setBlockHeight} color="#f59e0b" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function EquilibriumEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <EquilibriumEmbedInner />
    </Suspense>
  );
}
