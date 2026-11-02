'use client';
import { Suspense, useState, useRef, useEffect, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import { pendulumOmega, springOmega, physicalPendulumPeriod } from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

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

function OscillationsEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'spring' || t === 'conical' || t === 'physical' ? t : 'pendulum';
  })();
  const showGraph = sp.get('graph') !== '0' && topic !== 'conical';
  // Hide the parameter panel with &controls=0 for a locked, view-only embed.
  const showControls = sp.get('controls') !== '0';
  const initialGraphMode = ((): GraphMode => {
    const gmode = sp.get('gmode');
    return gmode === 'velocity' || gmode === 'acceleration' || gmode === 'energy' || gmode === 'phase'
      ? gmode : 'displacement';
  })();

  // Query params seed the INITIAL values; the sliders make the embed fully
  // interactive so viewers can explore, not just watch.
  const [pendL, setPendL] = useState(() => num(sp, 'L', 1.0, 0.1, 3));
  const [pendA, setPendA] = useState(() => num(sp, 'A', 15, 2, 30));
  const [pendG, setPendG] = useState(() => num(sp, 'g', 9.81, 1.6, 25));
  const [pendM, setPendM] = useState(() => num(sp, 'm', 0.5, 0.1, 2));
  const [spK, setSpK] = useState(() => num(sp, 'k', 50, 5, 500));
  const [spM, setSpM] = useState(() => num(sp, 'm', 1.0, 0.1, 5));
  const [spA, setSpA] = useState(() => num(sp, 'A', 0.1, 0.01, 0.3));
  const [conL, setConL] = useState(() => num(sp, 'L', 0.8, 0.2, 2));
  const [conTheta, setConTheta] = useState(() => num(sp, 'theta', 30, 5, 75));
  const [conM, setConM] = useState(() => num(sp, 'm', 0.3, 0.1, 1));
  const [physL, setPhysL] = useState(() => num(sp, 'L', 1.0, 0.2, 2));
  const [physM, setPhysM] = useState(() => num(sp, 'm', 0.5, 0.1, 2));
  const [physPF, setPhysPF] = useState(() => num(sp, 'pf', 0, 0, 0.45));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [graphMode, setGraphMode] = useState<GraphMode>(initialGraphMode);
  const [currentT, setCurrentT] = useState(0);

  const lastTickRef = useRef(0);
  const handleTick = (t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  };

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  // Changing any parameter stops the current run and resets.
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, reset]);

  // Graph omega/A must match what the canvas actually animates so the live
  // dot on the curve tracks the bob/mass/rod exactly (see oscillations page).
  const physD = Math.abs(physL / 2 - physPF * physL) < 0.001 ? 0.001 : Math.abs(physL / 2 - physPF * physL);
  const physI = physM * physL * physL / 12 + physM * physD * physD;
  const physT = physicalPendulumPeriod(physI, physM, physD);
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA :
                 topic === 'physical' ? 0.25 : 0.2;
  const graphOmega = topic === 'pendulum' ? pendulumOmega(pendL, pendG) :
                     topic === 'spring' ? springOmega(spK, spM) :
                     topic === 'physical' ? 2 * Math.PI / physT : 2;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM :
                 topic === 'physical' ? physM : 1;
  const graphK = topic === 'pendulum' ? pendM * graphOmega * graphOmega :
                 topic === 'spring' ? spK :
                 graphM * graphOmega * graphOmega;

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
        {topic === 'pendulum' && (
          <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA} gravity={pendG} mass={pendM}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={380} height={280} />
        )}
        {topic === 'spring' && (
          <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={280} height={300} />
        )}
        {topic === 'conical' && (
          <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta} mass={conM}
            isRunning={isRunning} isPaused={isPaused} width={380} height={280} />
        )}
        {topic === 'physical' && (
          <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM} pivotFraction={physPF}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={380} height={280} />
        )}
      </div>

      <SimulationControls
        isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)}
        onReset={reset}
      />

      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {topic === 'pendulum' && <>
              <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
              <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" />
              <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" />
              <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" />
            </>}
            {topic === 'spring' && <>
              <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
              <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
              <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" />
            </>}
            {topic === 'conical' && <>
              <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
              <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
              <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
            </>}
            {topic === 'physical' && <>
              <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
              <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
              <Slider label="Pivot (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" />
            </>}
          </div>
        </div>
      )}

      {showGraph && (
        <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
          <div className="mb-2 flex gap-1 overflow-x-auto rounded-lg bg-gray-100 p-0.5">
            {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
              <button key={gm} onClick={() => setGraphMode(gm)}
                className={`shrink-0 rounded-md px-2.5 py-1 text-[10px] font-medium transition ${
                  graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                }`}>
                {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase'}
              </button>
            ))}
          </div>
          <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK} mode={graphMode} currentT={currentT} />
        </div>
      )}

      <p className="text-center text-[10px] text-gray-400">
        Powered by{' '}
        <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
          A-Factor STEM Studio
        </a>
      </p>
    </div>
  );
}

export default function OscillationsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <OscillationsEmbedInner />
    </Suspense>
  );
}
