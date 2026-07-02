#!/usr/bin/env bash
# Pure-Odin unit tests for the runtime-reflection registration walk
# (runtime/register_class.odin) — no Godot process needed.
# Wraps `odin test tests/reflect_register -collection:godot=$ROOT` and prints
# REFLECT_REGISTER_OK on success. (The sentinel-grep contract lives in tests/run_all.sh.)
# Single-threaded: the walk appends into shared static pools, so parallel test procs
# would race them.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/reflect_register/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/reflect_register" -collection:godot="$ROOT" -define:ODIN_TEST_THREADS=1
echo "REFLECT_REGISTER_OK"
