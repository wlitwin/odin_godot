extends Node

# ----------------------------------------------------------------------------
# In-BROWSER driver for the N-peer WebRTC RPC test (tests/webrtc).
#
# This is the main scene of the web export, so it runs inside the wasm build in a real
# browser (Godot routes `print` to the JS console, which drive.mjs captures). drive.mjs
# launches THREE headless-Chrome instances of this same page — one ?role=host, two
# ?role=join — all with ?peers=2 (how many REMOTE peers to wait for) and the signaling
# ?url=... . Each:
#   1. loads the Odin RtcNode script onto /root/Net (SAME path on all — required for RPC
#      routing) and starts hosting/joining via gd.webrtc_host/join,
#   2. waits (generous timeout) for the REAL WebRTC data channels to come up — i.e. the
#      MultiplayerAPI reports ?peers=N connected peers and a non-zero unique id (a JOINER
#      only holds a channel to the host; it sees the other joiner because the host relays
#      the peer roster — so this gate also proves the star's relay),
#   3. fires `@(gd_rpc)` calls across the WebRTC links — targeted, broadcast, and call_local
#      broadcast (which must transit the HOST to reach the other joiner) — then stays alive
#      a moment to receive the other browsers' RPCs,
#   4. prints sentinels (WEBRTC_CONNECTED / RPC_RECV.. / WEBRTC_DONE) that drive.mjs asserts.
# ----------------------------------------------------------------------------

var net: Node = null
var role := "host"
var url := "ws://127.0.0.1:9080"
var room := ""
var expected := 1   # how many REMOTE peers to wait for before acting (?peers=N)
var room_printed := false
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
	room = String(q.get("room", ""))
	expected = maxi(1, int(String(q.get("peers", "1"))))

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
		net.call("start_join", url, room)
	mp = net.get_multiplayer()
	_hook(mp)
	t0 = Time.get_ticks_msec()
	phase = "connect"
	print("WEBRTC_BOOT role=", role, " url=", url, " room=", room)

# Surface departures: drive.mjs closes one joiner's browser mid-session and
# asserts the survivors both NOTICE (this sentinel) and stay alive (no wasm
# crash) — the production web host died on exactly this.
func _hook(m: MultiplayerAPI) -> void:
	if m != null:
		m.peer_disconnected.connect(func(id: int) -> void: print("WEBRTC_PEER_GONE id=", id))

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	# Host: surface the server-assigned room CODE so the driver can hand it to the joiner.
	if role == "host" and not room_printed:
		var c := String(net.call("room_code"))
		if c != "":
			room_printed = true
			print("WEBRTC_ROOM ", c)

	if phase == "connect":
		if mp == null:
			mp = net.get_multiplayer()
			_hook(mp)
			return
		var peers: PackedInt32Array = mp.get_peers()
		if peers.size() >= expected and mp.get_unique_id() != 0:
			net.call("report")
			print("WEBRTC_CONNECTED role=", role, " my_id=", mp.get_unique_id(), " peers=", peers)
			if role == "host":
				# broadcast (non-call_local): runs on every CLIENT, proving host->client.
				net.rpc("ping", 99)
				# call_local broadcast: positive control — runs locally on the host too.
				net.rpc("echo", 88)
			else:
				# targeted to the host (peer id 1): proves client->host with the client's id.
				net.rpc_id(1, "ping", 22)
				# broadcast from a JOINER: reaches the other joiner only if the HOST relays
				# it (a joiner holds no channel to its sibling) — the star's money shot.
				net.rpc("echo", 44)
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
