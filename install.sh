#!/usr/bin/env bash
# Install tomdown as the default Markdown viewer for the current user.
# Idempotent — safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${APP_DIR}/tomdown.desktop"
TARGET="${BIN_DIR}/tomdown"

command -v uv >/dev/null 2>&1 || {
  echo "error: 'uv' is required (https://docs.astral.sh/uv/). Install it first." >&2
  exit 1
}
command -v xdg-mime >/dev/null 2>&1 || {
  echo "error: 'xdg-mime' (xdg-utils) is required." >&2
  exit 1
}

mkdir -p "${BIN_DIR}" "${APP_DIR}"
install -m 0755 "${SCRIPT_DIR}/tomdown" "${TARGET}"

cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=tomdown
Comment=Render Markdown locally with Mermaid + dark theme
Exec=${TARGET} %f
Terminal=false
MimeType=text/markdown;text/x-markdown;
Categories=Utility;TextTools;
NoDisplay=false
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APP_DIR}" >/dev/null 2>&1 || true
fi

xdg-mime default tomdown.desktop text/markdown
xdg-mime default tomdown.desktop text/x-markdown

echo "installed: ${TARGET}"
echo "desktop:   ${DESKTOP_FILE}"
echo "default:   $(xdg-mime query default text/markdown)"
echo
echo "Open a markdown file with:"
echo "  xdg-open path/to/file.md"
echo "  ${TARGET} path/to/file.md"
