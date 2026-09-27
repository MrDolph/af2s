'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AppHeader } from '@/components/layout/AppHeader';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [name, setName] = useState('');
  const [passcode, setPasscode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/minitab-auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passcode, name }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? 'Incorrect passcode.');
        return;
      }
      const next = searchParams.get('next') ?? '/minitab';
      router.push(next);
      router.refresh();
    } catch {
      setError('Something went wrong — check your connection and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-sm rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
      <p className="text-xs text-gray-400 mb-1">PHY 403 · Mathematical Methods for Physics I</p>
      <h1 className="text-lg font-semibold text-gray-900 mb-1">Student access</h1>
      <p className="text-xs text-gray-500 mb-5">
        This area is for enrolled students only. Enter your name and the passcode your lecturer shared with you.
      </p>
      <form onSubmit={submit} className="space-y-3">
        <input
          type="text"
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="Your name (first name is fine)"
          maxLength={40}
          autoFocus
          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
        />
        <input
          type="password"
          value={passcode}
          onChange={e => setPasscode(e.target.value)}
          placeholder="Passcode"
          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
        />
        {error && <p className="text-xs text-rose-600">{error}</p>}
        <button
          type="submit"
          disabled={loading || !passcode || !name.trim()}
          className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? 'Checking…' : 'Enter'}
        </button>
      </form>
    </div>
  );
}

export default function MinitabLoginPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        {/* useSearchParams() (inside LoginForm) requires a Suspense boundary
            in the App Router, or static export/prerendering fails the build. */}
        <Suspense fallback={<div className="text-sm text-gray-400">Loading…</div>}>
          <LoginForm />
        </Suspense>
      </main>
    </>
  );
}
