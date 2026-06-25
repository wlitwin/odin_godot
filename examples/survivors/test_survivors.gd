extends SceneTree

# ----------------------------------------------------------------------------
# Headless end-to-end for "Odin Survivors" — the FULL survivors loop, proven through the REAL
# game (game.tscn is pure data: every node carries a `.odin` script, zero GDScript gameplay
# glue). Each link is driven through actual physics overlaps + frame stepping (never faked
# emit_signal for the gameplay path) and asserted on observable engine state:
#
#   1. input -> movement              : Input.action_press walks the Odin _process.
#   2. weapon present                 : the player auto-equips a Weapon child (auto-attack).
#   3. bullet -> enemy kill           : a real bullet overlap -> typed take_damage -> the enemy
#                                       dies -> a KILL is counted AND an XP gem appears.
#   4. gem -> XP                      : the player overlaps the gem -> game_state XP increases.
#   5. level-up                       : enough XP -> leveled_up fires -> the menu is VISIBLE and
#                                       the tree is PAUSED (Game enters the LevelUp state).
#   6. choose upgrade                 : invoking a menu button handler (as a click would) APPLIES
#                                       the upgrade (an observable player stat / weapon changes)
#                                       and RESUMES (unpaused, Playing).
#   7. difficulty scales              : the spawn interval shrinks as run-time grows.
#   8. death -> game over             : a real contact hit drops HP to 0 -> died -> GameOver
#                                       state + the game-over screen shows.
#   9. restart                        : the restart handler reloads + resets to a fresh run.
#
# Prints SURVIVORS_OK + the milestone list on success, or SURVIVORS_FAIL: <reason>.
# ----------------------------------------------------------------------------

var done := false
var hp_events: Array = []

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("SURVIVORS_FAIL: ", reason)
	quit(1)

func _on_health_changed(value: int) -> void:
	hp_events.append(value)

