"""Gate B test-only record validation. No clocks, Native, simulation or I/O hooks."""
from __future__ import annotations
import json
import re

SCHEMA = 1
CEILING_NS = 4_000_000
TRACKED_BYTES = 67_108_864
PROFILES = {
    "dense32_boxes_extra_sphere": ("504859534e455431", 141),
    "common32_spheres_crates_extra_capsule": ("534c494345503031", 122),
}
NORMAL_WORK = frozenset(("public_dispatch", "normal_step_capture_admission", "required_serialization",
                        "publication_events", "operation_cleanup", "core_return"))
REPAIR_WORK = frozenset(("public_dispatch", "envelope_reassembly_inspect", "canonical_native_read_build_verify_reencode",
                        "typed_decode", "accepted_input_replay", "complete_paired_compare", "publication_events",
                        "operation_cleanup", "core_return"))
KIT_V2_REPAIR_WORK = (REPAIR_WORK - {"canonical_native_read_build_verify_reencode"}) | {
    "canonical_five_part_signature_verification"}
KIT_V2_REPAIR_COUNTERS = ("accepted_packets", "signature_packets", "signatures_before", "signatures_after",
                          "full_states_before", "full_states_after")
LIMITS = dict(normal_ns=CEILING_NS, repair8_ns=CEILING_NS, hz=60, substeps=4, history=128,
              prediction=8, ordinary_repair=8, bodies=35, shapes=35, contacts=147, joints=1,
              tracked_bytes=TRACKED_BYTES)
FULL_ENTRIES = frozenset(("session_frame", "link_pump_then_client_pump", "session_dispatch_then_lane_frame"))
NORMAL_ENTRIES = {
    "client_prediction_send": "link_pump_then_client_step",
    "authority_step_requested_canonical": "server_step_then_requested_snapshot_pump",
}
NORMAL_STEP_OBSERVATION = "committed_tick_require_step"
NATIVE_PHASE_NAMES = {
    1:"native.step.fixed", 2:"native.snapshot.capture", 3:"native.snapshot.serialize",
    4:"native.snapshot.normalize", 5:"native.snapshot.finalize", 6:"native.snapshot.validate",
    7:"native.admission.world", 8:"native.recovery.read", 9:"native.recovery.parse_validate",
    10:"native.recovery.build", 11:"native.recovery.verify_reencode", 12:"native.recovery.write",
}
NATIVE_STATUS_NAMES = {str(-(2**31)):"UNAVAILABLE", **{
    str(i):"OGB3_"+name for i,name in enumerate(("OK","INVALID_ARGUMENT","INVALID_HANDLE",
    "OUT_OF_MEMORY","CAPACITY","UNSUPPORTED","INCOMPATIBLE","CORRUPT"))}}
NATIVE_U32 = ("abi_version","struct_bytes","mode","capacity","count","stack_depth","error_flags","state")
NATIVE_U64 = ("scope_token","domain_cookie","next_span_id","root_count","clock_reads",
              "clock_errors","overflow_count","nesting_errors","last_clock_us","phase_mask")
NATIVE_SPAN_KEYS = frozenset(("id","parent_id","root_ordinal","phase","native_status","start_us","end_us"))
NATIVE_BLOCK_KEYS = frozenset((*NATIVE_U32,*NATIVE_U64,"stack","spans"))
NATIVE_PHASE_EXTRAS = frozenset(("native_span_id","native_parent_id","native_root_ordinal","native_phase","native_status"))
HASH = re.compile(r"[0-9a-f]{64}\Z")


class RecordError(ValueError): pass


def require(value, message):
    if not value: raise RecordError(message)


def integer(value, name, minimum=0):
    require(type(value) is int and value >= minimum, f"{name}: expected integer >= {minimum}")
    return value


def boolean(value, name):
    require(type(value) is bool, f"{name}: expected boolean")
    return value


def text(value, name):
    require(isinstance(value, str) and 0 < len(value) <= 4096, f"{name}: expected bounded nonempty string")
    return value


def digest(value, name, nullable=False):
    if nullable and value is None: return
    require(isinstance(value, str) and HASH.fullmatch(value) and value != "0" * 64, f"{name}: invalid/zero SHA256")


