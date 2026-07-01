#!/usr/bin/env bash
# Build the core dll + run the Phase 1 headless milestone test. Greps for PHASE1_OK.
# (The sentinel-grep contract — which string means PASS — lives in tests/run_all.sh.)
# Phase 1 only exercises the ScriptLanguageExtension skeleton (no compiled scripts dll
# is required: hello.odin registers no class, so the engine gets a placeholder instance).
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase1/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase1"

# Build the core dll into tests/phase1/bin (core/build.sh targets that path).
bash "$ROOT/core/build.sh"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the milestone test.
"$GODOT" --headless --path "$PROJ" --script test_phase1.gd
