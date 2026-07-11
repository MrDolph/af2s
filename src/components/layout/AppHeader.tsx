'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV = [
  { label: 'Simulations', href: '/simulations' },
  { label: 'About', href: '/about' },
];

export function AppHeader() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 border-b border-gray-200 bg-white/95 backdrop-blur-sm">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="flex h-14 items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2 group">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-600 group-hover:bg-indigo-700 transition">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="white">
                <path d="M7 1L13 4.5V9.5L7 13L1 9.5V4.5L7 1Z"/>
              </svg>
            </div>
            <div className="leading-none">
              <span className="text-sm font-semibold text-gray-900">A-Factor</span>
              <span className="hidden sm:block text-[10px] text-gray-400 leading-none">STEM Studio</span>
            </div>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden sm:flex items-center gap-1">
            {NAV.map(n => (
              <Link key={n.href} href={n.href}
                className={`px-3 py-1.5 rounded-lg text-sm transition ${
                  pathname.startsWith(n.href)
                    ? 'bg-indigo-50 text-indigo-700 font-medium'
                    : 'text-gray-500 hover:text-gray-900 hover:bg-gray-50'
                }`}>
                {n.label}
              </Link>
            ))}
            <Link href="/simulations"
              className="ml-2 rounded-lg bg-indigo-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-indigo-700 transition">
              Try now
            </Link>
          </nav>

          {/* Mobile menu button */}
          <button onClick={() => setOpen(v => !v)}
            className="sm:hidden rounded-lg p-2 text-gray-500 hover:bg-gray-100 transition"
            aria-label="Menu">
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
              {open
                ? <><path d="M3 3l12 12M15 3L3 15"/></>
                : <><path d="M2 5h14M2 9h14M2 13h14"/></>
              }
            </svg>
          </button>
        </div>

        {/* Mobile nav */}
        {open && (
          <div className="sm:hidden border-t border-gray-100 py-3 space-y-1">
            {NAV.map(n => (
              <Link key={n.href} href={n.href} onClick={() => setOpen(false)}
                className={`block px-3 py-2 rounded-lg text-sm transition ${
                  pathname.startsWith(n.href)
                    ? 'bg-indigo-50 text-indigo-700 font-medium'
                    : 'text-gray-600 hover:bg-gray-50'
                }`}>
                {n.label}
              </Link>
            ))}
            <Link href="/simulations" onClick={() => setOpen(false)}
              className="block mt-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white text-center">
              Try now
            </Link>
          </div>
        )}
      </div>
    </header>
  );
}
