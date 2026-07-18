#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# The friendslop acid-test harness — source this from your game's run.sh.
#
# The pattern (three shipped games grew it independently, so it's yours free):
# launch N headless processes under injected latency, drive them with a
# GDScript SceneTree script (see driver.gd next door) that presses the same
# code paths the UI fires and PRINTS what it sees, then assert over the LOGS.
# Verdicts come from log greps, never process exit codes — the launch
# subshell owns the pids, so `wait` isn't yours to call.
#
#   source addons/odin_godot/template/test/harness.sh   # (in this repo:
#                                                       #  build/template/test/harness.sh)
#   fslp_build                                # scripts through the addon + --import
#
#   duel() {                                  # one ACT: a self-contained scenario
#       local port="$1" hlog="$FSLP_LOGS/h.log" glog="$FSLP_LOGS/g.log"
#       local hp gp
#       hp=$(fslp_launch host  "$hlog" MYGAME_PORT="$port" ROLE=host)
#       fslp_ready "$hlog" "HOSTING" 15 "$hp" || return 1   # bind receipt, or retry
#       gp=$(fslp_launch guest "$glog" MYGAME_PORT="$port" ROLE=guest MYGAME_LATENCY=120)
#       fslp_wait_all 90 "$hp" "$gp"
#       expect      "$hlog" "GAME_STARTED"                  "the round never started"
#       expect_same "$hlog" "$glog" "WORLD_SEED sum=[0-9]*" "the worlds diverged"
#   }
#   fslp_act "duel" 3 duel                    # 3 tries, fresh port each
#   fslp_verdict MYGAME                       # prints MYGAME_OK / MYGAME_FAIL
#
# Conventions worth copying from the examples (cavecrawl, quickdraw):
#   * a queries.odin of @(gd_method)s is the driver's window into the game —
#     and scriptgen GENERATES the mechanical half: per replicated scalar
#     field of every `entity=` kind, `probe_<kind>_<field>(id)` (0 = mine),
#     plus `probe_<kind>_count()` and `probe_my_<kind>()`. Hand-write only
#     the genuinely game-shaped reads (a derived view, a nearest-scan).
#   * drivers print ROLE_DONE on success and ROLE_FAIL on any timeout
#   * one grep-able UPPERCASE tag per fact; assert the fact on EVERY peer
#     that should observe it (and byte-identical where determinism matters)
#   * inject the bad link through your Options.env knobs (<ENV>_LATENCY /
#     _JITTER / _LOSS) — feel bugs live above 100ms, and a suite that only
#     ran on localhost proved nothing about your game
# ----------------------------------------------------------------------------

: "${GODOT:=/Applications/Godot.app/Contents/MacOS/Godot}"
: "${FSLP_PROJ:=$(pwd)}"
: "${FSLP_DRIVER:=driver.gd}"
: "${FSLP_LOGS:=$FSLP_PROJ/.runlogs}"

FSLP_OK=1        # the current act's verdict accumulator (expect* clear it)
FSLP_RUN_OK=1    # the whole run's verdict (a spent act clears it)
mkdir -p "$FSLP_LOGS"
# The pid LEDGER is a FILE, not a shell array, for one hard-won reason:
# launchers run inside command substitution (`hp=$(fslp_launch ...)`) — a
# subshell — so an array append there mutates a COPY and the parent reaps
# nothing (24 leaked headless instances taught this). A custom launcher
# joins the ledger with:  echo $! >> "$FSLP_PIDS"
FSLP_PIDS="$FSLP_LOGS/.pids"
: >"$FSLP_PIDS"

# Build the scripts through the ADDON (the downloader's path) and run the
# one-time --import pass headless runs need to discover the extension.
fslp_build() {
	ODIN_GODOT_ROOT="$FSLP_PROJ/addons/odin_godot" SKIP_CORE=1 \
		bash "$FSLP_PROJ/addons/odin_godot/build/build_scripts.sh" "$FSLP_PROJ" || return 1
	"$GODOT" --headless --path "$FSLP_PROJ" --import >/dev/null 2>&1 || true
}

# fslp_launch NAME LOG [ENV=VAL]... — one headless peer; echoes its pid (and
# files it in the ledger for fslp_reap).
fslp_launch() {
	local name="$1" log="$2"; shift 2
	mkdir -p "$(dirname "$log")"
	env "$@" ROLE="${ROLE:-$name}" \
		"$GODOT" --headless --path "$FSLP_PROJ" --script "$FSLP_DRIVER" \
		>"$log" 2>&1 &
	echo $! >>"$FSLP_PIDS"
	echo $!
}

# fslp_ready LOG PATTERN SECS PID — wait for a receipt (a bind, a join) before
# launching the next peer. Fails fast if the process died first — the classic
# port-in-use race every game re-discovered; pair it with fslp_act's retry.
fslp_ready() {
	local log="$1" pat="$2" secs="$3" pid="$4"
	local deadline=$((SECONDS + secs))
	while ((SECONDS < deadline)); do
		grep -qE "$pat" "$log" 2>/dev/null && return 0
		if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then return 1; fi
		sleep 0.2
	done
	return 1
}

