import type { Metadata, Viewport } from 'next';
import { GeistSans } from 'geist/font/sans';
import { GeistMono } from 'geist/font/mono';
import './globals.css';

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
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable} antialiased`}>
      <body className="min-h-screen bg-gray-50" suppressHydrationWarning>{children}</body>
    </html>
  );
}
