'use client';
import { useState, useRef, useEffect, useId } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { SUBJECTS, isSubjectPath, type Subject } from '@/lib/subjects';

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor"
      strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"
      className={`transition-transform ${open ? 'rotate-180' : ''}`}
    >
      <path d="M2 3.5l3 3 3-3" />
    </svg>
  );
}

function SoonTag() {
  return (
    <span className="rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-400">
      Coming soon
    </span>
  );
}

// One row in the dropdown. 'soon' subjects are greyed out and not clickable.
function SubjectRow({ subject, current, onNavigate }: { subject: Subject; current: boolean; onNavigate: () => void }) {
  const body = (
    <>
      <span className="mt-0.5 text-lg leading-none" aria-hidden="true">{subject.icon}</span>
      <span className="min-w-0">
        <span className={`flex items-center gap-2 text-sm font-medium ${current ? 'text-indigo-700' : 'text-gray-800'}`}>
          {subject.label}
          {subject.status === 'soon' && <SoonTag />}
        </span>
        <span className="block text-xs leading-snug text-gray-500">{subject.description}</span>
      </span>
    </>
  );

  if (subject.status !== 'live') {
    return <div className="flex cursor-not-allowed items-start gap-3 rounded-lg px-3 py-2 opacity-60">{body}</div>;
  }
  return (
    <Link
      href={subject.href}
      onClick={onNavigate}
      aria-current={current ? 'page' : undefined}
      className={`flex items-start gap-3 rounded-lg px-3 py-2 transition ${current ? 'bg-indigo-50' : 'hover:bg-gray-50'}`}
    >
      {body}
    </Link>
  );
}

/** Desktop: a "Simulations ▾" button that reveals the subject list. */
export function SimulationsMenu() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const panelId = useId();
  const active = SUBJECTS.some(s => s.status === 'live' && isSubjectPath(pathname, s));

  // Close on outside click or Escape while open.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  return (
    <div ref={wrapRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-expanded={open}
        aria-controls={panelId}
        className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm transition ${
          active || open
            ? 'bg-indigo-50 text-indigo-700 font-medium'
            : 'text-gray-500 hover:text-gray-900 hover:bg-gray-50'
        }`}
      >
        Simulations
        <Chevron open={open} />
      </button>

      {/* Always rendered (just hidden when closed) so the links exist in the page HTML. */}
      <div
        id={panelId}
        className={`${open ? 'block' : 'hidden'} absolute left-0 top-full z-50 mt-2 w-72 rounded-xl border border-gray-200 bg-white p-1.5 shadow-lg`}
      >
        <p className="px-3 pb-1 pt-1.5 text-[10px] font-medium uppercase tracking-wide text-gray-400">
          Choose a subject
        </p>
        {SUBJECTS.map(s => (
          <SubjectRow
            key={s.slug}
            subject={s}
            current={s.status === 'live' && isSubjectPath(pathname, s)}
            onNavigate={() => setOpen(false)}
          />
        ))}
      </div>
    </div>
  );
}

/** Mobile: an expandable "Simulations" section with the subjects indented beneath it. */
export function SimulationsMobileMenu({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(true); // the mobile menu is already opened on purpose, so show the subjects
  const panelId = useId();
  const active = SUBJECTS.some(s => s.status === 'live' && isSubjectPath(pathname, s));

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-expanded={open}
        aria-controls={panelId}
        className={`flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition ${
          active ? 'bg-indigo-50 text-indigo-700 font-medium' : 'text-gray-600 hover:bg-gray-50'
        }`}
      >
        Simulations
        <Chevron open={open} />
      </button>
      {open && (
        <div id={panelId} className="ml-3 mt-1 space-y-0.5 border-l border-gray-100 pl-2">
          {SUBJECTS.map(s => (
            <SubjectRow
              key={s.slug}
              subject={s}
              current={s.status === 'live' && isSubjectPath(pathname, s)}
              onNavigate={() => onNavigate?.()}
            />
          ))}
        </div>
      )}
    </div>
  );
}
