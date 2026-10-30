@tool
extends EditorPlugin

var dock:ScrollContainer
var panel:VBoxContainer
var status:Label
var detail:Label
var issues:ItemList
var selection:LineEdit
var draft_name:LineEdit
var draft_kind:OptionButton
var latency:OptionButton
var toolchain:Dictionary={}
var config:Dictionary={}
var pid:int=-1
var result_path:String=""
var action:String=""
var last_report:Dictionary={}
var status_clock:float=0
var pending_action:String=""

func _enter_tree():
	config=_json("res://replay_authoring.json")
	toolchain=_json("res://addons/replay_authoring/toolchain.json")
	dock=ScrollContainer.new();dock.name="Replay";dock.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel=VBoxContainer.new();panel.name="Actions";panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;dock.add_child(panel)
	status=Label.new();status.text="Content status pending";panel.add_child(status)
	detail=Label.new();detail.text="Save changes, then validate or refresh an isolated preview.";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(detail)
	selection=LineEdit.new();selection.placeholder_text="Ability Resource or recording path";selection.text=config.get("ability","res://data/abilities/salvefield.tres");panel.add_child(selection)
	_button("Use selected Resource",_use_selected)
	_button("Save & Validate Content",_start.bind("validate"))
	_button("Save & Bake Content",_start.bind("bake"))
	_button("Refresh Content Status",_start.bind("status"))
	_button("Open Ability Workbench",_open_workbench)
	latency=OptionButton.new();latency.add_item("Local — 0 ms",0);latency.add_item("Typical — 80 ms",80);latency.add_item("Adverse — 150 ms",150);panel.add_child(latency)
	_button("Run Network Encounter",_start.bind("network"))
	_button("Replay Late Correction",_start.bind("correction"))
	_button("Test Checkpoint Takeover",_start.bind("takeover"))
	_button("Choose recording…",_choose_recording)
	_button("Verify Recording",_start.bind("verify"))
	draft_kind=OptionButton.new();draft_kind.add_item("Ability draft");draft_kind.add_item("Actor draft");panel.add_child(draft_kind)
	draft_name=LineEdit.new();draft_name.placeholder_text="New feature name";panel.add_child(draft_name)
	_button("Create Feature Draft",_start.bind("scaffold"))
	_button("Cancel Current Job",_cancel)
	issues=ItemList.new();issues.custom_minimum_size=Vector2(260,180);issues.item_activated.connect(_open_issue);panel.add_child(issues)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL,dock)
	add_tool_menu_item("Validate Replay Content",_start.bind("validate"))
	add_tool_menu_item("Bake Replay Content",_start.bind("bake"))
	set_process(true)
	_start.call_deferred("status")

func _exit_tree():
	_cancel()
	remove_tool_menu_item("Validate Replay Content");remove_tool_menu_item("Bake Replay Content")
	if is_instance_valid(dock):remove_control_from_docks(dock);dock.queue_free()

func _json(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _button(label:String,callback:Callable):
	var button:=Button.new();button.text=label;button.pressed.connect(callback);panel.add_child(button)

func _use_selected():
	var object: Object=get_editor_interface().get_inspector().get_edited_object()
	if object is Resource and not object.resource_path.is_empty():selection.text=object.resource_path

func _save():
	get_editor_interface().save_all_scenes()
	var object: Object=get_editor_interface().get_inspector().get_edited_object()
	if object is Resource and object.resource_path.begins_with("res://") and not "::" in object.resource_path:
		return ResourceSaver.save(object)==OK
	return true

func _open_workbench():
	get_editor_interface().open_scene_from_path(config.get("workbench","res://dev/ability_workbench.tscn"))

func _start(wanted:String):
	if pid>0:
		if action=="status" and wanted!="status":pending_action=wanted
		return
	if wanted!="status" and not _save():detail.text="Could not save the selected Resource.";return
	var relative:="res://.godot/replay_authoring/status" if wanted=="status" else "res://.godot/replay_authoring/jobs/%s-%s"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	var base:=ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(base)
	result_path=base+"/result.json";action=wanted
	var worker:=ProjectSettings.globalize_path(config.get("worker","res://tools/authoring.py"))
	var args:=PackedStringArray([worker,"--project",ProjectSettings.globalize_path("res://"),"--framework",toolchain.get("framework",""),"--godot",OS.get_executable_path(),"--result",result_path,wanted,"--selection",selection.text,"--name",draft_name.text,"--kind","ability" if draft_kind.selected==0 else "actor","--latency",str(latency.get_selected_id())])
	pid=OS.create_process(toolchain.get("python","python3"),args)
	if pid<0:detail.text="Could not start the authoring worker. Check the configured Python executable.";return
	if wanted!="status":detail.text="Starting "+wanted+"…";issues.clear()

func _process(dt:float):
	if pid>0:
		var report:=_json(result_path)
		if not report.is_empty() and action!="status":detail.text=str(report.get("message",action))
		if not OS.is_process_running(pid):
			pid=-1;_finish(report);status_clock=0
			if not pending_action.is_empty():
				var next:=pending_action;pending_action="";_start.call_deferred(next)
	else:
		status_clock+=dt
		if status_clock>5:_start("status");status_clock=0

func _finish(report:Dictionary):
	if report.is_empty():detail.text="Worker stopped without a report. See .godot/replay_authoring/jobs.";return
	if action!="status":last_report=report
	if report.has("stale"):status.text="Content: STALE — bake required" if report.stale else "Content: current"
	if action!="status":
		detail.text=str(report.get("message","Done"));issues.clear()
		for issue in report.get("issues",[]):
			var index:=issues.add_item(str(issue.get("path",""))+": "+str(issue.get("message","")))
			issues.set_item_metadata(index,issue)
			issues.set_item_tooltip(index,str(issue.get("source","")))
		get_editor_interface().get_resource_filesystem().scan()
		if report.get("kind","")=="correction":detail.text+="\nCasts %d → %d; health %d → %d"%[report.before_casts,report.after_casts,report.before_hp,report.after_hp]
		if report.get("kind","")=="takeover":detail.text+="\nCheckpoint %d → tick %d; casts %d"%[report.checkpoint_tick,report.final_tick,report.after_casts]
		if report.has("created"):
			detail.text+="\nCreated "+str(report.created)
			get_editor_interface().get_file_system_dock().navigate_to_path(str(report.created)+"/preview.tscn")

func _open_issue(index:int):
	var issue:Dictionary=issues.get_item_metadata(index)
	var path:String=issue.get("source","")
	if not path.begins_with("res://"):return
	get_editor_interface().get_file_system_dock().navigate_to_path(path)
	if path.ends_with(".tscn"):get_editor_interface().open_scene_from_path(path)
	elif path.ends_with(".tres"):
		var resource:Resource=load(path)
		if resource!=null:get_editor_interface().edit_resource(resource)
	elif path.ends_with(".odin"):
		var script:Script=load(path)
		if script!=null:get_editor_interface().edit_script(script,int(issue.get("line",1))-1)

func _cancel():
	if pid>0 and not result_path.is_empty():
		var file:=FileAccess.open(result_path.get_basename()+".cancel",FileAccess.WRITE)
		if file!=null:file.store_string("cancel")
		detail.text="Cancelling…"

func _choose_recording():
	var dialog:=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.rplrec; Replay recording"])
	dialog.file_selected.connect(func(path:String):selection.text=path;dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog);dialog.popup_centered_ratio(.7)
