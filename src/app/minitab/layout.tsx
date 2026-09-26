import { MinitabBar } from '@/components/layout/MinitabBar';

export default function MinitabLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <MinitabBar />
      {children}
    </>
  );
}
