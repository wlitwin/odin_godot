#!/usr/bin/env bash
# Exercise the real quickstart lifecycle without exposing test methods in games.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
name="${1:?hello_net or hello_sim}"
case "$name" in hello_net|hello_sim) ;; *) exit 2 ;; esac
work="$(mktemp -d)"
cleanup() {
	local result=$?
	if ((result)); then
		for log in "$work/import.log" "$work/runtime.log"; do
			[[ ! -f "$log" ]] || tail -40 "$log" >&2
		done
		printf 'Scene lifecycle artifacts: %s\n' "$work" >&2
	else
		rm -rf "$work"
	fi
}
trap cleanup EXIT
python3 - "$ROOT" "$name" "$work/project" <<'PY'
from pathlib import Path
import shutil, sys

root, name, project = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
shutil.copytree(root/'examples'/name, project,
                ignore=shutil.ignore_patterns('.godot', 'bin', '*.gen.odin', '*.uid', '*.import', '.runlogs'))
cls = {'hello_net': 'HelloNet', 'hello_sim': 'HelloSim'}[name]
detach = name+'_detach' if name == 'hello_net' else name+'_net_detach'
probe = '''package $PACKAGE
import gd "godot:godot"
import "godot:gdext"
import kboot "godot:kit/boot"
import netgd "godot:kit/netgd"
import ksess "godot:kit/session"

@(gd_method)
$PREFIX_test_raw_detach :: proc(self: ^$CLASS) -> bool {
	mp := gd.node_get_multiplayer(self.owner)
	defer gd.release_ref(mp)
	before := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(before)
	for _ in 0..<2 {
		if netgd.wire_listen(&self.boot.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down") != .Ok {return false}
	}
	ses: ksess.Session
	wire: netgd.Session_Wire
	netgd.wire_attach(&wire, self.owner, &ses, 1)
	if netgd.wire_listen(&wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down") != .Ok {return false}
	netgd.wire_detach(&wire)
	netgd.wire_detach(&wire)
	ksess.session_destroy(&ses)
	after := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(after)
	callback := gd.callable(cast(gd.Object)self.owner, "on_packet")
	defer gd.free_callable(callback)
	connected := gd.object_is_connected(cast(gd.Object)mp, gd.sname("peer_packet"), callback)
	return before != nil && before == after && connected
}

@(gd_method)
$PREFIX_test_detach_rehost :: proc(self: ^$CLASS) -> bool {
	netgd.transport_close(&self.boot.wire)
	netgd.transport_close(&self.boot.wire)
	$DETACH(self)
	$DETACH(self)
	if self.ses.ran || kboot.boot_phase(&self.boot) != .Menu {return false}
	$PREFIX_ready(self)
	return self.ses.ran && self.ses.is_host && self.ses.replicating
}

@(gd_method)
$PREFIX_test_code_lifecycle :: proc(self: ^$CLASS) -> bool {
	_ = self
	rdv: netgd.Code_Rendezvous
	for _ in 0..<3 {
		if !netgd.code_host_open(&rdv, "ws://127.0.0.1:1", 4242) {return false}
		id := gd.object_get_instance_id(cast(gd.Object)rdv.ws)
		netgd.code_close(&rdv)
		netgd.code_close(&rdv)
		if gdext.object_get_instance_from_id(gdext.ObjectInstanceId(id)) != nil {return false}
	}
	return true
}
'''
for key, value in {'PACKAGE': name, 'CLASS': cls, 'PREFIX': name, 'DETACH': detach}.items():
    probe = probe.replace('$'+key, value)
(project/'scripts/kit_lifecycle_probe.odin').write_text(probe)
PY
project="$work/project"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
bash "$ROOT/build/build_scripts.sh" "$project"
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
HELLO_ROLE=host HELLO_PORT="${2:-45991}" HELLO_TOKEN=scene-lifecycle \
	"$GODOT" --headless --path "$project" --script "$ROOT/tests/kitboot/scene_exit.gd" >"$work/runtime.log" 2>&1
cat "$work/runtime.log"
rg -q '^KIT_SCENE_EXIT_OK$' "$work/runtime.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/import.log" "$work/runtime.log"; then
	cat "$work/import.log"
	exit 1
fi
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point \
	-custom-attribute:gd_method -custom-attribute:gd_half \
	-custom-attribute:gd_input -custom-attribute:gd_tick -custom-attribute:gd_sample
