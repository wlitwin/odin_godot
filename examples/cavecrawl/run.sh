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
# THE REFERENCE HARNESS CONSUMER: the launch/ready/wait/reap/act plumbing is
# build/template/test/harness.sh — the same file a downloaded game sources
# from addons/odin_godot/template/test/harness.sh. What stays here is the
# game-shaped part: the acts and their receipts.
#
# Prints CAVECRAWL_OK. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash examples/cavecrawl/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/cavecrawl"

# A failed build MUST kill the run here — this script has no `set -e` (the
# acts lean on expected failures), and falling through would acid the STALE
# dylib and print a false CAVECRAWL_OK.
if ! bash "$ROOT/build/build_scripts.sh" "$PROJ"; then
	echo "CAVECRAWL_FAIL: script build failed"
	exit 1
fi
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

FSLP_PROJ="$PROJ"
FSLP_DRIVER="cave_test.gd"
FSLP_PORT_BASE=$(((RANDOM % 12000) + 50000))
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# THE ACID CONDITION: every packet on every peer arrives 120ms late (240ms
# round trips). Casts must still bite instantly (prediction) while confirms
# measurably ride the slow wire — that is the "never feels sloppy" proof.
LATENCY_MS=120
SAVE="$FSLP_LOGS/save.fslp"
mkdir -p "$FSLP_LOGS"

# cave_launch ROLE LOG PORT NAME TOKEN [ENV=VAL]... — the game's env spelling
# over the harness launcher.
cave_launch() {
	local role="$1" log="$2" port="$3" name="$4" token="$5"; shift 5
	ROLE="$role" fslp_launch "$role" "$log" \
		CAVE_PORT="$port" CAVE_NAME="$name" CAVE_TOKEN="$token" \
		CAVE_LATENCY="$LATENCY_MS" CAVE_SAVE="$SAVE" "$@"
}

# ---- ACT 1: the main story (phases 1-5) -------------------------------------
# Its logs and save feed act 2 (resume reads the world act 1 wrote).
HLOG="$FSLP_LOGS/host.log"
GLOG="$FSLP_LOGS/guest.log"

