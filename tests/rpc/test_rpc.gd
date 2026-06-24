extends SceneTree

# ----------------------------------------------------------------------------
# RPC / multiplayer annotation test (runtime, non-editor). An Odin script (NetNode)
# declares two `@(gd_rpc)` methods. This driver asserts two things HEADLESSLY:
#
#   (1) CONFIG CORRECTNESS: the engine sees both methods as RPCs with the exact per-method
#       config the annotations declared. We read it straight from the source of truth the
#       engine itself consults: Script.get_rpc_config() (which routes to our ScriptExtension
#       _get_rpc_config virtual).
#
#   (2) call_local DISPATCH: with a multiplayer peer active, `node.rpc("set_value", n)` on a
#       call_local RPC runs the Odin method ON THE CALLING PEER too — observable in ONE
#       process. We assert the Odin proc actually ran (its exported side-effects changed).
#
# A genuine two-peer loopback is attempted separately and reported, but NOT gated on (see
# the LOOPBACK section at the end) — it is flaky/integration-only headless.
#
# Run:  $GODOT --headless --path tests/rpc --script test_rpc.gd
# ----------------------------------------------------------------------------

var _node: Node = null
var _done := false

func _fail(msg: String) -> void:
	print("RPC_FAIL: ", msg)
	print("RPC_FAIL")
	quit(1)

# Find a per-method subconfig by name, tolerant of String-vs-StringName key typing.
func _find(cfg: Dictionary, name: String) -> Variant:
	for k in cfg.keys():
		if str(k) == name:
			return cfg[k]
	return null

func _check(sub: Variant, name: String, mode: int, transfer: int, call_local: bool, channel: int) -> bool:
	if typeof(sub) != TYPE_DICTIONARY:
		_fail("config for '%s' is not a Dictionary (got %s)" % [name, typeof(sub)]); return false
	var d: Dictionary = sub
	if int(d["rpc_mode"]) != mode:
		_fail("'%s' rpc_mode = %s want %d" % [name, str(d["rpc_mode"]), mode]); return false
	if int(d["transfer_mode"]) != transfer:
		_fail("'%s' transfer_mode = %s want %d" % [name, str(d["transfer_mode"]), transfer]); return false
	if bool(d["call_local"]) != call_local:
		_fail("'%s' call_local = %s want %s" % [name, str(d["call_local"]), str(call_local)]); return false
	if int(d["channel"]) != channel:
		_fail("'%s' channel = %s want %d" % [name, str(d["channel"]), channel]); return false
	return true

func _initialize() -> void:
	var script: Script = load("res://scripts/net_node.odin")
	if script == null:
		_fail("could not load net_node.odin"); return

	var node := Node.new()
	node.set_script(script)
	node.name = "Net"
	get_root().add_child(node)
	_node = node

	# ---- (1) config correctness: read the engine's own RPC config source ----
	var cfg_v: Variant = script.get_rpc_config()
	if typeof(cfg_v) != TYPE_DICTIONARY:
		_fail("Script.get_rpc_config() is not a Dictionary (got %s)" % typeof(cfg_v)); return
	var cfg: Dictionary = cfg_v
	print("  rpc config keys: ", cfg.keys())

	var ping_sub: Variant = _find(cfg, "ping")
	if ping_sub == null:
		_fail("'ping' missing from rpc config"); return
	# ping: bare @(gd_rpc) -> authority(2) / reliable(2) / no call_local / channel 0
	if not _check(ping_sub, "ping", MultiplayerAPI.RPC_MODE_AUTHORITY, MultiplayerPeer.TRANSFER_MODE_RELIABLE, false, 0):
		return

	var sv_sub: Variant = _find(cfg, "set_value")
	if sv_sub == null:
		_fail("'set_value' missing from rpc config"); return
	# set_value: any_peer(1) / unreliable(0) / call_local / channel 2
	if not _check(sv_sub, "set_value", MultiplayerAPI.RPC_MODE_ANY_PEER, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, true, 2):
		return
	print("  ok  _get_rpc_config registered both methods with correct per-method config")
	# call_local dispatch runs in _process: node.rpc(...) requires the node be inside a LIVE
	# tree (engine ERR_UNCONFIGUREDs otherwise), which only holds once the main loop iterates.

# The first live frame: the scene tree is now running, so node.rpc(...) is legal. Do the
# call_local dispatch check here, then quit. Returning true ends the SceneTree main loop.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# ---- (2) call_local dispatch (single process) ----
	# A multiplayer peer must be active for node.rpc(...) to run (engine ERR_FAILs otherwise).
	# OfflineMultiplayerPeer is the single-peer (id 1, server) loopback — perfect for call_local.
	# Resolve/install the tree's MultiplayerAPI (rooted at "", which covers all nodes).
	var mp_api: MultiplayerAPI = get_multiplayer()
	if mp_api == null:
		mp_api = MultiplayerAPI.create_default_interface()
		set_multiplayer(mp_api, ^"")
	mp_api.multiplayer_peer = OfflineMultiplayerPeer.new()

	if not _node.is_inside_tree():
		_fail("node not inside tree on first frame"); return true
	if int(_node.get("last_value")) != 0:
		_fail("precondition: last_value should start 0"); return true
	var pings_before := int(_node.get("ping_count"))

	# call_local RPC: should dispatch into the Odin proc on THIS peer.
	var err := _node.rpc("set_value", 42)
	if err != OK:
		_fail("node.rpc('set_value', 42) returned error %d" % err); return true
	if int(_node.get("last_value")) != 42:
		_fail("call_local did NOT dispatch: last_value = %s want 42" % str(_node.get("last_value"))); return true
	if int(_node.get("ping_count")) != pings_before + 1:
		_fail("call_local dispatched wrong number of times"); return true
	print("  ok  call_local rpc dispatched the Odin method locally: last_value -> 42")

	print("RPC_OK")

	# ---- (3) LOOPBACK two-peer (best-effort, NOT gated) ----
	# A genuine remote dispatch (peer A rpc -> method runs on peer B) needs two independent
	# MultiplayerAPI/SceneTree contexts in one process, which is not reliably reproducible in
	# this headless single-SceneTree driver. We report status separately; RPC_OK above already
	# covers config + call_local, which is what is honestly verified here.
	print("RPC_LOOPBACK_SKIP: two-peer remote dispatch not exercised in this single-process driver")
	return true
