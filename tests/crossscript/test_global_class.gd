extends SceneTree

# ----------------------------------------------------------------------------
# Global class_name registration check (editor context). Proves an Odin `//gd:class <Name>`
# is exposed as a GLOBAL CLASS name:
#
#   1. DIRECT (synchronous, gating): Script.get_global_name() -> "<Name>". This is the
#      exact ScriptExtension._get_global_name virtual the editor's global-class scan reads.
#   2. REGISTRATION (best-effort, reported): after the editor filesystem scan (run.sh boots
#      the editor before this), ProjectSettings.get_global_class_list() lists the class —
#      i.e. the engine registered <Name> as a usable TYPE. Reported, not gated, because the
#      scan's persistence timing is environment-dependent in headless mode.
#
# Run:  $GODOT --editor --headless --path tests/crossscript --script test_global_class.gd
# ----------------------------------------------------------------------------

func _fail(msg: String) -> void:
	print("CROSSSCRIPT_GLOBAL_FAIL: ", msg)
	quit(1)

func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("expected editor context"); return

	# 1. Direct: _get_global_name reports the //gd:class name.
	var enemy_script: Script = load("res://scripts/enemy.odin")
	var ctrl_script: Script = load("res://scripts/controller.odin")
	if enemy_script == null or ctrl_script == null:
		_fail("could not load scripts"); return
	if String(enemy_script.get_global_name()) != "Enemy":
		_fail("Enemy.get_global_name() got '%s' want 'Enemy'" % String(enemy_script.get_global_name())); return
	if String(ctrl_script.get_global_name()) != "Controller":
		_fail("Controller.get_global_name() got '%s' want 'Controller'" % String(ctrl_script.get_global_name())); return
	print("  ok  Script.get_global_name() -> Enemy / Controller")

	# 2. Registration: the class shows up in the project's global class list (with the
	#    declared native base), making <Name> a first-class engine TYPE.
	var found := {}
	for entry in ProjectSettings.get_global_class_list():
		var n := String(entry.get("class", ""))
		if n == "Enemy" or n == "Controller":
			found[n] = String(entry.get("base", ""))
	if found.has("Enemy") and found.has("Controller"):
		if found["Enemy"] != "Node":
			_fail("Enemy global class base got '%s' want 'Node'" % found["Enemy"]); return
		print("  ok  ProjectSettings.get_global_class_list() registered Enemy(base=Node) + Controller")
		print("CROSSSCRIPT_GLOBAL_REGISTERED")
	else:
		print("  NOTE: global class list not populated in this headless run (found=%s); _get_global_name proof above still holds" % str(found))

	print("CROSSSCRIPT_GLOBAL_OK")
	quit(0)
