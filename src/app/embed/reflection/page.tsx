'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
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

function ReflectionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): ReflectionMode => {
    const m = sp.get('mode');
    return m === 'curved' || m === 'rotation' ? m : 'plane';
  })();
  const showControls = sp.get('controls') !== '0';

  const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 5, 80));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
  const [rotationAngle, setRotationAngle] = useState(() => num(sp, 'angle', 15, -35, 35));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
        focal={focal} objectDist={objectDist} converging={converging}
        rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
        width={660} height={320} />
      {mode === 'rotation' && (
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {mode === 'plane' && (
              <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1" />
            )}
            {mode === 'curved' && <>
              <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
              <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />
              <div className="space-y-1">
                <span className="text-xs text-gray-500">Type</span>
                <div className="flex gap-2">
                  {([true, false] as const).map(c => (
                    <button key={String(c)} onClick={() => setConverging(c)}
                      className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                        converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>
                      {c ? 'Concave' : 'Convex'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
            {mode === 'rotation' && (
              <Slider label="Mirror rotation θ" unit="°" value={rotationAngle} min={-35} max={35} step={1} set={setRotationAngle} color="#6366f1" />
            )}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ReflectionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ReflectionEmbedInner />
    </Suspense>
  );
}
