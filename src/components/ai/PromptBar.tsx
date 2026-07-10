'use client';
import { useState } from 'react';
import type { AIPromptResponse } from '@/types/ai';

interface PromptBarProps { onResult: (r: AIPromptResponse) => void; className?: string; }

const EXAMPLE_PROMPTS = [
  'Show projectile motion at 45° and 30 m/s',
  "Demonstrate Newton's second law with 10 kg and 50 N",
  'Ṣe afihan projectile ti o bẹrẹ ni 20 m/s',
];

export function PromptBar({ onResult, className }: PromptBarProps) {
  const [prompt, setPrompt] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (text: string) => {
    if (!text.trim() || isLoading) return;
    setIsLoading(true); setError(null);
    try {
      const res = await fetch('/api/ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: text }),
      });
      if (!res.ok) { const d = await res.json(); throw new Error(d.error || 'Error'); }
      onResult(await res.json());
      setPrompt('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate simulation');
    } finally { setIsLoading(false); }
  };

  return (
    <div className={className}>
      <div className="flex gap-2">
        <input
          type="text" value={prompt}
          onChange={e => setPrompt(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleSubmit(prompt)}
          placeholder="Describe what you want to simulate…"
          disabled={isLoading}
          className="flex-1 rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100 disabled:opacity-50"
        />
        <button
          onClick={() => handleSubmit(prompt)}
          disabled={!prompt.trim() || isLoading}
          className="rounded-lg bg-indigo-600 px-5 py-3 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-40"
        >
          {isLoading ? 'Generating…' : 'Generate'}
        </button>
      </div>
      {error && <p className="text-sm text-red-600 mt-2">{error}</p>}
      <div className="flex flex-wrap gap-2 mt-3">
        {EXAMPLE_PROMPTS.map(p => (
          <button key={p} onClick={() => handleSubmit(p)} disabled={isLoading}
            className="rounded-full border border-gray-200 bg-gray-50 px-3 py-1 text-xs text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700 disabled:opacity-40">
            {p}
          </button>
        ))}
      </div>
    </div>
  );
}
