#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v6
#   Silences the recurring hydration-mismatch console warning caused by
#   browser extensions (Grammarly, ColorZilla) injecting attributes onto
#   <body> before React hydrates. Harmless, dev-only noise — this just stops
#   it from cluttering the console. suppressHydrationWarning only ignores
#   attribute mismatches on this one element, so real hydration bugs
#   elsewhere in the tree still surface normally.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v6-suppress-extension-hydration-warning.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

mkdir -p "src/app"

echo "  → src/app/layout.tsx"
cat > "src/app/layout.tsx" << 'AFEOF'
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
AFEOF

echo ""
echo "✓ Patch v6 applied."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
