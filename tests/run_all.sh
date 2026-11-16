#!/usr/bin/env bash
# Consolidated checks. Run in nix develop; SKIP_WEB=1 keeps native portions of
# mixed checks and reports their omitted browser portions as SKIP.
# Exact names focus a run; --list prints the selected capability manifest.
# SUITE_SHARD_INDEX/COUNT partition the full manifest by stable row position.
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || exit 2
LIST_ONLY=0
REQUESTED=()
for argument in "$@"; do
    case "$argument" in
        --list) LIST_ONLY=1 ;;
        --help|-h)
            echo 'Usage: bash tests/run_all.sh [--list] [TEST_NAME ...]'
            echo 'Environment: SKIP_WEB=0|1, SUITE_SHARD_INDEX=0, SUITE_SHARD_COUNT=1, SUITE_LOGDIR, TIMEOUT_SECS=600'
            exit 0 ;;
        --*) echo "run_all: unknown option: $argument" >&2; exit 2 ;;
        *) REQUESTED+=("$argument") ;;
    esac
done
SHARD_INDEX="${SUITE_SHARD_INDEX:-0}"
SHARD_COUNT="${SUITE_SHARD_COUNT:-1}"
if [[ ! "$SHARD_INDEX" =~ ^(0|[1-9][0-9]*)$ || ! "$SHARD_COUNT" =~ ^[1-9][0-9]*$ ]] ||
   (( SHARD_INDEX >= SHARD_COUNT )); then
    echo 'run_all: shard index must be nonnegative and smaller than positive shard count' >&2
    exit 2
fi
SKIP_WEB="${SKIP_WEB:-0}"
if [[ "$SKIP_WEB" != 0 && "$SKIP_WEB" != 1 ]]; then
    echo 'run_all: SKIP_WEB must be 0 or 1' >&2
    exit 2
fi

