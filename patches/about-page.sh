#!/bin/bash
# A-Factor STEM Studio — About page
# Run inside af2s/ folder: bash about-page.sh
set -e
echo "Building About page..."

mkdir -p src/app/about

cat > src/app/about/page.tsx << 'EOF'
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const STATS = [
  { value: '16+', label: 'Physics simulations' },
  { value: '5', label: 'Exam curricula' },
  { value: '4', label: 'African languages' },
  { value: '100%', label: 'Free to start' },
];

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

const ROADMAP = [
  { phase: 'Phase 1', status: 'live', title: 'Mechanics & thermal physics', items: ['Projectile motion', 'Gas laws (Boyle & Charles)', 'AI prompt-to-simulation engine', 'Multilingual support (EN, YO, HA, IG)'] },
  { phase: 'Phase 2', status: 'building', title: 'Electricity & waves', items: ["Newton's 2nd law", 'Ohm\'s law & circuits', 'Wave motion & optics', 'Simple harmonic motion'] },
  { phase: 'Phase 3', status: 'planned', title: 'Modern physics & assessment', items: ['Radioactive decay', 'Photoelectric effect', 'AI-generated exercises', 'Teacher dashboard'] },
  { phase: 'Phase 4', status: 'planned', title: 'Platform & marketplace', items: ['Simulation marketplace', 'School LMS integration', 'Student analytics', 'Enterprise plans'] },
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
              Physics education shouldn't depend<br className="hidden sm:block" /> on where you were born
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
              <div className="rounded-xl border border-dashed border-gray-200 p-4 flex items-center justify-center">
                <p className="text-xs text-gray-400 text-center">More curricula being added — suggest yours</p>
              </div>
            </div>
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
                  <p className="text-xs text-gray-500 leading-relaxed">{t.bio}</p>
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
            </div>
          </div>
        </footer>

      </main>
    </>
  );
}
EOF

echo ""
echo "✅ About page built!"
echo "   Visit: http://localhost:3000/about"
