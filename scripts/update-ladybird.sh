#!/usr/bin/env bash
# Refresh the pinned Ladybird AppImage in pkgs/ladybird-bin.nix.
#
# Upstream publishes the current AppImage and its SHA-256 at
# https://download.ladybird.org/releases.json. This rewrites the two pinned
# values in place and is a no-op when they are already current. `mcli update`
# runs it before rebuilding, so Ladybird tracks upstream releases.
set -euo pipefail

cd "$(dirname "$0")/.."

python3 - pkgs/ladybird-bin.nix https://download.ladybird.org/releases.json << 'PY'
import base64
import json
import re
import sys
import urllib.request

path, url = sys.argv[1], sys.argv[2]
with urllib.request.urlopen(url, timeout=60) as response:
    data = json.load(response)

release = data["releases"][0]
asset = next(
    download
    for download in release["downloads"]
    if download["platform"] == "Linux"
    and download.get("architecture") == "x86_64"
    and download["name"].endswith(".AppImage")
)
version = release["version"]
digest = asset["sha256"]
sri = "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()

source = open(path).read()
updated = re.sub(r'version = "[^"]+";', f'version = "{version}";', source, count=1)
updated = re.sub(r'hash = "sha256-[^"]+";', f'hash = "{sri}";', updated, count=1)

if updated == source:
    print(f"ladybird: already at {version}")
else:
    open(path, "w").write(updated)
    print(f"ladybird: pinned {version} ({digest[:12]}...)")
PY
