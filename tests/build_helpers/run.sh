#!/usr/bin/env bash
# Build-helper parity regression: exercise the Bash helper directly and, when a
# PowerShell host is available, drive build_scripts.ps1 end-to-end with the same fake
# compiler. No Odin/MSVC toolchain is needed; the fixture observes cache/publish policy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"

fail() { echo "BUILD_HELPERS_FAIL: $*" >&2; exit 1; }

# common.sh owns the one Bash EXIT trap. Register the whole fixture after sourcing it.
source "$REPO_ROOT/build/common.sh"
odin_gd_cleanup_on_exit "$WORK"

FIXTURE_ROOT="$WORK/root"
CACHE="$WORK/cache"
OUT_DIR="$WORK/out"
LOG="$WORK/fake-odin.log"
FAKE_ODIN="$WORK/fake-odin"
FAKE_SGEN="$WORK/fake-scriptgen"
mkdir -p "$FIXTURE_ROOT/scriptgen" "$FIXTURE_ROOT/decl" "$FIXTURE_ROOT/pkg" "$OUT_DIR"
printf 'package scriptgen\n' >"$FIXTURE_ROOT/scriptgen/main.odin"
printf 'package decl\n' >"$FIXTURE_ROOT/decl/schema.odin"
printf 'package pkg\n' >"$FIXTURE_ROOT/pkg/main.odin"

cat >"$FAKE_SGEN" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_SGEN_LOG:?}"
SH
chmod +x "$FAKE_SGEN"

cat >"$FAKE_ODIN" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "version" ]]; then
    echo "fake-odin 1.0"
    exit 0
fi
[[ "${1:-}" == "build" ]] || exit 2
pkg="${2:-}"
shift 2
out=""
for arg in "$@"; do
    case "$arg" in -out:*) out="${arg#-out:}" ;; esac
done
[[ -n "$out" ]] || exit 3
printf '%s|%s|%s\n' "$pkg" "$out" "$*" >>"${FAKE_ODIN_LOG:?}"
mkdir -p "$(dirname "$out")"
printf 'partial:%s\n' "$pkg" >"$out"
printf 'intermediate\n' >"$out.obj"
if [[ -n "${FAKE_ODIN_SLEEP:-}" ]]; then sleep "$FAKE_ODIN_SLEEP"; fi
if [[ -n "${FAKE_ODIN_FAIL_PACKAGE:-}" && "$pkg" == *"$FAKE_ODIN_FAIL_PACKAGE"* ]]; then
    echo "fake compile failure: $pkg" >&2
    exit 42
fi
if [[ "$pkg" == */scriptgen || "$pkg" == *\\scriptgen ]]; then
    cp "${FAKE_SCRIPTGEN_TEMPLATE:?}" "$out"
    chmod +x "$out"
else
    printf 'complete:%s:%s\n' "$pkg" "${FAKE_PAYLOAD:-default}" >"$out"
fi
if [[ "${FAKE_EMIT_DEBUG_SYMBOLS:-0}" == "1" ]]; then
    case "$out" in
        *.dylib) mkdir -p "$out.dSYM"; printf symbols >"$out.dSYM/info" ;;
        *)       printf symbols >"${out%.*}.pdb" ;;
    esac
fi
SH
chmod +x "$FAKE_ODIN"

export FAKE_ODIN_LOG="$LOG"
export FAKE_SCRIPTGEN_TEMPLATE="$FAKE_SGEN"
export FAKE_SGEN_LOG="$WORK/fake-scriptgen.log"
export ODIN="$FAKE_ODIN"
export ODIN_GODOT_TOOL_CACHE_DIR="$CACHE"
ROOT="$FIXTURE_ROOT"

# Bash scriptgen cache: identical inputs hit; a path-only source rename and compiler
# byte change each invalidate. The cache key includes both, not only mtimes/content.
build_scriptgen
first_sgen="$SGEN"
[[ -x "$first_sgen" ]] || fail "Bash scriptgen cache did not publish an executable"
build_scriptgen
[[ "$SGEN" == "$first_sgen" ]] || fail "identical Bash inputs changed the cache key"
[[ "$(grep -c '/scriptgen|' "$LOG")" == "1" ]] || fail "identical Bash inputs rebuilt scriptgen"

