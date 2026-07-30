'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { QuantumTunnelingCanvas } from '@/components/simulation/QuantumTunnelingCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { TunnelingParams, PotentialType } from '@/lib/physics/quantumTunneling';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key);
  return v !== null ? v === '1' : fallback;
}

function str<T extends string>(sp: URLSearchParams, key: string, fallback: T, allowed: T[]): T {
  const v = sp.get(key) as T | null;
  return v && allowed.includes(v) ? v : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="font-normal text-gray-400">{unit}</span>
        </span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

function QuantumTunnelingEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const [potentialType, setPotentialType] = useState<PotentialType>(() => str(sp, 'type', 'barrier', ['barrier', 'well', 'step', 'double', 'triangular'] as PotentialType[]));
  const [particleEnergy, setParticleEnergy] = useState(() => num(sp, 'E', 1, 0.1, 10));
  const [barrierHeight, setBarrierHeight] = useState(() => num(sp, 'V', 2, 0.5, 10));
  const [barrierWidth, setBarrierWidth] = useState(() => num(sp, 'w', 2, 0.5, 10));
  const [barrierPosition, setBarrierPosition] = useState(() => num(sp, 'pos', 25, 10, 45));
  const [packetWidth, setPacketWidth] = useState(() => num(sp, 'sigma', 1.5, 0.5, 4));
  const [particleMass, setParticleMass] = useState(() => num(sp, 'm', 1, 0.2, 20));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [showPotential, setShowPotential] = useState(() => bool(sp, 'pot', true));
  const [showProbability, setShowProbability] = useState(() => bool(sp, 'prob', true));
  const [showRealPart, setShowRealPart] = useState(() => bool(sp, 're', true));
  const [showImaginaryPart, setShowImaginaryPart] = useState(() => bool(sp, 'im', false));
  const [showPhase, setShowPhase] = useState(() => bool(sp, 'phase', false));
  const [showClassical, setShowClassical] = useState(() => bool(sp, 'classical', false));
  const [showEnergyLine, setShowEnergyLine] = useState(() => bool(sp, 'eline', true));
  const [autoRestart, setAutoRestart] = useState(() => bool(sp, 'auto', true));

  const params: TunnelingParams = {
    potentialType, particleEnergy, barrierHeight, barrierWidth, barrierPosition,
    packetWidth, particleMass, speed, zoom: 1,
    showPotential, showProbability, showRealPart, showImaginaryPart,
    showPhase, showClassical, showEnergyLine, autoRestart,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey((k) => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="flex gap-1 overflow-x-auto pb-1">
        {(['barrier', 'well', 'step', 'double', 'triangular'] as PotentialType[]).map((m) => {
          const labels: Record<PotentialType, string> = { barrier: 'Barrier', well: 'Well', step: 'Step', double: 'Double', triangular: 'Triangular' };
          return (
            <button key={m} onClick={() => { setPotentialType(m); setIsRunning(false); setResetKey((k) => k + 1); }}
              className={`shrink-0 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${potentialType === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'}`}>
              {labels[m]}
            </button>
          );
        })}
      </div>

      <QuantumTunnelingCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} width={640} height={420} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused((p) => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Energy" unit="eV" value={particleEnergy} min={0.1} max={10} step={0.1} set={setParticleEnergy} color="#6366f1" />
          <Slider label="Barrier height" unit="eV" value={barrierHeight} min={0.5} max={10} step={0.1} set={setBarrierHeight} color="#fbbf24" />
          <Slider label="Barrier width" unit="Å" value={barrierWidth} min={0.5} max={10} step={0.1} set={setBarrierWidth} color="#f59e0b" />
          <Slider label="Mass" unit="mₑ" value={particleMass} min={0.2} max={20} step={0.1} set={setParticleMass} color="#10b981" />
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showPotential} onChange={(e) => setShowPotential(e.target.checked)} className="rounded" />Potential
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showProbability} onChange={(e) => setShowProbability(e.target.checked)} className="rounded" />|ψ|²
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showRealPart} onChange={(e) => setShowRealPart(e.target.checked)} className="rounded" />Re(ψ)
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showEnergyLine} onChange={(e) => setShowEnergyLine(e.target.checked)} className="rounded" />Energy line
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function QuantumTunnelingEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <QuantumTunnelingEmbedInner />
    </Suspense>
  );
}
