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
			enter("wrap", now)
		elif timed_out(now, "grab never settled, pickups=" + str(cave.call("pickups"))):
			quit(1); return true
		return false

	if phase == "wrap":
		# Let the last deltas settle, then the final ledger + the real UI.
		if now - t_acted > 800:
			print("CAVE_GEMS total=", cave.call("world_gems"))
			print("CAVE_FINAL [", label_texts(), "]")
			print(role.to_upper(), "_DONE")
			quit(0); return true
		return false

	return false
