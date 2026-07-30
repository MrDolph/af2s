#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v56: About page update -- new advanced
# simulations, an actionable "suggest a curriculum" CTA, and a portfolio
# link
#
#   Does NOT touch simulations/page.tsx (a different file entirely --
#   this patch only writes src/app/about/page.tsx).
#
#   1. ADVANCED & UNDERGRADUATE SIMULATIONS. Added a new showcase section
#      featuring Atomic Models, Quantum Tunnelling, Coupled Oscillators,
#      and Double Pendulum. IMPORTANT CAVEAT: these were added
#      independently and aren't present in the sandbox this session
#      worked from, so their exact routes couldn't be verified directly.
#      "Atomic Models" uses the exact URL given
#      (/simulations/atomic-models). The other three use best-guess
#      slugs matching this app's established kebab-case convention
#      (/simulations/quantum-tunneling, /simulations/coupled-oscillators,
#      /simulations/double-pendulum) -- please check these three links
#      actually resolve, and let me know the correct slugs if any differ
#      so they can be fixed precisely rather than guessed at again.
#
#   2. "SUGGEST A CURRICULUM" MADE ACTIONABLE. The dashed placeholder box
#      was static text with no way to act on it. It's now a real link
#      (opens the portfolio site in a new tab) with a clear call to
#      action, so a visitor who wants to suggest a curriculum has
#      somewhere to actually go.
#
#   3. PORTFOLIO LINK (https://mrdof-portfolio.vercel.app/) added in
#      three places: the curriculum-suggestion card, a "View portfolio"
#      link under the founder’s bio in the Team section, and the site
#      footer alongside the other navigation links.
#
#   4. Updated the simulation count stat and the product roadmap to
#      reflect the platform’s actual current state -- electrostatics,
#      magnetic effects, electromagnetic induction, AC circuits, and
#      thermal physics are now marked live rather than still "building",
#      and the new advanced-physics topics are called out as their own
#      roadmap phase.
#
#   Also fixed one pre-existing, unrelated lint issue caught while
#   editing this file: an unescaped apostrophe in the hero heading
#   ("shouldn't" -> "shouldn&apos;t"), flagged by the
#   react/no-unescaped-entities rule.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v56-about-page-update.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v56: About page update --"
mkdir -p "src/app/about"

echo "  -> src/app/about/page.tsx"
cat > "src/app/about/page.tsx" << 'AFEOF'
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const STATS = [
  { value: '25+', label: 'Physics simulations' },
  { value: '5', label: 'Exam curricula' },
  { value: '4', label: 'African languages' },
  { value: '100%', label: 'Free to start' },
];

const PORTFOLIO_URL = 'https://mrdof-portfolio.vercel.app/';

const CURRICULA = [
  { name: 'WAEC', desc: 'West African Senior School Certificate', color: 'bg-indigo-50 text-indigo-700 border-indigo-100' },
  { name: 'NECO', desc: 'National Examinations Council (Nigeria)', color: 'bg-pink-50 text-pink-700 border-pink-100' },
  { name: 'IGCSE', desc: 'Cambridge International General Certificate', color: 'bg-emerald-50 text-emerald-700 border-emerald-100' },
  { name: 'JUPEB', desc: 'Joint Universities Preliminary Examinations Board', color: 'bg-purple-50 text-purple-700 border-purple-100' },
  { name: 'SAT', desc: 'Scholastic Assessment Test (US)', color: 'bg-orange-50 text-orange-700 border-orange-100' },
];

const TEAM = [
  {
    name: 'Fatai',
    role: 'Founder & CEO',
    bio: 'Building A-Factor to give every African student access to world-class physics education — regardless of where they live or what they can afford.',
  },
];

