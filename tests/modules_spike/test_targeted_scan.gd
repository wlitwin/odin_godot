extends SceneTree

# Proves the editor worker maps a saved res:// path directly to its owning module instead
# of walking every module first. The run script enables an opt-in worker scan-plan trace and
# asserts that every job between this driver's request/completion markers targets enemies.

const ENEMY_SRC := "res://modules/enemies/enemy.odin"
const OLD := "\t//TARGET_SCAN_FIELD"
const NEW := "\ttarget_scan_field: gd.Int `gd:\"export\"`,"

var original := ""
var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _write_enemy(text: String) -> void:
	var f := FileAccess.open(ENEMY_SRC, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()

func _cleanup() -> void:
	if original != "":
		_write_enemy(original)

func _has_export(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name")) == name:
			return true
	return false

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	_cleanup()
	print("TARGETED_MODULE_SCAN_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if not Engine.is_editor_hint():
		_fail("requires --editor")
		return

	var script = load(ENEMY_SRC)
	if script == null:
		_fail("enemy script did not load")
		return
	var enemy := Node.new()
	enemy.set_script(script)
	root.add_child(enemy)
	if _has_export(enemy, "target_scan_field"):
		_fail("target-scan export already existed in the baseline")
		return

	# Let the first worker probe establish all module hashes before introducing the trap.
	await create_timer(3.0).timeout

	var rf := FileAccess.open(ENEMY_SRC, FileAccess.READ)
	if rf == null:
		_fail("could not read enemy source")
		return
	original = rf.get_as_text()
	rf.close()
	if original.find(OLD) == -1:
		_fail("target-scan marker missing")
		return

	_write_enemy(original.replace(OLD, NEW))

	print("TARGETED_SCAN_REQUEST")
	var err = script.reload(true)
	if err != OK:
		_fail("reload request returned %s" % str(err))
		return

	var live := false
	for i in range(4800):
		await process_frame
		if _has_export(enemy, "target_scan_field"):
			live = true
			break
	if not live:
		_fail("enemies edit never became live")
		return

	_cleanup()
	print("TARGETED_MODULE_SCAN_OK")
	done = true
	quit(0)
