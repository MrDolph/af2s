'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  TunnelingParams, PotentialType,
  initWavePacket, buildPotential, evolveStep, applyAbsorbingBoundary,
  measureProbabilities, analyticalTransmission, wkbTransmission,
  getDecayConstant, getWavelength,
  type Complex, type TunnelingStats,
} from '@/lib/physics/quantumTunneling';

interface Props {
  params: TunnelingParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: TunnelingStats) => void;
  width?: number;
  height?: number;
}

const N_GRID = 512;
const L_BOX = 60;
const DT_SIM = 0.12;

export function QuantumTunnelingCanvas({ params, isRunning, isPaused, onTick, width = 720, height = 500 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, isRunning, isPaused, onTick });
  propsRef.current = { params, isRunning, isPaused, onTick };

  const simRef = useRef<{
    psi: Complex[]; V: number[]; x: number[]; k: number[];
    dx: number; classicalX: number; classicalDir: number;
    initialized: boolean;
  }>({ psi: [], V: [], x: [], k: [], dx: 0, classicalX: 0, classicalDir: 1, initialized: false });

  const initSim = useCallback(() => {
    const p = propsRef.current.params;
    const dx = L_BOX / N_GRID;
    const x: number[] = [];
    const k: number[] = [];
    for (let i = 0; i < N_GRID; i++) {
      x.push(i * dx);
      let idx = i;
      if (idx >= N_GRID / 2) idx -= N_GRID;
      k.push((2 * Math.PI * idx) / L_BOX);
    }
    const V = buildPotential(p.potentialType, x, p.barrierHeight, p.barrierWidth, p.barrierPosition);
    const k0 = 0.512 * Math.sqrt(p.particleMass * p.particleEnergy);
    const x0 = Math.max(3, p.barrierPosition - 10);
    const psi = initWavePacket(x0, k0, p.packetWidth, x, dx);
    simRef.current = { psi, V, x, k, dx, classicalX: x0, classicalDir: 1, initialized: true };
    timeRef.current = 0;
  }, []);

  useEffect(() => { initSim(); }, [initSim]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current;

    const dpr = window.devicePixelRatio || 1;
    const displayW = width;
    const displayH = height;
    if (canvas.width !== Math.floor(displayW * dpr) || canvas.height !== Math.floor(displayH * dpr)) {
      canvas.width = Math.floor(displayW * dpr);
      canvas.height = Math.floor(displayH * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const sim = simRef.current;
    if (!sim.initialized) { rafRef.current = requestAnimationFrame(draw); return; }

    // Evolution
    if (dt > 0 && s.isRunning && !s.isPaused) {
      const steps = Math.ceil(s.params.speed * 3);
      for (let step = 0; step < steps; step++) {
        sim.psi = evolveStep(sim.psi, sim.V, sim.k, DT_SIM, s.params.particleMass);
        applyAbsorbingBoundary(sim.psi, sim.x, L_BOX);
        timeRef.current += DT_SIM;
      }

      const vClassical = 6 * Math.sqrt(s.params.particleEnergy / s.params.particleMass) * dt * s.params.speed;
      const maxV = Math.max(...sim.V);
      sim.classicalX += sim.classicalDir * vClassical;
      if (s.params.particleEnergy < maxV && sim.classicalDir > 0 && sim.classicalX >= s.params.barrierPosition) {
        sim.classicalDir = -1;
      }
      if (sim.classicalX < 0) { sim.classicalX = 0; sim.classicalDir = 1; }
      if (sim.classicalX > L_BOX) { sim.classicalX = L_BOX; sim.classicalDir = -1; }

      if (s.params.autoRestart && timeRef.current > 120) {
        const pr = measureProbabilities(sim.psi, sim.x, s.params.barrierPosition, s.params.barrierWidth, sim.dx);
        if (pr.right > 0.55 || pr.left > 0.55 || timeRef.current > 350) initSim();
      }
    }

    // Background
    ctx.clearRect(0, 0, displayW, displayH);
    ctx.fillStyle = '#0b1021';
    ctx.fillRect(0, 0, displayW, displayH);

    drawGrid(ctx, displayW, displayH);

    const axisY = displayH * 0.82;
    const xScale = displayW / L_BOX;

    const maxV = Math.max(1, s.params.barrierHeight * 1.2, Math.max(...sim.V) * 1.2);
    const vScale = (axisY - 40) / maxV;

    let maxProb = 0, maxPsi = 0;
    for (let i = 0; i < N_GRID; i++) {
      const prob = sim.psi[i].re * sim.psi[i].re + sim.psi[i].im * sim.psi[i].im;
      if (prob > maxProb) maxProb = prob;
      const a = Math.sqrt(prob);
      if (a > maxPsi) maxPsi = a;
    }
    maxProb = Math.max(maxProb, 0.01);
    maxPsi = Math.max(maxPsi, 0.01);
    const probScale = ((axisY - 60) / maxProb) * 0.65;
    const psiScale = ((axisY - 100) / maxPsi) * 0.22;

    const barStart = s.params.barrierPosition;
    const barEnd = s.params.potentialType === 'step' ? L_BOX : s.params.barrierPosition + s.params.barrierWidth;
    const pxStart = barStart * xScale;
    const pxEnd = barEnd * xScale;

    // Region tints
    ctx.fillStyle = 'rgba(59, 130, 246, 0.03)';
    ctx.fillRect(0, 0, pxStart, displayH);
    ctx.fillStyle = 'rgba(16, 185, 129, 0.03)';
    ctx.fillRect(pxEnd, 0, displayW - pxEnd, displayH);
    if (s.params.potentialType !== 'step') {
      ctx.fillStyle = 'rgba(251, 191, 36, 0.03)';
      ctx.fillRect(pxStart, 0, pxEnd - pxStart, displayH);
    }

    // Potential
    if (s.params.showPotential) {
      ctx.beginPath();
      ctx.moveTo(0, axisY);
      for (let i = 0; i < N_GRID; i++) ctx.lineTo(sim.x[i] * xScale, axisY - sim.V[i] * vScale);
      ctx.lineTo(displayW, axisY);
      ctx.closePath();
      ctx.fillStyle = 'rgba(251, 191, 36, 0.12)';
      ctx.fill();
      ctx.strokeStyle = 'rgba(251, 191, 36, 0.55)';
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // Energy line
    if (s.params.showEnergyLine) {
      const eY = axisY - s.params.particleEnergy * vScale;
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
      ctx.setLineDash([4, 4]);
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, eY); ctx.lineTo(displayW, eY); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.45)';
      ctx.font = '10px system-ui'; ctx.textAlign = 'right';
      ctx.fillText(`E = ${s.params.particleEnergy.toFixed(2)} eV`, displayW - 10, eY - 4);
    }

    // |ψ|²
    if (s.params.showProbability) {
      ctx.beginPath();
      ctx.moveTo(0, axisY);
      for (let i = 0; i < N_GRID; i++) {
        const prob = sim.psi[i].re * sim.psi[i].re + sim.psi[i].im * sim.psi[i].im;
        ctx.lineTo(sim.x[i] * xScale, axisY - prob * probScale);
      }
      ctx.lineTo(displayW, axisY);
      ctx.closePath();
      const grad = ctx.createLinearGradient(0, axisY, 0, axisY - displayH * 0.5);
      grad.addColorStop(0, 'rgba(59, 130, 246, 0.5)');
      grad.addColorStop(1, 'rgba(99, 102, 241, 0.08)');
      ctx.fillStyle = grad;
      ctx.fill();
    }

    // Phase coloring
    if (s.params.showPhase) {
      for (let i = 0; i < N_GRID; i += 2) {
        const prob = sim.psi[i].re * sim.psi[i].re + sim.psi[i].im * sim.psi[i].im;
        if (prob < 0.0005) continue;
        const phase = Math.atan2(sim.psi[i].im, sim.psi[i].re);
        const hue = ((phase + Math.PI) / (2 * Math.PI)) * 360;
        ctx.fillStyle = `hsla(${hue}, 85%, 60%, ${Math.min(0.5, (prob / maxProb) * 1.5)})`;
        ctx.fillRect(sim.x[i] * xScale - 1, axisY - prob * probScale, 3, prob * probScale + 1);
      }
    }

    // Re(ψ)
    if (s.params.showRealPart) {
      ctx.beginPath();
      for (let i = 0; i < N_GRID; i++) {
        const y = axisY - 28 - sim.psi[i].re * psiScale;
        if (i === 0) ctx.moveTo(sim.x[i] * xScale, y); else ctx.lineTo(sim.x[i] * xScale, y);
      }
      ctx.strokeStyle = 'rgba(16, 185, 129, 0.55)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Im(ψ)
    if (s.params.showImaginaryPart) {
      ctx.beginPath();
      for (let i = 0; i < N_GRID; i++) {
        const y = axisY - 28 - sim.psi[i].im * psiScale;
        if (i === 0) ctx.moveTo(sim.x[i] * xScale, y); else ctx.lineTo(sim.x[i] * xScale, y);
      }
      ctx.strokeStyle = 'rgba(244, 63, 94, 0.55)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Classical ghost
    if (s.params.showClassical) {
      const cx = sim.classicalX * xScale;
      const cy = axisY - 12;
      ctx.fillStyle = 'rgba(251, 191, 36, 0.25)';
      ctx.beginPath(); ctx.arc(cx, cy, 10, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.arc(cx, cy, 3.5, 0, Math.PI * 2); ctx.fill();
    }

    // Axis
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(displayW, axisY); ctx.stroke();

    // Ticks
    ctx.fillStyle = 'rgba(148, 163, 184, 0.4)';
    ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    for (let xv = 0; xv <= L_BOX; xv += 10) {
      const px = xv * xScale;
      ctx.fillText(`${xv} Å`, px, axisY + 14);
      ctx.beginPath(); ctx.moveTo(px, axisY); ctx.lineTo(px, axisY + 4); ctx.stroke();
    }

    // Region labels
    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(59, 130, 246, 0.35)';
    ctx.fillText('INCIDENT', pxStart / 2, 18);
    if (s.params.potentialType !== 'step') {
      ctx.fillStyle = 'rgba(251, 191, 36, 0.35)';
      ctx.fillText('BARRIER', (pxStart + pxEnd) / 2, 18);
    }
    ctx.fillStyle = 'rgba(16, 185, 129, 0.35)';
    ctx.fillText('TRANSMITTED', (pxEnd + displayW) / 2, 18);

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (!s.isRunning) { ctx.fillStyle = '#94a3b8'; ctx.fillText('Press Run to launch wave packet', displayW / 2, 28); }
    else if (s.isPaused) { ctx.fillStyle = '#f59e0b'; ctx.fillText('⏸ Paused', displayW / 2, 28); }
    else { ctx.fillStyle = '#10b981'; ctx.fillText('● Evolving', displayW / 2, 28); }

    if (s.onTick && timestamp !== undefined) {
      const now = performance.now();
      if (now - lastTickRef.current > 80) {
        lastTickRef.current = now;
        const probs = measureProbabilities(sim.psi, sim.x, s.params.barrierPosition, s.params.barrierWidth, sim.dx);
        const theo = (s.params.potentialType === 'barrier' || s.params.potentialType === 'well')
          ? analyticalTransmission(s.params.particleEnergy, Math.abs(s.params.barrierHeight), s.params.barrierWidth, s.params.particleMass)
          : wkbTransmission(s.params.particleEnergy, sim.V, sim.x, sim.dx, s.params.particleMass);
        s.onTick({
          energy: s.params.particleEnergy,
          momentum: 0.512 * Math.sqrt(s.params.particleMass * s.params.particleEnergy),
          barrierHeight: s.params.barrierHeight,
          barrierWidth: s.params.barrierWidth,
          theoreticalT: theo,
          measuredT: probs.right,
          measuredR: probs.left,
          wavelength: getWavelength(s.params.particleEnergy, s.params.particleMass),
          decayConstant: getDecayConstant(s.params.particleEnergy, s.params.barrierHeight, s.params.particleMass),
          time: timeRef.current,
        });
      }
    }

    rafRef.current = requestAnimationFrame(draw);
  }, [width, height, initSim]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  function drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.06)';
    ctx.lineWidth = 1;
    const xScale = w / L_BOX;
    for (let i = 0; i < L_BOX; i += 5) {
      ctx.beginPath(); ctx.moveTo(i * xScale, 0); ctx.lineTo(i * xScale, h); ctx.stroke();
    }
    for (let j = 0; j < h; j += 40) {
      ctx.beginPath(); ctx.moveTo(0, j); ctx.lineTo(w, j); ctx.stroke();
    }
  }

  return <canvas ref={canvasRef} width={width} height={height} className="w-full rounded-xl border border-gray-700 bg-slate-900" style={{ display: 'block' }} />;
}