const ADVANCED_SIMS = [
  { name: 'Atomic Models', href: '/simulations/atomic-models', desc: 'From Thomson to Bohr to the quantum model — how our picture of the atom evolved.' },
  { name: 'Quantum Tunnelling', href: '/simulations/quantum-tunneling', desc: 'Watch a particle pass through a barrier it classically shouldn\u2019t be able to cross.' },
  { name: 'Coupled Oscillators', href: '/simulations/coupled-oscillators', desc: 'Normal modes and energy exchange between two linked oscillating systems.' },
  { name: 'Double Pendulum', href: '/simulations/double-pendulum', desc: 'A deterministic system with genuinely chaotic, unpredictable motion.' },
];

const ROADMAP = [
  { phase: 'Phase 1', status: 'live', title: 'Mechanics & thermal physics', items: ['Projectile motion (all launch modes)', 'Gas laws (Boyle & Charles)', 'Thermal conductivity, convection & radiation', 'Multilingual support (EN, YO, HA, IG)'] },
  { phase: 'Phase 2', status: 'live', title: 'Electricity & electromagnetism', items: ["Ohm's law, series & parallel circuits", 'Electrostatics (charging, fields, potential)', 'Magnetic effects of current', 'Electromagnetic induction & AC circuits'] },
  { phase: 'Phase 3', status: 'building', title: 'Modern & advanced physics', items: ['Atomic models', 'Quantum tunnelling', 'Coupled oscillators & double pendulum', 'Photoelectric effect & radioactive decay'] },
  { phase: 'Phase 4', status: 'planned', title: 'Platform & marketplace', items: ['AI-generated exercises', 'Teacher dashboard', 'School LMS integration', 'Student analytics & enterprise plans'] },
];

const STATUS_STYLES: Record<string, string> = {
  live:     'bg-emerald-100 text-emerald-700',
  building: 'bg-amber-100 text-amber-700',
  planned:  'bg-gray-100 text-gray-500',
};

const STATUS_DOT: Record<string, string> = {
  live:     'bg-emerald-500',
  building: 'bg-amber-400',
  planned:  'bg-gray-300',
};

