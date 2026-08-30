#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Cross-build smoke: BUILD-verify the linux .so + windows .dll (core + scripts) and
# assert each is the right object format/arch AND exports the right entry symbol.
#
# This is a BUILD check, not a runtime check: a macOS host can cross-COMPILE and
# inspect ELF/PE binaries but cannot run a Linux/Windows Godot. Runtime confirmation
# needs that platform / CI (see docs/distribution.md).
#
# GATED like the web tests: if a target's cross C compiler is unavailable
# (build_cross.sh exits 3), that target is a non-fatal SKIP. Provide the toolchains via
# the cross dev shell:
#   nix develop .#cross --command bash tests/cross/run.sh
# Prints CROSS_OK when at least the checks that COULD run passed (and none failed);
# prints CROSS_SKIP when NO cross toolchain is present at all (run_all.sh reports that
# as a non-fatal SKIP — the sentinel-grep contract lives in tests/run_all.sh).
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase35"            # a project with a scripts/ dir to compile.
OUTBASE="$ROOT/tests/cross/out"
rm -rf "$OUTBASE"; mkdir -p "$OUTBASE"

# Pick the symbol tool (llvm-nm in the dev shell; objdump as fallback for PE exports).
NM="$(command -v llvm-nm nm 2>/dev/null | head -1)"
OBJDUMP="$(command -v llvm-objdump objdump 2>/dev/null | head -1)"

FAILED=0
RAN=0

# check_obj <lib> <file-grep-regex> <symbol> <human label>
check_obj() {
    local lib="$1" fre="$2" sym="$3" label="$4"
    echo "  -- $label: $lib"
    if [[ ! -f "$lib" ]]; then echo "     MISSING"; FAILED=1; return; fi
    local f; f="$(file -b "$lib")"
    echo "     file: $f"
    if ! echo "$f" | grep -Eq "$fre"; then
        echo "     FAIL: format/arch mismatch (wanted /$fre/)"; FAILED=1; return
    fi
    # Symbol export check. Scan BOTH the dynamic symbol table (-D, what dlopen sees) and
    # the regular symtab, and accept any DEFINED occurrence (nm type column != 'U'). awk
    # reads to EOF (no early exit), avoiding the `grep -q | nm` SIGPIPE+pipefail trap that
    # made an earlier version flaky by symbol position. For the Windows PE export TABLE,
    # also accept objdump -p's listing.
    local nmout
    nmout="$( { "$NM" -D "$lib" 2>/dev/null; "$NM" "$lib" 2>/dev/null; } || true )"
    if printf '%s\n' "$nmout" | awk -v s="$sym" '$NF==s && $2!="U" && $2!="u" {f=1} END{exit f?0:1}'; then
        echo "     symbol: $sym defined (nm)"
    elif [[ -n "$OBJDUMP" ]] && "$OBJDUMP" -p "$lib" 2>/dev/null | grep -qiw "$sym"; then
        echo "     symbol: $sym present (objdump export table)"
    else
        echo "     FAIL: entry symbol $sym not found"; FAILED=1; return
    fi
    echo "     OK"
}

run_target() {
    local target="$1" fre="$2" ext="$3"
    echo "== cross target: $target =="
    local out="$OUTBASE/$target"
    local rc=0
    bash "$ROOT/build/build_cross.sh" "$target" "$PROJ" "$out" || rc=$?
    if [[ $rc -eq 3 ]]; then
        echo "  SKIP: no $target cross toolchain (rc=3)"
        return
    fi
    if [[ $rc -ne 0 ]]; then
        echo "  FAIL: build_cross.sh $target exited $rc"; FAILED=1; return
    fi
    RAN=1
    check_obj "$out/libodin_godot$ext"  "$fre" "odin_godot_init"   "core $target"
    check_obj "$out/libodinscripts$ext" "$fre" "odin_scripts_boot" "scripts $target"
    check_obj "$out/libodinscripts$ext" "$fre" "odin_scripts_abi_fingerprint" "scripts ABI handshake $target"
}

echo "cross-build smoke  (root: $ROOT)"
run_target linux   "ELF 64-bit.*x86-64"            ".so"
run_target windows "PE32\+|x86-64.*(PE|MS Windows)" ".dll"

echo "=========================================================="
if [[ "$FAILED" == "1" ]]; then
    echo "CROSS_FAIL"
    exit 1
elif [[ "$RAN" == "0" ]]; then
    # Nothing was verified — say so. run_all.sh treats CROSS_SKIP as a non-fatal SKIP
    # (NOT a PASS); do not print CROSS_OK here.
    echo "CROSS_SKIP (no cross toolchains available)"
    exit 0
else
    echo "CROSS_OK"
    exit 0
fi