# name | pass marker | script | optional skip marker | capability
# Every entry declares native, browser, or mixed. Mixed scripts honor SKIP_WEB
# after their required native checks and emit SUITE_NATIVE_ONLY_OK.
TESTS=(
    # Pure-Odin unit tests for the `flow` sequencer — no Godot process, the fastest entry.
    "flow|FLOW_OK|tests/flow/run.sh||native"
    # Pure-Odin unit tests for the `events` observer (Event(T) subscribe/emit semantics).
    "events|EVENTS_OK|tests/events/run.sh||native"
    # Golden test for scriptgen's nested replicated/tagged-field discovery (same-package,
    # imported bundles, and the loud plain-nesting guardrail) — drives the binary, no Godot.
	"scriptgen|SCRIPTGEN_OK|tests/scriptgen/run.sh||native"
	# Breaking API guard: retired event attributes, quoted command policies,
	# redundant owner interpolation, ID-only census views, and boolean action
	# aliases must all stay rejected/absent.
	"authorsurface|AUTHOR_SURFACE_OK|tests/author_surface/run.sh||native"
	# Kit prose integrity: every local link resolves and normal-path guides keep
	# generated frame/lifecycle/event/query APIs as the canonical surface.
	"kitdocs|KITDOCS_OK|tests/kitdocs/run.sh||native"
	# Cross-platform build policy: cache invalidation, isolated/atomic publication,
	# failure + stale cleanup, and concurrent builds. Bash always runs; PowerShell runs
	# when available (the dedicated .#build-parity shell supplies it).
	"buildhelpers|BUILD_HELPERS_OK|tests/build_helpers/run.sh||native"
	# Recursive canonical wire ABI: one generated schema/fingerprint plus a raw
	# byte vector accepted identically by native, wasm32, Linux, and Windows.
	"wireabi|WIREABI_OK|tests/wireabi/run.sh||native"
    # THE WEB-TARGET COMPILE PIN: `odin check` of every godot:kit/* package plus
    # core/play/flowgd for freestanding_wasm32 — no Emscripten, no browser, under a
    # second. The browser-gated web suites below export toy projects that never link
    # the full kit, so an unguarded println-family call in kit code used to break
    # every user's web export with the whole suite green.
    "kitwasm|KITWASM_OK|tests/kitwasm/run.sh||native"
    # Pure-Odin unit tests for kit/net — the friendslop toolkit's replication core
    # (wire, shadow-copy deltas, intent pipeline + dedup, tick/clock sync, interp).
    "kitnet|KITNET_OK|tests/kitnet/run.sh||native"
    # Pure-Odin unit tests for kit/sim — the server-authority resim companion's
    # engine-free core (predict subset, history ledger, input pipeline + hold-last,
    # sim ticker/lead control, the compare -> rewind -> replay reconcile).
    "kitsim|KITSIM_OK|tests/kitsim/run.sh||native"
    # Experimental whole-world replay: native behavior, WASM type-check, demo.
    "replay|REPLAY_OK|tests/replay/run.sh||native"
    "replaypackages|REPLAY_PACKAGES_OK|tests/replay_packages/run.sh||native"
    "replaystormcaller|REPLAY_STORMCALLER_OK|tests/replay_stormcaller/run.sh||native"
    "replayeditor|REPLAY_EDITOR_OK|tests/replay_editor/run.sh||native"
    "replayscrapbridge|REPLAY_SCRAP_BRIDGE_OK|tests/replay_scrapyard_bridge/run.sh||native"
    "replaybridge|REPLAY_BRIDGE_OK|tests/replay_bridge/run.sh||native"
    "replaydefinitions|REPLAY_DEFINITIONS_OK|tests/replay_definitions/run.sh||native"
    "replaynodes|REPLAY_NODES_LIFECYCLE_OK|tests/replay_nodes/run.sh||native"
    "replaydeterministic|REPLAY_DETERMINISTIC_OK|tests/replay_deterministic/run.sh||native"
    "replayinputcapture|REPLAY_INPUT_CAPTURE_OK|tests/replay_input_capture/run.sh||native"
    "replayacktransport|REPLAY_ACK_TRANSPORT_OK|tests/replay_ack_transport/run.sh||native"
    "replaywatchfailover|REPLAY_DUEL_SPECTATOR_FAILOVER_OK|examples/replay_duel/watch_failover_run.sh||native"
    "replaynativecreator|REPLAY_DUEL_NATIVE_CREATOR_REJOIN_OK|examples/replay_duel/creator_rejoin_run.sh||native"
    "replaymultiplayergeneration|REPLAY_MULTIPLAYER_GENERATION_OK|tests/replay_multiplayer_generation/run.sh||native"
    "replaydashinput|REPLAY_DASH_INPUT_OK|tests/replay_scrapyard/dash_input.sh||native"
    "replayscrapaim|REPLAY_SCRAPYARD_AIM_OK|tests/replay_scrapyard_aim/run.sh||native"
    "replayjams|REPLAY_JAM_COMPARISON_OK|tests/replay_jam_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayendurance|REPLAY_ENDURANCE_COMPARISON_OK|tests/replay_endurance_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayp2p|REPLAY_P2P_OK|tests/replay_p2p/run.sh||native"
    "replayp2plink|REPLAY_P2P_LINK_OK|tests/replay_p2p_link/run.sh||native"
    "replayrecipes|REPLAY_RECIPES_OK|tests/replay_recipes/run.sh||native"
    "replayp2pnative|REPLAY_P2P_NATIVE_OK|tests/replay_p2p_native/run.sh||native"
    "replayp2padmission|REPLAY_P2P_ADMISSION_OK|tests/replay_p2p_admission/run.sh||native"
    "replayp2pprovision|REPLAY_P2P_PROVISION_OK|tests/replay_p2p_provision/run.sh||native"
    "replayp2pprovisionsqlite|REPLAY_P2P_PROVISION_SQLITE_OK|tests/replay_p2p_provision_sqlite/run.sh||native"
    "replayp2pprovisionservice|REPLAY_P2P_PROVISION_SERVICE_OK|tests/replay_p2p_provision_service/run.sh||native"
    "replayp2pparty|REPLAY_P2P_PARTY_OK|tests/replay_p2p_party/run.sh||browser"
    "replayp2padmissionservice|REPLAY_P2P_ADMISSION_SERVICE_OK|tests/replay_p2p_admission/service_run.sh||native"
    "replayp2padmissionweb|REPLAY_DUEL_AUTHENTICATED_REJOIN_OK|tests/replay_p2p_admission/web_run.sh||browser"
    "replayduel|REPLAY_DUEL_P2P_OK|examples/replay_duel/run.sh||native"
    "replayduelweb|REPLAY_DUEL_WEB_OK|examples/replay_duel/web_run.sh||browser"
    "replayduelresume|REPLAY_DUEL_RESUME_OK|examples/replay_duel/resume_run.sh||native"
    "replayduelrejoin|REPLAY_DUEL_LIVE_REJOIN_OK|examples/replay_duel/rejoin_run.sh||native"
    "replayduelwatch|REPLAY_DUEL_SPECTATOR_OK|examples/replay_duel/watch_run.sh||native"
    "replayduelprofile|REPLAY_DUEL_PROFILE_OK|examples/replay_duel/profile_run.sh||native"
    "replayowned|REPLAY_OWNED_OK|tests/replay_owned/run.sh||native"
    "replayownedgodot|REPLAY_OWNED_GODOT_OK|tests/replay_owned_godot/run.sh||native"
    "replayslopball|REPLAY_SLOPBALL_SINGLE_OK|examples/replay_slopball/run.sh||native"
    "replayslopballnet|REPLAY_SLOPBALL_NETWORK_OK|examples/replay_slopball/network_run.sh||native"
    "replayslopmodel|REPLAY_SLOPBALL_MODEL_OK|tests/replay_slopball/run.sh||native"
    "replayslopmigration|REPLAY_SLOPBALL_MIGRATION_OK|examples/replay_slopball/migration_run.sh||native"
    "replayowned3godot|REPLAY_OWNED3_GODOT_OK|tests/replay_owned3_godot/run.sh||native"
    "replayslop3model|REPLAY_SLOPBALL3D_MODEL_OK|tests/replay_slopball3d/run.sh||native"
    "replayslop3|REPLAY_SLOPBALL3D_SINGLE_OK|examples/replay_slopball3d/run.sh||native"
    "replayslop3net|REPLAY_SLOPBALL3D_NETWORK_OK|examples/replay_slopball3d/network_run.sh||native"
    "replayslop3migration|REPLAY_SLOPBALL3D_MIGRATION_OK|examples/replay_slopball3d/migration_run.sh||native"
    "replayeffects|REPLAY_EFFECTS_OK|tests/replay_effects/run.sh||native"
    "replaydirector|REPLAY_DIRECTOR_OK|tests/replay_director/run.sh||native"
    "replayassets|REPLAY_ASSETS_OK|tests/replay_assets/run.sh||native"
    "replaycompress|REPLAY_COMPRESS_OK|tests/replay_compress/run.sh||native"
    "replayrenderaudit|REPLAY_RENDER_AUDIT_OK|tests/replay_render_audit/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaytransfer|REPLAY_TRANSFER_OK|tests/replay_transfer/run.sh||native"
    "replayscrapspraymigration|REPLAY_SCRAPYARD_SPRAY_MIGRATION_OK|examples/replay_scrapyard/spray_migration_run.sh||native"
    "replayscrapwebmigration|REPLAY_SCRAPYARD_WEB_MIGRATION_OK|examples/replay_scrapyard/web_run.sh||browser"
    "replayscrapwebprofile|REPLAY_SCRAPYARD_BROWSER_PROFILE_OK|examples/replay_scrapyard/web_profile_run.sh||browser"
    "replayscrapwebsave|REPLAY_SCRAPYARD_BROWSER_SAVE_OK|examples/replay_scrapyard/web_save_run.sh||browser"
    "replaybrowserstore|REPLAY_BROWSER_STORE_OK|tests/replay_browser_store/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "godotlifetimes|GODOT_LIFETIMES_OK|tests/godot_lifetimes/run.sh||native"
    "replaycomparisonidle|REPLAY_COMPARISON_IDLE_OK|tests/replay_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayscans|REPLAY_SCANS_OK|tests/replay_scans/run.sh||native"
    "replaycomparisoncombat|REPLAY_COMPARISON_COMBAT_OK|tests/replay_comparison/combat_run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replaycomparisonswarm|REPLAY_SWARM_COMPARISON_OK|tests/replay_swarm_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replaybrowserstress|REPLAY_BROWSER_STRESS_OK|tests/replay_browser_stress/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayactiontransport|REPLAY_ACTION_TRANSPORT_OK|tests/replay_action_transport/run.sh||native"
    "replayshuffle|REPLAY_SHUFFLE_OK|tests/replay_shuffle/run.sh||native"
    "replayerasure|REPLAY_ERASURE_OK|tests/replay_erasure/run.sh||native"
    "replaydeltaselection|REPLAY_DELTA_SELECTION_OK|tests/replay_delta_selection/run.sh||native"
    "replaylz4staging|REPLAY_LZ4_STAGING_CHECK_OK|tests/replay_lz4_staging/run.sh||native"
    "replaycorrectionreuse|REPLAY_CORRECTION_REUSE_OK|tests/replay_correction_reuse/run.sh||native"
    "replaycomparisonmixed|REPLAY_MIXED_COMPARISON_OK|tests/replay_mixed_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replaynetworkfaults|REPLAY_NETWORK_FAULTS_OK|tests/replay_network_faults/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayauthoring|REPLAY_AUTHORING_OK|tests/replay_authoring/run.sh||native"
    "replayweaponauthoring|REPLAY_WEAPON_AUTHORING_OK|tests/replay_weapon_authoring/run.sh||native"
    "replaycomparisonfire|REPLAY_COMPARISON_FIRING_OK|tests/replay_comparison/firing_run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayscrapspray|REPLAY_SCRAPYARD_SPRAY_OK|examples/replay_scrapyard/spray_run.sh||native"
    "replayscrapstress|REPLAY_SCRAPYARD_STRESS_OK|examples/replay_scrapyard/stress_run.sh||native"
    "replayscrapmod|REPLAY_SCRAPYARD_MOD_OK|examples/replay_scrapyard/mod_run.sh||native"
    "replayscrapmodmigration|REPLAY_SCRAPYARD_MOD_MIGRATION_OK|examples/replay_scrapyard/mod_migration_run.sh||native"
    "replayscrapassetsave|REPLAY_SCRAPYARD_ASSET_SAVE_OK|examples/replay_scrapyard/save_assets_run.sh||native"
    "replayscrapcoopsave|REPLAY_SCRAPYARD_COOP_SAVE_OK|examples/replay_scrapyard/save_coop_run.sh||native"
    "replayscrapsave|REPLAY_SCRAPYARD_SAVE_OK|examples/replay_scrapyard/save_run.sh||native"
    "replayscrapupgrade|REPLAY_SCRAPYARD_UPGRADE_OK|tests/replay_scrapyard/upgrade_run.sh||native"
    "replayscrapworkbench|REPLAY_WORKBENCH_OK|examples/replay_scrapyard/workbench_run.sh||native"
    "replayscrapshop|REPLAY_SHOP_UI_OK|examples/replay_scrapyard/shop_run.sh||native"
    "replayscraphud|REPLAY_SCRAPYARD_HUD_OK|examples/replay_scrapyard/hud_run.sh||native"
    "replayscrapactors|REPLAY_ACTOR_VIEW_OK|examples/replay_scrapyard/actors_run.sh||native"
    "replayscrapfeedback|REPLAY_FEEDBACK_OK|examples/replay_scrapyard/feedback_run.sh||native"
    "replayscrapscreen|REPLAY_SCREEN_FX_OK|examples/replay_scrapyard/screen_run.sh||native"
    "replayscrapgrenademigration|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/grenade_migration_run.sh||native"
    "replayscrapmusterpeers|REPLAY_SCRAPYARD_MUSTER_PEERS_OK|examples/replay_scrapyard/muster_peers_run.sh||native"
    "replayscrapautomatic|REPLAY_SCRAPYARD_AUTOMATIC_OK|examples/replay_scrapyard/automatic_run.sh||native"
    "replayscrapautoweb|REPLAY_SCRAPYARD_AUTOMATIC_WEB_OK|examples/replay_scrapyard/automatic_web_run.sh||browser"
    "replayscrapmuster|REPLAY_MUSTER_VIEW_OK|examples/replay_scrapyard/muster_run.sh||native"
    "replayscrapmenu|REPLAY_MENU_VIEW_OK|examples/replay_scrapyard/menu_run.sh||native"
    "replayscrapordnanceview|REPLAY_ORDNANCE_VIEW_OK|examples/replay_scrapyard/ordnance_view_run.sh||native"
    "replayscrapyardglobs|REPLAY_GLOB_VIEW_OK|examples/replay_scrapyard/glob_view_run.sh||native"
    "replayscrapyardareas|REPLAY_AREA_VIEW_OK|examples/replay_scrapyard/area_view_run.sh||native"
    "replayscrapyardpaths|REPLAY_CAST_PATH_VIEW_OK|examples/replay_scrapyard/cast_path_run.sh||native"
    "replayscrapwalls|REPLAY_WALL_VIEW_OK|examples/replay_scrapyard/walls_run.sh||native"
    "replayscrapwounds|REPLAY_WOUND_VIEW_OK|examples/replay_scrapyard/wounds_run.sh||native"
    "replayscrapchat|REPLAY_SCRAPYARD_CHAT_OK|examples/replay_scrapyard/chat_run.sh||native"
    "replayscrappings|REPLAY_SCRAPYARD_PINGS_OK|examples/replay_scrapyard/pings_run.sh||native"
    "replayscrapwebui|REPLAY_SCRAPYARD_BROWSER_UI_OK|examples/replay_scrapyard/web_ui_run.sh||browser"
    "replayaudio|REPLAY_AUDIO_OK|tests/replay_audio/run.sh||native"
    "replayscrapsettings|REPLAY_SCRAPYARD_SETTINGS_OK|examples/replay_scrapyard/settings_run.sh||native"
    "replayscrapwebsettings|REPLAY_SCRAPYARD_BROWSER_SETTINGS_OK|examples/replay_scrapyard/web_settings_run.sh||browser"
    "replayscrapdevelopment|REPLAY_SCRAPYARD_DEVELOPMENT_OK|tests/replay_scrapyard/development_run.sh||native"
    "replayscrapprofile|REPLAY_SCRAPYARD_PROFILE_OK|examples/replay_scrapyard/profile_run.sh||native"
    "replayscrapmigration|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/migration_run.sh||native"
    "replayscraplobby|REPLAY_SCRAPYARD_MIGRATION_OK|examples/replay_scrapyard/lobby_migration_run.sh||native"
    "replayscraprun|REPLAY_SCRAPYARD_RUN_OK|examples/replay_scrapyard/run_loop.sh||native"
    "replayscraprevive|REPLAY_SCRAPYARD_REVIVE_OK|examples/replay_scrapyard/revive_run.sh||native"
    "replayscrapgauntlet|REPLAY_SCRAPYARD_GAUNTLET_OK|examples/replay_scrapyard/gauntlet_run.sh||native"
    "replayscrapstorm|REPLAY_SCRAPYARD_STORM_OK|examples/replay_scrapyard/storm_run.sh||native"
    "replayscrapabilities|REPLAY_SCRAPYARD_ABILITIES_OK|examples/replay_scrapyard/abilities_run.sh||native"
    "replayscrapenemies|REPLAY_SCRAPYARD_ENEMIES_OK|examples/replay_scrapyard/enemy_run.sh||native"
    "replaycarom|REPLAY_CAROM_OK|tests/replay_carom/run.sh||native"
    "replayscrapweapons|REPLAY_SCRAPYARD_WEAPONS_OK|examples/replay_scrapyard/weapon_run.sh||native"
    "replaygun|REPLAY_GUN_OK|tests/replay_gun/run.sh||native"
    "replayscrapcombat|REPLAY_SCRAPYARD_COMBAT_OK|examples/replay_scrapyard/combat_run.sh||native"
    "replayscrapmodel|REPLAY_SCRAPYARD_MODEL_OK|tests/replay_scrapyard/run.sh||native"
    "replayscraparena|REPLAY_SCRAPYARD_ARENA_OK|examples/replay_scrapyard/run.sh||native"
    "replayroutes|REPLAY_ROUTES_OK|tests/replay_routes/run.sh||native"
    "replayview|REPLAY_VIEW_OK|tests/replay_view/run.sh||native"
    "replayrotation|REPLAY_ROTATION_OK|tests/replay_rotation/run.sh||native"
    "replayrotationgodot|REPLAY_ROTATION_GODOT_OK|tests/replay_rotation_godot/run.sh||native"
    "replayrotationweb|REPLAY_ROTATION_WEB_OK|tests/replay_rotation_godot/web_run.sh||browser"
    "replayschema|REPLAY_SCHEMA_OK|tests/replay_schema/run.sh||native"
    "replayschemablocks|REPLAY_SCHEMA_BLOCKS_OK|tests/replay_schema_blocks/run.sh||native"
    "replayunions|REPLAY_UNIONS_OK|tests/replay_unions/run.sh||native"
    "replayunionenet|REPLAY_UNION_NETWORK_OK|tests/replay_unions/enet_run.sh||native"
    "replaydiagnostics|REPLAY_DIAGNOSTICS_OK|tests/replay_diagnostics/run.sh||native"
    "replayrecording|REPLAY_RECORDING_OK|tests/replay_recording/run.sh||native"
    "replayplayback|REPLAY_PLAYBACK_OK|tests/replay_recording/playback_run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaynetworkrecording|REPLAY_NETWORK_RECORDING_ALL_OK|tests/replay_network_recording/all.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycavesocialcontract|REPLAY_CAVE_SOCIAL_COMPLETE_OK|tests/replay_cave_social/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycavedirector|REPLAY_CAVE_DIRECTOR_OK|tests/replay_cave_director/run.sh||native"
    "replaycavecarrierbrowser|REPLAY_CAVE_CARRIER_WEB_OK|tests/replay_cave_carrier/web_run.sh||browser"
    "replayrecordingauthorityupgrade|REPLAY_RECORDING_AUTHORITY_UPGRADE_OK|tests/replay_network_recording/upgrade.sh||native"
    "replaydedicatedcombat|REPLAY_DEDICATED_COMBAT_COMPLETE_OK|tests/replay_dedicated_combat/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaydedicatedbrowser|REPLAY_DEDICATED_BROWSER_COMPLETE_OK|tests/replay_dedicated_browser/run.sh||browser"
    "replaydedicatedroom|REPLAY_DEDICATED_ROOM_COMPLETE_OK|tests/replay_dedicated_room/run.sh||native"
    "replaydedicatedcomparison|REPLAY_DEDICATED_COMPARISON_COMPLETE_OK|tests/replay_dedicated_comparison/run.sh|REPLAY_COMPARISON_BASELINE_MISSING|native"
    "replayrestorerenewal|REPLAY_RESTORE_RENEWAL_OK|tests/replay_restore_renewal/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycaveadoption|REPLAY_CAVE_ADOPTION_OK|tests/replay_cave_adoption/run.sh||native"
    "replaycaveadoptionbrowser|REPLAY_CAVE_ADOPTION_WEB_OK|tests/replay_cave_adoption/web_run.sh||browser"
    "replaycavecarrier|REPLAY_CAVE_CARRIER_OK|tests/replay_cave_carrier/run.sh||native"
    "replaycaveowner|REPLAY_CAVE_OWNER_OK|tests/replay_cave_owner/run.sh||native"
    "replaycavecontext|REPLAY_CAVE_ACTION_CONTEXT_OK|tests/replay_cave_context/run.sh||native"
    "replaycavecomparison|REPLAY_CAVE_COMPARISON_OK|tests/replay_cave_comparison/run.sh||native"
    "replayobservationcompat|REPLAY_OBSERVATION_COMPAT_OK|tests/replay_observation_compat/run.sh||native"
    "replaycaveownerbrowser|REPLAY_CAVE_OWNER_BROWSER_OK|tests/replay_cave_owner/browser_run.sh||browser"
    "replaycaverelic|REPLAY_CAVE_RELIC_STATE_OK|tests/replay_cave_relic/run.sh||native"
    "replaycavefloorstate|REPLAY_CAVE_FLOOR_STATE_OK|tests/replay_cave_floor/run.sh||native"
    "replaydebug|REPLAY_DEBUG_OK|tests/replay_debug/run.sh||native"
    "replaydebugports|REPLAY_DEBUG_PORTS_OK|tests/replay_debug/ports_run.sh||native"
    "replayscrubber|REPLAY_SCRUBBER_OK|tests/replay_scrubber/run.sh||native"
    "methodvalues|METHOD_VALUES_OK|tests/method_values/run.sh||native"
    "methodvaluesweb|METHOD_VALUES_WEB_OK|tests/method_values/web_run.sh||browser"
    "replaytransport|REPLAY_TRANSPORT_OK|tests/replay_transport/run.sh||native"
    "replayenet|REPLAY_ENET_OK|tests/replay_enet/run.sh||native"
    "replayauthrtc|REPLAY_AUTHENTICATED_RTC_SERVICE_OK|tests/replay_web_authority/signal_run.sh||browser"
    "replaycavebrowsersave|REPLAY_CAVE_BROWSER_SAVE_OK|examples/replay_cavecrawl/browser_save_run.sh||browser"
    "replaycavelobbyweb|REPLAY_CAVE_LOBBY_WEB_OK|examples/replay_cavecrawl/lobby_web_run.sh||browser"
    "replaycavesocialweb|REPLAY_CAVE_SOCIAL_WEB_OK|examples/replay_cavecrawl/social_web_run.sh||browser"
    "replaycavewebmigration|REPLAY_CAVE_WEB_MIGRATION_OK|examples/replay_cavecrawl/web_run.sh||browser"
    "replaywebauthority|REPLAY_WEB_AUTHORITY_OK|tests/replay_web_authority/run.sh||browser"
    "replaymigrationws|REPLAY_MIGRATION_WEBSOCKET_OK|tests/replay_migration/websocket_run.sh||native"
    "replayrtc|REPLAY_RTC_OK|tests/replay_rtc/run.sh||browser"
    "replayptrcallabi|REPLAY_PTRCALL_ABI_OK|tests/replay_ptrcall_abi/run.sh||native"
    "replaynet|REPLAY_NET_OK|tests/replay_net/run.sh||native"
    "replaylz4|REPLAY_LZ4_OK|tests/replay_lz4/run.sh||native"
    "replaysnapshotcompat|REPLAY_SNAPSHOT_COMPAT_ALL_OK|tests/replay_snapshot_compat/run.sh||native"
    "replayscrapyardstartup|REPLAY_SCRAPYARD_STARTUP_OK|tests/replay_scrapyard_startup/run.sh||native"
    "replayauthority|REPLAY_AUTHORITY_OK|tests/replay_authority/run.sh||native"
    "replayauthoritysqlite|REPLAY_AUTHORITY_SQLITE_OK|tests/replay_authority_sqlite/run.sh||native"
    "replayprovision|REPLAY_PROVISION_OK|tests/replay_provision/run.sh||native"
    "replayprovisionsqlite|REPLAY_PROVISION_SQLITE_OK|tests/replay_provision_sqlite/run.sh||native"
    "replayprovisiongodotcore|REPLAY_PROVISION_GODOT_CORE_OK|tests/replay_provision_godot_core/run.sh||native"
    "replayprovisiontls|REPLAY_PROVISION_TLS_OK|tests/replay_provision_godot/run.sh||native"
    "replayiceconfig|REPLAY_ICE_CONFIG_OK|tests/replay_turn/config_run.sh||native"
    "replayrelayprovider|REPLAY_RELAY_PROVIDER_OK|tests/replay_relay/run.sh||native"
    "replaydistribution|REPLAY_DISTRIBUTION_OK|tests/replay_distribution/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayenrollment|REPLAY_ENROLLMENT_OK|tests/replay_enrollment/run.sh||native"
    "replayenrollmentnative|REPLAY_ENROLLMENT_NATIVE_OK|tests/replay_enrollment_godot/run.sh||native"
    "replayenrollmentweb|REPLAY_ENROLLMENT_WEB_OK|tests/replay_enrollment_godot/web_run.sh||browser"
    "replayscrapyardonline|REPLAY_SCRAPYARD_ONLINE_OK|examples/replay_scrapyard/online_run.sh||native"
    "replayscrapyardonlineweb|REPLAY_SCRAPYARD_ONLINE_WEB_OK|examples/replay_scrapyard/online_web_run.sh||browser"
    "replayauthorityservice|REPLAY_AUTHORITY_SERVICE_OK|tests/replay_authority_service/run.sh||native"
    "replaymigrationplanned|REPLAY_MIGRATION_PLANNED_OK|tests/replay_migration/run.sh||native"
    "replaymigrationcrash|REPLAY_MIGRATION_CRASH_OK|tests/replay_migration/crash_run.sh||native"
    "replaymigrationextended|REPLAY_MIGRATION_EXTENDED_OK|tests/replay_migration/extended_run.sh||native"
    "replaymigrationpartition|REPLAY_MIGRATION_PARTITION_LOSS_OK|tests/replay_migration/partition_run.sh||native"
    "replaylease|REPLAY_LEASE_GODOT_OK|tests/replay_authority_godot/run.sh||native"
    "launchparams|LAUNCH_PARAMS_OK|tests/launch_params/run.sh||native"
    "replayinterest|REPLAY_INTEREST_OK|tests/replay_interest/run.sh||native"
    "replayschemabench|REPLAY_SCHEMA_BENCH_OK|tests/replay_schema_bench/run.sh||native"
    "replayinterestcorpus|REPLAY_INTEREST_CORPUS_OK|tests/replay_interest/corpus_run.sh||native"
    "replayinterestgodot|REPLAY_INTEREST_GODOT_ALL_OK|tests/replay_interest/godot_run.sh||native"
    "replaysteamcore|REPLAY_STEAM_CORE_OK|tests/replay_steam_core/run.sh||native"
    "replaysteamroom|REPLAY_STEAM_ROOM_CONTRACT_ALL_OK|tests/replay_steam_room/run.sh||native"
    "replaysteamcontract|REPLAY_STEAM_CONTRACT_ALL_OK|tests/replay_steam/run.sh||native"
    "replaybrowsercheckpoint|REPLAY_BROWSER_CHECKPOINT_CORE_OK|tests/replay_browser_checkpoint/run.sh||native"
    "replaylobby|REPLAY_LOBBY_OK|tests/replay_lobby/run.sh||native"
    "replayobservernames|REPLAY_OBSERVER_NAMES_OK|tests/replay_observer_names/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycommsgodot|REPLAY_COMMS_GODOT_OK|tests/replay_comms_godot/run.sh||native"
    "replaytelemetrygodot|REPLAY_TELEMETRY_GODOT_OK|tests/replay_telemetry_godot/run.sh||native"
    "replaytelemetry|REPLAY_TELEMETRY_OK|tests/replay_telemetry/run.sh||native"
    "replaycomms|REPLAY_COMMS_OK|tests/replay_comms/run.sh||native"
    "replayrecovery|REPLAY_RECOVERY_OK|tests/replay_recovery/run.sh||native"
    "replayreplica|REPLAY_REPLICA_ENET_OK|tests/replay_recovery_enet/run.sh||native"
    "replaydelta|REPLAY_DELTA_OK|tests/replay_delta/run.sh||native"
    "replaycavecore|REPLAY_CAVE_CORE_OK|tests/replay_cave/run.sh||native"
    "replaycavescatter|REPLAY_CAVE_SCATTER_OK|tests/replay_cave/scatter_run.sh||native"
    "replayquickdrawcore|REPLAY_QUICKDRAW_CORE_OK|tests/replay_quickdraw/run.sh||native"
    "replayquickdrawui|REPLAY_QUICKDRAW_UI_OK|tests/replay_quickdraw_ui/run.sh||native"
    "replayquickdrawfeedback|REPLAY_QUICKDRAW_FEEDBACK_OK|tests/replay_quickdraw_feedback/run.sh||native"
    "replayquickdrawsave|REPLAY_QUICKDRAW_SAVE_OK|tests/replay_quickdraw_save/run.sh||native"
    "replayquickdrawonline|REPLAY_QUICKDRAW_ONLINE_OK|tests/replay_quickdraw_online/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayquickdrawbrowsersave|REPLAY_QUICKDRAW_BROWSER_SAVE_OK|tests/replay_quickdraw_browser_save/run.sh||browser"
    "replayquickdrawpartyrestore|REPLAY_QUICKDRAW_PARTY_RESTORE_OK|tests/replay_quickdraw_party_restore/run.sh||browser"
    "replayquickdrawnativerestore|REPLAY_QUICKDRAW_NATIVE_RESTORE_OK|tests/replay_quickdraw_native_restore/run.sh||native"
    "replayquickdrawsolo|REPLAY_QUICKDRAW_SOLO_OK|examples/replay_quickdraw/run.sh||native"
    "replayquickdrawnetwork|REPLAY_QUICKDRAW_NETWORK_OK|examples/replay_quickdraw/network_run.sh||native"
    "replayquickdrawmigration|REPLAY_QUICKDRAW_MIGRATION_OK|examples/replay_quickdraw/migration_run.sh||native"
    "replayquickdrawearlyclaim|REPLAY_QUICKDRAW_EARLY_CLAIM_OK|examples/replay_quickdraw/early_claim_run.sh||native"
    "replayquickdrawearlyclaimfault|REPLAY_QUICKDRAW_EARLY_CLAIM_FAULT_OK|examples/replay_quickdraw/early_claim_fault_run.sh||native"
    "replayspeedballcore|REPLAY_SPEEDBALL_CORE_OK|tests/replay_speedball/run.sh||native"
    "replayspeedballsolo|REPLAY_SPEEDBALL_SOLO_OK|examples/replay_speedball/run.sh||native"
    "replayspeedballnetwork|REPLAY_SPEEDBALL_NETWORK_OK|examples/replay_speedball/network_run.sh||native"
    "replayspeedballui|REPLAY_SPEEDBALL_UI_OK|examples/replay_speedball/ui_run.sh||native"
    "replayspeedballmigration|REPLAY_SPEEDBALL_MIGRATION_OK|examples/replay_speedball/migration_run.sh||native"
    "replayspeedballround|REPLAY_SPEEDBALL_ROUND_OK|examples/replay_speedball/round_run.sh||native"
    "replayspeedballprofile|REPLAY_SPEEDBALL_PROFILE_OK|examples/replay_speedball/profile_run.sh||native"
    "replayspeedballsave|REPLAY_SPEEDBALL_SAVE_OK|examples/replay_speedball/save_run.sh||native"
    "replayspeedballparty|REPLAY_SPEEDBALL_PARTY_OK|examples/replay_speedball/online_run.sh||native"
    "replayspeedballpartyweb|REPLAY_SPEEDBALL_ONLINE_WEB_OK|examples/replay_speedball/online_web_run.sh||browser"
    "replayspeedballsaveweb|REPLAY_SPEEDBALL_BROWSER_SAVE_OK|examples/replay_speedball/browser_save_run.sh||browser"
    "replayslopballrounds|REPLAY_SLOPBALL_ROUND_OK|tests/replay_slopball_ui/round_run.sh||native"
    "replayslopball3drounds|REPLAY_SLOPBALL3D_ROUND_OK|tests/replay_slopball3d_ui/round_run.sh||native"
    "replayslopballpartyrestore|REPLAY_SLOPBALL_PARTY_RESTORE_OK|tests/replay_slopball_party_restore/run.sh||browser"
    "replayslopballnativerestore|REPLAY_SLOPBALL_NATIVE_RESTORE_OK|tests/replay_slopball_native_restore/run.sh||native"
    "replayslopball3dpartyrestore|REPLAY_SLOPBALL3D_PARTY_RESTORE_OK|tests/replay_slopball3d_party_restore/run.sh||browser"
    "replayslopball3dnativerestore|REPLAY_SLOPBALL3D_NATIVE_RESTORE_OK|tests/replay_slopball3d_native_restore/run.sh||native"
    "replayslopballbrowsersave|REPLAY_SLOPBALL_BROWSER_SAVE_OK|tests/replay_slopball_browser_save/run.sh||browser"
    "replayslopball3dbrowsersave|REPLAY_SLOPBALL3D_BROWSER_SAVE_OK|tests/replay_slopball3d_browser_save/run.sh||browser"
    "replayslopball3donline|REPLAY_SLOPBALL3D_ONLINE_OK|tests/replay_slopball3d_online/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayslopballonline|REPLAY_SLOPBALL_ONLINE_OK|tests/replay_slopball_online/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayslopballsave|REPLAY_SLOPBALL_SAVE_OK|tests/replay_slopball_save/run.sh||native"
    "replayslopball3dsave|REPLAY_SLOPBALL3D_SAVE_OK|tests/replay_slopball3d_save/run.sh||native"
    "replayslopball3dui|REPLAY_SLOPBALL3D_UI_OK|tests/replay_slopball3d_ui/run.sh||native"
    "replayslopballui|REPLAY_SLOPBALL_UI_OK|tests/replay_slopball_ui/run.sh||native"
    "replayclaimballbrowsersave|REPLAY_CLAIMBALL_BROWSER_SAVE_OK|tests/replay_claimball_browser_save/run.sh||browser"
    "replayclaimballpartyrestore|REPLAY_CLAIMBALL_PARTY_RESTORE_OK|tests/replay_claimball_party_restore/run.sh||browser"
    "replayclaimballnativerestore|REPLAY_CLAIMBALL_NATIVE_RESTORE_OK|tests/replay_claimball_native_restore/run.sh||native"
    "replayclaimballonline|REPLAY_CLAIMBALL_ONLINE_OK|tests/replay_claimball_online/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaybackupstatus|REPLAY_ROOM_BACKUP_STATUS_OK|tests/replay_room_backup_status/run.sh||native"
    "replayroomexpiry|REPLAY_ROOM_EXPIRY_OK|tests/replay_room_expiry/run.sh||native"
    "replayclaimballmigration|REPLAY_CLAIMBALL_MIGRATION_OK|tests/replay_claimball_migration/run.sh||native"
    "replayclaimballsave|REPLAY_CLAIMBALL_SAVE_OK|tests/replay_claimball_save/run.sh||native"
    "replayclaimballrounds|REPLAY_CLAIMBALL_ROUND_OK|tests/replay_claimball_ui/round_run.sh||native"
    "replaytransporttrace|REPLAY_TRANSPORT_TRACE_OK|tests/replay_transport_trace/run.sh||native"
    "replayclaimballtrace|REPLAY_CLAIMBALL_TRACE_OK|tests/replay_claimball_trace/run.sh||native"
    "replayclaimballresynceffects|REPLAY_CLAIMBALL_RESYNC_EFFECTS_OK|tests/replay_claimball_resync/run.sh||native"
    "replayclaimballui|REPLAY_CLAIMBALL_UI_OK|tests/replay_claimball_ui/run.sh||native"
    "replayclaimballcore|REPLAY_CLAIMBALL_CORE_OK|tests/replay_claimball/run.sh||native"
    "replayclaimballsolo|REPLAY_CLAIMBALL_SOLO_OK|examples/replay_claimball/run.sh||native"
    "replayclaimballnetwork|REPLAY_CLAIMBALL_NETWORK_OK|examples/replay_claimball/network_run.sh||native"
    "replayclaimballcompete|REPLAY_CLAIMBALL_COMPETE_OK|examples/replay_claimball/compete_run.sh||native"
    "replayclaimballfaults|REPLAY_CLAIMBALL_FAULT_OK|examples/replay_claimball/fault_run.sh||native"
    "replayclaimballstall|REPLAY_CLAIMBALL_STALL_OK|examples/replay_claimball/stall_run.sh||native"
    "replaycavesolo|REPLAY_CAVE_SOLO_OK|examples/replay_cavecrawl/run.sh||native"
    "replaycavedefinitions|REPLAY_CAVE_DEFINITION_GATE_OK|examples/replay_cavecrawl/definitions_run.sh||native"
    "replaycavedefinitionsnetwork|REPLAY_CAVE_DEFINITION_NETWORK_ALL_OK|examples/replay_cavecrawl/definitions_network_run.sh||native"
    "replaycaveupgrade|REPLAY_CAVE_UPGRADE_GATE_OK|tests/replay_cave/upgrade/run.sh||native"
    "replaycavelobbymigration|REPLAY_CAVE_LOBBY_MIGRATION_OK|tests/replay_migration/lobby_run.sh||native"
    "replaycavelobby|REPLAY_CAVE_LOBBY_ALL_OK|examples/replay_cavecrawl/lobby_run.sh||native"
    "replaycaveonline|REPLAY_CAVE_ONLINE_OK|examples/replay_cavecrawl/online_run.sh||native"
    "replaycaveonlineweb|REPLAY_CAVE_ONLINE_WEB_OK|examples/replay_cavecrawl/online_web_run.sh||browser"
    "replaycaverestart|REPLAY_CAVE_RESTART_ALL_OK|examples/replay_cavecrawl/restart_run.sh||native"
    "replaycavecontent2|REPLAY_CAVE_CONTENT2_UPGRADE_OK|tests/replay_cave/upgrade/content2_run.sh||native"
    "replaycavesocialmigration|REPLAY_CAVE_SOCIAL_MIGRATION_ALL_OK|tests/replay_migration/social_run.sh||native"
    "replaycavesocial|REPLAY_CAVE_SOCIAL_ALL_OK|examples/replay_cavecrawl/social_run.sh||native"
    "replaycavemoderation|REPLAY_CAVE_MODERATION_OK|tests/replay_cave_moderation/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycaverocks|REPLAY_CAVE_ROCKS_OK|tests/replay_cave_rocks/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycaveimpact|REPLAY_CAVE_IMPACT_OK|tests/replay_cave_impact/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycavefeedback|REPLAY_CAVE_FEEDBACK_OK|tests/replay_cave_feedback/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replaycavecampaign|REPLAY_CAVE_CAMPAIGN_ALL_OK|examples/replay_cavecrawl/campaign_run.sh||native"
    "replaycavenetwork|REPLAY_CAVE_NETWORK_OK|examples/replay_cavecrawl/network_run.sh||native"
    "replaycavereplication|REPLAY_CAVE_REPLICATION_OK|examples/replay_cavecrawl/replication_run.sh||native"
    "replaycavesave|REPLAY_CAVE_SAVE_RESUME_OK|examples/replay_cavecrawl/save_run.sh||native"
    "replaycaverecovery|REPLAY_CAVE_RECOVERY_OK|examples/replay_cavecrawl/recovery_run.sh||native"
    "replaysharedalias|REPLAY_SHARED_ALIAS_OK|tests/replay_shared_alias/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayhelloinput|REPLAY_HELLO_INPUT_OK|tests/replay_hello_input/run.sh|SUITE_NATIVE_ONLY_OK|mixed"
    "replayhello|REPLAY_HELLO_OK|examples/replay_hello/run.sh||native"
    "replaynetwork|REPLAY_NETWORK_OK|examples/replay_hello/network_run.sh||native"
    # Pure-Odin checks for the named complete-stack network profiles: resolved
    # rates/history plus cross-field and dedicated-authority guardrails.
    "kitnetcfg|KITNETCFG_OK|tests/kitnetcfg/run.sh||native"
    # Pure-Odin unit tests for kit/session — player identity (reconnect tokens ->
    # stable Player_Ids), join/leave/reconnect, roster sync, zombie takeover.
    "kitsession|KITSESSION_OK|tests/kitsession/run.sh||native"
    # Entity-census cardinality in both dev and release guard modes: singular
    # ownership returns exactly one and ambiguity can never become first-match.
    "kitboot|KITBOOT_OK|tests/kitboot/run.sh||native"
    # The kit's SCALE benchmark — delta/join/save CPU+bytes+memory at
    # 100/500/2000 entities, per-recipient fanout at 2/4/8 players, and forced
    # resimulation at 32/128/512 predicted entities. Timings use loose
    # complexity tripwires (see STRESS/FANOUT/RESIM in the log).
    "kitstress|KITSTRESS_OK|tests/kitstress/run.sh||native"
    # Pure-Odin unit tests for kit/comms — host-ordered chat, positional
    # markers, system lines, late-join catchup, and SES_APP route gating.
    "kitcomms|KITCOMMS_OK|tests/kitcomms/run.sh||native"
    # Pure-Odin unit tests for kit/xfer's ALBUM — kept payloads per (player,
    # kind), own-copy short circuit, supersede, late-join catch-up.
    "kitxfer|KITXFER_OK|tests/kitxfer/run.sh||native"
    # Pure-Odin unit tests for kit/items (stack-aware slot ops, deterministic +
    # allocation-free for predicted commands) and kit/interact (range/facing gates).
    "kititems|KITITEMS_OK|tests/kititems/run.sh||native"
    # Phase-3 integration: chests/bags/doors over the session pipeline — the
    # two-spelunkers-one-gem conflict, the cross-entity command-hook pattern,
    # range gates shared by prompt and host, item conservation on every peer.
    "kitloot|KITLOOT_OK|tests/kitloot/run.sh||native"
    # Pure-Odin unit tests for kit/combat (damage, ability gates, effects,
    # swept projectiles, auto-published stat columns).
    "kitcombat|KITCOMBAT_OK|tests/kitcombat/run.sh||native"
    # Phase-4 integration: rocks over the session pipeline — predicted casts,
    # host-validated hits, death/respawn, effects wearing off, the ledger.
    "kitarena|KITARENA_OK|tests/kitarena/run.sh||native"
    # Pure-Odin unit tests for kit/ai (perception, steering, the wave director).
    "kitai|KITAI_OK|tests/kitai/run.sh||native"
    # Pure-Odin unit tests for kit/fx's trauma shake (legacy zero-value feel,
    # the knobs, coherence, rotation channels).
    "kitfx|KITFX_OK|tests/kitfx/run.sh||native"
    # kit/nav adapter: a U-shaped NavigationPolygon the engine path must bend
    # through, followed by a kit/ai walker with the next_point cursor.
    "kitnav|KITNAV_OK|tests/kitnav/run.sh||native"
    # kit/save envelope: the save saga (save, die, resume, rejoin by token,
    # still-playable) + foreign/corrupt saves refusing to parse.
    "kitsave|KITSAVE_OK|tests/kitsave/run.sh||native"
    # gd:"replicate" codegen contract: scriptgen -> knet.Entity_Desc tables, POD
    # enforcement at scriptgen time (engine types) + consumer compile (#assert).
    "repgen|REPGEN_OK|tests/repgen/run.sh||native"
    # Two-peer ENet sync: the toolkit's full replication stack across a REAL wire
    # (replicate tag -> desc -> shadow delta -> send_bytes -> peer_packet -> apply).
    "kitsync|KITSYNC_OK|tests/kitsync/run.sh||native"
    # kit/sim solo gate: the sim-lane loop headless end to end — @(gd_tick)
    # movement, the world pass, a lane_rewound shot — host-with-no-peers.
    "quickdrawsingle|QUICKDRAW_SINGLE_OK|examples/quickdraw/run.sh||native"
    # THE DUEL ACID (three processes, ENet, 120ms injected latency each way):
    # a deadeye fires at a perpendicular-crossing strafer exactly where its
    # screen renders it. Lag comp ON: the shots land (kill -> respawn). The
    # SAME duel judged live: they miss. The gap is the feature, proved A/B.
    "quickdrawnative|QUICKDRAW_NATIVE_OK|examples/quickdraw/native_run.sh||native"
    # speedball solo gate: the contested-ball loop headless — dribble, kick,
    # predicted goal reset, delta-lane score via ball_tick_then.
    "speedballsingle|SPEEDBALL_SINGLE_OK|examples/speedball/run.sh||native"
    # THE CONTESTED-BALL ACID (three processes, ENet, 120ms each way):
    # @(gd_tick="contested") — the striker's own screen kicks its own
    # predicted ball at 240ms RTT, the goal reset predicts everywhere, the
    # score rides the delta lane, three screens agree.
    "speedballnative|SPEEDBALL_NATIVE_OK|examples/speedball/native_run.sh||native"
    # THE PHASE-0 ACID TEST: host + owning client + OBSERVER (three processes) over
    # ENet with injected receive latency on every peer. A new entity in ~10 lines
    # (orb.odin), zero role branches: predictions land before any round trip,
    # in-flight deltas reconcile (unwind -> apply -> replay) instead of stomping
    # them, the observer converges with no role code, and clock sync measures the
    # real RTT. tests/kitacid/scripts/session.odin is the seed of kit/session.
    "kitacid|KITACID_OK|tests/kitacid/run.sh||native"
    # Pure-Odin unit tests for the runtime-reflection registration walk (register_class).
    "reflectregister|REFLECT_REGISTER_OK|tests/reflect_register/run.sh||native"
    "phase1|PHASE1_OK|tests/phase1/run.sh||native"
    "phase2|PHASE2_OK|tests/phase2/run.sh||native"
    "phase3|PHASE3_OK|tests/phase3/run.sh||native"
    "phase35|PHASE35_OK|tests/phase35/run.sh||native"
    # Asset-Library drop-in layout: core dll inside addons/odin_godot/bin/<platform>/,
    # scripts dll at res://bin — NOT siblings. Pins the core's scripts-dll resolution.
    "splitaddon|SPLITADDON_OK|tests/splitaddon/run.sh||native"
    "phase4|PHASE4_OK|tests/phase4/run.sh||native"
    # Multi-module spike: one dll per script module (res://modules/<name>), per-module
    # hot reload with other modules provably untouched, engine-mediated cross-module
    # calls, module-local script_of, loud class-collision + cross-import rejection.
    "modspike|MODULES_SPIKE_OK|tests/modules_spike/run.sh||native"
    # Script SUBPACKAGES: annotated classes in subfolders of a module (still one dll).
    # A subfolder script attaches + reloads with state preserved, the root reads it TYPED
    # in-dll, and the four refusals hold (kit annotation, root import, dup package, dup class).
    "subpkgspike|SUBPKG_SPIKE_OK|tests/subpkg_spike/run.sh||native"
    # SHARED vocabulary tree: res://shared/<pkg> — read-only types/constants/pure procs
    # importable by EVERY module. Two dlls agree on one vocabulary, one shared edit
    # rebuilds+swaps both modules in a live editor, and the refusals hold (mutable global,
    # @(init), //gd: marker, shared->module import, tagged bundle, cross-module import).
    "sharedspike|SHARED_SPIKE_OK|tests/shared_spike/run.sh||native"
    "phase5|PHASE5_OK|tests/phase5/run.sh||native"
    "showcase|SHOWCASE_OK|tests/showcase/run.sh||native"
    "autoload|AUTOLOAD_OK|tests/autoload/run.sh||native"
    "ergonomics|ERGONOMICS_OK|tests/ergonomics/run.sh||native"
    "exporttypes|EXPORT_TYPES_OK|tests/export_types/run.sh||native"
    "codegen|CODEGEN_OK|tests/codegen/run.sh||native"
    "resources|RESOURCES_OK|tests/resources/run.sh||native"
    "crossscript|CROSSSCRIPT_OK|tests/crossscript/run.sh||native"
    "rpc|RPC_OK|tests/rpc/run.sh||native"
    # Two REAL peers over ENet (a server + a client process) exchange @(gd_rpc) calls both
    # directions with correct sender ids — the genuine remote path tests/rpc could not reach.
    "rpcnet|RPC_NET_OK|tests/rpc_net/run.sh||native"
    "survivors|SURVIVORS_OK|examples/survivors/run.sh||native"
    # CAVECRAWL (the friendslop toolkit's example, grown per phase). Phase 1: boots
    # to a WORKING LOBBY — two real peers seat via kit/session (tokens, roster) and
    # the test reads the ACTUAL kit/ui player-list labels back out of both trees
    # (names, you-marker, host crown, host-only Start button).
    "cavecrawl|CAVECRAWL_OK|examples/cavecrawl/run.sh||native"
    # Barrage: the data-oriented showcase — thousands of #soa bullets through ONE
    # RenderingServer multimesh, 5 isolated script modules, boss via the flow sequencer,
    # powerup resources, multi-scene UI. See examples/barrage/README.md.
    "barrage|BARRAGE_OK|examples/barrage/run.sh||native"
    # MultiplayerSpawner + MultiplayerSynchronizer with Odin scripts, in isolation over ENet:
    # the host spawns an Odin-scripted scene (replicated to the client) whose native position +
    # Odin @export field sync via the synchronizer. The de-risking proof the co-op game uses.
    "replspike|SPIKE_OK|tests/repl_spike/run.sh||native"
    # CO-OP NATIVE (ENet): two REAL peers run the unified co-op survivors (coop.tscn). Proves
    # connection, both players on both peers, client-move replication via MultiplayerSynchronizer,
    # host enemy spawn via MultiplayerSpawner, enemy position sync, authoritative death, shared
    # score, and a per-player level-up — all asserted from both processes' stdout.
    "coopnative|COOP_NATIVE_OK|examples/survivors/coop_native_run.sh||native"
    # UNIFIED PEER-AUTHORITATIVE co-op arena, SINGLE-PLAYER mode: the ONE gameplay codebase runs
    # solo as host-with-no-peers (same pawn/bullet/enemy scripts) — move, auto-fire kills, XP/
    # level, contact death.
    "arenasingle|ARENA_SINGLE_OK|examples/coop_arena/run.sh||native"
    # UNIFIED PEER-AUTHORITATIVE co-op arena, NATIVE (ENet): two REAL peers prove the OWNER-auth
    # netcode — both owner-auth pawns on both peers, local-first move replication, OWNER-LOCAL
    # bullet immediacy (the firer's bullet exists the same tick, NO host round-trip) + broadcast,
    # a peer-authoritative kill agreed by both peers, despawn replication, XP to the firer.
    "arenanative|ARENA_NATIVE_OK|examples/coop_arena/coop_native_run.sh||native"
    # THE QUICKSTART, kept honest: hello_net (docs/kit/quickstart.md's living copy) in two
    # headless windows under 120ms — the guest watches the host's walk arrive through the
    # wire, read entirely through GENERATED probes on the acid harness (its smallest consumer).
    "hellonet|HELLO_NET_OK|examples/hello_net/run.sh||native"
    # THE SIM QUICKSTART: hello_net promoted per the checklist (retag/tick/sample/two wires).
    # Pins the promotion's two receipts under 120ms each way: the guest's OWN square moves
    # within half a second of the press (prediction), the host's walk arrives watched.
    "hellosim|HELLO_SIM_OK|examples/hello_sim/run.sh||native"
    # ENGINE-PHYSICS soccer, SOLO: a real RigidBody2D ball (play.Puppet) + a move_and_slide
    # striker run the whole loop headless — kick, goal off the replicated pose, match edge.
    # The repo's only exercise of the 2D physics SOLVER under --headless.
    "slopballsingle|SLOPBALL_SINGLE_OK|examples/slopball/run.sh||native"
    # ENGINE-PHYSICS soccer, NATIVE (ENet, 3 peers): the Puppet proof — the host GRANTS the
    # ball's simulation seat to the striker CLIENT (Ev_Owner_Changed on all three screens),
    # the striker's LOCAL solver drives the goal, the host scores it off the streamed pose,
    # and all three screens report the ball within a few px at the same session tick.
    "slopballnative|SLOPBALL_NATIVE_OK|examples/slopball/native_run.sh||native"
    # DEDICATED SERVER: the kit's infrastructure seat end to end — an avatarless server
    # (kboot.boot_serve → session_host_start dedicated=true) referees two real clients:
    # player-only start gating, no kicker for the server on ANY screen (the flag rides the
    # welcome roster), seat grants + goals unchanged. Succession never arms on a server.
    "slopballserver|SLOPBALL_SERVER_OK|examples/slopball/server_run.sh||native"
    # ENGINE-PHYSICS soccer in 3D, SOLO: a RigidBody3D ball under real gravity (play.Puppet3,
    # quaternion orientation) + an XZ-plane move_and_slide striker — lofted kick, goal off the
    # replicated pose, match edge. The repo's only exercise of the 3D physics SOLVER headless.
    "slopball3dsingle|SLOPBALL3D_SINGLE_OK|examples/slopball3d/run.sh||native"
    # ENGINE-PHYSICS soccer in 3D, NATIVE (ENet, 3 peers): the Puppet3 proof — seat granted to
    # the striker CLIENT, its LOCAL 3D solver (gravity + tumble) drives the goal, the host
    # scores it off the streamed pose, the ball's QUATERNION nlerps on every watcher, and all
    # three screens report the ball within centimeters at the same session tick.
    "slopball3dnative|SLOPBALL3D_NATIVE_OK|examples/slopball3d/native_run.sh||native"
    "validate|VALIDATE_HARNESS_OK|tests/validate/run.sh||native"
    "complete|COMPLETE_HARNESS_OK|tests/complete/run.sh||native"
    "lookup|LOOKUP_OK|tests/lookup/run.sh||native"
    "gdextalloc|GDEXT_ALLOC_OK|tests/gdext_alloc/run.sh||native"
    "lsp|LSP_HARNESS_OK|tests/lsp/run.sh||native"
    "save|SAVE_TEST_OK|tests/save/run.sh||native"
    "editor|EDITOR_SMOKE_OK|tests/editor_smoke/run.sh||native"
    "editortools|EDITORTOOLS_OK|tests/editortools/run.sh||native"
    "debug|DEBUG_OK|tests/debug/run.sh||native"
    # Crash/panic REPORTING: a script panic prints ODIN_SCRIPT_PANIC (msg + file:line)
    # and push_errors it (editor-visible); a raw SIGSEGV in script code triggers the
    # fatal-signal reporter (ODIN_GODOT_CRASH + symbolized faulting Odin frame +
    # backtrace) and still chains to Godot's own crash handler.
    "crash|CRASH_TEST_OK|tests/crash/run.sh||native"
    # Editor-launched lldb debugging (build/debug_game.sh): file:line breakpoints bind
    # across the scripts-dll dlopen (the -use-single-module regression net), named args
    # + godot_lldb.py printers live, and a script panic freezes the session in place.
    # Darwin-only (SKIPs elsewhere / without a working lldb).
    "debuglaunch|DEBUG_LAUNCH_OK|tests/debug_launch/run.sh|DEBUG_LAUNCH_SKIP|native"
    "reloadexports|RELOAD_EXPORTS_OK|tests/reload_exports/run.sh||native"
    # Cross-build smoke: self-gating — prints CROSS_SKIP (a non-fatal SKIP) when no
    # Linux/Windows cross toolchain is present, so the default macOS shell stays green. To
    # actually exercise the cross builds: `nix develop .#cross --command bash tests/cross/run.sh`.
    "cross|CROSS_OK|tests/cross/run.sh|CROSS_SKIP|native"
)

