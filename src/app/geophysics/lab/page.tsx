import type { Metadata } from 'next';
import { GeophysicsFrame } from '@/components/geophysics/GeophysicsFrame';

export const metadata: Metadata = {
  title: "Geophysics Field Lab | A-Factor STEM Studio",
  description: "Interactive gravity, resistivity, seismic, electromagnetic and well-logging experiments for AUI-PHY 407.",
};

export default function Page() {
  return <GeophysicsFrame active="lab" src="/geophysics/field-lab.html"
    title="AUI-PHY 407 · Geophysics Field Lab" />;
}
