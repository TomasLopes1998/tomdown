# tomdown

Local Markdown viewer that renders in your browser with **Mermaid diagrams**, **GFM** (tables, task lists, strikethrough, footnotes, def lists), **syntax-highlighted code**, a **dark GitHub theme**, **auto-reload on save**, and **self-termination when the tab closes**.

No GitHub API calls, no rate limits. One CDN fetch on page load (Mermaid.js + theme CSS); rendering itself is local.

## Requirements

- Linux with `xdg-utils` (`xdg-mime`, `xdg-open`)
- [`uv`](https://docs.astral.sh/uv/) (the script is a [PEP 723](https://peps.python.org/pep-0723/) inline-deps script — first run resolves a cached venv, subsequent runs are instant)
- A modern desktop browser (any Chromium/Firefox/WebKit)

## Install

From the repo root:

```bash
./tools/tomdown/install.sh
```

This will:

1. Copy `tomdown` to `~/.local/bin/tomdown`.
2. Write `~/.local/share/applications/tomdown.desktop`.
3. Set it as the default handler for `text/markdown` and `text/x-markdown` via `xdg-mime`.

Make sure `~/.local/bin` is on your `PATH` (most Linux distros add it automatically; if not, add it to your shell rc).

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

```bash
./tools/tomdown/uninstall.sh
```

Removes the binary, desktop entry, and resets the mime defaults. Does not delete `uv`'s cached venv.

## How it works

`tomdown` is a single Python script with PEP 723 inline metadata declaring its dependencies (`markdown-it-py`, `mdit-py-plugins`, `linkify-it-py`, `Pygments`). The shebang `#!/usr/bin/env -S uv run --script` makes `uv` resolve them into a cached environment on first run.

When invoked:

1. Reads the `.md` file, renders to HTML with GFM extensions and Pygments-highlighted code blocks.
2. Wraps the HTML in a template loading `github-markdown-css` (dark) + `mermaid.js`.
3. Starts a `ThreadingTCPServer` on `127.0.0.1` on a random free port and opens the browser.
4. The page polls `/_mtime` every second; if the file changed, it reloads.
5. The same poll doubles as a heartbeat — if no poll arrives for 8s, the server shuts down.

The whole thing is ~150 lines. See `tomdown` in this folder.

### Mermaid embedding

Mermaid blocks are not HTML-escaped into a `<pre class="mermaid">`. Instead, the raw source is JSON-encoded into a `<script type="application/json" data-mm="…">` tag (with `<`, `>`, `&`, U+2028, U+2029 escaped to their `\uXXXX` forms so the script tag can't be terminated or break JS string literals). On load, a small module script copies each tag's source into a paired `<div class="mermaid-host">`, adds the `mermaid` class, and calls `mermaid.run()` explicitly (`startOnLoad: false`).

This avoids two common failure modes: (a) HTML entity round-tripping that breaks Mermaid when labels contain `&`, `<`, `>`, or quotes, and (b) the deferred-module-vs-`startOnLoad` race.

## Verify

`./verify.py` runs a round-trip invariant check: for a battery of tricky Mermaid sources (special chars, literal `</script>`, U+2028, unicode, multi-block), it parses the generated JSON the same way `JSON.parse` would and asserts the source comes back byte-for-byte equal to the input.

## Troubleshooting

- **`uv: command not found`** — install [uv](https://docs.astral.sh/uv/getting-started/installation/) first.
- **Browser opens but page doesn't load** — check `pgrep -f tomdown`; the script may have already self-terminated. Try opening from a terminal to see stderr.
- **First launch is slow** — `uv` is downloading deps into its cache. Subsequent launches are instant.
- **Mermaid diagram shows as raw code** — make sure the fence is exactly ` ```mermaid ` (lowercase, no extra space).
- **Default app didn't change** — some desktop environments cache mime associations. Log out and back in, or run `update-desktop-database ~/.local/share/applications`.
