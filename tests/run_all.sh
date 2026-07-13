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

# One suite-wide root for every child script (they all honor ODIN_GODOT_ROOT), so the
# per-test run.sh's stop re-deriving it.
export ODIN_GODOT_ROOT="$ROOT"

# Per-test wall-clock cap: a wedged headless Godot must not hang the whole suite.
# coreutils `timeout` ships in the nix dev shell; degrade gracefully without it.
TIMEOUT_SECS="${TIMEOUT_SECS:-600}"
TIMEOUT_BIN="$(command -v timeout || true)"
if [[ -z "$TIMEOUT_BIN" ]]; then
    echo "run_all: WARNING: no \`timeout\` on PATH — tests run uncapped" >&2
fi
run_with_timeout() { # run_with_timeout <script> — bash <script> under the suite time cap
    if [[ -n "$TIMEOUT_BIN" ]]; then
        "$TIMEOUT_BIN" "$TIMEOUT_SECS" bash "$@"
    else
        bash "$@"
    fi
}

# Pre-build the scriptgen preprocessor ONCE. build_scripts.sh honors SGEN_BIN (an already
# built scriptgen) and skips rebuilding it per test — a large chunk of suite wall time.
SGEN_BIN="$LOGDIR/scriptgen"
if "${ODIN:-odin}" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$SGEN_BIN" -debug \
    >"$LOGDIR/scriptgen_build.log" 2>&1; then
    export SGEN_BIN
else
    echo "run_all: scriptgen pre-build failed (see $LOGDIR/scriptgen_build.log); tests rebuild it per-run" >&2
    unset SGEN_BIN
fi

