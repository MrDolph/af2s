import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Chemistry & Materials Playground — A-Factor STEM Studio',
  description: 'Interactive periodic table, compound builder and perovskite lab. Build candidate compositions and structures, with clear separation between your proposals and established results.',
};

export default function ChemistryLayout({ children }: { children: React.ReactNode }) {
  return children;
}
