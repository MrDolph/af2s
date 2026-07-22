import type { Metadata, Viewport } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const geistMono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'A-Factor STEM Studio — Physics simulations for every curriculum',
  description: 'AI-powered interactive physics simulations for WAEC, NECO, IGCSE, SAT and JUPEB students. Type a prompt, get an instant simulation.',
  keywords: ['physics simulation', 'WAEC', 'IGCSE', 'NECO', 'SAT', 'JUPEB', 'STEM education', 'Africa'],
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
      <body className="min-h-screen bg-gray-50" suppressHydrationWarning>{children}</body>
    </html>
  );
}
