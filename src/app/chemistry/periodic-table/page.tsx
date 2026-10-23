'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PeriodicTable } from '@/components/chemistry/PeriodicTable';
import { ElementDetails } from '@/components/chemistry/ElementDetails';
import { BY_SYMBOL, type Element } from '@/lib/chemistry/elements';

export default function PeriodicTablePage() {
  const [sel, setSel] = useState<Element>(BY_SYMBOL['Na']);
  const [sheet, setSheet] = useState(false);
  const pick = (e: Element) => { setSel(e); setSheet(true); };
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Periodic table</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Select an element to see its configuration and oxidation states.</p>
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <div className="min-w-0 rounded-2xl border border-gray-200 bg-white p-3 sm:p-4"><PeriodicTable onPick={pick} selected={sel.symbol} listMaxHeight="calc(100vh - 21rem)" /></div>
            {/* Large screens: details beside the table */}
            <div className="hidden min-w-0 lg:block"><ElementDetails el={sel} /></div>
          </div>
        </div>

        {/* Small screens: details slide up as a sheet so they are never off-screen */}
        {sheet && (
          <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true" aria-label={`${sel.name} details`}>
            <button type="button" className="absolute inset-0 bg-black/30" onClick={() => setSheet(false)} aria-label="Close details" />
            <div className="absolute inset-x-0 bottom-0 max-h-[78vh] overflow-y-auto rounded-t-3xl bg-white p-3 pb-6 shadow-2xl" style={{ paddingBottom: 'max(1.5rem, env(safe-area-inset-bottom))' }}>
              <div className="mx-auto mb-2 h-1 w-10 rounded-full bg-gray-300" />
              <ElementDetails el={sel} />
              <button type="button" onClick={() => setSheet(false)} className="mt-3 h-11 w-full rounded-xl border border-gray-200 text-sm font-medium text-gray-700">Close</button>
            </div>
          </div>
        )}
      </main>
    </>
  );
}