# Legacy export gates remain best-effort when a browser is unavailable. They
# declare the same capability as every other browser entry.
TESTS+=(
    "web|PHASEWEB_OK|tests/web/run.sh|PHASEWEB_BUNDLED|gated-browser"
    "web_showcase|PHASEWEBSHOWCASE_OK|tests/web_showcase/run.sh|PHASEWEBSHOWCASE_BUNDLED|gated-browser"
    "modules_web|MODULES_WEB_OK|tests/modules_web/run.sh|MODULES_WEB_BUNDLED|gated-browser"
    "webrtc|WEBRTC_OK|tests/webrtc/run.sh|WEBRTC_BUNDLED|gated-browser"
    "coopweb|COOP_WEB_OK|examples/survivors/coop_web_run.sh|COOP_WEB_BUNDLED|gated-browser"
    "arenaweb|ARENA_WEB_OK|examples/coop_arena/coop_web_run.sh|ARENA_WEB_BUNDLED|gated-browser"
    "barrageweb|BARRAGE_WEB_OK|examples/barrage/web_run.sh|BARRAGE_WEB_BUNDLED|gated-browser"
)

known='|'
for entry in "${TESTS[@]}"; do
    IFS='|' read -r name sentinel script skip capability extra <<<"$entry"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_]+$ || -z "$sentinel" || -z "$script" || -n "${extra:-}" ]]; then
        echo "run_all: invalid manifest entry: $entry" >&2; exit 2
    fi
    case "$capability" in native|browser|mixed|gated-browser) ;; *)
        echo "run_all: undeclared capability for $name" >&2; exit 2 ;; esac
    if [[ "$known" == *"|$name|"* ]]; then
        echo "run_all: duplicate test name: $name" >&2; exit 2
    fi
    known="$known$name|"
