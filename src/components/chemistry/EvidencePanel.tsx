'use client';
// Makes the four evidence levels explicit so a built candidate is never mistaken for a known material.

interface Props {
  rule: { label: string; ok: boolean | null };
  extra?: string;
}

export function EvidencePanel({ rule, extra }: Props) {
  const tier = (title: string, state: 'yes' | 'warn' | 'no', body: string) => (
    <li className="flex gap-2.5 py-2 text-xs">
      <span className={`mt-0.5 h-2 w-2 shrink-0 rounded-full ${state === 'yes' ? 'bg-emerald-500' : state === 'warn' ? 'bg-amber-500' : 'bg-gray-300'}`} />
      <span><span className="font-medium text-gray-900">{title}.</span> <span className="text-gray-600">{body}</span></span>
    </li>
  );
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <h3 className="text-sm font-semibold text-gray-900">What this result is — and isn’t</h3>
      <ul className="mt-1 divide-y divide-gray-100">
        {tier('User-built candidate', 'yes', 'You chose this composition' + (extra ? ` / ${extra}` : '') + '. Choosing elements does not mean the compound exists.')}
        {tier('Rule-based assessment', rule.ok === null ? 'no' : rule.ok ? 'yes' : 'warn', rule.label)}
        {tier('Database-supported material', 'no', 'Not checked. Look the formula up yourself (e.g. Materials Project, ICSD, OQMD) before calling it a known phase.')}
        {tier('Calculated result', 'no', 'None. No DFT or other calculation is run here; tolerance factors are geometric heuristics.')}
      </ul>
    </div>
  );
}
