extends SceneTree
const Raw = preload("res://lossless_json.gd")
func _initialize() -> void:
	process_frame.connect(run,CONNECT_ONE_SHOT)
func fence_ok(text: String) -> bool:
	var split: Dictionary = Raw.fields(text)
	if not split.get("ok",false): return false
	for path in split.fields:
		if FileAccess.get_sha256(path)!=JSON.parse_string(split.fields[path]): return false
	return true
func run() -> void:
	# FUNCTIONAL ONLY. This script contains NO clock read or SAMPLE path.
	var metadata: String = FileAccess.get_file_as_string(OS.get_environment("GATE_B_META"))
	var run_id := OS.get_environment("GATE_B_RUN_ID")
	var source_fences: String = Raw.token(metadata,"source_files")
	var binary_fences: String = Raw.token(metadata,"binary_files")
	var node := Node.new()
	node.set_script(load("res://scripts/client_a.odin"));root.add_child(node)
	var images := int(node.call("native_images"))
	var regression := OS.get_environment("GATE_B_NORMAL_KIND")=="default_repair"
	print(Raw.compact(Raw.merge(metadata,{"event":JSON.stringify("GATE_B_META"),"schema":"1","run_id":JSON.stringify(run_id),"timing_mode":JSON.stringify("functional_only"),"sample_plan":'{"normal":0,"repair8":0}',"execution":Raw.merge(Raw.token(metadata,"execution"),{"native_images":str(images)})},["source_files","binary_files"])))
	var prepare := int(node.call("prepare"))
	var attempted := prepare==0 and images==1
	var operated := bool(node.call("operation")) if attempted else false
	var proved := bool(node.call("proof")) if operated else false
	var facts := str(node.call("facts"))
	var cleanup := str(node.call("close"))
	var clean := Raw.token(cleanup,"all_explicit_drops_ok")=="true" and Raw.token(cleanup,"stats_ok")=="true" and Raw.token(cleanup,"native_live_bytes")=="0" and Raw.token(cleanup,"snapshot_live_bytes")=="0" and Raw.token(cleanup,"host_application_live_bytes")=="0" and Raw.token(cleanup,"ledger_reserved_bytes")=="0"
	node.free()
	cleanup=Raw.merge(cleanup,{"core_shutdown_clean":"null"})
	print(Raw.compact(Raw.compose({"event":JSON.stringify("GATE_B_RESULT"),"schema":"1","run_id":JSON.stringify(run_id),"sample_count":"0","functional_operations":("20" if regression else "1") if attempted else "0","prepare_status":str(prepare),"correctness_ok":JSON.stringify(operated and proved and clean),"source_fence_unchanged":JSON.stringify(fence_ok(source_fences)),"binary_fence_unchanged":JSON.stringify(fence_ok(binary_fences)),"cleanup":cleanup,"functional_proof":facts,"timing_status":JSON.stringify("NOT_MEASURED")})))
	quit(0 if operated and proved and clean else 1)
