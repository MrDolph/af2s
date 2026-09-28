'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

interface MathSimulation {
  slug: string;
  href: string;
  title: string;
  description: string;
  icon: string;
  tags: string[];
  topic: string;
  status: 'live' | 'coming';
}

// Add new mathematics simulations here. The topic filter below is built from
// whatever topics appear in this list, so a new topic gets its own chip
// automatically — nothing else needs editing.
const MATH_SIMULATIONS: MathSimulation[] = [
  {
    slug: 'unit-circle',
    href: '/mathematics/unit-circle',
    title: 'Unit circle explorer',
    description: 'Drag a point around the unit circle and see sin, cos, degrees, and radians update together — with live graphs and quadrant signs.',
    icon: '⭕',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Trigonometry',
    status: 'live',
  },
];

const TOPICS = ['All', ...Array.from(new Set(MATH_SIMULATIONS.map(s => s.topic)))];

export default function MathematicsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visible = selectedTopic === 'All'
    ? MATH_SIMULATIONS
    : MATH_SIMULATIONS.filter(s => s.topic === selectedTopic);

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
                Mathematics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive tools for the maths behind physics — see how an idea works by moving it,
                not just reading about it.
              </p>
              <Link href="/simulations"
                className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-3 py-1 text-xs font-medium text-gray-600 hover:border-indigo-300 hover:text-indigo-700 transition">
                Looking for physics? Physics simulations →
              </Link>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — only worth showing once there is more than one topic */}
          {TOPICS.length > 2 && (
            <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
              {TOPICS.map(t => {
                const count = t === 'All' ? MATH_SIMULATIONS.length : MATH_SIMULATIONS.filter(s => s.topic === t).length;
                const active = selectedTopic === t;
                return (
                  <button key={t} onClick={() => setSelectedTopic(t)}
                    className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                      }`}>
                    {t}
                    <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>{count}</span>
                  </button>
                );
              })}
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visible.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${sim.status === 'live'
                ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md'
                : 'border-gray-100 opacity-70'
                }`}>
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}
                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>
                    <h2 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">{sim.title}</h2>
                    <p className="text-xs text-gray-500 leading-relaxed mb-3">{sim.description}</p>
                    <div className="flex flex-wrap gap-1.5">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag] ?? 'bg-gray-100 text-gray-600'}`}>{tag}</span>
                      ))}
                    </div>
                  </div>
                </Link>
              </div>
            ))}
          </div>

          <p className="mt-10 text-center text-xs text-gray-400">
            More mathematics simulations will be added here.
          </p>
        </section>
      </main>
    </>
  );
}
