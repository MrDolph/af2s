#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v54: AC Circuits -- collapsible Teacher
# notes card, collapsed by default for a cleaner first impression
#
#   Does NOT touch simulations/page.tsx (the hub) -- only the AC Circuits
#   page itself.
#
#   Added a Hide/Show toggle to the Teacher notes card, matching the
#   existing Parameters panel's toggle exactly in style and behaviour.
#   Defaults to COLLAPSED (unlike Parameters, which defaults open) --
#   the teacher notes are genuinely useful reference material, but five
#   dense bullet points of exam-level detail is the wrong thing to greet
#   someone with the moment the page loads. Collapsing it by default lets
#   the page open on just the simulation and its controls, with the
#   notes one click away whenever they're wanted.
#
#   The toggle state persists as the user switches between the five
#   topic tabs (same behaviour as the Parameters panel) -- once shown or
#   hidden, it stays that way rather than resetting on every tab change.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v54-ac-circuits-teacher-notes-toggle.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v54: AC Circuits -- collapsible Teacher notes (no hub file changes) --"
mkdir -p "src/app/simulations/ac-circuits"

echo "  -> src/app/simulations/ac-circuits/page.tsx"
cat > "src/app/simulations/ac-circuits/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg, resonantAngularFrequency,
  parallelRLCImpedance, parallelRLCTotalCurrent, parallelRLCPhaseAngleDeg,
  qFactorSeries, qFactorParallel, bandwidthHz,
} from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'waveform' | 'reactance' | 'series-rlc' | 'parallel-rlc' | 'resonance';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  waveform:       { title: 'AC Waveform & RMS',      icon: '〰️', sub: 'Peak vs RMS values',        eq: 'Vrms = Vpeak/√2' },
  reactance:      { title: 'Inductive & Capacitive Reactance', icon: '⏱️', sub: "'ELI the ICE man'", eq: 'XL=ωL, XC=1/ωC' },
  'series-rlc':   { title: 'Series RLC Circuit',      icon: '📈', sub: 'Impedance & resonance',      eq: 'Z=√(R²+(XL-XC)²)' },
  'parallel-rlc': { title: 'Parallel RLC Circuit',    icon: '🔀', sub: 'Branch currents & resonance', eq: 'I=√(IR²+(IC-IL)²)' },
  resonance:      { title: 'Q-Factor & Bandwidth',    icon: '🎯', sub: 'How sharp is the tuning?',   eq: 'Q=f₀/BW' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  waveform: [
    'Alternating current (AC) reverses direction periodically, unlike DC which flows one way — mains supply is AC specifically because transformers (which only work on AC) make it far more efficient to transmit over long distances.',
    'PEAK value is the maximum instantaneous value the wave reaches; RMS (root-mean-square) is the "effective" DC-equivalent value — the steady value that would deliver the same average power to a resistor.',
    'For a sine wave, RMS = peak/√2 ≈ 0.707 × peak — this factor comes directly from averaging sin²(θ) over a full cycle, which works out to exactly 1/2.',
    'When electricians or exam questions say "230V mains" or "240V mains", that is the RMS value — the actual peak voltage reaches roughly 325-340V.',
    'Undergraduate note: average power in a resistor is P = Irms²R = Vrms²/R — using RMS values lets you apply the familiar DC power formulas directly to AC circuits without needing to integrate over a cycle each time.',
  ],
  reactance: [
    'Reactance is the AC equivalent of resistance for inductors and capacitors — it opposes current flow, measured in ohms, but (unlike resistance) it depends on frequency.',
    "Mnemonic 'ELI the ICE man': in an inductor (L), EMF (voltage) Leads Current — ELI. In a capacitor (C), Current leads EMF (voltage) — ICE.",
    'Inductive reactance XL = ωL INCREASES with frequency — an inductor increasingly opposes fast-changing current (that\u2019s exactly why it opposes the sudden current changes that create the back-EMF).',
    'Capacitive reactance XC = 1/ωC DECREASES with frequency — a capacitor charges and discharges more freely as the current reverses faster, offering less opposition.',
    'Undergraduate note: reactance doesn\u2019t dissipate energy the way resistance does — a pure inductor or capacitor stores and returns energy every half-cycle rather than converting it to heat, which is why reactance and resistance combine as a right-angled (vector) sum rather than a simple addition.',
  ],
  'series-rlc': [
    'A series RLC circuit combines a resistor, inductor, and capacitor in one loop, carrying a SINGLE shared current — their opposition to that current (R, XL, XC) combines as impedance Z = √(R² + (XL-XC)²), not a simple sum, because XL and XC act in OPPOSITE directions.',
    'The phasor diagram shows why: VR is in phase with the current (reference direction), VL leads by 90°, VC lags by 90° — so VL and VC directly cancel each other, and only their DIFFERENCE combines with VR.',
    'RESONANCE occurs when XL = XC (they cancel completely) — at this frequency, impedance is at its MINIMUM (Z = R exactly), current is at its MAXIMUM, and the circuit behaves as if it were purely resistive (phase angle = 0°).',
    'Resonant angular frequency ω₀ = 1/√(LC) — this is the exact frequency an RLC circuit "prefers", the basis of tuning a radio receiver to a specific station by adjusting L or C.',
    'Undergraduate note: away from resonance, the phase angle φ = arctan((XL-XC)/R) tells you whether the circuit is net inductive (current lags, φ>0) or net capacitive (current leads, φ<0) — and the power factor cos(φ) determines how much of VrmsIrms is actually real (usable) power versus reactive power that sloshes back and forth without doing net work.',
  ],
  'parallel-rlc': [
    'In a PARALLEL RLC circuit, R, L, and C all share the same voltage (since they\u2019re connected across the same two nodes) — each branch draws its own current, and the branch currents add as phasors: I = √(IR² + (IC-IL)²).',
    "The same 90° phase relationships apply per branch: IR is in phase with V, IL lags V by 90°, IC leads V by 90° — so IL and IC directly cancel in the phasor sum, exactly mirroring how VL and VC cancel in the series case.",
    'RESONANCE still occurs when XL = XC — but the behaviour is the OPPOSITE of series resonance: IL and IC cancel completely, leaving only IR, so the TOTAL LINE CURRENT is at its MINIMUM and the impedance seen by the source is at its MAXIMUM (equal to R).',
    'This is why parallel resonant circuits are sometimes called "rejector" circuits (they reject/minimise current at resonance) while series resonant circuits are called "acceptor" circuits (they accept/maximise current at resonance) — the same LC combination, wired differently, does the opposite job.',
    'Undergraduate note: the resonant frequency formula ω₀ = 1/√(LC) is the SAME for both series and parallel ideal RLC circuits — what differs between them is which quantity (current for series, impedance for parallel) peaks there, and how R affects the sharpness of that peak.',
  ],
  resonance: [
    'The QUALITY FACTOR (Q) measures how "sharp" or selective a resonant circuit is — a high-Q circuit responds strongly only to a narrow band of frequencies near resonance; a low-Q circuit responds broadly across a wide range.',
    'Series RLC: Q = (1/R)√(L/C) — LOWER resistance gives a HIGHER, sharper Q (less energy lost to R each cycle, so the resonance "rings" more before dying out).',
    'Parallel RLC: Q = R√(C/L) — here it is the OPPOSITE dependence: HIGHER resistance gives a HIGHER Q, because in parallel, resistance provides a leak path for current that damps the resonance; more resistance means less of that damping path.',
    'BANDWIDTH is the range of frequencies (in Hz) between the two "half-power points" either side of resonance — the frequencies where the power delivered has dropped to half its peak value. Bandwidth = f₀/Q: a sharper (higher-Q) resonance has a NARROWER bandwidth.',
    'This is exactly how a radio tuner works: a high-Q circuit lets you pick out one station\u2019s narrow frequency band while rejecting neighbouring stations; a low-Q circuit would let several stations through at once, overlapping and unusable.',
    'Undergraduate note: the "half-power" points are where the response has fallen to 1/√2 (≈70.7%) of its peak — power depends on the square of voltage or current, so a 1/√2 drop in amplitude corresponds to exactly a 1/2 drop in power, which is where the name comes from. Bandwidth=f₀/Q is the standard high-Q approximation, increasingly exact as Q grows — for a low-Q circuit (broad, gentle peak) it is only approximate.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  waveform: [
    { q: 'A UK-style AC supply has an RMS voltage of 230V. Find the peak voltage.', a: 'Vpeak = Vrms×√2 = 230×1.414 ≈ 325 V.' },
    { q: 'A sinusoidal current has a peak value of 5A. Find the RMS value and the average power delivered to a 10Ω resistor.', a: 'Irms = 5/√2 ≈ 3.54A. Average power P = Irms²R = 3.54²×10 ≈ 125 W.' },
    { q: 'Why can\u2019t you just average the instantaneous values of a sine wave to find its "effective" value?', a: 'A sine wave is positive for exactly half the cycle and negative for the other half, so the simple average is always zero — RMS instead averages the SQUARE of the values (always positive) before taking the square root, giving a meaningful non-zero effective value.' },
  ],
  reactance: [
    { q: 'Find the reactance of a 200mH inductor at a frequency of 50Hz.', a: 'XL = ωL = 2π×50×0.2 ≈ 62.8 Ω.' },
    { q: 'Find the reactance of a 20µF capacitor at 50Hz.', a: 'XC = 1/(ωC) = 1/(2π×50×20×10⁻⁶) ≈ 159.2 Ω.' },
    { q: 'As frequency increases, what happens to XL and XC, and how does that explain why a capacitor "blocks DC but passes AC"?', a: 'XL increases and XC decreases with frequency. At f=0 (DC), XC = 1/(0) → infinite — a capacitor completely blocks steady current. At high frequency, XC → 0, offering almost no opposition, so a capacitor lets rapidly alternating current pass relatively freely.' },
  ],
  'series-rlc': [
    { q: 'A series RLC circuit has R=50Ω, XL=120Ω, XC=40Ω. Find the impedance.', a: 'Z = √(R² + (XL-XC)²) = √(50² + 80²) = √(2500+6400) = √8900 ≈ 94.3 Ω.' },
    { q: 'For the same circuit, find the phase angle and state whether current leads or lags voltage.', a: 'φ = arctan((XL-XC)/R) = arctan(80/50) ≈ 58°. Since XL>XC, the circuit is net inductive, so CURRENT LAGS voltage by about 58°.' },
    { q: 'A series circuit has L=0.2H and C=50µF. Find the resonant frequency.', a: 'ω₀ = 1/√(LC) = 1/√(0.2×50×10⁻⁶) = 1/√(1×10⁻⁵) ≈ 316.2 rad/s. f₀ = ω₀/2π ≈ 50.3 Hz.' },
  ],
  'parallel-rlc': [
    { q: 'A parallel RLC circuit has IR=2A, IL=5A, IC=1.5A (all peak). Find the total line current.', a: 'I = √(IR² + (IC-IL)²) = √(2² + (1.5-5)²) = √(4+12.25) = √16.25 ≈ 4.03A.' },
    { q: 'In the same circuit, is the total current more or less than IR alone, and what does that tell you about the phase?', a: 'More (4.03A > 2A) — since IL and IC do not cancel, there is a net reactive current, so the total current does not simply equal IR; it leads or lags voltage depending on whether IC or IL dominates (here IL>IC, so the circuit is net inductive and the line current lags voltage).' },
    { q: 'Why does total line current DROP to a minimum at resonance in a parallel RLC circuit, when current in a series circuit RISES to a maximum?', a: 'At resonance IL=IC in both cases, so they cancel. In series, that cancellation leaves only R limiting current, so impedance is minimum and current is maximum. In parallel, cancelling IL and IC leaves only the small IR branch contributing to the LINE current, so the total current drawn from the source is minimum — even though current is still circulating between L and C internally.' },
  ],
  resonance: [
    { q: 'A series RLC circuit has f₀=1000Hz and Q=50. Find the bandwidth and the two half-power frequencies.', a: 'BW = f₀/Q = 1000/50 = 20Hz. Half-power points ≈ f₀ ± BW/2 = 990Hz and 1010Hz.' },
    { q: 'Two series RLC circuits have the same L and C but different R. Which one has the higher Q, and why?', a: 'The circuit with the SMALLER R has the higher Q, since Q=(1/R)√(L/C) — less resistance means less energy dissipated each cycle, so the resonance is sharper and rings longer.' },
    { q: 'A radio tuner needs to separate two stations broadcasting just 10kHz apart, centred near 100MHz. Would a high-Q or low-Q circuit be more suitable, and why?', a: 'A HIGH-Q circuit — it produces a narrow bandwidth, letting through only a thin slice of frequencies around the tuned station while strongly rejecting a neighbouring station only 10kHz away. A low-Q (broad) circuit would let both stations through at once, overlapping and unusable.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

export default function ACCircuitsPage() {
  const [topic, setTopic] = useState<Topic>('waveform');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [vPeak, setVPeak] = useState(20);
  const [frequency, setFrequency] = useState(2);
  const [resistance, setResistance] = useState(100);

  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance, setInductance] = useState(0.5);
  const [capacitance, setCapacitance] = useState(10); // µF

  const [rlcFrequency, setRlcFrequency] = useState(50);
  const [parallelResistance, setParallelResistance] = useState(1000);

  const [resonanceCircuit, setResonanceCircuit] = useState<'series' | 'parallel'>('series');
  const [resR, setResR] = useState(100);
  const [resL, setResL] = useState(0.5);
  const [resC, setResC] = useState(10);

  const [liveValue, setLiveValue] = useState(0);
  const [speedMultiplier, setSpeedMultiplier] = useState(1);
  const [showParams, setShowParams] = useState(true);
  const [showTeacherNotes, setShowTeacherNotes] = useState(false);
  const [phasorZoom, setPhasorZoom] = useState(false);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, parallelResistance, resonanceCircuit, resR, resL, resC, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 340, 980);

  const capF = capacitance * 1e-6;
  const isSeriesTopic = topic === 'series-rlc';
  const isParallelTopic = topic === 'parallel-rlc';
  const effFrequency = isSeriesTopic || isParallelTopic ? rlcFrequency : topic === 'resonance' ? 0 : frequency;
  const omega = angularFrequency(isSeriesTopic || isParallelTopic ? rlcFrequency : frequency);
  const XL = inductiveReactance(omega, inductance);
  const XC = capacitiveReactance(omega, capF);
  const Z = seriesRLCImpedance(resistance, XL, XC);
  const phaseDeg = seriesRLCPhaseAngleDeg(resistance, XL, XC);
  const omegaRes = resonantAngularFrequency(inductance, capF);
  const fRes = omegaRes / (2 * Math.PI);
  const reactanceX = component === 'inductor' ? XL : XC;

  const parZ = parallelRLCImpedance(vPeak, parallelResistance, XL, XC);
  const parI = parallelRLCTotalCurrent(vPeak, parallelResistance, XL, XC);
  const parPhase = parallelRLCPhaseAngleDeg(parallelResistance, XL, XC);

  const resCapF = resC * 1e-6;
  const resOmega0 = resonantAngularFrequency(resL, resCapF);
  const resF0 = resOmega0 / (2 * Math.PI);
  const resQ = resonanceCircuit === 'series' ? qFactorSeries(resR, resL, resCapF) : qFactorParallel(resR, resL, resCapF);
  const resBW = bandwidthHz(resF0, resQ);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple AC Circuits</h1>
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
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
                  vPeak={vPeak} frequency={topic === 'resonance' ? resF0 : effFrequency}
                  resistance={isParallelTopic ? parallelResistance : topic === 'resonance' ? resR : resistance}
                  component={component}
                  inductance={topic === 'resonance' ? resL : inductance}
                  capacitance={topic === 'resonance' ? resCapF : capF}
                  resonanceCircuit={resonanceCircuit} speedMultiplier={speedMultiplier} phasorZoom={phasorZoom}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveValue}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2 flex-wrap">
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                  {topic !== 'resonance' && (
                    <button onClick={() => setPhasorZoom(z => !z)}
                      className={`rounded-lg border px-3 py-2 text-xs font-medium transition flex items-center gap-1 ${
                        phasorZoom ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
                      }`}>
                      {phasorZoom ? '🔍 Zoomed — click to restore' : '🔍 Zoom phasor'}
                    </button>
                  )}
                </div>
                <EmbedButton path="/embed/ac-circuits"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic }} />
              </div>
            </div>

            <div className="space-y-3">
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
                <Slider label="Animation speed" unit="×" value={speedMultiplier} min={0.25} max={3} step={0.25} set={setSpeedMultiplier} color="#94a3b8" />

                {topic === 'waveform' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
                </>}

                {topic === 'reactance' && <>
                  <div className="flex gap-2">
                    {(['inductor', 'capacitor'] as const).map(c => (
                      <button key={c} onClick={() => setComponent(c)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{c}</button>
                    ))}
                  </div>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  {component === 'inductor'
                    ? <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#8b5cf6" />
                    : <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#8b5cf6" />}
                </>}

                {topic === 'series-rlc' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b"
                    note={`Resonance at ≈ ${fRes.toFixed(1)} Hz`} />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
                  <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#2563eb" />
                </>}

                {topic === 'parallel-rlc' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b"
                    note={`Resonance at ≈ ${fRes.toFixed(1)} Hz`} />
                  <Slider label="Resistance" unit="Ω" value={parallelResistance} min={100} max={3000} step={100} set={setParallelResistance} color="#059669" />
                  <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#2563eb" />
                </>}

                {topic === 'resonance' && <>
                  <div className="flex gap-2">
                    {(['series', 'parallel'] as const).map(c => (
                      <button key={c} onClick={() => setResonanceCircuit(c)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          resonanceCircuit === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{c}</button>
                    ))}
                  </div>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Resistance" unit="Ω" value={resR} min={resonanceCircuit === 'series' ? 5 : 200} max={resonanceCircuit === 'series' ? 200 : 3000}
                    step={resonanceCircuit === 'series' ? 5 : 100} set={setResR} color="#059669"
                    note={resonanceCircuit === 'series' ? 'Lower R → sharper (higher Q) peak' : 'Higher R → sharper (higher Q) peak'} />
                  <Slider label="Inductance" unit="H" value={resL} min={0.1} max={2} step={0.1} set={setResL} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={resC} min={1} max={50} step={1} set={setResC} color="#2563eb" />
                </>}
                </>}
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'waveform' && <>
                    <StatRow label="Vrms" value={rmsFromPeak(vPeak).toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="Irms" value={rmsFromPeak(vPeak / resistance).toFixed(2)} unit="A" color="text-emerald-600" />
                    <StatRow label="Average power" value={((rmsFromPeak(vPeak) ** 2) / resistance).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="v(t) now" value={liveValue.toFixed(1)} unit="V" color="text-gray-500" />
                  </>}
                  {topic === 'reactance' && <>
                    <StatRow label={component === 'inductor' ? 'XL' : 'XC'} value={reactanceX.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Peak current" value={(vPeak / reactanceX).toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="Phase" value={component === 'inductor' ? 'I lags V by 90°' : 'I leads V by 90°'} unit="" color="text-amber-600" />
                  </>}
                  {topic === 'series-rlc' && <>
                    <StatRow label="XL" value={XL.toFixed(1)} unit="Ω" color="text-red-600" />
                    <StatRow label="XC" value={XC.toFixed(1)} unit="Ω" color="text-fuchsia-600" />
                    <StatRow label="Impedance Z" value={Z.toFixed(1)} unit="Ω" color="text-teal-600" />
                    <StatRow label="Phase angle" value={phaseDeg.toFixed(1)} unit="°" color="text-emerald-600" />
                    <StatRow label="Resonant f₀" value={fRes.toFixed(1)} unit="Hz" color="text-purple-600" />
                  </>}
                  {topic === 'parallel-rlc' && <>
                    <StatRow label="XL" value={XL.toFixed(1)} unit="Ω" color="text-red-600" />
                    <StatRow label="XC" value={XC.toFixed(1)} unit="Ω" color="text-fuchsia-600" />
                    <StatRow label="Impedance Z" value={parZ.toFixed(0)} unit="Ω" color="text-teal-600" />
                    <StatRow label="Line current" value={parI.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="Phase angle" value={parPhase.toFixed(1)} unit="°" color="text-amber-600" />
                    <StatRow label="Resonant f₀" value={fRes.toFixed(1)} unit="Hz" color="text-purple-600" />
                  </>}
                  {topic === 'resonance' && <>
                    <StatRow label="Resonant f₀" value={resF0.toFixed(1)} unit="Hz" color="text-purple-600" />
                    <StatRow label="Q factor" value={resQ.toFixed(2)} unit="" color="text-indigo-600" />
                    <StatRow label="Bandwidth" value={resBW.toFixed(1)} unit="Hz" color="text-emerald-600" />
                    <StatRow label="f₁ (lower)" value={(resF0 - resBW / 2).toFixed(1)} unit="Hz" color="text-amber-600" />
                    <StatRow label="f₂ (upper)" value={(resF0 + resBW / 2).toFixed(1)} unit="Hz" color="text-amber-600" />
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
                    {TEACHER_NOTES[topic].map((n, i) => (
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
                  {EXERCISES[topic].map((ex, i) => (
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
AFEOF

echo ""
echo "Patch v54 applied -- 1 file(s) written. simulations/page.tsx was NOT touched."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/ac-circuits -- the Teacher notes card should"
echo "now open collapsed, with a Show/Hide toggle matching the"
echo "Parameters panel's style."
