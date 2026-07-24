'use client';
import { useRef, useEffect, useCallback } from 'react';
import { capacitorChargingVoltage, capacitorDischargingVoltage, capacitorCharge, capacitorEnergy } from '@/lib/physics/electrostatics';

interface Props {
  voltageV: number;    // battery / supply voltage
  resistanceOhm: number;
  capacitanceUf: number;
  isRunning: boolean; isPaused: boolean;
  dischargeKey: number; // increments to switch from charging to discharging, once charged
  onTick?: (voltage: number, phase: 'charging' | 'discharging') => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 5) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.2;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

export function CapacitorCanvas({
  voltageV, resistanceOhm, capacitanceUf, isRunning, isPaused, dischargeKey, onTick,
  width = 660, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const phase = useRef<'charging' | 'discharging'>('charging');
  const lastDischargeKey = useRef(dischargeKey);
  const vAtSwitch = useRef(0);
  const sim = useRef({ voltageV, resistanceOhm, capacitanceUf, isRunning, isPaused, onTick });
  sim.current = { voltageV, resistanceOhm, capacitanceUf, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; phase.current = 'charging'; lastFrameRef.current = null; }, [voltageV, resistanceOhm, capacitanceUf]);

  useEffect(() => {
    if (dischargeKey !== lastDischargeKey.current) {
      lastDischargeKey.current = dischargeKey;
      const C = capacitanceUf * 1e-6;
      vAtSwitch.current = capacitorChargingVoltage(t.current, voltageV, resistanceOhm, C);
      phase.current = 'discharging';
      t.current = 0;
    }
  }, [dischargeKey, voltageV, resistanceOhm, capacitanceUf]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += (timestamp - lastFrameRef.current) / 1000;
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const C = s.capacitanceUf * 1e-6;
    const v = s.isRunning
      ? (phase.current === 'charging'
          ? capacitorChargingVoltage(t.current, s.voltageV, s.resistanceOhm, C)
          : capacitorDischargingVoltage(t.current, vAtSwitch.current, s.resistanceOhm, C))
      : 0;
    s.onTick?.(v, phase.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H * 0.42;
    const plateGap = 90, plateH = 110, plateX1 = W / 2 - plateGap / 2, plateX2 = W / 2 + plateGap / 2;

    // Wires + battery
    const battX = 70;
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(battX, midY - 30); ctx.lineTo(battX, midY - 70); ctx.lineTo(plateX1, midY - 70); ctx.lineTo(plateX1, midY - plateH / 2);
    ctx.moveTo(battX, midY + 30); ctx.lineTo(battX, midY + 70); ctx.lineTo(plateX2, midY + 70); ctx.lineTo(plateX2, midY + plateH / 2);
    ctx.stroke();
    // Battery symbol
    ctx.beginPath(); ctx.moveTo(battX - 14, midY - 30); ctx.lineTo(battX + 14, midY - 30); ctx.stroke();
    ctx.lineWidth = 4; ctx.beginPath(); ctx.moveTo(battX - 8, midY + 30); ctx.lineTo(battX + 8, midY + 30); ctx.stroke();
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.voltageV}V`, battX, midY + 50);

    // Plates
    const fraction = s.voltageV !== 0 ? Math.abs(v / s.voltageV) : 0;
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(plateX1 - 4, midY - plateH / 2, 8, plateH);
    ctx.fillRect(plateX2 - 4, midY - plateH / 2, 8, plateH);

    // Charge accumulating on the plates
    const nCharges = Math.round(fraction * 8);
    for (let i = 0; i < nCharges; i++) {
      const y = midY - plateH / 2 + 10 + (i / Math.max(1, nCharges - 1)) * (plateH - 20);
      drawCharge(ctx, plateX1 - 12, y, 1, 4.5);
      drawCharge(ctx, plateX2 + 12, y, -1, 4.5);
    }

    // Field between the plates, proportional to V
    if (fraction > 0.03) {
      ctx.strokeStyle = 'rgba(99,102,241,0.6)'; ctx.lineWidth = 1.3;
      for (let i = 1; i <= 4; i++) {
        const y = midY - plateH / 2 + (i * plateH) / 5;
        const ex1 = plateX1 + 6, ex2 = plateX2 - 6;
        ctx.beginPath(); ctx.moveTo(ex1, y); ctx.lineTo(ex2, y); ctx.stroke();
        const ang = 0;
        ctx.save(); ctx.fillStyle = 'rgba(99,102,241,0.6)';
        ctx.translate((ex1 + ex2) / 2, y); ctx.rotate(ang);
        ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, -4); ctx.lineTo(-4, 4); ctx.closePath(); ctx.fill();
        ctx.restore();
      }
    }

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = '#334155';
    ctx.fillText(
      !s.isRunning ? 'Press Run to charge the capacitor'
        : phase.current === 'charging' ? 'Charging — voltage climbs toward the supply voltage'
        : 'Discharging — voltage decays back toward zero',
      W / 2, 20,
    );

    // Voltage bar graph over time (a simple live meter, not a full trace)
    const meterX = W - 60, meterY = midY - 50, meterH = 100, meterW = 20;
    ctx.strokeStyle = '#94a3b8'; ctx.strokeRect(meterX, meterY, meterW, meterH);
    const fillH = Math.min(meterH, (Math.abs(v) / Math.max(s.voltageV, 1)) * meterH);
    ctx.fillStyle = '#f59e0b'; ctx.fillRect(meterX, meterY + meterH - fillH, meterW, fillH);
    ctx.fillStyle = '#334155'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('V', meterX + meterW / 2, meterY - 6);
    ctx.fillText(`${v.toFixed(1)}V`, meterX + meterW / 2, meterY + meterH + 14);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Q = CV = ${(capacitorCharge(C, v) * 1e6).toFixed(2)} µC   Energy = ½CV² = ${(capacitorEnergy(C, v) * 1e6).toFixed(2)} µJ`, 8, H - 10);

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