story() {
	local port="$1" hlog="$HLOG" glog="$GLOG"
	: >"$hlog"; : >"$glog"
	rm -f "$SAVE"

	local hp gp
	hp=$(cave_launch host "$hlog" "$port" hosty "")
	fslp_ready "$hlog" "CAVE_HOSTING" 8 "$hp" || { echo "  port $port: host never bound"; return 1; }
	gp=$(cave_launch guest "$glog" "$port" guest cave-guest-token)
	fslp_wait_all 60 "$hp" "$gp"

	expect "$hlog" "CAVE_UI_READY" "host lobby UI never built"
	# kit/steamgd rides in every build BY NAME: with no GodotSteam installed
	# it must answer "off" and leave the ENet path untouched (this grep is
	# the headless half of the Steam story; the live half needs Steam).
	expect "$hlog" "CAVE_STEAM off" "steamgd absence not graceful"
	expect "$hlog" "CAVE_HOSTING" "host never hosted"
	expect "$hlog" "CAVE_PLAYERS n=2" "host never saw 2 spelunkers"
	expect "$glog" "CAVE_SEATED me=" "guest was never seated"
	# The REAL UI, on both peers: both names, and the local you-marker.
	expect "$hlog" "CAVE_UI \[.*hosty.*\]" "host UI missing its own name"
	expect "$hlog" "CAVE_UI \[.*guest.*\]" "host UI missing the guest"
	expect "$hlog" "CAVE_UI \[.*hosty +\(you\).*\]" "host UI missing its you-marker"
	expect "$glog" "CAVE_UI \[.*hosty.*\]" "guest UI missing the host"
	expect "$glog" "CAVE_UI \[.*guest +\(you\).*\]" "guest UI missing its you-marker"
	# Host gets a visible Start once the cave has company; the guest never does.
	expect "$hlog" "CAVE_START_VISIBLE n=1" "host Start button not shown"
	expect "$glog" "CAVE_START_VISIBLE n=0" "guest must not see a Start button"
	# Phase 2 — chat: each peer's line lands on BOTH real UIs, host order,
	# plus the host-authored system line about the guest joining.
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_CHAT \[.*hosty: found a torch.*\]" "host line missing in $(basename "$log")"
		expect "$log" "CAVE_CHAT \[.*guest: on my way.*\]" "guest line missing in $(basename "$log")"
		expect "$log" "CAVE_CHAT \[.*\* guest joined the cave.*\]" "join system line missing in $(basename "$log")"
		# The guest's marker surfaces as a comms event on both peers.
		expect "$log" "CAVE_MARK player=2 kind=1" "marker missing in $(basename "$log")"
	done
	# Phase 3 — the cave. Both peers materialize the world and reach the chest
	# on their own legs (the prompt only shows inside the shared range gate).
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_WORLD_READY gems=3" "world missing in $(basename "$log")"
		expect "$log" "CAVE_AT_CHEST" "never reached the chest in $(basename "$log")"
		expect "$log" "CAVE_CHEST_EMPTY" "chest never emptied in $(basename "$log")"
		expect "$log" "CAVE_DOOR_OPEN" "door never opened in $(basename "$log")"
		# Conservation: exactly the 3 gems that ever existed, on every peer.
		expect "$log" "CAVE_GEMS total=3" "gems not conserved in $(basename "$log")"
	done
	# The guest's loot was PREDICTED (applied locally) then host-confirmed...
	expect "$glog" "CAVE_LOOT applied=true" "guest loot not predicted"
	expect "$glog" "CAVE_CONFIRM" "guest loot never confirmed"
	expect "$glog" "CAVE_GEMS_LOOTED mine=3" "gems never reached the guest's bag"
	# ...the host looted through the authority path, and a second grab said no.
	expect "$hlog" "CAVE_LOOT applied=true" "host loot failed"
	expect "$hlog" "CAVE_CHEST_EMPTY torches=2" "torches never reached the host's bag"
	expect "$glog" "CAVE_LOOT_DENIED" "empty-chest grab was not denied"
	# The door toggle over the wire, and drops/pickups: the guest spills its
	# gems, the pickup materializes on BOTH peers, the host scoops it up
	# (authority path) and shows the loot in ITS real inventory UI.
	expect "$glog" "CAVE_TOGGLE applied=true" "guest door toggle failed"
	expect "$glog" "CAVE_DROP applied=true" "guest drop not predicted"
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_PICKUP n=1 gems=3" "pickup missing in $(basename "$log")"
		expect "$log" "CAVE_GRABBED" "grab never settled in $(basename "$log")"
	done
	expect "$hlog" "CAVE_GRAB applied=true" "host grab failed"
	expect "$hlog" "CAVE_GRABBED my_gems=3" "gems never reached the host's bag"
	expect "$hlog" "CAVE_LOADOUT \[.*gem x3.*\]" "host inventory UI missing the grabbed gems"
	expect "$hlog" "CAVE_LOADOUT \[.*torch x2.*\]" "host inventory UI missing torches"
	# Phase 4 — combat under ${LATENCY_MS}ms injected latency. The cast BITES
	# INSTANTLY (stamina spent in the same print) while its confirm takes a
	# real round trip: prediction beat the wire, and only the host dealt
	# damage. One rock = one hit on both screens; three = a death, a spilled
	# bag, a respawn, and a truthful scoreboard.
	expect "$glog" "CAVE_THROW predicted=true stamina=7 cd=20" "cast not predicted instantly"
	expect "$glog" "CAVE_CONFIRM dt_ms=(19[0-9]|[2-9][0-9]{2}|[0-9]{4,})" "confirm arrived impossibly fast (latency not proven)"
	# PEER-OWNED VISUALS: the shooter's own rock visually connects and the
	# displayed hp dips to 65 WHILE the replicated truth still reads 100 —
	# the impact you saw, a round trip before the wire agrees. The victim's
	# screen plays the same impact from the host's fire announcement.
	# THE MOVING CAST: the guest's opening shot is thrown MID-STRIDE. The
	# cast carries its owner-true origin, so the host's authoritative rock
	# flies the shooter's line — without that, the host launches from its
	# ~30px-stale copy and the shot the guest watched connect misses.
	expect "$glog" "CAVE_STRAFE_THROW" "the guest never threw on the move"
	expect "$glog" "CAVE_IMPACT mine=true view=65 truth=100" "shooter's impact not predicted ahead of truth"
	expect "$hlog" "CAVE_IMPACT mine=false" "victim's screen never played the impact"
	# JUICE: every impact spawns a particle burst + a tween hit-flash from
	# code (fx.odin) — both peers must have played them.
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_FX burst" "no particle burst in $(basename "$log")"
		expect "$log" "CAVE_FX flash" "no hit-flash tween in $(basename "$log")"
	done
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_ARMED" "never armed in $(basename "$log")"
		expect "$log" "CAVE_HIT hp=65" "the rock never landed in $(basename "$log")"
		expect "$log" "CAVE_SPILLED pickups=[2-9] gems=3" "death never spilled the bag in $(basename "$log")"
		expect "$log" "CAVE_BACK" "the host never rose in $(basename "$log")"
		expect "$log" "CAVE_GEMS total=3" "gems not conserved in $(basename "$log")"
	done
	expect "$hlog" "CAVE_DIED" "the host never died"
	expect "$hlog" "CAVE_RESPAWNED" "the host never walked out of the grave"
	# The REAL scoreboard on both peers: guest 105 damage / 1 kill / 0 deaths,
	# host 0 damage / 0 kills / 1 death (plus a live ping column).
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_SCORE \[.*guest \| [0-9]+ \| 105 \| 1 \| 0.*\]" "guest ledger row wrong in $(basename "$log")"
		expect "$log" "CAVE_SCORE \[.*hosty \| [0-9]+ \| 0 \| 0 \| 1.*\]" "host ledger row wrong in $(basename "$log")"
	done
	# The host's HUD after resurrection: a full bar in the real UI tree
	# (read at the scoreboard beat — the phase-5 hunt scars it again later).
	expect "$hlog" "CAVE_SCORE \[.*100/100.*\]" "host HUD not full after respawn"
	# Phase 5 — cave dwellers. The kit/ai director paces the waves; brains
	# think on the host only, yet the guest watches the whole hunt through
	# replication: the mood byte flips to chase, the pursuit MOVES on its
	# screen (owner-streamed interp), the bite lands, rocks clear the wave
	# (torch drops on the floor), and the breather ends in wave 2.
	expect "$hlog" "CAVE_WAVE n=1" "wave 1 never announced"
	expect "$hlog" "CAVE_WAVE n=2" "wave 2 never announced"
	expect "$hlog" "CAVE_SLAIN left=[0-9]" "no dweller ever fell"
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_DWELLERS n=[1-9]" "dwellers missing in $(basename "$log")"
		expect "$log" "CAVE_CHASE_SEEN" "chase never seen in $(basename "$log")"
		expect "$log" "CAVE_BITTEN" "the bite never landed in $(basename "$log")"
		expect "$log" "CAVE_WAVE_CLEARED" "wave 1 never cleared in $(basename "$log")"
		expect "$log" "CAVE_WAVE2 n=[1-9]" "wave 2 never rose in $(basename "$log")"
	done
	# The guest's view of the pursuit crossed real distance (interp motion).
	expect "$glog" "CAVE_DWELLER_MOVED d=([1-9][0-9]|[0-9]{3,})" "the pursuit never moved on the guest's screen"
	# THE BANDAGE (ability slot 1): the bitten host heals through the same
	# predicted gate as the rock; the guest watches the hp climb back.
	expect "$hlog" "CAVE_HEAL applied=true" "the host never bandaged"
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_MENDED" "the heal never showed in $(basename "$log")"
	done
	# LEVEL MIGRATION: the cleared party at the open door moves the run down
	# a floor — old floor despawned, new def spawned, bags carried through,
	# each owner stepping to the new floor's mouth on the replicated edge.
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_CLEARED_FLOOR" "wave 2 never fell in $(basename "$log")"
	done
	expect "$hlog" "CAVE_DESCEND depth=2" "the host never descended the run"
	# SHARED-SEED PROCGEN: both processes grew the same decoration from the
	# replicated seed — the checksums must MATCH ACROSS PROCESSES, per floor
	# (integer-math scatter; zero wire bytes for the world it implies).
	for d in 1 2; do
		expect_same "$hlog" "$glog" "CAVE_SCATTER depth=$d sum=[0-9]+" "floor $d procgen diverged"
	done
	# ENTITY BLOBS: the host carves a variable-length inscription per floor
	# (session_set_blob on the level); the change ships reliably and every
	# peer prints the SAME text off Ev_Blob_Changed. The wire codecs ride
	# silently underneath this whole act: spelunker/relic x,y cross as half
	# floats and hp as one byte — every movement/combat assert above already
	# proved they decode.
	for d in 1 2; do
		expect_same "$hlog" "$glog" "CAVE_INSCRIPTION the walls of floor $d remember seed [0-9]+" "floor $d inscription diverged"
	done
	for log in "$hlog" "$glog"; do
		expect "$log" "CAVE_FLOOR depth=2" "owner never stepped to floor 2 in $(basename "$log")"
		expect "$log" "CAVE_DESCENDED depth=2 door=false dwellers=[0-9] chest=6" "floor 2 wrong in $(basename "$log")"
	done
	expect "$glog" "CAVE_DESCENDED depth=2 door=false dwellers=[0-9] chest=6 gems_bag=3" "the guest's bag did not cross the stairs"
	# DISCONNECT DETECTION: the guest exits without a goodbye; the host must
	# see the roster shrink through the transport signal (an unwired signal
	# means ghosts haunt rosters forever — every game's first playtest bug).
	expect "$hlog" "CAVE_ALONE players=1" "host never noticed the guest leave"
	expect "$hlog" "HOST_DONE" "host did not finish"
	expect "$glog" "GUEST_DONE" "guest did not finish"

	if ((!FSLP_OK)); then
		echo "  --- host log tail ---"; tail -n 15 "$hlog" | sed 's/^/    /'
		echo "  --- guest log tail ---"; tail -n 15 "$glog" | sed 's/^/    /'
		return 1
	fi
}

