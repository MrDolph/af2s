'use client';
import { Suspense, useState, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { BandTheoryCanvas } from '@/components/simulation/BandTheoryCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { BandTheoryParams, DopingType, MATERIALS } from '@/lib/physics/bandTheory';

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

function BandTheoryEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [material, setMaterial] = useState(() => str(sp, 'mat', 'silicon', Object.keys(MATERIALS)));
  const [temperature, setTemperature] = useState(() => num(sp, 'T', 300, 0, 1000));
  const [dopingType, setDopingType] = useState<DopingType>(() => str(sp, 'dopant', 'intrinsic', ['intrinsic', 'n-type', 'p-type'] as DopingType[]));
  const [dopingConcentration, setDopingConcentration] = useState(() => num(sp, 'conc', 10, 10, 20));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [showElectrons, setShowElectrons] = useState(() => bool(sp, 'e', true));
  const [showHoles, setShowHoles] = useState(() => bool(sp, 'h', true));
  const [showFermiLevel, setShowFermiLevel] = useState(() => bool(sp, 'ef', true));
  const [showBandGap, setShowBandGap] = useState(() => bool(sp, 'eg', true));

  const params: BandTheoryParams = {
    material, temperature, dopingType, dopingConcentration,
    speed, zoom: 1, showElectrons, showHoles, showFermiLevel,
    showBandGap, showThermalEnergy: false, showDOS: false, animateCarriers: true,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey((k) => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="flex gap-1 overflow-x-auto pb-1">
        {Object.entries(MATERIALS).map(([key, m]) => (
          <button key={key} onClick={() => { setMaterial(key); setIsRunning(false); setResetKey((k) => k + 1); }}
            className={`shrink-0 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${material === key ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'}`}>
            {m.symbol}
          </button>
        ))}
      </div>

      <BandTheoryCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} width={640} height={420} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused((p) => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Temperature" unit="K" value={temperature} min={0} max={1000} step={10} set={setTemperature} color="#f43f5e" />
          <Slider label="Doping" unit="log₁₀(cm⁻³)" value={dopingConcentration} min={10} max={20} step={0.5} set={setDopingConcentration} color="#8b5cf6" />
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showElectrons} onChange={(e) => setShowElectrons(e.target.checked)} className="rounded" />Electrons
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showHoles} onChange={(e) => setShowHoles(e.target.checked)} className="rounded" />Holes
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showFermiLevel} onChange={(e) => setShowFermiLevel(e.target.checked)} className="rounded" />Fermi level
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showBandGap} onChange={(e) => setShowBandGap(e.target.checked)} className="rounded" />Band gap
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function BandTheoryEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <BandTheoryEmbedInner />
    </Suspense>
  );
}