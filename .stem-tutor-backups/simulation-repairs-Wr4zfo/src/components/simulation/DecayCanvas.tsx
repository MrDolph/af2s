'use client';
import { useRef, useEffect, useCallback, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { decayProbability, decayCurve, remaining } from '@/lib/physics/decay';

// ── Canvas: grid of nuclei decaying stochastically ────────────────────────────
interface CanvasProps {
  n0: number;           // number of nuclei (perfect square works best)
  halfLife: number;     // seconds
  isRunning: boolean; isPaused: boolean;
  resetKey: number;
  onTick?: (t: number, nRemaining: number) => void;
  width?: number; height?: number;
}

export function DecayCanvas({ n0, halfLife, isRunning, isPaused, resetKey, onTick, width = 420, height = 300 }: CanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const decayedRef = useRef<boolean[]>([]);
  const sim = useRef({ n0, halfLife, isRunning, isPaused, onTick });
  sim.current = { n0, halfLife, isRunning, isPaused, onTick };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    decayedRef.current = new Array(n0).fill(false);
  }, [n0, halfLife, resetKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — measured half-life on screen equals the slider
    // value at any refresh rate. Each undecayed nucleus decays this frame
    // with probability p = 1 − 2^(−dt/T½): memoryless, exactly like nature.
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    if (dt > 0) {
      const p = decayProbability(s.halfLife, dt);
      const arr = decayedRef.current;
      for (let i = 0; i < arr.length; i++) {
        if (!arr[i] && Math.random() < p) arr[i] = true;
      }
    }
    const nLeft = decayedRef.current.reduce((a, d) => a + (d ? 0 : 1), 0);
    s.onTick?.(tRef.current, nLeft);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cols = Math.ceil(Math.sqrt(s.n0 * (W / H)));
    const rows = Math.ceil(s.n0 / cols);
    const cell = Math.min((W - 20) / cols, (H - 44) / rows);
    const ox = (W - cols * cell) / 2, oy = 8;
    const r = Math.max(2, cell * 0.32);
    for (let i = 0; i < s.n0; i++) {
      const cxp = ox + (i % cols) * cell + cell / 2;
      const cyp = oy + Math.floor(i / cols) * cell + cell / 2;
      ctx.beginPath(); ctx.arc(cxp, cyp, r, 0, Math.PI * 2);
      ctx.fillStyle = decayedRef.current[i] ? '#e2e8f0' : '#6366f1';
      ctx.fill();
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`t = ${tRef.current.toFixed(1)}s   remaining: ${nLeft}/${s.n0}   ● undecayed  ○ decayed`, 8, H - 10);
    // Expected from theory, for comparison against the random sample
    ctx.fillStyle = '#94a3b8'; ctx.textAlign = 'right';
    ctx.fillText(`theory: ${remaining(s.n0, s.halfLife, tRef.current).toFixed(0)}`, W - 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}

// ── Graph: analytic N–t curve + live dot for the measured count ───────────────
interface GraphProps {
  n0: number; halfLife: number;
  currentT?: number; currentN?: number;
}

export function DecayGraph({ n0, halfLife, currentT = 0, currentN }: GraphProps) {
  const tMax = 4 * halfLife;
  const data = useMemo(() => decayCurve(n0, halfLife, tMax), [n0, halfLife, tMax]);
  const markerT = Math.min(currentT, tMax);
  const theoryN = remaining(n0, halfLife, markerT);

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={[0, tMax]}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={[0, n0]}>
          <Label value="Nuclei remaining N" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(0), 'N']} labelFormatter={t => `t=${Number(t).toFixed(1)}s`} />
        <Line type="monotone" dataKey="n" stroke="#6366f1" strokeWidth={2} dot={false} name="theory" />
        {/* Half-life gridlines: N halves at every T½ */}
        {[1, 2, 3].map(k => (
          <ReferenceLine key={k} x={k * halfLife} stroke="#e2e8f0" strokeDasharray="4 4"
            label={{ value: `${k}T½`, position: 'top', fontSize: 9, fill: '#94a3b8' }} />
        ))}
        {currentT > 0 && <>
          <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
          {/* dot ON the theoretical curve */}
          <ReferenceDot x={markerT} y={theoryN} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          {/* measured (random) count from the canvas — scatters around theory */}
          {currentN !== undefined && (
            <ReferenceDot x={markerT} y={Math.min(currentN, n0)} r={5} fill="#ef4444" stroke="#fff" strokeWidth={2} />
          )}
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}
