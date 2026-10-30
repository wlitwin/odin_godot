extends SceneTree

var game: Node
var member := 0
var phase := "join"
var started := 0
var directory := ""
var mode := ""
var accepted_before := 0
var fenced_tick := -1
var durable_after := -1
var original_seat := -1

func _initialize() -> void:
	member = int(OS.get_environment("REPLAY_CAVE_MEMBER"))
	directory = OS.get_environment("REPLAY_MIGRATION_DIR")
	mode = OS.get_environment("REPLAY_MIGRATION_MODE")
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()
	if OS.get_environment("REPLAY_MIGRATION_RETURNED") == "1": phase = "return_join"

func signal_file(name: String) -> void:
	var file := FileAccess.open(directory + "/" + name, FileAccess.WRITE)
	file.store_string("ready")
	file.close()

func fail(message: String) -> bool:
	print("REPLAY_MIGRATION_FAIL member=", member, " phase=", phase, " ", message)
	print("REPLAY_MIGRATION_DIAGNOSTIC head=", game.probe_head(), " backup=", game.probe_backup_tick(), " prepared=", game.probe_prepared_tick(),
		" recovered=", game.probe_recovery_tick(), " seat=", game.probe_seat(), " original_seat=", original_seat,
		" bag=", game.probe_bag(), " chest=", game.probe_chest(0), " gems=", game.probe_gems())
	quit(1)
	return true