def strict_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"duplicate JSON key {key}")
            result[key] = value
        return result
    def invalid(value): raise RecordError("nonfinite JSON number " + value)
    value = json.loads(data, object_pairs_hook=pairs, parse_constant=invalid)
    require(isinstance(value, dict), "record must be an object")
    return value


def envelope(record, event, run_id=None):
    require(record.get("schema") == SCHEMA and type(record.get("schema")) is int, "schema must be integer1")
    require(record.get("event") == event, f"expected {event}")
    text(record.get("run_id"), "run_id")
    require(len(record["run_id"]) <= 128, "run_id length limit")
    if run_id is not None: require(record["run_id"] == run_id, "run_id changed")


def _kit_v2(meta):
    if not isinstance(meta, dict) or meta.get("framework") != "kit": return False
    descriptor = meta.get("descriptor")
    return (isinstance(descriptor, dict) and type(descriptor.get("wire_revision")) is int and
            descriptor["wire_revision"] == 2)


def validate_native_meta(meta):
    observer=meta["native_observer"]
    fixed=dict(abi_version=1,block_bytes=49392,span_bytes=48,capacity=1024,stack_capacity=16,
        phase_mask=4095,native_static_bytes=48,binding_control_bytes=32,clock_binding_static_bytes=24,
        meter_context_bytes=219928)
    require(set(observer)==set(fixed)|{"mode","clock_domain","source_phase_map","overhead","native_status_names"},"native observer metadata keys changed")
    require(all(type(observer[k]) is int and observer[k]==v for k,v in fixed.items()),"native ABI/storage/mask labels changed")
    require(observer["clock_domain"]=="godot_ticks_usec" and observer["overhead"]=="inside_whole","native clock/overhead scope changed")
    require(observer["native_status_names"]==NATIVE_STATUS_NAMES,"native status names/sentinel changed")
    if meta["timing_mode"]=="functional_only":
        require(observer["mode"] in ("off","structure_only"),"functional metadata cannot enable timed Native")
    else:
        require(observer["mode"]=="timed","profile Native observation must declare timed mode")
        text(meta.get("exclusive_grant"),"actual exclusive grant label")
    mapping=observer["source_phase_map"]
    require(isinstance(mapping,list) and len(mapping)==12,"native selected phase map must contain phases1..12")
    sources={item["path"]:item["sha256"] for item in meta["boundary"]["source_refs"]}
    for number,item in enumerate(mapping,1):
        require(set(item)=={"phase","name","path","symbol","sha256"},"native phase source keys changed")
        require(type(item["phase"]) is int and item["phase"]==number and item["name"]==NATIVE_PHASE_NAMES[number],"native phase id/name/order mismatch")
        text(item["symbol"],"native source symbol");text(item["path"],"native source path");digest(item["sha256"],"native source SHA")
        require(sources.get(item["path"])==item["sha256"],"native phase source not bound in boundary source_refs")


def validate_native_block(block):
    require(isinstance(block,dict) and set(block)==NATIVE_BLOCK_KEYS,"raw Native block/header keys changed")
    for names,bits in ((NATIVE_U32,32),(NATIVE_U64,64)):
        for name in names:require(type(block[name]) is int and 0<=block[name]<2**bits,"Native "+name+": integer width/precision lost")
    require(block["count"]<=1024 and block["stack_depth"]<=16,"Native raw count/depth bound")
    require(isinstance(block["stack"],list) and len(block["stack"])==16,"raw Native stack must have16 entries")
    for value in block["stack"]:require(type(value) is int and 0<=value<2**64,"Native stack ID precision lost")
    spans=block["spans"]
    require(isinstance(spans,list) and len(spans)==block["count"],"raw Native spans/count mismatch")
    for span in spans:
        require(isinstance(span,dict) and set(span)==NATIVE_SPAN_KEYS,"raw Native span must have exact7keys")
        for name in NATIVE_SPAN_KEYS-{"native_status"}:
            require(type(span[name]) is int and 0<=span[name]<2**(32 if name=="phase" else 64),"Native span "+name+": integer width/precision lost")
        require(type(span["native_status"]) is int and -(2**31)<=span["native_status"]<2**31,"Native signed status width/precision lost")