mv "$FIXTURE_ROOT/decl/schema.odin" "$FIXTURE_ROOT/decl/schema_renamed.odin"
build_scriptgen
[[ "$SGEN" != "$first_sgen" ]] || fail "Bash cache ignored a source-path rename"
[[ "$(grep -c '/scriptgen|' "$LOG")" == "2" ]] || fail "Bash path rename did not rebuild scriptgen"
second_sgen="$SGEN"

printf '\n# compiler bytes v2\n' >>"$FAKE_ODIN"
build_scriptgen
[[ "$SGEN" != "$second_sgen" ]] || fail "Bash cache ignored changed compiler bytes"
[[ "$(grep -c '/scriptgen|' "$LOG")" == "3" ]] || fail "Bash compiler change did not rebuild scriptgen"
last_good_sgen="$SGEN"

# A failed cache fill removes its candidate immediately and leaves prior entries usable.
printf '// force a new cache key\n' >>"$FIXTURE_ROOT/decl/schema_renamed.odin"
export FAKE_ODIN_FAIL_PACKAGE=scriptgen
if build_scriptgen; then fail "Bash failed scriptgen build unexpectedly succeeded"; fi
unset FAKE_ODIN_FAIL_PACKAGE
[[ -x "$last_good_sgen" ]] || fail "Bash failed cache fill damaged the last good tool"
if find "$CACHE" -type d -name '.scriptgen.build.*' -print -quit | grep -q .; then
    fail "Bash failed cache fill left a staging directory"
fi

# Bash DLL publication: failure preserves both live artifacts, removes intermediates,
# and reclaims a dead producer's stage. Success publishes complete bytes and invalidates
# an old dSYM when the new build emits none.
LIVE="$OUT_DIR/libfixture.dylib"
printf 'old-live\n' >"$LIVE"
mkdir -p "$LIVE.dSYM"
printf 'old-symbols\n' >"$LIVE.dSYM/info"
mkdir -p "$OUT_DIR/.libfixture.build.2147483647.abandoned"
printf junk >"$OUT_DIR/.libfixture.build.2147483647.abandoned/object.o"
export FAKE_ODIN_FAIL_PACKAGE=pkg
if atomic_odin_dll "$FIXTURE_ROOT/pkg" "$LIVE" -debug; then
    fail "Bash failed DLL build unexpectedly succeeded"
fi
unset FAKE_ODIN_FAIL_PACKAGE
[[ "$(cat "$LIVE")" == "old-live" ]] || fail "Bash failed DLL build replaced the live library"
[[ "$(cat "$LIVE.dSYM/info")" == "old-symbols" ]] || fail "Bash failed DLL build replaced live symbols"
if find "$OUT_DIR" -type d -name '.libfixture.build.*' -print -quit | grep -q .; then
    fail "Bash failed DLL build left current or stale stages"
fi

FAKE_PAYLOAD=bash-new atomic_odin_dll "$FIXTURE_ROOT/pkg" "$LIVE" -debug
grep -q 'bash-new' "$LIVE" || fail "Bash DLL success did not publish complete bytes"
[[ ! -e "$LIVE.dSYM" ]] || fail "Bash DLL success retained stale debug symbols"

# Two simultaneous publishers must use disjoint stages. Either complete result may win;
# a partial candidate may never become visible and neither build may delete the other.
export FAKE_ODIN_SLEEP=0.15
(FAKE_PAYLOAD=concurrent-a atomic_odin_dll "$FIXTURE_ROOT/pkg" "$LIVE" -debug) &
pid_a=$!
(FAKE_PAYLOAD=concurrent-b atomic_odin_dll "$FIXTURE_ROOT/pkg" "$LIVE" -debug) &
pid_b=$!
wait "$pid_a"
wait "$pid_b"
unset FAKE_ODIN_SLEEP
grep -Eq 'concurrent-(a|b)' "$LIVE" || fail "Bash concurrent publish exposed incomplete bytes"
if find "$OUT_DIR" -type d -name '.libfixture.build.*' -print -quit | grep -q .; then
    fail "Bash concurrent publish left stages"
fi
echo "  ok  Bash cache invalidation, failure recovery, stale cleanup, and concurrent publish"

