extends SceneTree

# ----------------------------------------------------------------------------
# Two-peer ENet RPC driver (tests/rpc_net). ONE of these runs per process; ROLE + PORT come
# from the environment so the harness can launch a "server" and a "client" that talk over a
# real ENet localhost connection.
#
# Each process:
#   1. loads the Odin NetNode script onto /root/Net (same path on both peers — required for
#      RPC routing),
#   2. hosts (server) or joins (client) via the Odin gd.host/gd.join ergonomic helpers,
#   3. waits for the connection (polls get_peers(), with a wall-clock timeout — no sleep-hope),
#   4. fires its RPCs, stays alive briefly to receive the peer's RPCs, then prints
#      <ROLE>_DONE and quits.
#
# The Odin @(gd_rpc) procs print "RPC_RECV <tag> on=<peer> from=<sender> value=<n>" sentinels;
# run.sh greps both processes' stdout to prove each call crossed the wire and executed on the
# OTHER peer with the right sender id.
# ----------------------------------------------------------------------------

var node: Node = null
var role := ""
var port := 0
var mp: MultiplayerAPI = null
var phase := "init"
var t0 := 0
var t_acted := 0
var client_id := 0

const TIMEOUT_MS := 15000
const SETTLE_MS := 2000   # stay alive this long after acting, to receive the peer's RPCs

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	port = int(OS.get_environment("PORT"))
	if role == "":
		role = "server"
	var script: Script = load("res://scripts/net_node.odin")
	if script == null:
		print(role.to_upper(), "_FAIL: could not load net_node.odin")
		quit(1); return
	node = Node.new()
	node.set_script(script)
	node.name = "Net"
	get_root().add_child(node)
	t0 = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT port=", port)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()

	# First LIVE frame: the node is now inside a running tree (it is NOT during _initialize),
	# so node.get_multiplayer() resolves and hosting/joining is legal. Do it here.
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
			node.call("report")
			if role == "server":
				client_id = peers[0]
				print("SERVER_SEES_CLIENT id=", client_id)
				# any_peer server -> client (targeted)
				node.rpc_id(client_id, "ping", 11)
				# authority server -> client (only the authority/server may send this)
				node.rpc_id(client_id, "auth", 33)
				# broadcast, NON-call_local: must NOT run on the server, MUST run on the client
				node.rpc("ping", 99)
				# broadcast, call_local: MUST run on the server too (positive control)
				node.rpc("echo", 88)
			else:
				print("CLIENT_SEES_SERVER")
				# any_peer client -> server (targeted) -> peer id 1 is the server
				node.rpc_id(1, "ping", 22)
			phase = "settle"
			t_acted = now
		elif now - t0 > TIMEOUT_MS:
			print(role.to_upper(), "_TIMEOUT: no peer after ", TIMEOUT_MS, "ms")
			quit(1); return true
		return false

	if phase == "settle":
		if now - t_acted > SETTLE_MS:
			print(role.to_upper(), "_DONE")
			quit(0); return true
		return false

	return false
