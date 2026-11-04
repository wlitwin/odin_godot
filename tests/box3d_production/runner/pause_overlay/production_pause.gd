extends Node
# Test-only derived-project autoload. Public status getter only; never calls a
# frame/step/pump, clock setter, input, reset or network method.
var _milliseconds: int=0
var _at: int=240
var _done: bool=false
var _go_seen: bool=false
var _last_host_head: int=-1
func _ready() -> void:
	process_priority=1000000
	_milliseconds=int(OS.get_environment("BOX3D_PRODUCTION_PAUSE_MS"));_at=int(OS.get_environment("BOX3D_PRODUCTION_PAUSE_AT"))
	set_process(_milliseconds in [300,3000] and _at>0)
func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=0 and value<=216008 and floor(float(value))==float(value)
func _process(_delta: float) -> void:
	if _done:return
	var sample: Node=get_tree().current_scene
	if sample==null or not sample.has_method("status"):return
	var raw: Variant=sample.call("status")
	if not raw is String or raw.is_empty():return
	var status: Variant=JSON.parse_string(raw)
	if not status is Dictionary or status.get("version",0)!=1 or status.get("go",false)!=true or not _integer(status.get("head")) or not _integer(status.get("confirmed")):return
	var role: String=OS.get_environment("BOX3D_SAMPLE_ROLE")
	var head: int=int(status.head);var confirmed: int=int(status.confirmed)
	if not _go_seen:
		_go_seen=true
		print("SAMPLE_PRODUCTION_GO ",JSON.stringify({"version":1,"role":role,"pid":OS.get_process_id(),"head":head,"confirmed":confirmed,"status_json":raw},"",true,true))
	if role=="host":
		# At most529 real head observations, no wall-clock/polling estimate.
		# They provide a fresh observed Host boundary while Client is stopped.
		if head>_at+512:_done=true;set_process(false);return
		if head>=maxi(0,_at-16) and head!=_last_host_head:
			_last_host_head=head
			print("SAMPLE_PRODUCTION_HOST ",JSON.stringify({"version":1,"role":role,"pid":OS.get_process_id(),"head":head,"confirmed":confirmed,"status_json":raw},"",true,true))
		return
	if role!="client" or confirmed<_at:return
	_done=true
	# The actual live public head/cf below are the frozen boundary: straight-line
	# log -> synchronous self SIGSTOP, no await or Session/World advance between.
	print("SAMPLE_PRODUCTION_PAUSE ",JSON.stringify({"version":1,"role":role,"pid":OS.get_process_id(),"head":head,"confirmed":confirmed,"requested_ms":_milliseconds,"status_json":raw},"",true,true))
	var output: Array=[]
	var result: int=OS.execute("/bin/kill",PackedStringArray(["-STOP",str(OS.get_process_id())]),output,true)
	# This statement runs only after the external supervisor's SIGCONT.
	print("SAMPLE_PRODUCTION_RESUME ",JSON.stringify({"version":1,"role":role,"pid":OS.get_process_id(),"head":head,"confirmed":confirmed,"kill_exit":result},"",true,true))
	set_process(false)
