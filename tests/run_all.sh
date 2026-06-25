#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Consolidated end-to-end test suite for odin_godot.
#
# Runs EVERY phase milestone in sequence, prints a per-test PASS/FAIL summary, and
# exits non-zero if any required test failed. Reproducible — one command:
#
#   nix develop --command bash tests/run_all.sh
#
# Each phase has its own self-contained `run.sh` (build dlls -> headless Godot ->
# assert a sentinel). This runner just invokes them, captures their output, and tallies.
#
# The WEB test needs a browser (Chrome + puppeteer-core). It is gated: when the browser
# harness is available it RUNS and must print PHASEWEB_OK; when it is not, the test still
# builds + web-exports and prints PHASEWEB_BUNDLED, which the suite reports as a non-fatal
# SKIP so the rest of the suite still goes green. Force-skip it entirely with SKIP_WEB=1.
# ----------------------------------------------------------------------------
set -uo pipefail # NOT -e: we run all tests and tally, never bail on the first failure.

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

if [[ -z "${GODOT:-}" || ! -x "${GODOT:-/nonexistent}" ]]; then
    echo "run_all: \$GODOT is not set/executable. Run inside the Nix dev shell:" >&2
    echo "  nix develop --command bash tests/run_all.sh" >&2
    exit 2
fi

LOGDIR="$ROOT/tests/.logs"
mkdir -p "$LOGDIR"

# name  sentinel  script
TESTS=(
    "phase1|PHASE1_OK|tests/phase1/run.sh"
    "phase2|PHASE2_OK|tests/phase2/run.sh"
    "phase3|PHASE3_OK|tests/phase3/run.sh"
    "phase35|PHASE35_OK|tests/phase35/run.sh"
    "phase4|PHASE4_OK|tests/phase4/run.sh"
    "phase5|PHASE5_OK|tests/phase5/run.sh"
    "showcase|SHOWCASE_OK|tests/showcase/run.sh"
    "autoload|AUTOLOAD_OK|tests/autoload/run.sh"
    "ergonomics|ERGONOMICS_OK|tests/ergonomics/run.sh"
    "exporttypes|EXPORT_TYPES_OK|tests/export_types/run.sh"
    "codegen|CODEGEN_OK|tests/codegen/run.sh"
    "resources|RESOURCES_OK|tests/resources/run.sh"
    "crossscript|CROSSSCRIPT_OK|tests/crossscript/run.sh"
    "rpc|RPC_OK|tests/rpc/run.sh"
    # Two REAL peers over ENet (a server + a client process) exchange @(gd_rpc) calls both
    # directions with correct sender ids — the genuine remote path tests/rpc could not reach.
    "rpcnet|RPC_NET_OK|tests/rpc_net/run.sh"
    "survivors|SURVIVORS_OK|examples/survivors/run.sh"
    # MultiplayerSpawner + MultiplayerSynchronizer with Odin scripts, in isolation over ENet:
    # the host spawns an Odin-scripted scene (replicated to the client) whose native position +
    # Odin @export field sync via the synchronizer. The de-risking proof the co-op game uses.
    "replspike|SPIKE_OK|tests/repl_spike/run.sh"
    # CO-OP NATIVE (ENet): two REAL peers run the unified co-op survivors (coop.tscn). Proves
    # connection, both players on both peers, client-move replication via MultiplayerSynchronizer,
    # host enemy spawn via MultiplayerSpawner, enemy position sync, authoritative death, shared
    # score, and a per-player level-up — all asserted from both processes' stdout.
    "coopnative|COOP_NATIVE_OK|examples/survivors/coop_native_run.sh"
    "validate|VALIDATE_HARNESS_OK|tests/validate/run.sh"
    "complete|COMPLETE_HARNESS_OK|tests/complete/run.sh"
    "lsp|LSP_HARNESS_OK|tests/lsp/run.sh"
    "save|SAVE_TEST_OK|tests/save/run.sh"
    "editor|EDITOR_SMOKE_OK|tests/editor_smoke/run.sh"
    "editortools|EDITORTOOLS_OK|tests/editortools/run.sh"
    "debug|DEBUG_OK|tests/debug/run.sh"
    "reloadexports|RELOAD_EXPORTS_OK|tests/reload_exports/run.sh"
    # Cross-build smoke: self-gating — SKIPs (still prints CROSS_OK) when no Linux/Windows
    # cross toolchain is present, so the default macOS shell stays green. To actually
    # exercise the cross builds: `nix develop .#cross --command bash tests/cross/run.sh`.
    "cross|CROSS_OK|tests/cross/run.sh"
)

