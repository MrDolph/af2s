// src/app/embed/mosfet/page.tsx
'use client';

import React, { useState } from 'react';
import { MosfetCanvas } from '@/components/simulation/MosfetCanvas';
import { MosfetParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/mosfet';

export default function MosfetEmbedPage() {
  const [params, setParams] = useState<MosfetParams>(getPreset('cutoff'));
  const [activePreset, setActivePreset] = useState('cutoff');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <div className="max-w-5xl mx-auto">
        <MosfetCanvas
          params={params}
          activeTab="schematic"
          isRunning={true}
          isPaused={false}
          showElectrons={true}
        />

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
