extends SceneTree

# Test-only diagnostic JSON remains original token text. In particular, no
# Native/metadata/facts numeric value enters Godot's floating JSON decoder.
const Raw = preload("res://lossless_json.gd")
var node: Node
var operations := 0
var ok := true
var run_id := OS.get_environment("GATE_B_RUN_ID")
var profiling := OS.get_environment("GATE_B_MODE") == "profile"
var observation_mode := OS.get_environment("GATE_B_OBSERVATION")
var exclusive_grant := OS.get_environment("GATE_B_EXCLUSIVE_GRANT")

func _initialize() -> void:
	process_frame.connect(run, CONNECT_ONE_SHOT)

func precision_ok(raw: String) -> bool:
	var native := Raw.token(raw,"native_raw")
	return Raw.controls() and Raw.token(raw,"synthetic_not_timing_sample")=="true" and Raw.token(native,"scope_token")=="18446744073709551615" and Raw.token(native,"domain_cookie")=="18446744073709551615" and native.contains('"start_us":9007199254740993') and raw.contains('"duration_ns":1000')

func fence_ok(raw_fields: String) -> bool:
	var split: Dictionary = Raw.fields(raw_fields)
	if not split.get("ok",false): return false
	for path in split.fields:
		# These tokens are SHA strings only, never numeric data.
		var expected = JSON.parse_string(split.fields[path])
		if not expected is String or FileAccess.get_sha256(path)!=expected: return false
	return true

