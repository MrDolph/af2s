'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

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

function RectilinearEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'eclipse' || t === 'pinhole' ? t : 'shadows';
  })();
  const showControls = sp.get('controls') !== '0';

  const [sourceType, setSourceType] = useState<'point' | 'extended'>(() => (sp.get('src') === 'point' ? 'point' : 'extended'));
  const [sourceRadius, setSourceRadius] = useState(() => num(sp, 'sr', 35, 5, 60));
  const [objectRadius, setObjectRadius] = useState(() => num(sp, 'or', 24, 8, 50));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'od', 160, 60, 300));
  const [screenDist, setScreenDist] = useState(() => num(sp, 'sd', 420, 100, 560));

  const [eclipseType, setEclipseType] = useState<EclipseType>(() => (sp.get('type') === 'lunar' ? 'lunar' : 'solar'));
  const [orbitalOffset, setOrbitalOffset] = useState(() => num(sp, 'offset', 0, 0, 120));

  const [objectHeight, setObjectHeight] = useState(() => num(sp, 'h', 90, 30, 130));
  const [pinholeObjectDist, setPinholeObjectDist] = useState(() => num(sp, 'u', 140, 60, 260));
  const [pinholeScreenDist, setPinholeScreenDist] = useState(() => num(sp, 'v', 160, 40, 260));
  const [pinholeRadius, setPinholeRadius] = useState(() => num(sp, 'r', 1, 0, 12));

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'shadows' && (
        <ShadowsCanvas sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
          objectDistPx={objectDist} screenDistPx={screenDist} width={640} height={280} />
      )}
      {topic === 'eclipse' && (
        <EclipseCanvas eclipseType={eclipseType} orbitalOffset={orbitalOffset} width={640} height={280} />
      )}
      {topic === 'pinhole' && (
        <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
          pinholeRadiusPx={pinholeRadius} width={640} height={280} />
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'shadows' && <>
            <div className="flex gap-2">
              {(['point', 'extended'] as const).map(t => (
                <button key={t} onClick={() => setSourceType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            {sourceType === 'extended' && (
              <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
            )}
            <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
            <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
            <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
          </>}
          {topic === 'eclipse' && <>
            <div className="flex gap-2">
              {(['solar', 'lunar'] as const).map(t => (
                <button key={t} onClick={() => setEclipseType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            <Slider label="Orbital offset" unit="px" value={orbitalOffset} min={0} max={120} step={2} set={setOrbitalOffset} color="#6366f1" />
          </>}
          {topic === 'pinhole' && <>
            <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
            <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
            <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
            <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function RectilinearEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <RectilinearEmbedInner />
    </Suspense>
  );
}
