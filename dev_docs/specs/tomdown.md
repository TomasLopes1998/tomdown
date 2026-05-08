# tomdown — spec

> Status: implemented. This is a retrospective spec capturing what `tomdown`
> currently is and what it deliberately is not. Use it as the contract for
> future changes — anything outside the goals/non-goals here needs an explicit
> revision of this document.

## 1. Purpose

`tomdown` opens a single Markdown file in a browser tab with the rendering
fidelity of a GitHub README — Mermaid diagrams, GFM extensions,
syntax-highlighted code, dark/light themes — without a long-running server,
without GitHub API calls, and without a heavy desktop app.

The user's mental model is "double-click an `.md` file → it opens in the
browser like an HTML file, and stays in sync while I edit it."

## 2. Goals

- **G1.** Render any Markdown file the way GitHub's web UI renders READMEs:
  GFM (tables, task lists, strikethrough, footnotes, definition lists,
  autolinks), Pygments-highlighted fenced code, Mermaid diagrams.
- **G2.** Hot-reload — the open tab refreshes within ~1s of the file being
  saved on disk.
- **G3.** Self-terminating — when the user closes the tab, the underlying
  process exits within ~10s. No background daemons, no port pile-up.
- **G4.** Per-file isolation — each invocation gets its own random localhost
  port, so concurrent files don't collide.
- **G5.** One source of truth: a single Python script with PEP 723 inline
  dependencies, runnable on Linux, macOS, and Windows.
- **G6.** OS-native file association — double-clicking a `.md` file in the
  desktop file manager invokes `tomdown`, on all three platforms.
- **G7.** Per-user install with no admin/root/UAC required.

## 3. Non-goals

These are explicit — declining them is the whole reason `tomdown` is small.

- **N1.** Editing. `tomdown` is read-only; users edit elsewhere.
- **N2.** A directory browser, search, or any kind of multi-file UI. One
  invocation, one file, one tab.
- **N3.** Offline rendering of Mermaid. The Mermaid runtime and the
  GitHub-flavoured CSS are loaded from a CDN (jsDelivr) on first paint. No
  attempt is made to bundle them.
- **N4.** Authentication, accounts, telemetry, analytics, crash reporting.
- **N5.** Custom themes beyond the bundled `dark` / `light` toggle.
- **N6.** A long-running daemon, system service, browser extension, or tray
  icon. The whole lifecycle is bound to a single browser tab.
- **N7.** A packaged installer (`.deb`, `.dmg`, `.msi`). Install is a script
  copy + a registry/desktop edit; uninstall is the reverse.

## 4. Functional requirements

### 4.1 Rendering

- **F1.1** Input is a single UTF-8 encoded Markdown file passed as argv[1].
- **F1.2** Output is HTML rendered server-side (in-process, via
  `markdown-it-py` configured as `gfm-like`) with these plugins enabled:
  task lists, footnotes, definition lists, header anchors with permalink
  symbol `#`. `linkify` and `typographer` are on; raw HTML is allowed.
- **F1.3** Fenced code blocks with a language tag are highlighted by Pygments
  using `github-dark` (dark) and `default` (light) styles. Both stylesheets
  are emitted; CSS scopes them under `[data-theme="dark"]` /
  `[data-theme="light"]` so the active theme wins.
- **F1.4** Fenced code blocks with no language tag are rendered as plain
  `<pre><code>` (markdown-it default). No guessing.
- **F1.5** GitHub-flavoured CSS comes from
  `cdn.jsdelivr.net/npm/github-markdown-css@5` (dark + light variants
  loaded; the inactive one is `disabled`).

### 4.2 Mermaid

- **F2.1** A fenced block whose info string is exactly `mermaid` is treated
  as a Mermaid diagram, not as code.
- **F2.2** The raw Mermaid source is **not** HTML-escaped. It is JSON-encoded
  into a `<script type="application/json" data-mm="...">` tag, paired with
  an empty `<div class="mermaid-host" data-mm="...">` placeholder.
- **F2.3** A small client-side ES module copies each script's `src` into the
  paired host `<div>`, adds the `mermaid` class, then calls
  `mermaid.run({ querySelector: '.mermaid' })` once. `startOnLoad` is
  `false` to avoid the deferred-module race.
- **F2.4** Mermaid theme follows the page theme: `dark` → Mermaid `dark`,
  `light` → Mermaid `default`. Toggling the page theme re-runs Mermaid.
- **F2.5** Mermaid is loaded from
  `cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs`.

### 4.3 Server / lifecycle

- **F3.1** `tomdown <path>` resolves the path, starts a `ThreadingTCPServer`
  bound to `127.0.0.1` on a kernel-assigned free port, opens the default
  browser at `http://127.0.0.1:<port>/`, and parks on a heartbeat loop.
- **F3.2** `GET /` and `GET /<basename>` return the rendered HTML.
- **F3.3** `GET /_mtime` returns the file's current `st_mtime` as plain text.
- **F3.4** Any other request is served as a static file from the file's
  parent directory (so relative `<img src="…">` and similar work).
- **F3.5** Every request updates an in-process "last seen" timestamp.
- **F3.6** The page polls `/_mtime` every 1s. If the value increased since
  the page loaded, the tab calls `location.reload()`.
- **F3.7** If no request arrives for **8 seconds**, the main thread exits
  cleanly via `server.shutdown()`. Process exits with code 0.

### 4.4 Theme

- **F4.1** Initial theme: `localStorage['tomdown-theme']` if set, otherwise
  `prefers-color-scheme`. Default fallback is `light` only if neither
  signal indicates dark.
