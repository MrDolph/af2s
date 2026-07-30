'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, Legend } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CircuitCanvas, CircuitMode, FlowDisplay } from '@/components/simulation/CircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  ohmCurrent, seriesAnalysis, parallelAnalysis, ivLine,
  nonOhmicCalibration, nonOhmicIVLine, nonOhmicCurrent, NonOhmicDevice,
} from '@/lib/physics/circuits';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<CircuitMode, { title: string; icon: string; sub: string; eq: string }> = {
  ohm:        { title: "Ohm's law",      icon: '⚡', sub: 'Single resistor',            eq: 'V = IR' },
  series:     { title: 'Series',         icon: '🔗', sub: 'Same current, voltages add', eq: 'R = R₁+R₂+R₃' },
  parallel:   { title: 'Parallel',       icon: '🪜', sub: 'Same voltage, currents add', eq: '1/R = 1/R₁+1/R₂+1/R₃' },
  'non-ohmic': { title: 'Non-ohmic',     icon: '📉', sub: 'V = IR does NOT hold',       eq: 'I ≠ kV' },
};

const TEACHER_NOTES: Record<CircuitMode, string[]> = {
  ohm: [
    'V = IR only holds for OHMIC conductors — the I–V graph is a straight line through the origin whose slope is 1/R.',
    'The carrier animation shows drift speed ∝ current: double the voltage, double the speed.',
    'Conventional current flows + → −, but the electrons physically drift the opposite way — try the flow-direction toggle to see both.',
    'Power dissipated P = VI = I²R = V²/R — a resistor converts electrical energy to heat.',
    'Try the sliders on the I–V graph: the operating point always sits on the line for a fixed R.',
  ],
  series: [
    'The SAME current flows through every component — there is only one path.',
    'Voltages divide in proportion to resistance: V₁/V₂ = R₁/R₂ (the potential divider).',
    'Total resistance is always LARGER than the largest single resistor.',
    'One broken component breaks the whole circuit — why old fairy lights all went out together.',
    'Check: the three voltage drops on the canvas always sum to the supply voltage.',
  ],
  parallel: [
    'Every branch gets the FULL supply voltage; the currents divide instead.',
    'The current divider: the SMALLEST resistance takes the LARGEST current, and the LARGEST resistance takes the smallest — watch both the electron speed AND how many dots are moving in each branch.',
    'Total resistance is always SMALLER than the smallest single resistor.',
    'House wiring is parallel: every appliance gets mains voltage, and one failing does not kill the rest.',
    'Check: branch currents on the canvas always sum to the total from the battery.',
  ],
  'non-ohmic': [
    'A NON-OHMIC conductor does NOT obey V = IR with a constant R — its I–V graph is curved, not a straight line, because its resistance itself changes as current flows.',
    'Filament lamp: as current flows, the filament heats up and its resistance RISES — so current grows more SLOWLY than voltage at higher V (the curve bends toward the V-axis, concave down).',
    'Thermistor (NTC — negative temperature coefficient): the opposite happens — resistance FALLS as it heats, so current grows FASTER than voltage at higher V (concave up).',
    'Diode: current is essentially ZERO below a threshold voltage (~0.6-0.7V for silicon), then rises very steeply — a diode only conducts easily in ONE direction, which is exactly why it is used to convert AC to DC.',
    'Undergraduate note: these curves are simplified, always-well-behaved teaching models chosen to show the correct QUALITATIVE shape (concave up/down, or a sharp threshold) rather than an exact material-specific derivation — a real filament\u2019s resistance-vs-temperature relationship and a real diode\u2019s reverse-bias behaviour are each their own, more detailed topics.',
  ],
};

