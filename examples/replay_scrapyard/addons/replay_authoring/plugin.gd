@tool
extends EditorPlugin

const SavedData = preload("saved_data.gd")
var saved_data := SavedData.new()
var dock: ScrollContainer
var panel: VBoxContainer
var action_panel: VBoxContainer
var status: Label
var detail: Label
var issues: ItemList
var outputs: ItemList
var controls: Dictionary = {}
var buttons: Dictionary = {}
var menus: Array[String] = []
var config: Dictionary = {}
var toolchain: Dictionary = {}
var pid: int = -1
var result_path: String = ""
var action: String = ""
var last_report: Dictionary = {}
var last_report_action: String = ""
var pending_request: Dictionary = {}
var status_clock: float = 0
var edits_clock: float = 0
var had_unsaved: bool = false

func _enter_tree() -> void:
	toolchain = _json("res://addons/replay_authoring/toolchain.json")
	var inspector := get_editor_interface().get_inspector()
	inspector.edited_object_changed.connect(_observe_selected)
	inspector.resource_selected.connect(_observe_resource)
	_observe_selected()
	dock = ScrollContainer.new()
	dock.name = "Replay"
	dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel = VBoxContainer.new()
	panel.name = "Actions"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(panel)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Loading authoring actions…"
	panel.add_child(status)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail)
	action_panel = VBoxContainer.new()
	panel.add_child(action_panel)
	_button(panel, "Reload Authoring Actions", _reload)
	_button(panel, "Cancel Current Job", _cancel)
	issues = ItemList.new()
	issues.custom_minimum_size = Vector2(260, 150)
	issues.item_activated.connect(_open_issue)
	panel.add_child(issues)
	outputs = ItemList.new()
	outputs.custom_minimum_size = Vector2(260, 75)
	outputs.item_activated.connect(_open_output)
	outputs.hide()
	panel.add_child(outputs)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	set_process(true)
	_launch.call_deferred({}, true)

func _exit_tree() -> void:
	_cancel()
	var inspector := get_editor_interface().get_inspector()
	if inspector.edited_object_changed.is_connected(_observe_selected): inspector.edited_object_changed.disconnect(_observe_selected)
	if inspector.resource_selected.is_connected(_observe_resource): inspector.resource_selected.disconnect(_observe_resource)
	for name in menus: remove_tool_menu_item(name)
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear_actions() -> void:
	for name in menus: remove_tool_menu_item(name)
	menus.clear()
	for child in action_panel.get_children():
		action_panel.remove_child(child)
		child.queue_free()
	controls.clear()
	buttons.clear()

func _reload() -> void:
	if pid > 0:
		detail.text = "Finish or cancel the current job before reloading actions."
		return
	pending_request = {}
	config = {}
	_clear_actions()
	_launch({}, true)

func _configure(manifest: Dictionary) -> void:
	_clear_actions()
	config = manifest
	dock.name = str(config.get("title", "Replay"))
	var used: Dictionary = {}
	for entry in config.get("actions", []):
		for key in entry.get("inputs", []): used[key] = true
	for entry in config.get("inputs", []):
		var spec: Dictionary = entry
		var key := str(spec.id)
		if not used.has(key): continue
		var label := Label.new()
		label.text = str(spec.label)
		action_panel.add_child(label)
		if spec.kind == "choice":
			var choice := OptionButton.new()
			for option in spec.choices:
				choice.add_item(str(option.label))
				var index := choice.item_count - 1
				choice.set_item_metadata(index, int(option.value) if option.value is float else option.value)
				if option.value == spec.default: choice.select(index)
			action_panel.add_child(choice)
			controls[key] = choice
		else:
			var text := LineEdit.new()
			text.text = str(spec.get("default", ""))
			action_panel.add_child(text)
			controls[key] = text
			if spec.kind == "resource": _button(action_panel, "Use selected Resource", _use_selected.bind(key))
			if spec.kind in ["resource", "file"]: _button(action_panel, "Choose…", _choose_file.bind(spec))
	for entry in config.get("actions", []):
		var key := str(entry.id)
		buttons[key] = _button(action_panel, str(entry.label), _start.bind(key))
		var menu := str(config.get("title", "Replay")) + ": " + str(entry.label)
		add_tool_menu_item(menu, _start.bind(key))
		menus.append(menu)
	status.text = "Ready"
	detail.text = "Choose an authoring action."
	if not _status_action().is_empty(): _start.call_deferred(_status_action())

func _action(key: String) -> Dictionary:
	for entry in config.get("actions", []):
		if entry.id == key: return entry
	return {}

func _status_action() -> String:
	return str(config.get("status_action", ""))

func _capture_request(wanted: String) -> Dictionary:
	var values: Dictionary = {}
	for key in _action(wanted).get("inputs", []):
		var control: Control = controls[key]
		if control is OptionButton:
			var choice := control as OptionButton
			values[key] = choice.get_item_metadata(choice.selected)
		else:
			values[key] = (control as LineEdit).text
	return {"action": wanted, "inputs": values.duplicate(true)}

