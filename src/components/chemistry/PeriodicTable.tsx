'use client';
import { useMemo, useState } from 'react';
import { ELEMENTS, CATEGORY_STYLE, CATEGORY_LABEL, type Element, type Category } from '@/lib/chemistry/elements';

interface Props {
  onPick: (el: Element) => void;
  /** Symbol shown with a ring (the element being inspected). */
  selected?: string | null;
  /** Atom counts to show as small badges (compound builder). */
  counts?: Record<string, number>;
  /** Hide element names in the wide table cells. */
  compact?: boolean;
  showLegend?: boolean;
  /** Max height of the phone list before it scrolls internally. */
  listMaxHeight?: string;
}

const CATS: Category[] = ['alkali', 'alkaline', 'transition', 'post-transition', 'metalloid', 'nonmetal', 'halogen', 'noble', 'lanthanide', 'actinide'];

/**
 * Two layouts of the same data:
 *  • ≥ md: the familiar 18-column table, sized to fit the container (no horizontal scrolling).
 *  • < md: a searchable, filterable grid of large tap targets, because 18 columns cannot be
 *    tapped reliably on a phone.
 */
export function PeriodicTable({ onPick, selected, counts, compact, showLegend = true, listMaxHeight = '60vh' }: Props) {
  const [query, setQuery] = useState('');
  const [cat, setCat] = useState<Category | 'all'>('all');

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return ELEMENTS.filter(e => {
      if (cat !== 'all' && e.category !== cat) return false;
      if (!q) return true;
      return e.symbol.toLowerCase() === q || e.name.toLowerCase().includes(q) || String(e.z) === q || e.symbol.toLowerCase().startsWith(q);
    });
  }, [query, cat]);

  const cell = (e: Element) => {
    const col = e.group ?? (e.z >= 57 && e.z <= 71 ? e.z - 57 + 3 : e.z - 89 + 3);
    const row = e.group ? e.period : e.period === 6 ? 9 : 10;
    const count = counts?.[e.symbol];
    return (
      <button
        key={e.z}
        type="button"
        onClick={() => onPick(e)}
        aria-label={`${e.name}, atomic number ${e.z}`}
        aria-pressed={selected === e.symbol}
        style={{ gridColumn: col, gridRow: row }}
        className={`relative aspect-square min-w-0 rounded-md border text-center leading-none transition ${CATEGORY_STYLE[e.category]} ${selected === e.symbol ? 'ring-2 ring-indigo-600 ring-offset-1' : ''} ${count ? 'outline outline-2 outline-indigo-500' : ''}`}
      >
        <span className="absolute left-0.5 top-0.5 text-[8px] opacity-60">{e.z}</span>
        {count ? <span className="absolute right-0.5 top-0.5 rounded-full bg-indigo-600 px-1 text-[8px] font-semibold text-white">{count}</span> : null}
        <span className="block pt-2.5 text-xs font-semibold lg:text-sm">{e.symbol}</span>
        {!compact && <span className="mt-0.5 hidden truncate px-0.5 text-[7px] opacity-70 xl:block">{e.name}</span>}
      </button>
    );
  };

  const tile = (e: Element) => {
    const count = counts?.[e.symbol];
    return (
      <button
        key={e.z}
        type="button"
        onClick={() => onPick(e)}
        aria-label={`${e.name}, atomic number ${e.z}`}
        aria-pressed={selected === e.symbol}
        className={`relative flex min-h-[68px] min-w-0 flex-col items-center justify-center rounded-xl border px-1 py-1.5 text-center leading-none transition active:scale-95 ${CATEGORY_STYLE[e.category]} ${selected === e.symbol ? 'ring-2 ring-indigo-600 ring-offset-1' : ''} ${count ? 'outline outline-2 outline-indigo-500' : ''}`}
      >
        <span className="absolute left-1.5 top-1 text-[9px] opacity-60">{e.z}</span>
        {count ? <span className="absolute right-1 top-1 rounded-full bg-indigo-600 px-1.5 py-0.5 text-[9px] font-semibold text-white">×{count}</span> : null}
        <span className="mt-1 text-lg font-semibold">{e.symbol}</span>
        <span className="mt-1 w-full truncate text-[9px] opacity-75">{e.name}</span>
      </button>
    );
  };

  return (
    <div className="min-w-0">
      {/* ── Phone / small tablet: search + category chips + tap grid ── */}
      <div className="md:hidden">
        <label className="sr-only" htmlFor="pt-search">Search elements</label>
        <input
          id="pt-search"
          type="search"
          inputMode="search"
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder="Search by name, symbol or number"
          className="h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-base text-gray-900 placeholder:text-gray-400"
        />
        <div className="scrollbar-hide -mx-1 mt-2 flex gap-1.5 overflow-x-auto px-1 pb-1" role="group" aria-label="Filter by category">
          {(['all', ...CATS] as const).map(c => (
            <button
              key={c}
              type="button"
              onClick={() => setCat(c)}
              aria-pressed={cat === c}
              className={`shrink-0 whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium ${cat === c ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600'}`}
            >
              {c === 'all' ? 'All' : CATEGORY_LABEL[c]}
            </button>
          ))}
        </div>
        <div className="mt-1 text-[11px] text-gray-400" aria-live="polite">{filtered.length} element{filtered.length === 1 ? '' : 's'}</div>
        <div className="mt-2 overflow-y-auto overscroll-contain rounded-xl" style={{ maxHeight: listMaxHeight }}>
          {filtered.length ? (
            <div className="grid grid-cols-4 gap-1.5 pb-1 min-[420px]:grid-cols-5 sm:grid-cols-6">{filtered.map(tile)}</div>
          ) : (
            <p className="rounded-xl bg-gray-50 px-3 py-6 text-center text-sm text-gray-500">No element matches “{query}”.</p>
          )}
        </div>
      </div>

      {/* ── md and up: the classic 18-column table, fitted to the width ── */}
      <div className="hidden md:block">
        <div className="grid w-full gap-[3px]" style={{ gridTemplateColumns: 'repeat(18, minmax(0, 1fr))' }}>
          {ELEMENTS.map(cell)}
          <div style={{ gridColumn: 3, gridRow: 6 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">57–71</div>
          <div style={{ gridColumn: 3, gridRow: 7 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">89–103</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 9 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Lanthanides</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 10 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Actinides</div>
          <div style={{ gridColumn: '1 / span 18', gridRow: 8, height: 6 }} aria-hidden="true" />
        </div>
        {showLegend && (
          <div className="mt-3 flex flex-wrap gap-x-3 gap-y-1">
            {CATS.map(c => (
              <span key={c} className="flex items-center gap-1 text-[10px] text-gray-500">
                <span className={`inline-block h-2.5 w-2.5 rounded-sm border ${CATEGORY_STYLE[c].split(' ').slice(0, 3).join(' ')}`} />
                {CATEGORY_LABEL[c]}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