def native_findings(block, expected_mode, outer=None):
    """Observation errors only; never mutate the actual game outcome/proof."""
    findings=[]
    for name,value in dict(abi_version=1,struct_bytes=49392,mode=expected_mode,capacity=1024,state=2,phase_mask=4095).items():
        if block[name]!=value:findings.append("Native observation "+name+" mismatch")
    if any(block[k] for k in ("error_flags","clock_errors","overflow_count","nesting_errors","stack_depth")) or any(block["stack"]):
        findings.append("Native observation error/overflow/nesting/uncLOSED stack")
    if not block["scope_token"] or not block["domain_cookie"] or block["next_span_id"]!=block["count"]+1:
        findings.append("Native observation token/cookie/next-ID invalid")
    if not block["count"]:findings.append("Native observation captured no selected spans")
    roots=[];seen={}
    for index,span in enumerate(block["spans"],1):
        if span["id"]!=index or span["phase"] not in NATIVE_PHASE_NAMES:
            findings.append("Native span ID/selected phase invalid");continue
        if str(span["native_status"]) not in NATIVE_STATUS_NAMES:findings.append("Native status unavailable/unknown encoding")
        parent=seen.get(span["parent_id"])
        if span["parent_id"]:
            if parent is None or parent["root_ordinal"]!=span["root_ordinal"]:
                findings.append("Native parent/root reference invalid")
            elif expected_mode==2 and not parent["start_us"]<=span["start_us"]<=span["end_us"]<=parent["end_us"]:
                findings.append("Native child outside parent clock interval")
        else:
            roots.append(span)
            if span["root_ordinal"]!=len(roots):findings.append("Native root ordinal invalid")
        if expected_mode==1:
            if span["start_us"] or span["end_us"]:findings.append("structure-only Native fabricated time")
        elif outer is not None and not outer[0]<=span["start_us"]<=span["end_us"]<=outer[1]:
            findings.append("Native span outside whole clock")
        seen[span["id"]]=span
    if block["root_count"]!=len(roots):findings.append("Native root count invalid")
    if expected_mode==1:
        if block["clock_reads"] or block["last_clock_us"]:findings.append("functional Native added clock reads")
    else:
        if block["clock_reads"]!=2*block["count"]:findings.append("Native clock read count differs from actual span boundaries")
        if block["last_clock_us"]!=max((s["end_us"] for s in block["spans"]),default=0):findings.append("Native last clock mismatch")
        if any(a["end_us"]>b["start_us"] for a,b in zip(roots,roots[1:])):findings.append("Native root intervals overlap")
    return findings


def validate_native_sample(meta,sample):
    block=sample.get("native_observation");validate_native_block(block)
    derived=[p for p in sample["phases"] if "native_span_id" in p or p["name"].startswith("native.")]
    invalid=any(block[k] for k in ("error_flags","clock_errors","overflow_count","nesting_errors","stack_depth"))
    if invalid and not derived:return # Raw is retained and native_findings FAILS; no fabricated/unsigned-invalid durations.
    require(len(derived)==block["count"],"Native raw/derived phases not one-for-one")
    by_id={}
    keys={"name","duration_ns","clock_domain","start_us","end_us","relation"}|NATIVE_PHASE_EXTRAS
    for phase in derived:
        require(set(phase)==keys,"Native derived phase keys changed")
        for name in NATIVE_PHASE_EXTRAS:
            integer(phase[name],name,-2**31 if name=="native_status" else 0)
        require(phase["native_span_id"] not in by_id,"duplicate Native derived phase")
        by_id[phase["native_span_id"]]=phase
    for span in block["spans"]:
        phase=by_id.get(span["id"])
        require(phase is not None and phase["name"]==NATIVE_PHASE_NAMES.get(span["phase"]) and
                phase["relation"]=="native_nested_in_whole" and phase["clock_domain"]=="godot_ticks_usec" and
                phase["native_parent_id"]==span["parent_id"] and phase["native_root_ordinal"]==span["root_ordinal"] and
                phase["native_phase"]==span["phase"] and phase["native_status"]==span["native_status"] and
                phase["start_us"]==span["start_us"] and phase["end_us"]==span["end_us"] and
                phase["duration_ns"]==(span["end_us"]-span["start_us"])*1000,"Native derived phase differs from actual raw span")


