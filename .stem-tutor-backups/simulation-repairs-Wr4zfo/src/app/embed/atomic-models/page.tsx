'use client';
import { Suspense, useState, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicParams, AtomicModel } from '@/lib/physics/atomicModels';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}
function bool(sp: URLSearchParams, key: string, fallback: boolean) {
  const v = sp.get(key); return v !== null ? v === '1' : fallback;
}
function str<T extends string>(sp: URLSearchParams, key: string, fallback: T, allowed: T[]): T {
  const v = sp.get(key) as T | null;
  return v && allowed.includes(v) ? v : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number; step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function AtomicModelsEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [model, setModel] = useState<AtomicModel>(() => str(sp, 'model', 'thomson', ['thomson', 'rutherford', 'bohr', 'quantum']));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 1, 0, 3));
  const [zoom, setZoom] = useState(() => num(sp, 'zoom', 1, 0.3, 3));
  const [showOrbits, setShowOrbits] = useState(() => bool(sp, 'orbits', true));
  const [showNucleus, setShowNucleus] = useState(() => bool(sp, 'nucleus', true));
  const [showElectrons, setShowElectrons] = useState(() => bool(sp, 'electrons', true));
  const [showProbability, setShowProbability] = useState(() => bool(sp, 'prob', true));
  const [showEnergyLevels, setShowEnergyLevels] = useState(() => bool(sp, 'levels', true));
  const [showSpectrum, setShowSpectrum] = useState(() => bool(sp, 'spectrum', true));
  const [showLabels, setShowLabels] = useState(() => bool(sp, 'labels', true));
  const [showSpin, setShowSpin] = useState(() => bool(sp, 'spin', false));
  const [showFineStructure, setShowFineStructure] = useState(() => bool(sp, 'fs', false));
  const [showZeeman, setShowZeeman] = useState(() => bool(sp, 'zeeman', false));
  const [magneticField, setMagneticField] = useState(() => num(sp, 'B', 0, 0, 5));
  const [nQuantum, setNQuantum] = useState(() => num(sp, 'n', 1, 1, 4));
  const [lQuantum, setLQuantum] = useState(() => num(sp, 'l', 0, 0, 3));
  const [mQuantum, setMQuantum] = useState(() => num(sp, 'm', 0, -3, 3));
  const [protonCount, setProtonCount] = useState(() => num(sp, 'Z', 1, 1, 92));
  const [alphaEnergy, setAlphaEnergy] = useState(() => num(sp, 'alphaE', 5, 1, 10));

  const params: AtomicParams = {
    model, speed, zoom, showOrbits, showNucleus, showElectrons, showProbability,
    showEnergyLevels, showSpectrum, showLabels, showSpin, showFineStructure, showZeeman,
    magneticField, nQuantum, lQuantum, mQuantum, protonCount, neutronCount: 0,
    electronCount: 1, alphaEnergy,
  };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="flex gap-1 overflow-x-auto pb-1">
        {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map(m => {
          const labels: Record<AtomicModel, string> = { thomson: 'Thomson', rutherford: 'Rutherford', bohr: 'Bohr', quantum: 'Quantum' };
          return (
            <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey(k => k + 1); }}
              className={`shrink-0 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'}`}>
              {labels[m]}
            </button>
          );
        })}
      </div>

      <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />

      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
          <Slider label="Zoom" unit="×" value={zoom} min={0.3} max={3} step={0.1} set={setZoom} color="#10b981" />
          <Slider label="Protons Z" unit="" value={protonCount} min={1} max={92} step={1} set={setProtonCount} color="#fbbf24" />
          {model === 'rutherford' && <Slider label="α energy" unit="MeV" value={alphaEnergy} min={1} max={10} step={0.5} set={setAlphaEnergy} color="#f43f5e" />}
          {model === 'bohr' && showZeeman && <Slider label="B field" unit="T" value={magneticField} min={0} max={5} step={0.1} set={setMagneticField} color="#8b5cf6" />}
          {model === 'quantum' && (
            <>
              <Slider label="n" unit="" value={nQuantum} min={1} max={4} step={1} set={setNQuantum} color="#6366f1" />
              <Slider label="l" unit="" value={lQuantum} min={0} max={nQuantum - 1} step={1} set={setLQuantum} color="#ec4899" />
              <Slider label="m" unit="" value={mQuantum} min={-lQuantum} max={lQuantum} step={1} set={setMQuantum} color="#10b981" />
            </>
          )}
          <div className="flex flex-wrap gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showNucleus} onChange={e => setShowNucleus(e.target.checked)} className="rounded" />Nucleus</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showElectrons} onChange={e => setShowElectrons(e.target.checked)} className="rounded" />Electrons</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showProbability} onChange={e => setShowProbability(e.target.checked)} className="rounded" />Probability</label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showLabels} onChange={e => setShowLabels(e.target.checked)} className="rounded" />Labels</label>
          </div>
        </div>
      )}
      <p className="text-center text-[10px] text-gray-400">Powered by <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">A-Factor STEM Studio</a></p>
    </div>
  );
}

export default function AtomicModelsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <AtomicModelsEmbedInner />
    </Suspense>
  );
}
