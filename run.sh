#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if command -v qs >/dev/null 2>&1; then
    exec qs -p "$HERE/shell.qml"
elif command -v quickshell >/dev/null 2>&1; then
    exec quickshell -p "$HERE/shell.qml"
else
    echo "Radio Atlas Lite: Quickshell was not found." >&2
    echo "You already have it if DMS is running through Quickshell; otherwise install Quickshell first." >&2
    exit 127
fi
