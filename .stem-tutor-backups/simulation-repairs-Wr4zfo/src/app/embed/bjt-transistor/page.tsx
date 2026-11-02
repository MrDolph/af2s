// src/app/embed/bjt-transistor/page.tsx
'use client';

import React, { useState } from 'react';
import BjtCanvas from '@/components/simulation/BjtCanvas';
import { BjtParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/bjtTransistor';

export default function BjtEmbedPage() {
  const [params, setParams] = useState<BjtParams>(getPreset('cutoff'));
  const [activePreset, setActivePreset] = useState('cutoff');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <div className="max-w-5xl mx-auto">
        <BjtCanvas params={params} width={800} height={500} />

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