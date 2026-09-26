// src/components/simulation/BjtCanvas.tsx
'use client';

import React, { useRef, useEffect, useCallback } from 'react';
import { computeBjtState, BjtParams, BjtState, REGION_COLORS } from '@/lib/physics/bjtTransistor';

interface BjtCanvasProps {
  params: BjtParams;
  width?: number;
  height?: number;
}

export default function BjtCanvas({ params, width = 900, height = 640 }: BjtCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number>(0);
  const timeRef = useRef<number>(0);
  
  const state = computeBjtState(params);
  
  const draw = useCallback((ctx: CanvasRenderingContext2D, t: number) => {
    const W = ctx.canvas.width;
    const H = ctx.canvas.height;
    const { Vbe, Vce, temperature, material, beta, topology, Vcc, Rb, Rc, Re, Rload } = params;
    const { region, Ib, Ic, Ie, Vb, Ve, Vc, Av, Ai, Ap, Zin, Zout, Pdiss, Ic_sat, Vce_cutoff } = state;
    
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, W, H);
    
    const margin = 45;
    
    drawCircuitSchematic(ctx, margin, 55, 420, 320, params, state, t);
    drawTransistorCrossSection(ctx, W - margin - 280, 55, 280, 180, params, state, t);
    drawOutputCharacteristics(ctx, W - margin - 280, 255, 280, 180, params, state);
    drawCircuitAnalysis(ctx, margin, 395, 420, 140, params, state);
    drawCurrentFlow(ctx, margin, 550, W - margin*2, 50, params, state, t);
    
    ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
    ctx.fillRect(margin, H - 42, W - margin*2, 34);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(margin, H - 42, W - margin*2, 34);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    ctx.fillText(`Vbe=${Vbe.toFixed(2)}V  Vce=${Vce.toFixed(2)}V  Vb=${Vb.toFixed(2)}V  Ve=${Ve.toFixed(2)}V  Vc=${Vc.toFixed(2)}V`, margin + 10, H - 22);
    ctx.fillStyle = region === 'active' ? '#4ade80' : region === 'saturation' ? '#f87171' : '#94a3b8';
    ctx.fillText(region.toUpperCase(), W - margin - 80, H - 22);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 15px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(`${material} NPN BJT — ${topology.replace(/-/g, ' ').toUpperCase()} @ ${temperature}K`, W/2, 22);
    
  }, [params, state]);
  
  function drawCircuitSchematic(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, params: BjtParams, state: BjtState, t: number) {
    const { topology, Vcc, Rb, Rc, Re, Rload } = params;
    const { Ib, Ic, Ie } = state;
    const cx = x + w/2;
    const cy = y + h/2;
    
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    
    if (topology === 'common-emitter') {
      ctx.beginPath(); ctx.moveTo(x + 30, y + 20); ctx.lineTo(x + w - 30, y + 20); ctx.stroke();
      ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText(`+Vcc = ${Vcc}V`, x + 35, y + 16);
      
      ctx.beginPath(); ctx.moveTo(cx + 40, y + 20); ctx.lineTo(cx + 40, cy - 45); ctx.stroke();
      drawResistor(ctx, cx + 40, cy - 45, 'vertical', Rc, 'Rc');
      ctx.beginPath(); ctx.moveTo(cx + 40, cy - 25); ctx.lineTo(cx + 40, cy - 10); ctx.stroke();
      
      drawNpnSymbol(ctx, cx, cy, 50);
      
      ctx.beginPath(); ctx.moveTo(cx - 35, cy); ctx.lineTo(cx - 80, cy); ctx.stroke();
      drawResistor(ctx, cx - 80, cy, 'horizontal', Rb, 'Rb');
      ctx.beginPath(); ctx.moveTo(cx - 100, cy); ctx.lineTo(cx - 120, cy); ctx.stroke();
      ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(cx - 135, cy, 12, 0, Math.PI*2); ctx.stroke();
      ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('~', cx - 135, cy + 3);
      ctx.fillText('Vin', cx - 135, cy + 28);
      
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - 135, cy + 12); ctx.lineTo(cx - 135, cy + 35); ctx.stroke();
      drawGround(ctx, cx - 135, cy + 35);
      
      ctx.beginPath(); ctx.moveTo(cx, cy + 50); ctx.lineTo(cx, cy + 80); ctx.stroke();
      if (Re > 0.1) {
        drawResistor(ctx, cx, cy + 80, 'vertical', Re, 'Re');
        ctx.beginPath(); ctx.moveTo(cx, cy + 100); ctx.lineTo(cx, cy + 115); ctx.stroke();
      }
      drawGround(ctx, cx, cy + 115);
      
      ctx.fillStyle = '#4ade80'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText('Vout', cx + 48, cy - 30);
      
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(cx + 40, cy - 10); ctx.lineTo(cx + 100, cy - 10); ctx.stroke();
      drawResistor(ctx, cx + 100, cy - 10, 'horizontal', Rload, 'Rload');
      ctx.beginPath(); ctx.moveTo(cx + 120, cy - 10); ctx.lineTo(cx + 140, cy - 10); ctx.stroke();
      drawGround(ctx, cx + 140, cy - 10);
      
      if (Ic > 0.01) {
        ctx.fillStyle = '#fbbf24';
        const progress = (t * Ic * 0.3) % 1;
        const cy_flow = y + 20 + progress * (cy + 50 - y - 20);
        ctx.beginPath(); ctx.arc(cx + 40, cy_flow, 3, 0, Math.PI*2); ctx.fill();
      }
      if (Ib > 0.1) {
        ctx.fillStyle = '#f87171';
        const progress = (t * Ib * 0.01) % 1;
        const bx_flow = cx - 120 + progress * 85;
        ctx.beginPath(); ctx.arc(bx_flow, cy, 2.5, 0, Math.PI*2); ctx.fill();
      }
      if (Ie > 0.01) {
        ctx.fillStyle = '#60a5fa';
        const progress = (t * Ie * 0.3) % 1;
        const ey_flow = cy + 50 + progress * 65;
        ctx.beginPath(); ctx.arc(cx, ey_flow, 3, 0, Math.PI*2); ctx.fill();
      }
      
    } else if (topology === 'common-collector') {
      ctx.beginPath(); ctx.moveTo(cx, y + 20); ctx.lineTo(cx, cy - 55); ctx.stroke();
      ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(`+Vcc = ${Vcc}V`, cx, y + 16);
      
      drawNpnSymbol(ctx, cx, cy, 50);
      
      ctx.beginPath(); ctx.moveTo(cx - 35, cy); ctx.lineTo(cx - 80, cy); ctx.stroke();
      drawResistor(ctx, cx - 80, cy, 'horizontal', Rb, 'Rb');
      ctx.beginPath(); ctx.moveTo(cx - 100, cy); ctx.lineTo(cx - 120, cy); ctx.stroke();
      ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(cx - 135, cy, 12, 0, Math.PI*2); ctx.stroke();
      ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('~', cx - 135, cy + 3);
      ctx.fillText('Vin', cx - 135, cy + 28);
      
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - 135, cy + 12); ctx.lineTo(cx - 135, cy + 35); ctx.stroke();
      drawGround(ctx, cx - 135, cy + 35);
      
      ctx.beginPath(); ctx.moveTo(cx, cy + 50); ctx.lineTo(cx, cy + 75); ctx.stroke();
      drawResistor(ctx, cx, cy + 75, 'vertical', Re, 'Re');
      ctx.beginPath(); ctx.moveTo(cx, cy + 95); ctx.lineTo(cx, cy + 110); ctx.stroke();
      
      ctx.beginPath(); ctx.moveTo(cx + 30, cy + 85); ctx.lineTo(cx + 70, cy + 85); ctx.stroke();
      drawResistor(ctx, cx + 70, cy + 85, 'horizontal', Rload, 'Rload');
      ctx.beginPath(); ctx.moveTo(cx + 90, cy + 85); ctx.lineTo(cx + 110, cy + 85); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx + 110, cy + 85); ctx.lineTo(cx + 110, cy + 110); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx, cy + 110); ctx.lineTo(cx + 110, cy + 110); ctx.stroke();
      drawGround(ctx, cx + 55, cy + 110);
      
      ctx.fillStyle = '#4ade80'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText('Vout', cx + 5, cy + 80);
      
      if (Ie > 0.01) {
        ctx.fillStyle = '#fbbf24';
        const progress = (t * Ie * 0.3) % 1;
        const ey = cy + 50 + progress * 60;
        ctx.beginPath(); ctx.arc(cx, ey, 3, 0, Math.PI*2); ctx.fill();
      }
      
    } else if (topology === 'common-base') {
      ctx.beginPath(); ctx.moveTo(cx + 30, y + 20); ctx.lineTo(cx + 30, cy - 55); ctx.stroke();
      ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText(`+Vcc = ${Vcc}V`, x + 35, y + 16);
      drawResistor(ctx, cx + 30, cy - 55, 'vertical', Rc, 'Rc');
      ctx.beginPath(); ctx.moveTo(cx + 30, cy - 35); ctx.lineTo(cx + 30, cy - 10); ctx.stroke();
      
      drawNpnSymbol(ctx, cx, cy, 50);
      
      ctx.beginPath(); ctx.moveTo(cx - 35, cy); ctx.lineTo(cx - 80, cy); ctx.stroke();
      drawGround(ctx, cx - 80, cy);
      
      ctx.beginPath(); ctx.moveTo(cx, cy + 50); ctx.lineTo(cx, cy + 80); ctx.stroke();
      drawResistor(ctx, cx, cy + 80, 'vertical', Re, 'Re');
      ctx.beginPath(); ctx.moveTo(cx, cy + 100); ctx.lineTo(cx, cy + 115); ctx.stroke();
      ctx.strokeStyle = '#60a5fa'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(cx, cy + 130, 12, 0, Math.PI*2); ctx.stroke();
      ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('~', cx, cy + 133);
      ctx.fillText('Vin', cx, cy + 155);
      drawGround(ctx, cx, cy + 155);
      
      ctx.fillStyle = '#4ade80'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText('Vout', cx + 38, cy - 30);
      
      if (Ic > 0.01) {
        ctx.fillStyle = '#fbbf24';
        const progress = (t * Ic * 0.3) % 1;
        const dy = y + 20 + progress * (cy - 30 - y - 20);
        ctx.beginPath(); ctx.arc(cx + 30, dy, 3, 0, Math.PI*2); ctx.fill();
      }
    }
  }
  
  function drawNpnSymbol(ctx: CanvasRenderingContext2D, cx: number, cy: number, size: number) {
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.moveTo(cx - 25, cy - 30); ctx.lineTo(cx - 25, cy + 30); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx - 25, cy - 20); ctx.lineTo(cx + 15, cy - 40); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx - 25, cy + 20); ctx.lineTo(cx + 15, cy + 40); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx + 8, cy + 32); ctx.lineTo(cx + 15, cy + 40); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx + 15, cy + 40); ctx.lineTo(cx + 5, cy + 38); ctx.stroke();
    ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(cx, cy, size/2 + 5, 0, Math.PI*2); ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('C', cx + 22, cy - 42);
    ctx.fillText('B', cx - 38, cy);
    ctx.fillText('E', cx + 22, cy + 48);
  }
  
  function drawResistor(ctx: CanvasRenderingContext2D, x: number, y: number, orientation: 'horizontal' | 'vertical', value: number, label: string) {
    ctx.strokeStyle = '#f87171'; ctx.lineWidth = 2;
    const seg = 8;
    if (orientation === 'vertical') {
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + 5); ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x, y + 5);
      for (let i = 0; i < 4; i++) {
        ctx.lineTo(x - 5, y + 10 + i*seg);
        ctx.lineTo(x + 5, y + 14 + i*seg);
      }
      ctx.lineTo(x, y + 42);
      ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x, y + 42); ctx.lineTo(x, y + 47); ctx.stroke();
      ctx.fillStyle = '#f87171'; ctx.font = '9px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText(`${label}=${value}k`, x + 8, y + 28);
    } else {
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 5, y); ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x + 5, y);
      for (let i = 0; i < 4; i++) {
        ctx.lineTo(x + 10 + i*seg, y - 5);
        ctx.lineTo(x + 14 + i*seg, y + 5);
      }
      ctx.lineTo(x + 42, y);
      ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x + 42, y); ctx.lineTo(x + 47, y); ctx.stroke();
      ctx.fillStyle = '#f87171'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(`${label}=${value}k`, x + 26, y - 10);
    }
  }
  
  function drawGround(ctx: CanvasRenderingContext2D, x: number, y: number) {
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + 10); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x - 10, y + 10); ctx.lineTo(x + 10, y + 10); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x - 7, y + 14); ctx.lineTo(x + 7, y + 14); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x - 4, y + 18); ctx.lineTo(x + 4, y + 18); ctx.stroke();
  }
  
  function drawTransistorCrossSection(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, params: BjtParams, state: BjtState, t: number) {
    const { Vbe, Vce, beta } = params;
    const { region, Ib, Ic, Ie } = state;
    const cx = x + w/2;
    const devW = w - 20;
    const devH = h - 40;
    const devX = x + 10;
    const devY = y + 20;
    
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(devX, devY, devW, devH);
    
    ctx.fillStyle = '#1d4ed8';
    ctx.fillRect(devX + 10, devY + 10, 50, devH - 20);
    
    ctx.fillStyle = '#be185d';
    ctx.fillRect(devX + 60, devY + 25, 30, devH - 50);
    
    ctx.fillStyle = '#1d4ed8';
    ctx.fillRect(devX + 90, devY + 10, 60, devH - 20);
    
    ctx.strokeStyle = '#94a3b8'; ctx.setLineDash([3, 3]); ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(devX + 60, devY + 10); ctx.lineTo(devX + 60, devY + devH - 10); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(devX + 90, devY + 10); ctx.lineTo(devX + 90, devY + devH - 10); ctx.stroke();
    ctx.setLineDash([]);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('E', devX + 35, devY + devH/2);
    ctx.fillText('B', devX + 75, devY + devH/2);
    ctx.fillText('C', devX + 120, devY + devH/2);
    
    if (region !== 'cutoff') {
      const elecCount = Math.min(20, Math.floor(Ic * 3));
      for (let i = 0; i < elecCount; i++) {
        const progress = ((t * 0.8 + i * 0.12) % 1);
        let ex, ey;
        if (progress < 0.3) {
          ex = devX + 15 + progress/0.3 * 45;
          ey = devY + 15 + (i % 4) * (devH - 30)/4;
        } else if (progress < 0.6) {
          ex = devX + 60 + (progress - 0.3)/0.3 * 30;
          ey = devY + 15 + (i % 4) * (devH - 30)/4 + Math.sin((progress - 0.3)/0.3 * Math.PI) * 5;
        } else {
          ex = devX + 90 + (progress - 0.6)/0.4 * 55;
          ey = devY + 15 + (i % 4) * (devH - 30)/4;
        }
        ctx.fillStyle = '#60a5fa';
        ctx.beginPath(); ctx.arc(ex, ey, 2.5, 0, Math.PI*2); ctx.fill();
      }
      
      if (Ib > 0.1) {
        for (let i = 0; i < 3; i++) {
          const flicker = Math.sin(t * 4 + i * 2) > 0.6;
          if (flicker) {
            ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 1.2;
            const rx = devX + 65 + i * 8;
            const ry = devY + 30 + (i % 2) * 20;
            ctx.beginPath();
            ctx.moveTo(rx - 3, ry - 3); ctx.lineTo(rx + 3, ry + 3);
            ctx.moveTo(rx + 3, ry - 3); ctx.lineTo(rx - 3, ry + 3);
            ctx.stroke();
          }
        }
      }
    }
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Device Cross-Section', cx, y + 12);
  }
  
  function drawOutputCharacteristics(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, params: BjtParams, state: BjtState) {
    const { Vcc, Rc, Re, beta, Vce } = params;
    const { Ic, Ic_sat, Vce_cutoff } = state;
    const Ib_values = [10, 20, 40, 80, 160];
    
    ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Output Characteristics (Ic vs Vce)', x + w/2, y + 14);
    
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x + 28, y + h - 22);
    ctx.lineTo(x + w - 5, y + h - 22);
    ctx.moveTo(x + 28, y + h - 22);
    ctx.lineTo(x + 28, y + 5);
    ctx.stroke();
    
    ctx.fillStyle = '#64748b'; ctx.font = '8px sans-serif';
    ctx.fillText('Vce (V)', x + w - 28, y + h - 8);
    ctx.save(); ctx.translate(x + 10, y + h/2); ctx.rotate(-Math.PI/2);
    ctx.fillText('Ic (mA)', 0, 0); ctx.restore();
    
    Ib_values.forEach((ibVal, idx) => {
      ctx.strokeStyle = `hsl(${200 + idx * 28}, 70%, 58%)`;
      ctx.lineWidth = 1.3;
      ctx.beginPath();
      for (let px = 0; px < w - 38; px++) {
        const vce = (px / (w - 38)) * Vcc;
        let ic = 0;
        if (vce < 0.2) {
          ic = (beta * ibVal / 1000) * (vce / 0.2);
        } else {
          ic = beta * ibVal / 1000;
        }
        const plotY = (y + h - 22) - (ic / (Vcc/(Rc+Re) * 1.2)) * (h - 32);
        if (px === 0) ctx.moveTo(x + 28 + px, plotY);
        else ctx.lineTo(x + 28 + px, plotY);
      }
      ctx.stroke();
    });
    
    ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 2; ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(x + 28, y + h - 22 - (Ic_sat / (Vcc/(Rc+Re) * 1.2)) * (h - 32));
    ctx.lineTo(x + 28 + ((Vce_cutoff/Vcc) * (w - 38)), y + h - 22);
    ctx.stroke();
    ctx.setLineDash([]);
    
    const opX = x + 28 + (Vce / Vcc) * (w - 38);
    const opY = (y + h - 22) - (Ic / (Vcc/(Rc+Re) * 1.2)) * (h - 32);
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(opX, opY, 4.5, 0, Math.PI*2); ctx.fill();
    ctx.strokeStyle = '#fbbf24'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(opX, opY, 7, 0, Math.PI*2); ctx.stroke();
    
    ctx.fillStyle = '#fbbf24'; ctx.font = '8px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText('Q-point', opX + 8, opY - 4);
    ctx.fillText(`(${Vce.toFixed(1)}V, ${Ic.toFixed(2)}mA)`, opX + 8, opY + 8);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '8px sans-serif';
    ctx.fillText('Load Line', x + 32, y + 22);
  }
  
  function drawCircuitAnalysis(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, params: BjtParams, state: BjtState) {
    const { topology } = params;
    const { Av, Ai, Ap, Zin, Zout, Pdiss } = state;
    
    ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Circuit Analysis', x + w/2, y + 16);
    
    ctx.fillStyle = '#e2e8f0'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    const col1 = x + 12;
    const col2 = x + w/2 + 5;
    const rowH = 22;
    let row = y + 32;
    
    ctx.fillText(`Voltage Gain (Av): ${Math.abs(Av).toFixed(1)} V/V`, col1, row);
    ctx.fillText(`Current Gain (Ai): ${Math.abs(Ai).toFixed(1)} A/A`, col2, row);
    row += rowH;
    ctx.fillText(`Power Gain (Ap): ${Ap.toFixed(1)} dB`, col1, row);
    ctx.fillText(`Power Diss: ${Pdiss.toFixed(1)} mW`, col2, row);
    row += rowH;
    ctx.fillText(`Input Z (Zin): ${Zin.toFixed(2)} kΩ`, col1, row);
    ctx.fillText(`Output Z (Zout): ${Zout.toFixed(2)} kΩ`, col2, row);
    row += rowH;
    ctx.fillText(`Phase Shift: ${topology === 'common-emitter' ? '180° (inverted)' : '0° (non-inverted)'}`, col1, row);
    
    ctx.fillStyle = '#4ade80'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(`${topology.replace(/-/g, ' ').toUpperCase()} CONFIGURATION`, x + w/2, y + h - 8);
  }
  
  function drawCurrentFlow(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, params: BjtParams, state: BjtState, t: number) {
    const { Ib, Ic, Ie } = state;
    
    ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Current Flow Summary', x + w/2, y + 14);
    
    const pathW = w / 3;
    
    ctx.fillStyle = '#f87171'; ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('BASE CURRENT (Ib)', x + pathW/2, y + 30);
    ctx.fillStyle = '#f87171'; ctx.font = '10px sans-serif';
    ctx.fillText(`${Ib.toFixed(1)} μA`, x + pathW/2, y + 44);
    ctx.fillStyle = '#f87171';
    const ibDots = Math.min(6, Math.max(0, Math.floor(Ib / 20)));
    for (let i = 0; i < ibDots; i++) {
      const progress = ((t * 0.5 + i / Math.max(ibDots, 1)) % 1);
      ctx.beginPath(); ctx.arc(x + pathW/2 - 30 + progress * 60, y + 32, 3, 0, Math.PI*2); ctx.fill();
    }
    
    ctx.fillStyle = '#60a5fa'; ctx.font = 'bold 11px sans-serif';
    ctx.fillText('COLLECTOR CURRENT (Ic)', x + pathW + pathW/2, y + 30);
    ctx.fillStyle = '#60a5fa'; ctx.font = '10px sans-serif';
    ctx.fillText(`${Ic.toFixed(2)} mA`, x + pathW + pathW/2, y + 44);
    ctx.fillStyle = '#60a5fa';
    const icDots = Math.min(10, Math.max(0, Math.floor(Ic * 2)));
    for (let i = 0; i < icDots; i++) {
      const progress = ((t * 1.0 + i / Math.max(icDots, 1)) % 1);
      ctx.beginPath(); ctx.arc(x + pathW + pathW/2 - 40 + progress * 80, y + 32, 3, 0, Math.PI*2); ctx.fill();
    }
    
    ctx.fillStyle = '#fbbf24'; ctx.font = 'bold 11px sans-serif';
    ctx.fillText('EMITTER CURRENT (Ie)', x + 2*pathW + pathW/2, y + 30);
    ctx.fillStyle = '#fbbf24'; ctx.font = '10px sans-serif';
    ctx.fillText(`${Ie.toFixed(2)} mA`, x + 2*pathW + pathW/2, y + 44);
    ctx.fillStyle = '#fbbf24';
    const ieDots = Math.min(10, Math.max(0, Math.floor(Ie * 2)));
    for (let i = 0; i < ieDots; i++) {
      const progress = ((t * 1.0 + i / Math.max(ieDots, 1)) % 1);
      ctx.beginPath(); ctx.arc(x + 2*pathW + pathW/2 - 40 + progress * 80, y + 32, 3, 0, Math.PI*2); ctx.fill();
    }
    
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('KCL: Ie = Ib + Ic  (emitter current = base current + collector current)', x + w/2, y + h - 6);
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