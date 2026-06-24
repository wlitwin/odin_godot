#!/usr/bin/env bash
# Spike R: prove in-process dlopen/dlclose hot-reload of an Odin "scripts" dll.
# Run from repo root inside the nix shell:  nix develop --command examples/reload-spike/run.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin

ext=dylib   # macOS

echo "== build script v1 (behavior=1) =="
odin build script -build-mode:dll -define:VERSION=1 -out:bin/script_v1.$ext
echo "== build script v2 (behavior=2) =="
odin build script -build-mode:dll -define:VERSION=2 -out:bin/script_v2.$ext
echo "== build host =="
odin build host -out:bin/host

echo "== run (load v1 -> unload -> load v2, in one process) =="
./bin/host bin/script_v1.$ext bin/script_v2.$ext
