import type { Metadata } from 'next';
import { GeophysicsFrame } from '@/components/geophysics/GeophysicsFrame';

export const metadata: Metadata = {
  title: "Tectonics & Earth’s Shape | A-Factor STEM Studio",
  description: "World plates, continental drift, plate margins, VMM anomalies, triple junctions and hydrostatic flattening.",
};

export default function Page() {
  return <GeophysicsFrame active="tectonics" src="/geophysics/tectonics-content.html"
    title="AUI-PHY 407 · Tectonics & Earth’s Shape" />;
}
