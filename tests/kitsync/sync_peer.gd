extends SceneTree

# ----------------------------------------------------------------------------
# Two-peer kit/net sync driver (tests/kitsync). ONE per process; ROLE + PORT from
# the environment (mirrors tests/rpc_net). The server hosts, waits for the client,
# then ships a FULL snapshot and a DELTA through kit/netgd; the client applies
# them via kit/net and self-verifies (SYNC_GOT_* ok=true sentinels). The driver
# only sequences — all wire logic lives in the Odin SyncNode.
# ----------------------------------------------------------------------------

var node: Node = null
var role := ""
var port := 0
var mp: MultiplayerAPI = null
var phase := "init"
var t0 := 0
var t_acted := 0

const TIMEOUT_MS := 15000
const SETTLE_MS := 2000

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	port = int(OS.get_environment("PORT"))
	if role == "":
		role = "server"
	var script: Script = load("res://scripts/sync_node.odin")
	if script == null:
		print(role.to_upper(), "_FAIL: could not load sync_node.odin")
		quit(1); return
	node = Node.new()
	node.set_script(script)
	node.name = "Sync"
	get_root().add_child(node)
	t0 = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT port=", port)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()

	if phase == "init":
		if not node.is_inside_tree():
			return false
		if role == "server":
			node.call("start_host", port)
		else:
			node.call("start_client", port)
		mp = node.get_multiplayer()
		if mp == null:
			print(role.to_upper(), "_FAIL: node.get_multiplayer() is null")
			quit(1); return true
		phase = "connect"
		t0 = Time.get_ticks_msec()
		return false

	if phase == "connect":
		var peers: PackedInt32Array = mp.get_peers()
		if peers.size() >= 1 and mp.get_unique_id() != 0:
			if role == "server":
				var client_id := peers[0]
				print("SERVER_SEES_CLIENT id=", client_id)
				node.call("send_full", client_id)
				node.call("send_delta", client_id)
				phase = "settle"
			else:
				print("CLIENT_SEES_SERVER")
				phase = "receive"
			t_acted = now
		elif now - t0 > TIMEOUT_MS:
			print(role.to_upper(), "_TIMEOUT: no peer after ", TIMEOUT_MS, "ms")
			quit(1); return true
		return false

	# Client: wait until both packets arrived AND self-verified.
	if phase == "receive":
		if int(node.call("get_got")) >= 2:
			print("CLIENT_DONE")
			quit(0); return true
		if now - t_acted > TIMEOUT_MS:
			print("CLIENT_TIMEOUT: got=", node.call("get_got"))
			quit(1); return true
		return false

	# Server: stay alive long enough for the reliable channel to deliver.
	if phase == "settle":
		if now - t_acted > SETTLE_MS:
			print("SERVER_DONE")
			quit(0); return true
		return false

	return false
