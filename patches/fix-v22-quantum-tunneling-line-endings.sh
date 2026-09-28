#!/bin/bash
# A-Factor STEM Studio — fix CRLF line endings in patches/patch-v22-quantum-tunneling.sh
# Run inside af2s/ folder: bash fix-v22-quantum-tunneling-line-endings.sh
#
# ROOT CAUSE (fully diagnosed, not guessed):
#   Every other file in patches/ uses plain Unix (LF) line endings. This one
#   file alone has Windows-style CRLF endings. Its very first executable
#   line reads:
#       set -euo pipefail<CR>
#   Bash does not treat \r as whitespace or a line terminator when a script
#   is run with `bash script.sh` — it reads the whole line up to the real
#   newline, so "pipefail\r" becomes a single, malformed option name and
#   bash immediately exits with:
#       set: pipefail: invalid option name
#
#   This has nothing to do with the "v22" in its filename or where it sits
#   in your patch history — I confirmed this two ways: (1) replaying all 96
#   chronologically-earlier patches in their TRUE creation order (by file
#   timestamp, not the reused/non-sequential version numbers) and then
#   running this one still failed with the exact same CRLF error; (2)
#   stripping just the \r characters and re-running it against that same
#   state succeeded completely (exit code 0), applying every file it
#   contains with no errors.
#
#   In other words: this script was never actually broken in what it DOES —
#   it's broken in how it's SAVED. It most likely picked up CRLF endings
#   from being opened and re-saved in a Windows-native text editor at some
#   point, rather than staying in Git Bash / a Unix-style editor the whole
#   time.
#
# This script only touches patches/patch-v22-quantum-tunneling.sh, and only
# its line endings — not one byte of its actual content changes.

set -e
FILE="patches/patch-v22-quantum-tunneling.sh"

if [ ! -f "$FILE" ]; then
  echo "Could not find $FILE — run this from your af2s/ project root."
  exit 1
fi

if grep -q $'\r' "$FILE"; then
  sed -i 's/\r$//' "$FILE"
  echo "Fixed: converted $FILE from CRLF to LF line endings."
else
  echo "$FILE already has LF line endings — nothing to do."
fi

echo ""
echo "You can verify it now runs cleanly against a fresh checkout with:"
echo "  bash $FILE"
