extends SceneTree

# ----------------------------------------------------------------------------
# Typed cross-script reference end-to-end test (runtime, non-editor). Two Odin script
# classes: Controller (A) and Enemy (B). At runtime Controller obtains a TYPED reference
# to a live Enemy node and reads/writes its exported field + calls its method DIRECTLY
# through the Odin struct (Option A, rt.script_of). The effect is observable: the Enemy's
# exported `hp`, read back from GDScript, reflects the cross-script write.
#
# Run:  $GODOT --headless --path tests/crossscript --script test_crossscript.gd
# ----------------------------------------------------------------------------

func _fail(msg: String) -> void:
	print("CROSSSCRIPT_FAIL: ", msg)
	print("CROSSSCRIPT_FAIL")
	quit(1)

func _initialize() -> void:
	var enemy_script: Script = load("res://scripts/enemy.odin")
	var ctrl_script: Script = load("res://scripts/controller.odin")
	if enemy_script == null or ctrl_script == null:
		_fail("could not load enemy.odin / controller.odin"); return

	var rootw := get_root()
	if rootw == null:
		_fail("no scene tree root"); return

	# Build:  root -> Controller -> Enemy(child)
	var ctrl := Node.new()
	ctrl.set_script(ctrl_script)
	ctrl.name = "Controller"
	rootw.add_child(ctrl)

	var enemy := Node.new()
	enemy.set_script(enemy_script)
	enemy.name = "Enemy"
	ctrl.add_child(enemy)

	# Seed the Enemy's exported hp via GDScript (the inspector/scene path).
	enemy.set("hp", 100)
	if int(enemy.get("hp")) != 100:
		_fail("enemy.hp seed got %s want 100" % str(enemy.get("hp"))); return

	# --- A obtains a TYPED ref to B via get_node, writes B's exported field directly ---
	var post = ctrl.call("attack", 30)
	if int(post) != 70:
		_fail("attack() returned %s want 70 (typed cross-script write failed)" % str(post)); return
	# The exported hp read back from B reflects A's direct struct write -> observable.
	if int(enemy.get("hp")) != 70:
		_fail("enemy.hp after attack got %s want 70" % str(enemy.get("hp"))); return
	print("  ok  Controller typed-wrote Enemy.hp via get_node+script_of: 100 -> 70")

	# --- A obtains a TYPED ref to B via an explicit node ref, calls B's method typed ---
	var post2 = ctrl.call("damage", enemy, 10)
	if int(post2) != 60:
		_fail("damage(enemy) returned %s want 60" % str(post2)); return
	if int(enemy.get("hp")) != 60:
		_fail("enemy.hp after damage got %s want 60" % str(enemy.get("hp"))); return
	print("  ok  Controller typed-accessed Enemy via node ref: 70 -> 60")

	# --- nil-safety: script_of on a non-Odin (plain) node returns nil -> -1, no crash ---
	var plain := Node.new()
	plain.name = "Plain"
	rootw.add_child(plain)
	if int(ctrl.call("damage", plain, 5)) != -1:
		_fail("damage(non-Odin node) should return -1"); return
	print("  ok  script_of(non-Odin node) safely returns nil")

	# --- TYPE-SAFETY: script_of(objA, TypeB) must return nil when objA's script is TypeA != TypeB.
	#     `ctrl` carries the Controller script; asking for an Enemy back from it must NOT hand over
	#     the Controller struct reinterpreted as ^Enemy. mistype() returns 1 when the resolver is
	#     type-safe (nil), 0 when it returns non-nil garbage (the type-confusion bug). This is the
	#     direct regression: it FAILS (returns 0) before the class-checked resolver, passes after.
	var ctrl2 := Node.new()
	ctrl2.set_script(ctrl_script)
	ctrl2.name = "Controller2"
	rootw.add_child(ctrl2)
	if int(ctrl.call("mistype", ctrl2)) != 1:
		_fail("script_of(Controller node, Enemy) returned NON-nil -> TYPE CONFUSION (must be nil)"); return
	# And the matching type still resolves: script_of(enemy, Enemy) is non-nil (mistype on an
	# actual Enemy returns 0, i.e. NOT nil, proving the check is not blanket-nil).
	if int(ctrl.call("mistype", enemy)) != 0:
		_fail("script_of(Enemy node, Enemy) returned nil -> matching type wrongly rejected"); return
	print("  ok  script_of type check: wrong class -> nil, matching class -> non-nil")

	print("CROSSSCRIPT_OK")
	quit(0)