# Count the player's Weapon child nodes (a Weapon's native base class is Node2D).
func _weapon_count(player) -> int:
	var n := 0
	for c in player.get_children():
		if c.get_class() == "Node2D":
			n += 1
	return n

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://game.tscn"):
		_fail("res://game.tscn not found"); return
	var scene = load("res://game.tscn").instantiate()
	if scene == null:
		_fail("failed to instantiate game.tscn"); return
	root.add_child(scene)
	current_scene = scene  # so reload_current_scene works in the restart milestone

	var game = scene  # the root carries the Game script
	var player = scene.get_node_or_null("Player")
	var spawner = scene.get_node_or_null("Spawner")
	var hud = scene.get_node_or_null("Hud")
	var levelup = scene.get_node_or_null("LevelUpMenu")
	var gameover = scene.get_node_or_null("GameOver")
	if player == null or spawner == null or hud == null or levelup == null or gameover == null:
		_fail("a game node is missing (Player/Spawner/Hud/LevelUpMenu/GameOver)"); return

	# Let every _ready run (groups join, signals wire, the starting weapon spawns).
	await process_frame
	await process_frame

	var milestones: Array = []

	# ===== base types from //gd:extends =====
	if player.get_script().get_instance_base_type() != "CharacterBody2D":
		_fail("Player base = %s" % player.get_script().get_instance_base_type()); return
	if hud.get_script().get_instance_base_type() != "CanvasLayer":
		_fail("Hud base = %s" % hud.get_script().get_instance_base_type()); return
	milestones.append("base-types")

	# ===== (2) the player auto-equips a weapon (auto-attack system) =====
	var w0 := _weapon_count(player)
	if w0 < 1:
		_fail("player has no Weapon child (starting weapon not equipped): %d" % w0); return
	milestones.append("weapon-equipped(%d)" % w0)

	# Stop the spawner so the only enemies are the ones we place (deterministic).
	spawner.set_process(false)

	# ===== (1) input drives the Odin _process =====
	var x0: float = player.position.x
	Input.action_press("ui_right")
	for _i in range(15):
		await process_frame
	Input.action_release("ui_right")
	if player.position.x <= x0 + 1.0:
		_fail("player did not move on ui_right: x0=%.1f x1=%.1f" % [x0, player.position.x]); return
	milestones.append("input-move(%.0f->%.0f)" % [x0, player.position.x])

	# ===== (3) bullet -> enemy: typed damage, death, kill counted, gem dropped =====
	var kills_before: int = game.call("get_kills")
	var enemy_scene: PackedScene = load("res://enemy.tscn")
	var bullet_scene: PackedScene = load("res://bullet.tscn")
	if enemy_scene == null or bullet_scene == null:
		_fail("enemy.tscn / bullet.tscn failed to load"); return

	# Place the target FAR from the player so the player's own pistol (range 240) can't reach
	# it — the kill we assert is the one our test bullet drives.
	player.set_process(false)
	var target = enemy_scene.instantiate()
	scene.add_child(target)
	target.global_position = Vector2(610, 40)
	target.set_physics_process(false)

	var bullet = bullet_scene.instantiate()
	scene.add_child(bullet)
	bullet.global_position = Vector2(610, 40)  # overlapping the enemy
	bullet.set("damage", 50)                   # one-shot
	bullet.set_physics_process(false)          # hold still so the overlap resolves

	var killed := false
	for _i in range(30):
		await physics_frame
		if not is_instance_valid(target):
			killed = true
			break
	if not killed:
		_fail("bullet did not kill the enemy via area_entered overlap"); return
	if game.call("get_kills") != kills_before + 1:
		_fail("kill not counted: before=%d after=%d" % [kills_before, game.call("get_kills")]); return

	# the dead enemy should have dropped an XP gem (joins the "gems" group)
	await physics_frame
	var gems := get_nodes_in_group("gems")
	if gems.size() < 1:
		_fail("no XP gem dropped on enemy death"); return
	milestones.append("kill+gem(kills=%d,gems=%d)" % [game.call("get_kills"), gems.size()])

	# ===== (4) gem -> XP: the player overlaps a gem and XP increases =====
	var xp_before: int = game.call("get_xp")
	var gem = gems[0]
	player.global_position = gem.global_position  # walk onto the gem
	var got_xp := false
	for _i in range(30):
		await physics_frame
		if game.call("get_xp") > xp_before or game.call("get_level") > 1:
			got_xp = true
			break
	if not got_xp:
		_fail("collecting a gem did not raise XP (before=%d now=%d)" % [xp_before, game.call("get_xp")]); return
	milestones.append("gem-xp(%d->%d)" % [xp_before, game.call("get_xp")])

	# ===== (5) level-up: force enough XP through the real path -> menu + pause =====
	var level_before: int = game.call("get_level")
	var big_gem = load("res://xp_gem.tscn").instantiate()
	big_gem.set("value", 50)               # plenty to cross a level boundary
	scene.add_child(big_gem)
	big_gem.global_position = player.global_position
	var leveled := false
	for _i in range(30):
		await physics_frame
		await process_frame
		if game.call("get_level") > level_before and bool(levelup.visible):
			leveled = true
			break
	if not leveled:
		_fail("level-up did not open the menu (level %d->%d, menu visible=%s)"
			% [level_before, game.call("get_level"), str(levelup.visible)]); return
	if not get_root().get_tree().paused:
		_fail("tree is not paused while the level-up menu is open"); return
	if int(game.call("get_state")) != 1:
		_fail("game state is not LevelUp(1): %d" % int(game.call("get_state"))); return
	milestones.append("levelup(menu-visible+paused, lv%d)" % game.call("get_level"))

	# ===== (6) choose an upgrade: invoke a button handler -> apply + resume =====
	var snap := {
		"move_speed": player.get("move_speed"),
		"max_health": player.get("max_health"),
		"pickup_range": player.get("pickup_range"),
		"damage_mult": player.get("damage_mult"),
		"fire_rate_mult": player.get("fire_rate_mult"),
		"projectile_count": player.get("projectile_count"),
		"pierce_bonus": player.get("pierce_bonus"),
	}
	var wc_before := _weapon_count(player)
	# Invoke the first choice's handler exactly the way a click would (the Button's `pressed`
	# is connected to this @(gd_method) in the menu's _ready). A big gem can fund several
	# levels at once, so keep choosing until every owed menu is settled and the run resumes.
	levelup.call("pick0")
	await process_frame
	await process_frame
	var guard := 0
	while bool(levelup.visible) and get_root().get_tree().paused and guard < 16:
		levelup.call("pick0")
		await process_frame
		await process_frame
		guard += 1

	var changed := ""
	for k in snap.keys():
		if float(player.get(k)) > float(snap[k]):
			changed = "%s %s->%s" % [k, str(snap[k]), str(player.get(k))]
			break
	if changed == "" and _weapon_count(player) > wc_before:
		changed = "weapons %d->%d" % [wc_before, _weapon_count(player)]
	if changed == "":
		_fail("picking an upgrade applied no observable change"); return
	# all owed level-ups consumed -> the run resumes
	if get_root().get_tree().paused:
		_fail("tree still paused after the upgrade was chosen"); return
	if bool(levelup.visible):
		_fail("level-up menu still visible after choosing"); return
	if int(game.call("get_state")) != 0:
		_fail("game did not resume to Playing(0): %d" % int(game.call("get_state"))); return
	milestones.append("upgrade-applied(%s)+resumed" % changed)

	# ===== (7) difficulty scales with run-time =====
	var i_early: float = spawner.call("interval_at", 0.0)
	var i_late: float = spawner.call("interval_at", 120.0)
	if not (i_late < i_early):
		_fail("spawn interval did not shrink over time: t0=%.2f t120=%.2f" % [i_early, i_late]); return
	milestones.append("difficulty(interval %.2f->%.2f)" % [i_early, i_late])

	# ===== (8) death by contact -> game over =====
	player.connect("health_changed", _on_health_changed)
	# A real enemy contact, but with a lethal one-hit config so a single body_entered ends it.
	var lethal = load("res://config/grunt.tres").duplicate()
	lethal.set("damage", 9999)
	lethal.set("hp", 9999)  # so the player's weapon can't kill it before it touches us
	var attacker = enemy_scene.instantiate()
	attacker.set("config", lethal)   # set BEFORE add_child so _ready reads it
	scene.add_child(attacker)
	attacker.global_position = player.global_position
	attacker.set_physics_process(false)

	var dead := false
	for _i in range(40):
		await physics_frame
		await process_frame
		if int(game.call("get_state")) == 2:
			dead = true
			break
	if not dead:
		_fail("contact damage did not end the run (state=%d hp_events=%s)"
			% [int(game.call("get_state")), str(hp_events)]); return
	if hp_events.size() == 0:
		_fail("no health_changed fired during the lethal contact"); return
	if not bool(gameover.visible):
		_fail("game-over screen not shown on death"); return
	milestones.append("game-over(state=2, screen shown)")

	# ===== (9) restart -> reload + reset to a fresh run =====
	gameover.call("on_restart")
	var restarted := false
	for _i in range(30):
		await process_frame
		var g2 = current_scene
		if g2 != null and is_instance_valid(g2) and g2.has_method("get_level"):
			if int(g2.call("get_level")) == 1 and int(g2.call("get_state")) == 0 and int(g2.call("get_kills")) == 0:
				restarted = true
				break
	if not restarted:
		_fail("restart did not reload to a fresh run (level/state/kills not reset)"); return
	milestones.append("restart(fresh run)")

	print("SURVIVORS milestones: ", ", ".join(milestones))
	print("SURVIVORS_OK")
	done = true
	quit(0)