# PowerShell Core runs cross-platform, so this drives the real Windows helper rather
# than asserting textual similarity. Set POWERSHELL explicitly in CI if its command has
# a nonstandard name. A host without PowerShell reports a skip but keeps the Bash gate.
PSH="${POWERSHELL:-}"
if [[ -z "$PSH" ]]; then
    if command -v pwsh >/dev/null 2>&1; then
        PSH="pwsh"
    elif command -v powershell >/dev/null 2>&1; then
        PSH="powershell"
    fi
fi
if [[ -z "$PSH" ]]; then
    echo "  SKIP PowerShell parity runtime (pwsh/powershell not installed)"
    echo "BUILD_HELPERS_OK"
    exit 0
fi
echo "  -> PowerShell parity runtime: $PSH"

PS_PROJ="$WORK/ps-project"
PS_ROOT="$PS_PROJ/addons/odin_godot"
PS_CACHE="$WORK/ps-cache"
mkdir -p "$PS_ROOT/scriptgen" "$PS_ROOT/decl" "$PS_ROOT/core" \
    "$PS_PROJ/scripts" "$PS_PROJ/modules/zeta" "$PS_PROJ/modules/empty" "$PS_PROJ/bin"
printf 'package scriptgen\n' >"$PS_ROOT/scriptgen/main.odin"
printf 'package decl\n' >"$PS_ROOT/decl/schema.odin"
printf 'package core\n' >"$PS_ROOT/core/main.odin"
printf 'package game\n' >"$PS_PROJ/scripts/main.odin"
printf 'package zeta\n' >"$PS_PROJ/modules/zeta/main.odin"
PS_SCRIPT="$REPO_ROOT/build/build_scripts.ps1"
export ODIN_GODOT_TOOL_CACHE_DIR="$PS_CACHE"
unset SGEN_BIN
: >"$LOG"

run_ps() {
    "$PSH" -NoLogo -NoProfile -File "$PS_SCRIPT" \
        -Root "$PS_ROOT" -Project "$PS_PROJ" -Odin "$FAKE_ODIN" "$@"
}
run_ps_ok() {
    local log="$1"; shift
    if ! run_ps "$@" >"$log" 2>&1; then
        tail -n 30 "$log" >&2
        fail "PowerShell parity build failed (log: $log)"
    fi
}

# Parse + execute the real script, then prove cache hit/path/compiler invalidation.
printf 'stale-pdb\n' >"$PS_PROJ/bin/libodinscripts.pdb"
run_ps_ok "$WORK/ps-first.log" -SkipCore -SkipModules
if [[ ! -f "$PS_PROJ/bin/libodinscripts.dll" ]]; then
    tail -n 30 "$WORK/ps-first.log" >&2
    find "$PS_PROJ" -maxdepth 4 -print >&2
    fail "PowerShell did not publish the scripts DLL"
fi
[[ ! -e "$PS_PROJ/bin/libodinscripts.pdb" ]] || fail "PowerShell retained stale PDB symbols"
[[ "$(grep -c 'scriptgen|' "$LOG")" == "1" ]] || fail "PowerShell first run did not build scriptgen once"
run_ps_ok "$WORK/ps-hit.log" -SkipCore -SkipModules
[[ "$(grep -c 'scriptgen|' "$LOG")" == "1" ]] || fail "PowerShell identical inputs rebuilt scriptgen"
grep -q 'scriptgen cache hit' "$WORK/ps-hit.log" || fail "PowerShell cache hit was not reported"

mv "$PS_ROOT/decl/schema.odin" "$PS_ROOT/decl/schema_renamed.odin"
run_ps_ok "$WORK/ps-rename.log" -SkipCore -SkipModules
[[ "$(grep -c 'scriptgen|' "$LOG")" == "2" ]] || fail "PowerShell cache ignored a source-path rename"
printf '\n# compiler bytes v3\n' >>"$FAKE_ODIN"
run_ps_ok "$WORK/ps-compiler.log" -SkipCore -SkipModules
[[ "$(grep -c 'scriptgen|' "$LOG")" == "3" ]] || fail "PowerShell cache ignored changed compiler bytes"

# A failed new cache fill has no candidate leak and does not touch the live DLL.
printf 'ps-live-before-cache-failure\n' >"$PS_PROJ/bin/libodinscripts.dll"
printf '// new cache key\n' >>"$PS_ROOT/decl/schema_renamed.odin"
export FAKE_ODIN_FAIL_PACKAGE=scriptgen
if run_ps -SkipCore -SkipModules >"$WORK/ps-cache-fail.log" 2>&1; then
    fail "PowerShell failed scriptgen build unexpectedly succeeded"
