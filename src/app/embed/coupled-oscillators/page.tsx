'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CoupledOscillatorsCanvas } from '@/components/simulation/CoupledOscillatorsCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { OscillatorParams } from '@/lib/physics/coupledOscillators';

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
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={e => set(Number(e.target.value))}
        className="w-full h-6 py-2 cursor-pointer"
        style={{ accentColor: color }}
      />
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

function CoupledOscillatorsEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [m1, setM1] = useState(() => num(sp, 'm1', 1, 0.1, 5));
  const [m2, setM2] = useState(() => num(sp, 'm2', 1, 0.1, 5));
  const [k1, setK1] = useState(() => num(sp, 'k1', 1, 0.1, 5));
  const [k2, setK2] = useState(() => num(sp, 'k2', 0.2, 0, 5));
  const [k3, setK3] = useState(() => num(sp, 'k3', 1, 0.1, 5));
  const [x1, setX1] = useState(() => num(sp, 'x1', 0.1, -0.3, 0.3));
  const [x2, setX2] = useState(() => num(sp, 'x2', 0.1, -0.3, 0.3));
  const [v1, setV1] = useState(() => num(sp, 'v1', 0, -2, 2));
  const [v2, setV2] = useState(() => num(sp, 'v2', 0, -2, 2));
  const [damping1, setDamping1] = useState(() => num(sp, 'd1', 0, 0, 1));
  const [damping2, setDamping2] = useState(() => num(sp, 'd2', 0, 0, 1));
  const [trailLength, setTrailLength] = useState(() => Math.round(num(sp, 'trail', 300, 0, 800)));
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);

  const params: OscillatorParams = { m1, m2, k1, k2, k3, damping1, damping2 };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <CoupledOscillatorsCanvas
        key={resetKey}
        x1Init={x1}
        v1Init={v1}
        x2Init={x2}
        v2Init={v2}
        params={params}
        isRunning={isRunning}
        isPaused={isPaused}
        showTrail={showTrail}
        showEnergy={showEnergy}
        trailLength={trailLength}
        width={640}
        height={400}
      />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={5} step={0.1} set={setM1} color="#6366f1" />
          <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={5} step={0.1} set={setM2} color="#f59e0b" />
          <Slider label="Spring k₁" unit="N/m" value={k1} min={0.1} max={5} step={0.1} set={setK1} color="#818cf8" />
          <Slider label="Coupling k₂" unit="N/m" value={k2} min={0} max={5} step={0.05} set={setK2} color="#10b981" />
          <Slider label="Spring k₃" unit="N/m" value={k3} min={0.1} max={5} step={0.1} set={setK3} color="#fbbf24" />
          <Slider label="Damping c₁" unit="" value={damping1} min={0} max={1} step={0.01} set={setDamping1} color="#ef4444" />
          <Slider label="Damping c₂" unit="" value={damping2} min={0} max={1} step={0.01} set={setDamping2} color="#ef4444" />
          <Slider label="Trail" unit="frames" value={trailLength} min={0} max={800} step={10} set={setTrailLength} color="#f43f5e" />
          <div className="flex gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showTrail} onChange={e => setShowTrail(e.target.checked)} className="rounded" />
              Show trail
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showEnergy} onChange={e => setShowEnergy(e.target.checked)} className="rounded" />
              Show energy
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function CoupledOscillatorsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <CoupledOscillatorsEmbedInner />
    </Suspense>
  );
}
