#!/bin/bash
# A-Factor STEM Studio — MOSFET build fixes
# Run inside af2s/ folder: bash patch-v59-mosfet-bugfix.sh
#
# Fixes two pre-existing bugs that were breaking `npm run build` entirely
# (found while build-verifying the PHY 403 minitab patch, unrelated to it):
#
#   1. src/app/embed/mosfet/page.tsx imported MosfetCanvas as a default
#      export, but it's a named export — and it was missing the required
#      activeTab/isRunning/isPaused/showElectrons props while passing
#      width/height, which MosfetCanvas doesn't accept at all (it sizes
#      itself from its wrapping element, unlike your other Canvas components).
#
#   2. src/components/simulation/MosfetCanvas.tsx line 637 referenced
#      `p.speed`, a field that doesn't exist on MosfetParams. Fixed by
#      using the raw frame delta directly (dt), matching how every other
#      Canvas component in the app already handles timing.
#
# Verified with a full `npm run build` against your actual project before
# delivery — the whole app (all previously-existing routes) now builds
# clean, including /simulations/mosfet and /embed/mosfet.

set -e
echo "Applying MOSFET build fixes..."

echo "  fixing src/app/embed/mosfet/page.tsx"
cat > src/app/embed/mosfet/page.tsx << 'FILEEOF'
// src/app/embed/mosfet/page.tsx
'use client';