# name  sentinel  script  [skip-sentinel: reported as a non-fatal SKIP, like the web tests]
TESTS=(
    # Pure-Odin unit tests for the `flow` sequencer — no Godot process, the fastest entry.
    "flow|FLOW_OK|tests/flow/run.sh"
    # Pure-Odin unit tests for the `events` observer (Event(T) subscribe/emit semantics).
    "events|EVENTS_OK|tests/events/run.sh"
    # Golden test for scriptgen's nested replicated/tagged-field discovery (same-package,
    # imported bundles, and the loud plain-nesting guardrail) — drives the binary, no Godot.
    "scriptgen|SCRIPTGEN_OK|tests/scriptgen/run.sh"
    # Pure-Odin unit tests for kit/net — the friendslop toolkit's replication core
    # (wire, shadow-copy deltas, intent pipeline + dedup, tick/clock sync, interp).
    "kitnet|KITNET_OK|tests/kitnet/run.sh"
    # Pure-Odin unit tests for kit/sim — the server-authority resim companion's
    # engine-free core (predict subset, history ledger, input pipeline + hold-last,
    # sim ticker/lead control, the compare -> rewind -> replay reconcile).
    "kitsim|KITSIM_OK|tests/kitsim/run.sh"
    # Pure-Odin unit tests for kit/session — player identity (reconnect tokens ->
    # stable Player_Ids), join/leave/reconnect, roster sync, zombie takeover.
    "kitsession|KITSESSION_OK|tests/kitsession/run.sh"
    # The kit's SCALE benchmark — delta walk / join snapshot / save-resume at
    # 100/500/2000 entities. Correctness asserted hard; timings printed with
    # loose O(n^2) tripwires only (see the STRESS table in the log).
    "kitstress|KITSTRESS_OK|tests/kitstress/run.sh"
    # Pure-Odin unit tests for kit/comms — host-ordered chat, positional
    # markers, system lines, late-join catchup, and SES_APP route gating.
    "kitcomms|KITCOMMS_OK|tests/kitcomms/run.sh"
    # Pure-Odin unit tests for kit/items (stack-aware slot ops, deterministic +
    # allocation-free for predicted commands) and kit/interact (range/facing gates).
    "kititems|KITITEMS_OK|tests/kititems/run.sh"
    # Phase-3 integration: chests/bags/doors over the session pipeline — the
    # two-spelunkers-one-gem conflict, the cross-entity command-hook pattern,
    # range gates shared by prompt and host, item conservation on every peer.
    "kitloot|KITLOOT_OK|tests/kitloot/run.sh"
    # Pure-Odin unit tests for kit/combat (damage, ability gates, effects,
    # swept projectiles, auto-published stat columns).
    "kitcombat|KITCOMBAT_OK|tests/kitcombat/run.sh"
    # Phase-4 integration: rocks over the session pipeline — predicted casts,
    # host-validated hits, death/respawn, effects wearing off, the ledger.
    "kitarena|KITARENA_OK|tests/kitarena/run.sh"
    # Pure-Odin unit tests for kit/ai (perception, steering, the wave director).
    "kitai|KITAI_OK|tests/kitai/run.sh"
    # kit/nav adapter: a U-shaped NavigationPolygon the engine path must bend
    # through, followed by a kit/ai walker with the next_point cursor.
    "kitnav|KITNAV_OK|tests/kitnav/run.sh"
    # kit/save envelope: the save saga (save, die, resume, rejoin by token,
    # still-playable) + foreign/corrupt saves refusing to parse.
    "kitsave|KITSAVE_OK|tests/kitsave/run.sh"
    # gd:"replicate" codegen contract: scriptgen -> knet.Entity_Desc tables, POD
    # enforcement at scriptgen time (engine types) + consumer compile (#assert).
    "repgen|REPGEN_OK|tests/repgen/run.sh"
    # Two-peer ENet sync: the toolkit's full replication stack across a REAL wire
    # (replicate tag -> desc -> shadow delta -> send_bytes -> peer_packet -> apply).
    "kitsync|KITSYNC_OK|tests/kitsync/run.sh"
    # THE PHASE-0 ACID TEST: host + owning client + OBSERVER (three processes) over
    # ENet with injected receive latency on every peer. A new entity in ~10 lines
    # (orb.odin), zero role branches: predictions land before any round trip,
    # in-flight deltas reconcile (unwind -> apply -> replay) instead of stomping
    # them, the observer converges with no role code, and clock sync measures the
    # real RTT. tests/kitacid/scripts/session.odin is the seed of kit/session.
    "kitacid|KITACID_OK|tests/kitacid/run.sh"
    # Pure-Odin unit tests for the runtime-reflection registration walk (register_class).
    "reflectregister|REFLECT_REGISTER_OK|tests/reflect_register/run.sh"
    "phase1|PHASE1_OK|tests/phase1/run.sh"
    "phase2|PHASE2_OK|tests/phase2/run.sh"
    "phase3|PHASE3_OK|tests/phase3/run.sh"
    "phase35|PHASE35_OK|tests/phase35/run.sh"
    # Asset-Library drop-in layout: core dll inside addons/odin_godot/bin/<platform>/,
    # scripts dll at res://bin — NOT siblings. Pins the core's scripts-dll resolution.
    "splitaddon|SPLITADDON_OK|tests/splitaddon/run.sh"
    "phase4|PHASE4_OK|tests/phase4/run.sh"
    # Multi-module spike: one dll per script module (res://modules/<name>), per-module
    # hot reload with other modules provably untouched, engine-mediated cross-module
    # calls, module-local script_of, loud class-collision + cross-import rejection.
    "modspike|MODULES_SPIKE_OK|tests/modules_spike/run.sh"
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
    # CAVECRAWL (the friendslop toolkit's example, grown per phase). Phase 1: boots
    # to a WORKING LOBBY — two real peers seat via kit/session (tokens, roster) and
    # the test reads the ACTUAL kit/ui player-list labels back out of both trees
    # (names, you-marker, host crown, host-only Start button).
    "cavecrawl|CAVECRAWL_OK|examples/cavecrawl/run.sh"
    # Barrage: the data-oriented showcase — thousands of #soa bullets through ONE
    # RenderingServer multimesh, 5 isolated script modules, boss via the flow sequencer,
    # powerup resources, multi-scene UI. See examples/barrage/README.md.
    "barrage|BARRAGE_OK|examples/barrage/run.sh"
    # MultiplayerSpawner + MultiplayerSynchronizer with Odin scripts, in isolation over ENet:
    # the host spawns an Odin-scripted scene (replicated to the client) whose native position +
    # Odin @export field sync via the synchronizer. The de-risking proof the co-op game uses.
    "replspike|SPIKE_OK|tests/repl_spike/run.sh"
    # CO-OP NATIVE (ENet): two REAL peers run the unified co-op survivors (coop.tscn). Proves
    # connection, both players on both peers, client-move replication via MultiplayerSynchronizer,
    # host enemy spawn via MultiplayerSpawner, enemy position sync, authoritative death, shared
    # score, and a per-player level-up — all asserted from both processes' stdout.
    "coopnative|COOP_NATIVE_OK|examples/survivors/coop_native_run.sh"
    # UNIFIED PEER-AUTHORITATIVE co-op arena, SINGLE-PLAYER mode: the ONE gameplay codebase runs
    # solo as host-with-no-peers (same pawn/bullet/enemy scripts) — move, auto-fire kills, XP/
    # level, contact death.
    "arenasingle|ARENA_SINGLE_OK|examples/coop_arena/run.sh"
    # UNIFIED PEER-AUTHORITATIVE co-op arena, NATIVE (ENet): two REAL peers prove the OWNER-auth
    # netcode — both owner-auth pawns on both peers, local-first move replication, OWNER-LOCAL
    # bullet immediacy (the firer's bullet exists the same tick, NO host round-trip) + broadcast,
    # a peer-authoritative kill agreed by both peers, despawn replication, XP to the firer.
    "arenanative|ARENA_NATIVE_OK|examples/coop_arena/coop_native_run.sh"
    # ENGINE-PHYSICS soccer, SOLO: a real RigidBody2D ball (play.Puppet) + a move_and_slide
    # striker run the whole loop headless — kick, goal off the replicated pose, match edge.
    # The repo's only exercise of the 2D physics SOLVER under --headless.
    "slopballsingle|SLOPBALL_SINGLE_OK|examples/slopball/run.sh"
    # ENGINE-PHYSICS soccer, NATIVE (ENet, 3 peers): the Puppet proof — the host GRANTS the
    # ball's simulation seat to the striker CLIENT (Ev_Owner_Changed on all three screens),
    # the striker's LOCAL solver drives the goal, the host scores it off the streamed pose,
    # and all three screens report the ball within a few px at the same session tick.
    "slopballnative|SLOPBALL_NATIVE_OK|examples/slopball/native_run.sh"
    # DEDICATED SERVER: the kit's infrastructure seat end to end — an avatarless server
    # (kboot.boot_serve → session_host_start dedicated=true) referees two real clients:
    # player-only start gating, no kicker for the server on ANY screen (the flag rides the
    # welcome roster), seat grants + goals unchanged. Succession never arms on a server.
    "slopballserver|SLOPBALL_SERVER_OK|examples/slopball/server_run.sh"
    # ENGINE-PHYSICS soccer in 3D, SOLO: a RigidBody3D ball under real gravity (play.Puppet3,
    # quaternion orientation) + an XZ-plane move_and_slide striker — lofted kick, goal off the
    # replicated pose, match edge. The repo's only exercise of the 3D physics SOLVER headless.
    "slopball3dsingle|SLOPBALL3D_SINGLE_OK|examples/slopball3d/run.sh"
    # ENGINE-PHYSICS soccer in 3D, NATIVE (ENet, 3 peers): the Puppet3 proof — seat granted to
    # the striker CLIENT, its LOCAL 3D solver (gravity + tumble) drives the goal, the host
    # scores it off the streamed pose, the ball's QUATERNION nlerps on every watcher, and all
    # three screens report the ball within centimeters at the same session tick.
    "slopball3dnative|SLOPBALL3D_NATIVE_OK|examples/slopball3d/native_run.sh"
    "validate|VALIDATE_HARNESS_OK|tests/validate/run.sh"
    "complete|COMPLETE_HARNESS_OK|tests/complete/run.sh"
    "lookup|LOOKUP_OK|tests/lookup/run.sh"
    "gdextalloc|GDEXT_ALLOC_OK|tests/gdext_alloc/run.sh"
    "lsp|LSP_HARNESS_OK|tests/lsp/run.sh"
    "save|SAVE_TEST_OK|tests/save/run.sh"
    "editor|EDITOR_SMOKE_OK|tests/editor_smoke/run.sh"
    "editortools|EDITORTOOLS_OK|tests/editortools/run.sh"
    "debug|DEBUG_OK|tests/debug/run.sh"
    # Crash/panic REPORTING: a script panic prints ODIN_SCRIPT_PANIC (msg + file:line)
    # and push_errors it (editor-visible); a raw SIGSEGV in script code triggers the
    # fatal-signal reporter (ODIN_GODOT_CRASH + symbolized faulting Odin frame +
    # backtrace) and still chains to Godot's own crash handler.
    "crash|CRASH_TEST_OK|tests/crash/run.sh"
    # Editor-launched lldb debugging (build/debug_game.sh): file:line breakpoints bind
    # across the scripts-dll dlopen (the -use-single-module regression net), named args
    # + godot_lldb.py printers live, and a script panic freezes the session in place.
    # Darwin-only (SKIPs elsewhere / without a working lldb).
    "debuglaunch|DEBUG_LAUNCH_OK|tests/debug_launch/run.sh|DEBUG_LAUNCH_SKIP"
    "reloadexports|RELOAD_EXPORTS_OK|tests/reload_exports/run.sh"
    # Cross-build smoke: self-gating — prints CROSS_SKIP (a non-fatal SKIP) when no
    # Linux/Windows cross toolchain is present, so the default macOS shell stays green. To
    # actually exercise the cross builds: `nix develop .#cross --command bash tests/cross/run.sh`.
    "cross|CROSS_OK|tests/cross/run.sh|CROSS_SKIP"
)