func _process(_dt: float) -> bool:
	if Time.get_ticks_msec() - started > 38000: return fail("timeout room_phase=%d epoch=%d" % [game.probe_room_phase(), game.probe_epoch()])
	match phase:
		"join":
			if game.probe_steady() and game.probe_players() == 3:
				original_seat = game.probe_seat()
				if member == 3: game.walk_to(300.0, 180.0)
				phase = "chest" if member == 3 else "loot"
		"chest":
			if game.probe_near(300.0, 180.0):
				game.loot(0)
				phase = "loot"
		"loot":
			if not game.probe_steady(): return false
			if game.probe_chest(0) == 0 and (member != 3 or game.probe_bag() == 3):
				if game.probe_gems() != 3: return fail("loot conservation")
				if member == 3: game.walk_to(560.0, 180.0)
				phase = "door" if member == 3 else "handoff"
		"door":
			if game.probe_near(560.0, 180.0):
				game.door()
				phase = "handoff"
		"handoff":
			if not game.probe_steady(): return false
			if member == 1:
				if game.probe_door() and game.probe_backup_sequence() >= 2:
					if not FileAccess.file_exists(directory + "/guest_ready"): return false
					# Conservation after crash is asserted only for gameplay inside
					# both the acknowledged and coordinator-authorized save frontier.
					if durable_after < 0: durable_after = game.probe_head()
					if game.probe_backup_tick() < durable_after or game.probe_prepared_tick() < durable_after: return false
					print("REPLAY_MIGRATION_DURABLE_TRIGGER gameplay=", durable_after, " backup=", game.probe_backup_tick(), " prepared=", game.probe_prepared_tick())
					if mode == "planned" or mode == "repeat" or mode == "successor_loss":
						if not game.handoff(): return fail("handoff request")
					elif mode == "partition": game.pause_control(true)
					else: signal_file("kill_owner")
					phase = "loss_freeze" if mode == "successor_loss" else "partition_wait" if mode == "partition" else "migrating"
			elif member == 3 and game.probe_door():
				signal_file("guest_ready")
				phase = "migrating"
			elif member == 2 and game.probe_door():
				phase = "migrating"
		"migrating":
			if game.probe_epoch() == 2 and game.probe_steady():
				if game.probe_recovery_kind() != (1 if mode == "planned" or mode == "repeat" else 2): return fail("unexpected recovery policy")
				if game.probe_gems() != 3: return fail("recovered conservation")
				if member == 3:
					if game.probe_bag() != 3: return fail("stable guest inventory")
					game.walk_to(560.0, 180.0)
					phase = "resume_door"
				else:
					if mode == "partition" and member == 1: signal_file("owner_rejoined")
					phase = "continued"
		"resume_door":
			if game.probe_near(560.0, 180.0):
				# A crash may recover before the door opened; make a fresh action in
				# the new epoch and check its acknowledgement, not an old sequence.
				accepted_before = game.probe_accepted()
				game.door()
				phase = "guest_action"
		"guest_action":
			if game.probe_accepted() > accepted_before:
				if game.probe_gems() != 3 or game.probe_bag() != 3: return fail("continued inventory")
				if (mode == "return" or mode == "repeat") and game.probe_epoch() == 2:
					game.walk_to(560.0, 40.0)
					signal_file("guest_after_migration")
					phase = "wait_return" if mode == "return" else "migrating2"
					return false
				if mode == "partition":
					game.walk_to(560.0, 40.0)
					signal_file("unpause_owner")
					phase = "wait_partition"
					return false
				signal_file("guest_done")
				print("REPLAY_MIGRATION_GUEST_OK epoch=", game.probe_epoch(), " migrations=", game.probe_migrations(),
					" checkpoint=", game.probe_recovery_tick(), " known_lost=", game.probe_lost_ticks(), " interruption_ms=", game.probe_interruption())
				quit(0)
				return true
		"continued":
			if mode == "repeat" and member == 2 and game.probe_epoch() == 2:
				if FileAccess.file_exists(directory + "/guest_after_migration") and game.probe_backup_sequence() >= 2:
					if not game.handoff(): return fail("second handoff")
					phase = "migrating2"
			elif mode == "repeat" and game.probe_epoch() == 3:
				phase = "continued3"
			if FileAccess.file_exists(directory + "/guest_done"):
				if game.probe_gems() != 3: return fail("host continued inventory")
				print("REPLAY_MIGRATION_MEMBER_OK member=", member, " epoch=", game.probe_epoch())
				quit(0)
				return true
		"migrating2":
			if game.probe_epoch() == 3 and game.probe_steady():
				if game.probe_gems() != 3 or game.probe_migrations() != 2: return fail("second recovery state")
				if member == 3:
					game.walk_to(560.0, 180.0)
					phase = "resume_door"
				else: phase = "continued3"
		"continued3":
			if FileAccess.file_exists(directory + "/guest_done"):
				print("REPLAY_MIGRATION_MEMBER_OK member=", member, " epoch=", game.probe_epoch())
				quit(0)
				return true
		"return_join":
			if game.probe_epoch() == 2 and game.probe_steady() and game.probe_players() == 3:
				if game.probe_incarnation() <= 102 or game.probe_seat() != 1: return fail("fresh incarnation / stable seat")
				game.walk_to(300.0, 180.0)
				phase = "return_walk"
		"return_walk":
			if game.probe_near(300.0, 180.0):
				game.loot(1)
				phase = "return_action"
		"return_action":
			if game.probe_chest(1) == 0 and game.probe_accepted() > 0:
				if game.probe_gems() != 3: return fail("returning host conservation")
				signal_file("returned_done")
				print("REPLAY_MIGRATION_RETURNED_OK incarnation=", game.probe_incarnation(), " seat=", game.probe_seat())
				quit(0)
				return true
		"wait_return":
			if FileAccess.file_exists(directory + "/returned_done"):
				if game.probe_gems() != 3 or game.probe_bag() != 3: return fail("return scenario conservation")
				signal_file("guest_done")
				print("REPLAY_MIGRATION_GUEST_OK epoch=", game.probe_epoch(), " migrations=", game.probe_migrations())
				quit(0)
				return true
		"partition_wait":
			if game.probe_fenced():
				if fenced_tick < 0: fenced_tick = game.probe_head()
				if game.probe_head() != fenced_tick: return fail("isolated owner advanced after lease expiry")
			if FileAccess.file_exists(directory + "/unpause_owner"):
				if fenced_tick < 0: return fail("partition did not fence old owner")
				game.pause_control(false)
				phase = "migrating"
		"wait_partition":
			if FileAccess.file_exists(directory + "/owner_rejoined"):
				if game.probe_gems() != 3 or game.probe_bag() != 3: return fail("partition recovery inventory")
				signal_file("guest_done")
				print("REPLAY_MIGRATION_GUEST_OK partition epoch=", game.probe_epoch())
				quit(0)
				return true
		"loss_freeze":
			if game.probe_room_phase() == 3 or game.probe_room_phase() == 4:
				signal_file("kill_successor")
				phase = "migrating"
	return false
