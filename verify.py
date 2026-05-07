#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "markdown-it-py>=3.0",
#   "mdit-py-plugins>=0.4",
#   "linkify-it-py>=2.0",
#   "Pygments>=2.17",
# ]
# ///
"""
Verify the round-trip invariant for Mermaid blocks:

    For any Mermaid source string, the text the browser would feed to
    Mermaid.run() must equal the original source byte-for-byte (modulo a
    single trailing newline added by markdown-it's fence parser).

This simulates the client side: parse the JSON inside the generated
<script type="application/json" data-mm="..."> tag the same way JSON.parse
would, and compare against the original.
"""

from __future__ import annotations

import importlib.util
import importlib.machinery
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
loader = importlib.machinery.SourceFileLoader("tomdown", str(HERE / "tomdown"))
spec = importlib.util.spec_from_loader("tomdown", loader)
assert spec is not None
tomdown = importlib.util.module_from_spec(spec)
loader.exec_module(tomdown)


SCRIPT_RE = re.compile(
    r'<script type="application/json" data-mm="(?P<id>[0-9a-f]+)">(?P<body>.*?)</script>',
    re.DOTALL,
)


def render_md(text: str) -> str:
    return tomdown.MD.render(text)


def extract_sources(html: str) -> list[str]:
    out = []
    for m in SCRIPT_RE.finditer(html):
        # JSON.parse in JS == json.loads in Python for our content.
        out.append(json.loads(m.group("body"))["src"])
    return out


def fence(content: str) -> str:
    return f"```mermaid\n{content}\n```\n"


CASES: list[tuple[str, str]] = [
    ("plain", "graph TD\n    A --> B"),
    ("ampersand label", 'graph LR\n    A["R&D Team"] --> B["Q&A"]'),
    ("html-like label", 'graph TD\n    A["<button>Click</button>"] --> B'),
    ("greater/less in edge", "graph LR\n    A --> B\n    B --> C\n    C --> A"),
    ("quotes in label", 'graph TD\n    A["She said \\"hi\\""] --> B'),
    ("apostrophe", "graph TD\n    A[Bob's box] --> B"),
    (
        "sequence diagram",
        "sequenceDiagram\n    Alice->>Bob: Hello\n    Bob-->>Alice: Hi",
    ),
    (
        "subgraph + special",
        'graph TB\n  subgraph "R&D <core>"\n    a[<<svc>>] --> b\n  end',
    ),
    (
        "literal </script>",
        'graph TD\n    A["contains </script> string"] --> B',
    ),
    ("unicode", "graph LR\n    A[Olá 世界 🚀] --> B[café]"),
    (
        "U+2028 line sep",
        "graph TD\n    A[line break] --> B",
    ),
    ("backslashes", "graph TD\n    A[C:\\\\path\\\\to] --> B"),
]


def main() -> int:
    failures: list[str] = []
    for name, src in CASES:
        html = render_md(fence(src))
        extracted = extract_sources(html)
        if len(extracted) != 1:
            failures.append(f"{name}: expected 1 mermaid block, got {len(extracted)}")
            continue
        # markdown-it adds a trailing newline; tolerate that.
        got = extracted[0].rstrip("\n")
        want = src.rstrip("\n")
        if got != want:
            failures.append(f"{name}:\n  want: {want!r}\n  got:  {got!r}")
        else:
            print(f"  PASS  {name}")

    # Multi-block doc
    multi = fence("graph TD\n    A --> B") + "\n" + fence("graph LR\n    X --> Y")
    html = render_md(multi)
    sources = extract_sources(html)
    if len(sources) != 2:
        failures.append(f"multi-block: expected 2 blocks, got {len(sources)}")
    else:
        print("  PASS  multi-block")

    if failures:
        print("\nFAILURES:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("\nall round-trip checks pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