import React, { useState } from 'react';
import { MosfetCanvas } from '@/components/simulation/MosfetCanvas';
import { MosfetParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/mosfet';

export default function MosfetEmbedPage() {
  const [params, setParams] = useState<MosfetParams>(getPreset('cutoff'));
  const [activePreset, setActivePreset] = useState('cutoff');

  const applyPreset = (name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4">
      <div className="max-w-5xl mx-auto">
        <MosfetCanvas
          params={params}
          activeTab="schematic"
          isRunning={true}
          isPaused={false}
          showElectrons={true}
        />

        <div className="mt-4 flex flex-wrap gap-2">
          {PRESET_NAMES.map(name => (
            <button
              key={name}
              onClick={() => applyPreset(name)}
              className={`px-3 py-1.5 rounded text-xs font-medium transition-colors ${
                activePreset === name
                  ? 'bg-blue-600 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              {PRESET_LABELS[name]}
            </button>
          ))}

        </div>
      </div>
    </div>
  );
}
FILEEOF

echo "  fixing src/components/simulation/MosfetCanvas.tsx"
cat > src/components/simulation/MosfetCanvas.tsx << 'FILEEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  MosfetParams, MosfetTopology, MosfetRegion,
  computeMosfetState,
  getOutputCurve, getLoadLine,
  REGION_COLORS,
} from '@/lib/physics/mosfet';

interface Props {
  params: MosfetParams;
  activeTab: 'schematic' | 'cross-section' | 'characteristics' | 'analysis';
  isRunning: boolean;
  isPaused: boolean;
  showElectrons: boolean;
  onTick?: (stats: {
    region: MosfetRegion;
    Id: number;
    Vgs: number;
    Vds: number;
    Vov: number;
    gm: number;
    Av: number;
    Zin: number;
    Zout: number;
    Pdiss: number;
  }) => void;
}

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
}

export function MosfetCanvas({ params, activeTab, isRunning, isPaused, showElectrons, onTick }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, activeTab, isRunning, isPaused, showElectrons, onTick });
  propsRef.current = { params, activeTab, isRunning, isPaused, showElectrons, onTick };

  const particlesRef = useRef<Particle[]>([]);

  const getFont = () => 'var(--kimi-font-sans, system-ui, sans-serif)';

  const resize = useCallback(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = wrap.getBoundingClientRect();
    const w = Math.floor(rect.width);
    const h = Math.floor(rect.height);
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr;
      canvas.height = h * dpr;
    }
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    const ctx = canvas.getContext('2d');
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }, []);

  const drawInfoBox = useCallback((ctx: CanvasRenderingContext2D, w: number, h: number, lines: string[]) => {
    const bw = Math.min(300, w * 0.42);
    const bh = lines.length * 17 + 18;
    const bx = w - bw - 12;
    const by = h - bh - 12;
    ctx.fillStyle = 'rgba(15,23,42,0.65)';
    ctx.fillRect(bx, by, bw, bh);
    ctx.strokeStyle = 'rgba(148,163,184,0.18)';
    ctx.strokeRect(bx, by, bw, bh);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '12px ' + getFont();
    ctx.textAlign = 'left';
    lines.forEach((line, i) => ctx.fillText(line, bx + 10, by + 18 + i * 17));
  }, []);

  const drawResistor = useCallback((ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number) => {
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 2;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    const nx = dx / len;
    const ny = dy / len;
    const px = -ny;
    const py = nx;
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    const segments = 6;
    const segLen = len / segments;
    for (let i = 0; i < segments; i++) {
      const t = i / segments;
      const bx = x1 + nx * len * t;
      const by = y1 + ny * len * t;
      const zig = (i % 2 === 0 ? 1 : -1) * 6;
      ctx.lineTo(bx + nx * segLen * 0.5 + px * zig, by + ny * segLen * 0.5 + py * zig);
    }
    ctx.lineTo(x2, y2);
    ctx.stroke();
  }, []);

  const drawSchematic = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: MosfetParams, state: ReturnType<typeof computeMosfetState>) => {
    const isNmos = p.type === 'nmos';
    const scale = Math.min(w, h) / 500;

    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(scale, scale);

    // Ground
    ctx.strokeStyle = '#64748b';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-150, 200);
    ctx.lineTo(150, 200);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, 200);
    ctx.lineTo(0, 220);
    ctx.stroke();
    for (let i = 0; i < 3; i++) {
      const y = 225 + i * 8;
      const len = 30 - i * 8;
      ctx.beginPath();
      ctx.moveTo(-len / 2, y);
      ctx.lineTo(len / 2, y);
      ctx.stroke();
    }

    // Vdd rail
    ctx.strokeStyle = '#ef4444';
    ctx.beginPath();
    ctx.moveTo(-150, -200);
    ctx.lineTo(150, -200);
    ctx.stroke();
    ctx.fillStyle = '#ef4444';
    ctx.font = '14px ' + getFont();
    ctx.fillText(`Vdd = ${p.Vdd}V`, 160, -195);

    const mx = 0, my = 0;

    // Body / substrate
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(mx, my - 60);
    ctx.lineTo(mx, my + 60);
    ctx.stroke();

    // Gate line
    ctx.beginPath();
    ctx.moveTo(mx - 40, my - 30);
    ctx.lineTo(mx - 40, my + 30);
    ctx.stroke();

    // Gate connection
    ctx.beginPath();
    ctx.moveTo(mx - 80, my);
    ctx.lineTo(mx - 40, my);
    ctx.stroke();

    // Gate oxide
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(mx - 35, my - 30);
    ctx.lineTo(mx - 35, my + 30);
    ctx.stroke();

    // Source
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(mx - 35, my + 30);
    ctx.lineTo(mx, my + 30);
    ctx.stroke();

    // Source arrow
    ctx.beginPath();
    ctx.moveTo(mx - 18, my + 30);
    ctx.lineTo(mx - 18, my + 45);
    ctx.lineTo(mx - 12, my + 38);
    ctx.lineTo(mx - 24, my + 38);
    ctx.lineTo(mx - 18, my + 45);
    ctx.stroke();

    // Source to ground
    ctx.beginPath();
    ctx.moveTo(mx, my + 45);
    ctx.lineTo(mx, my + 80);
    ctx.stroke();

    // Rs
    if (p.topology !== 'common-gate' || p.Rs > 0.1) {
      drawResistor(ctx, mx, my + 80, mx, my + 130);
      ctx.fillStyle = '#94a3b8';
      ctx.font = '12px ' + getFont();
      ctx.fillText(`Rs = ${p.Rs}kΩ`, mx + 15, my + 110);
    }

    ctx.strokeStyle = '#e2e8f0';
    ctx.beginPath();
    ctx.moveTo(mx, my + 130);
    ctx.lineTo(mx, 200);
    ctx.stroke();

    // Drain
    ctx.beginPath();
    ctx.moveTo(mx - 35, my - 30);
    ctx.lineTo(mx, my - 30);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(mx, my - 45);
    ctx.lineTo(mx, my - 80);
    ctx.stroke();

    // Rd
    if (p.topology !== 'common-drain' || p.Rd > 0.1) {
      drawResistor(ctx, mx, my - 80, mx, my - 130);
      ctx.fillStyle = '#94a3b8';
      ctx.font = '12px ' + getFont();
      ctx.fillText(`Rd = ${p.Rd}kΩ`, mx + 15, my - 110);
    }

    ctx.beginPath();
    ctx.moveTo(mx, my - 130);
    ctx.lineTo(mx, -200);
    ctx.stroke();

    // Gate resistor + input
    ctx.beginPath();
    ctx.moveTo(mx - 80, my);
    ctx.lineTo(mx - 150, my);
    ctx.stroke();
    drawResistor(ctx, mx - 150, my, mx - 200, my);
    ctx.fillStyle = '#94a3b8';
    ctx.fillText(`Rg = ${p.Rg}MΩ`, mx - 220, my - 10);

    // Vin source
    ctx.beginPath();
    ctx.moveTo(mx - 200, my);
    ctx.lineTo(mx - 250, my);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(mx - 265, my, 15, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = '#60a5fa';
    ctx.fillText('Vin', mx - 275, my - 20);

    // Vout
    let voutY = my - 80;
    if (p.topology === 'common-drain') voutY = my + 80;
    ctx.fillStyle = '#4ade80';
    ctx.font = 'bold 14px ' + getFont();
    ctx.fillText('Vout', mx + 20, voutY);

    // Load resistor
    if (p.topology === 'common-source') {
      ctx.strokeStyle = '#e2e8f0';
      ctx.beginPath();
      ctx.moveTo(mx + 60, my - 80);
      ctx.lineTo(mx + 60, 200);
      ctx.stroke();
      drawResistor(ctx, mx + 60, my - 80, mx + 60, my + 20);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText(`Rload = ${p.Rload}kΩ`, mx + 75, my - 20);
    } else if (p.topology === 'common-drain') {
      ctx.strokeStyle = '#e2e8f0';
      ctx.beginPath();
      ctx.moveTo(mx + 60, my + 80);
      ctx.lineTo(mx + 60, 200);
      ctx.stroke();
      drawResistor(ctx, mx + 60, my + 80, mx + 60, my + 150);
      ctx.fillStyle = '#94a3b8';
      ctx.fillText(`Rload = ${p.Rload}kΩ`, mx + 75, my + 120);
    }

    // Labels
    ctx.fillStyle = '#f472b6';
    ctx.font = 'bold 16px ' + getFont();
    ctx.fillText(isNmos ? 'NMOS' : 'PMOS', mx + 20, my - 50);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '12px ' + getFont();
    ctx.fillText('G', mx - 55, my - 5);
    ctx.fillText('D', mx + 8, my - 35);
    ctx.fillText('S', mx + 8, my + 40);

    ctx.fillStyle = '#fbbf24';
    ctx.font = 'bold 16px ' + getFont();
    ctx.fillText(p.topology.replace('-', ' ').toUpperCase(), -180, -170);

    // Particles
    if (showElectrons && state.Id > 0.01 && dt > 0) {
      const speed = Math.min(state.Id * 2, 8);
      if (Math.random() < state.Id / 5) {
        particlesRef.current.push({ x: mx, y: my - 180, vx: 0, vy: speed, life: 0, maxLife: 60 });
      }
      particlesRef.current = particlesRef.current.filter((pt) => {
        pt.life++;
        pt.y += pt.vy;
        if (p.topology === 'common-source') {
          if (pt.y > my - 30 && pt.y < my + 30) pt.x = mx - 18 + Math.sin(pt.life * 0.3) * 5;
          if (pt.y > my + 45) { pt.vx = (Math.random() - 0.5) * 0.5; pt.x += pt.vx; }
        } else if (p.topology === 'common-drain') {
          if (pt.y > my - 30 && pt.y < my + 30) pt.x = mx - 18 + Math.sin(pt.life * 0.3) * 5;
        }
        if (pt.life > pt.maxLife || pt.y > 200) return false;
        ctx.fillStyle = `rgba(250,204,21,${1 - pt.life / pt.maxLife})`;
        ctx.beginPath(); ctx.arc(pt.x, pt.y, 3, 0, Math.PI * 2); ctx.fill();
        return true;
      });
    }

    drawInfoBox(ctx, w, h, [
      `Region: ${state.region.toUpperCase()}`,
      `Id = ${state.Id.toFixed(2)} mA`,
      `Vgs = ${p.Vgs.toFixed(2)} V`,
      `Vds = ${p.Vds.toFixed(2)} V`,
      `Vov = ${state.Vov.toFixed(2)} V`,
    ]);

    ctx.restore();
  }, [drawInfoBox, drawResistor, showElectrons]);

  const drawCrossSection = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: MosfetParams, state: ReturnType<typeof computeMosfetState>) => {
    const scale = Math.min(w, h) / 500;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(scale, scale);

    const bw = 200, bh = 120, ox = 4;
    const ch = state.channelCharge * 25;

    // Substrate
    ctx.fillStyle = p.type === 'nmos' ? '#1e3a5f' : '#5f3a1e';
    ctx.fillRect(-bw / 2, 0, bw, bh);
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 2;
    ctx.strokeRect(-bw / 2, 0, bw, bh);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '12px ' + getFont();
    ctx.fillText(p.type === 'nmos' ? 'p-substrate' : 'n-substrate', -bw / 2 + 10, bh - 10);

    // Source / Drain
    const sdColor = p.type === 'nmos' ? '#3b82f6' : '#f97316';
    ctx.fillStyle = sdColor;
    ctx.fillRect(-bw / 2 + 10, -20, 50, 20);
    ctx.strokeRect(-bw / 2 + 10, -20, 50, 20);
    ctx.fillRect(bw / 2 - 60, -20, 50, 20);
    ctx.strokeRect(bw / 2 - 60, -20, 50, 20);
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 12px ' + getFont();
    ctx.fillText('S', -bw / 2 + 30, -5);
    ctx.fillText('D', bw / 2 - 40, -5);

    // Gate oxide
    ctx.fillStyle = '#fbbf24';
    ctx.fillRect(-bw / 2 + 60, -20 - ox, bw - 120, ox);

    // Gate metal
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(-bw / 2 + 50, -30 - ox, bw - 100, 10);
    ctx.fillStyle = '#e2e8f0';
    ctx.font = 'bold 12px ' + getFont();
    ctx.fillText('G', -5, -35 - ox);

    // Channel
    if (ch > 0.5) {
      ctx.fillStyle = p.type === 'nmos' ? 'rgba(59,130,246,0.6)' : 'rgba(249,115,22,0.6)';
      ctx.fillRect(-bw / 2 + 60, -ch, bw - 120, ch);
      if (showElectrons) {
        const carrierColor = p.type === 'nmos' ? '#60a5fa' : '#fb923c';
        ctx.fillStyle = carrierColor;
        const numCarriers = Math.floor(state.channelCharge * 20);
        for (let i = 0; i < numCarriers; i++) {
          const px = -bw / 2 + 70 + (i * (bw - 140) / numCarriers) + Math.sin(timeRef.current * 3 + i) * 5;
          const py = -ch / 2 + Math.cos(timeRef.current * 2 + i * 0.5) * 3;
          ctx.beginPath(); ctx.arc(px, py, 3, 0, Math.PI * 2); ctx.fill();
        }
      }
    }

    // Depletion
    if (state.region !== 'cutoff') {
      ctx.fillStyle = 'rgba(148,163,184,0.15)';
      ctx.fillRect(-bw / 2 + 60, 0, 20, bh);
      ctx.fillRect(bw / 2 - 80, 0, 20, bh);
    }

    // Pinch-off
    if (state.region === 'saturation') {
      ctx.fillStyle = 'rgba(239,68,68,0.3)';
      ctx.fillRect(bw / 2 - 85, -ch - 5, 15, ch + 5);
      ctx.fillStyle = '#ef4444';
      ctx.font = '11px ' + getFont();
      ctx.fillText('pinch-off', bw / 2 - 110, -ch - 10);
    }

    // Field lines
    ctx.strokeStyle = 'rgba(251,191,36,0.3)';
    ctx.lineWidth = 1;
    for (let i = -3; i <= 3; i++) {
      ctx.beginPath();
      ctx.moveTo(i * 15, -35);
      ctx.lineTo(i * 15, -ch - 2);
      ctx.stroke();
    }

    drawInfoBox(ctx, w, h, [
      `Region: ${state.region.toUpperCase()}`,
      `Vgs = ${p.Vgs.toFixed(2)} V`,
      `Vds = ${p.Vds.toFixed(2)} V`,
      `Vth = ${p.Vth.toFixed(2)} V`,
      `Vov = ${state.Vov.toFixed(2)} V`,
      `Channel: ${(state.channelCharge * 100).toFixed(0)}%`,
    ]);

    ctx.restore();
  }, [drawInfoBox, showElectrons]);

  const drawCharacteristics = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: MosfetParams, state: ReturnType<typeof computeMosfetState>) => {
    const pad = { top: 50, right: 50, bottom: 60, left: 70 };
    const gw = w - pad.left - pad.right;
    const gh = h - pad.top - pad.bottom;

    ctx.save();
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, w, h);

    // Grid
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 10; i++) {
      const x = pad.left + (i / 10) * gw;
      ctx.beginPath(); ctx.moveTo(x, pad.top); ctx.lineTo(x, pad.top + gh); ctx.stroke();
    }
    for (let i = 0; i <= 10; i++) {
      const y = pad.top + (i / 10) * gh;
      ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(pad.left + gw, y); ctx.stroke();
    }

    // Axes
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(pad.left, pad.top);
    ctx.lineTo(pad.left, pad.top + gh);
    ctx.lineTo(pad.left + gw, pad.top + gh);
    ctx.stroke();

    ctx.fillStyle = '#e2e8f0';
    ctx.font = '14px ' + getFont();
    ctx.fillText('Vds (V)', pad.left + gw / 2 - 20, h - 15);
    ctx.save();
    ctx.translate(20, pad.top + gh / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText('Id (mA)', -30, 0);
    ctx.restore();

    const maxVds = p.Vdd;
    const maxId = p.Vdd / Math.min(p.Rd, 0.5);

    ctx.fillStyle = '#64748b';
    ctx.font = '11px ' + getFont();
    for (let i = 0; i <= 5; i++) {
      const val = (i / 5) * maxVds;
      const x = pad.left + (i / 5) * gw;
      ctx.fillText(val.toFixed(1), x - 10, pad.top + gh + 20);
    }
    for (let i = 0; i <= 5; i++) {
      const val = (i / 5) * maxId;
      const y = pad.top + gh - (i / 5) * gh;
      ctx.fillText(val.toFixed(1), pad.left - 40, y + 4);
    }

    // Family of curves
    const vgsValues = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5];
    vgsValues.forEach((vgs) => {
      if (vgs <= p.Vth) return;
      const curve = getOutputCurve(vgs, p.Vth, p.type, p.W, p.L, p.tox, p.temperature, p.Vdd, p.Rd, 100);
      ctx.strokeStyle = `hsl(${(vgs - p.Vth) * 60 + 200},70%,60%)`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      curve.forEach((pt, i) => {
        const x = pad.left + (pt.vds / maxVds) * gw;
        const y = pad.top + gh - (pt.id / maxId) * gh;
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      });
      ctx.stroke();
      const lastPt = curve[curve.length - 1];
      const lx = pad.left + (lastPt.vds / maxVds) * gw;
      const ly = pad.top + gh - (lastPt.id / maxId) * gh;
      ctx.fillStyle = `hsl(${(vgs - p.Vth) * 60 + 200},70%,60%)`;
      ctx.font = '10px ' + getFont();
      ctx.fillText(`Vgs=${vgs.toFixed(1)}V`, lx + 5, ly);
    });

    // Load line
    const loadLine = getLoadLine(p.Vdd, p.Rd, 100);
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    loadLine.forEach((pt, i) => {
      const x = pad.left + (pt.vds / maxVds) * gw;
      const y = pad.top + gh - (pt.id / maxId) * gh;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    });
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#ef4444';
    ctx.font = '12px ' + getFont();
    ctx.fillText('Load Line', pad.left + 10, pad.top + 20);

    // Q-point
    const qx = pad.left + (Math.abs(p.Vds) / maxVds) * gw;
    const qy = pad.top + gh - (state.Id / maxId) * gh;
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(qx, qy, 8, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
    ctx.fillStyle = '#fbbf24';
    ctx.font = 'bold 12px ' + getFont();
    ctx.fillText('Q', qx + 12, qy - 5);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '11px ' + getFont();
    ctx.fillText(`(${Math.abs(p.Vds).toFixed(1)}V, ${state.Id.toFixed(2)}mA)`, qx + 12, qy + 10);

    // Sat/triode boundary
    ctx.strokeStyle = '#4ade80';
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    ctx.beginPath();
    const boundaryVgs = Math.max(...vgsValues.filter(v => v > p.Vth));
    const boundaryVov = boundaryVgs - p.Vth;
    const bx = pad.left + (boundaryVov / maxVds) * gw;
    ctx.moveTo(bx, pad.top);
    ctx.lineTo(bx, pad.top + gh);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#4ade80';
    ctx.font = '10px ' + getFont();
    ctx.fillText('sat/triode', bx + 5, pad.top + 15);

    drawInfoBox(ctx, w, h, [
      `Topology: ${p.topology}`,
      `Vdd = ${p.Vdd}V`,
      `Rd = ${p.Rd}kΩ`,
      `Q-point: (${Math.abs(p.Vds).toFixed(1)}V,`,
      `         ${state.Id.toFixed(2)}mA)`,
    ]);

    ctx.restore();
  }, [drawInfoBox]);

  const drawAnalysis = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: MosfetParams, state: ReturnType<typeof computeMosfetState>) => {
    ctx.save();
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, w, h);

    const cols = w > 700 ? 3 : w > 500 ? 2 : 1;
    const colW = (w - 60) / cols;
    const startX = 30;
    const startY = 40;
    const rowH = 70;

    const metrics = [
      { label: 'Voltage Gain (Av)', value: `${state.Av.toFixed(2)} V/V`, color: '#f472b6', detail: state.Av < 0 ? '180° phase invert' : '0° phase' },
      { label: 'Current Gain (Ai)', value: `${state.Ai.toFixed(2)}`, color: '#60a5fa', detail: '' },
      { label: 'Transconductance (gm)', value: `${(state.gm * 1000).toFixed(2)} μS`, color: '#4ade80', detail: `${state.gm.toFixed(3)} mS` },
      { label: 'Input Impedance (Zin)', value: `${state.Zin >= 1 ? state.Zin.toFixed(1) + ' MΩ' : (state.Zin * 1000).toFixed(1) + ' kΩ'}`, color: '#fbbf24', detail: '' },
      { label: 'Output Impedance (Zout)', value: `${state.Zout >= 1 ? state.Zout.toFixed(1) + ' kΩ' : state.Zout.toFixed(1) + ' Ω'}`, color: '#a78bfa', detail: '' },
      { label: 'Power Dissipation', value: `${state.Pdiss.toFixed(2)} mW`, color: '#f87171', detail: '' },
      { label: 'Drain Current (Id)', value: `${state.Id.toFixed(2)} mA`, color: '#38bdf8', detail: `Sat limit: ${state.Id_sat.toFixed(2)} mA` },
      { label: 'Overdrive (Vov)', value: `${state.Vov.toFixed(2)} V`, color: '#34d399', detail: `Vdsat = ${state.Vdsat.toFixed(2)} V` },
      { label: 'Channel Length Mod', value: `λ = ${state.lambda.toFixed(3)} V⁻¹`, color: '#fb923c', detail: `ro = ${state.Id > 0 ? (1 / (state.lambda * state.Id)).toFixed(1) : '∞'} kΩ` },
    ];

    metrics.forEach((m, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const x = startX + col * colW;
      const y = startY + row * rowH;

      ctx.fillStyle = '#1e293b';
      ctx.strokeStyle = m.color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(x, y, colW - 15, rowH - 10, 8);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#94a3b8';
      ctx.font = '11px ' + getFont();
      ctx.fillText(m.label, x + 12, y + 20);

      ctx.fillStyle = m.color;
      ctx.font = 'bold 18px monospace';
      ctx.fillText(m.value, x + 12, y + 42);

      if (m.detail) {
        ctx.fillStyle = '#64748b';
        ctx.font = '10px ' + getFont();
        ctx.fillText(m.detail, x + 12, y + 56);
      }
    });

    ctx.restore();
  }, []);

  const drawLoop = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current, p = s.params;
    resize();
    const rect = wrap.getBoundingClientRect(), w = rect.width, h = rect.height;
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) timeRef.current += dt;
    const t = timeRef.current;

    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, w, h);

    const state = computeMosfetState(p);
    const cx = w / 2, cy = h / 2;

    switch (s.activeTab) {
      case 'schematic': drawSchematic(ctx, cx, cy, w, h, dt, p, state); break;
      case 'cross-section': drawCrossSection(ctx, cx, cy, w, h, dt, p, state); break;
      case 'characteristics': drawCharacteristics(ctx, cx, cy, w, h, dt, p, state); break;
      case 'analysis': drawAnalysis(ctx, cx, cy, w, h, dt, p, state); break;
    }

    if (s.onTick) {
      const now = performance.now();
      if (now - lastTickRef.current > 80) {
        lastTickRef.current = now;
        s.onTick({
          region: state.region,
          Id: state.Id,
          Vgs: p.Vgs,
          Vds: p.Vds,
          Vov: state.Vov,
          gm: state.gm,
          Av: state.Av,
          Zin: state.Zin,
          Zout: state.Zout,
          Pdiss: state.Pdiss,
        });
      }
    }

    rafRef.current = requestAnimationFrame(drawLoop);
  }, [resize, drawSchematic, drawCrossSection, drawCharacteristics, drawAnalysis]);

  useEffect(() => {
    resize();
    rafRef.current = requestAnimationFrame(drawLoop);
    window.addEventListener('resize', resize);
    return () => {
      cancelAnimationFrame(rafRef.current);
      window.removeEventListener('resize', resize);
    };
  }, [drawLoop, resize]);

  return (
    <div ref={wrapRef} style={{ width: '100%', position: 'relative', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--kimi-color-border-secondary, #e5e7eb)', background: '#0b1021', aspectRatio: '16 / 10', minHeight: 260 }}>
      <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />
    </div>
  );
}
FILEEOF

echo ""
echo "Done. Your build should now be fully clean — try 'npm run build' to confirm."
