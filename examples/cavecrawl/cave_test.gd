extends SceneTree

# ----------------------------------------------------------------------------
# Cavecrawl test driver (examples/cavecrawl). TWO processes — host and guest —
# instantiate the REAL cave.tscn and press the same code paths the UI fires.
#
# Phase 1: seating over the wire, the live player list read out of the actual
#   kit/ui Label tree on both peers, the host-only Start button.
# Phase 2: chat through the box's own submit path (both directions), the
#   "guest joined" system line, a positional marker.
# Phase 3: Start builds the CAVE — both spelunkers WALK to the chest (owner-
#   streamed motion moving the prompt's range gate into place), the guest
#   loots the gems (predicted; bag credited by the host), the host loots the
#   torches (authority path), a second grab is DENIED empty, the door opens
#   for both, gems are conserved, and the bag shows in the real inventory UI.
# ----------------------------------------------------------------------------

var cave: Node = null
var role := ""
var phase := "init"
var t_acted := 0
var acted := false # one-shot action latch per phase

const TIMEOUT_MS := 20000

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	if role == "":
		role = "host"
	var scene: PackedScene = load("res://cave.tscn")
	if scene == null:
		print(role.to_upper(), "_FAIL: could not load cave.tscn")
		quit(1); return
	cave = scene.instantiate()
	get_root().add_child(cave)
	t_acted = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT")

func label_texts() -> String:
	var texts := []
	for l in cave.find_children("*", "Label", true, false):
		if l.visible and l.text != "":
			texts.append(l.text)
	return " | ".join(texts)

func enter(next: String, now: int) -> void:
	phase = next
	t_acted = now
	acted = false

