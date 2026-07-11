#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# The friendslop acid-test harness — source this from your game's run.sh.
#
# The pattern (two shipped games grew it independently, so it's yours free):
# launch N headless processes under injected latency, drive them with a
# GDScript SceneTree script (see driver.gd next door) that presses the same
# code paths the UI fires and PRINTS what it sees, then assert over the LOGS.
# Verdicts come from log greps, never process exit codes — the launch
# subshell owns the pids, so `wait` isn't yours to call.
#
#   source addons/odin_godot/template/test/harness.sh
#   fslp_build                       # scripts through the addon + the --import pass
#   pid=$(fslp_launch host  h.log MYGAME_PORT=4307 ROLE=host)
#   pid=$(fslp_launch guest g.log MYGAME_PORT=4307 ROLE=guest)
#   fslp_wait_all 90 "$hpid" "$gpid"
#   expect      h.log "GAME_STARTED"        "the round never started"
#   expect_same h.log g.log "WORLD_SEED sum=[0-9]*" "the worlds diverged"
#   fslp_verdict MYGAME                      # prints MYGAME_OK / MYGAME_FAIL
#
# Conventions worth copying from the examples (cavecrawl, puttputt):
#   * a queries.odin of @(gd_method)s is the driver's window into the game
#   * drivers print ROLE_DONE on success and ROLE_FAIL on any timeout
#   * one grep-able UPPERCASE tag per fact; assert the fact on EVERY peer
#     that should observe it (and byte-identical where determinism matters)
#   * retry the whole attempt on a fresh port — first-boot races are real
# ----------------------------------------------------------------------------

: "${GODOT:=/Applications/Godot.app/Contents/MacOS/Godot}"
: "${FSLP_PROJ:=$(pwd)}"
: "${FSLP_DRIVER:=driver.gd}"

FSLP_OK=1

# Build the scripts through the ADDON (the downloader's path) and run the
# one-time --import pass headless runs need to discover the extension.
fslp_build() {
	ODIN_GODOT_ROOT="$FSLP_PROJ/addons/odin_godot" SKIP_CORE=1 \
		bash "$FSLP_PROJ/addons/odin_godot/build/build_scripts.sh" "$FSLP_PROJ" || return 1
	"$GODOT" --headless --path "$FSLP_PROJ" --import >/dev/null 2>&1 || true
}

# fslp_launch NAME LOG [ENV=VAL]... — one headless peer; echoes its pid.
fslp_launch() {
	local name="$1" log="$2"; shift 2
	env "$@" ROLE="${ROLE:-$name}" \
		"$GODOT" --headless --path "$FSLP_PROJ" --script "$FSLP_DRIVER" \
		>"$log" 2>&1 &
	echo $!
}

# Wait (up to SECS) for every pid to exit; kill -9 stragglers.
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
		((SECONDS >= deadline)) && { kill -9 "$@" 2>/dev/null; break; }
		sleep 1
	done
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

# fslp_verdict PREFIX — prints PREFIX_OK/PREFIX_FAIL, returns accordingly,
# and resets FSLP_OK for a retry loop.
fslp_verdict() {
	if ((FSLP_OK)); then
		echo "$1_OK"
		return 0
	fi
	echo "$1_FAIL"
	FSLP_OK=1
	return 1
}
