@tool
extends EditorPlugin

var addon: EditorPlugin
var control: Box3DSetupControl
func _enter_tree() -> void:
	if OS.get_environment("BOX3D_SETUP_CHECK") == "1": call_deferred("_check")
func fail(message: String) -> void:
	push_error("BOX3D_SETUP_FAIL: " + message)
	get_tree().quit(1)
func ready_tools() -> bool:
	var until := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.25).timeout
		var state: int = int(addon.services.build_coordinator().call("get_build_state"))
		if state in [2, 3]: return false
		if addon.services.available() and state == 0: return true
	return false
func failed_build() -> bool:
	var until := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.25).timeout
		if int(addon.services.build_coordinator().call("get_build_state")) == 2:
			for _i in range(8): await get_tree().process_frame
			return true
	return false
func _check() -> void:
	for _i in range(8): await get_tree().process_frame
	var problem: String = preload("res://setup_cases.gd").run()
	if not problem.is_empty(): fail(problem); return
	var plugins := get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if plugins.size() != 1: fail("packaged plugin registration"); return
	addon = plugins[0]
	if addon.services.setup_status().state != "install": fail("initial setup status"); return
	control = Box3DSetupControl.new(addon)
	get_editor_interface().get_base_control().add_child(control)
	var original_path := OS.get_environment("PATH")
	var original_odin := OS.get_environment("ODIN")
	OS.set_environment("PATH", "")
	OS.set_environment("ODIN", "")
	control.action.pressed.emit()
	var missing: bool = addon.services.setup_status().state == "compiler_missing"
	OS.set_environment("PATH", original_path)
	OS.set_environment("ODIN", original_odin)
	if not missing: fail("missing compiler status"); return
	control.refresh()
	control.action.pressed.emit()
	if not await ready_tools(): fail("ordinary install/build: " + str(addon.services.setup_status())); return
	if DirAccess.dir_exists_absolute("res://scripts"): fail("module setup created main scripts"); return
	var registered := 0
	for entry in ProjectSettings.get_global_class_list():
		if entry.class == "AuthoringTools":
			registered += 1
			if entry.path != Box3DEditorServices.MODULE_SCRIPT: fail("template class registered"); return
	if registered != 1: fail("installed tool class count " + str(registered)); return
	print("BOX3D_SETUP_INSTALL_BUILD_OK")
	var world := Box3DWorld3D.new()
	var body := Box3DBody3D.new()
	body.shapes.append(Box3DBoxShape3D.new()); world.add_child(body)
	var inspected: Dictionary = addon.inspect_object(world)
	if not inspected.get("ok", false): world.free(); fail("compiled validation: " + str(inspected)); return
	var output := Box3DResultView.new()
	output.show_result(inspected)
	if not "1 bodies" in output.summary.text or output.details.visible or not output.details_toggle.visible: world.free(); output.free(); fail("concise collapsed result"); return
	output.details_toggle.button_pressed = true
	if not output.details.visible or not "metadata" in output.details.text: world.free(); output.free(); fail("expandable details"); return
	output.show_result({"ok": false, "diagnostics": [{"path": "World/Crate.shapes[0]", "message": "Invalid shape"}, {"path": "World/Floor.pose", "message": "Invalid pose"}]})
	if not "World/Crate.shapes[0]" in output.summary.text or not "World/Floor.pose" in output.summary.text: world.free(); output.free(); fail("diagnostic locations hidden"); return
	var baked: Dictionary = addon.services.bake_definition(world.box3d_definition(), "res://setup-world.tscn", "")
	output.free(); world.free()
	if not baked.get("ok", false): fail("native-free artifact bake"); return
	var reimports := {"count": 0}
	var filesystem := get_editor_interface().get_resource_filesystem()
	filesystem.resources_reimported.connect(func(paths: PackedStringArray):
		if paths.has("res://setup-world.b3authoring"): reimports.count += 1)
	var artifact_file := FileAccess.open("res://setup-world.b3authoring", FileAccess.WRITE)
	artifact_file.store_buffer(Marshalls.base64_to_raw(baked.artifact_base64));artifact_file.close()
	filesystem.scan()
	var import_deadline := Time.get_ticks_msec() + 10000
	while reimports.count == 0 and Time.get_ticks_msec() < import_deadline:
		await get_tree().create_timer(0.1).timeout
	if reimports.count == 0: fail("initial actual artifact import"); return
	var packaged := Box3DToolSetup.SOURCE.path_join("tools.odin")
	var original := FileAccess.get_file_as_string(packaged)
	preload("res://setup_cases.gd").write(packaged, original + "\n// simulated SDK update\n")
	control.refresh()
	if control._state != "update": fail("SDK update status"); return
	control.action.pressed.emit()
	if not await ready_tools(): fail("updated loaded tool fingerprint"); return
	var local := FileAccess.get_file_as_string(Box3DEditorServices.MODULE_SCRIPT) + "\n// project customization\n"
	preload("res://setup_cases.gd").write(Box3DEditorServices.MODULE_SCRIPT, local)
	if addon.services.available(): fail("stale loaded module accepted"); return
	print("BOX3D_EXPECT_UNAVAILABLE_BEGIN")
	filesystem.reimport_files(PackedStringArray(["res://setup-world.b3authoring"]))
	for _i in range(8): await get_tree().process_frame
	if not addon.services.pending_imports.has("res://setup-world.b3authoring"): fail("unavailable artifact not queued"); return
	var failed_import_count: int = reimports.count
	print("BOX3D_EXPECT_UNAVAILABLE_END")
	control.refresh()
	if control._state != "conflict" or control.action.disabled: fail("local conflict must still allow build"); return
	control.action.pressed.emit()
	if not await ready_tools(): fail("custom tool build"); return
	import_deadline = Time.get_ticks_msec() + 10000
	while reimports.count <= failed_import_count and Time.get_ticks_msec() < import_deadline:
		await get_tree().create_timer(0.1).timeout
	if reimports.count <= failed_import_count or not addon.services.pending_imports.is_empty(): fail("automatic artifact retry"); return
	var imported: Resource = ResourceLoader.load("res://setup-world.b3authoring", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not imported is Box3DBakeArtifact or not imported.inspect_with(addon.services).get("ok", false): fail("retried artifact invalid"); return
	imported = null
	print("BOX3D_SETUP_IMPORT_RETRY_OK")
	if FileAccess.get_file_as_string(Box3DEditorServices.MODULE_SCRIPT) != local: fail("custom source overwritten"); return
	print("BOX3D_SETUP_UPDATE_CUSTOM_OK")
	# A bulk build and the periodic reconciliation must both leave a module-only
	# project usable. Deliberately stay open past the reconciliation interval.
	await get_tree().create_timer(32.0).timeout
	if int(addon.services.build_coordinator().call("get_build_state")) != 0 or not addon.services.available(): fail("module-only periodic reconciliation"); return
	# A game that loses its main scripts must keep failing on a repeated build,
	# even though its independent authoring module still builds successfully.
	preload("res://setup_cases.gd").write("res://scripts/main.odin", "//gd:extends Node\n//gd:class SetupMain\n//gd:tool\npackage scripts\nimport gd \"godot:godot\"\nSetupMain :: struct { owner: gd.Node }\n@(gd_method)\nsetup_main_revision :: proc(self: ^SetupMain) -> i64 { return 1 }\n")
	addon.services.request_build()
	if not await ready_tools(): fail("main package build"); return
	if DirAccess.rename_absolute("res://scripts", "res://.godot/removed-main") != OK: fail("remove main fixture"); return
	for attempt in range(2):
		print("BOX3D_EXPECT_FAILURE_BEGIN ", attempt)
		addon.services.request_build()
		if not await failed_build(): fail("missing main retry must stay failed"); return
		if addon.services.setup_status().state != "failed": fail("build failure hidden by local tool edits"); return
		print("BOX3D_EXPECT_FAILURE_END ", attempt)
	if DirAccess.rename_absolute("res://.godot/removed-main", "res://scripts") != OK: fail("restore main fixture"); return
	addon.services.request_build()
	if not await ready_tools(): fail("main restoration recovery"); return
	print("BOX3D_SETUP_FAILURE_RECOVERY_OK")
	var main_script: Script = load("res://scripts/main.odin")
	var main_node := Node.new();main_node.set_script(main_script);add_child(main_node)
	if int(main_node.call("revision")) != 1: fail("main callable fixture"); return
	var collision_path := "res://modules/collision/tools.odin"
	var collision_source := "//gd:extends Node\n//gd:class AuthoringTools\n//gd:tool\npackage collision\nimport gd \"godot:godot\"\nAuthoringTools :: struct { owner: gd.Node }\n"
	print("BOX3D_EXPECT_ADMISSION_BEGIN")
	preload("res://setup_cases.gd").write(collision_path, collision_source)
	addon.services.request_build()
	if not await failed_build(): fail("new module collision accepted"); return
	if int(main_node.call("revision")) != 1 or not addon.services.available(): fail("collision damaged existing modules"); return
	var main_source := FileAccess.get_file_as_string("res://scripts/main.odin").replace("return 1", "return 2")
	preload("res://setup_cases.gd").write("res://scripts/main.odin", main_source)
	main_script.reload(true)
	var until := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until and int(main_node.call("revision")) != 2:
		await get_tree().create_timer(0.25).timeout
	if int(main_node.call("revision")) != 2: fail("unrelated targeted rebuild did not load"); return
	for _i in range(8): await get_tree().process_frame
	if int(addon.services.build_coordinator().call("get_build_state")) != 2: fail("unrelated build cleared rejected module"); return
	print("BOX3D_EXPECT_ADMISSION_END")
	preload("res://setup_cases.gd").write(collision_path, collision_source.replace("AuthoringTools", "SetupOtherTools"))
	addon.services.request_build()
	if not await ready_tools(): fail("repaired module admission"); return
	main_node.free()
	print("BOX3D_SETUP_ADMISSION_OK")
	control.queue_free()
	get_editor_interface().set_plugin_enabled("box3d_authoring", false)
	for _i in range(4): await get_tree().process_frame
	get_editor_interface().set_plugin_enabled("box3d_authoring", true)
	for _i in range(4): await get_tree().process_frame
	addon = get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")[0]
	if not addon.services.available(): fail("reenable tools"); return
	print("BOX3D_SETUP_EDITOR_OK")
	get_tree().quit(0)
