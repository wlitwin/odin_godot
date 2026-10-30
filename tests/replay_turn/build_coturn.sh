#!/usr/bin/env bash
set -euo pipefail
# Isolated source build, useful on macOS where the pinned Nix derivation is marked
# broken. No system installation. Requires CMake, pkg-config, OpenSSL, libevent
# and SQLite development libraries (e.g. an existing native package toolchain).
build="${COTURN_BUILD:-$(mktemp -d)}";mkdir -p "$build"
source="${COTURN_SOURCE:-}"
if [[ -z "$source" ]];then
 source="$(nix build --no-link --print-out-paths --impure --expr 'let f=builtins.getFlake "github:NixOS/nixpkgs/549bd84d6279f9852cae6225e372cc67fb91a4c1"; p=import f.outPath {system=builtins.currentSystem; config.allowBroken=true;}; in p.coturn.src')"
fi
cmake -S "$source" -B "$build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="${COTURN_PREFIX:-/opt/local}" -DWITH_MYSQL=OFF >"$build/configure.log" 2>&1
cmake --build "$build" --target turnserver -j 4 >"$build/build.log" 2>&1
echo "$build/bin/turnserver"
