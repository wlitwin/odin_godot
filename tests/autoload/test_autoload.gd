extends SceneTree

# ----------------------------------------------------------------------------
# Headless E2E for Odin-script AUTOLOAD singletons + the ProjectSettings/InputMap
# ergonomic helpers.
#
# `project.godot` configures:
#     [autoload]
#     GameManager="*res://scripts/game_manager.odin"
#
# The leading `*` makes Godot instantiate the script's base node (//gd:extends Node),
# attach the Odin script, run `_ready`, and add it under /root as `GameManager`. This
# driver asserts the GDScript-parity contract entirely through that live autoload node:
#   1. /root/GameManager exists and is a Node.
#   2. _ready actually ran (its sentinel write to `count` is visible).
#   3. a method call (bump) mutates state and reads back (get_count).
#   4. it is the SAME instance across a frame (object id stable, state persists).
#   5. ProjectSettings ergonomics: a setting set from Odin _ready is visible to GDScript,
#      a setting set from GDScript is read back through gd.get_setting_int, and the typed
#      float/bool/string/has_setting helpers round-trip (Odin-side selftest).
#   6. InputMap ergonomics: the action the autoload registered in _ready is visible to
#      InputMap.has_action AND drivable via Input.action_press + Input.is_action_pressed.
#
# Prints AUTOLOAD_OK on success, or AUTOLOAD_FAIL: <what>.
# ----------------------------------------------------------------------------

var done := false

func _init() -> void:
	# Run after one frame so autoloads have been added to /root and their _ready has run.
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("AUTOLOAD_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return

	# ===== 1. /root/GameManager exists (the autoload node) =====
	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		_fail("/root/GameManager not found (Odin autoload was not instantiated)"); return
	if not (gm is Node):
		_fail("/root/GameManager is not a Node"); return
	if gm.get_script() == null or gm.get_script().get_instance_base_type() != "Node":
		_fail("GameManager base type != Node (got %s)" % str(gm.get_script().get_instance_base_type() if gm.get_script() else "<no script>")); return

	# ===== 2. _ready ran (sentinel write visible) =====
	var c0 = gm.call("get_count")
	if int(c0) != 1000:
		_fail("_ready did not run: get_count=%s expected 1000 (READY_SENTINEL)" % str(c0)); return

	# ===== 3. a method call mutates state and reads back =====
	gm.call("bump", 5)
	var c1 = gm.call("get_count")
	if int(c1) != 1005:
		_fail("bump(5) did not mutate: get_count=%s expected 1005" % str(c1)); return

	# ===== 4. SAME instance across a frame =====
	var id_before := gm.get_instance_id()
	await process_frame
	var gm2 = root.get_node_or_null("GameManager")
	if gm2 == null or gm2.get_instance_id() != id_before:
		_fail("autoload is not the same instance across a frame (id changed)"); return
	if int(gm2.call("get_count")) != 1005:
		_fail("autoload state did not persist across a frame: get_count=%s expected 1005" % str(gm2.call("get_count"))); return

	# ===== 5. ProjectSettings ergonomics =====
	# 5a. setting written from Odin _ready is visible to GDScript (GDScript parity).
	if not ProjectSettings.has_setting("odin/autoload_marker"):
		_fail("project setting 'odin/autoload_marker' set from Odin _ready not visible to GDScript"); return
	if int(ProjectSettings.get_setting("odin/autoload_marker")) != 7:
		_fail("odin/autoload_marker = %s, expected 7 (gd.set_setting_int)" % str(ProjectSettings.get_setting("odin/autoload_marker"))); return
	# 5b. Odin gd.get_setting_int reads the same value back.
	if int(gm.call("read_marker")) != 7:
		_fail("gd.get_setting_int('odin/autoload_marker') via Odin returned %s, expected 7" % str(gm.call("read_marker"))); return
	# 5c. a value set from GDScript is read back THROUGH gd.get_setting_int.
	ProjectSettings.set_setting("odin/autoload_marker", 42)
	if int(gm.call("read_marker")) != 42:
		_fail("gd.get_setting_int did not see GDScript-set value: got %s expected 42" % str(gm.call("read_marker"))); return
	# 5d. typed float/bool/string/has_setting helpers round-trip (Odin-side).
	if int(gm.call("settings_selftest")) != 1:
		_fail("ProjectSettings typed-helper selftest (float/bool/string/has) failed in Odin"); return

	# ===== 6. InputMap ergonomics =====
	# The autoload registered "odin_fire" + a Space key binding in its Odin _ready.
	if not InputMap.has_action("odin_fire"):
		_fail("InputMap.has_action('odin_fire') false — gd.add_action from Odin _ready not visible"); return
	var events := InputMap.action_get_events("odin_fire")
	if events.is_empty():
		_fail("odin_fire has no events — gd.action_add_key/mouse_button did not register"); return
	# Drive it: pressing the action must be observed by Input.is_action_pressed.
	Input.action_press("odin_fire")
	if not Input.is_action_pressed("odin_fire"):
		_fail("Input.is_action_pressed('odin_fire') false after action_press"); return
	Input.action_release("odin_fire")

	print("AUTOLOAD: /root/GameManager ready (count 1000->1005); same instance; settings + input registered from Odin")
	print("AUTOLOAD_OK")
	done = true
	quit(0)