# ---- ACT 2 (phase 6): both processes are DEAD. Resume the run from the save
# file in fresh ones — the host under its saved identity, the guest reclaiming
# hers by token — and keep playing it.
resume_act() {
	local port="$1"
	local h2log="$FSLP_LOGS/resume.log" g2log="$FSLP_LOGS/rejoin.log"
	: >"$h2log"; : >"$g2log"
	[ -f "$SAVE" ] || { echo "  FAIL: no save file was written"; return 1; }

	local h2 g2
	h2=$(cave_launch resume "$h2log" "$port" hosty "")
	fslp_ready "$h2log" "CAVE_RESUMED" 12 "$h2" || true
	g2=$(cave_launch rejoin "$g2log" "$port" guest cave-guest-token)
	fslp_wait_all 40 "$h2" "$g2"

	expect "$HLOG" "CAVE_SAVED ok=true" "the run was never saved"
	# The whole world back from disk, under the identity that saved it.
	expect "$h2log" "CAVE_RESUMED me=1 players=2 entities=[0-9]+ reg=[0-9]+ dwellers=3 gems=3 door=true" "the resumed world is wrong"
	# #24 STATE HASH: the LIVE replicated state survived the save byte-identical —
	# the host's fingerprint AT SAVE TIME and the resumer's fingerprint right after
	# restore (both before any further sim) are the same number. This is the entity
	# delta lane (dweller hp/mood, spelunker hp/bag/cooldowns/effects, chest slots),
	# which the seed checksums never covered; a mismatch is a dropped or misread
	# field in the snapshot.
	expect_same "$HLOG" "$h2log" "CAVE_STATE_HASH h=[0-9]+" "the replicated state hash did not survive save/resume (#24)"
	# The GAME BLOB restored the campaign: wave 2 in progress, and the
	# director must NOT restart wave 1 on top of the saved dwellers.
	expect "$h2log" "CAVE_BLOB wave=2" "the game blob did not restore"
	expect_absent "$h2log" "CAVE_WAVE n=1" "the director restarted the campaign"
	# The guest's persisted token reclaims her identity across process death.
	expect "$g2log" "CAVE_SEATED me=2" "rejoiner did not reclaim her id"
	expect "$g2log" "CAVE_REJOINED dwellers=3 gems=3 door=true" "the rejoined world is wrong"
	# JOIN CARRY: the inscription was set BEFORE she rejoined and survived a
	# SAVE + RESUME in between (the save is taken on floor 1, pre-descent) —
	# the resumed host must hold it, and it must reach her with the world
	# snapshot, byte-identical, with zero catch-up code anywhere in the game.
	expect_same "$h2log" "$g2log" "CAVE_INSCRIPTION the walls of floor 1 remember seed [0-9]+" "the inscription did not survive save/resume"
	# ...and the resumed run is PLAYABLE: she avenges herself on a dweller.
	expect "$g2log" "CAVE_RESUME_SLAIN dwellers=[0-2]" "the resumed run was not playable"
	# The scoreboard remembers her kill from the previous life.
	expect "$h2log" "CAVE_RESUME_SCORE \[.*guest \| [0-9]+ \| [0-9]+ \| 1 \| 0.*\]" "the ledger forgot"
	expect "$h2log" "RESUME_DONE" "resume host did not finish"
	expect "$g2log" "REJOIN_DONE" "rejoiner did not finish"

	if ((!FSLP_OK)); then
		echo "  --- resume log tail ---"; tail -n 15 "$h2log" | sed 's/^/    /'
		echo "  --- rejoin log tail ---"; tail -n 15 "$g2log" | sed 's/^/    /'
		return 1
	fi
}

