#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

path = Path("libs/hbb_common/src/webrtc.rs")
source = path.read_text(encoding="utf-8")
pattern = re.compile(
    r"(static DEFAULT_ICE_SERVERS: \\[&str; )\\d+(\\] = \\[\\n)(.*?)(\\n\\];)",
    re.DOTALL,
)
matches = list(pattern.finditer(source))
if len(matches) != 1:
    raise SystemExit(
        f"Expected exactly one DEFAULT_ICE_SERVERS array in {path}; found {len(matches)}"
    )

match = matches[0]
existing = re.findall(r'"([^"]+)"', match.group(3))
if not existing:
    raise SystemExit("Could not read existing STUN defaults; refusing to replace them.")

bilibili = [
    "stun:stun6.chat.bilibili.com:3478",
    "stun:stun.chat.bilibili.com:3478",
]
fallbacks = [url for url in existing if url not in bilibili]
if not fallbacks:
    raise SystemExit("No upstream STUN fallbacks remain; refusing to create a Bilibili-only list.")

servers = bilibili + fallbacks
replacement = (
    match.group(1)
    + str(len(servers))
    + match.group(2)
    + "\\n".join(f'    "{url}",' for url in servers)
    + match.group(4)
)
patched = source[: match.start()] + replacement + source[match.end() :]

updated = list(pattern.finditer(patched))
if len(updated) != 1:
    raise SystemExit("Patched source no longer contains exactly one STUN defaults array.")
actual = re.findall(r'"([^"]+)"', updated[0].group(3))
if actual != servers or actual[:2] != bilibili:
    raise SystemExit(f"Unexpected STUN order after patch: {actual}")

path.write_text(patched, encoding="utf-8")
print("STUN order: Bilibili IPv6, Bilibili IPv4, then upstream fallbacks.")
print(f"Preserved {len(fallbacks)} upstream fallback server(s).")
PY