func run() -> void:
	if run_id.is_empty(): run_id = "kit-functional"
	if observation_mode.is_empty(): observation_mode = "off"
	if (profiling and exclusive_grant.is_empty()) or (not profiling and observation_mode=="timed") or (profiling and observation_mode=="structure"):
		push_error("Gate B profiling requires explicit grant; functional/structure modes cannot read profile clocks")
		quit(1)
		return
	var metadata_text := FileAccess.get_file_as_string(OS.get_environment("GATE_B_META"))
	if not Raw.fields(metadata_text).get("ok",false):
		push_error("Gate B metadata missing")
		quit(1)
		return
	var source_files: String = Raw.token(metadata_text,"source_files")
	var binary_files: String = Raw.token(metadata_text,"binary_files")
	var included_work: String = Raw.token(Raw.token(metadata_text,"boundary"),"included_work")
	node = Node.new()
	node.set_script(load("res://scripts/probe.odin"))
	root.add_child(node)
	var images := int(node.call("native_images"))
	ok = images == 1
	if ok: ok = int(node.call("prepare")) == 0
	var summary := str(node.call("observation",false))
	var precision := str(node.call("precision"))
	var producer_precision_applicable := Raw.token(summary,"compiled","false")=="true"
	var composer_precision_ok := Raw.controls()
	var producer_precision_ok := precision_ok(precision) if producer_precision_applicable else false
	ok = ok and composer_precision_ok and (not producer_precision_applicable or producer_precision_ok)
	if not producer_precision_applicable and observation_mode!="off": ok = false
	var descriptor := str(node.call("descriptor"))
	var fixture: String = Raw.token(metadata_text,"fixture")
	if Raw.token(descriptor,"descriptor_sha256")!="null":
		fixture=Raw.merge(fixture,{"static_descriptor_sha256":Raw.token(fixture,"descriptor_sha256"),"descriptor_sha256":Raw.token(descriptor,"descriptor_sha256"),"accepted_trajectory_sha256":Raw.token(descriptor,"accepted_trajectory_sha256"),"accepted_rows":Raw.token(descriptor,"accepted_rows")})
	var replacements := {"event":JSON.stringify("GATE_B_META"),"schema":"1","run_id":JSON.stringify(run_id),"timing_mode":JSON.stringify("profile" if profiling else "functional_only"),"sample_plan":'{"normal":0,"repair8":19}' if profiling else '{"normal":0,"repair8":0}',"measurement_windows":JSON.stringify({"kind":"fresh_v2_same_suffix","base_tick":154,"head_tick":162,"repair_samples":19,"final_untimed_oracle_tick":162}),"execution":Raw.merge(Raw.token(metadata_text,"execution"),{"native_images":str(images)}),"fixture":fixture,"native_observation":summary}
	if profiling: replacements["exclusive_grant"]=JSON.stringify(exclusive_grant)
	print(Raw.compact(Raw.merge(metadata_text,replacements,["source_files","binary_files"])))
	if ok: ok = bool(node.call("start"))
	var sample_count := 0
	var functional_scopes: Array = []
	for _index in range(20):
		if not ok: break
		ok = bool(node.call("predict"))
		var started := 0
		var ended := 0
		var operation_ok := false
		if ok:
			if profiling and _index<19: started = Time.get_ticks_usec()
			operation_ok = bool(node.call("apply",profiling and _index<19))
			if profiling and _index<19: ended = Time.get_ticks_usec()
		var operation_summary := str(node.call("observation",true))
		var native_raw := "null"
		var phases := "[]"
		if observation_mode!="off": native_raw = str(node.call("native_spans"))
		if profiling and observation_mode=="timed" and _index<19: phases = str(node.call("native_phases"))
		if not profiling and observation_mode!="off": functional_scopes.append(native_raw)
		operations += 1
		var oracle_ok := bool(node.call("proof")) if operation_ok else false
		ok = operation_ok and oracle_ok and Raw.token(operation_summary,"valid","false")=="true"
		if profiling and _index<19:
			var facts := str(node.call("facts"))
			sample_count += 1
			var proof := Raw.compose({"full_state_equal":Raw.token(facts,"full_state_equal"),"publication_atomic":Raw.token(facts,"publication_atomic"),"quota_ok":Raw.token(facts,"quota_ok"),"expected_complete_sha256":Raw.token(facts,"expected_complete_sha256"),"actual_complete_sha256":Raw.token(facts,"actual_complete_sha256")})
			var sample_fields := {"event":JSON.stringify("GATE_B_SAMPLE"),"schema":"1","run_id":JSON.stringify(run_id),"seq":str(sample_count),"operation":JSON.stringify("repair8"),"outer_start_us":str(started),"outer_end_us":str(ended),"whole_ns":str((ended-started)*1000),"included_work":included_work,"phases":phases,"proof":proof}
			if observation_mode=="timed": sample_fields["native_observation"]=native_raw
			print(Raw.compact(Raw.merge(facts,sample_fields)))
	var facts := str(node.call("facts")) if ok else "{}"
	var final_summary := str(node.call("observation",false))
	var final_raw := str(node.call("native_spans")) if observation_mode!="off" else "null"
	var failure := str(node.call("failure"))
	var cleanup := str(node.call("close"))
	ok = ok and Raw.token(cleanup,"all_explicit_drops_ok")=="true" and Raw.token(cleanup,"stats_ok")=="true" and Raw.token(cleanup,"native_live_bytes")=="0" and Raw.token(cleanup,"snapshot_live_bytes")=="0" and Raw.token(cleanup,"host_application_live_bytes")=="0" and Raw.token(cleanup,"ledger_reserved_bytes")=="0"
	node.free()
	# Core shutdown is unknown until actual process exit; the controller seals
	# only that independently observed boolean, preserving all numeric tokens.
	cleanup=Raw.merge(cleanup,{"core_shutdown_clean":"null"})
	print(Raw.compact(Raw.compose({"event":JSON.stringify("GATE_B_RESULT"),"schema":"1","run_id":JSON.stringify(run_id),"sample_count":str(sample_count),"functional_operations":str(operations),"correctness_ok":JSON.stringify(ok),"source_fence_unchanged":JSON.stringify(fence_ok(source_files)),"binary_fence_unchanged":JSON.stringify(fence_ok(binary_files)),"cleanup":cleanup,"functional_proof":facts,"native_observation":final_raw,"native_observation_summary":final_summary,"native_clock_prewarm_calls":Raw.token(final_summary,"clock_prewarm_reads","0"),"native_functional_scopes":Raw.array(functional_scopes),"producer_precision_applicable":JSON.stringify(producer_precision_applicable),"composer_precision_ok":JSON.stringify(composer_precision_ok),"producer_precision_ok":JSON.stringify(producer_precision_ok) if producer_precision_applicable else "null","producer_precision_control":precision,"producer_uint64_edges":Raw.array(Raw.UINT64_EDGES),"failure_facts":failure,"timing_status":JSON.stringify("REPAIR_ONLY_NORMAL_MISSING" if profiling else "NOT_MEASURED")})))
	quit(0 if ok else 1)
