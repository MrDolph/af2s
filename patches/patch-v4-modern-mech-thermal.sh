#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v4
#   6 new simulation modules:
#     💡 Photoelectric effect   (Einstein's equation, KEmax–f graph)
#     〰️ De Broglie hypothesis  (matter waves, λ = h/mv, electron-gun calculator)
#     🩻 X-rays                 (tube production, continuous + characteristic spectrum)
#     🧱 Friction                (flat + inclined, static/kinetic, angle of repose)
#     🔥 Modes of heat transfer  (conduction / convection / radiation)
#     🪢 Elasticity              (Hooke's law spring, Young's modulus wire)
#   Hub page: 6 new live cards added
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v4-modern-mech-thermal.sh
# Assumes patch v3 has already been applied.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v4: 6 new modules (photoelectric, de Broglie, X-rays, friction, heat, elasticity) ──"
mkdir -p "src/app/embed/debroglie" "src/app/embed/elasticity" "src/app/embed/friction" "src/app/embed/heat" "src/app/embed/photoelectric" "src/app/embed/xrays" "src/app/simulations" "src/app/simulations/de-broglie" "src/app/simulations/elasticity" "src/app/simulations/friction" "src/app/simulations/heat-transfer" "src/app/simulations/photoelectric-effect" "src/app/simulations/x-rays" "src/components/simulation" "src/lib/physics"

