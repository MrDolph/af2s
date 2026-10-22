'use client';
import { ELEMENTS, CATEGORY_STYLE, CATEGORY_LABEL, type Element, type Category } from '@/lib/chemistry/elements';

interface Props {
  onPick: (el: Element) => void;
  /** Symbol shown with a ring (the element being inspected). */
  selected?: string | null;
  /** Atom counts to show as small badges (compound builder). */
  counts?: Record<string, number>;
  /** Hide element names in cells (use inside narrow panels). */
  compact?: boolean;
  showLegend?: boolean;
}

const LEGEND: Category[] = ['alkali', 'alkaline', 'transition', 'post-transition', 'metalloid', 'nonmetal', 'halogen', 'noble', 'lanthanide', 'actinide'];

export function PeriodicTable({ onPick, selected, counts, compact, showLegend = true }: Props) {
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
        <span className="block pt-2 text-[13px] font-semibold sm:text-sm">{e.symbol}</span>
        {!compact && <span className="mt-0.5 hidden truncate px-0.5 text-[7px] opacity-70 lg:block">{e.name}</span>}
      </button>
    );
  };

  return (
    <div>
      <div className="overflow-x-auto pb-2">
        <div className="grid min-w-[640px] gap-[3px]" style={{ gridTemplateColumns: 'repeat(18, minmax(0, 1fr))' }}>
          {ELEMENTS.map(cell)}
          <div style={{ gridColumn: 3, gridRow: 6 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">57–71</div>
          <div style={{ gridColumn: 3, gridRow: 7 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">89–103</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 9 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Lanthanides</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 10 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Actinides</div>
          <div style={{ gridColumn: '1 / span 18', gridRow: 8, height: 6 }} aria-hidden="true" />
        </div>
      </div>
      {showLegend && (
        <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1">
          {LEGEND.map(c => (
            <span key={c} className="flex items-center gap-1 text-[10px] text-gray-500">
              <span className={`inline-block h-2.5 w-2.5 rounded-sm border ${CATEGORY_STYLE[c].split(' ').slice(0, 3).join(' ')}`} />
              {CATEGORY_LABEL[c]}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
