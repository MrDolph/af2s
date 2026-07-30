'use client';
import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { QuantumTunnelingCanvas } from '@/components/simulation/QuantumTunnelingCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  TUNNELING_PRESETS, TunnelingParams, PotentialType,
  analyticalTransmission, getDecayConstant, getWavelength,
  type TunnelingStats,
} from '@/lib/physics/quantumTunneling';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'A-Level', 'Undergrad'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
  Undergrad: 'bg-rose-100 text-rose-700',
};

/* ═══════════════════════════════════════════════════════════════════════════
   DYNAMIC TEACHER NOTES — change when you click a scenario card
   ═══════════════════════════════════════════════════════════════════════════ */

const SCENARIO_NOTES: Record<PotentialType, { title: string; bullets: string[] }> = {
  barrier: {
    title: 'Rectangular Barrier — The Canonical Tunneling Problem',
    bullets: [
      'When E < V₀, the wavefunction decays exponentially inside the barrier as ψ ∼ e^(−κx), where κ = √(2m(V₀−E))/ℏ. This is called an evanescent wave.',
      'The transmission probability depends exponentially on width: T ≈ 16(E/V₀)(1−E/V₀)e^(−2κw). Doubling the width squares T — this extreme sensitivity is why tunneling only matters at nanometer scales.',
      'Classically, the particle would bounce back with 100% probability. Quantum mechanically, there is always a non-zero probability of penetration, however small.',
      'Watch for the evanescent wave inside the barrier — it carries no probability current, yet it "connects" the incident and transmitted waves, enabling the particle to appear on the far side.',
      'When E > V₀, transmission is NOT 100%. The wave partially reflects at each boundary due to impedance mismatch (change in wavelength), creating interference oscillations in T(E).',
    ],
  },
  well: {
    title: 'Quantum Well — Attractive Scattering & Resonance',
    bullets: [
      'A quantum well is attractive (V < 0). Even though the particle is drawn inward, sudden changes in potential cause partial reflection at the boundaries — just like light reflecting at a change in refractive index.',
      'When E > 0, the well acts like a region of higher kinetic energy. The de Broglie wavelength lengthens inside, causing impedance-mismatch reflections that classical mechanics cannot explain.',
      'At specific resonance energies, the well becomes perfectly transparent (T = 1) due to constructive interference of multiple internal reflections. These are called transmission resonances.',
      'If E < 0, bound states exist inside the well with quantized energies — this reduces to the famous "particle in a box" problem. The number of bound states depends on well depth and width.',
      'In semiconductor devices, quantum wells confine electrons to 2D planes, creating quantum well lasers and high-electron-mobility transistors (HEMTs).',
    ],
  },
  step: {
    title: 'Step Potential — Evanescent Penetration & Total Reflection',
    bullets: [
      'A step potential represents a semi-infinite barrier. When E < V₀, the wave penetrates as an evanescent decay with characteristic length δ = 1/κ = ℏ/√(2m(V₀−E)).',
      'Despite penetration into the classically forbidden region, the reflection probability is exactly 100% for a semi-infinite step. No net probability current flows into the barrier region.',
      'The reflected wave acquires a phase shift relative to the incident wave. This phase shift contains information about the barrier height and is measurable in interference experiments.',
      'If E > V₀, partial transmission occurs with a refracted wavelength (shorter inside, since kinetic energy increases). The transmission coefficient is T = 4k₁k₂/(k₁+k₂)².',
      'Step potentials model metal-semiconductor interfaces (Schottky barriers) and the edge of a conductor where the work function creates a surface barrier.',
    ],
  },
  double: {
    title: 'Double Barrier — Resonant Tunneling & Quasi-Bound States',
    bullets: [
      'Two barriers separated by a quantum well create quasi-bound states. At resonance energies matching these bound states, the transmission coefficient can reach T ≈ 1 even though each barrier alone would block most of the wave.',
      'This is deeply counter-intuitive: two opaque barriers together can become perfectly transparent! The wave constructively interferes in the central well, building up amplitude that leaks out equally on both sides.',
      'Resonant tunneling diodes (RTDs) exploit this effect. Applying voltage shifts the well levels; current spikes sharply at resonance and drops off-resonance, creating negative differential resistance.',
      'Off-resonance, the double barrier behaves like a single thick barrier with very low T. The sharp resonance makes RTDs useful as high-frequency oscillators and fast switches in electronics.',
      'In quantum computing, double-barrier structures can isolate individual electrons or Cooper pairs, forming the basis of some qubit designs.',
    ],
  },
  triangular: {
    title: 'Triangular Barrier — Field Emission & STM Physics',
    bullets: [
      'A triangular barrier models field emission (Fowler-Nordheim tunneling). An electric field F tilts the vacuum barrier: V(x) = V₀ − eFx, making the effective barrier width depend on field strength.',
      'Unlike a rectangular barrier, the tunneling distance shrinks as the field increases. Higher fields exponentially increase current, which is why sharp tips (high local field) are essential for STM operation.',
      'This is the operating principle of scanning tunneling microscopes (STM). A 1 Å change in tip-sample distance changes current by roughly an order of magnitude, enabling true atomic resolution.',
      'The WKB integral for a triangular barrier yields the Fowler-Nordheim formula: T ∝ exp(−4√(2m)(V₀−E)^(3/2)/3ℏeF). The 3/2 power on (V₀−E) is the signature of field emission.',
      'Field emission is also used in electron guns for electron microscopes and in next-generation display technology (field emitter arrays).',
    ],
  },
};

