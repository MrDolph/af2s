'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

interface Playground {
  slug: string; href: string; title: string; description: string; icon: string; topic: string; status: 'live' | 'coming';
}

// Add new chemistry playgrounds here. The topic filter is built from this list.
const PLAYGROUNDS: Playground[] = [
  { slug: 'periodic-table', href: '/chemistry/periodic-table', title: 'Periodic table', icon: '🧪', topic: 'Foundations', status: 'live',
    description: 'All 118 elements: electron configuration, oxidation states, electronegativity and mass. Click to explore, then send an element to the compound builder.' },
  { slug: 'compound-builder', href: '/chemistry/compound-builder', title: 'Compound builder', icon: '⚗️', topic: 'Foundations', status: 'live',
    description: 'Click elements to add them, set atom counts, and read off the formula, molar mass, mass percentages and a rule-based charge-balance check.' },
  { slug: 'perovskite-lab', href: '/chemistry/perovskite-lab', title: 'Perovskite lab', icon: '💎', topic: 'Materials', status: 'live',
    description: 'Assign A, B and X sites (ABX₃ or double A₂BB′X₆), get the Goldschmidt tolerance and octahedral factors, rotate the model, and export a CIF.' },
  { slug: 'heusler', href: '/chemistry/heusler', title: 'Heusler alloys', icon: '🔩', topic: 'Materials', status: 'live',
    description: 'Half-Heusler XYZ and full-Heusler X₂YZ (regular and inverse) with alternative site arrangements, valence-electron rules and a Slater–Pauling estimate.' },
  { slug: 'crystal-builder', href: '/chemistry/crystal-builder', title: 'Crystal builder', icon: '🔷', topic: 'Materials', status: 'live',
    description: 'Pick a cubic prototype (rocksalt, CsCl, zincblende, fluorite, fcc, bcc, diamond…), assign elements and read computed coordination, density and packing.' },
  { slug: 'organic', href: '#', title: 'Organic molecules', icon: '🧬', topic: 'Organic', status: 'coming',
    description: 'Connect atoms with bonds, explore functional groups, and compare isomers that share a formula.' },
  { slug: 'nuclear', href: '/chemistry/nuclear', title: 'Nuclear playground', icon: '☢️', topic: 'Nuclear', status: 'live',
    description: 'Choose a nuclide, test decay modes against conservation laws, follow decay chains, run the half-life law and check nuclear equations.' },
];
const TOPICS = ['All', ...Array.from(new Set(PLAYGROUNDS.map(p => p.topic)))];

export default function ChemistryHub() {
  const [topic, setTopic] = useState('All');
  const visible = topic === 'All' ? PLAYGROUNDS : PLAYGROUNDS.filter(p => p.topic === topic);
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6 sm:py-14">
            <div className="max-w-2xl">
              <span className="mb-3 inline-block rounded-full bg-emerald-50 px-3 py-0.5 text-xs font-medium text-emerald-700">New · Chemistry &amp; Materials</span>
              <h1 className="mb-3 text-2xl font-semibold leading-tight text-gray-900 sm:text-3xl">Chemistry &amp; Materials Playground</h1>
              <p className="text-sm leading-relaxed text-gray-500 sm:text-base">
                Build compositions and crystal models, then see what the rules say about them. Everything you build is a
                <span className="font-medium text-gray-700"> candidate</span> — the playground never claims a compound exists just because you can assemble its formula.
              </p>
              <Link href="/simulations" className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-3 py-1 text-xs font-medium text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700">
                Looking for physics? Physics simulations →
              </Link>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
          <div className="scrollbar-hide mb-6 flex gap-2 overflow-x-auto pb-2">
            {TOPICS.map(t => {
              const n = t === 'All' ? PLAYGROUNDS.length : PLAYGROUNDS.filter(p => p.topic === t).length;
              const active = topic === t;
              return (
                <button key={t} onClick={() => setTopic(t)}
                  className={`flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border px-4 py-1.5 text-xs font-medium transition ${active ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'}`}>
                  {t}<span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>{n}</span>
                </button>
              );
            })}
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {visible.map(p => (
              <div key={p.slug} className={`group relative overflow-hidden rounded-2xl border bg-white transition ${p.status === 'live' ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md' : 'border-gray-100 opacity-70'}`}>
                {p.status === 'live' ? (
                  <div className="absolute right-3 top-3 flex items-center gap-1"><span className="h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-500" /><span className="text-[10px] font-medium text-emerald-600">Live</span></div>
                ) : (
                  <span className="absolute right-3 top-3 rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-400">Coming soon</span>
                )}
                <Link href={p.status === 'live' ? p.href : '#'} className={p.status !== 'live' ? 'pointer-events-none' : ''} aria-disabled={p.status !== 'live'}>
                  <div className="p-5">
                    <div className="mb-3 flex items-center gap-2"><span className="text-2xl">{p.icon}</span><span className="text-[10px] font-medium uppercase tracking-wide text-gray-400">{p.topic}</span></div>
                    <h2 className="mb-1.5 text-sm font-semibold text-gray-900 transition group-hover:text-indigo-700">{p.title}</h2>
                    <p className="text-xs leading-relaxed text-gray-500">{p.description}</p>
                  </div>
                </Link>
              </div>
            ))}
          </div>

          <div className="mt-8 rounded-2xl border border-gray-200 bg-white p-5">
            <h2 className="text-sm font-semibold text-gray-900">Four levels of evidence</h2>
            <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2 lg:grid-cols-4">
              {[
                ['User-built candidate', 'A composition or structure you proposed.'],
                ['Rule-based assessment', 'Checks such as charge balance or geometric factors.'],
                ['Database-supported material', 'A reported compound or structure, with its source.'],
                ['Calculated result', 'A property from a stated computational method.'],
              ].map(([k, v]) => (
                <div key={k}><dt className="font-medium text-gray-900">{k}</dt><dd className="mt-0.5 text-gray-500">{v}</dd></div>
              ))}
            </dl>
            <p className="mt-3 text-[11px] text-gray-400">This first release produces the first two. Database look-ups and calculations are not built in yet, and results are labelled accordingly.</p>
          </div>
        </section>
      </main>
    </>
  );
}