export default function AboutPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-4xl px-4 sm:px-6 py-12 sm:py-16 text-center">
            <div className="inline-flex items-center gap-2 rounded-full border border-indigo-100 bg-indigo-50 px-4 py-1.5 mb-6">
              <span className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-pulse"/>
              <span className="text-xs font-medium text-indigo-600">Early access — actively building</span>
            </div>
            <h1 className="text-2xl sm:text-4xl font-semibold text-gray-900 leading-tight mb-4">
              Physics education shouldn&apos;t depend<br className="hidden sm:block" /> on where you were born
            </h1>
            <p className="text-sm sm:text-base text-gray-500 leading-relaxed max-w-2xl mx-auto mb-8">
              A-Factor STEM Studio is an AI-powered physics simulation platform built for
              secondary school students across Africa and beyond. Type a prompt, get an
              instant interactive simulation. No programming skills required.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <Link href="/simulations"
                className="rounded-xl bg-indigo-600 px-6 py-3 text-sm font-medium text-white hover:bg-indigo-700 transition">
                Try a simulation
              </Link>
              <Link href="/simulations"
                className="rounded-xl border border-gray-200 bg-white px-6 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50 transition">
                Browse all topics
              </Link>
            </div>
          </div>
        </section>

        {/* Stats */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-4xl px-4 sm:px-6 py-8">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-6">
              {STATS.map(s => (
                <div key={s.label} className="text-center">
                  <p className="text-2xl sm:text-3xl font-semibold text-indigo-600 mb-1">{s.value}</p>
                  <p className="text-xs text-gray-500">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-4xl px-4 sm:px-6 py-10 space-y-10">

          {/* The problem */}
          <section>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">The problem</p>
            <div className="grid sm:grid-cols-2 gap-4">
              {[
                { icon: '📚', title: 'Static textbooks', desc: 'Most students learn physics from diagrams that never move. Abstract concepts like projectile motion or gas pressure stay abstract.' },
                { icon: '💰', title: 'Expensive labs', desc: 'Physical lab equipment is out of reach for most schools in Africa. Students sit exams on experiments they have never performed.' },
                { icon: '🌍', title: 'Localisation gap', desc: 'Global tools like PhET and GeoGebra are not built for WAEC, NECO, or JUPEB curricula, and offer no support in Yoruba, Hausa, or Igbo.' },
                { icon: '🤖', title: 'No AI layer', desc: 'No existing simulation platform lets a student describe what they want to see in plain language and instantly get an interactive result.' },
              ].map(p => (
                <div key={p.title} className="rounded-2xl border border-gray-200 bg-white p-5">
                  <span className="text-xl mb-3 block">{p.icon}</span>
                  <h3 className="text-sm font-semibold text-gray-900 mb-1.5">{p.title}</h3>
                  <p className="text-xs text-gray-500 leading-relaxed">{p.desc}</p>
                </div>
              ))}
            </div>
          </section>

          {/* The solution */}
          <section>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">What A-Factor does</p>
            <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-6 sm:p-8">
              <div className="grid sm:grid-cols-3 gap-6">
                {[
                  { step: '01', title: 'Describe it', desc: 'Type what you want to simulate in English, Yoruba, Hausa, or Igbo.' },
                  { step: '02', title: 'AI generates it', desc: 'Claude parses your prompt, extracts physics parameters, and builds the simulation instantly.' },
                  { step: '03', title: 'Learn from it', desc: 'Adjust parameters with sliders, read teacher notes, solve exercises, and share the link with classmates.' },
                ].map(s => (
                  <div key={s.step}>
                    <span className="text-2xl font-bold text-indigo-200 block mb-2">{s.step}</span>
                    <h3 className="text-sm font-semibold text-indigo-900 mb-1">{s.title}</h3>
                    <p className="text-xs text-indigo-700 leading-relaxed">{s.desc}</p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* Curricula */}
          <section>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Exam curricula supported</p>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {CURRICULA.map(c => (
                <div key={c.name} className={`rounded-xl border p-4 ${c.color}`}>
                  <p className="text-sm font-semibold mb-0.5">{c.name}</p>
                  <p className="text-xs opacity-70">{c.desc}</p>
                </div>
              ))}
              <a href={PORTFOLIO_URL} target="_blank" rel="noopener noreferrer"
                className="rounded-xl border border-dashed border-indigo-200 bg-indigo-50/40 p-4 flex flex-col items-center justify-center text-center hover:bg-indigo-50 hover:border-indigo-300 transition group">
                <p className="text-xs text-indigo-600 font-medium group-hover:text-indigo-700">More curricula being added — suggest yours</p>
                <p className="text-[10px] text-indigo-400 mt-1">Reach out via the founder&apos;s portfolio →</p>
              </a>
            </div>
          </section>

          {/* Advanced & undergraduate simulations */}
          <section>
            <div className="flex items-center gap-2 mb-3">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Advanced &amp; undergraduate topics</p>
              <span className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700">New</span>
            </div>
            <div className="grid sm:grid-cols-2 gap-3">
              {ADVANCED_SIMS.map(s => (
                <Link key={s.name} href={s.href}
                  className="rounded-xl border border-gray-200 bg-white p-4 hover:border-indigo-200 hover:bg-indigo-50/30 transition">
                  <p className="text-sm font-semibold text-gray-900 mb-0.5">{s.name}</p>
                  <p className="text-xs text-gray-500 leading-relaxed">{s.desc}</p>
                </Link>
              ))}
            </div>
            <p className="text-[10px] text-gray-400 mt-2">
              Newly added for JUPEB and undergraduate-level classes — beyond the core WAEC/NECO/IGCSE curriculum.
            </p>
          </section>

          {/* Roadmap */}
          <section>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-4">Product roadmap</p>
            <div className="space-y-3">
              {ROADMAP.map((phase, i) => (
                <div key={i} className="rounded-2xl border border-gray-200 bg-white p-5">
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full flex items-center gap-1.5 ${STATUS_STYLES[phase.status]}`}>
                          <span className={`h-1.5 w-1.5 rounded-full ${STATUS_DOT[phase.status]} ${phase.status === 'live' ? 'animate-pulse' : ''}`}/>
                          {phase.status === 'live' ? 'Live now' : phase.status === 'building' ? 'In progress' : 'Planned'}
                        </span>
                        <span className="text-xs text-gray-400">{phase.phase}</span>
                      </div>
                      <h3 className="text-sm font-semibold text-gray-900">{phase.title}</h3>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {phase.items.map(item => (
                      <span key={item} className="rounded-full bg-gray-50 border border-gray-100 px-3 py-1 text-xs text-gray-600">
                        {item}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </section>

          {/* Team */}
          <section>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">The team</p>
            {TEAM.map(t => (
              <div key={t.name} className="rounded-2xl border border-gray-200 bg-white p-5 flex gap-4 items-start">
                <div className="h-10 w-10 rounded-xl bg-indigo-100 flex items-center justify-center shrink-0">
                  <span className="text-sm font-semibold text-indigo-600">{t.name[0]}</span>
                </div>
                <div>
                  <p className="text-sm font-semibold text-gray-900">{t.name}</p>
                  <p className="text-xs text-indigo-600 mb-2">{t.role}</p>
                  <p className="text-xs text-gray-500 leading-relaxed mb-2">{t.bio}</p>
                  <a href={PORTFOLIO_URL} target="_blank" rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-xs font-medium text-indigo-600 hover:text-indigo-700">
                    View portfolio ↗
                  </a>
                </div>
              </div>
            ))}
          </section>

          {/* CTA */}
          <section className="rounded-2xl border border-indigo-100 bg-gradient-to-br from-indigo-50 to-white p-6 sm:p-8 text-center">
            <h2 className="text-base sm:text-xl font-semibold text-gray-900 mb-2">
              Ready to see physics come alive?
            </h2>
            <p className="text-xs sm:text-sm text-gray-500 mb-6 max-w-md mx-auto">
              Try a simulation now — no signup required. Just type what you want to see.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <Link href="/"
                className="rounded-xl bg-indigo-600 px-6 py-3 text-sm font-medium text-white hover:bg-indigo-700 transition">
                Start simulating
              </Link>
              <Link href="/simulations"
                className="rounded-xl border border-gray-200 bg-white px-6 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50 transition">
                Browse simulations
              </Link>
            </div>
          </section>

        </div>

        {/* Footer */}
        <footer className="border-t border-gray-200 bg-white mt-10">
          <div className="mx-auto max-w-4xl px-4 sm:px-6 py-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-gray-400">
            <div className="flex items-center gap-2">
              <div className="h-5 w-5 rounded bg-indigo-600 flex items-center justify-center">
                <svg width="10" height="10" viewBox="0 0 14 14" fill="white"><path d="M7 1L13 4.5V9.5L7 13L1 9.5V4.5L7 1Z"/></svg>
              </div>
              <span className="font-medium text-gray-600">A-Factor STEM Studio</span>
              <span>© {new Date().getFullYear()} A-Factor EdTech Solutions</span>
            </div>
            <div className="flex gap-4">
              <Link href="/" className="hover:text-indigo-600 transition">Home</Link>
              <Link href="/simulations" className="hover:text-indigo-600 transition">Simulations</Link>
              <Link href="/about" className="hover:text-indigo-600 transition">About</Link>
              <a href={PORTFOLIO_URL} target="_blank" rel="noopener noreferrer" className="hover:text-indigo-600 transition">Portfolio ↗</a>
            </div>
          </div>
        </footer>

      </main>
    </>
  );
}
AFEOF

echo ""
echo "Patch v56 applied -- 1 file written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /about -- the new 'Advanced & undergraduate topics' section,"
echo "and specifically click through Quantum Tunnelling, Coupled"
echo "Oscillators, and Double Pendulum to confirm those three guessed"
echo "slugs actually match your real routes (Atomic Models was given"
echo "explicitly and should already be correct)."
