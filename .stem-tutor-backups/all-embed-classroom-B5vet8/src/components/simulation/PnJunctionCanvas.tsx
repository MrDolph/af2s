// src/components/simulation/PnJunctionCanvas.tsx
'use client';

import React, { useRef, useEffect, useCallback } from 'react';
import { computeJunctionState, MaterialParams, JunctionState } from '@/lib/physics/pnJunction';

interface PnJunctionCanvasProps {
  params: MaterialParams;
  width?: number;
  height?: number;
}

export default function PnJunctionCanvas({ params, width = 900, height = 600 }: PnJunctionCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number>(0);
  const timeRef = useRef<number>(0);
  
  const state = computeJunctionState(params);
  
  const draw = useCallback((ctx: CanvasRenderingContext2D, t: number) => {
    const W = ctx.canvas.width;
    const H = ctx.canvas.height;
    const { Na, Nd, temperature, appliedBias, material, circuitMode, Vin, Rload, freq } = params;
    const { Vbi, Wp, Wn, Wtotal, Emax, Id, Vd, Pout, efficiency, ripple, Vdc } = state;
    
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, W, H);
    
    const margin = 50;
    const centerX = W / 2;
    
    if (circuitMode === 'diode') {
      drawDiodeMode(ctx, W, H, margin, centerX, t);
    } else {
      drawRectifierMode(ctx, W, H, margin, centerX, t);
    }
    
    ctx.fillStyle = 'rgba(15, 23, 42, 0.9)';
    ctx.fillRect(margin, H - 55, 340, 42);
    ctx.strokeStyle = '#334155';
    ctx.strokeRect(margin, H - 55, 340, 42);
    
    ctx.fillStyle = '#e2e8f0';
    ctx.font = '11px monospace';
    ctx.textAlign = 'left';
    ctx.fillText(`Vbi=${Vbi.toFixed(3)}V  Wdep=${Wtotal.toFixed(1)}nm  Id=${Id.toFixed(3)}mA`, margin + 8, H - 38);
    ctx.fillText(`Emax=${(Emax/1e4).toFixed(1)}kV/cm  Pout=${Pout.toFixed(1)}mW  η=${efficiency.toFixed(1)}%`, margin + 8, H - 22);
    
    ctx.fillStyle = '#e2e8f0';
    ctx.font = 'bold 15px sans-serif';
    ctx.textAlign = 'center';
    const modeLabel = circuitMode === 'diode' ? 'Diode Characteristic' : 
                      circuitMode === 'half-wave' ? 'Half-Wave Rectifier' : 'Full-Wave Bridge Rectifier';
    ctx.fillText(`${material} PN Junction — ${modeLabel} @ ${temperature}K`, W / 2, 22);
    
  }, [params, state]);
  
  function drawDiodeMode(ctx: CanvasRenderingContext2D, W: number, H: number, margin: number, centerX: number, t: number) {
    const { Na, Nd, appliedBias, material, temperature } = params;
    const { Vbi, Wp, Wn, Wtotal, fermiLevelP, fermiLevelN } = state;
    
    const crossY = 70;
    const crossH = 110;
    const devW = 280;
    const devStartX = centerX - devW / 2;
    
    ctx.fillStyle = '#1e3a5f';
    ctx.fillRect(devStartX, crossY, devW / 2 - 2, crossH);
    ctx.fillRect(devStartX + devW / 2 + 2, crossY, devW / 2 - 2, crossH);
    
    const maxW = 200;
    const scaleW = Math.min(devW / 4 / maxW, 1);
    const dispWp = Wp * scaleW;
    const dispWn = Wn * scaleW;
    
    const depGrad = ctx.createLinearGradient(centerX - dispWp, 0, centerX + dispWn, 0);
    depGrad.addColorStop(0, '#334155');
    depGrad.addColorStop(0.5, '#475569');
    depGrad.addColorStop(1, '#334155');
    ctx.fillStyle = depGrad;
    ctx.fillRect(centerX - dispWp, crossY, dispWp + dispWn, crossH);
    
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 5]);
    ctx.beginPath();
    ctx.moveTo(centerX, crossY - 8);
    ctx.lineTo(centerX, crossY + crossH + 8);
    ctx.stroke();
    ctx.setLineDash([]);
    
    ctx.fillStyle = '#e2e8f0';
    ctx.font = 'bold 12px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('P-TYPE', devStartX + (devW/2 - dispWp)/2, crossY + crossH/2);
    ctx.fillText('N-TYPE', centerX + dispWn + (devW/2 - dispWn)/2, crossY + crossH/2);
    ctx.fillText('DEPLETION', centerX, crossY + crossH/2);
    
    ctx.fillStyle = '#f87171';
    for (let i = 0; i < 6; i++) {
      const x = centerX - dispWp + (dispWp/6)*i + dispWp/12;
      for (let j = 0; j < 3; j++) {
        ctx.fillRect(x - 3, crossY + 12 + j*32, 6, 1.5);
      }
    }
    ctx.fillStyle = '#60a5fa';
    for (let i = 0; i < 6; i++) {
      const x = centerX + (dispWn/6)*i + dispWn/12;
      for (let j = 0; j < 3; j++) {
        ctx.fillRect(x - 3, crossY + 12 + j*32, 6, 1.5);
        ctx.fillRect(x - 1, crossY + 10 + j*32, 1.5, 5);
      }
    }
    
    const holeCount = Math.min(Math.floor(Na/1e15), 25);
    for (let i = 0; i < holeCount; i++) {
      const bx = (i*137.3) % (devW/2 - dispWp - 16);
      const by = (i*89.7) % (crossH - 16);
      const x = devStartX + 8 + bx;
      const y = crossY + 8 + by;
      const drift = appliedBias > 0 ? Math.sin(t*2 + i)*3 : 0;
      ctx.strokeStyle = '#f87171';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(x + drift, y, 4, 0, Math.PI*2);
      ctx.stroke();
      ctx.fillStyle = '#f87171';
      ctx.font = '7px sans-serif';
      ctx.fillText('+', x + drift, y + 2.5);
    }
    
    const elecCount = Math.min(Math.floor(Nd/1e15), 25);
    for (let i = 0; i < elecCount; i++) {
      const bx = (i*151.7) % (devW/2 - dispWn - 16);
      const by = (i*67.3) % (crossH - 16);
      const x = centerX + dispWn + 8 + bx;
      const y = crossY + 8 + by;
      const drift = appliedBias > 0 ? Math.sin(t*2 + i + 1)*3 : 0;
      ctx.fillStyle = '#60a5fa';
      ctx.beginPath();
      ctx.arc(x + drift, y, 3.5, 0, Math.PI*2);
      ctx.fill();
    }
    
    if (appliedBias > 0.1) {
      ctx.strokeStyle = '#fbbf24';
      ctx.lineWidth = 2;
      const arrowCount = Math.min(Math.floor(appliedBias*5), 6);
      for (let i = 0; i < arrowCount; i++) {
        const progress = ((t*0.5 + i/arrowCount) % 1);
        const hx = devStartX + (centerX + dispWn - devStartX)*progress;
        const hy = crossY - 12 + (i%3)*8;
        ctx.beginPath();
        ctx.moveTo(hx - 8, hy); ctx.lineTo(hx, hy);
        ctx.lineTo(hx - 3, hy - 2.5);
        ctx.moveTo(hx, hy); ctx.lineTo(hx - 3, hy + 2.5);
        ctx.stroke();
      }
    }
    
    const bandY = crossY + crossH + 35;
    const bandH = 130;
    const midBand = bandY + bandH/2;
    const props = { Si: 1.12, Ge: 0.67, GaAs: 1.42 };
    const Eg = props[material];
    const scaleE = bandH / 2.5;
    
    ctx.strokeStyle = '#f87171';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(margin, midBand + fermiLevelP*scaleE + Eg*scaleE/2);
    ctx.lineTo(centerX - dispWp, midBand + fermiLevelP*scaleE + Eg*scaleE/2);
    ctx.bezierCurveTo(centerX - dispWp/2, midBand + fermiLevelP*scaleE + Eg*scaleE/2,
                      centerX + dispWn/2, midBand + fermiLevelN*scaleE + Eg*scaleE/2,
                      centerX + dispWn, midBand + fermiLevelN*scaleE + Eg*scaleE/2);
    ctx.lineTo(W - margin, midBand + fermiLevelN*scaleE + Eg*scaleE/2);
    ctx.stroke();
    
    ctx.strokeStyle = '#60a5fa';
    ctx.beginPath();
    ctx.moveTo(margin, midBand + fermiLevelP*scaleE - Eg*scaleE/2);
    ctx.lineTo(centerX - dispWp, midBand + fermiLevelP*scaleE - Eg*scaleE/2);
    ctx.bezierCurveTo(centerX - dispWp/2, midBand + fermiLevelP*scaleE - Eg*scaleE/2,
                      centerX + dispWn/2, midBand + fermiLevelN*scaleE - Eg*scaleE/2,
                      centerX + dispWn, midBand + fermiLevelN*scaleE - Eg*scaleE/2);
    ctx.lineTo(W - margin, midBand + fermiLevelN*scaleE - Eg*scaleE/2);
    ctx.stroke();
    
    ctx.strokeStyle = '#4ade80';
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(margin, midBand + fermiLevelP*scaleE);
    ctx.lineTo(centerX - dispWp, midBand + fermiLevelP*scaleE);
    ctx.bezierCurveTo(centerX - dispWp/2, midBand + (fermiLevelP+fermiLevelN)/2*scaleE,
                      centerX + dispWn/2, midBand + (fermiLevelP+fermiLevelN)/2*scaleE,
                      centerX + dispWn, midBand + fermiLevelN*scaleE);
    ctx.lineTo(W - margin, midBand + fermiLevelN*scaleE);
    ctx.stroke();
    ctx.setLineDash([]);
    
    ctx.fillStyle = '#f87171'; ctx.font = '11px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText('Ev', margin + 4, midBand + fermiLevelP*scaleE + Eg*scaleE/2 - 4);
    ctx.fillStyle = '#60a5fa';
    ctx.fillText('Ec', margin + 4, midBand + fermiLevelP*scaleE - Eg*scaleE/2 - 4);
    ctx.fillStyle = '#4ade80';
    ctx.fillText('Ef', margin + 4, midBand + fermiLevelP*scaleE - 4);
    
    const ivX = W - margin - 200;
    const ivY = crossY + 10;
    const ivW = 190;
    const ivH = 110;
    
    ctx.fillStyle = 'rgba(15,23,42,0.92)';
    ctx.fillRect(ivX, ivY, ivW, ivH);
    ctx.strokeStyle = '#475569'; ctx.lineWidth = 1;
    ctx.strokeRect(ivX, ivY, ivW, ivH);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('I-V Characteristic', ivX + ivW/2, ivY + 12);
    
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(ivX + 22, ivY + ivH - 18);
    ctx.lineTo(ivX + ivW - 4, ivY + ivH - 18);
    ctx.moveTo(ivX + 22, ivY + ivH - 18);
    ctx.lineTo(ivX + 22, ivY + 5);
    ctx.stroke();
    
    ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 1.8;
    ctx.beginPath();
    const VT = 0.0258 * (temperature/300);
    const Js = 1e-12;
    for (let px = 0; px < ivW - 30; px++) {
      const v = (px/(ivW-30))*1.0 - 0.3;
      const i = Js * (Math.exp(v/VT) - 1);
      const plotI = Math.max(-1, Math.min(1, i/1e-3));
      const py = (ivY + ivH - 18) - plotI*(ivH - 26)/2;
      if (px === 0) ctx.moveTo(ivX + 22 + px, py);
      else ctx.lineTo(ivX + 22 + px, py);
    }
    ctx.stroke();
    
    const opV = (appliedBias + 0.3)/1.0 * (ivW - 30);
    const opI = Js * (Math.exp(appliedBias/VT) - 1);
    const plotOpI = Math.max(-1, Math.min(1, opI/1e-3));
    const opY = (ivY + ivH - 18) - plotOpI*(ivH - 26)/2;
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(ivX + 22 + opV, opY, 3.5, 0, Math.PI*2); ctx.fill();
  }
  
  function drawRectifierMode(ctx: CanvasRenderingContext2D, W: number, H: number, margin: number, centerX: number, t: number) {
    const { Vin, Rload, freq, circuitMode, material } = params;
    const { Vdc, ripple, efficiency, Pout } = state;
    
    const omega = 2 * Math.PI * freq;
    const vInstant = Vin * Math.sin(omega * t);
    
    const circY = 55;
    const circH = 180;
    
    if (circuitMode === 'half-wave') {
      drawHalfWaveCircuit(ctx, margin + 30, circY, circH, t, vInstant);
    } else {
      drawFullWaveCircuit(ctx, margin + 30, circY, circH, t, vInstant);
    }
    
    const waveX = margin;
    const waveY = circY + circH + 30;
    const waveW = (W - margin*2) / 2 - 10;
    const waveH = 100;
    
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.fillRect(waveX, waveY, waveW, waveH);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(waveX, waveY, waveW, waveH);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('AC Input Voltage', waveX + waveW/2, waveY + 14);
    
    ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 0.5;
    for (let i = 1; i < 4; i++) {
      const gy = waveY + i * waveH/4;
      ctx.beginPath(); ctx.moveTo(waveX, gy); ctx.lineTo(waveX + waveW, gy); ctx.stroke();
    }
    
    ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 2;
    ctx.beginPath();
    for (let px = 0; px < waveW; px++) {
      const phase = (px/waveW) * 4 * Math.PI - t * omega * 0.3;
      const amp = (Vin/15) * (waveH/2 - 10);
      const py = waveY + waveH/2 - Math.sin(phase) * amp;
      if (px === 0) ctx.moveTo(waveX + px, py);
      else ctx.lineTo(waveX + px, py);
    }
    ctx.stroke();
    
    const markerPhase = -t * omega * 0.3;
    const markerY = waveY + waveH/2 - Math.sin(markerPhase) * (Vin/15) * (waveH/2 - 10);
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(waveX + waveW/2, markerY, 4, 0, Math.PI*2); ctx.fill();
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(`Vpeak = ${Vin.toFixed(1)}V`, waveX + 8, waveY + waveH - 8);
    ctx.fillText(`f = ${freq}Hz`, waveX + waveW - 60, waveY + waveH - 8);
    
    const outX = waveX + waveW + 20;
    const outW = waveW;
    
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.fillRect(outX, waveY, outW, waveH);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(outX, waveY, outW, waveH);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('DC Output Voltage', outX + outW/2, waveY + 14);
    
    ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 0.5;
    for (let i = 1; i < 4; i++) {
      const gy = waveY + i * waveH/4;
      ctx.beginPath(); ctx.moveTo(outX, gy); ctx.lineTo(outX + outW, gy); ctx.stroke();
    }
    
    ctx.strokeStyle = '#4ade80'; ctx.lineWidth = 2;
    ctx.beginPath();
    for (let px = 0; px < outW; px++) {
      const phase = (px/outW) * 4 * Math.PI - t * omega * 0.3;
      let vout = 0;
      if (circuitMode === 'half-wave') {
        const vin = Math.sin(phase);
        vout = vin > 0 ? (Vin - 0.7) * vin : 0;
      } else {
        vout = (Vin - 0.7) * Math.abs(Math.sin(phase));
      }
      const amp = (1/15) * (waveH/2 - 10);
      const py = waveY + waveH/2 - vout * amp;
      if (px === 0) ctx.moveTo(outX + px, py);
      else ctx.lineTo(outX + px, py);
    }
    ctx.stroke();
    
    ctx.strokeStyle = '#f87171'; ctx.setLineDash([4, 3]); ctx.lineWidth = 1.5;
    const dcY = waveY + waveH/2 - Vdc * (1/15) * (waveH/2 - 10);
    ctx.beginPath(); ctx.moveTo(outX, dcY); ctx.lineTo(outX + outW, dcY); ctx.stroke();
    ctx.setLineDash([]);
    
    ctx.fillStyle = '#f87171'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(`Vdc = ${Vdc.toFixed(2)}V`, outX + 8, dcY - 4);
    
    const flowY = waveY + waveH + 25;
    ctx.fillStyle = '#94a3b8'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Current Flow Through Load', centerX, flowY + 12);
    
    const loadX = centerX - 60;
    const loadW = 120;
    ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(loadX, flowY + 30);
    for (let i = 0; i < 6; i++) {
      ctx.lineTo(loadX + i*20 + 5, flowY + 22);
      ctx.lineTo(loadX + i*20 + 15, flowY + 38);
    }
    ctx.lineTo(loadX + loadW, flowY + 30);
    ctx.stroke();
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = '10px sans-serif';
    ctx.fillText(`Rload = ${Rload}Ω`, centerX, flowY + 52);
    
    const Ipeak = (Vin - 0.7) / Rload * 1000;
    const Iinstant = circuitMode === 'half-wave' 
      ? (vInstant > 0 ? (vInstant - 0.7) / Rload * 1000 : 0)
      : (Math.abs(vInstant) - 0.7) / Rload * 1000;
    const dotCount = Math.max(0, Math.min(8, Math.floor(Iinstant / 2)));
    
    for (let i = 0; i < dotCount; i++) {
      const progress = ((t * 2 + i / Math.max(dotCount, 1)) % 1);
      const dx = loadX + progress * loadW;
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.arc(dx, flowY + 30, 3, 0, Math.PI*2); ctx.fill();
    }
    
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.fillRect(margin, flowY + 60, 280, 55);
    ctx.strokeStyle = '#334155'; ctx.strokeRect(margin, flowY + 60, 280, 55);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    ctx.fillText(`Pdc = ${Pout.toFixed(2)} mW`, margin + 10, flowY + 78);
    ctx.fillText(`η = ${efficiency.toFixed(1)}%`, margin + 10, flowY + 94);
    ctx.fillText(`Ripple = ${ripple.toFixed(1)}%`, margin + 140, flowY + 78);
    ctx.fillText(`Ipeak = ${Ipeak.toFixed(1)} mA`, margin + 140, flowY + 94);
    
    const miniX = W - margin - 220;
    const miniY = flowY + 60;
    const miniW = 200;
    const miniH = 55;
    
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.fillRect(miniX, miniY, miniW, miniH);
    ctx.strokeStyle = '#334155'; ctx.strokeRect(miniX, miniY, miniW, miniH);
    
    ctx.fillStyle = '#1e3a5f';
    ctx.fillRect(miniX + 5, miniY + 10, miniW/2 - 5, miniH - 20);
    ctx.fillRect(miniX + miniW/2 + 2, miniY + 10, miniW/2 - 7, miniH - 20);
    
    const miniDep = 15;
    ctx.fillStyle = '#475569';
    ctx.fillRect(miniX + miniW/2 - miniDep/2, miniY + 10, miniDep, miniH - 20);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('P', miniX + miniW/4, miniY + miniH/2 + 3);
    ctx.fillText('N', miniX + miniW*3/4, miniY + miniH/2 + 3);
    ctx.fillText('Junction Detail', miniX + miniW/2, miniY + miniH - 2);
  }
  
  function drawHalfWaveCircuit(ctx: CanvasRenderingContext2D, x: number, y: number, h: number, t: number, vInstant: number) {
    const w = 280;
    const cx = x + w/2;
    const cy = y + h/2;
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    
    ctx.beginPath();
    ctx.moveTo(x + 20, cy - 40);
    ctx.lineTo(x + 20, cy - 20);
    ctx.stroke();
    ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(x + 20, cy, 18, 0, Math.PI*2); ctx.stroke();
    ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('~', x + 20, cy + 3);
    ctx.fillText(`${params.Vin}V`, x + 20, cy + 28);
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x + 20, cy + 18);
    ctx.lineTo(x + 20, cy + 40);
    ctx.stroke();
    
    ctx.beginPath();
    ctx.moveTo(x + 20, cy - 40);
    ctx.lineTo(cx - 30, cy - 40);
    ctx.stroke();
    
    ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx - 30, cy - 55);
    ctx.lineTo(cx - 30, cy - 25);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx - 45, cy - 40);
    ctx.lineTo(cx - 15, cy - 40);
    ctx.lineTo(cx - 30, cy - 55);
    ctx.closePath();
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx - 35, cy - 55); ctx.lineTo(cx - 25, cy - 55);
    ctx.stroke();
    
    ctx.fillStyle = '#fbbf24'; ctx.font = '9px sans-serif';
    ctx.fillText('D1', cx - 30, cy - 62);
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx - 30, cy - 25);
    ctx.lineTo(cx - 30, cy + 10);
    ctx.lineTo(cx + 40, cy + 10);
    ctx.stroke();
    
    ctx.strokeStyle = '#f87171'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx + 40, cy + 10);
    for (let i = 0; i < 5; i++) {
      ctx.lineTo(cx + 45 + i*12, cy + 2);
      ctx.lineTo(cx + 50 + i*12, cy + 18);
    }
    ctx.lineTo(cx + 105, cy + 10);
    ctx.stroke();
    
    ctx.fillStyle = '#f87171'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(`Rload`, cx + 72, cy + 28);
    ctx.fillText(`${params.Rload}Ω`, cx + 72, cy + 40);
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx + 105, cy + 10);
    ctx.lineTo(cx + 105, cy + 40);
    ctx.lineTo(x + 20, cy + 40);
    ctx.stroke();
    
    if (vInstant > 0.7) {
      ctx.fillStyle = '#fbbf24';
      const progress = (t * 1.5) % 1;
      const tx = x + 20 + (cx - 50 - x - 20) * progress;
      ctx.beginPath(); ctx.arc(tx, cy - 40, 3, 0, Math.PI*2); ctx.fill();
      const dx = cx - 30;
      const dy = cy - 40 + 15 * progress;
      ctx.beginPath(); ctx.arc(dx, dy, 3, 0, Math.PI*2); ctx.fill();
      const lx = cx + 40 + 65 * progress;
      ctx.beginPath(); ctx.arc(lx, cy + 10, 3, 0, Math.PI*2); ctx.fill();
      const rx = cx + 105 - (cx + 85 - x - 20) * progress;
      ctx.beginPath(); ctx.arc(rx, cy + 40, 3, 0, Math.PI*2); ctx.fill();
    }
    
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x + 20, cy + 40); ctx.lineTo(x + 20, cy + 55); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 8, cy + 55); ctx.lineTo(x + 32, cy + 55); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 12, cy + 60); ctx.lineTo(x + 28, cy + 60); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 16, cy + 65); ctx.lineTo(x + 24, cy + 65); ctx.stroke();
  }
  
  function drawFullWaveCircuit(ctx: CanvasRenderingContext2D, x: number, y: number, h: number, t: number, vInstant: number) {
    const w = 320;
    const cx = x + w/2;
    const cy = y + h/2;
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    
    ctx.beginPath();
    ctx.moveTo(x + 20, cy - 50);
    ctx.lineTo(x + 20, cy - 30);
    ctx.stroke();
    ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(x + 20, cy - 10, 18, 0, Math.PI*2); ctx.stroke();
    ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('~', x + 20, cy - 7);
    ctx.fillText(`${params.Vin}V`, x + 20, cy + 18);
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x + 20, cy + 8);
    ctx.lineTo(x + 20, cy + 50);
    ctx.stroke();
    
    const bridgeLeft = cx - 50;
    const bridgeRight = cx + 50;
    const bridgeTop = cy - 35;
    const bridgeBot = cy + 35;
    
    ctx.beginPath();
    ctx.moveTo(x + 20, cy - 50);
    ctx.lineTo(bridgeLeft, cy - 50);
    ctx.lineTo(bridgeLeft, bridgeTop);
    ctx.stroke();
    
    ctx.beginPath();
    ctx.moveTo(x + 20, cy + 50);
    ctx.lineTo(bridgeLeft, cy + 50);
    ctx.lineTo(bridgeLeft, bridgeBot);
    ctx.stroke();
    
    ctx.beginPath();
    ctx.moveTo(bridgeRight, bridgeTop);
    ctx.lineTo(bridgeRight + 40, bridgeTop);
    ctx.stroke();
    
    ctx.beginPath();
    ctx.moveTo(bridgeRight, bridgeBot);
    ctx.lineTo(bridgeRight + 40, bridgeBot);
    ctx.stroke();
    
    ctx.strokeStyle = '#f87171'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(bridgeRight + 40, bridgeTop + 10);
    for (let i = 0; i < 5; i++) {
      ctx.lineTo(bridgeRight + 32 + i*4, bridgeTop + 18 + i*10);
      ctx.lineTo(bridgeRight + 48 + i*4, bridgeTop + 22 + i*10);
    }
    ctx.lineTo(bridgeRight + 40, bridgeBot - 10);
    ctx.stroke();
    
    ctx.fillStyle = '#f87171'; ctx.font = '9px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(`Rload`, bridgeRight + 55, cy);
    ctx.fillText(`${params.Rload}Ω`, bridgeRight + 55, cy + 12);
    
    const diodePositions = [
      { x: bridgeLeft, y: bridgeTop, rot: 0, label: 'D1' },
      { x: bridgeRight, y: bridgeTop, rot: Math.PI, label: 'D2' },
      { x: bridgeLeft, y: bridgeBot, rot: Math.PI, label: 'D3' },
      { x: bridgeRight, y: bridgeBot, rot: 0, label: 'D4' },
    ];
    
    diodePositions.forEach(d => {
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.rotate(d.rot);
      ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, -12); ctx.lineTo(0, 12);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(-12, 0); ctx.lineTo(12, 0); ctx.lineTo(0, -12); ctx.closePath();
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(-8, -12); ctx.lineTo(8, -12);
      ctx.stroke();
      ctx.fillStyle = '#fbbf24'; ctx.font = '8px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(d.label, 0, -16);
      ctx.restore();
    });
    
    const absV = Math.abs(vInstant);
    if (absV > 0.7) {
      ctx.fillStyle = '#fbbf24';
      const progress = (t * 1.5) % 1;
      
      if (vInstant > 0) {
        const p1 = x + 20 + (bridgeLeft - x - 20) * progress;
        ctx.beginPath(); ctx.arc(p1, cy - 50, 3, 0, Math.PI*2); ctx.fill();
        const p2 = bridgeLeft + (bridgeRight - bridgeLeft) * progress;
        ctx.beginPath(); ctx.arc(p2, bridgeTop, 3, 0, Math.PI*2); ctx.fill();
        const p3 = bridgeRight + 40;
        const p3y = bridgeTop + (bridgeBot - bridgeTop) * progress;
        ctx.beginPath(); ctx.arc(p3, p3y, 3, 0, Math.PI*2); ctx.fill();
        const p4 = bridgeRight - (bridgeRight - bridgeLeft) * progress;
        ctx.beginPath(); ctx.arc(p4, bridgeBot, 3, 0, Math.PI*2); ctx.fill();
      } else {
        const p1 = x + 20 + (bridgeLeft - x - 20) * progress;
        ctx.beginPath(); ctx.arc(p1, cy + 50, 3, 0, Math.PI*2); ctx.fill();
        const p2 = bridgeLeft + (bridgeRight - bridgeLeft) * progress;
        ctx.beginPath(); ctx.arc(p2, bridgeBot, 3, 0, Math.PI*2); ctx.fill();
        const p3 = bridgeRight + 40;
        const p3y = bridgeBot - (bridgeBot - bridgeTop) * progress;
        ctx.beginPath(); ctx.arc(p3, p3y, 3, 0, Math.PI*2); ctx.fill();
        const p4 = bridgeRight - (bridgeRight - bridgeLeft) * progress;
        ctx.beginPath(); ctx.arc(p4, bridgeTop, 3, 0, Math.PI*2); ctx.fill();
      }
    }
    
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x + 20, cy + 50); ctx.lineTo(x + 20, cy + 68); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 8, cy + 68); ctx.lineTo(x + 32, cy + 68); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 12, cy + 73); ctx.lineTo(x + 28, cy + 73); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 16, cy + 78); ctx.lineTo(x + 24, cy + 78); ctx.stroke();
  }
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    const animate = (timestamp: number) => {
      timeRef.current = timestamp / 1000;
      draw(ctx, timeRef.current);
      animRef.current = requestAnimationFrame(animate);
    };
    
    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [draw]);
  
  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="w-full h-auto rounded-lg border border-slate-700"
    />
  );
}