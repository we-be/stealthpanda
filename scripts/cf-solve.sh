#!/bin/bash
# StealthPanda CF Challenge Solver
# Solves Cloudflare managed challenges using Chrome headed mode
# and outputs cookies for use with StealthPanda.
#
# Usage: ./scripts/cf-solve.sh <url> [timeout_ms]
# Output: Cookie header string (cf_clearance=...; __cf_bm=...)
#
# Requirements: Chrome 146+ via Flatpak, Node.js, puppeteer-core

set -e

URL="${1:?Usage: $0 <url> [timeout_ms]}"
TIMEOUT="${2:-60000}"

# Check dependencies
if ! flatpak info com.google.Chrome >/dev/null 2>&1; then
  echo "Error: Chrome not found. Install via: flatpak install com.google.Chrome" >&2
  exit 1
fi

if ! which node >/dev/null 2>&1; then
  echo "Error: Node.js not found" >&2
  exit 1
fi

# Install puppeteer-core if needed
if [ ! -d "/tmp/node_modules/puppeteer-core" ]; then
  echo "Installing puppeteer-core..." >&2
  cd /tmp && npm install puppeteer-core 2>/dev/null >&2
fi

# Run the solver
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COOKIES=$(timeout $((TIMEOUT/1000 + 30)) node "$SCRIPT_DIR/solve_challenge.mjs" "$URL" "$TIMEOUT" 2>/dev/null)

if [ -z "$COOKIES" ]; then
  echo "Error: Challenge solver failed" >&2
  exit 1
fi

# Extract cookies into a usable format
CF_CLEARANCE=$(echo "$COOKIES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cf_clearance',''))" 2>/dev/null)
CF_BM=$(echo "$COOKIES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('__cf_bm',''))" 2>/dev/null)

if [ -z "$CF_CLEARANCE" ]; then
  echo "Error: No cf_clearance in response" >&2
  exit 1
fi

# Output cookie header
echo "cf_clearance=$CF_CLEARANCE; __cf_bm=$CF_BM"
