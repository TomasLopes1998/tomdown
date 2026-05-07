#!/usr/bin/env bash
# Remove tomdown and its desktop registration. Does not touch uv's cached venv.
set -euo pipefail

BIN="${HOME}/.local/bin/tomdown"
DESKTOP="${HOME}/.local/share/applications/tomdown.desktop"

if command -v xdg-mime >/dev/null 2>&1; then
  for mt in text/markdown text/x-markdown; do
    if [ "$(xdg-mime query default "${mt}" 2>/dev/null || true)" = "tomdown.desktop" ]; then
      xdg-mime default "" "${mt}" 2>/dev/null || true
    fi
  done
fi

rm -f "${BIN}" "${DESKTOP}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
fi

pkill -f "uv run --script ${BIN}" 2>/dev/null || true

echo "removed tomdown and desktop entry"