done
for name in ${REQUESTED[@]+"${REQUESTED[@]}"}; do
    if [[ "$known" != *"|$name|"* ]]; then
        echo "run_all: unknown test: $name" >&2; exit 2
    fi
done
selected() {
    local name="$1" position="$2" request matched=0
    (( position % SHARD_COUNT == SHARD_INDEX )) || return 1
    [[ ${#REQUESTED[@]} -gt 0 ]] || return 0
    for request in "${REQUESTED[@]}"; do [[ "$request" != "$name" ]] || matched=1; done
    [[ "$matched" == 1 ]]
}
SELECTED_COUNT=0
for position in "${!TESTS[@]}"; do
    IFS='|' read -r name sentinel script skip capability <<<"${TESTS[$position]}"
    if selected "$name" "$position"; then
        SELECTED_COUNT=$((SELECTED_COUNT + 1))
        if [[ "$LIST_ONLY" == 1 ]]; then printf '%s\t%s\t%s\n' "$name" "$capability" "$script"; fi
    fi
done
if [[ "$SELECTED_COUNT" == 0 ]]; then echo 'run_all: selection contains no checks' >&2; exit 2; fi
[[ "$LIST_ONLY" == 0 ]] || exit 0

LOGDIR="${SUITE_LOGDIR:-$ROOT/tests/.logs}"
mkdir -p "$LOGDIR"
REPORT="$LOGDIR/report.json"
MANIFEST="$LOGDIR/manifest.tsv"
: >"$MANIFEST"
for position in "${!TESTS[@]}"; do
    IFS='|' read -r name sentinel script skip capability <<<"${TESTS[$position]}"
    include=0
    if selected "$name" "$position"; then include=1; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$sentinel" "$script" "$skip" "$capability" "$include" >>"$MANIFEST"
done
if ! command -v python3 >/dev/null 2>&1; then echo 'run_all: python3 is required; enter nix develop' >&2; exit 2; fi
python3 "$ROOT/tests/suite_report.py" init "$REPORT" "$MANIFEST" "$SHARD_INDEX" "$SHARD_COUNT" "$SKIP_WEB" "$SELECTED_COUNT" || exit 2
SUITE_COMPLETED=0
ACTIVE_PID=''
ACTIVE_NAME=''
ACTIVE_START=0
SUMMARY=()
FAILED=0
FAILED_COUNT=0
PASSED=0
SKIPPED=0
finish_report() {
    local code=$?
    python3 "$ROOT/tests/suite_report.py" finish "$REPORT" "$SUITE_COMPLETED" "$code" || true
}
trap finish_report EXIT
record_result() {
    python3 "$ROOT/tests/suite_report.py" result "$REPORT" "$@" || { echo 'run_all: failed to save result report' >&2; exit 2; }
}
interrupted() {
    local code="$1"
    trap - INT TERM
    if [[ -n "$ACTIVE_PID" ]]; then
        # GNU timeout owns its child process group and forwards termination.
        kill -TERM "$ACTIVE_PID" 2>/dev/null || true
        wait "$ACTIVE_PID" 2>/dev/null || true
    fi
    if [[ -n "$ACTIVE_NAME" ]]; then
        record_result "$ACTIVE_NAME" ABORTED "$code" "$((SECONDS - ACTIVE_START))" "$LOGDIR/$ACTIVE_NAME.log" 'suite interrupted' 0
    fi
    exit "$code"
}
trap 'interrupted 130' INT
trap 'interrupted 143' TERM

missing=()
for tool in "${ODIN:-odin}" rg timeout node; do
    if ! command -v "$tool" >/dev/null 2>&1; then missing+=("$tool"); fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "run_all: required tools missing: ${missing[*]}; enter nix develop" >&2; exit 2
fi
if [[ -z "${GODOT:-}" || ! -x "${GODOT:-/nonexistent}" ]]; then
    echo 'run_all: GODOT must name an executable; enter nix develop and set it on Linux' >&2; exit 2
fi
TIMEOUT_SECS="${TIMEOUT_SECS:-600}"
if [[ ! "$TIMEOUT_SECS" =~ ^[1-9][0-9]*$ ]]; then echo 'run_all: TIMEOUT_SECS must be a positive integer' >&2; exit 2; fi
TIMEOUT_BIN="$(command -v timeout)"
# Crash checks inspect SDK logs and live debugger state, not OS core files.
# Keep file-based core dumps from filling the workspace after expected signals.
# Hosts that pipe dumps to a collector also need that collector configured.
if ! ulimit -S -c 0; then
    echo 'run_all: could not disable file-based core dumps' >&2
    exit 2
fi
export ODIN_GODOT_ROOT="$ROOT"
# Cache this suite's preprocessor separately from nested test output directories.
SGEN_BIN="$LOGDIR/suite-scriptgen"
if "${ODIN:-odin}" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$SGEN_BIN" -debug >"$LOGDIR/scriptgen_build.log" 2>&1; then
    export SGEN_BIN
else
    echo "run_all: scriptgen pre-build failed; see $LOGDIR/scriptgen_build.log" >&2
    exit 2
fi

run_one() {
    local name="$1" sentinel="$2" script="$3" skip_sentinel="$4" capability="$5"
    local log="$LOGDIR/$name.log" rc=0 dt reason native=0
    if [[ "$SKIP_WEB" == 1 && ( "$capability" == browser || "$capability" == gated-browser ) ]]; then
        reason='SKIP_WEB=1; browser capability omitted'
        printf '%s\n' "$reason" >"$log"
        printf '==> %-24s SKIP (%s)\n' "$name" "$reason"
        SUMMARY+=("$name SKIP ($reason)")
        SKIPPED=$((SKIPPED + 1))
        record_result "$name" SKIP 0 0 "$log" "$reason" 0
        return
    fi
    printf '==> %-24s ' "$name"
    ACTIVE_NAME="$name"; ACTIVE_START=$SECONDS
    "$TIMEOUT_BIN" --kill-after=10 "$TIMEOUT_SECS" bash "$ROOT/$script" >"$log" 2>&1 &
    ACTIVE_PID=$!
    wait "$ACTIVE_PID" || rc=$?
    ACTIVE_PID=''; ACTIVE_NAME=''
    dt=$((SECONDS - ACTIVE_START))
    if [[ "$rc" == 0 && !( "$capability" == mixed && "$SKIP_WEB" == 1 ) ]] && grep -Fq "$sentinel" "$log"; then
        printf 'PASS (%ds)\n' "$dt"
        SUMMARY+=("$name PASS ($sentinel)")
        PASSED=$((PASSED + 1))
        if [[ "$capability" == native || "$capability" == mixed ]]; then native=1; fi
        record_result "$name" PASS "$rc" "$dt" "$log" "$sentinel" "$native"
    elif [[ "$rc" == 124 ]]; then
        printf 'TIMEOUT (>%ss)\n' "$TIMEOUT_SECS"
        SUMMARY+=("$name TIMEOUT (see $log)")
        FAILED=1
        FAILED_COUNT=$((FAILED_COUNT + 1))
        record_result "$name" TIMEOUT "$rc" "$dt" "$log" 'per-check wall-clock limit exceeded' 0
    elif [[ "$rc" == 0 && -n "$skip_sentinel" ]] && grep -Fq "$skip_sentinel" "$log" &&
         [[ "$capability" != mixed || "$SKIP_WEB" == 1 ]]; then
        reason="$skip_sentinel"
        if [[ "$capability" == mixed ]]; then reason='native checks completed; SKIP_WEB=1 omits browser checks'; native=1; fi
        printf 'SKIP (%s)\n' "$reason"
        SUMMARY+=("$name SKIP ($reason)")
        SKIPPED=$((SKIPPED + 1))
        record_result "$name" SKIP "$rc" "$dt" "$log" "$reason" "$native"
    else
        printf 'FAIL (exit %s)\n' "$rc"
        echo "    ----- last 15 lines of $log -----"
        tail -n 15 "$log" | sed 's/^/    /'
        SUMMARY+=("$name FAIL (see $log)")
        FAILED=1
        FAILED_COUNT=$((FAILED_COUNT + 1))
        record_result "$name" FAIL "$rc" "$dt" "$log" 'nonzero exit or missing completion marker' 0
    fi
}

echo "odin_godot checks: $SELECTED_COUNT/${#TESTS[@]} selected; shard $SHARD_INDEX/$SHARD_COUNT; SKIP_WEB=$SKIP_WEB"
for position in "${!TESTS[@]}"; do
    IFS='|' read -r name sentinel script skip capability <<<"${TESTS[$position]}"
    if selected "$name" "$position"; then run_one "$name" "$sentinel" "$script" "$skip" "$capability"; fi
done
echo '=========================================================='
for line in "${SUMMARY[@]}"; do echo "  $line"; done
echo "Selected $SELECTED_COUNT/${#TESTS[@]}; passed $PASSED; skipped $SKIPPED; failed $FAILED_COUNT"
echo "Results: $REPORT"
SUITE_COMPLETED=1
if [[ "$FAILED" == 0 ]]; then
    if [[ "$SELECTED_COUNT" == "${#TESTS[@]}" && "$SKIPPED" == 0 ]]; then echo 'ALL GREEN';
    else echo 'SELECTED CHECKS PASSED'; fi
    exit 0
fi
echo 'SUITE FAILED'
exit 1