# ---- ACT 3: MATCH FLOW + MODERATION. One floor deep (CAVE_FLOORS=1):
# clearing it WINS the run on every screen; Start on the end screen runs it
# back in the SAME session; then the host kicks the guest WITH A BAN and the
# same token bounces off the door.
endgame() {
	local port="$1"
	local h3log="$FSLP_LOGS/endhost.log" g3log="$FSLP_LOGS/endguest.log" g4log="$FSLP_LOGS/endguest2.log"
	: >"$h3log"; : >"$g3log"; : >"$g4log"

	local h3 g3 g4
	h3=$(cave_launch endhost "$h3log" "$port" hosty "" CAVE_FLOORS=1)
	fslp_ready "$h3log" "CAVE_HOSTING" 8 "$h3" || { echo "  port $port: endhost never bound"; return 1; }
	g3=$(cave_launch endguest "$g3log" "$port" guest cave-end-token)
	fslp_wait_all 90 "$g3"
	g4=$(cave_launch endguest2 "$g4log" "$port" guest cave-end-token)
	fslp_wait_all 20 "$g4"
	fslp_reap

	# OWNERSHIP TRANSFER: the relic changes hands guest -> rests -> host, and
	# the HOST'S screen watched it ride the guest (owner-streamed motion).
	for log in "$h3log" "$g3log"; do
		expect "$log" "CAVE_RELIC owner=2" "guest never carried the relic in $(basename "$log")"
		expect "$log" "CAVE_RELIC owner=0" "the relic never rested in $(basename "$log")"
		expect "$log" "CAVE_RELIC owner=1" "host never carried the relic in $(basename "$log")"
	done
	expect "$h3log" "CAVE_RELIC_MOVED d=([6-9][0-9]|[0-9]{3,})" "the carried relic never moved on the host's screen"

	# DOWNED / REVIVE: the guest downs the host on purpose and raises them
	# IN PLACE at REVIVE_HP before the bleed-out clock — CAVE_REVIVED is the
	# in-place path; a bleed-out would print CAVE_RESPAWNED and fail this.
	expect "$h3log" "CAVE_DIED" "the host never went down"
	expect "$h3log" "CAVE_REVIVED" "the host was never revived in place"
	expect "$g3log" "CAVE_REVIVE applied=true" "the guest's revive never applied"
	# No exact-hp assert here: the raised host is bitten/heals between
	# samples (the mend-phase lesson). CAVE_REVIVED above already pins the
	# in-place-below-max path; this just proves the guest SAW them rise.
	expect "$g3log" "CAVE_RAISED (their_hp|my_hp)=[0-9]+" "the guest never saw the host rise"

	# THE WIN and the RESTART: one replicated byte each way, every screen.
	for log in "$h3log" "$g3log"; do
		expect "$log" "CAVE_WON depth=1" "never conquered in $(basename "$log")"
		expect "$log" "CAVE_END_UI \[.*conquered.*\]" "no end screen in $(basename "$log")"
		expect "$log" "CAVE_RESTARTED" "end screen never cleared in $(basename "$log")"
		expect "$log" "CAVE_REBORN chest=5 hp=100 players=2" "the second run is wrong in $(basename "$log")"
	done
	expect "$h3log" "CAVE_RESTART" "the host never ran it back"
	# THE KICK: deliberate, explained, enforced at the door.
	expect "$h3log" "CAVE_KICKED player=2" "the kick never happened"
	expect "$h3log" "CAVE_KICK_ROSTER n=1" "the roster kept the kicked guest"
	expect "$g3log" "CAVE_KICKED_ME" "the guest was never told"
	expect "$g3log" "ENDGUEST_DONE" "end guest did not finish"
	expect "$g4log" "CAVE_DENIED reason=Banned" "the ban did not hold"
	expect "$g4log" "ENDGUEST2_DONE" "banned guest did not finish"

	if ((!FSLP_OK)); then
		echo "  --- endhost log tail ---"; tail -n 15 "$h3log" | sed 's/^/    /'
		echo "  --- endguest log tail ---"; tail -n 15 "$g3log" | sed 's/^/    /'
		echo "  --- endguest2 log tail ---"; tail -n 15 "$g4log" | sed 's/^/    /'
		return 1
	fi
}

