# tomdown

Local Markdown viewer that renders in your browser with **Mermaid diagrams**, **GFM** (tables, task lists, strikethrough, footnotes, def lists), **syntax-highlighted code**, a **dark GitHub theme**, **auto-reload on save**, and **self-termination when the tab closes**.

No GitHub API calls, no rate limits. One CDN fetch on page load (Mermaid.js + theme CSS); rendering itself is local.

## Requirements

- [`uv`](https://docs.astral.sh/uv/) (the script is a [PEP 723](https://peps.python.org/pep-0723/) inline-deps script — first run resolves a cached venv, subsequent runs are instant)
- A modern desktop browser (any Chromium/Firefox/WebKit)
- One of:
  - **Linux** with `xdg-utils` (`xdg-mime`, `xdg-open`)
  - **macOS** 10.13+ (optional: [`duti`](https://github.com/moretension/duti) — `brew install duti` — to set the `.md` default automatically)
  - **Windows** 10 / 11

## Install (Linux)

From the repo root:

```bash
./install.sh
```

This will:

1. Copy `tomdown` to `~/.local/bin/tomdown`.
2. Write `~/.local/share/applications/tomdown.desktop`.
3. Set it as the default handler for `text/markdown` and `text/x-markdown` via `xdg-mime`.

Make sure `~/.local/bin` is on your `PATH` (most Linux distros add it automatically; if not, add it to your shell rc).

## Install (macOS)

From the repo root:

```bash
./install.sh
```

The same script auto-detects macOS via `uname -s` and runs the macOS path. It will:

1. Build a real `tomdown.app` bundle in `~/Applications/tomdown.app`.
   - `Contents/Resources/tomdown.py` — the Python script (shebang stripped).
   - `Contents/MacOS/tomdown` — a tiny bash launcher that re-invokes `uv run --script` on the script. It also injects `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin` into `PATH` so `uv` resolves under Launch Services' minimal env, and strips the `-psn_X_X` arg that Launch Services sometimes passes.
   - `Contents/Info.plist` — declares the bundle and a `CFBundleDocumentTypes` entry for `.md`, `.markdown`, `.mdown`, `.mkd` with `LSHandlerRank=Default`.
2. Register the bundle with Launch Services (`lsregister -f`) so Finder picks it up.
3. Symlink the launcher to `~/.local/bin/tomdown` for terminal use. Make sure that directory is on your `PATH`.
4. If [`duti`](https://github.com/moretension/duti) is installed, set tomdown as the default for `.md` and the `net.daringfireball.markdown` UTI. Otherwise, do this once manually: right-click any `.md` in Finder → **Open With → Other…**, pick `tomdown.app`, tick **Always Open With**.

Open a Markdown file with:

```bash
open path/to/file.md            # if tomdown is the default
open -a tomdown path/to/file.md
tomdown path/to/file.md
```

## Install (Windows)

From the repo root, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

This is a per-user install — no admin/UAC prompt. It will:

1. Copy the script to `%LOCALAPPDATA%\Programs\tomdown\tomdown.py` and a `tomdown.cmd` shim alongside it.
2. Add that directory to your **user** `PATH`.
3. Register a per-user ProgID (`tomdown.markdown`) under `HKCU\Software\Classes` and set it as the default for `.md` files.

Open a new terminal afterwards so the updated `PATH` is picked up. The first time you double-click a `.md` file in Explorer, Windows may show the "How do you want to open this?" prompt — pick **tomdown** and tick *Always use this app*. That prompt is a Windows policy and the installer can't dismiss it on your behalf.

## Usage

Open any `.md` file:

```bash
xdg-open path/to/file.md
# or directly
tomdown path/to/file.md
```

In a file manager (Files/Nautilus/Dolphin), double-click works too.

### What you get

- **Mermaid** — fenced ` ```mermaid ` blocks render as SVG diagrams (dark theme).
- **Auto-reload** — saving the file refreshes the tab within ~1s.
- **Self-termination** — server exits ~8s after the tab is closed; nothing piles up.
- **Random port** — every file gets its own server, no collisions.
- **Local rendering** — Markdown → HTML happens in-process via `markdown-it-py`. Only Mermaid.js and the GitHub-dark CSS are pulled from a CDN (jsDelivr) on first paint.

## Uninstall

Linux / macOS:

```bash
./uninstall.sh
```

- **Linux** — removes `~/.local/bin/tomdown` and the desktop entry, resets the mime defaults.
- **macOS** — unregisters the bundle from Launch Services, removes `~/Applications/tomdown.app` and the `~/.local/bin/tomdown` symlink. If `duti` is installed and `.md` was still pointing at tomdown, it bounces the default back to TextEdit.

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Removes the install dir, drops the ProgID from `HKCU\Software\Classes`, clears the `.md` default if it was pointing at tomdown, and strips the install dir from your user `PATH`.

Neither uninstaller deletes `uv`'s cached venv.

## How it works

`tomdown` is a single Python script with PEP 723 inline metadata declaring its dependencies (`markdown-it-py`, `mdit-py-plugins`, `linkify-it-py`, `Pygments`). The shebang `#!/usr/bin/env -S uv run --script` makes `uv` resolve them into a cached environment on first run.

When invoked:

1. Reads the `.md` file, renders to HTML with GFM extensions and Pygments-highlighted code blocks.
2. Wraps the HTML in a template loading `github-markdown-css` (dark) + `mermaid.js`.
3. Starts a `ThreadingTCPServer` on `127.0.0.1` on a random free port and opens the browser.
4. The page polls `/_mtime` every second; if the file changed, it reloads.
5. The same poll doubles as a heartbeat — if no poll arrives for 8s, the server shuts down.

The whole thing is ~150 lines. See `tomdown` in this folder.

### File-association mechanics by platform

Same Python script everywhere; only the OS glue differs.

| Platform | Where it lives | How `.md` opens it |
|---|---|---|
| Linux  | `~/.local/bin/tomdown` (executable, shebang dispatched) + `~/.local/share/applications/tomdown.desktop` | `xdg-mime default tomdown.desktop text/markdown` |
| macOS  | `~/Applications/tomdown.app` (real `.app` bundle) + `~/.local/bin/tomdown` symlink for CLI use | `lsregister -f` registers the bundle; `Info.plist` declares `CFBundleDocumentTypes` with `LSHandlerRank=Default`; `duti` (optional) pins it as the default |
| Windows| `%LOCALAPPDATA%\Programs\tomdown\tomdown.py` + `tomdown.cmd` shim | `HKCU\Software\Classes\.md` → ProgID `tomdown.markdown` whose `shell\open\command` runs the shim |

The macOS `.app` is the only "real bundle" — Launch Services binds defaults to bundle identifiers, not arbitrary executables, so a bundle is unavoidable if we want Finder double-click to work. The bundle's `MacOS/tomdown` is just a 10-line bash launcher that calls `uv run --script` on `Resources/tomdown.py`.

### Mermaid embedding

Mermaid blocks are not HTML-escaped into a `<pre class="mermaid">`. Instead, the raw source is JSON-encoded into a `<script type="application/json" data-mm="…">` tag (with `<`, `>`, `&`, U+2028, U+2029 escaped to their `\uXXXX` forms so the script tag can't be terminated or break JS string literals). On load, a small module script copies each tag's source into a paired `<div class="mermaid-host">`, adds the `mermaid` class, and calls `mermaid.run()` explicitly (`startOnLoad: false`).

This avoids two common failure modes: (a) HTML entity round-tripping that breaks Mermaid when labels contain `&`, `<`, `>`, or quotes, and (b) the deferred-module-vs-`startOnLoad` race.

## Verify

`./verify.py` runs a round-trip invariant check: for a battery of tricky Mermaid sources (special chars, literal `</script>`, U+2028, unicode, multi-block), it parses the generated JSON the same way `JSON.parse` would and asserts the source comes back byte-for-byte equal to the input.

## Troubleshooting

- **`uv: command not found`** — install [uv](https://docs.astral.sh/uv/getting-started/installation/) first. On macOS, if it works in your shell but Finder double-click fails, the launcher already prepends `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin` to `PATH` — if your `uv` lives somewhere else, edit `~/Applications/tomdown.app/Contents/MacOS/tomdown`.
- **Browser opens but page doesn't load** — check `pgrep -f tomdown`; the script may have already self-terminated. Try opening from a terminal to see stderr.
- **First launch is slow** — `uv` is downloading deps into its cache. Subsequent launches are instant.
- **Mermaid diagram shows as raw code** — make sure the fence is exactly ` ```mermaid ` (lowercase, no extra space).
- **Linux: default app didn't change** — some desktop environments cache mime associations. Log out and back in, or run `update-desktop-database ~/.local/share/applications`.
- **macOS: Finder still opens .md in TextEdit / Xcode** — Launch Services has its own cache. Either install `duti` and re-run `./install.sh`, or right-click an `.md` file → **Open With → Other…** → pick `tomdown.app` → tick **Always Open With**. As a last resort, rebuild the LS database: `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user`.
- **macOS: Gatekeeper blocks the bundle ("damaged or can't be opened")** — only happens if the `.app` is moved across systems with quarantine. Clear it with `xattr -dr com.apple.quarantine ~/Applications/tomdown.app`.