def validate_meta(meta):
    envelope(meta, "GATE_B_META")
    require(meta.get("framework") in ("kit", "replay"), "unknown framework")
    require(meta.get("timing_mode") in ("functional_only", "profile"), "unknown timing_mode")
    fixture = meta["fixture"]
    require(fixture["id"] in PROFILES, "unknown fixture identity")
    profile, contacts = PROFILES[fixture["id"]]
    require(fixture["profile_hex"] == profile, "fixture/profile identity mismatch")
    require(fixture["initial_dynamic"] == 32, "initial32 cannot be reduced")
    require(fixture["reference_peak"] == dict(bodies=35, shapes=35, contacts=contacts, joints=1), "reference peak relabelled")
    digest(fixture["descriptor_sha256"], "fixture descriptor")
    execution = meta["execution"]
    require(execution["core"] in ("actual_godot_core", "registry_fake_core", "none"), "unknown Core mode")
    require(execution["ownership"] in ("sdk_meter", "nil_owner"), "unknown ownership mode")
    require(execution["native_linkage"] in ("shared_dso", "static_diagnostic"), "unknown Native linkage")
    require(execution["transport"] in ("offline_public_packets", "actual_enet"), "unknown transport scope")
    integer(execution["native_images"], "native_images")
    identity = meta["identity"]
    for name in ("os", "arch", "configuration", "godot"): text(identity[name], name)
    for name in ("source_manifest_sha256", "native_binary_sha256", "native_build_sha256", "native_target_sha256"):
        digest(identity[name], name)
    for name in ("core_binary_sha256", "script_binary_sha256"):
        digest(identity[name], name, nullable=execution["core"] != "actual_godot_core")
    require(meta["limits"] == LIMITS and all(type(meta["limits"][key]) is int for key in LIMITS), "predeclared limits changed")
    boundary = meta["boundary"]
    require(boundary["id"] in ("core_public_ingress_v1", "lower_diagnostic_v1"), "unknown boundary")
    text(boundary["receiver_entry"], "receiver_entry")
    text(boundary["clock_domain"], "clock_domain")
    integer(boundary["clock_resolution_ns"], "clock_resolution_ns", 1)
    require(isinstance(boundary["included_work"], list), "included_work must be a list")
    require(set(boundary["excluded_work"]) <= {"network_wait", "render", "diagnostic_output", "diagnostic_resource_read"}, "mandatory work excluded")
    require(isinstance(boundary["source_refs"], list) and boundary["source_refs"], "boundary source refs missing")
    for source in boundary["source_refs"]:
        text(source["path"], "source path"); text(source["symbol"], "source symbol"); digest(source["sha256"], "source hash")
    plan = meta["sample_plan"]
    require(set(plan) == {"normal", "repair8"}, "unknown sample-plan category")
    for op, count in plan.items(): integer(count, "sample_plan." + op)
    if meta["timing_mode"] == "functional_only": require(sum(plan.values()) == 0, "functional-only planned timed samples")
    if ("normal_kind" in meta or "step_observation" in meta or
            boundary["receiver_entry"] in NORMAL_ENTRIES.values()):
        require(meta.get("normal_kind") in NORMAL_ENTRIES, "new normal boundary requires a declared normal_kind")
        require(boundary["receiver_entry"] == NORMAL_ENTRIES[meta["normal_kind"]], "normal_kind/boundary mismatch")
        require(meta.get("step_observation") == NORMAL_STEP_OBSERVATION, "normal step observation must be explicit")
        expected = dict(normal=19, repair8=0) if meta["timing_mode"] == "profile" else dict(normal=0, repair8=0)
        require(plan == expected, "declared normal kind requires its own normal19/repair0 or functional-only stream")
    if _kit_v2(meta) and (plan["repair8"] or "canonical_five_part_signature_verification" in boundary["included_work"]):
        require(meta["descriptor"].get("native_recovery_read_in_operation") is False,
                "Kit wire2 ordinary signature repair must explicitly exclude Native recovery read")
    if "native_observer" in meta:validate_native_meta(meta)
    return meta


