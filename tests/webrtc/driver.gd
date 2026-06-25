extends Node

# ----------------------------------------------------------------------------
# In-BROWSER driver for the two-peer WebRTC RPC test (tests/webrtc).
#
# This is the main scene of the web export, so it runs inside the wasm build in a real
# browser (Godot routes `print` to the JS console, which drive.mjs captures). drive.mjs
# launches TWO headless-Chrome instances of this same page, one with ?role=host and one with
# ?role=join (plus the signaling ?url=...). Each:
#   1. loads the Odin RtcNode script onto /root/Net (SAME path on both — required for RPC
#      routing) and starts hosting/joining via gd.webrtc_host/join,
#   2. waits (generous timeout) for the REAL WebRTC data channel to come up — i.e. the
#      MultiplayerAPI reports a connected peer and a non-zero unique id,
#   3. fires `@(gd_rpc)` calls across the WebRTC link in BOTH directions, then stays alive a
#      moment to receive the other browser's RPCs,
#   4. prints sentinels (WEBRTC_CONNECTED / RPC_RECV.. / WEBRTC_DONE) that drive.mjs asserts.
# ----------------------------------------------------------------------------

var net: Node = null
var role := "host"
var url := "ws://127.0.0.1:9080"
var mp: MultiplayerAPI = null
var phase := "init"
var t0 := 0
var t_acted := 0

const TIMEOUT_MS := 45000   # WebRTC handshakes are async; be generous.
const SETTLE_MS := 3000     # stay alive after acting, to receive the peer's RPCs

func _ready() -> void:
	var q := _query()
	role = String(q.get("role", "host"))
	url = String(q.get("url", "ws://127.0.0.1:9080"))

	var script: Script = load("res://scripts/rtc_node.odin")
	if script == null:
		print("WEBRTC_FAIL: could not load rtc_node.odin")
		return
	net = Node.new()
	net.set_script(script)
	net.name = "Net"
	# Add under the scene-tree ROOT so the path is /root/Net on BOTH peers (RPC routing needs
	# identical node paths). add_child must be deferred from _ready while the tree is busy.
	get_tree().get_root().call_deferred("add_child", net)
	call_deferred("_start")

func _start() -> void:
	if role == "host":
		net.call("start_host", url)
	else:
		net.call("start_join", url)
	mp = net.get_multiplayer()
	t0 = Time.get_ticks_msec()
	phase = "connect"
	print("WEBRTC_BOOT role=", role, " url=", url)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	if phase == "connect":
		if mp == null:
			mp = net.get_multiplayer()
			return
		var peers: PackedInt32Array = mp.get_peers()
		if peers.size() >= 1 and mp.get_unique_id() != 0:
			net.call("report")
			print("WEBRTC_CONNECTED role=", role, " my_id=", mp.get_unique_id(), " peer=", peers[0])
			if role == "host":
				# broadcast (non-call_local): runs on the CLIENT, proving host->client.
				net.rpc("ping", 99)
				# call_local broadcast: positive control — runs locally on the host too.
				net.rpc("echo", 88)
			else:
				# targeted to the host (peer id 1): proves client->host with the client's id.
				net.rpc_id(1, "ping", 22)
			phase = "settle"
			t_acted = now
		elif now - t0 > TIMEOUT_MS:
			print("WEBRTC_TIMEOUT role=", role, " (no WebRTC peer after ", TIMEOUT_MS, "ms)")
			phase = "done"
		return

	if phase == "settle":
		if now - t_acted > SETTLE_MS:
			print("WEBRTC_DONE role=", role)
			phase = "done"
		return

func _query() -> Dictionary:
	var out := {}
	if OS.has_feature("web"):
		var s := str(JavaScriptBridge.eval("location.search || ''", true))
		if s.begins_with("?"):
			s = s.substr(1)
		for kv in s.split("&", false):
			var p := kv.split("=")
			if p.size() == 2:
				out[p[0]] = (p[1] as String).uri_decode()
	return out