declare -a SUMMARY
FAILED=0

run_one() {
    local name="$1" sentinel="$2" script="$3"
    local log="$LOGDIR/$name.log"
    printf '==> %-9s ' "$name"
    local start=$SECONDS
    if bash "$ROOT/$script" >"$log" 2>&1 && grep -q "$sentinel" "$log"; then
        local dt=$((SECONDS - start))
        printf 'PASS (%ds)\n' "$dt"
        SUMMARY+=("$(printf '  %-9s PASS  (%s)' "$name" "$sentinel")")
    else
        printf 'FAIL\n'
        echo "    ----- last 15 lines of $log -----"
        tail -n 15 "$log" | sed 's/^/    /'
        SUMMARY+=("$(printf '  %-9s FAIL  (see %s)' "$name" "$log")")
        FAILED=1
    fi
}

echo "odin_godot full test suite  (root: $ROOT)"
echo "=========================================================="

for t in "${TESTS[@]}"; do
    IFS='|' read -r name sentinel script <<<"$t"
    run_one "$name" "$sentinel" "$script"
done

# ---- browser-gated web tests ----
# Each builds + web-exports unconditionally; the in-browser drive is best-effort. PASS
# requires <ok> (verified in a real browser); <bundled> reports a non-fatal SKIP when no
# browser is available. SKIP_WEB=1 skips them entirely.
run_web_gated() {
    local name="$1" script="$2" ok="$3" bundled="$4"
    if [[ "${SKIP_WEB:-0}" == "1" ]]; then
        printf '==> %-12s SKIP (SKIP_WEB=1)\n' "$name"
        SUMMARY+=("$(printf '  %-12s SKIP  (SKIP_WEB=1)' "$name")")
        return
    fi
    printf '==> %-12s ' "$name"
    local log="$LOGDIR/$name.log"
    local start=$SECONDS
    bash "$ROOT/$script" >"$log" 2>&1
    local dt=$((SECONDS - start))
    if grep -q "$ok" "$log"; then
        printf 'PASS browser-verified (%ds)\n' "$dt"
        SUMMARY+=("$(printf '  %-12s PASS  (%s, in-browser)' "$name" "$ok")")
    elif grep -q "$bundled" "$log"; then
        printf 'SKIP build+export OK, browser unavailable (%ds)\n' "$dt"
        SUMMARY+=("$(printf '  %-12s SKIP  (%s; no browser)' "$name" "$bundled")")
    else
        printf 'FAIL\n'
        echo "    ----- last 15 lines of $log -----"
        tail -n 15 "$log" | sed 's/^/    /'
        SUMMARY+=("$(printf '  %-12s FAIL  (see %s)' "$name" "$log")")
        FAILED=1
    fi
}

# web: a trivial Odin _ready runs in-browser (WEB_RAN).
run_web_gated "web" "tests/web/run.sh" "PHASEWEB_OK" "PHASEWEB_BUNDLED"
# web_showcase: the FULL coin-collector game loop (physics collide -> Odin collect -> signal
# -> shared score -> coin freed -> cross-script HUD) runs in-browser (SHOWCASE_WEB_OK).
run_web_gated "web_showcase" "tests/web_showcase/run.sh" "PHASEWEBSHOWCASE_OK" "PHASEWEBSHOWCASE_BUNDLED"
# webrtc: TWO real browser peers establish a browser-native WebRTC data channel (via the
# WebSocket signaling server) and exchange @(gd_rpc) calls BOTH directions with correct sender
# ids — the in-browser mirror of rpc_net's ENet guarantees (WEBRTC_OK).
run_web_gated "webrtc" "tests/webrtc/run.sh" "WEBRTC_OK" "WEBRTC_BUNDLED"
# coopweb: TWO real browser peers run the exported co-op survivors (coop.tscn) over WebRTC and
# prove the in-browser sync guarantees — both players synced/visible, a host->client enemy sync
# (MultiplayerSpawner + MultiplayerSynchronizer over WebRTC), and a client->host action.
run_web_gated "coopweb" "examples/survivors/coop_web_run.sh" "COOP_WEB_OK" "COOP_WEB_BUNDLED"

echo "=========================================================="
echo "SUMMARY"
for line in "${SUMMARY[@]}"; do echo "$line"; done
echo "=========================================================="
if [[ "$FAILED" == "0" ]]; then
    echo "ALL GREEN"
    exit 0
else
    echo "SUITE FAILED"
    exit 1
fi
