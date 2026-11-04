extends SceneTree
# Outer timer is before actual Core entry and after the full return. Optional
# phase hooks stay OFF for the first baseline. Required operation work is inside.
var probe
func _initialize(): call_deferred("run")
func run():
    var meta_text = FileAccess.get_file_as_string(OS.get_environment("GATE_B_META_FILE"))
    var measured = OS.get_environment("GATE_B_TIMING_MODE") == "profile"
    if measured and OS.get_environment("GATE_B_PROFILE_APPROVED") != "1":
        push_error("No Root exclusive profiling grant")
        quit(2)
        return
    probe = load("res://main.tscn").instantiate()
    root.add_child(probe)
    var images = int(probe.call("probe_native_images"))
    var contract = JSON.parse_string(probe.call("probe_native_contract"))
    var version = Engine.get_version_info()
    var actual_os = OS.get_name().to_lower()
    var actual_arch = Engine.get_architecture_name()
    var actual_godot = str(version.get("string",""))
    var actual_meta_object = JSON.parse_string(meta_text)
    if contract.status != 0 or contract.build != actual_meta_object.identity.native_build_sha256 or contract.target != actual_meta_object.identity.native_target_sha256:
        push_error("Actual Native contract differs from verified build evidence")
        probe.call("probe_cleanup")
        quit(2)
        return
    # Replace only runtime facts as JSON scalar text, preserving all integer types.
    meta_text = meta_text.strip_edges().replace('"native_images": null','"native_images": %d' % images)
    meta_text = meta_text.replace('"os": null','"os": '+JSON.stringify(actual_os))
    meta_text = meta_text.replace('"arch": null','"arch": '+JSON.stringify(actual_arch))
    meta_text = meta_text.replace('"godot": null','"godot": '+JSON.stringify(actual_godot))
    var actual_meta = FileAccess.open(OS.get_environment("GATE_B_ACTUAL_META_FILE"),FileAccess.WRITE)
    actual_meta.store_string(meta_text)
    actual_meta.close()
    var identity = actual_meta_object.identity.duplicate()
    identity.os = actual_os
    identity.arch = actual_arch
    identity.godot = actual_godot
    var execution = actual_meta_object.execution.duplicate()
    execution.native_images = images
    var runtime_text = '{"execution":'+JSON.stringify(execution)+',"identity":'+JSON.stringify(identity)+',"image_census_observed":true,"pid":%d,"native_contract":%s,"image_census_method":"loaded process image census in test-only producer"}' % [OS.get_process_id(),JSON.stringify(contract)]
    var runtime_file = FileAccess.open(OS.get_environment("GATE_B_RUNTIME_FILE"),FileAccess.WRITE)
    runtime_file.store_string(runtime_text)
    runtime_file.close()
    print(meta_text)
    if images != 1:
        push_error("Expected exactly one actual Native shared image")
        probe.call("probe_cleanup")
        quit(2)
        return
    var operations = 19 if measured else 1
    var summaries = []
    var success = true
    for index in range(operations):
        # Fresh public initialization/history and input preparation is outside
        # this operation timer. Every attempt remains, including prepare errors.
        var prepared = probe.call("probe_prepare")
        var preparation_diagnostics = probe.call("probe_preparation_diagnostics")
        var allocations_before = probe.call("probe_allocations")
        var started = 0
        var ended = 0
        if measured: started = Time.get_ticks_usec()
        var status = probe.call("probe_repair")
        if measured: ended = Time.get_ticks_usec()
        var allocations_after = probe.call("probe_allocations")
        var verified = -1
        if prepared == 0 and status == 0:
            verified = probe.call("probe_verify") # EXTRA independent source-byte oracle
        if measured:
            print(probe.call("probe_records",index+1,started,ended))
        var closed = probe.call("probe_cleanup") # persistent fixture teardown, not temps
        var raw = probe.call("probe_result")
        # Odin emits integers; append statuses textually without float conversion.
        raw = raw.trim_suffix("}") + ',"prepare_status":%d,"repair_status":%d,"verify_status":%d,"cleanup_status":%d,"allocation_before":%s,"allocation_after":%s,"preparation_diagnostics":%s}' % [prepared,status,verified,closed,allocations_before,allocations_after,preparation_diagnostics]
        summaries.append(raw)
        if prepared != 0 or status != 0 or verified != 0 or closed != 0 or not JSON.parse_string(allocations_before).ok or not JSON.parse_string(allocations_after).ok: success = false
    var output = FileAccess.open(OS.get_environment("GATE_B_RESULT_FILE"),FileAccess.WRITE)
    output.store_string('[' + ','.join(summaries) + ']')
    output.close()
    quit(0 if success else 1)
