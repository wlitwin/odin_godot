extends SceneTree
# TEST ONLY timing-preparation driver. Functional.gd never loads this script.
# Requires a NEW explicit Root grant before execution; no execution authorized
# by merely compiling or staging this file.
const Raw = preload("res://lossless_json.gd")
func _initialize() -> void:
	process_frame.connect(run,CONNECT_ONE_SHOT)
func fence_ok(text: String) -> bool:
	var split: Dictionary = Raw.fields(text)
	if not split.get("ok",false): return false
	for path in split.fields:
		if FileAccess.get_sha256(path)!=JSON.parse_string(split.fields[path]): return false
	return true
func cleanup_ok(text: String) -> bool:
	return Raw.token(text,"all_explicit_drops_ok")=="true" and Raw.token(text,"stats_ok")=="true" and Raw.token(text,"native_live_bytes")=="0" and Raw.token(text,"snapshot_live_bytes")=="0" and Raw.token(text,"host_application_live_bytes")=="0" and Raw.token(text,"ledger_reserved_bytes")=="0"
func run() -> void:
	var grant := OS.get_environment("GATE_B_EXCLUSIVE_GRANT")
	var kind := OS.get_environment("GATE_B_NORMAL_KIND")
	if OS.get_environment("GATE_B_MODE")!="profile" or grant.is_empty() or not kind in ["client_prediction","authority_step_with_due_signature"]:
		push_error("Normal19 driver requires explicit Root profile grant and exact A/B kind")
		quit(1)
		return
	var metadata := FileAccess.get_file_as_string(OS.get_environment("GATE_B_META"))
	var run_id := OS.get_environment("GATE_B_RUN_ID")
	var source_fences: String = Raw.token(metadata,"source_files")
	var binary_fences: String = Raw.token(metadata,"binary_files")
	var included: String = Raw.token(Raw.token(metadata,"boundary"),"included_work")
	var all_ok := true
	var all_cleanup := true
	var samples := 0
	var operations := 0
	var last_facts := "{}"
	var last_cleanup := "{}"
	var last_prepare := 0
	for index in range(19):
		var node := Node.new()
		node.set_script(load("res://scripts/client_a.odin"));root.add_child(node)
		var images := int(node.call("native_images"))
		if index==0:
			print(Raw.compact(Raw.merge(metadata,{"event":JSON.stringify("GATE_B_META"),"schema":"1","run_id":JSON.stringify(run_id),"timing_mode":JSON.stringify("profile"),"exclusive_grant":JSON.stringify(grant),"sample_plan":'{"normal":19,"repair8":0}',"execution":Raw.merge(Raw.token(metadata,"execution"),{"native_images":str(images)})},["source_files","binary_files"])))
		# Reference oracle, full reference-context teardown and candidate warmup
		# are preparation, outside the ONE public normal operation timer.
		last_prepare=int(node.call("prepare"))
		var prepared := images==1 and last_prepare==0
		var operated := false
		var started := 0
		var ended := 0
		if prepared:
			started=Time.get_ticks_usec()
			operated=bool(node.call("operation"))
			ended=Time.get_ticks_usec()
			operations+=1
		var proved := bool(node.call("proof")) if operated else false
		last_facts=str(node.call("facts"))
		if prepared:
			samples+=1
			var proof := Raw.compose({"full_state_equal":Raw.token(last_facts,"full5_equal","false"),"publication_atomic":Raw.token(last_facts,"publication_atomic","false"),"quota_ok":Raw.token(last_facts,"quota_ok","false"),"expected_complete_sha256":Raw.token(last_facts,"expected_complete_sha256"),"actual_complete_sha256":Raw.token(last_facts,"actual_complete_sha256"),"counter_kind":JSON.stringify("model_step_callback"),"return_ticks":Raw.token(last_facts,"return_ticks")})
			print(Raw.compact(Raw.merge(last_facts,{"event":JSON.stringify("GATE_B_SAMPLE"),"schema":"1","run_id":JSON.stringify(run_id),"seq":str(samples),"operation":JSON.stringify("normal"),"outer_start_us":str(started),"outer_end_us":str(ended),"whole_ns":str((ended-started)*1000),"included_work":included,"phases":"[]","proof":proof})))
		last_cleanup=str(node.call("close"))
		var clean := cleanup_ok(last_cleanup)
		node.free()
		all_ok=all_ok and prepared and operated and proved and clean
		all_cleanup=all_cleanup and clean
		# A failed operation remains a raw SAMPLE and does not get filtered.
		# Unsafe preparation/cleanup failure prevents creating another actor;
		# RESULT is then short/failed, never relabelled as nineteen successes.
		if not prepared or not clean: break
	last_cleanup=Raw.merge(last_cleanup,{"all_explicit_drops_ok":JSON.stringify(all_cleanup),"core_shutdown_clean":"null"})
	print(Raw.compact(Raw.compose({"event":JSON.stringify("GATE_B_RESULT"),"schema":"1","run_id":JSON.stringify(run_id),"sample_count":str(samples),"functional_operations":str(operations),"prepare_status":str(last_prepare),"correctness_ok":JSON.stringify(all_ok and samples==19),"source_fence_unchanged":JSON.stringify(fence_ok(source_fences)),"binary_fence_unchanged":JSON.stringify(fence_ok(binary_fences)),"cleanup":last_cleanup,"functional_proof":last_facts,"timing_status":JSON.stringify("NORMAL_ONLY_REPAIR_MISSING")})))
	quit(0 if all_ok and samples==19 else 1)
