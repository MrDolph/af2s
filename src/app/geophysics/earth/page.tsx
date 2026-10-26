import type { Metadata } from 'next';
import { GeophysicsFrame } from '@/components/geophysics/GeophysicsFrame';

export const metadata: Metadata = {
  title: "Earth Explorer | A-Factor STEM Studio",
  description: "Rotate and open the Earth to explore its interior and atmosphere from inner core to exosphere.",
};

export default function Page() {
  return <GeophysicsFrame active="earth" src="/geophysics/earth-content.html"
    title="AUI-PHY 407 · Earth Explorer" />;
}
