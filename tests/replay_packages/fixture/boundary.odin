package replay_packages_probe

import gd "godot:godot"
import replaygd "godot:replay/godot"
import transportgd "godot:replay/godot/transport"
import storagegd "godot:replay/godot/storage"
import scenegd "godot:replay/godot/scene"
import inputgd "godot:replay/godot/input"
import debuggd "godot:replay/godot/debug"

World :: struct {tick: u32}
Control :: struct {held: u64}
Action :: struct {kind: u8}
Event :: struct {kind: u8}
Script :: struct {owner: gd.Node2d}

Owners :: struct {
	session: replaygd.Session(World, Control, Action, Event, 2),
	room: replaygd.Room(World, Control, Action, Event, 2),
	transport: transportgd.Enet,
	storage: storagegd.Browser_Store_Op,
	importer: storagegd.File_Import,
	view: scenegd.Script_View(u8, Script),
	input: inputgd.Input_Binding(Control),
	debug: debuggd.Debug_Overlay,
}

// Type checking instantiates the canonical package APIs without opening an
// engine window, file, endpoint, or browser operation.
@(require)
canonical_surface :: proc() {
	owners: Owners
	_ = replaygd.session_seat(&owners.session)
	_ = transportgd.enet_transport(&owners.transport)
	_ = storagegd.browser_store_key_valid("portable/profile")
	_ = storagegd.session_token("package-boundary-test")
	_ = scenegd.script_view_binding(&owners.view)
	_ = inputgd.input_binding_read(&owners.input)
	_ = debuggd.debug_session_status(&owners.session)
}