def boundary_findings(meta):
    execution, boundary = meta["execution"], meta["boundary"]
    findings = []
    if execution["core"] != "actual_godot_core" or execution["ownership"] != "sdk_meter": findings.append("diagnostic Core/ownership mode")
    if execution["native_linkage"] != "shared_dso" or execution["native_images"] != 1: findings.append("one shared Native DSO not established")
    normal_entry = (meta.get("normal_kind") in NORMAL_ENTRIES and
                    boundary["receiver_entry"] == NORMAL_ENTRIES[meta["normal_kind"]] and
                    meta.get("step_observation") == NORMAL_STEP_OBSERVATION and
                    meta["sample_plan"]["repair8"] == 0)
    if boundary["id"] != "core_public_ingress_v1" or not (boundary["receiver_entry"] in FULL_ENTRIES or normal_entry): findings.append("lower/public-ingress boundary incomplete")
    if boundary["clock_domain"] != "godot_ticks_usec" or boundary["clock_resolution_ns"] != 1000: findings.append("actual Core outer clock/resolution not established")
    included=set(boundary["included_work"])
    repair_work = KIT_V2_REPAIR_WORK if _kit_v2(meta) else REPAIR_WORK
    required=set()
    if meta["sample_plan"]["normal"]:required.update(NORMAL_WORK)
    if meta["sample_plan"]["repair8"]:required.update(repair_work)
    if meta["timing_mode"]=="functional_only" and not required:
        # No timed work was claimed; require one complete declared functional
        # pipeline, rather than fabricating an unused normal+repair union.
        if normal_entry and not NORMAL_WORK<=included:
            findings.append("functional normal boundary lacks its complete declared pipeline")
        elif not normal_entry and not (NORMAL_WORK<=included or repair_work<=included):
            findings.append("functional boundary lacks a complete declared operation pipeline")
    if _kit_v2(meta) and (meta["sample_plan"]["repair8"] or KIT_V2_REPAIR_WORK <= included):
        if "canonical_native_read_build_verify_reencode" in included:
            findings.append("Kit wire2 ordinary repair declares Native recovery work")
    missing=required-included
    if missing: findings.append("META missing required work: " + ",".join(sorted(missing)))
    return findings


def validate_sample(meta, sample, sequence):
    envelope(sample, "GATE_B_SAMPLE", meta["run_id"])
    require(meta["timing_mode"] == "profile", "functional-only emitted timing sample")
    require(integer(sample["seq"], "seq", 1) == sequence, "sample sequence gap/duplicate")
    op = sample["operation"]
    require(op in ("normal", "repair8"), "unknown operation; no post-hoc ineligible category")
    for name in ("epoch", "base_tick", "head_before", "head_after", "confirmed_before", "confirmed_after",
                 "requested_depth", "outer_start_us", "outer_end_us", "whole_ns"):
        integer(sample[name], name, 1 if name == "epoch" else 0)
    if "normal_kind" in meta:
        require(op == "normal" and sample.get("normal_kind") == meta["normal_kind"], "normal stream operation/kind changed")
        require(sample.get("step_observation") == meta["step_observation"], "normal step observation changed")
        for name in ("actual_steps_before", "actual_steps_after"):
            require(name in sample and sample[name] is None, "normal tick proof cannot fabricate an observed step counter")
    else:
        require("normal_kind" not in sample and "step_observation" not in sample, "sample added an undeclared normal proof/kind")
        for name in ("actual_steps_before", "actual_steps_after"): integer(sample[name], name)
    if _kit_v2(meta) and op == "repair8":
        for name in KIT_V2_REPAIR_COUNTERS: integer(sample.get(name), name)
        text(sample.get("counter_kind"), "counter_kind")
    require(sample["outer_end_us"] >= sample["outer_start_us"], "outer clock regressed")
    require(sample["whole_ns"] == (sample["outer_end_us"] - sample["outer_start_us"]) * 1000, "whole duration differs from outer call")
    require(sample["outcome"] in ("committed", "rejected", "hold_resync", "error"), "unknown outcome")
    require(isinstance(sample["included_work"], list), "sample coverage missing")
    proof = sample["proof"]
    for name in ("full_state_equal", "publication_atomic", "quota_ok"): boolean(proof[name], name)
    if "normal_kind" in meta:
        for name in ("successful_public_step", "external_require_step"): boolean(proof[name], name)
        for name in ("committed_tick_before", "committed_tick_after"): integer(proof[name], name)
    for name in ("expected_complete_sha256", "actual_complete_sha256"):
        digest(proof[name], name, nullable=sample["outcome"] != "committed")
    for name in ("bodies", "shapes", "contacts", "joints"): integer(sample["counts"][name], "counts." + name)
    ledger = sample["ledger"]
    for name in ("live_bytes", "reserved_bytes", "admitted_bytes", "limit_bytes", "committed_peak_bytes", "storage_bytes"):
        integer(ledger[name], "ledger." + name)
    require(ledger["admitted_bytes"] == ledger["live_bytes"] + ledger["reserved_bytes"], "ledger sum inconsistent")
    require(ledger["limit_bytes"] == TRACKED_BYTES, "ledger cap changed")
    for phase in sample["phases"]:
        text(phase["name"], "phase name"); text(phase["clock_domain"], "phase clock"); text(phase["relation"], "phase relation")
        integer(phase["duration_ns"], "phase duration")
        a, b = phase["start_us"], phase["end_us"]
        if a is None or b is None:
            require(a is b is None, "partial phase interval")
        else:
            require(phase["clock_domain"] == meta["boundary"]["clock_domain"], "cross-clock absolute interval cannot be compared")
            integer(a, "phase start"); integer(b, "phase end")
            require(sample["outer_start_us"] <= a <= b <= sample["outer_end_us"], "phase outside whole call")
            require(phase["duration_ns"] == (b - a) * 1000, "phase duration inconsistent")
        require(phase["duration_ns"] <= sample["whole_ns"] + meta["boundary"]["clock_resolution_ns"], "phase longer than whole call")
    if "native_observer" in meta:validate_native_sample(meta,sample)
    return sample