# Wait (up to SECS) for every pid to exit — the normal path: drivers quit
# themselves after ROLE_DONE/ROLE_FAIL. Stragglers past the deadline are
# reaped GRACEFULLY (the act has failed by then; the logs still matter).
fslp_wait_all() {
	local secs="$1"; shift
	local deadline=$((SECONDS + secs))
	local live=1
	while ((live)); do
		live=0
		for p in "$@"; do
			kill -0 "$p" 2>/dev/null && live=1
		done
		((live)) || break
		((SECONDS >= deadline)) && { fslp_reap "$@"; break; }
		sleep 0.2
	done
}

# fslp_reap [PID]... — end processes without eating their last words: TERM,
# a short grace for stdout to flush, then -9 for anything still standing.
# A raw kill -9 truncates the log buffer, and a log that lies is worse than
# a hang (three separate "silent hang" hunts bought this lesson). No args =
# everything this act launched. kill -9 remains YOURS to call when the crash
# IS the test (host-migration acts kill the host mid-sentence on purpose).
fslp_reap() {
	local pids=("$@")
	if ((${#pids[@]} == 0)) && [ -s "$FSLP_PIDS" ]; then
		while read -r p; do pids+=("$p"); done <"$FSLP_PIDS"
	fi
	((${#pids[@]})) || return 0
	kill "${pids[@]}" 2>/dev/null
	local deadline=$((SECONDS + 8)) live=1
	while ((live && SECONDS < deadline)); do
		live=0
		for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && live=1; done
		((live)) && sleep 0.2
	done
	((live)) && kill -9 "${pids[@]}" 2>/dev/null
	: >"$FSLP_PIDS"
	return 0
}

# fslp_act NAME TRIES FN — run one scenario with per-act retries on fresh
# ports. FN receives a port; it returns nonzero (or lets an expect* fail) to
# spend a try. First-boot races are real: a bind conflict on a shared CI box
# should cost a retry, not the run. A spent act marks the RUN failed;
# later acts still execute (one run, every finding).
: "${FSLP_PORT_BASE:=$((20000 + RANDOM % 20000))}"
FSLP_ACT_NO=0
fslp_act() {
	local name="$1" tries="$2" fn="$3"
	FSLP_ACT_NO=$((FSLP_ACT_NO + 1))
	local try port
	for ((try = 1; try <= tries; try++)); do
		port=$((FSLP_PORT_BASE + FSLP_ACT_NO * 16 + try))
		echo "==> act $name (try $try, port $port)"
		FSLP_OK=1
		: >"$FSLP_PIDS"
		if "$fn" "$port" && ((FSLP_OK)); then
			echo "  PASS: $name"
			return 0
		fi
		fslp_reap
		((try < tries)) && echo "  retry: $name"
	done
	echo "  SPENT: $name failed $tries tries"
	FSLP_RUN_OK=0
	return 1
}

# expect LOG PATTERN MSG — the fact must appear in the log.
expect() {
	grep -qE "$2" "$1" || { echo "  FAIL: $3"; FSLP_OK=0; }
}

# expect_same LOG1 LOG2 PATTERN MSG — capture the first match from LOG1 and
# demand it BYTE-IDENTICAL in LOG2 (checksums, seeds, plaques).
expect_same() {
	local got; got=$(grep -m1 -oE "$3" "$1")
	if [ -z "$got" ]; then
		echo "  FAIL: $4 (never appeared in $(basename "$1"))"; FSLP_OK=0; return
	fi
	grep -qF "$got" "$2" || { echo "  FAIL: $4 ($got)"; FSLP_OK=0; }
}

# expect_absent LOG PATTERN MSG — driver *_FAIL lines, error spew.
expect_absent() {
	grep -qE "$2" "$1" && { echo "  FAIL: $3 ($(grep -m1 -E "$2" "$1"))"; FSLP_OK=0; }
}

# expect_count LOG PATTERN MIN MSG — the fact must appear at least MIN times
# (waves survived, pickups looted, scoreboard rows).
expect_count() {
	local n; n=$(grep -cE "$2" "$1")
	((n >= $3)) || { echo "  FAIL: $4 (saw $n, wanted >= $3)"; FSLP_OK=0; }
}

# fslp_verdict PREFIX — prints PREFIX_OK/PREFIX_FAIL from the RUN verdict
# (an act left un-acted still counts: a bare-expect script works too),
# returns accordingly, and resets both accumulators for reuse.
fslp_verdict() {
	if ((FSLP_RUN_OK && FSLP_OK)); then
		echo "$1_OK"
		return 0
	fi
	echo "$1_FAIL"
	FSLP_OK=1
	FSLP_RUN_OK=1
	return 1
}
