'use client';
import type { ProjectileParams } from '@/lib/physics/projectile';
interface SliderProps { label: string; unit: string; value: number; min: number; max: number; step?: number; onChange: (v: number) => void; disabled?: boolean; color?: string; }
function Slider({ label, unit, value, min, max, step = 0.5, onChange, disabled, color = '#6366f1' }: SliderProps) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-500">{label}</span>
        <span className="text-xs font-medium text-gray-800 tabular-nums">{value} <span className="text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} disabled={disabled} onChange={e => onChange(Number(e.target.value))} className="w-full disabled:opacity-40" style={{ accentColor: color }} />
      <div className="flex justify-between text-[10px] text-gray-300"><span>{min}{unit}</span><span>{max}{unit}</span></div>
    </div>
  );
}
interface ParamControlsProps { params: ProjectileParams; onChange: (p: ProjectileParams) => void; disabled?: boolean; }
export function ParamControls({ params, onChange, disabled }: ParamControlsProps) {
  const update = (key: keyof ProjectileParams) => (value: number) => onChange({ ...params, [key]: value });
  return (
    <div className="space-y-4 rounded-xl border border-gray-100 bg-gray-50 p-4">
      <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Adjust parameters</p>
      <Slider label="Initial velocity" unit="m/s" value={params.initialVelocity} min={1} max={100} step={1} onChange={update('initialVelocity')} disabled={disabled} color="#6366f1" />
      <Slider label="Launch angle" unit="°" value={params.angle} min={1} max={89} step={1} onChange={update('angle')} disabled={disabled} color="#f59e0b" />
      <Slider label="Gravity" unit="m/s²" value={params.gravity} min={1} max={25} step={0.1} onChange={update('gravity')} disabled={disabled} color="#10b981" />
      <Slider label="Mass" unit="kg" value={params.mass} min={0.1} max={100} step={0.1} onChange={update('mass')} disabled={disabled} color="#8b5cf6" />
      {disabled && <p className="text-xs text-gray-400 italic text-center">Reset to adjust parameters</p>}
    </div>
  );
}
