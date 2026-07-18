#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# HELLO_NET: the quickstart's own acid — two headless windows under 120ms
# injected latency; the host walks, the guest watches the walk arrive through
# the wire, both read through GENERATED probes. Prints HELLO_NET_OK.
#   nix develop --command bash -c 'bash examples/hello_net/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/hello_net"

if ! bash "$ROOT/build/build_scripts.sh" "$PROJ"; then
	echo "HELLO_NET_FAIL: script build failed"
	exit 1
fi
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

FSLP_PROJ="$PROJ"
FSLP_DRIVER="hello_test.gd"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

two_windows() {
	local port="$1"
	local hlog="$FSLP_LOGS/host.log" glog="$FSLP_LOGS/guest.log"
	: >"$hlog"; : >"$glog"
	local hp gp
	hp=$(fslp_launch host "$hlog" HELLO_ROLE=host HELLO_PORT="$port" HELLO_LATENCY=120)
	fslp_ready "$hlog" "HELLO_STARTED" 10 "$hp" || { echo "  port $port: host never started"; return 1; }
	gp=$(fslp_launch guest "$glog" HELLO_ROLE=join HELLO_PORT="$port" HELLO_LATENCY=120 HELLO_TOKEN=hello-guest)
	fslp_wait_all 45 "$hp" "$gp"

	# (No HELLO_SEATED on the host: its own seat emits no welcome — the
	# roster receipt below covers it.)
	expect "$glog" "HELLO_SEATED me=2" "the guest was never seated"
	expect "$hlog" "HELLO_TWO_UP me=1" "the host never saw both squares"
	expect "$glog" "HELLO_TWO_UP" "the guest never saw both squares"
	expect "$hlog" "HELLO_WALKED" "the host never walked"
	expect "$glog" "HELLO_SAW_WALK d=([6-9][0-9]|[0-9]{3,})" "the walk never crossed the wire"
	expect "$hlog" "HOST_DONE" "host did not finish"
	expect "$glog" "GUEST_DONE" "guest did not finish"

	if ((!FSLP_OK)); then
		echo "  --- host ---"; tail -n 10 "$hlog" | sed 's/^/    /'
		echo "  --- guest ---"; tail -n 10 "$glog" | sed 's/^/    /'
		return 1
	fi
}

# JOIN BY CODE: the same two windows, but the guest types a four-letter code
# instead of an address — the relay (the SAME signaling server the browser
# build uses, in native room mode) answers with the host's endpoint and the
# join proceeds as plain ENet. Needs node for the relay; skipped without it.
join_by_code() {
	local port="$1"
	local sigport=$((port + 7))
	node "$ROOT/tests/webrtc/signal_server.mjs" "$sigport" >"$FSLP_LOGS/signal.log" 2>&1 &
	local sigpid=$!
	fslp_ready "$FSLP_LOGS/signal.log" "signal: listening" 10 "$sigpid" || { kill "$sigpid" 2>/dev/null; echo "  the relay never listened"; return 1; }
	local relay="ws://127.0.0.1:$sigport/rtc"
	local hlog="$FSLP_LOGS/chost.log" glog="$FSLP_LOGS/cguest.log"
	: >"$hlog"; : >"$glog"
	local hp gp code
	hp=$(fslp_launch host "$hlog" HELLO_ROLE=host HELLO_PORT="$port" HELLO_RELAY="$relay" HELLO_LATENCY=120)
	if ! fslp_ready "$hlog" "HELLO_CODE room=" 15 "$hp"; then
		kill "$sigpid" 2>/dev/null
		echo "  the code never minted"; return 1
	fi
	code=$(grep -m1 -oE "HELLO_CODE room=[A-Z0-9]+" "$hlog" | cut -d= -f2)
	gp=$(fslp_launch guest "$glog" HELLO_ROLE=code HELLO_CODE="$code" HELLO_RELAY="$relay" HELLO_LATENCY=120 HELLO_TOKEN=hello-code-guest)
	fslp_wait_all 45 "$hp" "$gp"
	kill "$sigpid" 2>/dev/null

	# (The guest gets NO address env — seating at all proves the relay
	# resolved the code to the host's real endpoint.)
	expect "$glog" "HELLO_CODE_JOIN code=$code" "the guest never opened the code door"
	expect "$glog" "HELLO_SEATED me=2" "the code-joiner was never seated"
	expect "$glog" "HELLO_SAW_WALK d=([6-9][0-9]|[0-9]{3,})" "the walk never crossed the code-brokered wire"
	expect "$hlog" "HOST_DONE" "coded host did not finish"
	expect "$glog" "GUEST_DONE" "code-joiner did not finish"

	if ((!FSLP_OK)); then
		echo "  --- signal ---"; tail -n 6 "$FSLP_LOGS/signal.log" | sed 's/^/    /'
		echo "  --- host ---"; tail -n 10 "$hlog" | sed 's/^/    /'
		echo "  --- guest ---"; tail -n 10 "$glog" | sed 's/^/    /'
		return 1
	fi
}

fslp_act "two windows" 3 two_windows
if command -v node >/dev/null 2>&1; then
	fslp_act "join by code" 2 join_by_code
else
	echo "  (join-by-code act skipped: no node for the relay)"
fi
fslp_verdict HELLO_NET