func _start(wanted: String) -> void:
	if _action(wanted).is_empty():
		_show_failure("Choose a declared authoring action.")
		return
	# Capture at the click, before any import/status wait or subsequent edit.
	_dispatch(_capture_request(wanted))

func _dispatch(request: Dictionary) -> void:
	var spec := _action(str(request.action))
	if pid > 0:
		if action == _status_action() and request.action != action:
			pending_request = request.duplicate(true)
		return
	if bool(spec.get("save", false)):
		if get_editor_interface().get_resource_filesystem().is_scanning():
			pending_request = request.duplicate(true)
			detail.text = "Waiting for project import before saving…"
			return
		var saved := _save()
		if not saved.ok:
			action = str(request.action)
			last_report = saved
			last_report_action = action
			status.text = "Content: unsaved edits"
			detail.text = str(saved.message)
			_show_issues(saved)
			return
	if spec.kind == "open_scene":
		get_editor_interface().open_scene_from_path(str(spec.scene))
		return
	_launch(request)

func _launch(request: Dictionary, describe: bool = false) -> void:
	action = "@describe" if describe else str(request.action)
	toolchain = _json("res://addons/replay_authoring/toolchain.json")
	var framework := str(toolchain.get("framework", ""))
	var python := str(toolchain.get("python", ""))
	var runner := framework.path_join("replay/editor/worker.py")
	if python.is_empty() or not FileAccess.file_exists(runner):
		_show_failure("Build the project once to install its authoring toolchain.")
		return
	var relative := "res://.godot/replay_authoring/jobs/%s-%s" % [action.replace("@", ""), Time.get_ticks_usec()]
	var base := ProjectSettings.globalize_path(relative)
	if DirAccess.make_dir_recursive_absolute(base) != OK:
		_show_failure("Cannot create the authoring job directory.")
		return
	result_path = base.path_join("result.json")
	var args := PackedStringArray([runner, "--project", ProjectSettings.globalize_path("res://"), "--framework", framework, "--godot", OS.get_executable_path(), "--result", result_path])
	if describe:
		args.append("--describe")
	else:
		var request_path := base.path_join("request.json")
		var file := FileAccess.open(request_path, FileAccess.WRITE)
		if file == null:
			_show_failure("Cannot save the authoring request.")
			return
		file.store_string(JSON.stringify(request))
		file.close()
		args.append_array(["--request", request_path])
	pid = OS.create_process(python, args)
	if pid <= 0:
		pid = -1
		_show_failure("Could not start the authoring worker. Check the configured Python executable.")
		return
	if action != _status_action():
		status.text = "Loading actions…" if describe else "Checking saved inputs…"
		detail.text = "Starting " + action.replace("@", "") + "…"
		issues.clear()
	_refresh_buttons()

func _refresh_buttons() -> void:
	for key in buttons:
		buttons[key].disabled = pid > 0 and action != _status_action()

func _process(dt: float) -> void:
	edits_clock += dt
	if edits_clock > 1:
		edits_clock = 0
		var unsaved := saved_data.has_pending(get_editor_interface())
		if unsaved: status.text = "Content: unsaved edits — save before validating"
		elif had_unsaved and pid < 0 and _status_action().is_empty(): status.text = "Saved changes — run validation"
		had_unsaved = unsaved
		# A packaged starter has its dock before its first build. Pick up the
		# build's local tool paths without requiring a plugin toggle or restart.
		if config.is_empty() and pid < 0:
			var installed := _json("res://addons/replay_authoring/toolchain.json")
			if not installed.is_empty() and installed != toolchain:
				_launch({}, true)
	if pid > 0:
		var report := _json(result_path)
		if not report.is_empty() and action != _status_action(): detail.text = str(report.get("message", action))
		if not OS.is_process_running(pid):
			pid = -1
			_finish(report)
			status_clock = 0
			_refresh_buttons()
			if not pending_request.is_empty(): _run_pending.call_deferred()
	else:
		if not pending_request.is_empty() and not get_editor_interface().get_resource_filesystem().is_scanning():
			_run_pending.call_deferred()
			return
		status_clock += dt
		if status_clock > 5 and not _status_action().is_empty():
			_start(_status_action())
			status_clock = 0

func _run_pending() -> void:
	if pid > 0 or pending_request.is_empty(): return
	var request := pending_request
	pending_request = {}
	_dispatch(request)

