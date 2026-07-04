extends SceneTree

# ----------------------------------------------------------------------------
# THE PHASE-0 ACID TEST driver (tests/kitacid). THREE processes — server (host
# authority), owner (the issuing client), observer (a client that never issues
# anything) — over ENet localhost with injected receive latency on every peer.
# ROLE + PORT + LATENCY_MS come from the environment. The driver only sequences;
# all wire logic lives in the Odin AcidSession, all GAMEPLAY in orb.odin.
#
# Scenario: server spawns the orb (hp=100 st=10, owned by player 2) and
# join-snapshots both clients. COMMANDS: the owner strikes (cost 4) twice —
# each predicted instantly, then CONFIRMED a real round trip later — and a
# third time on empty stamina, which is locally rejected, still sent, and
# REJECTED by the host with truth. The observer just converges
# (100/10 -> 92/6 -> 84/2) through delta batches. STREAMS: the owner then
# drives the orb's x/y for ~4s — streamed unreliable at the net tick rate —
# and BOTH the host and the observer (the same role-free sampling code)
# verify smooth interpolated motion. Both clients also prove clock sync sees
# the injected RTT.
# ----------------------------------------------------------------------------

var session: Node = null
var orb: Node = null
var role := ""
var port := 0
var latency := 0
var mp: MultiplayerAPI = null
var phase := "init"
var t_acted := 0

const TIMEOUT_MS := 20000
const FLUSH_MS := 600
const SERVER_SETTLE_MS := 800

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	port = int(OS.get_environment("PORT"))
	latency = int(OS.get_environment("LATENCY_MS"))
	if role == "":
		role = "server"
	var orb_script: Script = load("res://scripts/orb.odin")
	var session_script: Script = load("res://scripts/session.odin")
	if orb_script == null or session_script == null:
		print(role.to_upper(), "_FAIL: could not load scripts")
		quit(1); return
	orb = Node.new()
	orb.set_script(orb_script)
	orb.name = "Orb"
	session = Node.new()
	session.set_script(session_script)
	session.name = "Session"
	get_root().add_child(orb)
	get_root().add_child(session)
	t_acted = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT port=", port, " latency_ms=", latency)

func timed_out(now: int, msg: String) -> bool:
	if now - t_acted > TIMEOUT_MS:
		print(role.to_upper(), "_TIMEOUT: ", msg)
		return true
	return false

func _process(delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if phase != "init" and session != null:
		session.call("tick", delta)

	if phase == "init":
		if not session.is_inside_tree() or not orb.is_inside_tree():
			return false
		session.call("setup", latency, orb)
		if role == "server":
			session.call("start_host", port)
		elif role == "owner":
			session.call("start_owner", port)
		else:
			session.call("start_observer", port)
		mp = session.get_multiplayer()
		if mp == null:
			print(role.to_upper(), "_FAIL: get_multiplayer() is null")
			quit(1); return true
		phase = "connect"
		t_acted = now
		return false

	if phase == "connect":
		var need := 2 if role == "server" else 1
		if mp.get_peers().size() >= need and mp.get_unique_id() != 0:
			if role == "server":
				phase = "seat"
			else:
				# Transport up: ask the host to seat us in the session.
				session.call("join")
				phase = "wait_spawn"
			t_acted = now
		elif timed_out(now, "peers never connected"):
			quit(1); return true
		return false

	# ---- server: both players seated in the SESSION, then announce the world ----
	if phase == "seat":
		if int(session.call("get_players")) >= 3:
			session.call("announce_world")
			phase = "serve"
			t_acted = now
		elif timed_out(now, "players seated=" + str(session.call("get_players"))):
			quit(1); return true
		return false

	# ---- server: commands answered, own stream view verified, clients done ----
	if phase == "serve":
		if int(session.call("get_cmds")) >= 3 and int(session.call("get_stream")) >= 1 and int(session.call("get_dones")) >= 2:
			phase = "settle"
			t_acted = now
		elif timed_out(now, "cmds=" + str(session.call("get_cmds")) + " stream=" + str(session.call("get_stream")) + " dones=" + str(session.call("get_dones"))):
			quit(1); return true
		return false

	if phase == "settle":
		if now - t_acted > SERVER_SETTLE_MS:
			print("SERVER_DONE")
			quit(0); return true
		return false

	# ---- owner: strike -> confirm -> strike -> confirm -> strike -> reject ----
	if phase == "wait_spawn":
		if int(session.call("get_got")) >= 1:
			if role == "owner":
				session.call("issue_strike", 4)
				phase = "round1"
			else:
				phase = "watch"
			t_acted = now
		elif timed_out(now, "spawn never arrived"):
			quit(1); return true
		return false

	if phase == "round1":
		if int(session.call("get_got")) >= 2:
			session.call("issue_strike", 4)
			phase = "round2"
			t_acted = now
		elif timed_out(now, "first confirm never arrived"):
			quit(1); return true
		return false

	if phase == "round2":
		if int(session.call("get_got")) >= 3:
			session.call("issue_strike", 4) # stamina is 2 < 4: local + host reject
			phase = "round3"
			t_acted = now
		elif timed_out(now, "second confirm never arrived"):
			quit(1); return true
		return false

	if phase == "round3":
		if int(session.call("get_got")) >= 4:
			# Commands proven — now drive the orb for the stream scenario. The
			# owner streams for a fixed window while host + observer verify.
			session.call("start_moving")
			phase = "move"
			t_acted = now
		elif timed_out(now, "reject never arrived"):
			quit(1); return true
		return false

	if phase == "move":
		if now - t_acted > 4000 and int(session.call("get_pings")) >= 3:
			session.call("send_done")
			phase = "flush"
			t_acted = now
		elif timed_out(now, "move window / pings=" + str(session.call("get_pings"))):
			quit(1); return true
		return false

	# ---- observer: converge on the authoritative end state, no role code ----
	if phase == "watch":
		if int(session.call("get_hp")) == 84 and int(session.call("get_st")) == 2:
			phase = "stream"
			t_acted = now
		elif timed_out(now, "state never converged hp=" + str(session.call("get_hp")) + " st=" + str(session.call("get_st"))):
			quit(1); return true
		return false

	if phase == "stream":
		if int(session.call("get_stream")) >= 1:
			phase = "clock"
			t_acted = now
		elif timed_out(now, "stream never verified (state=" + str(session.call("get_stream")) + ")"):
			quit(1); return true
		return false

	# ---- both clients: prove clock sync sampled the injected RTT ----
	if phase == "clock":
		if int(session.call("get_pings")) >= 3:
			session.call("send_done")
			phase = "flush"
			t_acted = now
		elif timed_out(now, "pings=" + str(session.call("get_pings"))):
			quit(1); return true
		return false

	if phase == "flush":
		if now - t_acted > FLUSH_MS:
			print(role.to_upper(), "_DONE")
			quit(0); return true
		return false

	return false
