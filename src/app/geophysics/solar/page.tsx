import type { Metadata } from 'next';
import { GeophysicsFrame } from '@/components/geophysics/GeophysicsFrame';

export const metadata: Metadata = {
  title: "Solar System Explorer | A-Factor STEM Studio",
  description: "Planet families, nebular formation and Kepler’s laws through interactive experiments.",
};

export default function Page() {
  return <GeophysicsFrame active="solar" src="/geophysics/solar-content.html"
    title="AUI-PHY 407 · Solar System Explorer" />;
}
