'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PeriodicTable } from '@/components/chemistry/PeriodicTable';
import { ElementDetails } from '@/components/chemistry/ElementDetails';
import { BY_SYMBOL, type Element } from '@/lib/chemistry/elements';

export default function PeriodicTablePage() {
  const [sel, setSel] = useState<Element>(BY_SYMBOL['Na']);
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Periodic table</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Select an element to see its configuration and oxidation states.</p>
          <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <div className="rounded-2xl border border-gray-200 bg-white p-4"><PeriodicTable onPick={setSel} selected={sel.symbol} /></div>
            <ElementDetails el={sel} />
          </div>
        </div>
      </main>
    </>
  );
}
