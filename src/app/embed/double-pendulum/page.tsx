'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DoublePendulumCanvas } from '@/components/simulation/DoublePendulumCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PendulumParams } from '@/lib/physics/doublePendulum';

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

function DoublePendulumEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [m1, setM1] = useState(() => num(sp, 'm1', 1, 0.1, 3));
  const [m2, setM2] = useState(() => num(sp, 'm2', 1, 0.1, 3));
  const [L1, setL1] = useState(() => num(sp, 'L1', 1, 0.3, 2));
  const [L2, setL2] = useState(() => num(sp, 'L2', 1, 0.3, 2));
  const [theta1Deg, setTheta1Deg] = useState(() => num(sp, 't1', 90, -180, 180));
  const [theta2Deg, setTheta2Deg] = useState(() => num(sp, 't2', 90, -180, 180));
  const [omega1, setOmega1] = useState(() => num(sp, 'w1', 0, -5, 5));
  const [omega2, setOmega2] = useState(() => num(sp, 'w2', 0, -5, 5));
  const [damping, setDamping] = useState(() => num(sp, 'damping', 0, 0, 0.5));
  const [trailLength, setTrailLength] = useState(() => Math.round(num(sp, 'trail', 300, 0, 800)));
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);

  const params: PendulumParams = { m1, m2, L1, L2, g: 9.81, damping };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DoublePendulumCanvas
        key={resetKey}
        theta1Deg={theta1Deg}
        omega1Init={omega1}
        theta2Deg={theta2Deg}
        omega2Init={omega2}
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
          <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={3} step={0.1} set={setM1} color="#6366f1" />
          <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={3} step={0.1} set={setM2} color="#f59e0b" />
          <Slider label="Length L₁" unit="m" value={L1} min={0.3} max={2} step={0.1} set={setL1} color="#818cf8" />
          <Slider label="Length L₂" unit="m" value={L2} min={0.3} max={2} step={0.1} set={setL2} color="#fbbf24" />
          <Slider label="Angle θ₁" unit="°" value={theta1Deg} min={-180} max={180} step={1} set={setTheta1Deg} color="#a78bfa" />
          <Slider label="Angle θ₂" unit="°" value={theta2Deg} min={-180} max={180} step={1} set={setTheta2Deg} color="#fcd34d" />
          <Slider label="Damping" unit="" value={damping} min={0} max={0.5} step={0.01} set={setDamping} color="#ef4444" />
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

export default function DoublePendulumEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DoublePendulumEmbedInner />
    </Suspense>
  );
}
