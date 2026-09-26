'use client';
import { useState, useCallback, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { MosfetCanvas } from '@/components/simulation/MosfetCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  MosfetParams, MosfetTopology, MosfetRegion,
  computeMosfetState,
  getPreset,
  PRESET_NAMES,
  PRESET_LABELS,
  REGION_COLORS,
  REGION_DESCRIPTIONS,
  TOPOLOGY_DESCRIPTIONS,
  PRACTICE_PROBLEMS,
} from '@/lib/physics/mosfet';

const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
};

const TEACHER_NOTES = [
  'The MOSFET is the workhorse of modern electronics — billions exist in every smartphone.',
  'Common-Source: High voltage gain (Av = -gm·Rd), 180° phase shift. Most common amplifier topology.',
  'Common-Drain (Source Follower): Gain ≈ 1, very high Zin, low Zout. Used as voltage buffer.',
  'Common-Gate: Low Zin (1/gm), high gain, no Miller effect. Used in RF and high-frequency circuits.',
  'Cutoff: Vgs < Vth — transistor is OFF. Triode: Vds < Vov — acts as voltage-controlled resistor. Saturation: Vds > Vov — used for amplification.',
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number; step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function MosfetPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level']);
  const [mobileControlsOpen, setMobileControlsOpen] = useState(false);

  const [activeTab, setActiveTab] = useState<'schematic' | 'cross-section' | 'characteristics' | 'analysis'>('schematic');
  const [showElectrons, setShowElectrons] = useState(true);

  const [Vgs, setVgs] = useState(2.0);
  const [Vds, setVds] = useState(5.0);
  const [Vth, setVth] = useState(0.7);
  const [temperature, setTemperature] = useState(300);
  const [type, setType] = useState<'nmos' | 'pmos'>('nmos');
  const [W, setW] = useState(10);
  const [L, setL] = useState(1);
  const [tox, setTox] = useState(10);
  const [topology, setTopology] = useState<MosfetTopology>('common-source');
  const [Vdd, setVdd] = useState(10);
  const [Rd, setRd] = useState(2);
  const [Rs, setRs] = useState(0.5);
  const [Rg, setRg] = useState(1);
  const [Rload, setRload] = useState(10);

  const params: MosfetParams = useMemo(() => ({
    Vgs, Vds, Vth, temperature, type, W, L, tox, topology, Vdd, Rd, Rs, Rg, Rload,
  }), [Vgs, Vds, Vth, temperature, type, W, L, tox, topology, Vdd, Rd, Rs, Rg, Rload]);

  const [liveStats, setLiveStats] = useState({
    region: 'cutoff' as MosfetRegion,
    Id: 0, Vgs: 0, Vds: 0, Vov: 0, gm: 0, Av: 0, Zin: 0, Zout: 0, Pdiss: 0,
  });
  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const applyPreset = useCallback((name: string) => {
    const preset = getPreset(name);
    setVgs(preset.Vgs);
    setVds(preset.Vds);
    setVth(preset.Vth);
    setTemperature(preset.temperature);
    setType(preset.type);
    setW(preset.W);
    setL(preset.L);
    setTox(preset.tox);
    setTopology(preset.topology);
    setVdd(preset.Vdd);
    setRd(preset.Rd);
    setRs(preset.Rs);
    setRg(preset.Rg);
    setRload(preset.Rload);
    setIsRunning(false);
    setIsPaused(false);
    setResetKey(k => k + 1);
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false);
    setIsPaused(false);
    setResetKey(k => k + 1);
  }, []);

  const computed = useMemo(() => computeMosfetState(params), [params]);

  const topologyLabels: Record<MosfetTopology, string> = {
    'common-source': 'Common Source',
    'common-drain': 'Common Drain',
    'common-gate': 'Common Gate',
  };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Semiconductor Devices — MOSFET Amplifier Topologies</p>
                <h1 className="text-lg font-semibold text-gray-900">MOSFET Transistor</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {Object.keys(CC).map(c => (
                  <button key={c} onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'}`}>
                    {c}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">NMOS / PMOS — Cutoff → Triode → Saturation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">I_d = ½·k'·(W/L)·V_ov²</span>
          </div>

          {/* Topology selector */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {(['common-source', 'common-drain', 'common-gate'] as MosfetTopology[]).map(t => (
              <button key={t} onClick={() => { setTopology(t); setIsRunning(false); setResetKey(k => k + 1); }}
                className={`shrink-0 rounded-xl border px-4 py-2 text-left hover:shadow-sm transition min-w-[140px] ${topology === t ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}>
                <p className="text-xs font-medium">{topologyLabels[t]}</p>
              </button>
            ))}
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESET_NAMES.map((name) => (
              <button key={name} onClick={() => applyPreset(name)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]">
                <p className="text-xs font-medium text-indigo-700">{PRESET_LABELS[name]}</p>
              </button>
            ))}
          </div>

          {/* Canvas + Controls + Stats grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_240px] xl:grid-cols-[1fr_240px_280px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <MosfetCanvas
                  key={resetKey}
                  params={params}
                  activeTab={activeTab}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  showElectrons={showElectrons}
                  onTick={handleTick}
                />
              </div>

              {/* Tab bar */}
              <div className="flex gap-1 rounded-lg bg-gray-100 p-1">
                {(['schematic', 'cross-section', 'characteristics', 'analysis'] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setActiveTab(tab)}
                    className={`flex-1 rounded-md px-3 py-2 text-xs font-medium capitalize transition ${activeTab === tab ? 'bg-white text-indigo-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>
                    {tab.replace('-', ' ')}
                  </button>
                ))}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                <EmbedButton
                  path="/embed/mosfet"
                  title="MOSFET Transistor"
                  params={{
                    Vgs, Vds, Vth, temp: temperature, type, W, L, tox, topology, Vdd, Rd, Rs, Rg, Rload,
                    tab: activeTab, electrons: showElectrons ? 1 : 0,
                  }}
                />
              </div>

              {/* Mobile controls toggle */}
              <button onClick={() => setMobileControlsOpen(o => !o)} className="lg:hidden w-full py-2.5 text-sm font-medium rounded-xl border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 transition">
                {mobileControlsOpen ? 'Hide controls ▲' : 'Show controls ▼'}
              </button>

              <div className={`rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4 ${mobileControlsOpen ? '' : 'hidden lg:block'}`}>
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">DC Bias</p>
                    <Slider label="Vgs" unit="V" value={Vgs} min={-5} max={5} step={0.1} set={setVgs} color="#6366f1" note="Gate-source voltage" />
                    <Slider label="Vds" unit="V" value={Vds} min={-10} max={10} step={0.1} set={setVds} color="#ec4899" note="Drain-source voltage" />
                    <Slider label="Vth" unit="V" value={Vth} min={-2} max={2} step={0.05} set={setVth} color="#fbbf24" note="Threshold voltage" />
                    <Slider label="Vdd" unit="V" value={Vdd} min={1} max={20} step={0.5} set={setVdd} color="#ef4444" note="Supply voltage" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Circuit</p>
                    <Slider label="Rd" unit="kΩ" value={Rd} min={0.1} max={10} step={0.1} set={setRd} color="#f43f5e" note="Drain resistor" />
                    <Slider label="Rs" unit="kΩ" value={Rs} min={0} max={5} step={0.1} set={setRs} color="#a78bfa" note="Source resistor" />
                    <Slider label="Rg" unit="MΩ" value={Rg} min={0.01} max={10} step={0.1} set={setRg} color="#10b981" note="Gate resistor" />
                    <Slider label="Rload" unit="kΩ" value={Rload} min={0.1} max={50} step={0.5} set={setRload} color="#3b82f6" note="Load resistor" />
                  </div>
                </div>

                <div className="border-t border-gray-100 pt-3">
                  <p className="text-[10px] font-medium text-emerald-600 uppercase tracking-wide mb-2">Device</p>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <Slider label="W" unit="μm" value={W} min={0.1} max={100} step={0.5} set={setW} color="#10b981" note="Channel width" />
                    <Slider label="L" unit="μm" value={L} min={0.05} max={10} step={0.05} set={setL} color="#f59e0b" note="Channel length" />
                    <Slider label="tox" unit="nm" value={tox} min={1} max={50} step={0.5} set={setTox} color="#8b5cf6" note="Oxide thickness" />
                    <Slider label="Temp" unit="K" value={temperature} min={200} max={400} step={5} set={setTemperature} color="#f97316" note="Temperature" />
                  </div>
                </div>

                <div className="border-t border-gray-100 pt-3">
                  <p className="text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-2">Options</p>
                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showElectrons} onChange={e => setShowElectrons(e.target.checked)} className="rounded" /> Show carriers
                    </label>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-gray-400">Type:</span>
                      <select value={type} onChange={e => setType(e.target.value as 'nmos' | 'pmos')} className="rounded-lg border border-gray-200 bg-white px-2 py-1 text-xs text-gray-700">
                        <option value="nmos">NMOS</option>
                        <option value="pmos">PMOS</option>
                      </select>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Stats panel */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Region" value={liveStats.region.toUpperCase()} unit="" color={REGION_COLORS[liveStats.region].replace('#', 'text-[#') + ']'} />
                  <StatRow label="Id" value={liveStats.Id.toFixed(2)} unit="mA" color="text-indigo-600" />
                  <StatRow label="Vgs" value={liveStats.Vgs.toFixed(2)} unit="V" color="text-rose-500" />
                  <StatRow label="Vds" value={liveStats.Vds.toFixed(2)} unit="V" color="text-emerald-600" />
                  <StatRow label="Vov" value={liveStats.Vov.toFixed(2)} unit="V" color="text-amber-600" />
                  <StatRow label="gm" value={liveStats.gm.toFixed(3)} unit="mS" color="text-blue-500" />
                  <StatRow label="Av" value={liveStats.Av.toFixed(2)} unit="V/V" color="text-pink-500" />
                  <StatRow label="Zin" value={liveStats.Zin >= 1 ? liveStats.Zin.toFixed(1) : (liveStats.Zin * 1000).toFixed(1)} unit={liveStats.Zin >= 1 ? 'MΩ' : 'kΩ'} color="text-purple-600" />
                  <StatRow label="Zout" value={liveStats.Zout >= 1 ? liveStats.Zout.toFixed(1) : liveStats.Zout.toFixed(1)} unit={liveStats.Zout >= 1 ? 'kΩ' : 'Ω'} color="text-cyan-600" />
                  <StatRow label="Pdiss" value={liveStats.Pdiss.toFixed(2)} unit="mW" color="text-orange-500" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Operating Regions</p>
                <div className="space-y-2">
                  {(['cutoff', 'triode', 'saturation'] as MosfetRegion[]).map(r => (
                    <div key={r} className="flex items-start gap-2">
                      <span className="mt-1 h-2 w-2 rounded-full shrink-0" style={{ backgroundColor: REGION_COLORS[r] }} />
                      <div>
                        <p className="text-[10px] font-bold uppercase text-gray-700">{r}</p>
                        <p className="text-[10px] text-gray-400 leading-relaxed">{REGION_DESCRIPTIONS[r]}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Topology</p>
                <p className="text-[10px] text-gray-600 leading-relaxed">{TOPOLOGY_DESCRIPTIONS[topology]}</p>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {Object.keys(CC).map(c => <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>)}
                </div>
              </div>
            </div>

            {/* Teacher notes + Practice problems */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2"><span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}</li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Practice Problems</p>
                <div className="space-y-2">
                  {PRACTICE_PROBLEMS.slice(0, 3).map((problem) => (
                    <div key={problem.id} className="rounded-lg border border-gray-100 bg-gray-50 p-3">
                      <p className="text-[10px] font-bold uppercase text-indigo-600 mb-1">{problem.topology.replace('-', ' ')}</p>
                      <p className="text-xs text-gray-700 mb-1">{problem.question}</p>
                      <p className="text-[10px] text-gray-500">{problem.find}</p>
                      <p className="text-[10px] font-mono text-emerald-600 mt-1">Ans: {problem.answer}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}