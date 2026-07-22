'use client';
import { useState, useMemo } from 'react';

interface EmbedButtonProps {
  /** Embed route path, e.g. '/embed/projectile' */
  path: string;
  /** Query params baked into the embed URL (current simulation settings). */
  params?: Record<string, string | number>;
  /** Accessible title for the iframe. */
  title: string;
  width?: number;
  height?: number;
}

export function EmbedButton({ path, params = {}, title, width = 760, height = 520 }: EmbedButtonProps) {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  const embedUrl = useMemo(() => {
    const origin =
      typeof window !== 'undefined'
        ? window.location.origin
        : process.env.NEXT_PUBLIC_APP_URL ?? '';
    const qs = new URLSearchParams(
      Object.fromEntries(Object.entries(params).map(([k, v]) => [k, String(v)]))
    ).toString();
    return `${origin}${path}${qs ? `?${qs}` : ''}`;
  }, [path, params]);

  const snippet = `<iframe src="${embedUrl}" width="${width}" height="${height}" style="border:1px solid #e5e7eb;border-radius:12px;max-width:100%;" loading="lazy" allowfullscreen title="${title}"></iframe>`;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(snippet);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // Clipboard API unavailable — user can still select + copy manually.
    }
  };

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700"
      >
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4.5 3L1.5 6l3 3M7.5 3l3 3-3 3" />
        </svg>
        Embed
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          onClick={() => setOpen(false)}
        >
          <div
            className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-xl"
            onClick={e => e.stopPropagation()}
          >
            <div className="mb-3 flex items-start justify-between gap-4">
              <div>
                <h3 className="text-sm font-semibold text-gray-900">Embed this simulation</h3>
                <p className="mt-0.5 text-xs text-gray-400">
                  Paste this HTML into any website, LMS page, or blog. The embed uses the
                  current parameter values as its starting state.
                </p>
              </div>
              <button onClick={() => setOpen(false)} className="text-gray-300 transition hover:text-gray-500">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                  <path d="M4 4l8 8M12 4l-8 8" />
                </svg>
              </button>
            </div>

            <textarea
              readOnly
              value={snippet}
              rows={5}
              onFocus={e => e.target.select()}
              className="w-full resize-none rounded-xl border border-gray-200 bg-gray-50 p-3 font-mono text-[11px] leading-relaxed text-gray-700 outline-none focus:border-indigo-300"
            />

            <div className="mt-3 flex items-center justify-between gap-2">
              <a
                href={embedUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs font-medium text-indigo-600 hover:text-indigo-700"
              >
                Preview embed →
              </a>
              <button
                onClick={copy}
                className={`rounded-lg px-4 py-2 text-xs font-medium text-white transition ${
                  copied ? 'bg-emerald-500' : 'bg-indigo-600 hover:bg-indigo-700'
                }`}
              >
                {copied ? '✓ Copied' : 'Copy HTML'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