echo "  → src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'photoelectric-effect',
    href: '/simulations/photoelectric-effect',
    title: 'Photoelectric effect',
    description: "Fire light at a metal plate and test Einstein's equation hf = φ + KEmax.",
    icon: '💡',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'de-broglie',
    href: '/simulations/de-broglie',
    title: 'De Broglie hypothesis',
    description: 'See matter waves in action: λ = h/mv for particles from electrons to cricket balls.',
    icon: '〰️',
    tags: ['IGCSE', 'JUPEB', 'SAT'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'x-rays',
    href: '/simulations/x-rays',
    title: 'X-rays',
    description: 'Explore X-ray tube production, the continuous spectrum, and the Duane–Hunt limit.',
    icon: '🩻',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'friction',
    href: '/simulations/friction',
    title: 'Friction',
    description: 'Static vs kinetic friction on flat and inclined surfaces, with the angle of repose.',
    icon: '🧱',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'heat-transfer',
    href: '/simulations/heat-transfer',
    title: 'Modes of heat transfer',
    description: 'Conduction, convection, and radiation compared side by side with live particle animation.',
    icon: '🔥',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'elasticity',
    href: '/simulations/elasticity',
    title: 'Elasticity',
    description: "Hooke's law with a loaded spring, and Young's modulus for a stretched wire.",
    icon: '🪢',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

export default function SimulationsPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => (
              <button key={t}
                className="shrink-0 rounded-full border border-gray-200 bg-white px-4 py-1.5 text-xs font-medium text-gray-600 hover:border-indigo-300 hover:text-indigo-700 transition whitespace-nowrap">
                {t}
              </button>
            ))}
          </div>

          {/* Cards grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {SIMULATIONS.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo "  → src/lib/physics/photoelectric.ts"
cat > "src/lib/physics/photoelectric.ts" << 'AFEOF'
// ── Photoelectric effect ──────────────────────────────────────────────────────
// Einstein's equation:  hf = φ + KEmax
//   E = hf              photon energy
//   φ                   work function of the metal
//   f₀ = φ/h            threshold frequency (no emission below it)
//   eVs = KEmax         stopping potential
// Intensity changes the NUMBER of photons (→ current), never their energy.

export const H = 6.626e-34;       // Planck constant (J·s)
export const E_CHARGE = 1.602e-19; // electron charge (C)
export const C_LIGHT = 3e8;       // speed of light (m/s)

// Frequencies handled in units of 10¹⁴ Hz for friendly slider numbers.
export function photonEnergyEV(f14: number) {
  return (H * f14 * 1e14) / E_CHARGE;
}
export function thresholdF14(phiEV: number) {
  return (phiEV * E_CHARGE) / H / 1e14;
}
export function keMaxEV(f14: number, phiEV: number) {
  return Math.max(0, photonEnergyEV(f14) - phiEV);
}
export function stoppingPotential(f14: number, phiEV: number) {
  return keMaxEV(f14, phiEV); // volts, numerically equal to KEmax in eV
}
export function wavelengthNm(f14: number) {
  return (C_LIGHT / (f14 * 1e14)) * 1e9;
}
// Electron speed from KE (non-relativistic, fine below ~10 eV scale here).
export function electronSpeed(keEV: number) {
  const me = 9.109e-31;
  return Math.sqrt((2 * keEV * E_CHARGE) / me);
}

export const METALS = [
  { name: 'Caesium',  phi: 2.10 },
  { name: 'Sodium',   phi: 2.28 },
  { name: 'Calcium',  phi: 2.87 },
  { name: 'Zinc',     phi: 4.30 },
  { name: 'Copper',   phi: 4.70 },
  { name: 'Platinum', phi: 6.35 },
] as const;

// KEmax–f line for the graph: straight line, slope h/e, intercept −φ/e.
export function keLine(phiEV: number, f14Max: number, points = 60) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const f = (i / points) * f14Max;
    return { f: +f.toFixed(3), ke: +keMaxEV(f, phiEV).toFixed(4) };
  });
}

// Rough visible-spectrum colour for the beam (f in 10¹⁴ Hz).
export function lightColor(f14: number): string {
  if (f14 < 4.0) return '#b91c1c';        // infrared → deep red
  if (f14 < 4.8) return '#ef4444';        // red
  if (f14 < 5.3) return '#f59e0b';        // orange/yellow
  if (f14 < 6.0) return '#22c55e';        // green
  if (f14 < 6.7) return '#3b82f6';        // blue
  if (f14 < 7.9) return '#8b5cf6';        // violet
  return '#c4b5fd';                        // ultraviolet (shown pale violet)
}
AFEOF

echo "  → src/lib/physics/debroglie.ts"
cat > "src/lib/physics/debroglie.ts" << 'AFEOF'
// ── De Broglie hypothesis ─────────────────────────────────────────────────────
// Every moving particle has an associated matter wave:
//   λ = h / p = h / (mv)
// Electron accelerated through potential V:
//   λ = h / √(2 m e V)

export const H = 6.626e-34;
export const E_CHARGE = 1.602e-19;
export const M_ELECTRON = 9.109e-31;

export interface ParticlePreset {
  name: string;
  mass: number;       // kg
  vMin: number; vMax: number; vDefault: number; // m/s slider range
  emoji: string;
}

export const PARTICLES: ParticlePreset[] = [
  { name: 'Electron',     mass: 9.109e-31, vMin: 1e5,  vMax: 1e7,  vDefault: 2e6,  emoji: '⚛️' },
  { name: 'Proton',       mass: 1.673e-27, vMin: 1e4,  vMax: 1e6,  vDefault: 1e5,  emoji: '🔴' },
  { name: 'Alpha particle', mass: 6.645e-27, vMin: 1e4, vMax: 1e6, vDefault: 1e5,  emoji: '🟠' },
  { name: 'Cricket ball (160g)', mass: 0.16, vMin: 5, vMax: 45, vDefault: 30, emoji: '🏏' },
];

export function deBroglieLambda(mass: number, v: number) {
  return v > 0 ? H / (mass * v) : Infinity;
}
export function momentum(mass: number, v: number) {
  return mass * v;
}
export function lambdaFromVoltage(V: number) {
  return H / Math.sqrt(2 * M_ELECTRON * E_CHARGE * V);
}
// Human-readable length with sensible unit.
export function formatLambda(lambda: number): string {
  if (!isFinite(lambda)) return '∞';
  if (lambda >= 1e-3) return (lambda * 1e3).toPrecision(3) + ' mm';
  if (lambda >= 1e-6) return (lambda * 1e6).toPrecision(3) + ' µm';
  if (lambda >= 1e-9) return (lambda * 1e9).toPrecision(3) + ' nm';
  if (lambda >= 1e-12) return (lambda * 1e12).toPrecision(3) + ' pm';
  if (lambda >= 1e-15) return (lambda * 1e15).toPrecision(3) + ' fm';
  return lambda.toExponential(2) + ' m';
}
AFEOF

echo "  → src/lib/physics/xrays.ts"
cat > "src/lib/physics/xrays.ts" << 'AFEOF'
// ── X-ray production ──────────────────────────────────────────────────────────
// Electrons accelerated through V kilovolts strike a metal target.
//   Max photon energy = eV  →  minimum wavelength (Duane–Hunt limit):
//     λmin = hc / eV
// Spectrum = continuous bremsstrahlung (Kramers' law shape)
//          + characteristic Kα/Kβ lines once V exceeds the excitation energy.

export const H = 6.626e-34;
export const C = 3e8;
export const E_CHARGE = 1.602e-19;

// λmin in nanometres for tube voltage in kV.  λmin(nm) ≈ 1.24 / V(kV)
export function lambdaMinNm(kV: number) {
  return kV > 0 ? (H * C) / (E_CHARGE * kV * 1000) * 1e9 : Infinity;
}
export function maxPhotonEnergyKeV(kV: number) {
  return kV; // eV of electron = photon max, numerically kV → keV
}
export function electronSpeedFraction(kV: number) {
  // Classical estimate v = √(2eV/m) as a fraction of c (fine for a school sim).
  const v = Math.sqrt((2 * E_CHARGE * kV * 1000) / 9.109e-31);
  return Math.min(v / C, 0.99);
}

// Molybdenum target (the classic textbook case):
export const MO_K_ALPHA_NM = 0.071;
export const MO_K_BETA_NM = 0.063;
export const MO_EXCITATION_KV = 20;

// Continuous spectrum via Kramers: I(λ) ∝ (λ/λmin − 1)/λ³, plus Gaussian
// characteristic peaks when the tube voltage can excite them.
export function xraySpectrum(kV: number, current: number, lambdaMaxNm = 0.14, points = 160) {
  const lMin = lambdaMinNm(kV);
  const data: { lambda: number; i: number }[] = [];
  const showLines = kV >= MO_EXCITATION_KV;
  for (let p = 0; p <= points; p++) {
    const l = (p / points) * lambdaMaxNm;
    let I = 0;
    if (l > lMin && l > 0) {
      I = ((l / lMin - 1) / (l * l * l)) * 2e-5 * current;
    }
    if (showLines) {
      const g = (c0: number, s: number, a: number) => a * Math.exp(-((l - c0) ** 2) / (2 * s * s));
      I += g(MO_K_ALPHA_NM, 0.0012, 9 * current) * (l > lMin ? 1 : 0);
      I += g(MO_K_BETA_NM, 0.0012, 5 * current) * (l > lMin ? 1 : 0);
    }
    data.push({ lambda: +l.toFixed(4), i: +I.toFixed(3) });
  }
  return data;
}
AFEOF

echo "  → src/lib/physics/friction.ts"
cat > "src/lib/physics/friction.ts" << 'AFEOF'
// ── Friction ──────────────────────────────────────────────────────────────────
// Static:  F_s ≤ μs·N  (matches the applied force until the limit)
// Kinetic: F_k = μk·N  (constant once sliding; μk < μs)
// On an incline the block slips when tanθ > μs  →  angle of repose θr = tan⁻¹μs.

export const G = 9.81;

export interface FlatResult {
  N: number;
  staticMax: number;
  friction: number;     // actual friction force right now
  netForce: number;
  acceleration: number;
  moving: boolean;
}

export function flatFriction(mass: number, applied: number, muS: number, muK: number): FlatResult {
  const N = mass * G;
  const staticMax = muS * N;
  if (applied <= staticMax) {
    // Static regime: friction exactly balances the applied force.
    return { N, staticMax, friction: applied, netForce: 0, acceleration: 0, moving: false };
  }
  const kinetic = muK * N;
  const net = applied - kinetic;
  return { N, staticMax, friction: kinetic, netForce: net, acceleration: net / mass, moving: true };
}

export interface InclineResult {
  N: number;
  gravityAlong: number;   // mg sinθ (down-slope)
  staticMax: number;      // μs·mg·cosθ
  friction: number;
  acceleration: number;   // down-slope, 0 if static
  sliding: boolean;
  reposeAngle: number;    // tan⁻¹(μs) in degrees
}

export function inclineFriction(mass: number, thetaDeg: number, muS: number, muK: number): InclineResult {
  const th = (thetaDeg * Math.PI) / 180;
  const N = mass * G * Math.cos(th);
  const along = mass * G * Math.sin(th);
  const staticMax = muS * N;
  const reposeAngle = (Math.atan(muS) * 180) / Math.PI;
  if (along <= staticMax) {
    return { N, gravityAlong: along, staticMax, friction: along, acceleration: 0, sliding: false, reposeAngle };
  }
  const kinetic = muK * N;
  return {
    N, gravityAlong: along, staticMax, friction: kinetic,
    acceleration: (along - kinetic) / mass, sliding: true, reposeAngle,
  };
}

// Friction-vs-applied-force curve: the classic ramp-then-plateau graph.
export function frictionCurve(mass: number, muS: number, muK: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { F: +F.toFixed(2), f: +flatFriction(mass, F, muS, muK).friction.toFixed(2) };
  });
}
AFEOF

echo "  → src/lib/physics/heat.ts"
cat > "src/lib/physics/heat.ts" << 'AFEOF'
// ── Modes of heat transfer ────────────────────────────────────────────────────
// Conduction (solids): energy passed particle-to-particle, no bulk movement.
//   Rate:  Q/t = kAΔT / L      (k = thermal conductivity)
// Convection (fluids): warm fluid expands, becomes less dense, rises — a
//   circulation current carries the energy.
// Radiation: electromagnetic (infrared) waves, needs NO medium.
//   Stefan–Boltzmann: P = εσAT⁴

export const SIGMA = 5.67e-8; // Stefan–Boltzmann constant (W·m⁻²·K⁻⁴)

export const MATERIALS = [
  { name: 'Copper',    k: 385 },
  { name: 'Aluminium', k: 205 },
  { name: 'Steel',     k: 50 },
  { name: 'Glass',     k: 0.8 },
  { name: 'Brick',     k: 0.6 },
  { name: 'Wood',      k: 0.13 },
  { name: 'Air',       k: 0.024 },
] as const;

// Q/t in watts: k (W/mK), A (m²), ΔT (K), L (m)
export function conductionRate(k: number, A: number, dT: number, L: number) {
  return L > 0 ? (k * A * dT) / L : 0;
}

// Radiated power P = εσAT⁴ (T in kelvin)
export function radiatedPower(emissivity: number, A: number, T: number) {
  return emissivity * SIGMA * A * Math.pow(T, 4);
}

// Net radiation exchange with surroundings at T0
export function netRadiation(emissivity: number, A: number, T: number, T0: number) {
  return emissivity * SIGMA * A * (Math.pow(T, 4) - Math.pow(T0, 4));
}

export function celsiusToKelvin(c: number) { return c + 273.15; }
AFEOF

echo "  → src/lib/physics/elasticity.ts"
cat > "src/lib/physics/elasticity.ts" << 'AFEOF'
// ── Elasticity ────────────────────────────────────────────────────────────────
// Hooke's law:  F = ke   (up to the elastic limit / limit of proportionality)
// Energy stored (elastic PE): E = ½Fe = ½ke²
// For a wire:
//   stress σ = F/A,  strain ε = e/L,  Young's modulus E = σ/ε = FL/(Ae)

export const G = 9.81;

export function extension(F: number, k: number) {
  return k > 0 ? F / k : 0;
}
export function springEnergy(k: number, e: number) {
  return 0.5 * k * e * e;
}
export function stress(F: number, A: number) {
  return A > 0 ? F / A : 0;
}
export function strain(e: number, L: number) {
  return L > 0 ? e / L : 0;
}
export function youngModulus(F: number, A: number, e: number, L: number) {
  const s = strain(e, L);
  return s > 0 ? stress(F, A) / s : 0;
}
// Wire extension from Young's modulus: e = FL/(AE)
export function wireExtension(F: number, L: number, A: number, E: number) {
  return A > 0 && E > 0 ? (F * L) / (A * E) : 0;
}

export const WIRE_MATERIALS = [
  { name: 'Steel',     E: 200e9 },
  { name: 'Copper',    E: 117e9 },
  { name: 'Brass',     E: 100e9 },
  { name: 'Aluminium', E: 69e9 },
  { name: 'Glass',     E: 70e9 },
  { name: 'Rubber',    E: 0.05e9 },
] as const;

// Force–extension curve: linear (Hooke) up to the elastic limit, then a
// flattening plastic region — the classic exam graph.
export function forceExtensionCurve(k: number, elasticLimitF: number, fMax: number, points = 100) {
  const eLimit = elasticLimitF / k;
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    let e: number;
    if (F <= elasticLimitF) {
      e = F / k;
    } else {
      // Plastic: extension grows much faster per unit force.
      const dF = F - elasticLimitF;
      e = eLimit + (dF / k) * (1 + 3 * (dF / elasticLimitF));
    }
    return { e: +(e * 100).toFixed(3), F: +F.toFixed(2) }; // e in cm for the graph
  });
}
AFEOF

echo "  → src/components/simulation/PhotoelectricCanvas.tsx"
cat > "src/components/simulation/PhotoelectricCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { keMaxEV, thresholdF14, lightColor, wavelengthNm } from '@/lib/physics/photoelectric';

interface Props {
  f14: number;         // frequency in 10¹⁴ Hz
  intensity: number;   // 1–10 (relative)
  phiEV: number;       // work function
  metalName: string;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Electron { x: number; y: number; vx: number; }
interface Photon { x: number; y: number; }

export function PhotoelectricCanvas({ f14, intensity, phiEV, metalName, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const electronsRef = useRef<Electron[]>([]);
  const photonsRef = useRef<Photon[]>([]);
  const emitAccRef = useRef(0);
  const collectedRef = useRef(0);
  const sim = useRef({ f14, intensity, phiEV, metalName, isRunning, isPaused });
  sim.current = { f14, intensity, phiEV, metalName, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    electronsRef.current = []; photonsRef.current = [];
    emitAccRef.current = 0; collectedRef.current = 0;
  }, [f14, intensity, phiEV]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const ke = keMaxEV(s.f14, s.phiEV);
    const emits = ke > 0;
    const plateX = 90, collX = W - 70;
    const beamColor = lightColor(s.f14);

    // Spawn photons streaming towards the plate; rate ∝ intensity.
    if (dt > 0) {
      emitAccRef.current += dt * s.intensity * 4;
      while (emitAccRef.current >= 1) {
        emitAccRef.current -= 1;
        photonsRef.current.push({ x: 0, y: 0 }); // param along beam 0→1
        // Each absorbed photon MAY free one electron (if above threshold).
        if (emits) {
          // Speed on screen ∝ √KE — doubling KE does not double speed.
          const px = plateX + 6;
          const py = 60 + Math.random() * (H - 140);
          electronsRef.current.push({ x: px, y: py, vx: 40 + Math.sqrt(ke) * 90 });
        }
      }
      photonsRef.current.forEach(p => { p.x += dt * 1.6; });
      photonsRef.current = photonsRef.current.filter(p => p.x < 1);
      electronsRef.current.forEach(e => { e.x += e.vx * dt; });
      const before = electronsRef.current.length;
      electronsRef.current = electronsRef.current.filter(e => e.x < collX);
      collectedRef.current += before - electronsRef.current.length;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Light source (top-left) + beam onto the plate
    const srcX = 20, srcY = 26;
    ctx.save();
    ctx.fillStyle = beamColor;
    ctx.beginPath(); ctx.arc(srcX, srcY, 10, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 0.14 + s.intensity * 0.02;
    ctx.beginPath();
    ctx.moveTo(srcX, srcY);
    ctx.lineTo(plateX, 50); ctx.lineTo(plateX, H - 70); ctx.closePath();
    ctx.fillStyle = beamColor; ctx.fill();
    ctx.restore();
    // Photons as short dashes travelling down the beam
    ctx.save();
    ctx.strokeStyle = beamColor; ctx.lineWidth = 2;
    photonsRef.current.forEach(p => {
      const bx = srcX + (plateX - srcX) * p.x;
      const by = srcY + ((H / 2 - 10) - srcY) * p.x + Math.sin(p.x * 40) * 6;
      ctx.beginPath(); ctx.moveTo(bx - 5, by); ctx.lineTo(bx + 5, by); ctx.stroke();
    });
    ctx.restore();

    // Metal plate (emitter)
    ctx.fillStyle = '#64748b';
    ctx.fillRect(plateX - 10, 50, 10, H - 120);
    ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(s.metalName, plateX - 5, H - 56);
    ctx.font = '9px system-ui'; ctx.fillStyle = '#64748b';
    ctx.fillText(`φ = ${s.phiEV} eV`, plateX - 5, H - 44);

    // Collector
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(collX, 50, 8, H - 120);
    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui';
    ctx.fillText('collector', collX + 4, H - 56);

    // Photoelectrons
    ctx.save();
    electronsRef.current.forEach(e => {
      ctx.beginPath(); ctx.arc(e.x, e.y, 3.5, 0, Math.PI * 2);
      ctx.fillStyle = '#0ea5e9'; ctx.fill();
      ctx.fillStyle = '#0369a1'; ctx.font = '8px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('e⁻', e.x, e.y - 6);
    });
    ctx.restore();

    // Status banner
    ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui';
    if (!emits) {
      ctx.fillStyle = '#ef4444';
      ctx.fillText(`NO EMISSION — f below threshold f₀ = ${thresholdF14(s.phiEV).toFixed(2)}×10¹⁴ Hz (however bright the light!)`, W / 2, 24);
    } else {
      ctx.fillStyle = '#059669';
      ctx.fillText(`Emitting: KEmax = ${ke.toFixed(2)} eV per electron — intensity changes HOW MANY, not how fast`, W / 2, 24);
    }

    // HUD
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`f = ${s.f14.toFixed(2)}×10¹⁴ Hz (λ ≈ ${wavelengthNm(s.f14).toFixed(0)} nm)   intensity = ${s.intensity}   collected: ${collectedRef.current} e⁻   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/DeBroglieCanvas.tsx"
cat > "src/components/simulation/DeBroglieCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { deBroglieLambda, formatLambda } from '@/lib/physics/debroglie';

interface Props {
  mass: number;         // kg
  velocity: number;     // m/s
  particleName: string;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// The real wavelengths span ~30 orders of magnitude, so the on-screen
// wavelength is a LOG mapping of the true λ — the number shown is exact,
// the picture just keeps everything visible.
function screenLambda(lambda: number): number {
  if (!isFinite(lambda)) return 400;
  const logL = Math.log10(lambda); // e.g. −10 for 0.1nm, −34 for a ball
  // Map log10(λ) ∈ [−36, −6] → [14, 220] px
  const t = Math.min(1, Math.max(0, (logL + 36) / 30));
  return 14 + t * 206;
}

export function DeBroglieCanvas({ mass, velocity, particleName, isRunning, isPaused, width = 640, height = 280 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mass, velocity, particleName, isRunning, isPaused });
  sim.current = { mass, velocity, particleName, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mass, velocity]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    const lambda = deBroglieLambda(s.mass, s.velocity);
    const sl = screenLambda(lambda);
    const midY = H / 2;
    const px = ((t * 90) % (W + 120)) - 60; // particle drifts across, wraps

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Direction of travel
    ctx.strokeStyle = '#e2e8f0'; ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
    ctx.setLineDash([]);

    // Matter wave: a wave packet centred on the particle
    ctx.save();
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
    ctx.beginPath();
    const k = (2 * Math.PI) / sl;
    for (let x = 0; x <= W; x += 2) {
      const envelope = Math.exp(-((x - px) ** 2) / (2 * (sl * 2.2) ** 2)); // packet
      const y = midY - Math.sin(k * (x - px)) * 44 * envelope;
      if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.restore();

    // Particle
    ctx.save();
    const r = Math.max(6, Math.min(16, 6 + Math.log10(s.mass / 9.109e-31)));
    const grad = ctx.createRadialGradient(px - 2, midY - 2, 1, px, midY, r);
    grad.addColorStop(0, '#a5b4fc'); grad.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(px, midY, r, 0, Math.PI * 2);
    ctx.fillStyle = grad; ctx.fill();
    ctx.restore();

    // λ bracket (only meaningful when packet fits nicely)
    if (sl < W / 2) {
      const bx = px + sl * 0.75, by = midY + 58;
      if (bx > 0 && bx + sl < W) {
        ctx.save();
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + sl, by); ctx.stroke();
        [bx, bx + sl].forEach(x => {
          ctx.beginPath(); ctx.moveTo(x, by - 4); ctx.lineTo(x, by + 4); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`λ = ${formatLambda(lambda)}`, bx + sl / 2, by + 14);
        ctx.restore();
      }
    }

    // Caption
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.particleName}:  λ = h/mv = ${formatLambda(lambda)}`, W / 2, 24);
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui';
    ctx.fillText('(wave drawn on a log scale so it stays visible — the value shown is exact)', W / 2, 38);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`m = ${s.mass.toExponential(2)} kg   v = ${s.velocity.toExponential(2)} m/s   p = mv = ${(s.mass * s.velocity).toExponential(2)} kg·m/s`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/XrayCanvas.tsx"
cat > "src/components/simulation/XrayCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { lambdaMinNm, electronSpeedFraction, MO_EXCITATION_KV } from '@/lib/physics/xrays';

interface Props {
  kV: number;          // tube voltage in kilovolts
  current: number;     // filament current 1–10 (relative)
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Beam { x: number; y: number; }
interface Ray { p: number; ang: number; }

export function XrayCanvas({ kV, current, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const electronsRef = useRef<Beam[]>([]);
  const raysRef = useRef<Ray[]>([]);
  const accRef = useRef(0);
  const sim = useRef({ kV, current, isRunning, isPaused });
  sim.current = { kV, current, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    electronsRef.current = []; raysRef.current = []; accRef.current = 0;
  }, [kV, current]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const cathX = 110, anodeX = W - 170, beamY = 120;
    const eSpeed = 120 + s.kV * 3; // px/s ∝ ish √V feel, readable

    if (dt > 0) {
      accRef.current += dt * s.current * 3;
      while (accRef.current >= 1) {
        accRef.current -= 1;
        electronsRef.current.push({ x: cathX + 8, y: beamY + (Math.random() - 0.5) * 14 });
      }
      electronsRef.current.forEach(e => { e.x += eSpeed * dt; });
      const arrived = electronsRef.current.filter(e => e.x >= anodeX).length;
      electronsRef.current = electronsRef.current.filter(e => e.x < anodeX);
      for (let i = 0; i < arrived; i++) {
        // ~1% of electron energy becomes X-rays (rest is heat) — but we draw
        // a ray per impact so the physics is visible.
        raysRef.current.push({ p: 0, ang: Math.PI / 2 + (Math.random() - 0.5) * 0.9 });
      }
      raysRef.current.forEach(r => { r.p += dt * 220; });
      raysRef.current = raysRef.current.filter(r => r.p < 180);
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Evacuated glass tube
    ctx.save();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.roundRect(70, 60, W - 200, 120, 40);
    ctx.stroke();
    ctx.fillStyle = 'rgba(226,232,240,0.25)'; ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('evacuated tube', 82, 76);
    ctx.restore();

    // Cathode (heated filament)
    ctx.save();
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 3;
    ctx.beginPath();
    for (let i = 0; i < 4; i++) {
      ctx.arc(cathX, beamY - 12 + i * 8, 4, Math.PI * 0.5, Math.PI * 1.5, i % 2 === 0);
    }
    ctx.stroke();
    const glow = ctx.createRadialGradient(cathX, beamY, 2, cathX, beamY, 26);
    glow.addColorStop(0, 'rgba(251,191,36,0.5)'); glow.addColorStop(1, 'transparent');
    ctx.fillStyle = glow;
    ctx.beginPath(); ctx.arc(cathX, beamY, 26, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#92400e'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('cathode (−)', cathX, beamY + 44);
    ctx.fillText('hot filament', cathX, beamY + 55);
    ctx.restore();

    // Anode: angled tungsten/molybdenum target block
    ctx.save();
    ctx.fillStyle = '#64748b';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    // Angled face
    ctx.fillStyle = '#475569';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 18, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#334155'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('anode (+)', anodeX + 24, beamY - 42);
    ctx.fillText('Mo target', anodeX + 24, beamY + 48);
    ctx.restore();

    // Electron beam
    ctx.save();
    electronsRef.current.forEach(e => {
      ctx.beginPath(); ctx.arc(e.x, e.y, 3, 0, Math.PI * 2);
      ctx.fillStyle = '#0ea5e9'; ctx.fill();
    });
    ctx.restore();

    // X-rays: wavy rays leaving the target downward through a window
    ctx.save();
    ctx.strokeStyle = '#8b5cf6'; ctx.lineWidth = 1.6;
    raysRef.current.forEach(r => {
      const ox = anodeX + 8, oy = beamY + 10;
      ctx.beginPath();
      for (let d = Math.max(0, r.p - 34); d <= r.p; d += 3) {
        const wob = Math.sin(d * 0.55) * 3;
        const x = ox + Math.cos(r.ang) * d - Math.sin(r.ang) * wob;
        const y = oy + Math.sin(r.ang) * d + Math.cos(r.ang) * wob;
        if (d === Math.max(0, r.p - 34)) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    });
    ctx.fillStyle = '#7c3aed'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('X-rays', anodeX + 8, H - 40);
    ctx.restore();

    // HV supply annotation
    ctx.save();
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
    ctx.beginPath(); ctx.moveTo(cathX, 60); ctx.lineTo(cathX, 34); ctx.lineTo(anodeX + 24, 34); ctx.lineTo(anodeX + 24, 60); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.kV} kV`, (cathX + anodeX) / 2, 28);
    ctx.restore();

    // Status
    ctx.fillStyle = s.kV >= MO_EXCITATION_KV ? '#059669' : '#64748b';
    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.kV >= MO_EXCITATION_KV
        ? 'V above 20 kV — characteristic Kα/Kβ lines appear in the spectrum'
        : 'Continuous (bremsstrahlung) spectrum only — raise V past 20 kV for the K lines',
      W / 2, H - 24,
    );

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`λmin = hc/eV = ${lambdaMinNm(s.kV).toFixed(4)} nm   e⁻ speed ≈ ${(electronSpeedFraction(s.kV) * 100).toFixed(0)}% of c   ~99% of the energy becomes HEAT in the anode`, 8, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/FrictionCanvas.tsx"
cat > "src/components/simulation/FrictionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { flatFriction, inclineFriction } from '@/lib/physics/friction';

export type FrictionMode = 'flat' | 'incline';

interface Props {
  mode: FrictionMode;
  mass: number;
  applied: number;      // N (flat mode)
  angle: number;        // degrees (incline mode)
  muS: number; muK: number;
  isRunning: boolean; isPaused: boolean;
  resetKey: number;
  width?: number; height?: number;
}

function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, dx: number, dy: number, color: string, label: string, labelDy = -8) {
  const len = Math.hypot(dx, dy);
  if (len < 1) return;
  const ang = Math.atan2(dy, dx);
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + dx, y + dy); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x + dx, y + dy);
  ctx.lineTo(x + dx - 9 * Math.cos(ang - 0.4), y + dy - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(x + dx - 9 * Math.cos(ang + 0.4), y + dy - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dx, y + dy + labelDy);
  ctx.restore();
}

export function FrictionCanvas({ mode, mass, applied, angle, muS, muK, isRunning, isPaused, resetKey, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const posRef = useRef(0);   // metres travelled
  const velRef = useRef(0);   // m/s
  const tRef = useRef(0);
  const sim = useRef({ mode, mass, applied, angle, muS, muK, isRunning, isPaused });
  sim.current = { mode, mass, applied, angle, muS, muK, isRunning, isPaused };

  useEffect(() => {
    posRef.current = 0; velRef.current = 0; tRef.current = 0;
    lastFrameRef.current = null;
  }, [mode, mass, applied, angle, muS, muK, resetKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const SCALE = 1.4; // px per N for arrows

    if (s.mode === 'flat') {
      const r = flatFriction(s.mass, s.applied, s.muS, s.muK);
      // Wall-clock physics integration once sliding
      if (dt > 0 && r.moving) {
        velRef.current += r.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const groundY = H - 70;
      const bw = 70, bh = 48;
      const px = 60 + ((posRef.current * 40) % (W - 180)); // wraps to stay on screen
      // Ground with texture ∝ μ
      ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, 70);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      const rough = 6 + s.muS * 20;
      for (let x = 4; x < W; x += rough) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 4, groundY + 5); ctx.stroke();
      }
      // Block
      ctx.fillStyle = r.moving ? '#f59e0b' : '#6366f1';
      ctx.fillRect(px, groundY - bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass} kg`, px + bw / 2, groundY - bh / 2 + 4);
      const cx = px + bw / 2, cy = groundY - bh / 2;
      // Forces
      forceArrow(ctx, px + bw, cy, Math.min(s.applied * SCALE, 150), 0, '#059669', `F = ${s.applied.toFixed(0)}N`, -10);
      forceArrow(ctx, px, cy, -Math.min(r.friction * SCALE, 150), 0, '#ef4444', `f = ${r.friction.toFixed(1)}N`, -10);
      forceArrow(ctx, cx, groundY - bh, 0, -Math.min(r.N * SCALE * 0.5, 70), '#3b82f6', `N`, -6);
      forceArrow(ctx, cx, groundY, 0, Math.min(r.N * SCALE * 0.5, 60), '#8b5cf6', `mg`, 14);
      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (!r.moving) {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — friction matches F exactly (limit: μsN = ${r.staticMax.toFixed(1)}N)`, W / 2, 28);
      } else {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING — kinetic friction μkN = ${r.friction.toFixed(1)}N,  a = ${r.acceleration.toFixed(2)} m/s²`, W / 2, 28);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   distance = ${posRef.current.toFixed(1)} m   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
    }

    if (s.mode === 'incline') {
      const r = inclineFriction(s.mass, s.angle, s.muS, s.muK);
      if (dt > 0 && r.sliding) {
        velRef.current += r.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const th = (s.angle * Math.PI) / 180;
      const baseX = 60, baseY = H - 50;
      const slopeLen = Math.min((W - 140) / Math.cos(th), (H - 110) / Math.max(Math.sin(th), 0.05));
      const topX = baseX + slopeLen * Math.cos(th);
      const topY = baseY - slopeLen * Math.sin(th);
      // Hill
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.lineTo(topX, baseY); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(baseX - 40, baseY); ctx.lineTo(W, baseY); ctx.stroke();
      // Angle arc
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(baseX, baseY, 34, -th, 0); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`θ = ${s.angle}°`, baseX + 40, baseY - 8);
      // Block on the slope (slides down from 75% up)
      const sMax = slopeLen * 0.7;
      const sPos = Math.min(posRef.current * 30, sMax * 0.95);
      const along = slopeLen * 0.75 - sPos;
      const bx = baseX + along * Math.cos(th);
      const by = baseY - along * Math.sin(th);
      const bw = 54, bh = 36;
      ctx.save();
      ctx.translate(bx, by); ctx.rotate(-th);
      ctx.fillStyle = r.sliding ? '#f59e0b' : '#6366f1';
      ctx.fillRect(-bw / 2, -bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, 0, -bh / 2 + 3);
      ctx.restore();
      // Forces (in slope frame, drawn in world coordinates)
      const c0x = bx, c0y = by - bh / 2;
      const dirDown: [number, number] = [-Math.cos(th), Math.sin(th)];
      const dirN: [number, number] = [-Math.sin(th), -Math.cos(th)];
      forceArrow(ctx, c0x, c0y, dirDown[0] * Math.min(r.gravityAlong * SCALE, 110), dirDown[1] * Math.min(r.gravityAlong * SCALE, 110), '#8b5cf6', `mg sinθ = ${r.gravityAlong.toFixed(1)}N`, -8);
      forceArrow(ctx, c0x, c0y, -dirDown[0] * Math.min(r.friction * SCALE, 110), -dirDown[1] * Math.min(r.friction * SCALE, 110), '#ef4444', `f = ${r.friction.toFixed(1)}N`, 14);
      forceArrow(ctx, c0x, c0y, dirN[0] * Math.min(r.N * SCALE * 0.5, 70), dirN[1] * Math.min(r.N * SCALE * 0.5, 70), '#3b82f6', 'N', -6);
      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (!r.sliding) {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — tilts to ${r.reposeAngle.toFixed(1)}° (angle of repose, tanθr = μs) before slipping`, W / 2, 28);
      } else {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING — a = g(sinθ − μk cosθ) = ${r.acceleration.toFixed(2)} m/s²`, W / 2, 28);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/HeatTransferCanvas.tsx"
cat > "src/components/simulation/HeatTransferCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type HeatMode = 'conduction' | 'convection' | 'radiation';

interface Props {
  mode: HeatMode;
  hotTemp: number;    // °C
  coldTemp: number;   // °C
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Temperature → colour (blue 0° → red 100°+)
function tempColor(tc: number, alpha = 1): string {
  const t = Math.min(1, Math.max(0, tc / 120));
  const r = Math.round(59 + t * (239 - 59));
  const g = Math.round(130 - t * (130 - 68));
  const b = Math.round(246 - t * (246 - 68));
  return `rgba(${r},${g},${b},${alpha})`;
}

function flame(ctx: CanvasRenderingContext2D, x: number, y: number, t: number) {
  ctx.save();
  for (let i = 0; i < 3; i++) {
    const wob = Math.sin(t * 7 + i * 2) * 3;
    const h = 20 + i * -5 + Math.sin(t * 9 + i) * 3;
    ctx.beginPath();
    ctx.moveTo(x - 8 + i * 8 + wob, y);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob - 5, y - h / 2, x - 8 + i * 8 + wob, y - h);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob + 5, y - h / 2, x - 8 + i * 8 + wob, y);
    ctx.fillStyle = i === 1 ? '#f59e0b' : '#ef4444';
    ctx.globalAlpha = 0.85;
    ctx.fill();
  }
  ctx.restore();
}

export function HeatTransferCanvas({ mode, hotTemp, coldTemp, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const warmthRef = useRef(0); // radiation target warming 0→1
  const sim = useRef({ mode, hotTemp, coldTemp, isRunning, isPaused });
  sim.current = { mode, hotTemp, coldTemp, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null; warmthRef.current = 0;
  }, [mode, hotTemp, coldTemp]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'conduction') {
      // Metal rod, hot left → cold right; particles vibrate harder where hotter.
      const rodY = H / 2 - 20, rodH = 56, rodX = 80, rodW = W - 160;
      const grad = ctx.createLinearGradient(rodX, 0, rodX + rodW, 0);
      grad.addColorStop(0, tempColor(s.hotTemp, 0.35));
      grad.addColorStop(1, tempColor(s.coldTemp, 0.35));
      ctx.fillStyle = grad;
      ctx.fillRect(rodX, rodY, rodW, rodH);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.strokeRect(rodX, rodY, rodW, rodH);
      // Particles: fixed lattice positions, vibration amplitude ∝ local T.
      // Energy passes along WITHOUT the particles migrating — that is conduction.
      const cols = 22, rows = 3;
      for (let c = 0; c < cols; c++) {
        const frac = c / (cols - 1);
        const localT = s.hotTemp + (s.coldTemp - s.hotTemp) * frac;
        // The "wave" of vibration spreads left→right over time
        const reached = t * 4 > frac * 10;
        const amp = reached ? 1.5 + (localT / 120) * 5 : 1;
        for (let r = 0; r < rows; r++) {
          const x0 = rodX + 16 + c * ((rodW - 32) / (cols - 1));
          const y0 = rodY + 14 + r * ((rodH - 28) / (rows - 1));
          const jx = Math.sin(t * (9 + c) + r * 2) * amp;
          const jy = Math.cos(t * (11 + c * 0.7) + r) * amp;
          ctx.beginPath(); ctx.arc(x0 + jx, y0 + jy, 3.4, 0, Math.PI * 2);
          ctx.fillStyle = tempColor(localT); ctx.fill();
        }
      }
      flame(ctx, rodX + 8, rodY + rodH + 44, t);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`HOT ${s.hotTemp}°C`, rodX + 20, rodY - 10);
      ctx.fillText(`COLD ${s.coldTemp}°C`, rodX + rodW - 24, rodY - 10);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('Particles vibrate harder and pass energy along — they do NOT move down the rod', W / 2, H - 26);
    }

    if (s.mode === 'convection') {
      // Beaker of fluid with a circulation loop; heated at bottom-left.
      const bx = W / 2 - 130, by = 50, bw = 260, bh = H - 130;
      ctx.fillStyle = 'rgba(186,230,253,0.4)';
      ctx.fillRect(bx, by, bw, bh);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(bx, by); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by);
      ctx.stroke();
      // Particles circulate on an ellipse: rise on the heated left, sink right.
      const cxm = bx + bw / 2, cym = by + bh / 2;
      const rx = bw / 2 - 30, ry = bh / 2 - 24;
      const N = 26;
      for (let i = 0; i < N; i++) {
        const phase = (i / N) * Math.PI * 2 + t * 0.8;
        // parametric loop: angle 0 = bottom-left rising
        const px = cxm - Math.cos(phase) * rx;
        const py = cym + Math.sin(phase) * ry * (Math.cos(phase) > 0 ? 1 : 1);
        const yFrac = (py - by) / bh;            // 0 top … 1 bottom
        const rising = Math.sin(phase) < 0 ? false : true;
        void rising;
        const localT = s.hotTemp * (1 - yFrac) * 0.4 + (yFrac > 0.7 && px < cxm ? s.hotTemp : s.coldTemp + (s.hotTemp - s.coldTemp) * (1 - yFrac) * 0.6);
        ctx.beginPath(); ctx.arc(px, py, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = tempColor(Math.min(localT, 110)); ctx.fill();
      }
      // Loop arrows
      ctx.save();
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.ellipse(cxm, cym, rx, ry, 0, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('warm, less dense → RISES', bx - 4, cym - 8);
      ctx.fillStyle = '#3b82f6';
      ctx.fillText('cool, denser → SINKS', bx + bw + 6, cym - 8);
      flame(ctx, bx + 50, by + bh + 44, t);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('A convection current: the FLUID ITSELF moves, carrying the energy', W / 2, H - 26);
    }

    if (s.mode === 'radiation') {
      // Heater/Sun on the left radiating across a vacuum to an object.
      const sx = 90, sy = H / 2 - 12;
      warmthRef.current = Math.min(1, warmthRef.current + dt * 0.12 * (s.hotTemp / 100));
      // Sun
      const sun = ctx.createRadialGradient(sx, sy, 4, sx, sy, 34);
      sun.addColorStop(0, '#fde047'); sun.addColorStop(1, '#f59e0b');
      ctx.beginPath(); ctx.arc(sx, sy, 30, 0, Math.PI * 2);
      ctx.fillStyle = sun; ctx.fill();
      // Rays: wavy IR arrows travelling right
      ctx.save();
      ctx.strokeStyle = '#f97316'; ctx.lineWidth = 1.6;
      for (let r = -2; r <= 2; r++) {
        const y0 = sy + r * 26;
        const speed = 130;
        const head = (t * speed) % (W - 220);
        ctx.beginPath();
        for (let d = 0; d <= head; d += 4) {
          const x = sx + 40 + d;
          const y = y0 + Math.sin(d * 0.25 - t * 6) * 5;
          if (d === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }
      ctx.restore();
      // Vacuum label
      ctx.fillStyle = '#94a3b8'; ctx.font = 'italic 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('VACUUM — no particles needed', W / 2, 40);
      // Object warming up
      const ox = W - 130, oy = H / 2 - 40, ow = 60, oh = 80;
      const objT = s.coldTemp + (s.hotTemp - s.coldTemp) * warmthRef.current * 0.7;
      ctx.fillStyle = tempColor(objT, 0.8);
      ctx.fillRect(ox, oy, ow, oh);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.strokeRect(ox, oy, ow, oh);
      ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui';
      ctx.fillText(`${objT.toFixed(0)}°C`, ox + ow / 2, oy + oh / 2 + 4);
      ctx.fillText('absorber', ox + ow / 2, oy + oh + 16);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('Infrared electromagnetic waves — the ONLY mode that crosses empty space (Sun → Earth)', W / 2, H - 26);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`t = ${t.toFixed(1)}s`, 8, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/ElasticityCanvas.tsx"
cat > "src/components/simulation/ElasticityCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { extension, springEnergy, wireExtension, stress, strain } from '@/lib/physics/elasticity';

export type ElasticityMode = 'hooke' | 'wire';

interface Props {
  mode: ElasticityMode;
  load: number;         // N
  k: number;            // N/m (hooke mode)
  elasticLimitF: number;
  // wire mode:
  wireLength: number;   // m
  wireDiamMm: number;   // mm
  youngE: number;       // Pa
  materialName: string;
  width?: number; height?: number;
}

function drawCoil(ctx: CanvasRenderingContext2D, x: number, yTop: number, len: number, coils = 10, r = 16) {
  ctx.save();
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x, yTop);
  const seg = len / (coils + 1);
  ctx.lineTo(x, yTop + seg / 2);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + (i % 2 === 0 ? r : -r), yTop + seg / 2 + seg * i + seg / 2);
  }
  ctx.lineTo(x, yTop + len - seg / 2);
  ctx.lineTo(x, yTop + len);
  ctx.stroke();
  ctx.restore();
}

export function ElasticityCanvas({ mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, width = 640, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName });
  sim.current = { mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#cbd5e1'; ctx.fillRect(0, 20, W, 10);
    ctx.strokeStyle = '#94a3b8';
    for (let x = 6; x < W; x += 14) {
      ctx.beginPath(); ctx.moveTo(x, 20); ctx.lineTo(x - 6, 12); ctx.stroke();
    }

    if (s.mode === 'hooke') {
      const e = extension(s.load, s.k);                 // metres
      const beyondLimit = s.load > s.elasticLimitF;
      const eScale = 900;                                // px per metre
      const natural = 90;
      const xUnloaded = W / 2 - 130, xLoaded = W / 2 + 90;

      // Reference (unloaded) spring
      drawCoil(ctx, xUnloaded, 30, natural);
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(xUnloaded - 60, 30 + natural); ctx.lineTo(xLoaded + 80, 30 + natural); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('natural length', xUnloaded, 30 + natural + 18);

      // Loaded spring
      const stretch = Math.min(e * eScale, H - 200);
      drawCoil(ctx, xLoaded, 30, natural + stretch);
      // Mass
      const mw = 56, mh = 40;
      ctx.fillStyle = beyondLimit ? '#ef4444' : '#6366f1';
      ctx.fillRect(xLoaded - mw / 2, 30 + natural + stretch, mw, mh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui';
      ctx.fillText(`${s.load.toFixed(0)}N`, xLoaded, 30 + natural + stretch + mh / 2 + 4);

      // Extension bracket
      if (stretch > 6) {
        const bx = xLoaded + 60;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + natural); ctx.lineTo(bx, 30 + natural + stretch); ctx.stroke();
        [30 + natural, 30 + natural + stretch].forEach(y => {
          ctx.beginPath(); ctx.moveTo(bx - 4, y); ctx.lineTo(bx + 4, y); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(e * 100).toFixed(1)} cm`, bx + 8, 30 + natural + stretch / 2 + 3);
      }

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (beyondLimit) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`BEYOND THE ELASTIC LIMIT (${s.elasticLimitF}N) — permanent deformation, Hooke's law no longer holds`, W / 2, H - 30);
      } else {
        ctx.fillStyle = '#059669';
        ctx.fillText(`Hooke's law: e ∝ F   —   energy stored = ½Fe = ${springEnergy(s.k, e).toFixed(2)} J`, W / 2, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`k = ${s.k} N/m   F = ke check: ${s.load.toFixed(0)}N / ${s.k} = ${(e * 100).toFixed(1)} cm`, 8, H - 10);
    }

    if (s.mode === 'wire') {
      const A = Math.PI * Math.pow((s.wireDiamMm / 1000) / 2, 2);  // m²
      const e = wireExtension(s.load, s.wireLength, A, s.youngE);   // metres (tiny!)
      const sg = stress(s.load, A);
      const sn = strain(e, s.wireLength);

      const x = W / 2 - 60;
      const naturalPx = H - 150;
      // Real extensions are fractions of a millimetre — magnified ×2000 on
      // screen so students can SEE it; true values printed below.
      const MAG = 2000;
      const stretchPx = Math.min(e * MAG, 90);

      // Wire (thickness from diameter)
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
      ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 30 + naturalPx + stretchPx); ctx.stroke();
      // Original end marker
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x - 70, 30 + naturalPx); ctx.lineTo(x + 150, 30 + naturalPx); ctx.stroke();
      ctx.setLineDash([]);
      // Load
      const mw = 60, mh = 40;
      ctx.fillStyle = '#6366f1';
      ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx, mw, mh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + mh / 2 + 4);
      // Extension bracket (magnified)
      if (stretchPx > 3) {
        const bx = x + 70;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + naturalPx); ctx.lineTo(bx, 30 + naturalPx + stretchPx); ctx.stroke();
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(e * 1000).toFixed(3)} mm (shown ×${MAG})`, bx + 8, 30 + naturalPx + stretchPx / 2 + 3);
      }

      // Info card
      ctx.save();
      const cx0 = W - 250, cy0 = 46;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(cx0, cy0, 236, 118, 10); ctx.fill();
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${s.materialName} wire`, cx0 + 12, cy0 + 20);
      ctx.font = '10px monospace'; ctx.fillStyle = '#475569';
      const lines = [
        `L = ${s.wireLength} m,  d = ${s.wireDiamMm} mm`,
        `A = πd²/4 = ${(A * 1e6).toFixed(4)} mm²`,
        `stress σ = F/A = ${(sg / 1e6).toFixed(1)} MPa`,
        `strain ε = e/L = ${sn.toExponential(2)}`,
        `E = σ/ε = ${(s.youngE / 1e9).toFixed(0)} GPa`,
      ];
      lines.forEach((l, i) => ctx.fillText(l, cx0 + 12, cy0 + 40 + i * 16));
      ctx.restore();

      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Young's modulus is a MATERIAL property — same E whatever the wire's size. e = FL/(AE)`, 8, H - 10);
    }
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/app/simulations/photoelectric-effect/page.tsx"
cat > "src/app/simulations/photoelectric-effect/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PhotoelectricCanvas } from '@/components/simulation/PhotoelectricCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { METALS, keMaxEV, thresholdF14, stoppingPotential, photonEnergyEV, wavelengthNm, keLine } from '@/lib/physics/photoelectric';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The killer observation classical physics could NOT explain: below the threshold frequency f₀ = φ/h, NO electrons are emitted no matter how intense the light. Try it — set red light on zinc and crank the intensity.',
  'Light arrives as PHOTONS of energy E = hf. One photon frees at most one electron: hf = φ + KEmax (Einstein, Nobel Prize 1921).',
  'Intensity controls the NUMBER of photons → the photocurrent. Frequency controls the ENERGY of each electron. Watch: more intensity = more electrons, not faster ones.',
  'The KEmax–f graph is a straight line with slope h/e (the same for every metal!) and x-intercept f₀. Different metals shift the line, never tilt it.',
  'Stopping potential Vs: the reverse voltage that just stops the fastest electrons — eVs = KEmax, so Vs in volts equals KEmax in eV.',
];

const EXERCISES = [
  { q: 'Light of frequency 7×10¹⁴ Hz falls on sodium (φ = 2.28 eV). Find the photon energy and KEmax. (h = 6.63×10⁻³⁴ Js, e = 1.6×10⁻¹⁹ C)', a: 'E = hf = 6.63e-34 × 7e14 = 4.64e-19 J = 2.90 eV. KEmax = 2.90 − 2.28 = 0.62 eV ≈ 1.0×10⁻¹⁹ J.' },
  { q: 'The threshold wavelength of a metal is 500 nm. Find its work function in eV.', a: 'φ = hc/λ₀ = (6.63e-34 × 3e8)/5e-7 = 3.98e-19 J ≈ 2.48 eV.' },
  { q: 'Doubling the intensity of light on a photocell does what to (a) the current, (b) the KEmax?', a: '(a) Current doubles — twice as many photons free twice as many electrons. (b) KEmax is unchanged — each photon still carries the same energy hf.' },
  { q: 'For caesium (φ = 2.1 eV) lit at f = 8×10¹⁴ Hz, find the stopping potential.', a: 'E = hf = 3.31 eV. KEmax = 3.31 − 2.1 = 1.21 eV, so Vs = 1.21 V.' },
];

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

// KEmax vs f graph: straight line of universal slope h/e, x-intercept f₀.
function KEGraph({ phiEV, f14 }: { phiEV: number; f14: number }) {
  const fMax = 14;
  const data = useMemo(() => keLine(phiEV, fMax), [phiEV]);
  const f0 = thresholdF14(phiEV);
  const ke = keMaxEV(f14, phiEV);
  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="f" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Frequency f (×10¹⁴ Hz)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="KEmax (eV)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' eV', 'KEmax']} labelFormatter={f => `f = ${f}×10¹⁴ Hz`} />
        <Line type="linear" dataKey="ke" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={f0} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'f₀', position: 'top', fontSize: 10, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(f14, fMax)} y={ke} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function PhotoelectricPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [metalIdx, setMetalIdx] = useState(0);
  const [f14, setF14] = useState(6.0);
  const [intensity, setIntensity] = useState(5);

  const metal = METALS[metalIdx];
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [metalIdx, f14, intensity, reset]);

  const ke = keMaxEV(f14, metal.phi);
  const f0 = thresholdF14(metal.phi);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Photoelectric effect</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Einstein&apos;s photoelectric equation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">hf = φ + KEmax</span>
            <span className="text-xs text-gray-400 ml-2">f₀ = φ/h &nbsp;|&nbsp; eVs = KEmax</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <PhotoelectricCanvas f14={f14} intensity={intensity} phiEV={metal.phi} metalName={metal.name}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/photoelectric"
                  title="Photoelectric effect — A-Factor STEM Studio"
                  params={{ metal: metalIdx, f: f14, i: intensity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">KEmax against frequency</p>
                <KEGraph phiEV={metal.phi} f14={f14} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Slope = h/e for EVERY metal · x-intercept = threshold f₀ · red dot = your current light
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {METALS.map((m, i) => (
                    <button key={m.name} onClick={() => setMetalIdx(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        metalIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{m.name} ({m.phi} eV)</button>
                  ))}
                </div>
                <Slider label="Light frequency" unit="×10¹⁴ Hz" value={f14} min={2} max={14} step={0.1} set={setF14} color="#6366f1"
                  note={`Threshold for ${metal.name}: f₀ = ${f0.toFixed(2)}×10¹⁴ Hz — drop below it and emission stops`} />
                <Slider label="Intensity" unit="" value={intensity} min={1} max={10} step={1} set={setIntensity} color="#f59e0b"
                  note="Changes how MANY electrons per second — never their energy" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Photon energy hf" value={photonEnergyEV(f14).toFixed(2)} unit="eV" color="text-indigo-600" />
                  <StatRow label="Wavelength λ" value={wavelengthNm(f14).toFixed(0)} unit="nm" color="text-emerald-600" />
                  <StatRow label="Work function φ" value={metal.phi.toFixed(2)} unit="eV" color="text-amber-600" />
                  <StatRow label="Threshold f₀" value={f0.toFixed(2)} unit="×10¹⁴ Hz" color="text-rose-500" />
                  <StatRow label="KEmax" value={ke.toFixed(2)} unit="eV" color="text-purple-600" />
                  <StatRow label="Stopping potential" value={stoppingPotential(f14, metal.phi).toFixed(2)} unit="V" color="text-gray-600" />
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
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
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/simulations/de-broglie/page.tsx"
cat > "src/app/simulations/de-broglie/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DeBroglieCanvas } from '@/components/simulation/DeBroglieCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PARTICLES, deBroglieLambda, momentum, formatLambda, lambdaFromVoltage } from '@/lib/physics/debroglie';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'De Broglie (1924): if light waves can behave as particles (photons), then particles should behave as waves — λ = h/mv. Confirmed by Davisson–Germer electron diffraction in 1927.',
  'The key comparison: an electron at 2×10⁶ m/s has λ ≈ 0.36 nm (atom-sized → diffracts off crystals) while a cricket ball has λ ≈ 10⁻³⁴ m — unimaginably smaller than a nucleus, so we never see cricket balls diffract.',
  'Larger momentum → shorter wavelength. Switch particles and watch λ collapse: mass in the denominator is why wave behaviour is invisible for everyday objects.',
  'Electron microscopes exploit this: electrons accelerated through kilovolts get λ far below visible light (400–700 nm), resolving individual atoms.',
  'For an electron accelerated through voltage V: λ = h/√(2meV) ≈ 1.23/√V nm — a favourite exam derivation (KE = eV = p²/2m).',
];

const EXERCISES = [
  { q: 'Find the de Broglie wavelength of an electron (m = 9.11×10⁻³¹ kg) moving at 2×10⁶ m/s.', a: 'λ = h/mv = 6.63e-34 / (9.11e-31 × 2e6) = 3.6×10⁻¹⁰ m = 0.36 nm.' },
  { q: 'A 0.16 kg cricket ball travels at 30 m/s. Find λ and explain why we never observe its wave nature.', a: 'λ = 6.63e-34/(0.16×30) ≈ 1.4×10⁻³⁴ m — about 10¹⁹ times smaller than a nucleus, far too small for any slit or detector.' },
  { q: 'An electron is accelerated from rest through 100 V. Find its de Broglie wavelength.', a: 'λ = h/√(2meV) = 6.63e-34/√(2×9.11e-31×1.6e-19×100) ≈ 1.23×10⁻¹⁰ m ≈ 0.123 nm.' },
  { q: 'A proton and an electron have the SAME speed. Which has the longer wavelength and by what factor?', a: 'λ ∝ 1/m at fixed v, so the electron: longer by mp/me ≈ 1836 times.' },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value.toExponential(2)} <span className="text-gray-400 font-normal">{unit}</span></span>
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

export default function DeBrogliePage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [pIdx, setPIdx] = useState(0);
  const particle = PARTICLES[pIdx];
  const [velocity, setVelocity] = useState(particle.vDefault);
  const [accelV, setAccelV] = useState(100);

  const selectParticle = (i: number) => { setPIdx(i); setVelocity(PARTICLES[i].vDefault); };

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pIdx, velocity, reset]);

  const lambda = deBroglieLambda(particle.mass, velocity);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">De Broglie hypothesis</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Matter waves</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λ = h/mv = h/p</span>
            <span className="text-xs text-gray-400 ml-2">accelerated electron: λ = h/√(2meV)</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DeBroglieCanvas mass={particle.mass} velocity={velocity} particleName={particle.name}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/debroglie"
                  title="De Broglie wavelength — A-Factor STEM Studio"
                  params={{ p: pIdx, v: velocity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {PARTICLES.map((p, i) => (
                    <button key={p.name} onClick={() => selectParticle(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        pIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{p.emoji} {p.name}</button>
                  ))}
                </div>
                <Slider label="Speed v" unit="m/s" value={velocity} min={particle.vMin} max={particle.vMax}
                  step={(particle.vMax - particle.vMin) / 200} set={setVelocity} color="#6366f1"
                  note="Faster → more momentum → SHORTER wavelength" />
                <div className="rounded-xl bg-indigo-50 border border-indigo-100 p-3 space-y-2">
                  <p className="text-[11px] font-medium text-indigo-700">Electron gun calculator: λ = h/√(2meV)</p>
                  <Slider label="Accelerating voltage" unit="V" value={accelV} min={10} max={10000} step={10} set={setAccelV} color="#8b5cf6" />
                  <p className="text-xs text-indigo-800 font-mono">
                    V = {accelV} V → λ = {formatLambda(lambdaFromVoltage(accelV))}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Mass m" value={particle.mass.toExponential(2)} unit="kg" color="text-indigo-600" />
                  <StatRow label="Momentum p" value={momentum(particle.mass, velocity).toExponential(2)} unit="kg·m/s" color="text-emerald-600" />
                  <StatRow label="Wavelength λ" value={formatLambda(lambda)} unit="" color="text-amber-600" />
                  <StatRow label="vs atom (0.1nm)" value={(lambda / 1e-10).toExponential(1)} unit="×" color="text-rose-500" />
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
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
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/simulations/x-rays/page.tsx"
cat > "src/app/simulations/x-rays/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { XrayCanvas } from '@/components/simulation/XrayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { lambdaMinNm, maxPhotonEnergyKeV, xraySpectrum, MO_K_ALPHA_NM, MO_K_BETA_NM, MO_EXCITATION_KV } from '@/lib/physics/xrays';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'X-ray production is the photoelectric effect in REVERSE: fast electrons in, photons out. Electrons accelerated through kV strike a metal target; ~99% of their energy becomes heat, ~1% becomes X-rays (which is why anodes are cooled or rotated).',
  'The continuous (bremsstrahlung = "braking radiation") spectrum has a sharp cutoff λmin = hc/eV — the Duane–Hunt limit. An electron cannot give a photon more than its whole kinetic energy eV.',
  'Raise the tube voltage: λmin slides LEFT (shorter, more penetrating "harder" X-rays). Raise the filament current: MORE X-rays (taller spectrum), same λmin.',
  'The sharp Kα/Kβ characteristic lines appear only when electrons can knock out inner-shell electrons of the target (Mo: above ~20 kV). Their wavelengths identify the target element — the basis of X-ray spectroscopy.',
  'Properties for exams: travel in straight lines, not deflected by electric/magnetic fields (uncharged), ionise gases, penetrate matter (absorbed by dense material like bone/lead), affect photographic film.',
];

const EXERCISES = [
  { q: 'An X-ray tube runs at 50 kV. Find the minimum wavelength produced. (h = 6.63×10⁻³⁴ Js, c = 3×10⁸ m/s, e = 1.6×10⁻¹⁹ C)', a: 'λmin = hc/eV = (6.63e-34 × 3e8)/(1.6e-19 × 5e4) = 2.49×10⁻¹¹ m ≈ 0.025 nm.' },
  { q: 'What is the maximum photon energy (in keV) from a 80 kV tube, and why is it a maximum?', a: '80 keV — a photon cannot carry more than the full kinetic energy eV of one electron; most electrons give up their energy in stages (heat + softer photons).' },
  { q: 'Doubling the filament current does what to (a) the spectrum height, (b) λmin?', a: '(a) Doubles the intensity everywhere — twice as many electrons. (b) λmin unchanged: it depends only on the tube voltage.' },
  { q: 'Why do the Kα and Kβ lines disappear when the tube voltage drops below 20 kV (Mo target)?', a: 'Below 20 kV the electrons lack the energy to eject a K-shell electron from molybdenum, so no inner-shell vacancies form and no characteristic photons are emitted.' },
];

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

function SpectrumGraph({ kV, current }: { kV: number; current: number }) {
  const data = useMemo(() => xraySpectrum(kV, current), [kV, current]);
  const lMin = lambdaMinNm(kV);
  return (
    <ResponsiveContainer width="100%" height={210}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="lambda" type="number" tick={{ fontSize: 10 }} domain={[0, 0.14]}>
          <Label value="Wavelength λ (nm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Intensity" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2), 'I']} labelFormatter={l => `λ=${Number(l).toFixed(3)}nm`} />
        <Line type="linear" dataKey="i" stroke="#8b5cf6" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={lMin} stroke="#ef4444" strokeDasharray="4 4"
          label={{ value: 'λmin', position: 'top', fontSize: 10, fill: '#dc2626' }} />
        {kV >= MO_EXCITATION_KV && <>
          <ReferenceLine x={MO_K_ALPHA_NM} stroke="#e2e8f0"
            label={{ value: 'Kα', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
          <ReferenceLine x={MO_K_BETA_NM} stroke="#e2e8f0"
            label={{ value: 'Kβ', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function XraysPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [kV, setKV] = useState(35);
  const [current, setCurrent] = useState(5);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [kV, current, reset]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">X-rays</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Duane–Hunt limit</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λmin = hc/eV</span>
            <span className="text-xs text-gray-400 ml-2">max photon energy = eV</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <XrayCanvas kV={kV} current={current}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/xrays"
                  title="X-ray tube — A-Factor STEM Studio"
                  params={{ kV, i: current }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">X-ray spectrum (Mo target)</p>
                <SpectrumGraph kV={kV} current={current} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Continuous bremsstrahlung with sharp cutoff at λmin — Kα/Kβ characteristic lines above {MO_EXCITATION_KV} kV
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Tube voltage" unit="kV" value={kV} min={5} max={100} step={1} set={setKV} color="#6366f1"
                  note="Higher V → shorter λmin → harder, more penetrating X-rays" />
                <Slider label="Filament current" unit="" value={current} min={1} max={10} step={1} set={setCurrent} color="#f59e0b"
                  note="More electrons → more X-rays, but λmin does not move" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="λmin" value={lambdaMinNm(kV).toFixed(4)} unit="nm" color="text-indigo-600" />
                  <StatRow label="Max photon energy" value={maxPhotonEnergyKeV(kV).toFixed(0)} unit="keV" color="text-emerald-600" />
                  <StatRow label="Electron KE" value={kV.toFixed(0)} unit="keV" color="text-amber-600" />
                  <StatRow label="K lines" value={kV >= MO_EXCITATION_KV ? 'visible' : 'absent'} unit="" color="text-rose-500" />
                  <StatRow label="Energy → heat" value="~99" unit="%" color="text-purple-600" />
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
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
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/simulations/friction/page.tsx"
cat > "src/app/simulations/friction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { flatFriction, inclineFriction, frictionCurve } from '@/lib/physics/friction';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<FrictionMode, { title: string; icon: string; sub: string; eq: string }> = {
  flat:    { title: 'Flat surface', icon: '➡️', sub: 'Push a block along the ground', eq: 'f ≤ μsN,  f = μkN once sliding' },
  incline: { title: 'Inclined plane', icon: '⛰️', sub: 'A block on a slope',           eq: 'tanθr = μs' },
};

const TEACHER_NOTES: Record<FrictionMode, string[]> = {
  flat: [
    'Static friction is NOT fixed — it exactly matches the applied force, up to a maximum of μsN. Push harder within that limit and friction grows to match; nothing moves.',
    'Once the applied force exceeds μsN, the block breaks free and KINETIC friction takes over — μk is always a little LESS than μs, which is why things "jerk" into motion.',
    'Friction is independent of the contact area and (to a good approximation) of speed — but always proportional to the normal reaction N.',
    'N = mg only holds here because the surface is flat and the push is horizontal — on a slope, or with an angled push, N changes.',
    'Real applications: brake pads (want HIGH μ), ice skates and ball bearings (want LOW μ), why worn tyres skid more easily.',
  ],
  incline: [
    'The angle at which a block JUST starts to slide is the angle of repose θr, where tanθr = μs — a clean way to measure friction experimentally.',
    'On the slope, gravity splits into two components: mg sinθ (down the slope, drives sliding) and mg cosθ (into the slope, creates the normal reaction N).',
    'Below θr the block is static and friction exactly balances mg sinθ. Above it, friction is capped at μkN and the block accelerates: a = g(sinθ − μk cosθ).',
    'This is literally how a plumb-line/tilt-table experiment measures μs for sand, wood, or rubber in a school lab.',
    'A steeper slope always needs a HIGHER μ to prevent sliding — this is why steep roofs need rougher tiles.',
  ],
};

const EXERCISES: Record<FrictionMode, { q: string; a: string }[]> = {
  flat: [
    { q: 'A 10kg block has μs=0.4. What is the maximum static friction force before it starts to slide?', a: 'N=mg=10×9.81=98.1N. F_s,max=μsN=0.4×98.1=39.2N.' },
    { q: 'A 5kg box needs 20N to start moving and 15N to keep it moving at constant velocity. Find μs and μk.', a: 'N=5×9.81=49.05N. μs=20/49.05=0.41. μk=15/49.05=0.31.' },
    { q: 'A 2kg block slides with μk=0.25 under a 15N push. Find its acceleration.', a: 'f=μkN=0.25×2×9.81=4.9N. Net=15−4.9=10.1N. a=10.1/2=5.05 m/s².' },
  ],
  incline: [
    { q: 'A block just begins to slide on a slope at 22°. Find μs.', a: 'μs = tan22° ≈ 0.40.' },
    { q: 'A 4kg block sits on a 35° slope with μs=0.5. Does it slide? Show your working.', a: 'mg sinθ = 4×9.81×sin35° ≈ 22.5N. μs·mg cosθ = 0.5×4×9.81×cos35° ≈ 16.1N. Since 22.5N > 16.1N, YES it slides.' },
    { q: 'A block slides down a 40° slope with μk=0.2. Find its acceleration.', a: 'a = g(sinθ − μk cosθ) = 9.81(sin40° − 0.2cos40°) ≈ 9.81(0.643−0.153) ≈ 4.81 m/s².' },
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

function FrictionGraph({ mass, muS, muK, applied }: { mass: number; muS: number; muK: number; applied: number }) {
  const fMax = mass * 9.81 * muS * 2.2;
  const data = useMemo(() => frictionCurve(mass, muS, muK, fMax), [mass, muS, muK, fMax]);
  const r = flatFriction(mass, applied, muS, muK);
  const staticLimit = muS * mass * 9.81;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="F" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Applied force F (N)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Friction f (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'f']} labelFormatter={f => `F=${Number(f).toFixed(1)}N`} />
        <Line type="linear" dataKey="f" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={staticLimit} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'μsN', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(applied, fMax)} y={r.friction} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function FrictionPage() {
  const [mode, setMode] = useState<FrictionMode>('flat');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [mass, setMass] = useState(5);
  const [applied, setApplied] = useState(15);
  const [angle, setAngle] = useState(20);
  const [muS, setMuS] = useState(0.4);
  const [muK, setMuK] = useState(0.3);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, mass, applied, angle, muS, muK, reset]);

  const flat = flatFriction(mass, applied, muS, muK);
  const inc = inclineFriction(mass, angle, muS, muK);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Friction</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as FrictionMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
                  muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
                  width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/friction"
                  title={`${MODE_META[mode].title} friction — A-Factor STEM Studio`}
                  params={{ mode, mass, applied, angle, muS, muK }} />
              </div>

              {mode === 'flat' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Friction vs applied force</p>
                  <FrictionGraph mass={mass} muS={muS} muK={muK} applied={applied} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Friction RISES to match F (static), then plateaus at μkN once sliding
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
                {mode === 'flat' && (
                  <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
                )}
                {mode === 'incline' && (
                  <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                )}
                <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
                <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" note="μk is kept ≤ μs, as it always is physically" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'flat' && <>
                    <StatRow label="Normal reaction N" value={flat.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="Max static friction" value={flat.staticMax.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Current friction" value={flat.friction.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="State" value={flat.moving ? 'sliding' : 'static'} unit="" color="text-rose-500" />
                    <StatRow label="Acceleration" value={flat.acceleration.toFixed(2)} unit="m/s²" color="text-purple-600" />
                  </>}
                  {mode === 'incline' && <>
                    <StatRow label="Normal reaction N" value={inc.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="mg sinθ" value={inc.gravityAlong.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Max static friction" value={inc.staticMax.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="Angle of repose" value={inc.reposeAngle.toFixed(1)} unit="°" color="text-rose-500" />
                    <StatRow label="State" value={inc.sliding ? 'sliding' : 'static'} unit="" color="text-purple-600" />
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
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
AFEOF

echo "  → src/app/simulations/heat-transfer/page.tsx"
cat > "src/app/simulations/heat-transfer/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { celsiusToKelvin, radiatedPower, netRadiation } from '@/lib/physics/heat';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<HeatMode, { title: string; icon: string; sub: string; eq: string }> = {
  conduction: { title: 'Conduction', icon: '🔗', sub: 'Solids — particle to particle', eq: 'Q/t = kAΔT/L' },
  convection: { title: 'Convection', icon: '🌀', sub: 'Fluids — bulk movement',        eq: 'warm rises, cool sinks' },
  radiation:  { title: 'Radiation',  icon: '☀️', sub: 'EM waves — needs no medium',    eq: 'P = εσAT⁴' },
};

const TEACHER_NOTES: Record<HeatMode, string[]> = {
  conduction: [
    'Particles do NOT travel down the rod — they vibrate in place and pass energy to their neighbours, like a row of people jiggling a rope.',
    'Metals conduct well because free (delocalised) electrons carry energy quickly through the lattice; non-metals lack these free electrons.',
    'Rate of heat flow: Q/t = kAΔT/L — bigger area or ΔT speeds it up, a thicker (longer) barrier slows it down. This is exactly why we use thick walls and small windows to keep buildings warm.',
    'Compare copper (k≈385) with glass (k≈0.8): copper conducts about 480 times faster — try both in the material list.',
    'Trapped air (double glazing, wool, fur) is a poor conductor and makes an excellent insulator, precisely because it has such a low k.',
  ],
  convection: [
    'Unlike conduction, the medium ITSELF moves in convection — warm fluid expands, becomes less dense, and rises; cooler, denser fluid sinks to replace it, setting up a convection current.',
    'This only happens in fluids (liquids and gases) — solids cannot flow, so they never convect.',
    'Real examples: sea breezes (land heats faster than sea by day), the radiator in a room (warms air rises, circulates the whole room), boiling water in a pot.',
    'Convection needs gravity (or an equivalent force) to drive the density difference — it does not work in free-fall / microgravity.',
    'The hotter the source, the faster and more vigorous the circulation — watch the particle loop speed up as you raise the temperature.',
  ],
  radiation: [
    'Radiation is the only mode of heat transfer that needs NO medium — infrared electromagnetic waves cross the vacuum of space, which is how the Sun warms the Earth.',
    'Stefan–Boltzmann law: P = εσAT⁴ — power radiated depends on the FOURTH power of absolute temperature, so a small temperature rise causes a huge jump in radiated power.',
    'Dull, black (matte) surfaces are good absorbers AND good emitters (high emissivity ε); shiny, silvered surfaces are poor absorbers/emitters — why vacuum flasks are silvered and radiators are painted matte black.',
    'All objects above 0 K radiate; the object also absorbs radiation from its surroundings, so the NET transfer depends on the temperature difference (T⁴ − T₀⁴).',
    'Applications: thermal imaging cameras detect the infrared radiated by warm bodies; a car left in the sun heats up mainly by absorbed solar radiation.',
  ],
};

const EXERCISES: Record<HeatMode, { q: string; a: string }[]> = {
  conduction: [
    { q: 'A copper bar (k=385 W/mK) of area 0.002m² and length 0.5m has a 60°C temperature difference across it. Find the rate of heat flow.', a: 'Q/t = kAΔT/L = 385×0.002×60/0.5 = 92.4 W.' },
    { q: 'Why do metal spoons feel colder to touch than wooden ones at the same room temperature?', a: 'Metal has much higher thermal conductivity, so it conducts heat away from your hand much faster than wood, feeling colder even though both are at the same temperature.' },
    { q: 'A wall has half the thickness of another identical wall. How does the rate of heat conduction compare?', a: 'Q/t ∝ 1/L, so halving the thickness DOUBLES the rate of heat loss.' },
  ],
  convection: [
    { q: 'Explain, using convection, why a radiator is placed near the floor rather than the ceiling.', a: 'Air warmed by the radiator becomes less dense and rises, setting up a convection current that circulates warm air throughout the whole room from the bottom up.' },
    { q: 'Why does a hot air balloon rise?', a: 'The burner heats the air inside, making it less dense than the surrounding cooler air, so the balloon experiences a net upward (buoyant) force — exactly like a convection current.' },
    { q: 'Why can convection not occur in a solid?', a: 'Convection requires bulk movement of particles; particles in a solid are fixed in place and cannot flow to create a circulation current.' },
  ],
  radiation: [
    { q: 'A black surface of area 0.01m² at 500K radiates into surroundings at 300K. Find the net power radiated. (σ = 5.67×10⁻⁸ W/m²K⁴, ε=1)', a: 'P = εσA(T⁴−T₀⁴) = 5.67e-8×0.01×(500⁴−300⁴) = 5.67e-10×(6.25e10−8.1e9) ≈ 30.7 W.' },
    { q: 'Why are the pipes of a solar water heater usually painted matte black?', a: 'Matte black surfaces are excellent absorbers of radiation, maximising the energy absorbed from sunlight to heat the water.' },
    { q: 'A star doubles in absolute temperature. By what factor does its radiated power increase?', a: 'P ∝ T⁴, so doubling T increases power by 2⁴ = 16 times.' },
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

export default function HeatTransferPage() {
  const [mode, setMode] = useState<HeatMode>('conduction');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [hotTemp, setHotTemp] = useState(90);
  const [coldTemp, setColdTemp] = useState(20);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, reset]);

  const Thot = celsiusToKelvin(hotTemp), Tcold = celsiusToKelvin(coldTemp);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Thermal physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Modes of heat transfer</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as HeatMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/heat"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, hot: hotTemp, cold: coldTemp }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
                <Slider label="Cold / surroundings temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="ΔT" value={(hotTemp - coldTemp).toFixed(0)} unit="°C" color="text-indigo-600" />
                  {mode === 'radiation' && <>
                    <StatRow label="Hot object radiates" value={radiatedPower(1, 0.01, Thot).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Net transfer" value={netRadiation(1, 0.01, Thot, Tcold).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="T⁴ ratio" value={Math.pow(Thot / Tcold, 4).toFixed(1)} unit="×" color="text-rose-500" />
                  </>}
                  {mode !== 'radiation' && (
                    <StatRow label="Direction" value="hot → cold" unit="always" color="text-emerald-600" />
                  )}
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
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
AFEOF

echo "  → src/app/simulations/elasticity/page.tsx"
cat > "src/app/simulations/elasticity/page.tsx" << 'AFEOF'
'use client';
import { useState, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { extension, springEnergy, forceExtensionCurve, wireExtension, stress, strain, youngModulus, WIRE_MATERIALS } from '@/lib/physics/elasticity';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ElasticityMode, { title: string; icon: string; sub: string; eq: string }> = {
  hooke: { title: "Hooke's law", icon: '🌀', sub: 'A loaded spring',       eq: 'F = ke' },
  wire:  { title: 'Young modulus', icon: '🧵', sub: 'Stretching a wire', eq: 'E = σ/ε = FL/(Ae)' },
};

const TEACHER_NOTES: Record<ElasticityMode, string[]> = {
  hooke: [
    "Hooke's law: extension is directly proportional to the applied force, e ∝ F, i.e. F = ke — but only up to the ELASTIC LIMIT.",
    'Beyond the elastic limit the spring deforms PERMANENTLY: it will not return to its natural length when the load is removed, and F = ke no longer applies.',
    'The spring constant k (N/m) measures stiffness: a bigger k means a stiffer spring that stretches less for the same force.',
    'Energy stored in a stretched (or compressed) spring: E = ½Fe = ½ke² — the area under a force–extension graph, used in catapults, archery bows, and pogo sticks.',
    'Springs in series share the load but each stretches independently (softer overall); springs in parallel share the extension (stiffer overall) — a nice follow-up demonstration.',
  ],
  wire: [
    'Stress σ = F/A (force per unit cross-sectional area) and strain ε = e/L (extension per unit original length) — both are needed because a thick wire stretches less than a thin one under the same force.',
    "Young's modulus E = σ/ε is a property of the MATERIAL only — steel always has the same E, whatever the wire's length or thickness.",
    'Real wire extensions under normal loads are tiny (often fractions of a millimetre) — this simulation magnifies the extension so you can see it; the true value is always shown in the info card.',
    'A stress–strain graph for a ductile material (like copper) shows a straight (Hookean) region, then plastic deformation, then a breaking point — steel and glass behave very differently here.',
    'Practical use: engineers select materials by their E value — steel cables for bridges need high E (stiff, minimal sag) while rubber seals need low E (flexible).',
  ],
};

const EXERCISES: Record<ElasticityMode, { q: string; a: string }[]> = {
  hooke: [
    { q: 'A spring stretches 4cm under a 20N load. Find its spring constant k.', a: 'k = F/e = 20/0.04 = 500 N/m.' },
    { q: 'A spring of k=250 N/m is stretched by 6cm. Find the elastic energy stored.', a: 'E = ½ke² = ½×250×0.06² = 0.45 J.' },
    { q: 'A spring obeys Hooke\'s law up to 30N, extending 10cm at that load. What extension would 45N (beyond the limit) roughly NOT follow, and why?', a: 'It would NOT simply extend to 15cm proportionally — beyond the elastic limit the material deforms plastically and extension grows faster than F for a given increase in load, and the deformation becomes permanent.' },
  ],
  wire: [
    { q: 'A steel wire (E=200 GPa) of length 2m and cross-sectional area 1×10⁻⁶ m² carries a 100N load. Find its extension.', a: 'e = FL/(AE) = (100×2)/(1e-6×200e9) = 200/200000 = 1×10⁻³ m = 1mm.' },
    { q: 'A wire of diameter 0.5mm stretches 0.8mm under a 50N load over 1.5m. Find the stress and strain.', a: 'A=π(0.00025)²≈1.96×10⁻⁷m². σ=F/A=50/1.96e-7≈2.55×10⁸ Pa. ε=e/L=0.0008/1.5≈5.33×10⁻⁴.' },
    { q: 'Using the previous answer, find the Young\'s modulus.', a: 'E=σ/ε=2.55×10⁸/5.33×10⁻⁴≈4.78×10¹¹ Pa ≈ 478 GPa.' },
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

function ForceExtensionGraph({ k, elasticLimitF, load }: { k: number; elasticLimitF: number; load: number }) {
  const fMax = elasticLimitF * 2.2;
  const data = useMemo(() => forceExtensionCurve(k, elasticLimitF, fMax), [k, elasticLimitF, fMax]);
  const e = extension(Math.min(load, elasticLimitF), k) * 100;
  const eLimitCm = (elasticLimitF / k) * 100;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="e" type="number" tick={{ fontSize: 10 }}>
          <Label value="Extension e (cm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis dataKey="F" tick={{ fontSize: 10 }}>
          <Label value="Force F (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'F']} labelFormatter={e => `e=${Number(e).toFixed(2)}cm`} />
        <Line type="linear" dataKey="F" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={eLimitCm} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'elastic limit', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={e} y={Math.min(load, elasticLimitF)} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function ElasticityPage() {
  const [mode, setMode] = useState<ElasticityMode>('hooke');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [load, setLoad] = useState(8);
  const [k, setK] = useState(200);
  const [elasticLimitF, setElasticLimitF] = useState(15);

  const [wireLength, setWireLength] = useState(2);
  const [wireDiamMm, setWireDiamMm] = useState(0.5);
  const [matIdx, setMatIdx] = useState(0);
  const [wireLoad, setWireLoad] = useState(60);
  const material = WIRE_MATERIALS[matIdx];

  const A = Math.PI * Math.pow((wireDiamMm / 1000) / 2, 2);
  const e = wireExtension(wireLoad, wireLength, A, material.E);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Elasticity</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ElasticityMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ElasticityCanvas mode={mode}
                  load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
                  wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
                  width={640} height={320} />
              </div>

              <div className="flex justify-end">
                <EmbedButton path="/embed/elasticity"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'hooke' ? { mode, load, k, limit: elasticLimitF } : { mode, mat: matIdx, L: wireLength, d: wireDiamMm, F: wireLoad }} />
              </div>

              {mode === 'hooke' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Force–extension graph</p>
                  <ForceExtensionGraph k={k} elasticLimitF={elasticLimitF} load={load} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Linear (Hooke) region, then plastic deformation beyond the elastic limit
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'hooke' && <>
                  <Slider label="Load F" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
                  <Slider label="Spring constant k" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
                  <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
                </>}
                {mode === 'wire' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {WIRE_MATERIALS.map((m, i) => (
                      <button key={m.name} onClick={() => setMatIdx(i)}
                        className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                          matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{m.name}</button>
                    ))}
                  </div>
                  <Slider label="Load F" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
                  <Slider label="Wire length L" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
                  <Slider label="Wire diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'hooke' && <>
                    <StatRow label="Extension e" value={(extension(Math.min(load, elasticLimitF), k) * 100).toFixed(2)} unit="cm" color="text-indigo-600" />
                    <StatRow label="Energy stored" value={springEnergy(k, extension(Math.min(load, elasticLimitF), k)).toFixed(3)} unit="J" color="text-emerald-600" />
                    <StatRow label="Within limit?" value={load <= elasticLimitF ? 'yes' : 'NO — plastic'} unit="" color="text-amber-600" />
                  </>}
                  {mode === 'wire' && <>
                    <StatRow label="Cross-section A" value={(A * 1e6).toFixed(4)} unit="mm²" color="text-indigo-600" />
                    <StatRow label="Stress σ" value={(stress(wireLoad, A) / 1e6).toFixed(1)} unit="MPa" color="text-emerald-600" />
                    <StatRow label="Strain ε" value={strain(e, wireLength).toExponential(2)} unit="" color="text-amber-600" />
                    <StatRow label="Extension e" value={(e * 1000).toFixed(3)} unit="mm" color="text-rose-500" />
                    <StatRow label="Young modulus" value={(youngModulus(wireLoad, A, e, wireLength) / 1e9).toFixed(0)} unit="GPa" color="text-purple-600" />
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
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
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
AFEOF

echo "  → src/app/embed/photoelectric/page.tsx"
cat > "src/app/embed/photoelectric/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { PhotoelectricCanvas } from '@/components/simulation/PhotoelectricCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { METALS } from '@/lib/physics/photoelectric';

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

function PhotoelectricEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const [metalIdx, setMetalIdx] = useState(() => Math.round(num(sp, 'metal', 0, 0, METALS.length - 1)));
  const [f14, setF14] = useState(() => num(sp, 'f', 6, 2, 14));
  const [intensity, setIntensity] = useState(() => num(sp, 'i', 5, 1, 10));
  const metal = METALS[metalIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [metalIdx, f14, intensity, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <PhotoelectricCanvas f14={f14} intensity={intensity} phiEV={metal.phi} metalName={metal.name}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="flex flex-wrap gap-1.5">
            {METALS.map((m, i) => (
              <button key={m.name} onClick={() => setMetalIdx(i)}
                className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                  metalIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                }`}>{m.name}</button>
            ))}
          </div>
          <Slider label="Frequency" unit="×10¹⁴ Hz" value={f14} min={2} max={14} step={0.1} set={setF14} color="#6366f1" />
          <Slider label="Intensity" unit="" value={intensity} min={1} max={10} step={1} set={setIntensity} color="#f59e0b" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function PhotoelectricEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <PhotoelectricEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/debroglie/page.tsx"
cat > "src/app/embed/debroglie/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DeBroglieCanvas } from '@/components/simulation/DeBroglieCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PARTICLES } from '@/lib/physics/debroglie';

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

function DeBroglieEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const [pIdx, setPIdx] = useState(() => Math.round(num(sp, 'p', 0, 0, PARTICLES.length - 1)));
  const particle = PARTICLES[pIdx];
  const [velocity, setVelocity] = useState(() => num(sp, 'v', particle.vDefault, particle.vMin, particle.vMax));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pIdx, velocity, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DeBroglieCanvas mass={particle.mass} velocity={velocity} particleName={particle.name}
        isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="flex flex-wrap gap-1.5">
            {PARTICLES.map((p, i) => (
              <button key={p.name} onClick={() => { setPIdx(i); setVelocity(p.vDefault); }}
                className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                  pIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                }`}>{p.emoji} {p.name}</button>
            ))}
          </div>
          <Slider label="Speed" unit="m/s" value={velocity} min={particle.vMin} max={particle.vMax}
            step={(particle.vMax - particle.vMin) / 200} set={setVelocity} color="#6366f1" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DeBroglieEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DeBroglieEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/xrays/page.tsx"
cat > "src/app/embed/xrays/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { XrayCanvas } from '@/components/simulation/XrayCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function XraysEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const [kV, setKV] = useState(() => num(sp, 'kV', 35, 5, 100));
  const [current, setCurrent] = useState(() => num(sp, 'i', 5, 1, 10));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [kV, current, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <XrayCanvas kV={kV} current={current} isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Tube voltage" unit="kV" value={kV} min={5} max={100} step={1} set={setKV} color="#6366f1" />
          <Slider label="Filament current" unit="" value={current} min={1} max={10} step={1} set={setCurrent} color="#f59e0b" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function XraysEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <XraysEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/friction/page.tsx"
cat > "src/app/embed/friction/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function FrictionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): FrictionMode => (sp.get('mode') === 'incline' ? 'incline' : 'flat'))();
  const showControls = sp.get('controls') !== '0';

  const [mass, setMass] = useState(() => num(sp, 'mass', 5, 1, 20));
  const [applied, setApplied] = useState(() => num(sp, 'applied', 15, 0, 80));
  const [angle, setAngle] = useState(() => num(sp, 'angle', 20, 0, 60));
  const [muS, setMuS] = useState(() => num(sp, 'muS', 0.4, 0.05, 1));
  const [muK, setMuK] = useState(() => num(sp, 'muK', 0.3, 0.05, 1));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mass, applied, angle, muS, muK, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
        muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
          {mode === 'flat'
            ? <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
            : <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />}
          <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
          <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function FrictionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <FrictionEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/heat/page.tsx"
cat > "src/app/embed/heat/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

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

function HeatEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): HeatMode => {
    const m = sp.get('mode');
    return m === 'convection' || m === 'radiation' ? m : 'conduction';
  })();
  const showControls = sp.get('controls') !== '0';
  const [hotTemp, setHotTemp] = useState(() => num(sp, 'hot', 90, 30, 120));
  const [coldTemp, setColdTemp] = useState(() => num(sp, 'cold', 20, 0, 40));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
          <Slider label="Cold temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function HeatEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <HeatEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/elasticity/page.tsx"
cat > "src/app/embed/elasticity/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { WIRE_MATERIALS } from '@/lib/physics/elasticity';

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

function ElasticityEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): ElasticityMode => (sp.get('mode') === 'wire' ? 'wire' : 'hooke'))();
  const showControls = sp.get('controls') !== '0';

  const [load, setLoad] = useState(() => num(sp, 'load', 8, 0, 30));
  const [k, setK] = useState(() => num(sp, 'k', 200, 50, 500));
  const [elasticLimitF, setElasticLimitF] = useState(() => num(sp, 'limit', 15, 5, 25));

  const [matIdx, setMatIdx] = useState(() => Math.round(num(sp, 'mat', 0, 0, WIRE_MATERIALS.length - 1)));
  const [wireLength, setWireLength] = useState(() => num(sp, 'L', 2, 0.5, 5));
  const [wireDiamMm, setWireDiamMm] = useState(() => num(sp, 'd', 0.5, 0.1, 2));
  const [wireLoad, setWireLoad] = useState(() => num(sp, 'F', 60, 5, 200));
  const material = WIRE_MATERIALS[matIdx];

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ElasticityCanvas mode={mode}
        load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
        wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
        width={640} height={320} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {mode === 'hooke' ? <>
            <Slider label="Load" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
            <Slider label="Spring constant" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
            <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
          </> : <>
            <div className="flex flex-wrap gap-1.5">
              {WIRE_MATERIALS.map((m, i) => (
                <button key={m.name} onClick={() => setMatIdx(i)}
                  className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                    matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m.name}</button>
              ))}
            </div>
            <Slider label="Load" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
            <Slider label="Length" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
            <Slider label="Diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElasticityEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElasticityEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v4 applied — 24 files written."
echo ""
echo "New pages:"
echo "  /simulations/photoelectric-effect  /simulations/de-broglie"
echo "  /simulations/x-rays                /simulations/friction"
echo "  /simulations/heat-transfer         /simulations/elasticity"
echo ""
echo "New embeds: /embed/photoelectric /embed/debroglie /embed/xrays"
echo "            /embed/friction /embed/heat /embed/elasticity"
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
