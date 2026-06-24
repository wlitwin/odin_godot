extends SceneTree

# ----------------------------------------------------------------------------
# Runtime (REAL script instance) verification for the richer-authoring codegen.
#
# Headless, NON-editor: CodegenProbe is instantiated for real, so we observe the actual
# runtime EFFECTS of all four features:
#   (1) @onready  — both child refs resolved & usable inside _ready (asserted via onready_ok()).
#   (3) defaults  — the freshly-created instance shows speed=200, jump=12.5 (applied on create).
#   (4) get/set   — set("hp", 500) is CLAMPED to 100 by the setter; 42 stays 42.
#
# _ready fires on the deferred ready pass, so we drive from the first process_frame.
# Prints CODEGEN_OK, or CODEGEN_FAIL: <which>.
#
# Run:  $GODOT --headless --path tests/codegen --script test_runtime.gd
# ----------------------------------------------------------------------------

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(which: String) -> void:
	if done: return
	done = true
	print("CODEGEN_FAIL: ", which)
	quit(1)

func _run() -> void:
	if done: return

	if not ResourceLoader.exists("res://codegen.tscn"):
		_fail("scene: res://codegen.tscn not found"); return
	var n = load("res://codegen.tscn").instantiate()
	if n == null:
		_fail("scene: instantiate failed"); return
	root.add_child(n)

	# --- (1) @onready ---------------------------------------------------------
	if not bool(n.call("onready_ok")):
		_fail("onready: refs not resolved/usable in _ready"); return
	print("  ok  (1) @onready: sprite + label resolved & usable in _ready")

	# --- (3) @export defaults applied on instance create ----------------------
	if abs(float(n.get("speed")) - 200.0) > 0.001:
		_fail("default: speed got %s want 200" % str(n.get("speed"))); return
	if abs(float(n.get("jump")) - 12.5) > 0.001:
		_fail("default: jump got %s want 12.5" % str(n.get("jump"))); return
	print("  ok  (3) defaults: instance initialized speed=200, jump=12.5")

	# --- (4) getter/setter routing -------------------------------------------
	n.set("hp", 500)            # setter clamps to 100
	if int(n.get("hp")) != 100:
		_fail("get/set: set 500 -> get %s want 100 (setter must clamp)" % str(n.get("hp"))); return
	n.set("hp", 42)
	if int(n.get("hp")) != 42:
		_fail("get/set: set 42 -> get %s want 42" % str(n.get("hp"))); return
	print("  ok  (4) getter/setter: write routes through setter (clamp 500->100, 42->42)")

	print("CODEGEN_OK")
	quit(0)
