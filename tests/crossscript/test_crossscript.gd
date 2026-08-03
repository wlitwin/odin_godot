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

	# --- rt.script_any: ONE dispatch table keyed by TYPE, instances carry nothing ---
	# The Enemy entry runs and writes through: hp 60 -> 55, the impl's return observable.
	if int(ctrl.call("dispatch", enemy, 5)) != 55:
		_fail("dispatch(enemy, 5) did not run the Enemy impl (want 55)"); return
	if int(enemy.get("hp")) != 55:
		_fail("dispatch write did not land: enemy.hp=%s want 55" % str(enemy.get("hp"))); return
	# The SAME call site, a different type: the Controller entry runs (marker 777).
	if int(ctrl.call("dispatch", ctrl2, 5)) != 777:
		_fail("dispatch(controller) did not run the Controller impl (want 777)"); return
	# A plain engine node resolves to nothing: -1, no crash.
	if int(ctrl.call("dispatch", plain, 5)) != -1:
		_fail("dispatch(non-Odin node) should return -1"); return
	# And the any-resolver agrees with the class-checked resolver on the struct pointer.
	if int(ctrl.call("any_matches", enemy)) != 1:
		_fail("script_any(enemy) pointer != script_of(enemy, Enemy)"); return
	print("  ok  rt.script_any static dispatch: Enemy impl, Controller impl, plain -> nil, ptr identity")

	# --- rt.dispatch: the one-call form of the same pattern (compose script_any + lookup) ---
	if int(ctrl.call("dispatch2", enemy, 5)) != 50:
		_fail("dispatch2(enemy, 5) did not run the Enemy impl (want 50)"); return
	if int(enemy.get("hp")) != 50:
		_fail("dispatch2 write did not land: enemy.hp=%s want 50" % str(enemy.get("hp"))); return
	if int(ctrl.call("dispatch2", ctrl2, 5)) != 777:
		_fail("dispatch2(controller) did not run the Controller impl (want 777)"); return
	if int(ctrl.call("dispatch2", plain, 5)) != -1:
		_fail("dispatch2(non-Odin node) should return -1"); return
	print("  ok  rt.dispatch one-call form: same three outcomes through the composed helper")

	# --- script-resolving @onready: `buddy: ^Enemy `gd:"onready=Enemy"`` — the core wires
	#     node AND typed script struct at READY. Built here, ASSERTED IN _process:
	#     nodes added during _initialize get their READY only when the main loop starts,
	#     so the wiring hasn't happened yet on this line. Assembled BEFORE entering the
	#     tree, the scene-instantiation shape (children ready first).
	var wing_script: Script = load("res://scripts/wingman.odin")
	if wing_script == null:
		_fail("could not load wingman.odin"); return
	_wing = Node.new()
	_wing.set_script(wing_script)
	_wing.name = "Wingman"
	_enemy2 = Node.new()
	_enemy2.set_script(enemy_script)
	_enemy2.name = "Enemy"
	# Array-onready children: Squad0/Squad1 (Enemy-scripted), wired into `squad: [2]^Enemy`
	# by the `%d` template at READY.
	for i in range(2):
		var sq := Node.new()
		sq.set_script(enemy_script)
		sq.name = "Squad%d" % i
		_wing.add_child(sq)
		_squad.append(sq)
	_wing.add_child(_enemy2)
	# Scene-unique child for the `%doc` onready/connect pair: flag first, then owner —
	# set_owner registers the unique name in _wing's registry (the scene-file order).
	_doc = Node.new()
	_doc.set_script(enemy_script)
	_doc.name = "doc"
	_doc.unique_name_in_owner = true
	_wing.add_child(_doc)
	_doc.owner = _wing
	rootw.add_child(_wing)
	_enemy2.set("hp", 40)
	_squad[0].set("hp", 10)
	_squad[1].set("hp", 20)

	# Negative twin: the path resolves to a PLAIN (script-less) node -> ref must stay nil
	# (the core pushes a loud error naming the field; no crash, no wrong-typed pointer).
	_wing2 = Node.new()
	_wing2.set_script(wing_script)
	_wing2.name = "Wingman2"
	var decoy := Node.new()
	decoy.name = "Enemy"
	_wing2.add_child(decoy)
	rootw.add_child(_wing2)

	# Prototype PackedScene for the _process-phase spawn probe (script ref is in scope here).
	_proto_scene = PackedScene.new()
	var proto := Node.new()
	proto.set_script(enemy_script)
	proto.name = "Proto"
	if _proto_scene.pack(proto) != OK:
		_fail("could not pack the Enemy prototype scene"); return
	proto.free()

var _wing: Node
var _enemy2: Node
var _wing2: Node
var _squad: Array[Node] = []
var _doc: Node
var _proto_scene: PackedScene