const GENERAL_NOTES = [
  'Quantum tunneling is the phenomenon where a particle passes through a potential energy barrier that it classically cannot surmount. It arises from the wave nature of matter encoded in the Schrödinger equation.',
  'The wavefunction ψ(x,t) is not zero inside the barrier even when E < V₀. It decays exponentially as ψ ∼ exp(−κx), where κ = √(2m(V₀−E))/ℏ. This evanescent wave carries no probability current, yet it connects to a non-zero transmitted wave on the far side.',
  'Transmission probability for a thick rectangular barrier: T ≈ 16(E/V₀)(1−E/V₀) exp(−2κw). The exponential dependence on width w and height V₀ makes tunneling extremely sensitive to atomic-scale geometry.',
  'Classically, a particle with E < V₀ is always reflected. The classical turning point is where E = V(x). Quantum mechanics permits non-zero |ψ|² beyond this point because the particle does not have a definite position — only a probability amplitude.',
  'When E > V₀, transmission is not 100%. The wave partially reflects from the barrier boundaries due to impedance mismatch (change in wavelength), creating interference oscillations in T(E). This is purely a wave phenomenon.',
  'The split-step Fourier method used here is unconditionally stable and unitary (conserves total probability exactly). It is spectrally accurate in space, making it far superior to finite-difference methods for teaching the time-dependent Schrödinger equation.',
];

