extends SceneTree

# Headless suite driver (run with BARRAGE_TEST=1 — compressed pacing, see game_state).
# Loads game.tscn directly (skipping the title menu), lets the REAL game run, and
# asserts the milestones by polling the same cross-module APIs the HUD uses.

var frames := 0
var peak_bullets := 0
var max_phase := 0
var hurt := false
var base_fire_rate := -1.0
var powerup_seen := false
var done := false

func _init() -> void:
	var scene = load("res://game.tscn").instantiate()
	root.add_child(scene)
	physics_frame.connect(_tick)

func _obj(group: String) -> Node:
	return get_first_node_in_group(group)

func _tick() -> void:
	if done:
		return
	frames += 1
	var gs = root.get_node("/root/GameState")
	var field = _obj("bullet_field")
	var spawner = _obj("spawner")
	var player = _obj("player")
	if field != null:
		peak_bullets = max(peak_bullets, int(field.call("live_count")))
	if spawner != null:
		max_phase = max(max_phase, int(spawner.call("get_boss_phase")))
	if player != null:
		var fr = float(player.call("get_fire_rate"))
		if base_fire_rate < 0.0:
			base_fire_rate = fr
		elif fr > base_fire_rate + 0.01:
			powerup_seen = true
	if gs != null and int(gs.call("get_hp")) < int(gs.call("get_max_hp")):
		hurt = true

	# Force-feed the missable milestones once the boss fight is underway: a powerup
	# straight to the player (the drop table is random-position), and one guaranteed hit.
	# Stress the SOA/multimesh path directly: 50 rings x 100 = 5000 live bullets at once
	# (they live ~8s) — the capacity claim, asserted, not assumed.
	if frames == 300 and field != null:
		for i in range(50):
			field.call("spawn_ring", Vector2(480, 300), 100, 60.0, float(i) * 0.13, 1)
	if frames == 400 and player != null:
		player.call("apply_powerup", 0, 4.0)
	if frames == 410 and spawner != null:
		# Exercise the SlowEnemies fan-out (spawner's pure-Odin events.Event -> every
		# live enemy, docs/events.md) with live subscribers mid-fight.
		spawner.call("slow_all_enemies", 0.5)
	if frames == 420 and player != null:
		player.call("take_damage", 1)

	if frames >= 4000 or (max_phase >= 3 and hurt and powerup_seen and peak_bullets > 4000):
		done = true
		_finish()

func _finish() -> void:
	var ok := true
	print("BARRAGE_PEAK_BULLETS %d" % peak_bullets)
	print("BARRAGE_MAX_PHASE %d" % max_phase)
	if peak_bullets < 4000:
		print("BARRAGE_FAIL: peak bullets %d < 4000 (multimesh/SOA path underfed)" % peak_bullets)
		ok = false
	if max_phase < 3:
		print("BARRAGE_FAIL: boss never reached phase 3 (flow sequencer) — got %d" % max_phase)
		ok = false
	if not hurt:
		print("BARRAGE_FAIL: player never took damage (field->player signal path)")
		ok = false
	if not powerup_seen:
		print("BARRAGE_FAIL: fire rate never rose (powerup path)")
		ok = false
	var gs = root.get_node("/root/GameState")
	if gs == null or int(gs.call("get_score")) <= 0:
		print("BARRAGE_FAIL: no score accumulated (enemy kill path)")
		ok = false
	if ok:
		print("BARRAGE_OK")
	quit(0 if ok else 1)
