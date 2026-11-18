#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
odin test "$ROOT/tests/editor_authoring" -collection:godot="$ROOT"
exec python3 "$ROOT/tests/editor_authoring/run.py"
