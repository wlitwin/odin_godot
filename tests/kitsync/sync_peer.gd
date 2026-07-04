extends SceneTree

# ----------------------------------------------------------------------------
# Two-peer kit/net sync driver (tests/kitsync). ONE per process; ROLE + PORT from
# the environment (mirrors tests/rpc_net). Phases:
#   state:    server ships FULL + DELTA; client applies + self-verifies (got 1,2)
#   commands: client issues the predicted `bump` command twice — the first is
#             CONFIRMED (got 3), the second runs against silently-diverged host
#             state and is REJECTED with embedded truth (got 4).
# The driver only sequences — all wire logic lives in the Odin SyncNode.
# ----------------------------------------------------------------------------

var node: Node = null
var role := ""
var port := 0
var mp: MultiplayerAPI = null
var phase := "init"
var t0 := 0
var t_acted := 0

const TIMEOUT_MS := 15000
const SETTLE_MS := 1000

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
				phase = "serve"
			else:
				print("CLIENT_SEES_SERVER")
				phase = "receive"
			t_acted = now
		elif now - t0 > TIMEOUT_MS:
			print(role.to_upper(), "_TIMEOUT: no peer after ", TIMEOUT_MS, "ms")
			quit(1); return true
		return false

	# Client: wait for both state packets, then run the command sequence.
	if phase == "receive":
		if int(node.call("get_got")) >= 2:
			node.call("issue_bump") # predicted; host will CONFIRM
			phase = "cmd_confirm"
			t_acted = now
		elif now - t_acted > TIMEOUT_MS:
			print("CLIENT_TIMEOUT: got=", node.call("get_got"))
			quit(1); return true
		return false

	if phase == "cmd_confirm":
		if int(node.call("get_got")) >= 3:
			node.call("issue_bump") # stale prediction; host will REJECT with truth
			phase = "cmd_reject"
			t_acted = now
		elif now - t_acted > TIMEOUT_MS:
			print("CLIENT_TIMEOUT: confirm never verified, got=", node.call("get_got"))
			quit(1); return true
		return false

	if phase == "cmd_reject":
		if int(node.call("get_got")) >= 4:
			print("CLIENT_DONE")
			quit(0); return true
		if now - t_acted > TIMEOUT_MS:
			print("CLIENT_TIMEOUT: reject never verified, got=", node.call("get_got"))
			quit(1); return true
		return false

	# Server: stay up until both commands executed, then settle so the final
	# result flushes through the reliable channel.
	if phase == "serve":
		if int(node.call("get_cmds")) >= 2:
			phase = "settle"
			t_acted = now
		elif now - t_acted > TIMEOUT_MS:
			print("SERVER_TIMEOUT: cmds=", node.call("get_cmds"))
			quit(1); return true
		return false

	if phase == "settle":
		if now - t_acted > SETTLE_MS:
			print("SERVER_DONE")
			quit(0); return true
		return false

	return false