func _finish(report: Dictionary) -> void:
	if report.is_empty() or report.get("running", false):
		_show_failure("Worker stopped without a completed report. See the authoring job logs.")
		return
	if action == "@describe":
		if report.get("ok", false) and report.get("manifest") is Dictionary:
			last_report = report.duplicate(true)
			last_report_action = action
			issues.clear()
			outputs.clear()
			outputs.hide()
			_configure(report.manifest)
		else:
			last_report = report
			status.text = "Authoring setup needs attention"
			detail.text = str(report.get("message", "Invalid authoring manifest."))
			_show_issues(report)
		return
	var unsaved := saved_data.has_pending(get_editor_interface())
	var visible_report: bool = action != _status_action() or not report.get("ok", false) or last_report_action == _status_action()
	if visible_report:
		last_report = report.duplicate(true)
		last_report["editor_unsaved"] = unsaved
		last_report_action = action
	if not report.get("ok", false):
		status.text = "Status check failed" if action == _status_action() else "Action failed"
	elif report.has("stale"):
		status.text = "Content: STALE — bake required" if report.stale else "Content: current"
	else:
		status.text = "Validation passed" if action != _status_action() else str(report.get("message", "Status checked"))
	if unsaved: status.text = "Content: unsaved edits — save before validating"
	if visible_report:
		detail.text = str(report.get("message", "Done"))
		if not str(report.get("details", "")).is_empty(): detail.text += "\n" + str(report.details)
		_show_issues(report)
		_show_outputs(report)
		if action != _status_action(): get_editor_interface().get_resource_filesystem().scan()
		var target := str(report.get("navigate_to", ""))
		if action != _status_action() and target.begins_with("res://"): get_editor_interface().get_file_system_dock().navigate_to_path(target)
		if unsaved: detail.text += "\nNew editor changes were not included. Save and rerun the action."

func _show_failure(message: String) -> void:
	last_report = {"ok": false, "running": false, "message": message, "issues": [{"source": "res://replay_authoring.json", "path": "$job", "message": message}]}
	last_report_action = action
	status.text = "Status check failed" if action == _status_action() else "Action could not start"
	detail.text = message
	_show_issues(last_report)

func _observe_selected() -> void:
	saved_data.observe(get_editor_interface().get_inspector().get_edited_object())

func _observe_resource(resource: Resource, _path: String) -> void:
	saved_data.observe(resource)

func _save() -> Dictionary:
	return saved_data.save(get_editor_interface())

func _use_selected(key: String) -> void:
	var object: Object = get_editor_interface().get_inspector().get_edited_object()
	if object is Resource and not object.resource_path.is_empty(): controls[key].text = object.resource_path

func _choose_file(spec: Dictionary) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES if spec.kind == "resource" else FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(spec.get("filters", []))
	dialog.file_selected.connect(func(path: String): controls[spec.id].text = path; dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(.7)

func _show_issues(report: Dictionary) -> void:
	issues.clear()
	for issue in report.get("issues", []):
		var index := issues.add_item(str(issue.get("source", "")) + " " + str(issue.get("path", "")) + ": " + str(issue.get("message", "")))
		issues.set_item_metadata(index, issue)
		issues.set_item_tooltip(index, str(issue.get("source", "")))

func _show_outputs(report: Dictionary) -> void:
	outputs.clear()
	for output in report.get("outputs", []):
		var index := outputs.add_item(str(output.label))
		outputs.set_item_metadata(index, str(output.path))
	for path in report.get("logs", []):
		var index := outputs.add_item(str(path).get_file())
		outputs.set_item_metadata(index, str(path))
	outputs.visible = outputs.item_count > 0

func _open_output(index: int) -> void:
	var path := str(outputs.get_item_metadata(index))
	if path.begins_with("res://"): _open_path(path)
	elif FileAccess.file_exists(path): OS.shell_open(path)

func _open_issue(index: int) -> void:
	var issue: Dictionary = issues.get_item_metadata(index)
	var object_id := int(issue.get("object_id", 0))
	if object_id != 0 and is_instance_id_valid(object_id):
		var object := instance_from_id(object_id)
		if object is Script: get_editor_interface().edit_script(object)
		elif object is Resource: get_editor_interface().edit_resource(object)
		elif object is Node: get_editor_interface().edit_node(object)
		return
	_open_path(str(issue.get("source", "")), int(issue.get("line", 1)))

func _open_path(path: String, line: int = 1) -> void:
	if not path.begins_with("res://"): return
	get_editor_interface().get_file_system_dock().navigate_to_path(path)
	if path.ends_with(".tscn") or path.ends_with(".scn"): get_editor_interface().open_scene_from_path(path)
	elif path.ends_with(".tres") or path.ends_with(".res"):
		var resource: Resource = load(path)
		if resource != null: get_editor_interface().edit_resource(resource)
	elif path.ends_with(".odin"):
		var script: Script = load(path)
		if script != null: get_editor_interface().edit_script(script, line - 1)

func _cancel() -> void:
	pending_request = {}
	if pid > 0 and not result_path.is_empty():
		var file := FileAccess.open(result_path.get_basename() + ".cancel", FileAccess.WRITE)
		if file != null: file.store_string("cancel")
		detail.text = "Cancelling…"
