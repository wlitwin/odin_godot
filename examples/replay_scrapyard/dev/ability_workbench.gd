extends Node

@export var ability:Resource
var preview:Node
var encounter:Node
var layer:CanvasLayer
var message:Label
var latency:OptionButton
var selected:LineEdit
var pid:int=-1
var result_path:String=""
var toolchain:Dictionary={}
var clock:float=0

func _ready():
	toolchain=JSON.parse_string(FileAccess.get_file_as_string("res://addons/replay_authoring/toolchain.json"))
	layer=CanvasLayer.new();layer.layer=5;add_child(layer)
	var box:=VBoxContainer.new();box.position=Vector2(990,12);box.custom_minimum_size=Vector2(278,0);layer.add_child(box)
	var title:=Label.new();title.text="Ability Authoring Workbench";box.add_child(title)
	selected=LineEdit.new();selected.text=ability.resource_path if ability!=null else "res://data/abilities/salvefield.tres";box.add_child(selected)
	button(box,"Load selected ability",load_selected)
	button(box,"Run isolated encounter",start_encounter)
	button(box,"Return to preview",stop_encounter)
	button(box,"Export reproduction",export_recording)
	button(box,"Verify last reproduction",run_job.bind("verify"))
	latency=OptionButton.new();latency.add_item("Local — 0 ms",0);latency.add_item("Typical — 80 ms",80);latency.add_item("Adverse — 150 ms",150);box.add_child(latency)
	button(box,"Run network encounter",run_job.bind("network"))
	button(box,"Replay rejected prediction",run_job.bind("correction"))
	button(box,"Test checkpoint takeover",run_job.bind("takeover"))
	button(box,"Cancel test job",cancel_job)
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.text="Edit and save the definition in Godot, then refresh the preview. Encounters admit a separate copy.";box.add_child(message)
	load_selected()

func button(parent:Node,text:String,callback:Callable):
	var item:=Button.new();item.text=text;item.pressed.connect(callback);parent.add_child(item)
func load_selected():
	if encounter!=null:return
	var resource:Resource=ResourceLoader.load(selected.text,"",ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if resource==null:message.text="Could not load the selected definition.";return
	ability=resource
	if preview==null:
		preview=load("res://dev/ability_preview.tscn").instantiate();preview.definition=ability;add_child(preview)
	else:preview.definition=ability;preview.preview_refresh()
func start_encounter():
	if encounter!=null or ability==null:return
	if preview!=null:preview.queue_free();preview=null
	encounter=load("res://dev/workbench.tscn").instantiate()
	encounter.ability=ability;encounter.cast_on_start=true;encounter.hurt=true
	add_child(encounter);message.text="Starting isolated encounter through normal profile, ready and cast actions…"
func stop_encounter():
	if encounter!=null:encounter.queue_free();encounter=null;await get_tree().process_frame
	load_selected()
func export_recording():
	if encounter==null or not encounter.export_recording():message.text="Start and stage an encounter first.";return
	message.text="Export requested: user://workbench.rplrec"
func run_job(action:String):
	if pid>0:return
	var base:=ProjectSettings.globalize_path("res://.godot/replay_authoring/jobs/workbench-%s"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(base);result_path=base+"/result.json"
	var selection:=ProjectSettings.globalize_path("user://workbench.rplrec") if action=="verify" else selected.text
	var args:=PackedStringArray([ProjectSettings.globalize_path("res://tools/authoring.py"),"--project",ProjectSettings.globalize_path("res://"),"--framework",toolchain.framework,"--godot",OS.get_executable_path(),"--result",result_path,action,"--selection",selection,"--latency",str(latency.get_selected_id())])
	pid=OS.create_process(toolchain.python,args);message.text="Starting "+action+"…"
func _process(_dt:float):
	if pid>0 and FileAccess.file_exists(result_path):
		var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(result_path))
		message.text=str(report.get("message","Working…"))
		if report.get("kind","")=="correction":message.text+="\nCasts %d → %d; health %d → %d"%[report.before_casts,report.after_casts,report.before_hp,report.after_hp]
		if report.get("kind","")=="takeover":message.text+="\nCheckpoint %d → tick %d; casts %d"%[report.checkpoint_tick,report.final_tick,report.after_casts]
		if not OS.is_process_running(pid):pid=-1
	elif pid>0 and not OS.is_process_running(pid):pid=-1;message.text="Job stopped without a report. Inspect .godot/replay_authoring/jobs."
func cancel_job():
	if pid>0:
		var file:=FileAccess.open(result_path.get_basename()+".cancel",FileAccess.WRITE);file.store_string("cancel")
func _exit_tree():cancel_job()
