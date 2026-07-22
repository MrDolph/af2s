'use client';
import { Suspense, useState, useMemo, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ProjectileModeCanvas, ProjectileMode } from '@/components/simulation/ProjectileModeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import type {
  StandardParams, HorizontalParams, VerticalParams, InclinedParams,
} from '@/lib/physics/projectile-modes';

// Reads a numeric query param with clamping so a hand-edited embed URL can't
// produce a broken simulation.
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

function ProjectileEmbedInner() {
  const sp = useSearchParams();

  const mode = ((): ProjectileMode => {
    const m = sp.get('mode');
    return m === 'horizontal' || m === 'vertical' || m === 'inclined' ? m : 'standard';
  })();

  // Hide the parameter panel with &controls=0 for a locked, view-only embed.
  const showControls = sp.get('controls') !== '0';

  // Query params seed the INITIAL values; the sliders below make the embed
  // fully interactive so viewers can explore, not just watch.
  const [g, setG] = useState(() => num(sp, 'g', 9.81, 1, 25));
  const [v0, setV0] = useState(() => num(sp, 'v0', mode === 'standard' ? 25 : mode === 'horizontal' ? 20 : mode === 'vertical' ? 15 : 20, mode === 'vertical' ? -30 : 1, mode === 'inclined' ? 60 : mode === 'vertical' ? 50 : 100));
  const [angle, setAngle] = useState(() => num(sp, 'angle', 45, 1, 89));
  const [h0, setH0] = useState(() => num(sp, 'h0', 0, 0, 200));
  const [hH, setHH] = useState(() => num(sp, 'h', 30, 1, 200));
  const [iAlpha, setIAlpha] = useState(() => num(sp, 'alpha', 30, 1, 89));
  const [iBeta, setIBeta] = useState(() => num(sp, 'beta', 30, 5, 60));
  const [launchFrom, setLaunchFrom] = useState<'base' | 'top'>(() => (sp.get('launch') === 'top' ? 'top' : 'base'));

  const std: StandardParams   = useMemo(() => ({ v0, angle, g, h0 }), [v0, angle, g, h0]);
  const hrz: HorizontalParams = useMemo(() => ({ v0, h: hH, g }), [v0, hH, g]);
  const vtc: VerticalParams   = useMemo(() => ({ v0, h0, g }), [v0, h0, g]);
  const inc: InclinedParams   = useMemo(
    () => ({ v0, alpha: iAlpha, beta: iBeta, g, launchFrom }),
    [v0, iAlpha, iBeta, g, launchFrom]
  );

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setIsComplete(false);
    setResetKey(k => k + 1);
  }, []);
  const handleComplete = useCallback(() => { setIsComplete(true); setIsRunning(false); }, []);

  // Changing any parameter stops the current run and resets — same behaviour
  // as the full simulation page.
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [v0, angle, g, h0, hH, iAlpha, iBeta, launchFrom, reset]);

  return (
    <div className="mx-auto max-w-3xl space-y-3 p-3 sm:p-4">
      <ProjectileModeCanvas
        key={resetKey}
        mode={mode}
        standard={std} horizontal={hrz} vertical={vtc} inclined={inc}
        isRunning={isRunning} isPaused={isPaused}
        onComplete={handleComplete}
        width={720} height={340}
      />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <SimulationControls
          isRunning={isRunning && !isComplete} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
          onPause={() => setIsPaused(p => !p)}
          onReset={reset}
        />
        {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete</span>}
      </div>

      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Gravity" unit="m/s²" value={g} min={1} max={25} step={0.1} set={setG} color="#10b981" />
            {mode === 'standard' && <>
              <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
              <Slider label="Launch angle" unit="°" value={angle} min={1} max={89} step={1} set={setAngle} color="#f59e0b" />
              <Slider label="Platform height" unit="m" value={h0} min={0} max={120} step={1} set={setH0} color="#8b5cf6" />
            </>}
            {mode === 'horizontal' && <>
              <Slider label="Horizontal speed" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
              <Slider label="Launch height" unit="m" value={hH} min={1} max={200} step={1} set={setHH} color="#8b5cf6" />
            </>}
            {mode === 'vertical' && <>
              <Slider label="Initial velocity (↑ +)" unit="m/s" value={v0} min={-30} max={50} step={1} set={setV0} color="#6366f1" />
              <Slider label="Initial height" unit="m" value={h0} min={0} max={200} step={1} set={setH0} color="#8b5cf6" />
            </>}
            {mode === 'inclined' && <>
              <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={60} step={1} set={setV0} color="#6366f1" />
              <Slider label="α — angle above slope" unit="°" value={iAlpha} min={1} max={89} step={1} set={setIAlpha} color="#f59e0b" />
              <Slider label="β — slope angle" unit="°" value={iBeta} min={5} max={60} step={1} set={setIBeta} color="#ef4444" />
              <div className="space-y-1">
                <span className="text-xs text-gray-500">Launched from</span>
                <div className="flex gap-2">
                  {(['base', 'top'] as const).map(v => (
                    <button key={v} onClick={() => setLaunchFrom(v)}
                      className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                        launchFrom === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>
                      {v === 'base' ? 'Base — up' : 'Top — down'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
          </div>
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

export default function ProjectileEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ProjectileEmbedInner />
    </Suspense>
  );
}
