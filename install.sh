#!/usr/bin/env bash
# Install tomdown as the default Markdown viewer for the current user.
# Idempotent — safe to re-run. Linux and macOS supported.
# (Windows: use install.ps1 from PowerShell.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${SCRIPT_DIR}/tomdown"

command -v uv >/dev/null 2>&1 || {
  echo "error: 'uv' is required (https://docs.astral.sh/uv/). Install it first." >&2
  exit 1
}
[ -f "${SOURCE}" ] || {
  echo "error: source script not found at ${SOURCE}" >&2
  exit 1
}

install_linux() {
  command -v xdg-mime >/dev/null 2>&1 || {
    echo "error: 'xdg-mime' (xdg-utils) is required." >&2
    exit 1
  }

  local bin_dir="${HOME}/.local/bin"
  local app_dir="${HOME}/.local/share/applications"
  local desktop_file="${app_dir}/tomdown.desktop"
  local target="${bin_dir}/tomdown"

  mkdir -p "${bin_dir}" "${app_dir}"
  install -m 0755 "${SOURCE}" "${target}"

  cat > "${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=tomdown
Comment=Render Markdown locally with Mermaid + dark theme
Exec=${target} %f
Terminal=false
MimeType=text/markdown;text/x-markdown;
Categories=Utility;TextTools;
NoDisplay=false
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${app_dir}" >/dev/null 2>&1 || true
  fi

  xdg-mime default tomdown.desktop text/markdown
  xdg-mime default tomdown.desktop text/x-markdown

  echo "installed: ${target}"
  echo "desktop:   ${desktop_file}"
  echo "default:   $(xdg-mime query default text/markdown)"
  echo
  echo "Open a markdown file with:"
  echo "  xdg-open path/to/file.md"
  echo "  ${target} path/to/file.md"
}

install_macos() {
  local app_bundle="${HOME}/Applications/tomdown.app"
  local contents="${app_bundle}/Contents"
  local bin_dir="${HOME}/.local/bin"
  local cli_link="${bin_dir}/tomdown"

  # Clean any prior bundle so stale files don't linger.
  rm -rf "${app_bundle}"
  mkdir -p "${contents}/MacOS" "${contents}/Resources" "${bin_dir}"

  # Copy source into Resources as tomdown.py (uv --script wants .py).
  # Strip the unix shebang since the launcher re-invokes uv directly.
  sed '1{/^#!/d;}' "${SOURCE}" > "${contents}/Resources/tomdown.py"

  # Launcher executable invoked by Launch Services.
  cat > "${contents}/MacOS/tomdown" <<'LAUNCHER'
#!/bin/bash
# Launch Services starts apps with a minimal PATH; add the usual uv locations.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
DIR="$(cd "$(dirname "$0")" && pwd)"
# Strip the -psn_X_X process-serial arg Launch Services sometimes injects.
ARGS=()
for a in "$@"; do
  case "$a" in -psn_*) ;; *) ARGS+=("$a") ;; esac
done
exec uv run --script "${DIR}/../Resources/tomdown.py" "${ARGS[@]}"
LAUNCHER
  chmod +x "${contents}/MacOS/tomdown"

  # Info.plist declares the .md association.
  cat > "${contents}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>tomdown</string>
  <key>CFBundleDisplayName</key><string>tomdown</string>
  <key>CFBundleIdentifier</key><string>dev.tomdown.tomdown</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>tomdown</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Markdown Document</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Default</string>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>md</string>
        <string>markdown</string>
        <string>mdown</string>
        <string>mkd</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
        <string>public.plain-text</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

  # Register with Launch Services so Finder picks it up.
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
  if [ -x "${lsregister}" ]; then
    "${lsregister}" -f "${app_bundle}" >/dev/null 2>&1 || true
  fi

  ln -sf "${contents}/MacOS/tomdown" "${cli_link}"

  local default_hint
  if command -v duti >/dev/null 2>&1; then
    duti -s dev.tomdown.tomdown .md all 2>/dev/null || true
    duti -s dev.tomdown.tomdown net.daringfireball.markdown all 2>/dev/null || true
    default_hint="default:   set via duti for .md (current: $(duti -x md 2>/dev/null | head -n1 || echo unknown))"
  else
    default_hint="default:   not set automatically. Either 'brew install duti' and re-run, or right-click any .md → Open With → tomdown → Always Open With."
  fi

  echo "installed: ${app_bundle}"
  echo "cli:       ${cli_link}"
  echo "${default_hint}"
  echo
  echo "Make sure ${bin_dir} is on your PATH."
  echo "Open a markdown file with:"
  echo "  open path/to/file.md           # if tomdown is the default"
  echo "  open -a tomdown path/to/file.md"
  echo "  ${cli_link} path/to/file.md"
}

case "$(uname -s)" in
  Linux*)  install_linux ;;
  Darwin*) install_macos ;;
  *)       echo "error: unsupported OS '$(uname -s)'. For Windows, use install.ps1." >&2; exit 1 ;;
esac