func timed_out(now: int, msg: String) -> bool:
	if now - t_acted > TIMEOUT_MS:
		print(role.to_upper(), "_TIMEOUT: ", phase, " ", msg, "  UI=[", label_texts(), "]")
		return true
	return false

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()

	# ---- ACT 2 (phase 6): resume the saved run in fresh processes ----------
	if role == "resume":
		if phase == "init":
			if not cave.is_inside_tree():
				return false
			cave.call("on_resume") # host the world back from the file
			enter("await", now)
			return false
		if phase == "await":
			# CAVE_RESUMED already printed the world's ledger; now the guest
			# returns with her persisted token and reclaims herself.
			if int(cave.call("get_players")) >= 2:
				enter("board", now)
			elif timed_out(now, "the guest never returned"):
				quit(1); return true
			return false
		if phase == "board":
			if not acted:
				acted = true
				cave.call("show_score", true)
			var board := label_texts()
			if board.contains("| 1 | 0"): # the guest's kill outlived every process
				print("CAVE_RESUME_SCORE [", board, "]")
				enter("linger", now)
			elif timed_out(now, "the ledger forgot"):
				quit(1); return true
			return false
		if phase == "linger":
			# Stay hosting until the guest's post-resume kill lands — quitting
			# now would tear the server down under her.
			if int(cave.call("dwellers")) < 3:
				print("RESUME_DONE")
				quit(0); return true
			if timed_out(now, "the guest never avenged herself"):
				quit(1); return true
			return false
		return false

	if role == "rejoin":
		if phase == "init":
			if not cave.is_inside_tree():
				return false
			cave.call("on_join")
			enter("seat", now)
			return false
		if phase == "seat":
			if bool(cave.call("is_seated")) and bool(cave.call("world_ready")):
				print("CAVE_REJOINED dwellers=", cave.call("dwellers"), " gems=", cave.call("world_gems"), " door=", cave.call("door_open"))
				enter("avenge", now)
			elif timed_out(now, "never re-seated"):
				quit(1); return true
			return false
		if phase == "avenge":
			# The resumed run is PLAYABLE, not a diorama: rocks still fell
			# dwellers (wave 2 came back mid-campaign with the game blob).
			if int(cave.call("dwellers")) < 3:
				print("CAVE_RESUME_SLAIN dwellers=", cave.call("dwellers"))
				print("REJOIN_DONE")
				quit(0); return true
			if bool(cave.call("can_throw")):
				var aim: Vector2 = cave.call("dweller_dir")
				if aim != Vector2.ZERO:
					cave.call("throw", aim.x, aim.y)
			if timed_out(now, "no vengeance, dwellers=" + str(cave.call("dwellers"))):
				quit(1); return true
			return false
		return false

	# ---- ACT 3: MATCH FLOW (win -> run it back) + MODERATION (kick -> ban) --
	if role == "endhost" or role == "endguest":
		if phase == "init":
			if not cave.is_inside_tree():
				return false
			cave.call("on_host" if role == "endhost" else "on_join")
			enter("lobby3", now)
			return false
		if phase == "lobby3":
			var seated := role == "endhost" or bool(cave.call("is_seated"))
			if seated and int(cave.call("get_players")) >= 2:
				if role == "endhost":
					cave.call("on_start")
				enter("world3", now)
			elif timed_out(now, "players=" + str(cave.call("get_players"))):
				quit(1); return true
			return false
		if phase == "world3":
			if bool(cave.call("world_ready")):
				enter("cull", now)
			elif timed_out(now, "world never materialized"):
				quit(1); return true
			return false
		if phase == "cull":
			# The ONLY floor (CAVE_FLOORS=1): kill wave 1, healing through bites.
			cave.call("heal")
			if int(cave.call("dwellers")) > 0 and bool(cave.call("can_throw")):
				var dir: Vector2 = cave.call("dweller_dir")
				if dir != Vector2.ZERO:
					cave.call("throw", dir.x, dir.y)
			if int(cave.call("wave")) >= 2:
				enter("brood", now)
			elif timed_out(now, "wave 1 never fell, dwellers=" + str(cave.call("dwellers"))):
				quit(1); return true
			return false
		if phase == "brood":
			if int(cave.call("dwellers")) > 0:
				enter("sweep", now)
			elif timed_out(now, "wave 2 never came"):
				quit(1); return true
			return false
		if phase == "sweep":
			cave.call("heal")
			if int(cave.call("dwellers")) > 0 and bool(cave.call("can_throw")):
				var dir: Vector2 = cave.call("dweller_dir")
				if dir != Vector2.ZERO:
					cave.call("throw", dir.x, dir.y)
			if int(cave.call("dwellers")) == 0 and int(cave.call("wave")) >= 2:
				cave.call("walk_to", 560.0, 180.0) # the whole party to the door
				enter("door3", now)
			elif timed_out(now, "wave 2 never fell"):
				quit(1); return true
			return false
		if phase == "door3":
			# The LAST floor's open door doesn't descend — it WINS. The game's
			# own won edge prints CAVE_WON on every peer.
			cave.call("heal")
			if not get_meta("opened", false) and role == "endguest" and int(cave.call("prompt_kind")) == 2:
				set_meta("opened", true)
				cave.call("interact")
			if bool(cave.call("won")):
				if not acted:
					acted = true
					set_meta("won_at", now)
					print("CAVE_END_UI [", label_texts(), "]")
				# The host DWELLS on the end screen before running it back — a
				# human reads it, and the won byte must outlive a net tick to
				# ship at all (a same-tick 1->0 pulse never survives the
				# shadow diff: deltas carry STATE, not events).
				if role == "endguest" or now - int(get_meta("won_at")) > 2500:
					if role == "endhost":
						cave.call("on_start") # Start on the end screen = ANOTHER RUN
					enter("reborn", now)
			elif timed_out(now, "never conquered, door=" + str(cave.call("door_open"))):
				quit(1); return true
			return false
		if phase == "reborn":
			# The same session runs it back: fresh chest, fresh hp, no re-seat.
			if not bool(cave.call("won")) and int(cave.call("chest_items")) == 5 and int(cave.call("my_hp")) == 100:
				if not acted:
					acted = true
					set_meta("reborn_at", now)
					print("CAVE_REBORN chest=", cave.call("chest_items"), " hp=", cave.call("my_hp"), " players=", cave.call("get_players"))
				if role == "endhost":
					# Let the second run breathe before the kick — the guest's
					# 120ms-late view of the restart must land first.
					if now - int(get_meta("reborn_at")) > 2000:
						cave.call("kick", 2) # moderation: the guest is out, with a ban
						enter("lonely", now)
				else:
					enter("limbo", now)
			elif timed_out(now, "second run never bloomed, chest=" + str(cave.call("chest_items")) + " won=" + str(cave.call("won"))):
				quit(1); return true
			return false
		if phase == "lonely": # endhost: the kick must shrink the CONNECTED roster
			if int(cave.call("get_players")) == 1:
				print("CAVE_KICK_ROSTER n=1")
				enter("serve", now)
			elif timed_out(now, "the kick never landed"):
				quit(1); return true
			return false
		if phase == "serve":
			# Keep hosting so the banned token can come bounce off the door;
			# run.sh reaps this process when the story is over.
			return false
		if phase == "limbo": # endguest: the game's handler prints CAVE_KICKED_ME
			if bool(cave.call("kicked")):
				print(role.to_upper(), "_DONE")
				quit(0); return true
			elif timed_out(now, "never told about the kick"):
				quit(1); return true
			return false
		return false

	if role == "endguest2":
		# The banned identity returns: same token, new process — and the door
		# says no, with a reason (the game's handler prints CAVE_DENIED).
		if phase == "init":
			if not cave.is_inside_tree():
				return false
			cave.call("on_join")
			enter("bounce", now)
			return false
		if phase == "bounce":
			if int(cave.call("denied")) >= 0:
				print(role.to_upper(), "_DONE")
				quit(0); return true
			elif timed_out(now, "the ban never answered"):
				quit(1); return true
			return false
		return false

	if phase == "init":
		if not cave.is_inside_tree():
			return false
		cave.call("on_host" if role == "host" else "on_join")
		enter("lobby", now)
		return false

	if phase == "lobby":
		var seated := role == "host" or bool(cave.call("is_seated"))
		if seated and int(cave.call("get_players")) >= 2:
			enter("verify", now)
		elif timed_out(now, "players=" + str(cave.call("get_players"))):
			quit(1); return true
		return false

	if phase == "verify":
		# Give the stats a beat so ping can appear, then read the REAL UI.
		if now - t_acted > 1500:
			print("CAVE_UI [", label_texts(), "]")
			var starts := 0
			for b in cave.find_children("*", "Button", true, false):
				if b.text == "Start" and b.visible:
					starts += 1
			print("CAVE_START_VISIBLE n=", starts)
			# Phase 2: speak through the chat box's own submit path.
			cave.call("on_chat", "found a torch" if role == "host" else "on my way")
			if role == "guest":
				cave.call("mark")
			enter("chat", now)
		return false

	if phase == "chat":
		var ui := label_texts()
		if ui.contains("hosty: found a torch") and ui.contains("guest: on my way"):
			print("CAVE_CHAT [", ui, "]")
			# Phase 3: the host presses Start — the same method the button fires.
			if role == "host":
				cave.call("on_start")
			enter("world", now)
		elif timed_out(now, "chat lines never landed"):
			quit(1); return true
		return false

	if phase == "world":
		if bool(cave.call("world_ready")):
			print("CAVE_WORLD_READY gems=", cave.call("world_gems"))
			# Walk to the chest (300,180) from each side — owner-streamed motion.
			cave.call("walk_to", 300.0 if role == "host" else 270.0, 150.0 if role == "host" else 180.0)
			enter("walk", now)
		elif timed_out(now, "world never materialized"):
			quit(1); return true
		return false

	if phase == "walk":
		if int(cave.call("prompt_kind")) == 1:
			print("CAVE_AT_CHEST")
			enter("loot_guest", now)
		elif timed_out(now, "never reached the chest, prompt_kind=" + str(cave.call("prompt_kind"))):
			quit(1); return true
		return false

	if phase == "loot_guest":
		# The guest grabs the gems (slot 0). The host watches the chest drain
		# through replication before taking its own turn.
		if role == "guest" and not acted:
			acted = true
			cave.call("interact")
		var gems := int(cave.call("my_gems"))
		var chest_gone := int(cave.call("chest_items")) <= 2 # gems left the chest
		if (role == "guest" and gems == 3) or (role == "host" and chest_gone):
			print("CAVE_GEMS_LOOTED mine=", gems)
			enter("loot_host", now)
		elif timed_out(now, "gems never landed, mine=" + str(gems)):
			quit(1); return true
		return false

	if phase == "loot_host":
		# The host loots the torches through the authority path.
		if role == "host" and not acted:
			acted = true
			cave.call("interact")
		if int(cave.call("chest_items")) == 0:
			print("CAVE_CHEST_EMPTY torches=", cave.call("my_torches"))
			# A second grab at an empty chest must be denied.
			if role == "guest":
				cave.call("interact")
			cave.call("walk_to", 560.0 if role == "guest" else 530.0, 150.0 if role == "guest" else 180.0)
			enter("door", now)
		elif timed_out(now, "chest never emptied, items=" + str(cave.call("chest_items"))):
			quit(1); return true
		return false

	if phase == "door":
		if not acted and int(cave.call("prompt_kind")) == 2:
			acted = true
			if role == "guest":
				cave.call("interact") # swing it open
		if bool(cave.call("door_open")):
			print("CAVE_DOOR_OPEN")
			# The guest spills its gems on the floor by the door.
			if role == "guest":
				cave.call("drop", 0)
			enter("drop", now)
		elif timed_out(now, "door never opened, prompt=" + str(cave.call("prompt_kind"))):
			quit(1); return true
		return false

	if phase == "drop":
		# A pickup materializes for BOTH peers; the host walks over to it
		# (guest stands at ~(560,150), so its drop lands at ~(584,150)).
		if int(cave.call("pickups")) == 1:
			print("CAVE_PICKUP n=1 gems=", cave.call("world_gems"))
			if role == "host":
				cave.call("walk_to", 584.0, 140.0)
			enter("grab", now)
		elif timed_out(now, "the drop never landed, pickups=" + str(cave.call("pickups"))):
			quit(1); return true
		return false

	if phase == "grab":
		if role == "host" and not acted and int(cave.call("prompt_kind")) == 3:
			acted = true
			cave.call("interact") # scoop it up (authority path)
		if int(cave.call("pickups")) == 0 and (role == "guest" or int(cave.call("my_gems")) == 3):
			print("CAVE_GRABBED my_gems=", cave.call("my_gems"))
			# The pre-combat loadout, read from the real inventory UI.
			print("CAVE_LOADOUT [", label_texts(), "]")
			# Phase 4: back apart — rock-throwing distance.
			cave.call("walk_to", 440.0 if role == "host" else 200.0, 180.0)
			enter("arm", now)
		elif timed_out(now, "grab never settled, pickups=" + str(cave.call("pickups"))):
			quit(1); return true
		return false

	if phase == "arm":
		var pos: Vector2 = cave.call("my_pos")
		var tx := 440.0 if role == "host" else 200.0
		if abs(pos.x - tx) < 4.0 and abs(pos.y - 180.0) < 4.0 and bool(cave.call("can_throw")):
			print("CAVE_ARMED")
			# The guest opens fire ON THE MOVE (see strafe).
			if role == "guest":
				cave.call("walk_to", 200.0, 110.0)
			enter("strafe", now)
		elif timed_out(now, "never in position, pos=" + str(pos)):
			quit(1); return true
		return false

	if phase == "strafe":
		# THE MOVING CAST: the guest shoots mid-stride, aimed at the host.
		# Its own screen is the truth for where the rock left from (position
		# is owner-streamed) — the cast carries that origin, so the host's
		# authoritative rock flies the SAME line the shooter saw. Without
		# that, the host launches from its lagged copy (~30px behind at this
		# latency) and the rock the guest watched connect sails wide.
		if role == "host":
			enter("fight", now)
			return false
		var pos: Vector2 = cave.call("my_pos")
		if pos.y <= 150.0 and bool(cave.call("can_throw")):
			var d: Vector2 = (Vector2(cave.call("their_pos")) - pos).normalized()
			cave.call("throw", d.x, d.y)
			print("CAVE_STRAFE_THROW y=", pos.y)
			enter("fight", now)
		elif timed_out(now, "never threw on the move, pos=" + str(pos)):
			quit(1); return true
		return false

	if phase == "fight":
		# One rock, one hit: 100 -> 65, seen from BOTH sides of the wire.
		var hp := int(cave.call("my_hp") if role == "host" else cave.call("their_hp"))
		if hp == 65:
			print("CAVE_HIT hp=65")
			enter("kill", now)
		elif timed_out(now, "the rock never landed, hp=" + str(hp)):
			quit(1); return true
		return false

	if phase == "kill":
		# The guest keeps throwing as the cooldown allows until the host
		# falls; the host's own process prints CAVE_DIED / CAVE_RESPAWNED.
		if role == "guest" and int(cave.call("their_hp")) > 0 and bool(cave.call("can_throw")):
			var d: Vector2 = (Vector2(cave.call("their_pos")) - Vector2(cave.call("my_pos"))).normalized()
			if d != Vector2.ZERO:
				cave.call("throw", d.x, d.y)
		var down := int(cave.call("my_hp") if role == "host" else cave.call("their_hp")) <= 0
		# Death spills the host's bag: gems + torches hit the floor.
		if down and int(cave.call("pickups")) >= 2:
			print("CAVE_SPILLED pickups=", cave.call("pickups"), " gems=", cave.call("world_gems"))
			enter("rise", now)
		elif timed_out(now, "the host never fell, their_hp=" + str(cave.call("their_hp"))):
			quit(1); return true
		return false

	if phase == "rise":
		if role == "host":
			if int(cave.call("my_hp")) == 100:
				print("CAVE_BACK hp=", cave.call("my_hp"))
				enter("score", now)
			elif timed_out(now, "never respawned, hp=" + str(cave.call("my_hp"))):
				quit(1); return true
		else:
			if int(cave.call("their_hp")) == 100:
				print("CAVE_BACK their_hp=100")
				enter("score", now)
			elif timed_out(now, "host never rose, their_hp=" + str(cave.call("their_hp"))):
				quit(1); return true
		return false

	if phase == "score":
		if not acted:
			acted = true
			cave.call("show_score", true)
		# Wait for a stat flush carrying the kill, then read the REAL board.
		var board := label_texts()
		if board.contains("| 1 | 0") and board.contains("| 0 | 1"):
			print("CAVE_SCORE [", board, "]")
			enter("hunt", now)
		elif timed_out(now, "the ledger never showed"):
			quit(1); return true
		return false

	if phase == "hunt":
		# Phase 5: the dwellers are out (the kit/ai director paced them in).
		# The host walks toward a den; the guest just watches the REPLICATED
		# brain: mood byte flips to chase, position streams the pursuit.
		if int(cave.call("dwellers")) >= 1:
			if not acted:
				acted = true
				print("CAVE_DWELLERS n=", cave.call("dwellers"))
				if role == "host":
					cave.call("walk_to", 320.0, 100.0)
			if int(cave.call("dweller_mood")) >= 1:
				print("CAVE_CHASE_SEEN pos=", cave.call("dweller_pos"))
				enter("bitten", now)
		if timed_out(now, "no dweller ever stirred, n=" + str(cave.call("dwellers"))):
			quit(1); return true
		return false

	if phase == "bitten":
		# It catches the host and bites; both peers see the hp drop. The
		# guest also confirms the pursuit MOVED on its screen (interp).
		var hurt := int(cave.call("my_hp") if role == "host" else cave.call("their_hp")) < 100
		if role == "guest" and not acted:
			acted = true
			set_meta("dw0", cave.call("dweller_pos"))
		if hurt:
			if role == "guest":
				var moved: Vector2 = cave.call("dweller_pos") - get_meta("dw0")
				print("CAVE_DWELLER_MOVED d=", moved.length())
			print("CAVE_BITTEN")
			enter("mend", now)
		elif timed_out(now, "never bitten"):
			quit(1); return true
		return false

	if phase == "mend":
		# The BANDAGE (ability slot 1): the bitten host heals through the
		# same predicted-command gate the rock uses. Only the HOST gates on
		# hp — its own screen is authoritative and instant. The guest just
		# settles: watching someone else's fluctuating hp for an exact
		# value is a phase-machine trap (the heal erases the hurt between
		# samples); the wire-side proof is run.sh's CAVE_HEAL grep.
		if role == "host":
			cave.call("heal")
			if int(cave.call("my_hp")) >= 95:
				print("CAVE_MENDED hp=", cave.call("my_hp"))
				enter("slay", now)
			elif timed_out(now, "the bandage never took, hp=" + str(cave.call("my_hp"))):
				quit(1); return true
		else:
			if now - t_acted > 2000:
				print("CAVE_MENDED their_hp=", cave.call("their_hp"))
				enter("slay", now)
		return false

	if phase == "slay":
		# Rocks answer teeth: both spelunkers shoot at the nearest dweller
		# (it flees when hurt — the rocks chase it down the same line).
		# Exit on the REPLICATED wave byte, not the entity count: counts
		# race the next wave's spawns; the byte is ordered with them.
		if int(cave.call("dwellers")) > 0 and bool(cave.call("can_throw")):
			var dir: Vector2 = cave.call("dweller_dir")
			if dir != Vector2.ZERO:
				cave.call("throw", dir.x, dir.y)
		if int(cave.call("wave")) >= 2:
			print("CAVE_WAVE_CLEARED")
			enter("wave2", now)
		elif timed_out(now, "wave 1 never cleared, dwellers=" + str(cave.call("dwellers"))):
			quit(1); return true
		return false

	if phase == "wave2":
		# The director's breather passes and the next wave crawls out —
		# visible on both peers as new dweller entities.
		if int(cave.call("dwellers")) > 0:
			print("CAVE_WAVE2 n=", cave.call("dwellers"))
			enter("wrap", now)
		elif timed_out(now, "wave 2 never came"):
			quit(1); return true
		return false

	if phase == "wrap":
		# Let the last deltas settle, then the final ledger + the real UI —
		# and the host etches the run to disk for act 2 (BEFORE the party
		# descends: act 2 resumes this floor).
		if now - t_acted > 800:
			print("CAVE_GEMS total=", cave.call("world_gems"))
			print("CAVE_FINAL [", label_texts(), "]")
			if role == "host":
				cave.call("save_run")
			enter("clearout", now)
		return false

	if phase == "clearout":
		# The cave only lets a CLEARED floor go: kill wave 2, bandaging
		# through the bites, before anyone can leave.
		cave.call("heal")
		if int(cave.call("dwellers")) > 0 and bool(cave.call("can_throw")):
			var dir: Vector2 = cave.call("dweller_dir")
			if dir != Vector2.ZERO:
				cave.call("throw", dir.x, dir.y)
		if int(cave.call("dwellers")) == 0 and int(cave.call("wave")) >= 2:
			print("CAVE_CLEARED_FLOOR")
			enter("descend", now)
		elif timed_out(now, "wave 2 never fell, dwellers=" + str(cave.call("dwellers"))):
			quit(1); return true
		return false

	if phase == "descend":
		# LEVEL MIGRATION: the floor is cleared. The guest first rescues
		# the loot the host's death spilled — the collapse eats anything
		# left lying on the floor; only BAGS cross floors — then the whole
		# party walks to the open door, and the host, seeing everyone
		# standing there alive, moves the run down a level.
		if role == "guest" and int(cave.call("my_gems")) < 3:
			if not acted:
				acted = true
				cave.call("walk_to", 464.0, 180.0)
			if int(cave.call("prompt_kind")) == 3:
				cave.call("interact")
			if timed_out(now, "never rescued the spilled gems"):
				quit(1); return true
			return false
		if not get_meta("to_door", false):
			set_meta("to_door", true)
			cave.call("walk_to", 560.0, 180.0)
		cave.call("heal")
		if int(cave.call("depth")) >= 2:
			enter("floor2", now)
		elif timed_out(now, "the party never descended, depth=" + str(cave.call("depth"))):
			quit(1); return true
		return false

	if phase == "floor2":
		# The new floor arrived over the wire: closed door, restocked chest,
		# a cleared field — and the bag walked down the stairs intact.
		if now - t_acted > 600:
			print("CAVE_DESCENDED depth=", cave.call("depth"), " door=", cave.call("door_open"),
				" dwellers=", cave.call("dwellers"), " chest=", cave.call("chest_items"),
				" gems_bag=", cave.call("my_gems"), " pos=", cave.call("my_pos"))
			if role == "guest":
				# The guest just LEAVES (process exit, no goodbye) — the
				# host must notice through the transport's disconnect
				# signal, not a polite message.
				print(role.to_upper(), "_DONE")
				quit(0); return true
			enter("alone", now)
		return false

	if phase == "alone":
		# DISCONNECT DETECTION: the guest's process died without a goodbye.
		# The peer_disconnected signal -> session_peer_disconnected marks the
		# roster; without that wiring this phase hangs forever on a ghost.
		if int(cave.call("get_players")) == 1:
			print("CAVE_ALONE players=1")
			print(role.to_upper(), "_DONE")
			quit(0); return true
		elif timed_out(now, "never noticed the guest leave"):
			quit(1); return true
		return false

	return false
