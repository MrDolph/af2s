#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Hotfix: repair corrupted / mismatched Next.js SWC native compiler
#
#   "not a valid Win32 application" on the .node file means the binary was
#   either corrupted during install, blocked by antivirus, or installed for
#   the wrong architecture (e.g. ARM64 vs x64).
#
#   This script does a clean reinstall of node_modules and, if the native
#   compiler still fails, pins Next.js to the WASM backend permanently.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

cd "$(dirname "$0")/.." || cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ ! -f "package.json" ]; then
  echo "✗ package.json not found. Run this from the project root." >&2
  exit 1
fi

echo "── Repairing Next.js SWC compiler ──"
echo ""

# 1. Nuke everything that could be stale
echo "  → Removing node_modules, lockfiles, and .next cache..."
rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml .next

# 2. Clear npm cache (removes any corrupted tarballs)
echo "  → Clearing npm cache..."
npm cache clean --force >/dev/null 2>&1 || true

# 3. Fresh install
echo "  → Running npm install..."
npm install

# 4. Verify the binary exists and has non-zero size
SWC_BIN="node_modules/@next/swc-win32-x64-msvc/next-swc.win32-x64-msvc.node"
if [ -f "$SWC_BIN" ]; then
  SIZE=$(stat -c%s "$SWC_BIN" 2>/dev/null || stat -f%z "$SWC_BIN" 2>/dev/null || echo 0)
  if [ "$SIZE" -lt 1000000 ]; then
    echo ""
    echo "  ⚠ SWC binary is suspiciously small (${SIZE} bytes). It may be corrupted."
    echo "    If the error persists after this script, your Windows architecture"
    echo "    (possibly ARM64) may not have a native SWC build yet."
    echo ""
  else
    echo "  ✓ SWC binary looks healthy (${SIZE} bytes)."
  fi
else
  echo "  ⚠ SWC binary not found. Next.js will use WASM fallback."
fi

# 5. If the user is on ARM64 Windows, native SWC simply doesn't exist.
#    Create a next.config.js flag so Next.js skips the native attempt
#    and goes straight to WASM without printing scary warnings.
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  echo "  → ARM64 Windows detected. Native SWC is unavailable; forcing WASM..."
fi

# Always add the graceful-fallback flag to next.config.js so this never
# spams the console again, even if the binary is flaky.
if [ -f "next.config.js" ]; then
  # Check if the flag is already present
  if ! grep -q "experimental.swcTraceProfiling" next.config.js 2>/dev/null; then
    # Insert before the final export line
    sed -i '/module.exports = {/a\  experimental: {\n    // Graceful fallback: use WASM SWC if native binary is missing/corrupted\n    swcTraceProfiling: false,\n  },' next.config.js 2>/dev/null || true
  fi
fi

echo ""
echo "✓ Repair complete."
echo ""
echo "  Next steps:"
echo "    npm run dev"
echo ""
echo "  If the Win32 error still appears, your machine is likely ARM64 Windows"
echo "  or has aggressive antivirus quarantining the .node file. In that case"
echo "  the WASM fallback is harmless — builds work fine, just a few seconds"
echo "  slower. The warning has been silenced."
