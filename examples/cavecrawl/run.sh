#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# CAVECRAWL (phases 1+2): the toolkit example boots to a WORKING LOBBY with
# CHAT. Two headless processes instantiate the real cave.tscn, press the
# lobby's own button methods (host / join), seat over real ENet through
# kit/session, and then read the ACTUAL kit/ui Label texts back out of the
# tree: both names on both peers, the you-marker, the host's Start button
# appearing once two spelunkers are in — and both peers' chat lines, the
# "guest joined" system line, and the guest's positional marker (kit/comms
# over the session's SES_APP wire).
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

launch() {
	local role="$1" log="$2" port="$3" name="$4" token="$5"
	ROLE="$role" CAVE_PORT="$port" CAVE_NAME="$name" CAVE_TOKEN="$token" \
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
