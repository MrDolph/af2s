'use client';
import Link from 'next/link';
import { CATEGORY_LABEL, type Element } from '@/lib/chemistry/elements';
import { fmtCharge } from '@/lib/chemistry/perovskite';

const fmtOs = (n: number) => (n === 0 ? '0' : n === -0.5 ? '−½' : `${n > 0 ? '+' : '−'}${Math.abs(n)}`);

export function ElementDetails({ el, onAdd, addLabel = 'Add to compound builder' }: { el: Element; onAdd?: (el: Element) => void; addLabel?: string }) {
  const row = (k: string, v: React.ReactNode) => (
    <div className="flex justify-between gap-3 border-b border-gray-100 py-1.5 text-xs last:border-0">
      <dt className="text-gray-500">{k}</dt>
      <dd className="text-right font-medium text-gray-900">{v}</dd>
    </div>
  );
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <div className="flex items-baseline gap-3">
        <span className="text-4xl font-semibold text-gray-900">{el.symbol}</span>
        <div>
          <div className="text-sm font-semibold text-gray-900">{el.name}</div>
          <div className="text-[11px] text-gray-500">{CATEGORY_LABEL[el.category]}</div>
        </div>
        <span className="ml-auto text-xs text-gray-400">Z = {el.z}</span>
      </div>
      <dl className="mt-3">
        {row('Atomic mass', `${el.mass} u`)}
        {row('Electron configuration', <span className="font-mono">{el.config}</span>)}
        {row('Group / period', `${el.group ?? 'f-block'} / ${el.period}`)}
        {row('Electronegativity (Pauling)', el.en ?? '—')}
        {row('Common oxidation states', el.common.length ? el.common.map(fmtOs).join(', ') : '—')}
        {row('Less common', el.other.length ? el.other.map(fmtOs).join(', ') : '—')}
      </dl>
      {el.predicted && (
        <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] text-amber-800">
          Z &gt; 103: configuration is a prediction, and no chemistry is established.
        </p>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        {onAdd ? (
          <button type="button" onClick={() => onAdd(el)} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{addLabel}</button>
        ) : (
          <Link href={`/chemistry/compound-builder?add=${el.symbol}`} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{addLabel}</Link>
        )}
      </div>
      <p className="mt-3 text-[10px] leading-relaxed text-gray-400">
        Oxidation states are a teaching table (formal charges), not a prediction for any particular compound. Charge notation example: Mg{fmtCharge(2)}.
      </p>
    </div>
  );
}
