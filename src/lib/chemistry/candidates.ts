'use client';
// Saved candidates: kept in this browser's localStorage (nothing is uploaded).
import { useSyncExternalStore } from 'react';
import type { Composition } from './compound';

export interface Candidate {
  id: string;
  name: string;
  savedAt: string; // ISO
  kind: 'composition' | 'perovskite' | 'heusler' | 'crystal' | 'organic';
  formula: string;
  composition: Composition;
  molarMass: number;
  /** Rule-based charge-balance outcome at the time of saving. */
  chargeStatus: string;
  perovskite?: {
    model: 'cubic' | 'double';
    sites: Record<string, { symbol: string; charge: number } | undefined>;
    a: number;
    tolerance: number | null;
    octahedral: number | null;
    density: number | null;
  };
  heusler?: {
    template: string;
    elements: Record<string, string>;
    a: number;
    valenceElectrons: number;
    slaterPauling: number | null;
  };
  crystal?: {
    prototype: string;
    elements: Record<string, string>;
    a: number;
    density: number;
  };
  organic?: {
    atoms: { el: string; x: number; y: number }[];
    bonds: { a: number; b: number; order: number }[];
    smiles: string;
  };
  note?: string;
}

const KEY = 'af2s.chemistry.candidates.v1';
const EVENT = 'af2s-chem-candidates';
let cache: { raw: string | null; list: Candidate[] } = { raw: null, list: [] };

function read(): Candidate[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = window.localStorage.getItem(KEY);
    if (raw === cache.raw) return cache.list;
    const parsed = raw ? (JSON.parse(raw) as Candidate[]) : [];
    cache = { raw, list: Array.isArray(parsed) ? parsed : [] };
    return cache.list;
  } catch {
    return cache.list;
  }
}

function write(list: Candidate[]) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(list));
  } catch { /* storage full or blocked — the in-page list still works until reload */ }
  window.dispatchEvent(new Event(EVENT));
}

function subscribe(cb: () => void) {
  window.addEventListener(EVENT, cb);
  window.addEventListener('storage', cb);
  return () => { window.removeEventListener(EVENT, cb); window.removeEventListener('storage', cb); };
}
const EMPTY: Candidate[] = [];

export function useCandidates(): Candidate[] {
  return useSyncExternalStore(subscribe, read, () => EMPTY);
}
export function saveCandidate(c: Omit<Candidate, 'id' | 'savedAt'>): Candidate {
  const full: Candidate = { ...c, id: `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`, savedAt: new Date().toISOString() };
  write([full, ...read()]);
  return full;
}
export function deleteCandidate(id: string) { write(read().filter(c => c.id !== id)); }
export function renameCandidate(id: string, name: string) { write(read().map(c => (c.id === id ? { ...c, name } : c))); }

export function download(filename: string, text: string, mime = 'text/plain') {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a');
  a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function candidatesToCsv(list: Candidate[]): string {
  const esc = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const head = ['name', 'formula', 'kind', 'molar_mass_g_per_mol', 'charge_balance', 'model', 'tolerance_factor', 'octahedral_factor', 'a_estimate_A', 'saved_at', 'note'];
  const rows = list.map(c => [
    c.name, c.formula, c.kind, c.molarMass.toFixed(3), c.chargeStatus,
    c.perovskite?.model ?? '', c.perovskite?.tolerance?.toFixed(3) ?? '', c.perovskite?.octahedral?.toFixed(3) ?? '',
    c.perovskite?.a.toFixed(3) ?? '', c.savedAt, c.note ?? '',
  ].map(esc).join(','));
  return [head.join(','), ...rows].join('\n');
}
