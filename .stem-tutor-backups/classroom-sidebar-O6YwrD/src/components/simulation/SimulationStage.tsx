'use client';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import './simulation-stage.css';

/** Keeps the existing simulation mounted while expanding it with its controls. */
export function SimulationStage({ children, className = '' }: { children: ReactNode; className?: string }) {
  const [expanded, setExpanded] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const toggle = useRef<HTMLButtonElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  function close() {
    if (document.fullscreenElement === root.current) void document.exitFullscreen().catch(() => {});
    setExpanded(false);
  }
  function open() {
    previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    setExpanded(true);
    // A fixed, scrollable view remains available when native fullscreen is unsupported.
    try { void root.current?.requestFullscreen?.().catch(() => {}); } catch {}
  }
  useEffect(() => {
    if (!expanded) return;
    const old = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    toggle.current?.focus();
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.preventDefault(); close(); } };
    const fullscreen = () => { if (!document.fullscreenElement) setExpanded(false); };
    document.addEventListener('keydown', escape);
    document.addEventListener('fullscreenchange', fullscreen);
    return () => {
      document.body.style.overflow = old;
      document.removeEventListener('keydown', escape);
      document.removeEventListener('fullscreenchange', fullscreen);
      previousFocus.current?.focus();
    };
  }, [expanded]);
  return <div ref={root} data-simulation-stage data-expanded={expanded} className={`af-simulation-stage ${className}`}
    role={expanded ? 'dialog' : undefined} aria-modal={expanded || undefined} aria-label={expanded ? 'Classroom simulation view' : undefined}
    onKeyDown={e => {
      if (!expanded || e.key !== 'Tab') return;
      const elements = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),a[href],[tabindex="0"]') || []).filter(el => el.getClientRects().length);
      const first = elements[0], last = elements[elements.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last?.focus(); }
      if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
    }}>
    <div className="af-stage-toolbar"><span>{expanded ? 'Classroom view · simulation and controls' : 'Simulation'}</span>
      <button ref={toggle} type="button" onClick={expanded ? close : open} aria-expanded={expanded}>{expanded ? 'Exit classroom view ✕' : '⛶ Expand simulation'}</button>
    </div>
    {children}
  </div>;
}
