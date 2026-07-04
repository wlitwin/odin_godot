#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# CAVECRAWL (phases 1+2+3): lobby -> chat -> THE CAVE, two headless processes
# over real ENet driving the real cave.tscn. Phase 3: Start spawns a world
# (spelunker per player, stocked chest, door), both peers WALK there (owner-
# streamed motion swinging the interact prompt's range gate), the guest loots
# the gems (predicted; the host's command hook credits the bag), the host
# loots the torches (authority path), a second grab is denied, the door
# opens on both screens, gems are conserved, and the inventory grid shows
# the loot in the real UI tree.
#
# Prints CAVECRAWL_OK. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash examples/cavecrawl/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/cavecrawl"
LOGDIR="$PROJ/.runlogs"
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# THE ACID CONDITION: every packet on every peer arrives 120ms late (240ms
# round trips). Casts must still bite instantly (prediction) while confirms
# measurably ride the slow wire — that is the "never feels sloppy" proof.
LATENCY_MS=120

launch() {
	local role="$1" log="$2" port="$3" name="$4" token="$5"
	ROLE="$role" CAVE_PORT="$port" CAVE_NAME="$name" CAVE_TOKEN="$token" \
		CAVE_LATENCY="$LATENCY_MS" \
		"$GODOT" --headless --path "$PROJ" --script cave_test.gd \
		>"$log" 2>&1 &
	echo $!
}

