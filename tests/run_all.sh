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
	# Breaking API guard: retired event attributes, quoted command policies,
	# redundant owner interpolation, ID-only census views, and boolean action
	# aliases must all stay rejected/absent.
	"authorsurface|AUTHOR_SURFACE_OK|tests/author_surface/run.sh"
	# Kit prose integrity: every local link resolves and normal-path guides keep
	# generated frame/lifecycle/event/query APIs as the canonical surface.
	"kitdocs|KITDOCS_OK|tests/kitdocs/run.sh"
	# Cross-platform build policy: cache invalidation, isolated/atomic publication,
	# failure + stale cleanup, and concurrent builds. Bash always runs; PowerShell runs
	# when available (the dedicated .#build-parity shell supplies it).
	"buildhelpers|BUILD_HELPERS_OK|tests/build_helpers/run.sh"
	# Recursive canonical wire ABI: one generated schema/fingerprint plus a raw
	# byte vector accepted identically by native, wasm32, Linux, and Windows.
	"wireabi|WIREABI_OK|tests/wireabi/run.sh"
    # THE WEB-TARGET COMPILE PIN: `odin check` of every godot:kit/* package plus
    # core/play/flowgd for freestanding_wasm32 — no Emscripten, no browser, under a
    # second. The browser-gated web suites below export toy projects that never link
    # the full kit, so an unguarded println-family call in kit code used to break
    # every user's web export with the whole suite green.
    "kitwasm|KITWASM_OK|tests/kitwasm/run.sh"
    # Pure-Odin unit tests for kit/net — the friendslop toolkit's replication core
    # (wire, shadow-copy deltas, intent pipeline + dedup, tick/clock sync, interp).
    "kitnet|KITNET_OK|tests/kitnet/run.sh"
    # Pure-Odin unit tests for kit/sim — the server-authority resim companion's
    # engine-free core (predict subset, history ledger, input pipeline + hold-last,
    # sim ticker/lead control, the compare -> rewind -> replay reconcile).
    "kitsim|KITSIM_OK|tests/kitsim/run.sh"
    # Experimental whole-world replay: native behavior, WASM type-check, demo.
    "replay|REPLAY_OK|tests/replay/run.sh"
    "replaystormcaller|REPLAY_STORMCALLER_OK|tests/replay_stormcaller/run.sh"
    "replayeditor|REPLAY_EDITOR_OK|tests/replay_editor/run.sh"
    "replayscrapbridge|REPLAY_SCRAP_BRIDGE_OK|tests/replay_scrapyard_bridge/run.sh"
    "replaybridge|REPLAY_BRIDGE_OK|tests/replay_bridge/run.sh"
    "replaydefinitions|REPLAY_DEFINITIONS_OK|tests/replay_definitions/run.sh"
    "replaynodes|REPLAY_NODES_LIFECYCLE_OK|tests/replay_nodes/run.sh"
    "replaydeterministic|REPLAY_DETERMINISTIC_OK|tests/replay_deterministic/run.sh"
    "replayinputcapture|REPLAY_INPUT_CAPTURE_OK|tests/replay_input_capture/run.sh"
    "replayacktransport|REPLAY_ACK_TRANSPORT_OK|tests/replay_ack_transport/run.sh"
    "replaywatchfailover|REPLAY_DUEL_SPECTATOR_FAILOVER_OK|examples/replay_duel/watch_failover_run.sh"
    "replaynativecreator|REPLAY_DUEL_NATIVE_CREATOR_REJOIN_OK|examples/replay_duel/creator_rejoin_run.sh"
    "replaymultiplayergeneration|REPLAY_MULTIPLAYER_GENERATION_OK|tests/replay_multiplayer_generation/run.sh"
    "replaydashinput|REPLAY_DASH_INPUT_OK|tests/replay_scrapyard/dash_input.sh"
    "replayscrapaim|REPLAY_SCRAPYARD_AIM_OK|tests/replay_scrapyard_aim/run.sh"
    "replayjams|REPLAY_JAM_COMPARISON_OK|tests/replay_jam_comparison/run.sh"
    "replayendurance|REPLAY_ENDURANCE_COMPARISON_OK|tests/replay_endurance_comparison/run.sh"
    "replayp2p|REPLAY_P2P_OK|tests/replay_p2p/run.sh"
    "replayp2plink|REPLAY_P2P_LINK_OK|tests/replay_p2p_link/run.sh"
    "replayrecipes|REPLAY_RECIPES_OK|tests/replay_recipes/run.sh"
    "replayp2pnative|REPLAY_P2P_NATIVE_OK|tests/replay_p2p_native/run.sh"
    "replayp2padmission|REPLAY_P2P_ADMISSION_OK|tests/replay_p2p_admission/run.sh"
    "replayp2pprovision|REPLAY_P2P_PROVISION_OK|tests/replay_p2p_provision/run.sh"
    "replayp2pprovisionsqlite|REPLAY_P2P_PROVISION_SQLITE_OK|tests/replay_p2p_provision_sqlite/run.sh"
    "replayp2pprovisionservice|REPLAY_P2P_PROVISION_SERVICE_OK|tests/replay_p2p_provision_service/run.sh"
    "replayp2pparty|REPLAY_P2P_PARTY_OK|tests/replay_p2p_party/run.sh"
    "replayp2padmissionservice|REPLAY_P2P_ADMISSION_SERVICE_OK|tests/replay_p2p_admission/service_run.sh"
    "replayp2padmissionweb|REPLAY_DUEL_AUTHENTICATED_REJOIN_OK|tests/replay_p2p_admission/web_run.sh"
    "replayduel|REPLAY_DUEL_P2P_OK|examples/replay_duel/run.sh"
    "replayduelweb|REPLAY_DUEL_WEB_OK|examples/replay_duel/web_run.sh"
    "replayduelresume|REPLAY_DUEL_RESUME_OK|examples/replay_duel/resume_run.sh"
    "replayduelrejoin|REPLAY_DUEL_LIVE_REJOIN_OK|examples/replay_duel/rejoin_run.sh"
    "replayduelwatch|REPLAY_DUEL_SPECTATOR_OK|examples/replay_duel/watch_run.sh"
    "replayduelprofile|REPLAY_DUEL_PROFILE_OK|examples/replay_duel/profile_run.sh"
    "replayowned|REPLAY_OWNED_OK|tests/replay_owned/run.sh"
    "replayownedgodot|REPLAY_OWNED_GODOT_OK|tests/replay_owned_godot/run.sh"
    "replayslopball|REPLAY_SLOPBALL_SINGLE_OK|examples/replay_slopball/run.sh"
    "replayslopballnet|REPLAY_SLOPBALL_NETWORK_OK|examples/replay_slopball/network_run.sh"
    "replayslopmodel|REPLAY_SLOPBALL_MODEL_OK|tests/replay_slopball/run.sh"
    "replayslopmigration|REPLAY_SLOPBALL_MIGRATION_OK|examples/replay_slopball/migration_run.sh"
    "replayowned3godot|REPLAY_OWNED3_GODOT_OK|tests/replay_owned3_godot/run.sh"
    "replayslop3model|REPLAY_SLOPBALL3D_MODEL_OK|tests/replay_slopball3d/run.sh"
    "replayslop3|REPLAY_SLOPBALL3D_SINGLE_OK|examples/replay_slopball3d/run.sh"
    "replayslop3net|REPLAY_SLOPBALL3D_NETWORK_OK|examples/replay_slopball3d/network_run.sh"
    "replayslop3migration|REPLAY_SLOPBALL3D_MIGRATION_OK|examples/replay_slopball3d/migration_run.sh"
    "replayeffects|REPLAY_EFFECTS_OK|tests/replay_effects/run.sh"
    "replaydirector|REPLAY_DIRECTOR_OK|tests/replay_director/run.sh"
    "replayassets|REPLAY_ASSETS_OK|tests/replay_assets/run.sh"
    "replaycompress|REPLAY_COMPRESS_OK|tests/replay_compress/run.sh"
    "replayrenderaudit|REPLAY_RENDER_AUDIT_OK|tests/replay_render_audit/run.sh"
    "replaytransfer|REPLAY_TRANSFER_OK|tests/replay_transfer/run.sh"
    "replayscrapspraymigration|REPLAY_SCRAPYARD_SPRAY_MIGRATION_OK|examples/replay_scrapyard/spray_migration_run.sh"
    "replayscrapwebmigration|REPLAY_SCRAPYARD_WEB_MIGRATION_OK|examples/replay_scrapyard/web_run.sh"
    "replayscrapwebprofile|REPLAY_SCRAPYARD_BROWSER_PROFILE_OK|examples/replay_scrapyard/web_profile_run.sh"
    "replayscrapwebsave|REPLAY_SCRAPYARD_BROWSER_SAVE_OK|examples/replay_scrapyard/web_save_run.sh"
    "replaybrowserstore|REPLAY_BROWSER_STORE_OK|tests/replay_browser_store/run.sh"
    "godotlifetimes|GODOT_LIFETIMES_OK|tests/godot_lifetimes/run.sh"
    "replaycomparisonidle|REPLAY_COMPARISON_IDLE_OK|tests/replay_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replayscans|REPLAY_SCANS_OK|tests/replay_scans/run.sh"
    "replaycomparisoncombat|REPLAY_COMPARISON_COMBAT_OK|tests/replay_comparison/combat_run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replaycomparisonswarm|REPLAY_SWARM_COMPARISON_OK|tests/replay_swarm_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replaybrowserstress|REPLAY_BROWSER_STRESS_OK|tests/replay_browser_stress/run.sh"
    "replayactiontransport|REPLAY_ACTION_TRANSPORT_OK|tests/replay_action_transport/run.sh"
    "replayshuffle|REPLAY_SHUFFLE_OK|tests/replay_shuffle/run.sh"
    "replayerasure|REPLAY_ERASURE_OK|tests/replay_erasure/run.sh"
    "replaydeltaselection|REPLAY_DELTA_SELECTION_OK|tests/replay_delta_selection/run.sh"
    "replaylz4staging|REPLAY_LZ4_STAGING_CHECK_OK|tests/replay_lz4_staging/run.sh"
    "replaycorrectionreuse|REPLAY_CORRECTION_REUSE_OK|tests/replay_correction_reuse/run.sh"
    "replaycomparisonmixed|REPLAY_MIXED_COMPARISON_OK|tests/replay_mixed_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replaynetworkfaults|REPLAY_NETWORK_FAULTS_OK|tests/replay_network_faults/run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replayauthoring|REPLAY_AUTHORING_OK|tests/replay_authoring/run.sh"
    "replayweaponauthoring|REPLAY_WEAPON_AUTHORING_OK|tests/replay_weapon_authoring/run.sh"
    "replaycomparisonfire|REPLAY_COMPARISON_FIRING_OK|tests/replay_comparison/firing_run.sh|REPLAY_COMPARISON_BASELINE_MISSING"
    "replayscrapspray|REPLAY_SCRAPYARD_SPRAY_OK|examples/replay_scrapyard/spray_run.sh"
    "replayscrapstress|REPLAY_SCRAPYARD_STRESS_OK|examples/replay_scrapyard/stress_run.sh"
    "replayscrapmod|REPLAY_SCRAPYARD_MOD_OK|examples/replay_scrapyard/mod_run.sh"
    "replayscrapmodmigration|REPLAY_SCRAPYARD_MOD_MIGRATION_OK|examples/replay_scrapyard/mod_migration_run.sh"
    "replayscrapassetsave|REPLAY_SCRAPYARD_ASSET_SAVE_OK|examples/replay_scrapyard/save_assets_run.sh"
    "replayscrapcoopsave|REPLAY_SCRAPYARD_COOP_SAVE_OK|examples/replay_scrapyard/save_coop_run.sh"
    "replayscrapsave|REPLAY_SCRAPYARD_SAVE_OK|examples/replay_scrapyard/save_run.sh"
    "replayscrapupgrade|REPLAY_SCRAPYARD_UPGRADE_OK|tests/replay_scrapyard/upgrade_run.sh"
    "replayscrapworkbench|REPLAY_WORKBENCH_OK|examples/replay_scrapyard/workbench_run.sh"
    "replayscrapshop|REPLAY_SHOP_UI_OK|examples/replay_scrapyard/shop_run.sh"
    "replayscraphud|REPLAY_SCRAPYARD_HUD_OK|examples/replay_scrapyard/hud_run.sh"
    "replayscrapactors|REPLAY_ACTOR_VIEW_OK|examples/replay_scrapyard/actors_run.sh"
    "replayscrapfeedback|REPLAY_FEEDBACK_OK|examples/replay_scrapyard/feedback_run.sh"
    "replayscrapscreen|REPLAY_SCREEN_FX_OK|examples/replay_scrapyard/screen_run.sh"
    "replayscrapgrenademigration|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/grenade_migration_run.sh"
    "replayscrapmusterpeers|REPLAY_SCRAPYARD_MUSTER_PEERS_OK|examples/replay_scrapyard/muster_peers_run.sh"
    "replayscrapautomatic|REPLAY_SCRAPYARD_AUTOMATIC_OK|examples/replay_scrapyard/automatic_run.sh"
    "replayscrapautoweb|REPLAY_SCRAPYARD_AUTOMATIC_WEB_OK|examples/replay_scrapyard/automatic_web_run.sh"
    "replayscrapmuster|REPLAY_MUSTER_VIEW_OK|examples/replay_scrapyard/muster_run.sh"
    "replayscrapmenu|REPLAY_MENU_VIEW_OK|examples/replay_scrapyard/menu_run.sh"
    "replayscrapordnanceview|REPLAY_ORDNANCE_VIEW_OK|examples/replay_scrapyard/ordnance_view_run.sh"
    "replayscrapyardglobs|REPLAY_GLOB_VIEW_OK|examples/replay_scrapyard/glob_view_run.sh"
    "replayscrapyardareas|REPLAY_AREA_VIEW_OK|examples/replay_scrapyard/area_view_run.sh"
    "replayscrapyardpaths|REPLAY_CAST_PATH_VIEW_OK|examples/replay_scrapyard/cast_path_run.sh"
    "replayscrapwalls|REPLAY_WALL_VIEW_OK|examples/replay_scrapyard/walls_run.sh"
    "replayscrapwounds|REPLAY_WOUND_VIEW_OK|examples/replay_scrapyard/wounds_run.sh"
    "replayscrapchat|REPLAY_SCRAPYARD_CHAT_OK|examples/replay_scrapyard/chat_run.sh"
    "replayscrappings|REPLAY_SCRAPYARD_PINGS_OK|examples/replay_scrapyard/pings_run.sh"
    "replayscrapwebui|REPLAY_SCRAPYARD_BROWSER_UI_OK|examples/replay_scrapyard/web_ui_run.sh"
    "replayaudio|REPLAY_AUDIO_OK|tests/replay_audio/run.sh"
    "replayscrapsettings|REPLAY_SCRAPYARD_SETTINGS_OK|examples/replay_scrapyard/settings_run.sh"
    "replayscrapwebsettings|REPLAY_SCRAPYARD_BROWSER_SETTINGS_OK|examples/replay_scrapyard/web_settings_run.sh"
    "replayscrapdevelopment|REPLAY_SCRAPYARD_DEVELOPMENT_OK|tests/replay_scrapyard/development_run.sh"
    "replayscrapprofile|REPLAY_SCRAPYARD_PROFILE_OK|examples/replay_scrapyard/profile_run.sh"
    "replayscrapmigration|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/migration_run.sh"
    "replayscraplobby|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/lobby_migration_run.sh"
    "replayscraprun|REPLAY_SCRAPYARD_RUN_OK|examples/replay_scrapyard/run_loop.sh"
    "replayscraprevive|REPLAY_SCRAPYARD_REVIVE_OK|examples/replay_scrapyard/revive_run.sh"
    "replayscrapgauntlet|REPLAY_SCRAPYARD_GAUNTLET_OK|examples/replay_scrapyard/gauntlet_run.sh"
    "replayscrapstorm|REPLAY_SCRAPYARD_STORM_OK|examples/replay_scrapyard/storm_run.sh"
    "replayscrapabilities|REPLAY_SCRAPYARD_ABILITIES_OK|examples/replay_scrapyard/abilities_run.sh"
    "replayscrapenemies|REPLAY_SCRAPYARD_ENEMIES_OK|examples/replay_scrapyard/enemy_run.sh"
    "replaycarom|REPLAY_CAROM_OK|tests/replay_carom/run.sh"
    "replayscrapweapons|REPLAY_SCRAPYARD_WEAPONS_OK|examples/replay_scrapyard/weapon_run.sh"
    "replaygun|REPLAY_GUN_OK|tests/replay_gun/run.sh"
    "replayscrapcombat|REPLAY_SCRAPYARD_COMBAT_OK|examples/replay_scrapyard/combat_run.sh"
    "replayscrapmodel|REPLAY_SCRAPYARD_MODEL_OK|tests/replay_scrapyard/run.sh"
    "replayscraparena|REPLAY_SCRAPYARD_ARENA_OK|examples/replay_scrapyard/run.sh"
    "replayroutes|REPLAY_ROUTES_OK|tests/replay_routes/run.sh"
    "replayview|REPLAY_VIEW_OK|tests/replay_view/run.sh"
    "replayrotation|REPLAY_ROTATION_OK|tests/replay_rotation/run.sh"
    "replayrotationgodot|REPLAY_ROTATION_GODOT_OK|tests/replay_rotation_godot/run.sh"
    "replayrotationweb|REPLAY_ROTATION_WEB_OK|tests/replay_rotation_godot/web_run.sh"
    "replayschema|REPLAY_SCHEMA_OK|tests/replay_schema/run.sh"
    "replayschemablocks|REPLAY_SCHEMA_BLOCKS_OK|tests/replay_schema_blocks/run.sh"
    "replayunions|REPLAY_UNIONS_OK|tests/replay_unions/run.sh"
    "replayunionenet|REPLAY_UNION_NETWORK_OK|tests/replay_unions/enet_run.sh"
    "replaydiagnostics|REPLAY_DIAGNOSTICS_OK|tests/replay_diagnostics/run.sh"
    "replayrecording|REPLAY_RECORDING_OK|tests/replay_recording/run.sh"
    "replayplayback|REPLAY_PLAYBACK_OK|tests/replay_recording/playback_run.sh"
    "replaynetworkrecording|REPLAY_NETWORK_RECORDING_ALL_OK|tests/replay_network_recording/all.sh"
    "replaycavesocial|REPLAY_CAVE_SOCIAL_COMPLETE_OK|tests/replay_cave_social/run.sh"
    "replaycavedirector|REPLAY_CAVE_DIRECTOR_OK|tests/replay_cave_director/run.sh"
    "replaycavecarrierbrowser|REPLAY_CAVE_CARRIER_WEB_OK|tests/replay_cave_carrier/web_run.sh"
    "replayrecordingauthorityupgrade|REPLAY_RECORDING_AUTHORITY_UPGRADE_OK|tests/replay_network_recording/upgrade.sh"
    "replaydedicatedcombat|REPLAY_DEDICATED_COMBAT_COMPLETE_OK|tests/replay_dedicated_combat/run.sh"
    "replaydedicatedbrowser|REPLAY_DEDICATED_BROWSER_COMPLETE_OK|tests/replay_dedicated_browser/run.sh"
    "replaydedicatedroom|REPLAY_DEDICATED_ROOM_COMPLETE_OK|tests/replay_dedicated_room/run.sh"
    "replaydedicatedcomparison|REPLAY_DEDICATED_COMPARISON_COMPLETE_OK|tests/replay_dedicated_comparison/run.sh"
    "replayrestorerenewal|REPLAY_RESTORE_RENEWAL_OK|tests/replay_restore_renewal/run.sh"
    "replaycaveadoption|REPLAY_CAVE_ADOPTION_OK|tests/replay_cave_adoption/run.sh"
    "replaycaveadoptionbrowser|REPLAY_CAVE_ADOPTION_WEB_OK|tests/replay_cave_adoption/web_run.sh"
    "replaycavecarrier|REPLAY_CAVE_CARRIER_OK|tests/replay_cave_carrier/run.sh"
    "replaycaveowner|REPLAY_CAVE_OWNER_OK|tests/replay_cave_owner/run.sh"
    "replaycavecontext|REPLAY_CAVE_ACTION_CONTEXT_OK|tests/replay_cave_context/run.sh"
    "replaycavecomparison|REPLAY_CAVE_COMPARISON_OK|tests/replay_cave_comparison/run.sh"
    "replayobservationcompat|REPLAY_OBSERVATION_COMPAT_OK|tests/replay_observation_compat/run.sh"
    "replaycaveownerbrowser|REPLAY_CAVE_OWNER_BROWSER_OK|tests/replay_cave_owner/browser_run.sh"
    "replaycaverelic|REPLAY_CAVE_RELIC_STATE_OK|tests/replay_cave_relic/run.sh"
    "replaycavefloorstate|REPLAY_CAVE_FLOOR_STATE_OK|tests/replay_cave_floor/run.sh"
    "replaydebug|REPLAY_DEBUG_OK|tests/replay_debug/run.sh"
    "replaydebugports|REPLAY_DEBUG_PORTS_OK|tests/replay_debug/ports_run.sh"
    "replayscrubber|REPLAY_SCRUBBER_OK|tests/replay_scrubber/run.sh"
    "methodvalues|METHOD_VALUES_OK|tests/method_values/run.sh"
    "methodvaluesweb|METHOD_VALUES_WEB_OK|tests/method_values/web_run.sh"
    "replaytransport|REPLAY_TRANSPORT_OK|tests/replay_transport/run.sh"
    "replayenet|REPLAY_ENET_OK|tests/replay_enet/run.sh"
    "replayauthrtc|REPLAY_AUTHENTICATED_RTC_SERVICE_OK|tests/replay_web_authority/signal_run.sh"
    "replaycavebrowsersave|REPLAY_CAVE_BROWSER_SAVE_OK|examples/replay_cavecrawl/browser_save_run.sh"
    "replaycavelobbyweb|REPLAY_CAVE_LOBBY_WEB_OK|examples/replay_cavecrawl/lobby_web_run.sh"
    "replaycavesocialweb|REPLAY_CAVE_SOCIAL_WEB_OK|examples/replay_cavecrawl/social_web_run.sh"
    "replaycavewebmigration|REPLAY_CAVE_WEB_MIGRATION_OK|examples/replay_cavecrawl/web_run.sh"
    "replaywebauthority|REPLAY_WEB_AUTHORITY_OK|tests/replay_web_authority/run.sh"
    "replaymigrationws|REPLAY_MIGRATION_WEBSOCKET_OK|tests/replay_migration/websocket_run.sh"
    "replayrtc|REPLAY_RTC_OK|tests/replay_rtc/run.sh"
    "replayptrcallabi|REPLAY_PTRCALL_ABI_OK|tests/replay_ptrcall_abi/run.sh"
    "replaynet|REPLAY_NET_OK|tests/replay_net/run.sh"
    "replaylz4|REPLAY_LZ4_OK|tests/replay_lz4/run.sh"
    "replaysnapshotcompat|REPLAY_SNAPSHOT_COMPAT_ALL_OK|tests/replay_snapshot_compat/run.sh"
    "replayscrapyardstartup|REPLAY_SCRAPYARD_STARTUP_OK|tests/replay_scrapyard_startup/run.sh"
    "replayauthority|REPLAY_AUTHORITY_OK|tests/replay_authority/run.sh"
    "replayauthoritysqlite|REPLAY_AUTHORITY_SQLITE_OK|tests/replay_authority_sqlite/run.sh"
    "replayprovision|REPLAY_PROVISION_OK|tests/replay_provision/run.sh"
    "replayprovisionsqlite|REPLAY_PROVISION_SQLITE_OK|tests/replay_provision_sqlite/run.sh"
    "replayprovisiongodotcore|REPLAY_PROVISION_GODOT_CORE_OK|tests/replay_provision_godot_core/run.sh"
    "replayprovisiontls|REPLAY_PROVISION_TLS_OK|tests/replay_provision_godot/run.sh"
    "replayiceconfig|REPLAY_ICE_CONFIG_OK|tests/replay_turn/config_run.sh"
    "replayrelayprovider|REPLAY_RELAY_PROVIDER_OK|tests/replay_relay/run.sh"
    "replaydistribution|REPLAY_DISTRIBUTION_OK|tests/replay_distribution/run.sh"
    "replayenrollment|REPLAY_ENROLLMENT_OK|tests/replay_enrollment/run.sh"
    "replayenrollmentnative|REPLAY_ENROLLMENT_NATIVE_OK|tests/replay_enrollment_godot/run.sh"
    "replayenrollmentweb|REPLAY_ENROLLMENT_WEB_OK|tests/replay_enrollment_godot/web_run.sh"
    "replayscrapyardonline|REPLAY_SCRAPYARD_ONLINE_OK|examples/replay_scrapyard/online_run.sh"
    "replayscrapyardonlineweb|REPLAY_SCRAPYARD_ONLINE_WEB_OK|examples/replay_scrapyard/online_web_run.sh"
    "replayauthorityservice|REPLAY_AUTHORITY_SERVICE_OK|tests/replay_authority_service/run.sh"
    "replaymigrationplanned|REPLAY_MIGRATION_PLANNED_OK|tests/replay_migration/run.sh"
    "replaymigrationcrash|REPLAY_MIGRATION_CRASH_OK|tests/replay_migration/crash_run.sh"
    "replaymigrationextended|REPLAY_MIGRATION_EXTENDED_OK|tests/replay_migration/extended_run.sh"
    "replaymigrationpartition|REPLAY_MIGRATION_PARTITION_LOSS_OK|tests/replay_migration/partition_run.sh"
    "replaylease|REPLAY_LEASE_GODOT_OK|tests/replay_authority_godot/run.sh"
    "launchparams|LAUNCH_PARAMS_OK|tests/launch_params/run.sh"
    "replayinterest|REPLAY_INTEREST_OK|tests/replay_interest/run.sh"
    "replayschemabench|REPLAY_SCHEMA_BENCH_OK|tests/replay_schema_bench/run.sh"
    "replayinterestcorpus|REPLAY_INTEREST_CORPUS_OK|tests/replay_interest/corpus_run.sh"
    "replayinterestgodot|REPLAY_INTEREST_GODOT_ALL_OK|tests/replay_interest/godot_run.sh"
    "replaysteamcore|REPLAY_STEAM_CORE_OK|tests/replay_steam_core/run.sh"
    "replaysteamroom|REPLAY_STEAM_ROOM_CONTRACT_ALL_OK|tests/replay_steam_room/run.sh"
    "replaysteamcontract|REPLAY_STEAM_CONTRACT_ALL_OK|tests/replay_steam/run.sh"
    "replaybrowsercheckpoint|REPLAY_BROWSER_CHECKPOINT_CORE_OK|tests/replay_browser_checkpoint/run.sh"
    "replaylobby|REPLAY_LOBBY_OK|tests/replay_lobby/run.sh"
    "replayobservernames|REPLAY_OBSERVER_NAMES_OK|tests/replay_observer_names/run.sh"
    "replaycommsgodot|REPLAY_COMMS_GODOT_OK|tests/replay_comms_godot/run.sh"
    "replaytelemetrygodot|REPLAY_TELEMETRY_GODOT_OK|tests/replay_telemetry_godot/run.sh"
    "replaytelemetry|REPLAY_TELEMETRY_OK|tests/replay_telemetry/run.sh"
    "replaycomms|REPLAY_COMMS_OK|tests/replay_comms/run.sh"
    "replayrecovery|REPLAY_RECOVERY_OK|tests/replay_recovery/run.sh"
    "replayreplica|REPLAY_REPLICA_ENET_OK|tests/replay_recovery_enet/run.sh"
    "replaydelta|REPLAY_DELTA_OK|tests/replay_delta/run.sh"
    "replaycavecore|REPLAY_CAVE_CORE_OK|tests/replay_cave/run.sh"
    "replaycavescatter|REPLAY_CAVE_SCATTER_OK|tests/replay_cave/scatter_run.sh"
    "replayquickdrawcore|REPLAY_QUICKDRAW_CORE_OK|tests/replay_quickdraw/run.sh"
    "replayquickdrawui|REPLAY_QUICKDRAW_UI_OK|tests/replay_quickdraw_ui/run.sh"
    "replayquickdrawfeedback|REPLAY_QUICKDRAW_FEEDBACK_OK|tests/replay_quickdraw_feedback/run.sh"
    "replayquickdrawsave|REPLAY_QUICKDRAW_SAVE_OK|tests/replay_quickdraw_save/run.sh"
    "replayquickdrawonline|REPLAY_QUICKDRAW_ONLINE_OK|tests/replay_quickdraw_online/run.sh"
    "replayquickdrawbrowsersave|REPLAY_QUICKDRAW_BROWSER_SAVE_OK|tests/replay_quickdraw_browser_save/run.sh"
    "replayquickdrawpartyrestore|REPLAY_QUICKDRAW_PARTY_RESTORE_OK|tests/replay_quickdraw_party_restore/run.sh"
    "replayquickdrawnativerestore|REPLAY_QUICKDRAW_NATIVE_RESTORE_OK|tests/replay_quickdraw_native_restore/run.sh"
    "replayquickdrawsolo|REPLAY_QUICKDRAW_SOLO_OK|examples/replay_quickdraw/run.sh"
    "replayquickdrawnetwork|REPLAY_QUICKDRAW_NETWORK_OK|examples/replay_quickdraw/network_run.sh"
    "replayquickdrawmigration|REPLAY_QUICKDRAW_MIGRATION_OK|examples/replay_quickdraw/migration_run.sh"
    "replayquickdrawearlyclaim|REPLAY_QUICKDRAW_EARLY_CLAIM_OK|examples/replay_quickdraw/early_claim_run.sh"
    "replayquickdrawearlyclaimfault|REPLAY_QUICKDRAW_EARLY_CLAIM_FAULT_OK|examples/replay_quickdraw/early_claim_fault_run.sh"
    "replayspeedballcore|REPLAY_SPEEDBALL_CORE_OK|tests/replay_speedball/run.sh"
    "replayspeedballsolo|REPLAY_SPEEDBALL_SOLO_OK|examples/replay_speedball/run.sh"
    "replayspeedballnetwork|REPLAY_SPEEDBALL_NETWORK_OK|examples/replay_speedball/network_run.sh"
    "replayspeedballui|REPLAY_SPEEDBALL_UI_OK|examples/replay_speedball/ui_run.sh"
    "replayspeedballmigration|REPLAY_SPEEDBALL_MIGRATION_OK|examples/replay_speedball/migration_run.sh"
    "replayspeedballround|REPLAY_SPEEDBALL_ROUND_OK|examples/replay_speedball/round_run.sh"
    "replayspeedballprofile|REPLAY_SPEEDBALL_PROFILE_OK|examples/replay_speedball/profile_run.sh"
    "replayspeedballsave|REPLAY_SPEEDBALL_SAVE_OK|examples/replay_speedball/save_run.sh"
    "replayspeedballparty|REPLAY_SPEEDBALL_PARTY_OK|examples/replay_speedball/online_run.sh"
    "replayspeedballpartyweb|REPLAY_SPEEDBALL_ONLINE_WEB_OK|examples/replay_speedball/online_web_run.sh"
    "replayspeedballsaveweb|REPLAY_SPEEDBALL_BROWSER_SAVE_OK|examples/replay_speedball/browser_save_run.sh"
    "replayslopballrounds|REPLAY_SLOPBALL_ROUND_OK|tests/replay_slopball_ui/round_run.sh"
    "replayslopball3drounds|REPLAY_SLOPBALL3D_ROUND_OK|tests/replay_slopball3d_ui/round_run.sh"
    "replayslopballpartyrestore|REPLAY_SLOPBALL_PARTY_RESTORE_OK|tests/replay_slopball_party_restore/run.sh"
    "replayslopballnativerestore|REPLAY_SLOPBALL_NATIVE_RESTORE_OK|tests/replay_slopball_native_restore/run.sh"
    "replayslopball3dpartyrestore|REPLAY_SLOPBALL3D_PARTY_RESTORE_OK|tests/replay_slopball3d_party_restore/run.sh"
    "replayslopball3dnativerestore|REPLAY_SLOPBALL3D_NATIVE_RESTORE_OK|tests/replay_slopball3d_native_restore/run.sh"
    "replayslopballbrowsersave|REPLAY_SLOPBALL_BROWSER_SAVE_OK|tests/replay_slopball_browser_save/run.sh"
    "replayslopball3dbrowsersave|REPLAY_SLOPBALL3D_BROWSER_SAVE_OK|tests/replay_slopball3d_browser_save/run.sh"
    "replayslopball3donline|REPLAY_SLOPBALL3D_ONLINE_OK|tests/replay_slopball3d_online/run.sh"
    "replayslopballonline|REPLAY_SLOPBALL_ONLINE_OK|tests/replay_slopball_online/run.sh"
    "replayslopballsave|REPLAY_SLOPBALL_SAVE_OK|tests/replay_slopball_save/run.sh"
    "replayslopball3dsave|REPLAY_SLOPBALL3D_SAVE_OK|tests/replay_slopball3d_save/run.sh"
    "replayslopball3dui|REPLAY_SLOPBALL3D_UI_OK|tests/replay_slopball3d_ui/run.sh"
    "replayslopballui|REPLAY_SLOPBALL_UI_OK|tests/replay_slopball_ui/run.sh"
    "replayclaimballbrowsersave|REPLAY_CLAIMBALL_BROWSER_SAVE_OK|tests/replay_claimball_browser_save/run.sh"
    "replayclaimballpartyrestore|REPLAY_CLAIMBALL_PARTY_RESTORE_OK|tests/replay_claimball_party_restore/run.sh"
    "replayclaimballnativerestore|REPLAY_CLAIMBALL_NATIVE_RESTORE_OK|tests/replay_claimball_native_restore/run.sh"
    "replayclaimballonline|REPLAY_CLAIMBALL_ONLINE_OK|tests/replay_claimball_online/run.sh"
    "replaybackupstatus|REPLAY_ROOM_BACKUP_STATUS_OK|tests/replay_room_backup_status/run.sh"
    "replayroomexpiry|REPLAY_ROOM_EXPIRY_OK|tests/replay_room_expiry/run.sh"
    "replayclaimballmigration|REPLAY_CLAIMBALL_MIGRATION_OK|tests/replay_claimball_migration/run.sh"
    "replayclaimballsave|REPLAY_CLAIMBALL_SAVE_OK|tests/replay_claimball_save/run.sh"
    "replayclaimballrounds|REPLAY_CLAIMBALL_ROUND_OK|tests/replay_claimball_ui/round_run.sh"
    "replaytransporttrace|REPLAY_TRANSPORT_TRACE_OK|tests/replay_transport_trace/run.sh"
    "replayclaimballtrace|REPLAY_CLAIMBALL_TRACE_OK|tests/replay_claimball_trace/run.sh"
    "replayclaimballresynceffects|REPLAY_CLAIMBALL_RESYNC_EFFECTS_OK|tests/replay_claimball_resync/run.sh"
    "replayclaimballui|REPLAY_CLAIMBALL_UI_OK|tests/replay_claimball_ui/run.sh"
    "replayclaimballcore|REPLAY_CLAIMBALL_CORE_OK|tests/replay_claimball/run.sh"
    "replayclaimballsolo|REPLAY_CLAIMBALL_SOLO_OK|examples/replay_claimball/run.sh"
    "replayclaimballnetwork|REPLAY_CLAIMBALL_NETWORK_OK|examples/replay_claimball/network_run.sh"
    "replayclaimballcompete|REPLAY_CLAIMBALL_COMPETE_OK|examples/replay_claimball/compete_run.sh"
    "replayclaimballfaults|REPLAY_CLAIMBALL_FAULT_OK|examples/replay_claimball/fault_run.sh"
    "replayclaimballstall|REPLAY_CLAIMBALL_STALL_OK|examples/replay_claimball/stall_run.sh"
    "replaycavesolo|REPLAY_CAVE_SOLO_OK|examples/replay_cavecrawl/run.sh"
    "replaycavedefinitions|REPLAY_CAVE_DEFINITION_GATE_OK|examples/replay_cavecrawl/definitions_run.sh"
    "replaycavedefinitionsnetwork|REPLAY_CAVE_DEFINITION_NETWORK_ALL_OK|examples/replay_cavecrawl/definitions_network_run.sh"
    "replaycaveupgrade|REPLAY_CAVE_UPGRADE_GATE_OK|tests/replay_cave/upgrade/run.sh"
    "replaycavelobbymigration|REPLAY_CAVE_LOBBY_MIGRATION_OK|tests/replay_migration/lobby_run.sh"
    "replaycavelobby|REPLAY_CAVE_LOBBY_ALL_OK|examples/replay_cavecrawl/lobby_run.sh"
    "replaycaveonline|REPLAY_CAVE_ONLINE_OK|examples/replay_cavecrawl/online_run.sh"
    "replaycaveonlineweb|REPLAY_CAVE_ONLINE_WEB_OK|examples/replay_cavecrawl/online_web_run.sh"
    "replaycaverestart|REPLAY_CAVE_RESTART_ALL_OK|examples/replay_cavecrawl/restart_run.sh"
    "replaycavecontent2|REPLAY_CAVE_CONTENT2_UPGRADE_OK|tests/replay_cave/upgrade/content2_run.sh"
    "replaycavesocialmigration|REPLAY_CAVE_SOCIAL_MIGRATION_ALL_OK|tests/replay_migration/social_run.sh"
    "replaycavesocial|REPLAY_CAVE_SOCIAL_ALL_OK|examples/replay_cavecrawl/social_run.sh"
    "replaycavemoderation|REPLAY_CAVE_MODERATION_OK|tests/replay_cave_moderation/run.sh"
    "replaycaverocks|REPLAY_CAVE_ROCKS_OK|tests/replay_cave_rocks/run.sh"
    "replaycaveimpact|REPLAY_CAVE_IMPACT_OK|tests/replay_cave_impact/run.sh"
    "replaycavefeedback|REPLAY_CAVE_FEEDBACK_OK|tests/replay_cave_feedback/run.sh"
    "replaycavecampaign|REPLAY_CAVE_CAMPAIGN_ALL_OK|examples/replay_cavecrawl/campaign_run.sh"
    "replaycavenetwork|REPLAY_CAVE_NETWORK_OK|examples/replay_cavecrawl/network_run.sh"
    "replaycavereplication|REPLAY_CAVE_REPLICATION_OK|examples/replay_cavecrawl/replication_run.sh"
    "replaycavesave|REPLAY_CAVE_SAVE_RESUME_OK|examples/replay_cavecrawl/save_run.sh"
    "replaycaverecovery|REPLAY_CAVE_RECOVERY_OK|examples/replay_cavecrawl/recovery_run.sh"
    "replaysharedalias|REPLAY_SHARED_ALIAS_OK|tests/replay_shared_alias/run.sh"
    "replayhelloinput|REPLAY_HELLO_INPUT_OK|tests/replay_hello_input/run.sh"
    "replayhello|REPLAY_HELLO_OK|examples/replay_hello/run.sh"
    "replaynetwork|REPLAY_NETWORK_OK|examples/replay_hello/network_run.sh"
    # Pure-Odin checks for the named complete-stack network profiles: resolved
    # rates/history plus cross-field and dedicated-authority guardrails.
    "kitnetcfg|KITNETCFG_OK|tests/kitnetcfg/run.sh"
    # Pure-Odin unit tests for kit/session — player identity (reconnect tokens ->
    # stable Player_Ids), join/leave/reconnect, roster sync, zombie takeover.
    "kitsession|KITSESSION_OK|tests/kitsession/run.sh"
    # Entity-census cardinality in both dev and release guard modes: singular
    # ownership returns exactly one and ambiguity can never become first-match.
    "kitboot|KITBOOT_OK|tests/kitboot/run.sh"
    # The kit's SCALE benchmark — delta/join/save CPU+bytes+memory at
    # 100/500/2000 entities, per-recipient fanout at 2/4/8 players, and forced
    # resimulation at 32/128/512 predicted entities. Timings use loose
    # complexity tripwires (see STRESS/FANOUT/RESIM in the log).
    "kitstress|KITSTRESS_OK|tests/kitstress/run.sh"
    # Pure-Odin unit tests for kit/comms — host-ordered chat, positional
    # markers, system lines, late-join catchup, and SES_APP route gating.
    "kitcomms|KITCOMMS_OK|tests/kitcomms/run.sh"
    # Pure-Odin unit tests for kit/xfer's ALBUM — kept payloads per (player,
    # kind), own-copy short circuit, supersede, late-join catch-up.
    "kitxfer|KITXFER_OK|tests/kitxfer/run.sh"
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
    # Pure-Odin unit tests for kit/fx's trauma shake (legacy zero-value feel,
    # the knobs, coherence, rotation channels).
    "kitfx|KITFX_OK|tests/kitfx/run.sh"
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
    # kit/sim solo gate: the sim-lane loop headless end to end — @(gd_tick)
    # movement, the world pass, a lane_rewound shot — host-with-no-peers.
    "quickdrawsingle|QUICKDRAW_SINGLE_OK|examples/quickdraw/run.sh"
    # THE DUEL ACID (three processes, ENet, 120ms injected latency each way):
    # a deadeye fires at a perpendicular-crossing strafer exactly where its
    # screen renders it. Lag comp ON: the shots land (kill -> respawn). The
    # SAME duel judged live: they miss. The gap is the feature, proved A/B.
    "quickdrawnative|QUICKDRAW_NATIVE_OK|examples/quickdraw/native_run.sh"
    # speedball solo gate: the contested-ball loop headless — dribble, kick,
    # predicted goal reset, delta-lane score via ball_tick_then.
    "speedballsingle|SPEEDBALL_SINGLE_OK|examples/speedball/run.sh"
    # THE CONTESTED-BALL ACID (three processes, ENet, 120ms each way):
    # @(gd_tick="contested") — the striker's own screen kicks its own
    # predicted ball at 240ms RTT, the goal reset predicts everywhere, the
    # score rides the delta lane, three screens agree.
    "speedballnative|SPEEDBALL_NATIVE_OK|examples/speedball/native_run.sh"
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
    # Script SUBPACKAGES: annotated classes in subfolders of a module (still one dll).
    # A subfolder script attaches + reloads with state preserved, the root reads it TYPED
    # in-dll, and the four refusals hold (kit annotation, root import, dup package, dup class).
    "subpkgspike|SUBPKG_SPIKE_OK|tests/subpkg_spike/run.sh"
    # SHARED vocabulary tree: res://shared/<pkg> — read-only types/constants/pure procs
    # importable by EVERY module. Two dlls agree on one vocabulary, one shared edit
    # rebuilds+swaps both modules in a live editor, and the refusals hold (mutable global,
    # @(init), //gd: marker, shared->module import, tagged bundle, cross-module import).
    "sharedspike|SHARED_SPIKE_OK|tests/shared_spike/run.sh"
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
    # THE QUICKSTART, kept honest: hello_net (docs/kit/quickstart.md's living copy) in two
    # headless windows under 120ms — the guest watches the host's walk arrive through the
    # wire, read entirely through GENERATED probes on the acid harness (its smallest consumer).
    "hellonet|HELLO_NET_OK|examples/hello_net/run.sh"
    # THE SIM QUICKSTART: hello_net promoted per the checklist (retag/tick/sample/two wires).
    # Pins the promotion's two receipts under 120ms each way: the guest's OWN square moves
    # within half a second of the press (prediction), the host's walk arrives watched.
    "hellosim|HELLO_SIM_OK|examples/hello_sim/run.sh"
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