fi
unset FAKE_ODIN_FAIL_PACKAGE
grep -q 'ps-live-before-cache-failure' "$PS_PROJ/bin/libodinscripts.dll" \
    || fail "PowerShell failed cache fill touched the live DLL"
if find "$PS_CACHE" -type d -name '.scriptgen.build.*' -print -quit | grep -q .; then
    fail "PowerShell failed cache fill left a staging directory"
fi

# A failed DLL compile preserves DLL+PDB and removes its own plus abandoned stages.
export SGEN_BIN="$FAKE_SGEN"
printf 'ps-live\n' >"$PS_PROJ/bin/libodinscripts.dll"
printf 'ps-symbols\n' >"$PS_PROJ/bin/libodinscripts.pdb"
mkdir -p "$PS_PROJ/bin/.libodinscripts.build.2147483647.abandoned"
printf junk >"$PS_PROJ/bin/.libodinscripts.build.2147483647.abandoned/object.obj"
export FAKE_ODIN_FAIL_PACKAGE=scripts
if run_ps -SkipCore -SkipModules >"$WORK/ps-dll-fail.log" 2>&1; then
    fail "PowerShell failed DLL build unexpectedly succeeded"
fi
unset FAKE_ODIN_FAIL_PACKAGE
[[ "$(cat "$PS_PROJ/bin/libodinscripts.dll")" == "ps-live" ]] \
    || fail "PowerShell failed DLL build replaced the live library"
[[ "$(cat "$PS_PROJ/bin/libodinscripts.pdb")" == "ps-symbols" ]] \
    || fail "PowerShell failed DLL build replaced live symbols"
ps_stages="$(find "$PS_PROJ/bin" -type d -name '.libodinscripts.build.*' -print)"
if [[ -n "$ps_stages" ]]; then
    fail "PowerShell failed DLL build left current or stale stages: $ps_stages"
fi

# Module discovery and SCRIPT_BUILD_FLAGS mirror Bash; sourceless modules stay skipped.
export SCRIPT_BUILD_FLAGS='-define:PARITY=1 -o:speed'
run_ps_ok "$WORK/ps-modules.log" -SkipCore
unset SCRIPT_BUILD_FLAGS
[[ -f "$PS_PROJ/bin/libodinscripts_zeta.dll" ]] || fail "PowerShell did not build a sourced module"
[[ ! -e "$PS_PROJ/bin/libodinscripts_empty.dll" ]] || fail "PowerShell built a sourceless module"
grep -q "skipping module 'empty'" "$WORK/ps-modules.log" || fail "PowerShell did not report a sourceless module"
grep 'scripts|' "$LOG" | grep -q -- '-define:PARITY=1.*-o:speed' \
    || fail "PowerShell did not forward SCRIPT_BUILD_FLAGS"

# Finally race two real helper processes against one output. Unique staging prevents the
# fixed-name collision this test is specifically guarding against.
export FAKE_ODIN_SLEEP=0.15
run_ps -SkipCore -SkipModules >"$WORK/ps-concurrent-a.log" 2>&1 &
ps_a=$!
run_ps -SkipCore -SkipModules >"$WORK/ps-concurrent-b.log" 2>&1 &
ps_b=$!
if ! wait "$ps_a"; then
    tail -n 30 "$WORK/ps-concurrent-a.log" >&2
    fail "first concurrent PowerShell publisher failed"
fi
if ! wait "$ps_b"; then
    tail -n 30 "$WORK/ps-concurrent-b.log" >&2
    fail "second concurrent PowerShell publisher failed"
fi
unset FAKE_ODIN_SLEEP SGEN_BIN
grep -q 'complete:' "$PS_PROJ/bin/libodinscripts.dll" \
    || fail "PowerShell concurrent publish exposed incomplete bytes"
if find "$PS_PROJ/bin" -type d -name '.libodinscripts.build.*' -print -quit | grep -q .; then
    fail "PowerShell concurrent publish left stages"
fi

echo "  ok  PowerShell cache invalidation, failure recovery, modules, flags, stale cleanup, and concurrent publish"
echo "BUILD_HELPERS_OK"
