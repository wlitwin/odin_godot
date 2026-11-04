extends SceneTree
# One pre-GO SDK callback test. No Client, frame/pump/step/reset or allocator reset.
const WARMUP_PAIRS: int=128
const BATCH_PAIRS: int=10000
var _sample: Node
var _errors: Array[String]=[]
var _before: Array[int]=[0,0,0]
var _middle: Array[int]=[0,0,0]
var _after: Array[int]=[0,0,0]
var _heap_before: int=0
var _heap_middle: int=0
var _heap_after: int=0
var _frontier_before: Dictionary={}
var _frontier_after: Dictionary={}
var _closed: bool=false
var _freed: bool=false
var _measured: bool=false
var _before_available: bool=false
var _middle_available: bool=false
var _after_available: bool=false

func _initialize() -> void:
	call_deferred("_run")

func _pair() -> bool:
	# Both actual converted method returns die at this function's return.
	var status_value: Variant=_sample.call("status")
	var presentation_value: Variant=_sample.call("presentation")
	return status_value is String and presentation_value is String

func _batch(count: int) -> bool:
	for _index: int in range(count):
		if not _pair():return false
	return true

func _temp_snapshot(destination: Array[int]) -> bool:
	if _sample.call("callback_temp_available")!=true:return false
	var used: Variant=_sample.call("callback_temp_used")
	var capacity: Variant=_sample.call("callback_temp_capacity")
	var count: Variant=_sample.call("callback_temp_count")
	if not used is int or not capacity is int or not count is int:return false
	if used<0 or capacity<0 or count<0:return false # unavailable sentinel, never an observed zero
	destination[0]=used;destination[1]=capacity;destination[2]=count
	return true

func _frontier(validate_presentation: bool) -> Dictionary:
	var encoded: Variant=_sample.call("status")
	if not encoded is String:return {}
	var value: Variant=JSON.parse_string(encoded)
	if not value is Dictionary or value.get("version",0)!=1:return {}
	if String(value.get("framework","")).to_lower()!=OS.get_environment("BOX3D_CALLBACK_FRAMEWORK"):return {}
	if value.get("role","")!="host" or value.get("go",true)!=false or value.get("error","")!="":return {}
	if not value.get("frames") is float and not value.get("frames") is int:return {}
	if value.frames!=0:return {}
	if validate_presentation:
		var presentation_text: Variant=_sample.call("presentation")
		if not presentation_text is String:return {}
		var presentation: Variant=JSON.parse_string(presentation_text)
		if not presentation is Dictionary or presentation.get("version",0)!=1 or not presentation.get("bodies") is Array:return {}
	# Null frontiers in an initialized pre-roster Kit Host remain null, never set.
	return {"head":value.get("head"),"confirmed":value.get("confirmed"),"epoch":value.get("epoch"),"go":value.go,"frames":value.frames,"phase":value.get("phase")}

func _finish() -> void:
	if _sample!=null:
		var weak: WeakRef=weakref(_sample)
		var close_result: Variant=_sample.call("close")
		_closed=close_result is bool and close_result
		if not _closed:_errors.append("actual public close failed")
		_sample.free();_sample=null
		_freed=weak.get_ref()==null
		if not _freed:_errors.append("source Sample Node not freed")
	var result: Dictionary={"version":1,"framework":OS.get_environment("BOX3D_CALLBACK_FRAMEWORK"),"ok":_errors.is_empty() and _measured and _closed and _freed,"errors":_errors,"warmup_pairs":WARMUP_PAIRS,"pairs_per_batch":BATCH_PAIRS,"batches":2,"tls_fields":["total_used","total_capacity","temp_count"],"tls_available":_measured,"tls_before":_before if _before_available else null,"tls_middle":_middle if _middle_available else null,"tls_after":_after if _after_available else null,"godot_heap_before":_heap_before,"godot_heap_middle":_heap_middle,"godot_heap_after":_heap_after,"frontier_before":_frontier_before,"frontier_after":_frontier_after,"checked_close":_closed,"node_freed":_freed,"scope":"actual SDK producer TLS and Godot static heap; no RSS/Native quota/performance/physics qualification"}
	print("CALLBACK_LIFETIME_RESULT ",JSON.stringify(result,"",true,true))
	quit(0 if result.ok else 1)

func _run() -> void:
	var packed: PackedScene=load("res://main.tscn")
	if packed==null:_errors.append("actual authored sample scene missing");_finish();return
	_sample=packed.instantiate()
	# Ready executes normally; the real Host opens before GO. No process callback
	# or child presentation loop runs, and no SceneTree await advances this test.
	_sample.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(_sample)
	for method: String in ["status","presentation","close","callback_temp_available","callback_temp_used","callback_temp_capacity","callback_temp_count"]:
		if not _sample.has_method(method):_errors.append("missing actual method: "+method);_finish();return
	_frontier_before=_frontier(true)
	if _frontier_before.is_empty():_errors.append("real initialized pre-GO Host/JSON unavailable");_finish();return
	if not _batch(WARMUP_PAIRS):_errors.append("warmup return is not a String");_finish();return
	_before_available=_temp_snapshot(_before)
	if not _before_available:_errors.append("producer TLS unavailable before batch");_finish();return
	_heap_before=OS.get_static_memory_usage()
	if not _batch(BATCH_PAIRS):_errors.append("batch1 return is not a String");_finish();return
	_middle_available=_temp_snapshot(_middle)
	if not _middle_available:_errors.append("producer TLS unavailable after batch1");_finish();return
	_heap_middle=OS.get_static_memory_usage()
	if not _batch(BATCH_PAIRS):_errors.append("batch2 return is not a String");_finish();return
	_after_available=_temp_snapshot(_after)
	if not _after_available:_errors.append("producer TLS unavailable after batch2");_finish();return
	_heap_after=OS.get_static_memory_usage();_measured=true
	if _before!=_middle or _middle!=_after:_errors.append("producer TLS used/capacity/temp_count not restored exactly")
	if _heap_before<=0 or _heap_middle<=0 or _heap_after<=0:_errors.append("actual Godot static heap anchors unavailable")
	if _heap_after>_heap_middle:_errors.append("second identical getter batch keeps growing Godot static heap")
	_frontier_after=_frontier(false)
	if _frontier_after.is_empty() or _frontier_after!=_frontier_before:_errors.append("actual pre-GO frontier changed during getter-only batches")
	_finish()
