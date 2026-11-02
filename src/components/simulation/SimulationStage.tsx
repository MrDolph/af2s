'use client';
import { Children, isValidElement, useCallback, useEffect, useRef, useState, type ReactNode, type RefObject } from 'react';
import './simulation-stage.css';

/** Keeps the existing simulation mounted while expanding it with its controls. */
export function SimulationStage({ children, className = '', containerRef }: { children: ReactNode; className?: string; containerRef?: RefObject<HTMLDivElement | null> }) {
  const [expanded, setExpanded] = useState(false);
  const [controlsVisible, setControlsVisible] = useState(true);
  const root = useRef<HTMLDivElement>(null);
  const setRoot = useCallback((node: HTMLDivElement | null) => { root.current = node; if (containerRef) containerRef.current = node; }, [containerRef]);
  const toggle = useRef<HTMLButtonElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  const orientationLocked = useRef(false);
  const active = useRef(false);
  const items = Children.toArray(children);
  const role = (item: ReactNode) => isValidElement<{'data-stage-role'?: string}>(item) ? item.props['data-stage-role'] : undefined;
  const hasContent = (item: ReactNode): boolean => {
    if (!isValidElement<{children?: ReactNode}>(item)) return typeof item === 'string' ? item.trim().length > 0 : typeof item === 'number';
    if (typeof item.type !== 'string') return true;
    if (item.props.children === undefined) return ['input','canvas','iframe','img'].includes(item.type);
    return Children.toArray(item.props.children).some(hasContent);
  };
  const parameters = items.filter(item => role(item) === 'parameters' && hasContent(item));
  const scene = items.filter(item => role(item) !== 'parameters');
  function unlock() { if (orientationLocked.current) { try { screen.orientation?.unlock(); } catch {} orientationLocked.current = false; } }
  function close() {
    active.current = false;
    unlock();
    if (document.fullscreenElement === root.current) void document.exitFullscreen().catch(() => {});
    setExpanded(false);
  }
  function open() {
    active.current = true;
    previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    setExpanded(true);
    // Request landscape only after native fullscreen succeeds; physical rotation remains available.
    try {
      const request = root.current?.requestFullscreen?.();
      if (request) void request.then(async () => {
        if (!active.current) { if (document.fullscreenElement === root.current) void document.exitFullscreen().catch(() => {}); return; }
        if (!window.matchMedia('(pointer: coarse)').matches) return;
        const orientation = screen.orientation as ScreenOrientation & { lock?: (mode: string) => Promise<void> };
        try { await orientation.lock?.('landscape'); orientationLocked.current = !!orientation.lock; if (!active.current) unlock(); } catch {}
      }).catch(() => {});
    } catch {}
  }
  useEffect(() => {
    if (!expanded) return;
    const old = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    toggle.current?.focus();
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.preventDefault(); close(); } };
    const fullscreen = () => { if (!document.fullscreenElement) { active.current = false; unlock(); setExpanded(false); } };
    document.addEventListener('keydown', escape);
    document.addEventListener('fullscreenchange', fullscreen);
    return () => {
      active.current = false;
      unlock();
      document.body.style.overflow = old;
      document.removeEventListener('keydown', escape);
      document.removeEventListener('fullscreenchange', fullscreen);
      previousFocus.current?.focus();
    };
  }, [expanded]);
  useEffect(() => {
    if (!expanded || !root.current) return;
    const el = root.current;
    const main = el.querySelector<HTMLElement>('.af-stage-main');
    if (!main) return;
    let frame = 0;
    const resize = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const playback = Array.from(main.querySelectorAll<HTMLElement>('[data-stage-role="playback"]')).filter(p => p.getClientRects().length).reduce((sum, p) => sum + p.getBoundingClientRect().height, 0);
        el.style.setProperty('--af-stage-canvas-height', `${Math.max(40, main.clientHeight - playback - 36)}px`);
      });
    };
    const observer = new ResizeObserver(resize);
    observer.observe(main);
    main.querySelectorAll('[data-stage-role="playback"]').forEach(p => observer.observe(p));
    resize();
    return () => { cancelAnimationFrame(frame); observer.disconnect(); el.style.removeProperty('--af-stage-canvas-height'); };
  }, [expanded]);
  return <div ref={setRoot} data-simulation-stage data-expanded={expanded} className={`af-simulation-stage ${className}`} data-has-parameters={parameters.length > 0} data-controls-visible={controlsVisible}
    role={expanded ? 'dialog' : undefined} aria-modal={expanded || undefined} aria-label={expanded ? 'Classroom simulation view' : undefined}
    onKeyDown={e => {
      if (!expanded || e.key !== 'Tab') return;
      const elements = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),a[href],iframe,[tabindex="0"]') || []).filter(el => el.getClientRects().length);
      const first = elements[0], last = elements[elements.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last?.focus(); }
      if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
    }}>
    <div className="af-stage-toolbar"><span>{expanded ? 'Classroom view' : 'Simulation'}{expanded && <small className="af-rotate-hint"> · Rotate your phone for a wider view</small>}</span>
      {expanded && parameters.length > 0 && <button type="button" onClick={() => setControlsVisible(v => !v)} aria-expanded={controlsVisible}>{controlsVisible ? 'Hide parameters' : 'Show parameters'}</button>}
      <button ref={toggle} type="button" onClick={expanded ? close : open} aria-expanded={expanded}>{expanded ? 'Exit classroom view ✕' : '⛶ Expand simulation'}</button>
    </div>
    <div className="af-stage-body">
      <div className="af-stage-main">{scene}</div>
      {parameters.length > 0 && <aside className="af-stage-parameters" aria-label="Simulation parameters">{parameters}</aside>}
    </div>
  </div>;
}
