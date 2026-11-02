'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';

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

function OpticsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): OpticsMode => (sp.get('mode') === 'lens' ? 'lens' : 'snell'))();
  const showControls = sp.get('controls') !== '0';

  const [n1, setN1] = useState(() => num(sp, 'n1', 1.0, 1, 2.5));
  const [n2, setN2] = useState(() => num(sp, 'n2', 1.5, 1, 2.5));
  const [theta1, setTheta1] = useState(() => num(sp, 'theta1', 35, 0, 89));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
        focal={focal} objectDist={objectDist} converging={converging}
        width={660} height={320} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {mode === 'snell' && <>
              <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1" />
              <Slider label="n₁ (top)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
              <Slider label="n₂ (bottom)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
            </>}
            {mode !== 'snell' && <>
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
                      {c ? 'Converging' : 'Diverging'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function OpticsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <OpticsEmbedInner />
    </Suspense>
  );
}
