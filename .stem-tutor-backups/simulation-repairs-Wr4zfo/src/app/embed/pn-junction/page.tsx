// src/app/embed/pn-junction/page.tsx
'use client';

import React, { useState } from 'react';
import PnJunctionCanvas from '@/components/simulation/PnJunctionCanvas';
import { MaterialParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/pnJunction';

export default function PnJunctionEmbedPage() {
  const [params, setParams] = useState<MaterialParams>(getPreset('equilibrium'));
  const [activePreset, setActivePreset] = useState('equilibrium');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <div className="max-w-5xl mx-auto">
        <PnJunctionCanvas params={params} width={800} height={480} />

        <div className="mt-4 flex flex-wrap gap-2">
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
      </div>
    </div>
  );
}