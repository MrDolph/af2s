'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DeBroglieCanvas } from '@/components/simulation/DeBroglieCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PARTICLES } from '@/lib/physics/debroglie';

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

function DeBroglieEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const [pIdx, setPIdx] = useState(() => Math.round(num(sp, 'p', 0, 0, PARTICLES.length - 1)));
  const particle = PARTICLES[pIdx];
  const [velocity, setVelocity] = useState(() => num(sp, 'v', particle.vDefault, particle.vMin, particle.vMax));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pIdx, velocity, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DeBroglieCanvas mass={particle.mass} velocity={velocity} particleName={particle.name}
        isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="flex flex-wrap gap-1.5">
            {PARTICLES.map((p, i) => (
              <button key={p.name} onClick={() => { setPIdx(i); setVelocity(p.vDefault); }}
                className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                  pIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                }`}>{p.emoji} {p.name}</button>
            ))}
          </div>
          <Slider label="Speed" unit="m/s" value={velocity} min={particle.vMin} max={particle.vMax}
            step={(particle.vMax - particle.vMin) / 200} set={setVelocity} color="#6366f1" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DeBroglieEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DeBroglieEmbedInner />
    </Suspense>
  );
}