# First frame: every READY has fired, so the @onready script refs are wired (or provably not).
func _process(_delta: float) -> bool:
	if int(_wing.call("wired")) != 1:
		_fail("onready script ref did not resolve (buddy nil after READY)"); return true
	var post3 = _wing.call("hit", 15)
	if int(post3) != 25:
		_fail("hit() through the onready script ref returned %s want 25" % str(post3)); return true
	if int(_enemy2.get("hp")) != 25:
		_fail("enemy2.hp after onready-ref hit got %s want 25 (typed write did not land)" % str(_enemy2.get("hp"))); return true
	print("  ok  @onready script ref: ^Enemy auto-wired at READY, typed write landed")

	if int(_wing2.call("wired")) != 0:
		_fail("onready script ref on a script-less target must stay nil"); return true
	if int(_wing2.call("hit", 5)) != -1:
		_fail("hit() through an unresolved ref must return -1"); return true
	print("  ok  @onready script ref: script-less target -> nil ref (soft + loud)")

	# --- //gd:group: declarative membership joined at READY (both names on one marker).
	if not _wing.is_in_group("wingmen") or not _wing.is_in_group("escorts"):
		_fail("//gd:group did not join wingmen+escorts at READY"); return true
	if get_nodes_in_group("wingmen").size() != 2:  # _wing and _wing2 both carry the class
		_fail("group census wrong: want both Wingman instances in 'wingmen'"); return true
	print("  ok  //gd:group: class-declared membership joined at READY")

	# --- array onready: `squad: [2]^Enemy `gd:"onready=Squad%d"`` — both elements typed-wired.
	var shp = _wing.call("squad_hp")
	if int(shp) != 30:
		_fail("array onready squad_hp returned %s want 30 (10+20)" % str(shp)); return true
	print("  ok  array @onready: [2]^Enemy wired via %d template, typed reads landed")

	# --- path-qualified @(gd_connect="Enemy:hurt"): the CHILD's declared signal wired to a
	#     parent method at READY; emits are synchronous, so the counter reads back at once.
	#     (_wing2's decoy is a plain Node: its connect attempt fails SOFT with the engine's
	#     nonexistent-signal error — that path is exercised just by _wing2 existing.)
	_enemy2.call("shout", 7)
	if int(_wing.call("sig_total")) != 7:
		_fail("path-qualified gd_connect handler did not fire (want 7, got %s)" % str(_wing.call("sig_total"))); return true
	_enemy2.call("shout", 5)
	if int(_wing.call("sig_total")) != 12:
		_fail("second emit did not accumulate (want 12, got %s)" % str(_wing.call("sig_total"))); return true
	print("  ok  @(gd_connect=\"Enemy:hurt\"): child signal -> parent method, args intact")

	# --- INDEXED @(gd_connect="Squad%d:hurt"): both squad members wired to ONE handler,
	#     each with its 0-based index bound as the trailing arg (weighted by idx+1).
	_squad[0].call("shout", 3)   # 3 * (0+1) = 3
	_squad[1].call("shout", 5)   # 5 * (1+1) = 10
	var w = _wing.call("squad_weighted")
	if int(w) != 13:
		_fail("indexed gd_connect weighted sum %s want 13 (index binding broken)" % str(w)); return true
	print("  ok  indexed @(gd_connect): %d probe wired both, bound index reached the handler")

	# --- scene-unique-name paths: `%doc` onready + "%doc:hurt" connect. The name is
	#     deliberately d-initial — the path contains the bytes "%d" and must resolve
	#     through the unique-name registry, never substitute as an array template.
	if int(_wing.call("doc_wired")) != 1:
		_fail("unique-name onready (doc) did not resolve after READY"); return true
	_doc.call("shout", 9)
	if int(_wing.call("doc_total")) != 9:
		_fail("unique-name gd_connect handler did not fire (want 9, got %s)" % str(_wing.call("doc_total"))); return true
	print("  ok  scene-unique names: onready + gd_connect resolved via the unique-name registry")

	# --- gd.vcall family: by-name void call (heal +5: 25 -> 30) then vcall_int (power*2).
	var pw = _wing.call("vcall_probe", 5)
	if int(pw) != 60:
		_fail("vcall_probe returned %s want 60 ((25+5)*2)" % str(pw)); return true
	if int(_enemy2.get("hp")) != 30:
		_fail("vcall_void heal did not land: hp=%s want 30" % str(_enemy2.get("hp"))); return true
	print("  ok  gd.vcall: void + int-returning by-name calls, args auto-converted")

	# --- rt.spawn_scripted / rt.spawn_as: typed spawning from the prototype scene packed
	#     in _initialize (where the script ref was in scope).
	var sp = _wing.call("spawn_probe", _proto_scene)
	if int(sp) != 82:
		_fail("spawn_probe returned %s want 82 (77 poked-before-add + 5 poked-after)" % str(sp)); return true
	print("  ok  rt.spawn_*: typed spawns, poke-before-add and poke-after shapes")

	print("CROSSSCRIPT_OK")
	quit(0)
	return true