def sample_findings(sample, meta=None):
    findings = []
    op = sample["operation"]
    signature_repair = op == "repair8" and _kit_v2(meta)
    work = NORMAL_WORK if op == "normal" else (KIT_V2_REPAIR_WORK if signature_repair else REPAIR_WORK)
    missing = work - set(sample["included_work"])
    if missing: findings.append("missing work: " + ",".join(sorted(missing)))
    if signature_repair:
        if (meta["descriptor"].get("native_recovery_read_in_operation") is not False or
                "canonical_native_read_build_verify_reencode" in sample["included_work"]):
            findings.append("Kit wire2 ordinary repair cannot claim Native recovery work")
        if sample.get("counter_kind") != "model_step_callback":
            findings.append("Kit wire2 repair requires the observed model-step callback counter")
        if any(type(sample.get(name)) is not int or sample[name] < 0 for name in KIT_V2_REPAIR_COUNTERS):
            findings.append("Kit wire2 repair packet/signature/full-state counters unavailable or invalid")
        else:
            if sample["accepted_packets"] != 1 or sample["signature_packets"] != 1:
                findings.append("Kit wire2 repair requires exactly one ACCEPTED and one SIGNATURE")
            if sample["signatures_after"] - sample["signatures_before"] != 1:
                findings.append("Kit wire2 repair matched-signature delta is not one")
            if sample["full_states_before"] < 1 or sample["full_states_after"] != sample["full_states_before"]:
                findings.append("Kit wire2 ordinary repair received a full state or lacks validated bootstrap")
    if sample["outcome"] != "committed": findings.append("operation did not commit")
    if "normal_kind" in sample:
        proof = sample["proof"]
        if not proof["successful_public_step"] or not proof["external_require_step"]:
            findings.append("successful public step/External.require_step proof failed")
        if (proof["committed_tick_before"] != sample["head_before"] or
                proof["committed_tick_after"] != sample["head_after"] or
                proof["committed_tick_after"] != proof["committed_tick_before"] + 1):
            findings.append("committed tick step proof differs from the one published forward tick")
        if sample["base_tick"] != sample["head_before"]:
            findings.append("normal predecessor differs from published head before step")
        if sample["normal_kind"] == "client_prediction_send" and sample["confirmed_after"] != sample["confirmed_before"]:
            findings.append("client prediction normal unexpectedly changed confirmation")
        if sample["normal_kind"] == "authority_step_requested_canonical" and any(
                sample["confirmed_" + suffix] != sample["head_" + suffix] for suffix in ("before", "after")):
            findings.append("authority normal did not confirm its published step")
    else:
        delta = sample["actual_steps_after"] - sample["actual_steps_before"]
        if delta != (1 if op == "normal" else 8): findings.append("actual step delta is not declared operation")
    if op == "repair8" and (sample["requested_depth"] != 8 or sample["head_before"] - sample["base_tick"] != 8): findings.append("repair is not depth8")
    if op == "normal" and sample["requested_depth"] != 0: findings.append("normal labelled with repair depth")
    if sample["whole_ns"] <= 0: findings.append("whole measured duration must be positive")
    for suffix in ("before", "after"):
        head, confirmed = sample["head_" + suffix], sample["confirmed_" + suffix]
        if confirmed > head or head - confirmed > 8:
            findings.append("published/unconfirmed window invalid " + suffix)
    if op == "normal" and sample["head_after"] != sample["head_before"] + 1:
        findings.append("normal did not publish exactly one forward tick")
    if op == "repair8" and (sample["head_after"] != sample["head_before"] or
            sample["confirmed_before"] != sample["base_tick"] or
            sample["confirmed_after"] != sample["head_before"]):
        findings.append("reference repair8 tick transition differs")
    if sample["head_after"] < sample["base_tick"]: findings.append("published tick identity inconsistent")
    proof = sample["proof"]
    if not all(proof[name] for name in ("full_state_equal", "publication_atomic", "quota_ok")): findings.append("correctness/atomicity/quota proof failed")
    if proof["expected_complete_sha256"] != proof["actual_complete_sha256"]: findings.append("complete paired identity differs")
    for key, cap in (("bodies", 35), ("shapes", 35), ("contacts", 147), ("joints", 1)):
        if sample["counts"][key] > cap: findings.append("actual " + key + " exceeds cap")
    if sample["ledger"]["admitted_bytes"] > TRACKED_BYTES or sample["ledger"]["committed_peak_bytes"] > TRACKED_BYTES: findings.append("actual tracked ledger exceeds cap")
    block=sample.get("native_observation")
    if isinstance(block,dict) and set(block)==NATIVE_BLOCK_KEYS:
        findings.extend(native_findings(block,2,(sample["outer_start_us"],sample["outer_end_us"])))
    return findings


