// src/app/embed/bjt-transistor/page.tsx
'use client';
import { useRef as useEmbedRef } from 'react';
import { useResponsiveCanvasSize as useEmbedSize } from '@/hooks/useResponsiveCanvasSize';
import { SimulationStage } from '@/components/simulation/SimulationStage';


import React, { useState } from 'react';
import BjtCanvas from '@/components/simulation/BjtCanvas';
import { BjtParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/bjtTransistor';

export default function BjtEmbedPage() {
  const embedBoxRef = useEmbedRef<HTMLDivElement>(null);
  const embedSize = useEmbedSize(embedBoxRef, 640, 360, 1100);

  const [params, setParams] = useState<BjtParams>(getPreset('cutoff'));
  const [activePreset, setActivePreset] = useState('cutoff');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <SimulationStage containerRef={embedBoxRef} className="af-embed-stage af-stage-dark mx-auto max-w-4xl space-y-3 p-3 sm:p-4">
        <div data-stage-role="canvas"><BjtCanvas params={params} width={Math.max(160, embedSize.width - 24)} height={Math.round((Math.max(160, embedSize.width - 24)) / (embedSize.width < 600 ? Math.min(1.6, 1.6) : 1.6))} /></div>

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