// src/app/embed/pn-junction/page.tsx
'use client';
import { useRef as useEmbedRef } from 'react';
import { useResponsiveCanvasSize as useEmbedSize } from '@/hooks/useResponsiveCanvasSize';
import { SimulationStage } from '@/components/simulation/SimulationStage';


import React, { useState } from 'react';
import PnJunctionCanvas from '@/components/simulation/PnJunctionCanvas';
import { MaterialParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/pnJunction';

export default function PnJunctionEmbedPage() {
  const embedBoxRef = useEmbedRef<HTMLDivElement>(null);
  const embedSize = useEmbedSize(embedBoxRef, 640, 360, 1100);

  const [params, setParams] = useState<MaterialParams>(getPreset('equilibrium'));
  const [activePreset, setActivePreset] = useState('equilibrium');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <SimulationStage containerRef={embedBoxRef} className="af-embed-stage af-stage-dark mx-auto max-w-4xl space-y-3 p-3 sm:p-4">
        <div data-stage-role="canvas"><PnJunctionCanvas params={params} width={Math.max(160, embedSize.width - 24)} height={Math.round((Math.max(160, embedSize.width - 24)) / (embedSize.width < 600 ? Math.min(1.6666666666666667, 1.6) : 1.6666666666666667))} /></div>

        <div data-stage-role="parameters" className="mt-4 flex flex-wrap gap-2">
          {PRESET_NAMES.map(name => (
            <button
              key={name}
              onClick={() => applyPreset(name)}
              className={`px-3 py-1.5 rounded text-xs font-medium transition-colors ${
                activePreset === name
                  ? 'bg-blue-600 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              {PRESET_LABELS[name]}
            </button>
          ))}
        </div>
      </SimulationStage>
    </div>
  );
}