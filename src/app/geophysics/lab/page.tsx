import type { Metadata } from 'next';
import { AppHeader } from '@/components/layout/AppHeader';

export const metadata: Metadata = {
  title: 'Geophysics Field Lab | A-Factor STEM Studio',
  description: 'Interactive gravity, resistivity, seismic, electromagnetic and well-logging experiments for AUI-PHY 407.',
};

export default function GeophysicsLabPage() {
  return (
    <>
      <AppHeader />
      <main
        aria-label="Geophysics field lab"
        style={{ height: 'calc(100dvh - 3.5rem)', minHeight: '24rem' }}
      >
        <iframe
          src="/geophysics/field-lab.html"
          title="AUI-PHY 407 interactive geophysics field lab"
          style={{ display: 'block', width: '100%', height: '100%', border: 0 }}
        />
      </main>
    </>
  );
}
