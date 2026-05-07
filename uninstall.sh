#!/usr/bin/env bash
# Remove tomdown and its file association. Linux and macOS supported.
# (Windows: use uninstall.ps1 from PowerShell.) Does not touch uv's cached venv.
set -euo pipefail

uninstall_linux() {
  local bin="${HOME}/.local/bin/tomdown"
  local desktop="${HOME}/.local/share/applications/tomdown.desktop"

  if command -v xdg-mime >/dev/null 2>&1; then
    for mt in text/markdown text/x-markdown; do
      if [ "$(xdg-mime query default "${mt}" 2>/dev/null || true)" = "tomdown.desktop" ]; then
        xdg-mime default "" "${mt}" 2>/dev/null || true
      fi
    done
  fi

  rm -f "${bin}" "${desktop}"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
  fi

  pkill -f "uv run --script ${bin}" 2>/dev/null || true

  echo "removed tomdown and desktop entry"
}

uninstall_macos() {
  local app_bundle="${HOME}/Applications/tomdown.app"
  local cli_link="${HOME}/.local/bin/tomdown"

  # If duti is around and .md still points at us, bounce it back to TextEdit.
  if command -v duti >/dev/null 2>&1; then
    if [ "$(duti -x md 2>/dev/null | tail -n1 || true)" = "dev.tomdown.tomdown" ]; then
      duti -s com.apple.TextEdit .md all 2>/dev/null || true
    fi
  fi

  local lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
  if [ -x "${lsregister}" ] && [ -d "${app_bundle}" ]; then
    "${lsregister}" -u "${app_bundle}" >/dev/null 2>&1 || true
  fi

  rm -rf "${app_bundle}"
  rm -f "${cli_link}"

  pkill -f "uv run --script .*tomdown.py" 2>/dev/null || true

  echo "removed ${app_bundle} and ${cli_link}"
}

case "$(uname -s)" in
  Linux*)  uninstall_linux ;;
  Darwin*) uninstall_macos ;;
  *)       echo "error: unsupported OS '$(uname -s)'. For Windows, use uninstall.ps1." >&2; exit 1 ;;
esac