const EXERCISES: Record<CircuitMode, { q: string; a: string }[]> = {
  ohm: [
    { q: 'A 12V battery drives a current of 3A through a resistor. Find R and the power dissipated.', a: 'R=V/I=12/3=4Ω. P=VI=12×3=36W.' },
    { q: 'The I–V graph of a conductor is a straight line of slope 0.25 A/V. Find its resistance.', a: 'Slope = 1/R → R = 1/0.25 = 4Ω.' },
    { q: 'An electric kettle rated 2000W runs on 230V mains. Find the current and its resistance.', a: 'I=P/V=2000/230≈8.7A. R=V/I=230/8.7≈26.4Ω.' },
  ],
  series: [
    { q: 'R₁=2Ω, R₂=3Ω, R₃=5Ω in series with a 20V battery. Find the current and V across R₂.', a: 'R=10Ω. I=20/10=2A. V₂=IR₂=2×3=6V.' },
    { q: 'Two resistors in series carry 0.5A. If V₁=3V and the supply is 9V, find R₂.', a: 'V₂=9−3=6V. R₂=V₂/I=6/0.5=12Ω.' },
    { q: 'Why does adding a resistor in series always reduce the current?', a: 'Total R increases (R = ΣRᵢ), and I = V/R with fixed V, so I falls.' },
  ],
  parallel: [
    { q: 'R₁=6Ω and R₂=3Ω in parallel across 12V. Find each branch current and the total.', a: 'I₁=12/6=2A, I₂=12/3=4A. Total I=6A (and R=2Ω checks: 12/2=6A).' },
    { q: 'Find the combined resistance of 4Ω, 6Ω and 12Ω in parallel.', a: '1/R=1/4+1/6+1/12=3/12+2/12+1/12=6/12 → R=2Ω.' },
    { q: 'Two equal resistors R in parallel — what is the combined resistance?', a: 'R/2. Equal resistors in parallel halve the resistance.' },
  ],
  'non-ohmic': [
    { q: 'A filament lamp and a fixed resistor have the same resistance at their normal operating voltage. At a LOWER voltage, which passes more current?', a: 'The filament lamp — its resistance is lower when cold (not yet heated by the current), so at a lower voltage it briefly behaves like a smaller resistor than the fixed one it was compared to.' },
    { q: 'A silicon diode has almost zero current until about 0.6V, then rises steeply. What circuit-level use does this threshold behaviour enable?', a: 'It lets the diode act as a one-way valve for current (rectification) and as a way to fix a nearly-constant voltage drop across it once conducting — both used throughout electronics, e.g. converting AC to DC.' },
    { q: 'Why can\u2019t a single fixed value of R describe a non-ohmic conductor across its whole I–V graph?', a: 'Because its resistance (V/I at each point) genuinely CHANGES as the operating point moves along the curve — R is only a true constant for a straight-line, ohmic I–V graph through the origin.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

// I–V characteristic with the live operating point sitting ON the line.
function IVGraph({ R, V }: { R: number; V: number }) {
  const vMax = 24;
  const data = useMemo(() => ivLine(R, vMax), [R]);
  const I = ohmCurrent(V, R);
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="v" type="number" tick={{ fontSize: 10 }} domain={[0, vMax]}>
          <Label value="Voltage V (V)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Current I (A)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3) + ' A']} labelFormatter={v => `V=${v}V`} />
        <Line type="monotone" dataKey="i" stroke="#6366f1" strokeWidth={2} dot={false} />
        <ReferenceDot x={V} y={I} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

// Non-ohmic comparison graph: the selected device's curve alongside a
// straight ohmic reference line, so the curvature (or sharp threshold)
// is immediately visible against a known-linear baseline.
function NonOhmicGraph({ device, refR, V }: { device: NonOhmicDevice; refR: number; V: number }) {
  const vMax = device === 'diode' ? 1 : 24;
  const { cLamp, cTherm } = useMemo(() => nonOhmicCalibration(refR, 12), [refR]);
  const ohmicData = useMemo(() => ivLine(refR, vMax), [refR, vMax]);
  const deviceData = useMemo(() => nonOhmicIVLine(device, vMax, cLamp, cTherm), [device, vMax, cLamp, cTherm]);
  const merged = ohmicData.map((d, i) => ({ v: d.v, ohmic: d.i, device: deviceData[i]?.i ?? 0 }));
  const I = nonOhmicCurrent(device, Math.min(V, vMax), cLamp, cTherm);
  const deviceLabel = device === 'filament' ? 'Filament lamp' : device === 'diode' ? 'Diode' : 'Thermistor';
  return (
    <ResponsiveContainer width="100%" height={210}>
      <LineChart data={merged} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="v" type="number" tick={{ fontSize: 10 }} domain={[0, vMax]}>
          <Label value="Voltage V (V)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Current I (A)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4) + ' A']} labelFormatter={v => `V=${v}V`} />
        <Legend wrapperStyle={{ fontSize: 10 }} />
        <Line type="monotone" dataKey="ohmic" name="Ohmic (fixed R)" stroke="#94a3b8" strokeWidth={1.5} strokeDasharray="4 3" dot={false} />
        <Line type="monotone" dataKey="device" name={deviceLabel} stroke="#dc2626" strokeWidth={2.2} dot={false} />
        <ReferenceDot x={Math.min(V, vMax)} y={I} r={6} fill="#dc2626" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function OhmsLawPage() {
  const [mode, setMode] = useState<CircuitMode>('ohm');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [showParams, setShowParams] = useState(true);
  const [showTeacherNotes, setShowTeacherNotes] = useState(false);

  const [V, setV] = useState(12);
  const [r1, setR1] = useState(4);
  const [r2, setR2] = useState(6);
  const [r3, setR3] = useState(12);
  const [nonOhmicDevice, setNonOhmicDevice] = useState<NonOhmicDevice>('filament');
  const [flowDisplay, setFlowDisplay] = useState<FlowDisplay>('electron');

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
  }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, V, r1, r2, r3, nonOhmicDevice, flowDisplay, reset]);

  const ser = seriesAnalysis(V, [r1, r2, r3]);
  const par = parallelAnalysis(V, [r1, r2, r3]);
  const I1 = ohmCurrent(V, r1);
  const { cLamp, cTherm } = nonOhmicCalibration(r1, 12);
  const Inon = nonOhmicCurrent(nonOhmicDevice, mode === 'non-ohmic' && nonOhmicDevice === 'diode' ? Math.min(V, 1) : V, cLamp, cTherm);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity</p>
                <h1 className="text-lg font-semibold text-gray-900">Ohm&apos;s law &amp; circuits</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as CircuitMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            {mode !== 'non-ohmic' && <span className="text-xs text-gray-400 ml-2">P = VI = I²R = V²/R</span>}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
                  nonOhmicDevice={nonOhmicDevice} flowDisplay={flowDisplay}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2 flex-wrap">
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                  <div className="flex rounded-lg border border-gray-200 overflow-hidden">
                    {(['electron', 'conventional'] as const).map(f => (
                      <button key={f} onClick={() => setFlowDisplay(f)}
                        className={`px-2.5 py-2 text-xs font-medium transition ${
                          flowDisplay === f ? 'bg-indigo-50 text-indigo-700' : 'bg-white text-gray-500 hover:bg-gray-50'
                        }`}>{f === 'electron' ? '● Electron flow' : '▶ Conventional I'}</button>
                    ))}
                  </div>
                </div>
                <EmbedButton path="/embed/circuits"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, V, r1, r2, r3 }} />
              </div>

              {mode === 'ohm' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">I–V characteristic</p>
                  <IVGraph R={r1} V={V} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Straight line through the origin — the red dot is the current operating point (slope = 1/R)
                  </p>
                </div>
              )}

              {mode === 'non-ohmic' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">I–V characteristic</p>
                    <div className="flex gap-1">
                      {(['filament', 'thermistor', 'diode'] as const).map(d => (
                        <button key={d} onClick={() => setNonOhmicDevice(d)}
                          className={`px-2 py-1 rounded-md text-[10px] font-medium capitalize transition ${
                            nonOhmicDevice === d ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                          }`}>{d}</button>
                      ))}
                    </div>
                  </div>
                  <NonOhmicGraph device={nonOhmicDevice} refR={r1} V={V} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Red curve = the non-ohmic device; grey dashed line = an ohmic resistor for comparison — same R at V=12V
                  </p>
                </div>
              )}
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'ohm' && <>
                    <StatRow label="Current I" value={I1.toFixed(3)} unit="A" color="text-indigo-600" />
                    <StatRow label="Power P" value={(V * I1).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Charge in 60s" value={(I1 * 60).toFixed(1)} unit="C" color="text-amber-600" />
                    <StatRow label="Energy in 60s" value={(V * I1 * 60).toFixed(0)} unit="J" color="text-rose-500" />
                  </>}
                  {mode === 'series' && <>
                    <StatRow label="Total R" value={ser.Rtotal.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Current I" value={ser.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="V across R₁" value={ser.drops[0].toFixed(2)} unit="V" color="text-amber-600" />
                    <StatRow label="V across R₂" value={ser.drops[1].toFixed(2)} unit="V" color="text-rose-500" />
                    <StatRow label="V across R₃" value={ser.drops[2].toFixed(2)} unit="V" color="text-purple-600" />
                    <StatRow label="Total power" value={ser.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                  {mode === 'parallel' && <>
                    <StatRow label="Total R" value={par.Rtotal.toFixed(2)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Total current" value={par.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="I through R₁" value={par.branches[0].toFixed(3)} unit="A" color="text-amber-600" />
                    <StatRow label="I through R₂" value={par.branches[1].toFixed(3)} unit="A" color="text-rose-500" />
                    <StatRow label="I through R₃" value={par.branches[2].toFixed(3)} unit="A" color="text-purple-600" />
                    <StatRow label="Total power" value={par.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                  {mode === 'non-ohmic' && <>
                    <StatRow label="Device" value={nonOhmicDevice} unit="" color="text-indigo-600" />
                    <StatRow label="Current at this V" value={(Inon * (nonOhmicDevice === 'diode' ? 1000 : 1)).toFixed(nonOhmicDevice === 'diode' ? 3 : 3)} unit={nonOhmicDevice === 'diode' ? 'mA' : 'A'} color="text-emerald-600" />
                    <StatRow label="Apparent R (V/I)" value={Inon > 0.0001 ? (Math.min(V, nonOhmicDevice === 'diode' ? 1 : V) / Inon).toFixed(1) : '∞'} unit="Ω" color="text-amber-600" />
                    <StatRow label="Obeys V=IR?" value="NO" unit="(R not constant)" color="text-rose-500" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                  <button onClick={() => setShowParams(p => !p)}
                    className="text-xs font-medium text-indigo-600 hover:text-indigo-700 flex items-center gap-1">
                    {showParams ? 'Hide' : 'Show'}
                    <span className={`transition-transform ${showParams ? 'rotate-180' : ''}`}>▾</span>
                  </button>
                </div>
                {showParams && <>
                  <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
                  {mode !== 'non-ohmic' && (
                    <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
                  )}
                  {mode === 'non-ohmic' && (
                    <Slider label="Reference R (for comparison)" unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
                  )}
                  {(mode === 'series' || mode === 'parallel') && <>
                    <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
                    <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
                  </>}
                </>}
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-xs font-medium text-amber-700 uppercase tracking-wide">📋 Teacher notes</p>
                  <button onClick={() => setShowTeacherNotes(p => !p)}
                    className="text-xs font-medium text-amber-700 hover:text-amber-800 flex items-center gap-1">
                    {showTeacherNotes ? 'Hide' : 'Show'}
                    <span className={`transition-transform ${showTeacherNotes ? 'rotate-180' : ''}`}>▾</span>
                  </button>
                </div>
                {showTeacherNotes && (
                  <ul className="space-y-2">
                    {TEACHER_NOTES[mode].map((n, i) => (
                      <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                        <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
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
