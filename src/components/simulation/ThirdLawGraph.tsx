'use client';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';

interface DataPoint { t: number; v1: number; v2: number; }

interface Props {
  data: DataPoint[];
  scenario: 'push' | 'rocket' | 'collision';
  liveT: number;
  liveV1: number;
  liveV2: number;
}

// Shows the full predicted v–t curve(s) immediately, with live dots riding
// along as the animation plays — same pattern as NewtonsGraph. For
// push/collision this is the whole point of the demo: two lines with equal
// magnitude but opposite sign, diverging at different rates because the
// masses differ, even though the force on each is identical.
export function ThirdLawGraph({ data, scenario, liveT, liveV1, liveV2 }: Props) {
  const tMax = data.length > 0 ? data[data.length - 1].t : 0;
  const dual = scenario !== 'rocket';
  return (
    <ResponsiveContainer width="100%" height={180}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={[0, tMax]}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Velocity (m/s)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown, name?: unknown) => [Number(v).toFixed(3) + ' m/s', String(name ?? '')]}
          labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        {dual && <ReferenceLine y={0} stroke="#e2e8f0" />}
        <Line type="monotone" dataKey="v1" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} name={dual ? 'Object 1' : 'Rocket'} />
        {dual && <Line type="monotone" dataKey="v2" stroke="#10b981" strokeWidth={2} dot={false} isAnimationActive={false} name="Object 2" />}
        {liveT > 0 && <ReferenceDot x={Math.min(liveT, tMax)} y={liveV1} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />}
        {dual && liveT > 0 && <ReferenceDot x={Math.min(liveT, tMax)} y={liveV2} r={5} fill="#10b981" stroke="#fff" strokeWidth={2} />}
      </LineChart>
    </ResponsiveContainer>
  );
}
