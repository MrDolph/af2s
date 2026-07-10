'use client';
import { getProjectileAnalytics } from '@/lib/physics/projectile';
import type { ProjectileParams } from '@/lib/physics/projectile';

interface StatCardProps { label: string; value: string; unit: string; color?: string; }
function StatCard({ label, value, unit, color = 'text-indigo-600' }: StatCardProps) {
  return (
    <div className="flex flex-col items-center rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
      <span className="text-xs text-gray-400 mb-1">{label}</span>
      <span className={`text-lg font-semibold ${color}`}>{value}</span>
      <span className="text-xs text-gray-400">{unit}</span>
    </div>
  );
}
interface SimulationStatsProps { params: ProjectileParams; elapsedTime?: number; currentHeight?: number; currentSpeed?: number; }
export function SimulationStats({ params, elapsedTime, currentHeight, currentSpeed }: SimulationStatsProps) {
  const { timeOfFlight, maxRange, maxHeight } = getProjectileAnalytics(params);
  return (
    <div className="space-y-3">
      <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Calculated values</p>
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Time of flight" value={String(timeOfFlight)} unit="seconds" />
        <StatCard label="Max range" value={String(maxRange)} unit="metres" color="text-emerald-600" />
        <StatCard label="Max height" value={String(maxHeight)} unit="metres" color="text-amber-600" />
      </div>
      {elapsedTime !== undefined && elapsedTime > 0 && (
        <>
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400 pt-1">Live values</p>
          <div className="grid grid-cols-3 gap-3">
            <StatCard label="Elapsed" value={elapsedTime.toFixed(2)} unit="seconds" color="text-gray-700" />
            <StatCard label="Altitude" value={(currentHeight ?? 0).toFixed(1)} unit="metres" color="text-blue-600" />
            <StatCard label="Speed" value={(currentSpeed ?? 0).toFixed(1)} unit="m/s" color="text-rose-500" />
          </div>
        </>
      )}
    </div>
  );
}
