'use client';
import { useCandidates, deleteCandidate, download, candidatesToCsv, type Candidate } from '@/lib/chemistry/candidates';

interface Props {
  onLoad?: (c: Candidate) => void;
}

export function CandidatesPanel({ onLoad }: Props) {
  const list = useCandidates();
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="text-sm font-semibold text-gray-900">Saved candidates <span className="font-normal text-gray-400">({list.length})</span></h3>
        {list.length > 0 && (
          <div className="ml-auto flex gap-2">
            <button type="button" onClick={() => download('af2s-candidates.csv', candidatesToCsv(list), 'text/csv')} className="rounded-md border border-gray-200 px-2 py-1 text-[11px] text-gray-600 hover:border-indigo-300 hover:text-indigo-700">CSV</button>
            <button type="button" onClick={() => download('af2s-candidates.json', JSON.stringify(list, null, 2), 'application/json')} className="rounded-md border border-gray-200 px-2 py-1 text-[11px] text-gray-600 hover:border-indigo-300 hover:text-indigo-700">JSON</button>
          </div>
        )}
      </div>
      {list.length === 0 ? (
        <p className="mt-2 text-xs text-gray-500">Nothing saved yet. Candidates are stored only in this browser.</p>
      ) : (
        <div className="mt-3 overflow-x-auto">
          <table className="w-full min-w-[420px] text-left text-xs">
            <thead className="text-[10px] uppercase tracking-wide text-gray-400">
              <tr><th className="py-1 pr-2">Name</th><th className="pr-2">Formula</th><th className="pr-2">M (g/mol)</th><th className="pr-2">t</th><th className="pr-2">μ</th><th /></tr>
            </thead>
            <tbody>
              {list.map(c => (
                <tr key={c.id} className="border-t border-gray-100">
                  <td className="py-1.5 pr-2 font-medium text-gray-900">{c.name}</td>
                  <td className="pr-2 text-gray-700">{c.formula}</td>
                  <td className="pr-2 text-gray-700">{c.molarMass.toFixed(2)}</td>
                  <td className="pr-2 text-gray-700">{c.perovskite?.tolerance?.toFixed(3) ?? '—'}</td>
                  <td className="pr-2 text-gray-700">{c.perovskite?.octahedral?.toFixed(3) ?? '—'}</td>
                  <td className="whitespace-nowrap text-right">
                    {onLoad && <button type="button" onClick={() => onLoad(c)} className="mr-2 text-indigo-600 hover:underline">Load</button>}
                    <button type="button" onClick={() => deleteCandidate(c.id)} className="text-gray-400 hover:text-red-600" aria-label={`Delete ${c.name}`}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