def validate_result(meta, result, count):
    envelope(result, "GATE_B_RESULT", meta["run_id"])
    require(integer(result["sample_count"], "sample_count") == count, "RESULT sample count mismatch")
    integer(result["functional_operations"], "functional_operations")
    for name in ("correctness_ok", "source_fence_unchanged", "binary_fence_unchanged"): boolean(result[name], name)
    cleanup = result["cleanup"]
    for name in ("native_live_bytes", "snapshot_live_bytes", "host_application_live_bytes"): integer(cleanup[name], name)
    for name in ("all_explicit_drops_ok", "core_shutdown_clean"): boolean(cleanup[name], name)
    text(cleanup["ownership_evidence"], "ownership_evidence")
    if "native_observer" in meta:
        mode=meta["native_observer"]["mode"]
        expected_prewarm=1 if mode=="timed" else 0
        require(type(result.get("native_clock_prewarm_calls")) is int and result["native_clock_prewarm_calls"]==expected_prewarm,"Native clock prewarm count differs from explicit profile/functional mode")
        block=result.get("native_observation")
        if mode=="off":require("native_observation" in result and block is None,"functional OFF Native raw must be null")
        else:
            validate_native_block(block) # Timed RESULT is the FINAL160 untimed structure oracle.
            require(not native_findings(block,1),"Native final/functional observation failed: "+repr(native_findings(block,1)))
        scopes=result.get("native_functional_scopes",[])
        require(isinstance(scopes,list) and len(scopes)<=20,"functional Native scope history bound")
        if mode=="off":require(not scopes,"OFF cannot claim recorded Native scopes")
        for item in scopes:
            validate_native_block(item)
            require(not native_findings(item,1),"Native functional scope observation failed")
    return result


def result_findings(result):
    findings = []
    for name in ("correctness_ok", "source_fence_unchanged", "binary_fence_unchanged"):
        if not result[name]: findings.append(name + " failed")
    cleanup = result["cleanup"]
    for name in ("native_live_bytes", "snapshot_live_bytes", "host_application_live_bytes"):
        if cleanup[name] != 0: findings.append(name + " nonzero")
    for name in ("all_explicit_drops_ok", "core_shutdown_clean"):
        if not cleanup[name]: findings.append(name + " failed")
    if "native_clock_prewarm_calls" in result:
        block=result.get("native_observation")
        if block is not None:findings.extend(native_findings(block,1))
        for item in result.get("native_functional_scopes",[]):findings.extend(native_findings(item,1))
    return findings
