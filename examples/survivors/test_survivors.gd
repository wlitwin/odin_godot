extends SceneTree

# ----------------------------------------------------------------------------
# Headless end-to-end for "Odin Survivors". game.tscn is pure data — every node carries a
# `.odin` script and there is NO GDScript gameplay glue. This driver loads it and exercises
# the REAL game loop through actual physics overlaps (never emit_signal fakery):
#
#   (a) INPUT -> MOVEMENT      : Input.action_press("ui_right") makes the Odin _process walk
#                                the player to the right.
#   (b) BULLET -> ENEMY        : a bullet placed overlapping an enemy, stepped through PHYSICS,
#                                fires area_entered -> the bullet calls the enemy's take_damage
#                                TYPED -> the enemy dies -> game_state score increments -> the
#                                HUD's text updates. (Player + Spawner are paused so the only
#                                kill is the one we drive.)
#   (c) ENEMY -> PLAYER        : an enemy placed on the player, stepped through PHYSICS, fires
#                                body_entered -> the enemy calls the player's take_damage TYPED
#                                -> the player emits health_changed -> the HUD shows the new HP.
#
# Prints SURVIVORS_OK on success, or SURVIVORS_FAIL: <reason>.
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

# Parse the integer after "Score: " in the HUD's (possibly multi-line) text.
func _hud_score(hud) -> int:
	for line in String(hud.text).split("\n"):
		if line.begins_with("Score: "):
			return int(line.substr(7))
	return -999

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://game.tscn"):
		_fail("res://game.tscn not found"); return
	var scene = load("res://game.tscn").instantiate()
	if scene == null:
		_fail("failed to instantiate game.tscn"); return
	root.add_child(scene)

	var player = scene.get_node_or_null("Player")
	var spawner = scene.get_node_or_null("Spawner")
	var hud = scene.get_node_or_null("Hud")
	var brute = scene.get_node_or_null("Brute")
	if player == null or spawner == null or hud == null or brute == null:
		_fail("a game node is missing (Player/Spawner/Hud/Brute)"); return

	# Let every _ready run (player joins "player" group; HUD connects to health_changed).
	await process_frame
	await process_frame

	# ===== base types from //gd:extends =====
	if player.get_script().get_instance_base_type() != "CharacterBody2D":
		_fail("Player base = %s" % player.get_script().get_instance_base_type()); return
	if brute.get_script().get_instance_base_type() != "Area2D":
		_fail("Enemy base = %s" % brute.get_script().get_instance_base_type()); return
	if hud.get_script().get_instance_base_type() != "Label":
		_fail("Hud base = %s" % hud.get_script().get_instance_base_type()); return

	# ===== @export values round-tripped from the scene =====
	if float(player.get("speed")) <= 0.0:
		_fail("player.speed export bad: %s" % str(player.get("speed"))); return
	if int(player.get("max_health")) != 100:
		_fail("player.max_health export bad: %s" % str(player.get("max_health"))); return

	# ===== (a) input drives the Odin _process =====
	var x0: float = player.position.x
	Input.action_press("ui_right")
	for _i in range(15):
		await process_frame
	Input.action_release("ui_right")
	if player.position.x <= x0 + 1.0:
		_fail("player did not move on ui_right: x0=%.1f x1=%.1f" % [x0, player.position.x]); return

	# Pause the autonomous actors so (b) is deterministic: no auto-fire, no auto-spawns.
	player.set_process(false)
	spawner.set_process(false)
	brute.set_physics_process(false) # the placed brute stops chasing; it just sits there

	# ===== (b) bullet -> enemy: typed damage, death, score, HUD =====
	var score_before := _hud_score(hud)
	if score_before < 0:
		_fail("could not parse HUD score: '%s'" % str(hud.text)); return

	var enemy_scene: PackedScene = load("res://enemy.tscn")
	var bullet_scene: PackedScene = load("res://bullet.tscn")
	if enemy_scene == null or bullet_scene == null:
		_fail("enemy.tscn / bullet.tscn failed to load"); return

	var target = enemy_scene.instantiate()
	scene.add_child(target)
	target.global_position = Vector2(520, 300)
	target.set_physics_process(false) # hold still so the bullet's overlap is clean

	var bullet = bullet_scene.instantiate()
	scene.add_child(bullet)
	bullet.global_position = Vector2(520, 300) # overlapping the enemy
	bullet.set("damage", 5)                    # one-shot the grunt (hp 3)
	bullet.set_physics_process(false)          # don't fly off before the overlap resolves

	var killed := false
	for _i in range(30):
		await physics_frame
		if not is_instance_valid(target):
			killed = true
			break
	if not killed:
		_fail("bullet did not kill the enemy via area_entered overlap"); return
	if is_instance_valid(bullet):
		_fail("bullet still alive after hitting the enemy (should queue_free)"); return

	await process_frame # let the HUD's _process pick up the new score
	var score_after := _hud_score(hud)
	if score_after != score_before + 1:
		_fail("score did not increment by the grunt's points: before=%d after=%d" % [score_before, score_after]); return

	# ===== (c) enemy -> player: contact damage, health_changed, HUD =====
	player.connect("health_changed", _on_health_changed)
	var attacker = enemy_scene.instantiate()
	scene.add_child(attacker)
	attacker.global_position = player.global_position # right on top of the player
	attacker.set_physics_process(false)               # one clean body_entered, no re-enter

	var hit := false
	for _i in range(30):
		await physics_frame
		if hp_events.size() > 0:
			hit = true
			break
	if not hit:
		_fail("enemy contact did not trigger player.take_damage / health_changed"); return

	var new_hp: int = hp_events[hp_events.size() - 1]
	if new_hp >= 100 or new_hp <= 0:
		_fail("health_changed payload out of range: %d" % new_hp); return

	# The HUD updates HP from its signal handler, then repaints on its next _process — poll a
	# few frames for the text to reflect the new HP.
	var hud_updated := false
	for _i in range(10):
		await process_frame
		if String(hud.text).contains("HP: %d" % new_hp):
			hud_updated = true
			break
	if not hud_updated:
		_fail("HUD did not show new HP: text='%s' expected HP %d" % [str(hud.text), new_hp]); return

	print("SURVIVORS: moved x %.1f->%.1f; bullet killed grunt (score %d->%d); contact HP 100->%d; HUD='%s'"
		% [x0, player.position.x, score_before, score_after, new_hp, String(hud.text).replace("\n", " | ")])
	print("SURVIVORS_OK")
	done = true
	quit(0)