const EXERCISES = [
  {
    q: 'Set E = 1 eV, V₀ = 2 eV, w = 2 Å. Launch the packet. What happens to the classical particle vs the quantum wave? Calculate κ and estimate T.',
    a: 'The classical particle (amber dot) hits the barrier and reflects. The quantum wave splits: most reflects, but an exponentially decaying tail penetrates the barrier, and a small transmitted packet (~10–20%) emerges. κ = 0.512√(2−1) ≈ 0.51 Å⁻¹. T ≈ 16(0.5)(0.5)exp(−2·0.51·2) ≈ 4 exp(−2.04) ≈ 0.15 or 15%.',
  },
  {
    q: 'Double the barrier width to 4 Å (keep E=1, V₀=2). How does T change? Verify the exponential dependence.',
    a: 'T drops to ≈ 4 exp(−4.08) ≈ 0.02 or 2%. Doubling width squares the transmission (in the thick-barrier limit). This exponential sensitivity is why tunneling only matters at nanometer scales.',
  },
  {
    q: 'Increase particle energy to E = 3 eV (above V₀ = 2 eV). Why is T not 100%? What classical prediction does this violate?',
    a: 'Classically, any particle with E > V₀ should transmit with 100% probability. Quantum mechanically, the wave partially reflects at each boundary where the wavelength changes (impedance mismatch), causing interference. T oscillates between 1 and T_min as E increases.',
  },
  {
    q: 'Switch to the Double Barrier preset. Slowly tune the particle energy between 0.5 and 1.5 eV. Where does T peak? What causes this resonance?',
    a: 'T peaks when the energy matches a quasi-bound state in the quantum well between the two barriers. At resonance, the wave constructively interferes in the well, giving T ≈ 1 even though each barrier alone would block most of the wave. This is resonant tunneling.',
  },
  {
    q: 'Select the Quantum Well. Set E = 1 eV and V = −3 eV (well depth 3 eV). Why does the well partially reflect the particle even though it is attractive?',
    a: 'An attractive well changes the wavelength (λ increases inside because kinetic energy E−V is larger). The sudden change in λ at the boundaries causes partial reflection — just like light reflecting at a change in refractive index. Only at specific resonance energies does the well become perfectly transparent.',
  },
  {
    q: 'Enable "Show Phase" and run the simulation. What does the color variation inside the packet represent? Why does the phase change faster inside the barrier when E < V₀?',
    a: 'Color represents the complex phase arg(ψ). In free space, phase advances as exp(ikx) with k = √(2mE)/ℏ. Inside the barrier (E < V₀), the wave becomes evanescent with imaginary momentum iκ, so the phase behavior changes dramatically — the amplitude decays while the phase relationship between Re and Im shifts.',
  },
  {
    q: 'Set mass to 10 mₑ (Heavy Particle preset). How does the de Broglie wavelength change? Why does the packet behave more classically?',
    a: 'λ = h/p = 2π/(0.512√(mE)) shrinks by √10 ≈ 3.2×. A shorter wavelength means the wave packet is more localized and follows the classical trajectory more closely. The decay constant κ also increases, suppressing tunneling exponentially. This is the quantum-classical correspondence.',
  },
  {
    q: 'Use the Triangular barrier (STM preset). The WKB integral replaces the simple rectangular formula. Why is a triangular barrier more realistic for field emission?',
    a: 'In field emission, an electric field F tilts the vacuum barrier from a rectangle into a triangle: V(x) = V₀ − eFx. The barrier width at energy E is w = (V₀−E)/eF. The WKB integral gives T ≈ exp(−4√(2m) (V₀−E)^(3/2) / 3ℏeF), the Fowler-Nordheim formula. This explains why sharp tips (high F) and small work functions (low V₀) enhance tunneling.',
  },
  {
    q: 'Graduate: For alpha decay, the nuclear potential is a Coulomb barrier V(r) = 2(Z−2)e²/(4πε₀r) for r > R. Derive the Gamow factor and explain why small changes in E cause huge changes in half-life.',
    a: 'The Gamow factor is the WKB integral from the nuclear radius R to the classical turning point r_t = 2(Z−2)e²/(4πε₀E). Integrating √(2m(V(r)−E)) dr gives G = 2π(Z−2)e²/(ℏv) − 4√(2m(Z−2)e²R/4πε₀)/ℏ, where v = √(2E/m). Since T ∝ exp(−G) and decay rate λ = fT (with f ∼ 10²¹ Hz), the half-life τ = ln2/λ varies by orders of magnitude when G changes by a few units. A small increase in E reduces G linearly, exponentially increasing T and reducing τ.',
  },
  {
    q: 'Graduate: The split-step Fourier method is used here. Why is it superior to finite-difference methods for the time-dependent Schrödinger equation?',
    a: 'The split-step method is unconditionally stable (no Courant limit on dt), unitary (conserves total probability exactly), and spectrally accurate in space (errors decay exponentially with grid resolution). Finite-difference methods require very small dt for stability and accumulate phase errors. The FFT handles the kinetic energy operator exactly in momentum space, while pointwise multiplication handles the potential in position space.',
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="text-gray-400 font-normal">{unit}</span>
        </span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string; }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   COLLAPSIBLE PANEL COMPONENT
   ═══════════════════════════════════════════════════════════════════════════ */

function CollapsiblePanel({
  title, children, defaultOpen = true, badge,
}: {
  title: string; children: React.ReactNode; defaultOpen?: boolean; badge?: string;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 transition"
      >
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{title}</span>
          {badge && <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-indigo-50 text-indigo-600 font-medium">{badge}</span>}
        </div>
        <span className="text-gray-400 text-xs">{open ? '▲ Hide' : '▼ Show'}</span>
      </button>
      {open && <div className="px-4 pb-4">{children}</div>}
    </div>
  );
}

export default function QuantumTunnelingPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level', 'Undergrad']);

  const [potentialType, setPotentialType] = useState<PotentialType>('barrier');
  const [particleEnergy, setParticleEnergy] = useState(1);
  const [barrierHeight, setBarrierHeight] = useState(2);
  const [barrierWidth, setBarrierWidth] = useState(2);
  const [barrierPosition, setBarrierPosition] = useState(25);
  const [packetWidth, setPacketWidth] = useState(1.5);
  const [particleMass, setParticleMass] = useState(1);
  const [speed, setSpeed] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [showPotential, setShowPotential] = useState(true);
  const [showProbability, setShowProbability] = useState(true);
  const [showRealPart, setShowRealPart] = useState(true);
  const [showImaginaryPart, setShowImaginaryPart] = useState(false);
  const [showPhase, setShowPhase] = useState(false);
  const [showClassical, setShowClassical] = useState(false);
  const [showEnergyLine, setShowEnergyLine] = useState(true);
  const [autoRestart, setAutoRestart] = useState(true);

  const params: TunnelingParams = {
    potentialType, particleEnergy, barrierHeight, barrierWidth, barrierPosition,
    packetWidth, particleMass, speed, zoom,
    showPotential, showProbability, showRealPart, showImaginaryPart,
    showPhase, showClassical, showEnergyLine, autoRestart,
  };

  const [liveStats, setLiveStats] = useState<TunnelingStats>({
    energy: 1, momentum: 0.512, barrierHeight: 2, barrierWidth: 2,
    theoreticalT: 0, measuredT: 0, measuredR: 0, wavelength: 12.27, decayConstant: 0.512, time: 0,
  });

  const applyPreset = useCallback((presetIdx: number) => {
    const preset = TUNNELING_PRESETS[presetIdx];
    if (!preset) return;
    const pp = preset.params;
    if (pp.potentialType) setPotentialType(pp.potentialType);
    if (pp.particleEnergy !== undefined) setParticleEnergy(pp.particleEnergy);
    if (pp.barrierHeight !== undefined) setBarrierHeight(pp.barrierHeight);
    if (pp.barrierWidth !== undefined) setBarrierWidth(pp.barrierWidth);
    if (pp.barrierPosition !== undefined) setBarrierPosition(pp.barrierPosition);
    if (pp.packetWidth !== undefined) setPacketWidth(pp.packetWidth);
    if (pp.particleMass !== undefined) setParticleMass(pp.particleMass);
    if (pp.speed !== undefined) setSpeed(pp.speed);
    if (pp.showPotential !== undefined) setShowPotential(pp.showPotential);
    if (pp.showProbability !== undefined) setShowProbability(pp.showProbability);
    if (pp.showRealPart !== undefined) setShowRealPart(pp.showRealPart);
    if (pp.showImaginaryPart !== undefined) setShowImaginaryPart(pp.showImaginaryPart);
    if (pp.showEnergyLine !== undefined) setShowEnergyLine(pp.showEnergyLine);
    if (pp.showClassical !== undefined) setShowClassical(pp.showClassical);
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
    setLiveStats({ energy: pp.particleEnergy ?? 1, momentum: 0.512, barrierHeight: pp.barrierHeight ?? 2, barrierWidth: pp.barrierWidth ?? 2, theoreticalT: 0, measuredT: 0, measuredR: 0, wavelength: 12.27, decayConstant: 0.512, time: 0 });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 720, 500, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: TunnelingStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const theoTDisplay = useMemo(() => {
    if (potentialType === 'barrier' || potentialType === 'well') {
      return analyticalTransmission(particleEnergy, Math.abs(barrierHeight), barrierWidth, particleMass);
    }
    return liveStats.theoreticalT;
  }, [potentialType, particleEnergy, barrierHeight, barrierWidth, particleMass, liveStats.theoreticalT]);

  const scenarioNote = SCENARIO_NOTES[potentialType];

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Quantum Mechanics — Wave Mechanics & Scattering</p>
                <h1 className="text-lg font-semibold text-gray-900">1D Quantum Tunneling</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map((c) => (
                  <button key={c} onClick={() => setActiveCurricula((p) => p.includes(c) ? p.filter((x) => x !== c) : [...p, c])}
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
            <span className="text-xs text-gray-400">Schrödinger → Scattering → Tunneling → WKB → QED</span>
            <span className="text-sm font-semibold font-mono text-gray-900">T ≈ exp(−2κw)</span>
          </div>

          {/* ═══════════════════════════════════════════════════════════════
              SCENARIO PRINCIPLE CARDS — compact on mobile, click to update
              teacher notes. 3 columns on mobile for better balance.
              ═══════════════════════════════════════════════════════════════ */}
          <div className="grid grid-cols-3 lg:grid-cols-5 gap-1.5 sm:gap-2">
            {(['barrier', 'well', 'step', 'double', 'triangular'] as PotentialType[]).map((m) => {
              const labels: Record<PotentialType, string> = {
                barrier: 'Barrier', well: 'Well', step: 'Step', double: 'Double', triangular: 'Triangular',
              };
              const desc: Record<PotentialType, string> = {
                barrier: 'Rectangular wall',
                well: 'Attractive trough',
                step: 'Semi-infinite step',
                double: 'Two barriers',
                triangular: 'Linear ramp',
              };
              const active = potentialType === m;
              return (
                <button
                  key={m}
                  onClick={() => { setPotentialType(m); setIsRunning(false); setResetKey((k) => k + 1); }}
                  className={`relative rounded-xl border px-2 py-2 sm:px-3 sm:py-3 text-left hover:shadow-md transition min-w-0
                    ${active ? 'border-indigo-400 bg-indigo-50 text-indigo-800 ring-1 ring-indigo-200' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}
                >
                  <div className="flex items-center justify-between mb-0.5 sm:mb-1">
                    <p className={`text-[10px] sm:text-xs font-semibold ${active ? 'text-indigo-700' : 'text-gray-700'}`}>{labels[m]}</p>
                    {active && <span className="w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-indigo-500 animate-pulse" />}
                  </div>
                  <p className="text-[9px] sm:text-[10px] text-gray-400 leading-relaxed">{desc[m]}</p>
                  {active && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-400 rounded-b-xl" />}
                </button>
              );
            })}
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {TUNNELING_PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(i)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]">
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] xl:grid-cols-[1fr_280px_300px] gap-4 items-start">
            {/* ═══════════════════════════════════════════════════════════════
                MAIN COLUMN — Canvas → Controls → Parameters (sticky bottom)
                Parameters sits RIGHT HERE, immediately below the canvas,
                making it the most accessible element on the page.
                ═══════════════════════════════════════════════════════════════ */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <QuantumTunnelingCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused((p) => !p)} onReset={reset} />
                <EmbedButton path="/embed/quantum-tunneling" title="Quantum Tunneling — A-Factor STEM Studio"
                  params={{ type: potentialType, E: particleEnergy, V: barrierHeight, w: barrierWidth, pos: barrierPosition, sigma: packetWidth, m: particleMass, speed, pot: showPotential ? 1 : 0, prob: showProbability ? 1 : 0, re: showRealPart ? 1 : 0, im: showImaginaryPart ? 1 : 0, phase: showPhase ? 1 : 0, classical: showClassical ? 1 : 0, eline: showEnergyLine ? 1 : 0, auto: autoRestart ? 1 : 0 }} />
              </div>

              {/* ═══════════════════════════════════════════════════════════
                  PARAMETERS PANEL — Sticky at bottom on desktop,
                  right after controls on mobile. Always within easy reach.
                  ═══════════════════════════════════════════════════════════ */}
              <div className="lg:sticky lg:bottom-4 z-30">
                <CollapsiblePanel title="Parameters" badge="Interactive" defaultOpen={true}>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">Wave Packet</p>
                      <Slider label="Energy E" unit="eV" value={particleEnergy} min={0.1} max={10} step={0.1} set={setParticleEnergy} color="#6366f1" note="Kinetic energy of incident particle" />
                      <Slider label="Packet width σ" unit="Å" value={packetWidth} min={0.5} max={4} step={0.1} set={setPacketWidth} color="#3b82f6" note="Spatial spread of Gaussian (uncertainty)" />
                      <Slider label="Mass" unit="mₑ" value={particleMass} min={0.2} max={20} step={0.1} set={setParticleMass} color="#10b981" note="In units of electron mass" />
                    </div>
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Potential</p>
                      <Slider label="Height |V₀|" unit="eV" value={barrierHeight} min={0.5} max={10} step={0.1} set={setBarrierHeight} color="#fbbf24" note="Barrier height (well depth for Well)" />
                      <Slider label="Width w" unit="Å" value={barrierWidth} min={0.5} max={10} step={0.1} set={setBarrierWidth} color="#f59e0b" note="Barrier thickness" />
                      <Slider label="Position" unit="Å" value={barrierPosition} min={10} max={45} step={1} set={setBarrierPosition} color="#d97706" note="Distance from left edge" />
                    </div>
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-emerald-600 uppercase tracking-wide">Animation</p>
                      <Slider label="Speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" note="Time evolution speed" />
                      <Slider label="Zoom" unit="×" value={zoom} min={0.5} max={2} step={0.1} set={setZoom} color="#10b981" note="Canvas zoom level" />
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer mt-1">
                        <input type="checkbox" checked={autoRestart} onChange={(e) => setAutoRestart(e.target.checked)} className="rounded" />
                        Auto-restart when packet settles
                      </label>
                    </div>
                  </div>

                  <div className="border-t border-gray-100 mt-4 pt-3">
                    <p className="text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-2">Visibility Layers</p>
                    <div className="flex flex-wrap gap-2">
                      {[
                        { label: 'Potential V(x)', checked: showPotential, set: setShowPotential },
                        { label: '|ψ|²', checked: showProbability, set: setShowProbability },
                        { label: 'Re(ψ)', checked: showRealPart, set: setShowRealPart },
                        { label: 'Im(ψ)', checked: showImaginaryPart, set: setShowImaginaryPart },
                        { label: 'Phase', checked: showPhase, set: setShowPhase },
                        { label: 'Classical', checked: showClassical, set: setShowClassical },
                        { label: 'Energy line', checked: showEnergyLine, set: setShowEnergyLine },
                      ].map((item) => (
                        <label key={item.label} className="flex items-center gap-1.5 text-[11px] text-gray-600 cursor-pointer bg-gray-50 px-2 py-1 rounded-md border border-gray-100 hover:border-indigo-200 transition">
                          <input type="checkbox" checked={item.checked} onChange={(e) => item.set(e.target.checked)} className="rounded" />
                          {item.label}
                        </label>
                      ))}
                    </div>
                  </div>
                </CollapsiblePanel>
              </div>
            </div>

            {/* ═══════════════════════════════════════════════════════════════
                RIGHT COLUMN 1 — Calculated Stats + Formulas + Curriculum
                ═══════════════════════════════════════════════════════════════ */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Energy E" value={liveStats.energy.toFixed(2)} unit="eV" color="text-indigo-600" />
                  <StatRow label="Momentum p" value={liveStats.momentum.toFixed(3)} unit="Å⁻¹" color="text-blue-500" />
                  <StatRow label="Wavelength λ" value={liveStats.wavelength.toFixed(2)} unit="Å" color="text-emerald-600" />
                  <StatRow label="Barrier V₀" value={liveStats.barrierHeight.toFixed(2)} unit="eV" color="text-amber-600" />
                  <StatRow label="Width w" value={liveStats.barrierWidth.toFixed(1)} unit="Å" color="text-orange-500" />
                  <StatRow label="Decay κ" value={liveStats.decayConstant.toFixed(3)} unit="Å⁻¹" color="text-purple-600" />
                  <div className="border-t border-gray-100 my-1" />
                  <StatRow label="Theoretical T" value={(theoTDisplay * 100).toFixed(2)} unit="%" color="text-rose-500" />
                  <StatRow label="Measured T" value={(liveStats.measuredT * 100).toFixed(1)} unit="%" color="text-pink-500" />
                  <StatRow label="Measured R" value={(liveStats.measuredR * 100).toFixed(1)} unit="%" color="text-cyan-600" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Formulas</p>
                <div className="space-y-2 text-[10px] text-gray-600 font-mono leading-relaxed">
                  <p>κ = √(2m(V₀−E))/ℏ</p>
                  <p>κ = {liveStats.decayConstant.toFixed(3)} Å⁻¹</p>
                  <p className="text-gray-400">———————</p>
                  <p>T ≈ 16(E/V₀)(1−E/V₀)e^(−2κw)</p>
                  <p>T ≈ {(16 * (liveStats.energy/Math.max(liveStats.barrierHeight,0.01)) * (1 - liveStats.energy/Math.max(liveStats.barrierHeight,0.01)) * Math.exp(-2*liveStats.decayConstant*liveStats.barrierWidth)).toExponential(2)}</p>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map((c) => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* ═══════════════════════════════════════════════════════════════
                RIGHT COLUMN 2 — Collapsible Teacher Notes + Exercises
                ═══════════════════════════════════════════════════════════════ */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <CollapsiblePanel
                title="Teacher Notes"
                badge={potentialType.charAt(0).toUpperCase() + potentialType.slice(1)}
                defaultOpen={true}
              >
                <div className="space-y-3">
                  <div className="rounded-lg bg-amber-50 border border-amber-100 p-3">
                    <p className="text-xs font-semibold text-amber-800 mb-1.5">{scenarioNote.title}</p>
                    <ul className="space-y-1.5">
                      {scenarioNote.bullets.map((b, i) => (
                        <li key={i} className="text-[11px] text-amber-900 leading-relaxed flex gap-2">
                          <span className="text-amber-400 shrink-0 mt-0.5">•</span>{b}
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div>
                    <p className="text-[10px] font-medium text-gray-400 uppercase tracking-wide mb-2">General Principles</p>
                    <ul className="space-y-2">
                      {GENERAL_NOTES.map((n, i) => (
                        <li key={i} className="text-xs text-gray-600 leading-relaxed flex gap-2">
                          <span className="text-gray-300 shrink-0 mt-0.5">•</span>{n}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              </CollapsiblePanel>

              <CollapsiblePanel title="Exercises" defaultOpen={false}>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
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
              </CollapsiblePanel>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}