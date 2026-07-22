'use client';
import { useEffect, useState, type RefObject } from 'react';

/**
 * Measures the width of a wrapping container (via an externally-created ref)
 * and returns a canvas size that fills it (up to maxWidth), preserving the
 * aspect ratio of baseWidth:baseHeight.
 *
 * Usage:
 *   const boxRef = useRef<HTMLDivElement>(null);
 *   const { width, height } = useResponsiveCanvasSize(boxRef, 640, 300, 980);
 *   <div ref={boxRef}><MyCanvas width={width} height={height} /></div>
 *
 * Every simulation canvas in this app reads its size either straight from
 * its `width`/`height` props or from the live <canvas> element's own
 * width/height attributes (which React keeps in sync with those same
 * props) — so simply passing a dynamically-computed width/height here is
 * enough to make the whole animation scale up, with no changes needed
 * inside the canvas components themselves.
 */
export function useResponsiveCanvasSize(
  containerRef: RefObject<HTMLElement | null>,
  baseWidth: number,
  baseHeight: number,
  maxWidth = 980,
) {
  const aspect = baseWidth / baseHeight;
  const [size, setSize] = useState({ width: baseWidth, height: baseHeight });

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const update = () => {
      const available = el.clientWidth;
      if (!available) return;
      const w = Math.round(Math.min(available, maxWidth));
      const h = Math.round(w / aspect);
      setSize(prev => (prev.width === w && prev.height === h ? prev : { width: w, height: h }));
    };

    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aspect, maxWidth]);

  return size;
}
