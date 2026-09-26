'use client';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

// This list grows as more PHY 403 simulations are added. Unlike the public
// /simulations hub, this page is only reachable after the /minitab middleware
// passcode check succeeds, so nothing here needs curriculum tags — it's a
// single-course reading list, not a multi-curriculum catalogue.
const SIMULATIONS = [
  {
    slug: 'gradient-explorer',
    href: '/minitab/gradient-explorer',
    title: 'Gradient & Directional Derivative Explorer',
    description: 'Drag a point through a scalar field and watch D_âφ=∇φ·â update live — the shortcut formula that replaces the slow limit-definition calculation.',
    icon: '🧭',
    chapter: 'Ch 1–2',
  },
  {
    slug: 'div-stokes',
    href: '/minitab/div-stokes',
    title: "Divergence & Stokes' Theorem Visualizer",
    description: 'Drag a disk through a vector field — boundary flux/circulation and interior area integrals, computed independently, always agree.',
    icon: '🔄',
    chapter: 'Ch 3–4',
  },
  {
    slug: 'eigenvector-explorer',
    href: '/minitab/eigenvector-explorer',
    title: 'Eigenvector Explorer',
    description: 'Watch a matrix transform the whole plane while its eigenvector directions stay perfectly fixed — Av=λv made visible.',
    icon: '📐',
    chapter: 'Ch 6',
  },
  {
    slug: 'gamma-function',
    href: '/minitab/gamma-function',
    title: 'Gamma Function Explorer',
    description: 'Γ(x+1)=xΓ(x) explains everything on this graph — matching n! at every integer, and blowing up at every non-positive integer.',
    icon: 'Γ',
    chapter: 'Ch 8',
  },
  {
    slug: 'legendre-bessel',
    href: '/minitab/legendre-bessel',
    title: 'Legendre & Bessel Explorer',
    description: 'Toggle Pₙ or Jₙ curves, check orthogonality integrals and the Bessel recurrence relation live, by direct numerical computation.',
    icon: '〰️',
    chapter: 'Ch 9–10',
  },
  {
    slug: 'hermite-laguerre-delta',
    href: '/minitab/hermite-laguerre-delta',
    title: 'Hermite, Laguerre & the Dirac Delta',
    description: 'The quantum harmonic oscillator and hydrogen atom\u2019s special functions, plus δ(x) built as the limit of a narrowing Gaussian pulse.',
    icon: '🌊',
    chapter: 'Ch 11',
  },
  {
    slug: 'fourier-series',
    href: '/minitab/fourier-series',
    title: 'Fourier Series Builder',
    description: 'Build a square wave, sawtooth, or triangle wave from harmonics one term at a time — including the Gibbs phenomenon.',
    icon: '📈',
    chapter: 'Ch 12',
  },
  {
    slug: 'fourier-transform',
    href: '/minitab/fourier-transform',
    title: 'Fourier Transform Pairs',
    description: 'Squeeze a function in position space and watch its transform spread out in frequency space — the same trade-off behind the uncertainty principle.',
    icon: '🔀',
    chapter: 'Ch 13',
  },
  {
    slug: 'damped-oscillator',
    href: '/minitab/damped-oscillator',
    title: 'Damped Oscillator (Laplace Transform)',
    description: "Drag γ past ω₀ and watch underdamped, critical, and overdamped regimes — every curve from Chapter 15's Laplace-transform solution, verified against RK4 numerical integration.",
    icon: '🌀',
    chapter: 'Ch 14–15',
  },
];

export default function MinitabHubPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6">
            <p className="text-xs text-gray-400 mb-1">PHY 403 · Mathematical Methods for Physics I</p>
            <h1 className="text-xl font-semibold text-gray-900">Student Simulation Library</h1>
            <p className="text-sm text-gray-500 mt-1">
              Interactive companions to the course notes — every simulation&apos;s physics is verified numerically before it&apos;s built.
            </p>
          </div>
        </section>

        <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {SIMULATIONS.map(sim => (
              <Link
                key={sim.slug}
                href={sim.href}
                className="group rounded-2xl border border-gray-200 bg-white p-5 transition hover:border-indigo-300 hover:shadow-sm"
              >
                <div className="flex items-start justify-between gap-3">
                  <span className="text-2xl">{sim.icon}</span>
                  <span className="text-[10px] font-medium text-indigo-600 bg-indigo-50 px-2 py-1 rounded-full">
                    {sim.chapter}
                  </span>
                </div>
                <h2 className="mt-3 text-sm font-semibold text-gray-900 group-hover:text-indigo-700">
                  {sim.title}
                </h2>
                <p className="mt-1.5 text-xs text-gray-500 leading-relaxed">{sim.description}</p>
              </Link>
            ))}
          </div>
        </div>
      </main>
    </>
  );
}