attempt() {
	local port="$1"
	local hlog="$LOGDIR/host.log" glog="$LOGDIR/guest.log"
	: >"$hlog"; : >"$glog"

	local hp; hp=$(launch host "$hlog" "$port" hosty "")
	local i=0
	while ((i < 50)); do
		grep -q "CAVE_HOSTING" "$hlog" && break
		if grep -q "CAVE_HOST_FAIL" "$hlog"; then
			kill "$hp" 2>/dev/null; wait "$hp" 2>/dev/null
			echo "  port $port: host failed to bind, retrying"
			return 2
		fi
		if ! kill -0 "$hp" 2>/dev/null; then break; fi
		sleep 0.1; ((i++))
	done

	local gp; gp=$(launch guest "$glog" "$port" guest cave-guest-token)
	local waited=0
	while ((waited < 300)); do
		if ! kill -0 "$hp" 2>/dev/null && ! kill -0 "$gp" 2>/dev/null; then break; fi
		sleep 0.1; ((waited++))
	done
	kill "$hp" "$gp" 2>/dev/null

	local ok=1
	grep -q "CAVE_UI_READY" "$hlog" || { echo "  FAIL: host lobby UI never built"; ok=0; }
	grep -q "CAVE_HOSTING" "$hlog" || { echo "  FAIL: host never hosted"; ok=0; }
	grep -q "CAVE_PLAYERS n=2" "$hlog" || { echo "  FAIL: host never saw 2 spelunkers"; ok=0; }
	grep -q "CAVE_SEATED me=" "$glog" || { echo "  FAIL: guest was never seated"; ok=0; }
	# The REAL UI, on both peers: both names, and the local you-marker.
	grep -qE "CAVE_UI \[.*hosty.*\]" "$hlog" || { echo "  FAIL: host UI missing its own name"; ok=0; }
	grep -qE "CAVE_UI \[.*guest.*\]" "$hlog" || { echo "  FAIL: host UI missing the guest"; ok=0; }
	grep -qE "CAVE_UI \[.*hosty +\(you\).*\]" "$hlog" || { echo "  FAIL: host UI missing its you-marker"; ok=0; }
	grep -qE "CAVE_UI \[.*hosty.*\]" "$glog" || { echo "  FAIL: guest UI missing the host"; ok=0; }
	grep -qE "CAVE_UI \[.*guest +\(you\).*\]" "$glog" || { echo "  FAIL: guest UI missing its you-marker"; ok=0; }
	# Host gets a visible Start once the cave has company; the guest never does.
	grep -q "CAVE_START_VISIBLE n=1" "$hlog" || { echo "  FAIL: host Start button not shown"; ok=0; }
	grep -q "CAVE_START_VISIBLE n=0" "$glog" || { echo "  FAIL: guest must not see a Start button"; ok=0; }
	# Phase 2 — chat: each peer's line lands on BOTH real UIs, host order,
	# plus the host-authored system line about the guest joining.
	for log in "$hlog" "$glog"; do
		grep -qE "CAVE_CHAT \[.*hosty: found a torch.*\]" "$log" || { echo "  FAIL: host line missing in $(basename "$log")"; ok=0; }
		grep -qE "CAVE_CHAT \[.*guest: on my way.*\]" "$log" || { echo "  FAIL: guest line missing in $(basename "$log")"; ok=0; }
		grep -qE "CAVE_CHAT \[.*\* guest joined the cave.*\]" "$log" || { echo "  FAIL: join system line missing in $(basename "$log")"; ok=0; }
		# The guest's marker surfaces as a comms event on both peers.
		grep -q "CAVE_MARK player=2 kind=1" "$log" || { echo "  FAIL: marker missing in $(basename "$log")"; ok=0; }
	done
	# Phase 3 — the cave. Both peers materialize the world and reach the chest
	# on their own legs (the prompt only shows inside the shared range gate).
	for log in "$hlog" "$glog"; do
		grep -q "CAVE_WORLD_READY gems=3" "$log" || { echo "  FAIL: world missing in $(basename "$log")"; ok=0; }
		grep -q "CAVE_AT_CHEST" "$log" || { echo "  FAIL: never reached the chest in $(basename "$log")"; ok=0; }
		grep -q "CAVE_CHEST_EMPTY" "$log" || { echo "  FAIL: chest never emptied in $(basename "$log")"; ok=0; }
		grep -q "CAVE_DOOR_OPEN" "$log" || { echo "  FAIL: door never opened in $(basename "$log")"; ok=0; }
		# Conservation: exactly the 3 gems that ever existed, on every peer.
		grep -q "CAVE_GEMS total=3" "$log" || { echo "  FAIL: gems not conserved in $(basename "$log")"; ok=0; }
	done
	# The guest's loot was PREDICTED (applied locally) then host-confirmed...
	grep -q "CAVE_LOOT applied=true" "$glog" || { echo "  FAIL: guest loot not predicted"; ok=0; }
	grep -q "CAVE_CONFIRM" "$glog" || { echo "  FAIL: guest loot never confirmed"; ok=0; }
	grep -q "CAVE_GEMS_LOOTED mine=3" "$glog" || { echo "  FAIL: gems never reached the guest's bag"; ok=0; }
	# ...the host looted through the authority path, and a second grab said no.
	grep -q "CAVE_LOOT applied=true" "$hlog" || { echo "  FAIL: host loot failed"; ok=0; }
	grep -q "CAVE_CHEST_EMPTY torches=2" "$hlog" || { echo "  FAIL: torches never reached the host's bag"; ok=0; }
	grep -q "CAVE_LOOT_DENIED" "$glog" || { echo "  FAIL: empty-chest grab was not denied"; ok=0; }
	# The door toggle over the wire, and drops/pickups: the guest spills its
	# gems, the pickup materializes on BOTH peers, the host scoops it up
	# (authority path) and shows the loot in ITS real inventory UI.
	grep -q "CAVE_TOGGLE applied=true" "$glog" || { echo "  FAIL: guest door toggle failed"; ok=0; }
	grep -q "CAVE_DROP applied=true" "$glog" || { echo "  FAIL: guest drop not predicted"; ok=0; }
	for log in "$hlog" "$glog"; do
		grep -q "CAVE_PICKUP n=1 gems=3" "$log" || { echo "  FAIL: pickup missing in $(basename "$log")"; ok=0; }
		grep -q "CAVE_GRABBED" "$log" || { echo "  FAIL: grab never settled in $(basename "$log")"; ok=0; }
	done
	grep -q "CAVE_GRAB applied=true" "$hlog" || { echo "  FAIL: host grab failed"; ok=0; }
	grep -q "CAVE_GRABBED my_gems=3" "$hlog" || { echo "  FAIL: gems never reached the host's bag"; ok=0; }
	grep -qE "CAVE_LOADOUT \[.*gem x3.*\]" "$hlog" || { echo "  FAIL: host inventory UI missing the grabbed gems"; ok=0; }
	grep -qE "CAVE_LOADOUT \[.*torch x2.*\]" "$hlog" || { echo "  FAIL: host inventory UI missing torches"; ok=0; }
	# Phase 4 — combat under ${LATENCY_MS}ms injected latency. The cast BITES
	# INSTANTLY (stamina spent in the same print) while its confirm takes a
	# real round trip: prediction beat the wire, and only the host dealt
	# damage. One rock = one hit on both screens; three = a death, a spilled
	# bag, a respawn, and a truthful scoreboard.
	grep -q "CAVE_THROW predicted=true stamina=7 cd=20" "$glog" || { echo "  FAIL: cast not predicted instantly"; ok=0; }
	grep -qE "CAVE_CONFIRM dt_ms=(19[0-9]|[2-9][0-9]{2}|[0-9]{4,})" "$glog" || { echo "  FAIL: confirm arrived impossibly fast (latency not proven)"; ok=0; }
	# PEER-OWNED VISUALS: the shooter's own rock visually connects and the
	# displayed hp dips to 65 WHILE the replicated truth still reads 100 —
	# the impact you saw, a round trip before the wire agrees. The victim's
	# screen plays the same impact from the host's fire announcement.
	grep -q "CAVE_IMPACT mine=true view=65 truth=100" "$glog" || { echo "  FAIL: shooter's impact not predicted ahead of truth"; ok=0; }
	grep -q "CAVE_IMPACT mine=false" "$hlog" || { echo "  FAIL: victim's screen never played the impact"; ok=0; }
	for log in "$hlog" "$glog"; do
		grep -q "CAVE_ARMED" "$log" || { echo "  FAIL: never armed in $(basename "$log")"; ok=0; }
		grep -q "CAVE_HIT hp=65" "$log" || { echo "  FAIL: the rock never landed in $(basename "$log")"; ok=0; }
		grep -qE "CAVE_SPILLED pickups=[2-9] gems=3" "$log" || { echo "  FAIL: death never spilled the bag in $(basename "$log")"; ok=0; }
		grep -q "CAVE_BACK" "$log" || { echo "  FAIL: the host never rose in $(basename "$log")"; ok=0; }
		grep -q "CAVE_GEMS total=3" "$log" || { echo "  FAIL: gems not conserved in $(basename "$log")"; ok=0; }
	done
	grep -q "CAVE_DIED" "$hlog" || { echo "  FAIL: the host never died"; ok=0; }
	grep -q "CAVE_RESPAWNED" "$hlog" || { echo "  FAIL: the host never walked out of the grave"; ok=0; }
	# The REAL scoreboard on both peers: guest 105 damage / 1 kill / 0 deaths,
	# host 0 damage / 0 kills / 1 death (plus a live ping column).
	for log in "$hlog" "$glog"; do
		grep -qE "CAVE_SCORE \[.*guest \| [0-9]+ \| 105 \| 1 \| 0.*\]" "$log" || { echo "  FAIL: guest ledger row wrong in $(basename "$log")"; ok=0; }
		grep -qE "CAVE_SCORE \[.*hosty \| [0-9]+ \| 0 \| 0 \| 1.*\]" "$log" || { echo "  FAIL: host ledger row wrong in $(basename "$log")"; ok=0; }
	done
	# The host's HUD after resurrection: a full bar in the real UI tree
	# (read at the scoreboard beat — the phase-5 hunt scars it again later).
	grep -qE "CAVE_SCORE \[.*100/100.*\]" "$hlog" || { echo "  FAIL: host HUD not full after respawn"; ok=0; }
	# Phase 5 — cave dwellers. The kit/ai director paces the waves; brains
	# think on the host only, yet the guest watches the whole hunt through
	# replication: the mood byte flips to chase, the pursuit MOVES on its
	# screen (owner-streamed interp), the bite lands, rocks clear the wave
	# (torch drops on the floor), and the breather ends in wave 2.
	grep -q "CAVE_WAVE n=1" "$hlog" || { echo "  FAIL: wave 1 never announced"; ok=0; }
	grep -q "CAVE_WAVE n=2" "$hlog" || { echo "  FAIL: wave 2 never announced"; ok=0; }
	grep -qE "CAVE_SLAIN left=[0-9]" "$hlog" || { echo "  FAIL: no dweller ever fell"; ok=0; }
	for log in "$hlog" "$glog"; do
		grep -qE "CAVE_DWELLERS n=[1-9]" "$log" || { echo "  FAIL: dwellers missing in $(basename "$log")"; ok=0; }
		grep -q "CAVE_CHASE_SEEN" "$log" || { echo "  FAIL: chase never seen in $(basename "$log")"; ok=0; }
		grep -q "CAVE_BITTEN" "$log" || { echo "  FAIL: the bite never landed in $(basename "$log")"; ok=0; }
		grep -q "CAVE_WAVE_CLEARED" "$log" || { echo "  FAIL: wave 1 never cleared in $(basename "$log")"; ok=0; }
		grep -qE "CAVE_WAVE2 n=[1-9]" "$log" || { echo "  FAIL: wave 2 never rose in $(basename "$log")"; ok=0; }
	done
	# The guest's view of the pursuit crossed real distance (interp motion).
	grep -qE "CAVE_DWELLER_MOVED d=([1-9][0-9]|[0-9]{3,})" "$glog" || { echo "  FAIL: the pursuit never moved on the guest's screen"; ok=0; }
	grep -q "HOST_DONE" "$hlog" || { echo "  FAIL: host did not finish"; ok=0; }
	grep -q "GUEST_DONE" "$glog" || { echo "  FAIL: guest did not finish"; ok=0; }

	if ((ok == 1)); then
		echo "  PASS on port $port"
		echo "  --- host ---"; grep -E "CAVE_" "$hlog" | sed 's/^/    /'
		echo "  --- guest ---"; grep -E "CAVE_" "$glog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- host log tail ---"; tail -n 15 "$hlog" | sed 's/^/    /'
	echo "  --- guest log tail ---"; tail -n 15 "$glog" | sed 's/^/    /'
	return 1
}

rc=1
for try in 1 2 3 4 5; do
	PORT=$(((RANDOM % 12000) + 50000))
	echo "==> attempt $try on port $PORT"
	attempt "$PORT"; rc=$?
	if ((rc == 0)); then break; fi
	if ((rc == 2)); then continue; fi
done

if ((rc == 0)); then
	echo "CAVECRAWL_OK"
	exit 0
else
	echo "CAVECRAWL_FAIL"
	exit 1
fi