# ---- ACT 4: HOST MIGRATION. Three players; the host dies with kill -9 (no
# goodbye, no socket close); the backup holder resumes the run as the new
# host on the SAME port; the third player rejoins and reclaims their
# identity — the whole stepping stone, end to end.
migration() {
	local port="$1"
	local h4log="$FSLP_LOGS/mhost.log" g5log="$FSLP_LOGS/mguest.log" g6log="$FSLP_LOGS/mguest2.log"
	: >"$h4log"; : >"$g5log"; : >"$g6log"

	local h4 g5 g6
	h4=$(cave_launch mhost "$h4log" "$port" hosty "")
	fslp_ready "$h4log" "CAVE_HOSTING" 8 "$h4" || { echo "  port $port: mhost never bound"; return 1; }
	g5=$(cave_launch mguest "$g5log" "$port" guest cave-m-a)
	g6=$(cave_launch mguest2 "$g6log" "$port" walker cave-m-b)
	local w5=0
	while ((w5 < 400)); do
		grep -q "CAVE_BACKUP_HELD" "$g5log" "$g6log" 2>/dev/null && break
		sleep 0.1; ((w5++))
	done
	kill -9 "$h4" 2>/dev/null # no goodbye, no FIN — the real crash shape IS the test
	fslp_wait_all 90 "$g5" "$g6"

	# The two guests' JOINs race over the shim, so which process is player 2
	# is not ours to assume — the story is asserted across BOTH logs: exactly
	# one bearer (named ahead of need, hears the succession, takes over, gets
	# rejoined), exactly one chaser (chases, reclaims itself, sees the world).
	grep -q "CAVE_BACKUP size=" "$g5log" "$g6log" || { echo "  FAIL: the backup never shipped"; FSLP_OK=0; }
	expect "$h4log" "CAVE_TORCH_NAMED player=2 addr=" "the successor was never named"
	local mine; mine=$(cat "$g5log" "$g6log" | grep -c "CAVE_TORCH_MINE")
	((mine == 1)) || { echo "  FAIL: torch bearers heard: $mine (want exactly 1)"; FSLP_OK=0; }
	grep -qE "CAVE_TAKEOVER me=[0-9]+ players=3 entities=[0-9]+ dwellers=[0-9]+" "$g5log" "$g6log" || { echo "  FAIL: the takeover failed"; FSLP_OK=0; }
	grep -q "CAVE_TORCH_SHARED players=2" "$g5log" "$g6log" || { echo "  FAIL: nobody rejoined the new host"; FSLP_OK=0; }
	grep -qE "CAVE_CHASE_TORCH try=[0-9]+" "$g5log" "$g6log" || { echo "  FAIL: nobody chased the torch"; FSLP_OK=0; }
	grep -q "CAVE_REJOINING" "$g5log" "$g6log" || { echo "  FAIL: the chaser never rejoined"; FSLP_OK=0; }
	grep -qE "CAVE_RETURNED players=[2-3] dwellers=[0-9]+" "$g5log" "$g6log" || { echo "  FAIL: the chaser's world is wrong"; FSLP_OK=0; }
	expect "$g5log" "MGUEST_DONE" "mguest did not finish"
	expect "$g6log" "MGUEST2_DONE" "mguest2 did not finish"

	if ((!FSLP_OK)); then
		echo "  --- mhost log tail ---"; tail -n 12 "$h4log" | sed 's/^/    /'
		echo "  --- mguest log tail ---"; tail -n 12 "$g5log" | sed 's/^/    /'
		echo "  --- mguest2 log tail ---"; tail -n 12 "$g6log" | sed 's/^/    /'
		return 1
	fi
}

fslp_act "the story" 5 story && fslp_act "resume + rejoin" 3 resume_act
fslp_act "match flow + moderation" 3 endgame
fslp_act "host migration" 3 migration

if fslp_verdict CAVECRAWL; then
	echo "  --- host ---"; grep -E "CAVE_" "$HLOG" | sed 's/^/    /'
	echo "  --- guest ---"; grep -E "CAVE_" "$GLOG" | sed 's/^/    /'
	exit 0
fi
exit 1
