'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function ToggleChip({ label, active, onClick, color }: { label: string; active: boolean; onClick: () => void; color: string }) {
  return (
    <button onClick={onClick}
      className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
        active ? 'border-transparent text-white' : 'border-gray-200 bg-white text-gray-400'
      }`}
      style={active ? { backgroundColor: color } : undefined}>
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${active ? 'bg-white' : 'bg-gray-300'}`} />
      {label}
    </button>
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

function FrictionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): FrictionMode => (sp.get('mode') === 'incline' ? 'incline' : 'flat'))();
  const showControls = sp.get('controls') !== '0';

  const [mass, setMass] = useState(() => num(sp, 'mass', 5, 1, 20));
  const [applied, setApplied] = useState(() => num(sp, 'applied', 25, 0, 80));
  const [angle, setAngle] = useState(() => num(sp, 'angle', 35, 0, 60));
  const [appliedIncline, setAppliedIncline] = useState(() => num(sp, 'push', 0, 0, 100));
  const [muS, setMuS] = useState(() => num(sp, 'muS', 0.4, 0.05, 1));
  const [muK, setMuK] = useState(() => num(sp, 'muK', 0.3, 0.05, 1));

  const [showWeight, setShowWeight] = useState(true);
  const [showComponents, setShowComponents] = useState(true);
  const [showNormal, setShowNormal] = useState(true);
  const [showFriction, setShowFriction] = useState(true);
  const [showApplied, setShowApplied] = useState(true);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mass, applied, angle, appliedIncline, muS, muK, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
        appliedIncline={appliedIncline} muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
        showWeight={showWeight} showComponents={showComponents} showNormal={showNormal}
        showFriction={showFriction} showApplied={showApplied}
        width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <>
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Show forces</p>
            <div className="flex flex-wrap gap-1.5">
              <ToggleChip label="Weight (mg)" active={showWeight} onClick={() => setShowWeight(v => !v)} color="#8b5cf6" />
              {mode === 'incline' && (
                <ToggleChip label="Components" active={showComponents} onClick={() => setShowComponents(v => !v)} color="#a855f7" />
              )}
              <ToggleChip label="Normal (N)" active={showNormal} onClick={() => setShowNormal(v => !v)} color="#3b82f6" />
              <ToggleChip label="Friction (f)" active={showFriction} onClick={() => setShowFriction(v => !v)} color="#ef4444" />
              <ToggleChip label="Applied (F)" active={showApplied} onClick={() => setShowApplied(v => !v)} color="#059669" />
            </div>
          </div>
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
            <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
            {mode === 'flat'
              ? <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
              : <>
                  <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                  <Slider label="Push up-slope" unit="N" value={appliedIncline} min={0} max={100} step={1} set={setAppliedIncline} color="#059669" />
                </>}
            <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
            <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" />
          </div>
        </>
      )}
      <PoweredBy />
    </div>
  );
}

export default function FrictionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <FrictionEmbedInner />
    </Suspense>
  );
}
