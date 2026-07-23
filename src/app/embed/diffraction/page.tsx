'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DiffractionCanvas, DiffractionMode } from '@/components/simulation/DiffractionCanvas';
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

function DiffractionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): DiffractionMode => (sp.get('mode') === 'grating' ? 'grating' : 'single-slit'))();
  const showControls = sp.get('controls') !== '0';

  const [wavelengthNm, setWavelengthNm] = useState(() => num(sp, 'wavelength', 550, 400, 700));
  const [slitWidthNm, setSlitWidthNm] = useState(() => num(sp, 'width', 1000, 200, 3000));
  const [slitSpacingNm, setSlitSpacingNm] = useState(() => num(sp, 'spacing', 2000, 500, 5000));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
        isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Wavelength" unit="nm" value={wavelengthNm} min={400} max={700} step={10} set={setWavelengthNm} color="#6366f1" />
          {mode === 'single-slit'
            ? <Slider label="Slit width" unit="nm" value={slitWidthNm} min={200} max={3000} step={50} set={setSlitWidthNm} color="#f59e0b" />
            : <Slider label="Slit spacing" unit="nm" value={slitSpacingNm} min={500} max={5000} step={50} set={setSlitSpacingNm} color="#f59e0b" />}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DiffractionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DiffractionEmbedInner />
    </Suspense>
  );
}