declare -a SUMMARY
FAILED=0

run_one() {
    local name="$1" sentinel="$2" script="$3" skip_sentinel="${4:-}"
    local log="$LOGDIR/$name.log"
    printf '==> %-9s ' "$name"
    local start=$SECONDS rc=0
    run_with_timeout "$ROOT/$script" >"$log" 2>&1 || rc=$?
    local dt=$((SECONDS - start))
    if [[ $rc -eq 0 ]] && grep -q "$sentinel" "$log"; then
        printf 'PASS (%ds)\n' "$dt"
        SUMMARY+=("$(printf '  %-9s PASS  (%s)' "$name" "$sentinel")")
    elif [[ $rc -eq 124 && -n "$TIMEOUT_BIN" ]]; then
        # coreutils timeout exit code for "killed by the cap": report distinctly.
        printf 'TIMEOUT (>%ss)\n' "$TIMEOUT_SECS"
        SUMMARY+=("$(printf '  %-9s TIMEOUT  (>%ss, see %s)' "$name" "$TIMEOUT_SECS" "$log")")
        FAILED=1
    elif [[ -n "$skip_sentinel" ]] && grep -q "$skip_sentinel" "$log"; then
        printf 'SKIP (%s)\n' "$skip_sentinel"
        SUMMARY+=("$(printf '  %-9s SKIP  (%s)' "$name" "$skip_sentinel")")
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
    IFS='|' read -r name sentinel script skip <<<"$t"
    run_one "$name" "$sentinel" "$script" "${skip:-}"
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
    local start=$SECONDS rc=0
    run_with_timeout "$ROOT/$script" >"$log" 2>&1 || rc=$?
    local dt=$((SECONDS - start))
    if [[ $rc -eq 124 && -n "$TIMEOUT_BIN" ]] && ! grep -q "$ok" "$log"; then
        printf 'TIMEOUT (>%ss)\n' "$TIMEOUT_SECS"
        SUMMARY+=("$(printf '  %-12s TIMEOUT  (>%ss, see %s)' "$name" "$TIMEOUT_SECS" "$log")")
        FAILED=1
    elif grep -q "$ok" "$log"; then
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
# modules_web: MULTI-MODULE scripts on web (main + modules composed into ONE wasm) — the
# main-module class AND a module class both run in-browser, a cross-module engine call works,
# and a deliberate cross-module class-name collision surfaces a LOUD duplicate-registration
# error on the JS console (keep-first, never silent last-write-wins).
run_web_gated "modules_web" "tests/modules_web/run.sh" "MODULES_WEB_OK" "MODULES_WEB_BUNDLED"
# webrtc: TWO real browser peers establish a browser-native WebRTC data channel (via the
# WebSocket signaling server) and exchange @(gd_rpc) calls BOTH directions with correct sender
# ids — the in-browser mirror of rpc_net's ENet guarantees (WEBRTC_OK).
run_web_gated "webrtc" "tests/webrtc/run.sh" "WEBRTC_OK" "WEBRTC_BUNDLED"
# coopweb: TWO real browser peers run the exported co-op survivors (coop.tscn) over WebRTC and
# prove the in-browser sync guarantees — both players synced/visible, a host->client enemy sync
# (MultiplayerSpawner + MultiplayerSynchronizer over WebRTC), and a client->host action.
run_web_gated "coopweb" "examples/survivors/coop_web_run.sh" "COOP_WEB_OK" "COOP_WEB_BUNDLED"
# arenaweb: TWO real browser peers run the exported peer-authoritative co-op arena over WebRTC
# and prove the SAME owner-auth guarantees in-browser — both owner-auth pawns synced, the firer's
# OWNER-LOCAL bullet immediacy (BULLET_LOCAL + BULLET_REMOTE), and a peer-auth kill agreed by both.
run_web_gated "arenaweb" "examples/coop_arena/coop_web_run.sh" "ARENA_WEB_OK" "ARENA_WEB_BUNDLED"
# barrageweb: the bullet-hell example's Web export boots in a real browser (all FIVE script
# modules in one wasm), and clicking Play runs Odin input handling + a scene switch into the
# RenderingServer/MultiMesh game scene (BARRAGE_TITLE_READY -> BARRAGE_FIELD_READY).
run_web_gated "barrageweb" "examples/barrage/web_run.sh" "BARRAGE_WEB_OK" "BARRAGE_WEB_BUNDLED"

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