- **F4.2** A floating toggle button in the top-right swaps `dark` ↔ `light`,
  persists to `localStorage`, swaps the GitHub CSS, and re-renders Mermaid.
- **F4.3** No flash of unstyled content: the theme is applied via an inline
  `<script>` in `<head>` before the `<body>` parses.

### 4.5 Install / uninstall

Per-user, idempotent on all platforms.

| Platform | Where it lives | Default-handler mechanism |
|---|---|---|
| Linux  | `~/.local/bin/tomdown` (executable, shebang) + `~/.local/share/applications/tomdown.desktop` | `xdg-mime default tomdown.desktop text/markdown` (and `text/x-markdown`) |
| macOS  | `~/Applications/tomdown.app` (`.app` bundle) + `~/.local/bin/tomdown` symlink | `lsregister -f` registers the bundle; `Info.plist` declares `CFBundleDocumentTypes` with `LSHandlerRank=Default`. `duti` (optional) pins the default. |
| Windows| `%LOCALAPPDATA%\Programs\tomdown\tomdown.py` + `tomdown.cmd` shim | `HKCU\Software\Classes\.md` → ProgID `tomdown.markdown` whose `shell\open\command` runs the shim |

- **F5.1** `install.sh` dispatches on `uname -s` (Linux / Darwin).
- **F5.2** `install.ps1` is the Windows equivalent (per-user, no admin).
- **F5.3** All three install paths only modify the **current user's** scope.
  No system-wide writes, no `sudo`, no UAC prompt.
- **F5.4** Uninstallers reverse exactly what their installers did and leave
  `uv`'s cache untouched.

## 5. Non-functional requirements

- **NFR1.** Cold start (after `uv` cache warm) ≤ 1s from `tomdown file.md` to
  the browser tab opening.
- **NFR2.** Idle CPU: the page polls every 1s; the server's only steady-state
  work is responding to those polls. Effectively zero.
- **NFR3.** No filesystem writes. The script reads the input file and emits
  HTTP responses; nothing is persisted.
- **NFR4.** No outbound network calls from the Python process. The CDN
  fetches happen in the browser only, on first paint per tab.
- **NFR5.** Source size: the runtime script stays under ~300 lines so the
  whole thing remains auditable in one screen.
- **NFR6.** Dependencies are pinned by lower bound only and resolved by `uv`
  on first run; no `requirements.txt`, no `pyproject.toml`.

## 6. Edge cases (handled)

- **E1.** Mermaid label contains `&`, `<`, `>`, `"`, `'`, backslashes,
  apostrophes, or unicode — preserved byte-for-byte by the JSON-in-script
  embedding (covered by `verify.py`).
- **E2.** Mermaid source contains the literal substring `</script>` — the
  encoder escapes `<` to `<` so the script tag can't be terminated
  early.
- **E3.** Mermaid source contains U+2028 / U+2029 — escaped to ` ` /
  ` ` so the JS string literal is valid.
- **E4.** Multiple Mermaid blocks in the same document — each gets a unique
  `data-mm` id (`secrets.token_hex(4)`). Hosts and scripts are paired by id.
- **E5.** Browser tab is closed — server shuts down within 8s of the last
  poll.
- **E6.** Multiple files opened concurrently — each invocation binds a
  fresh free port; no global state is shared.
- **E7.** Relative image / link references — served as static files from the
  Markdown file's parent directory (`F3.4`).
- **E8.** File path contains spaces — handled by the OS-specific shim
  (`%~dp0` on Windows, `"$@"` in the macOS launcher).
- **E9.** File modified after the server starts — `/_mtime` reflects the
  fresh `st_mtime`; the tab reloads on the next 1s tick.

## 7. Edge cases (NOT handled — by design)

- **X1.** File is deleted while the server is running → the next render
  raises and returns a 500. Acceptable; the user closes the tab.
- **X2.** File is non-UTF-8 → `read_text(encoding="utf-8")` raises. No fallback
  detection.
- **X3.** Markdown spans more than one file (includes/transclusion) — not
  supported.
- **X4.** A second poll arrives after the 8s timer fired → race; the
  process is already exiting and the request fails. Acceptable.

## 8. Success criteria

A change to `tomdown` is acceptable iff:

1. **`./verify.py` passes** — the Mermaid round-trip invariant holds for
   every case in `verify.CASES` (special chars, literal `</script>`, U+2028,
   unicode, multi-block).
2. **Manual smoke** — open a representative `.md` with at least one Mermaid
   block, one fenced code block, one table, one task list, and one image
   reference. All render correctly in both themes.
3. **Auto-reload** — saving the file refreshes the tab within 2 seconds.
4. **Self-termination** — closing the tab causes the process to exit within
   10 seconds (verified via `pgrep -f tomdown`).
5. **Each platform's install** — `./install.sh` (Linux / macOS) or
   `install.ps1` (Windows) leaves the system in a state where double-clicking
   an `.md` file in the native file manager opens it in tomdown, and the
   matching uninstall script reverses every change.

Criterion 1 is automated. The rest are manual; they're acceptable as manual
because the tool is single-user and the surface is small.

## 9. References

- Source: [`tomdown`](../../tomdown)
- Round-trip verifier: [`verify.py`](../../verify.py)
- Linux/macOS installer: [`install.sh`](../../install.sh)
- Windows installer: [`install.ps1`](../../install.ps1)
- README: [`README.md`](../../README.md)
- PEP 723 (inline script metadata): https://peps.python.org/pep-0723/
- markdown-it-py: https://markdown-it-py.readthedocs.io/
- Mermaid: https://mermaid.js.org/
