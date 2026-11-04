package kit_physics

// Optional Box3D participant for Kit. Importing kit/sim alone never imports this
// package or a native library. Side is an owned value with world-independent keys.
import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:reflect"
import b3 "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import ksim "godot:kit/sim"

Config :: struct {
	allocator_context:            ^bm.Context,
	provider_user, author_user:   rawptr,
	provider_owner, author_owner: ksim.World_Owner,
	effect_owner:                 ksim.World_Owner,
	effect_user:                  rawptr,
	owner:                        ksim.World_Owner,
	detached_owner:               ksim.World_Owner,
	asset_id:                     u64,
	reservation_bytes:            u64,
	additional_owned_bytes:       u64,
}
Instance :: struct($Side: typeid) {
	network_identity:       Network_Identity,
	lane:                   ^ksim.Lane,
	active, published:      ^Execution(Side),
	config:                 Config,
	initial_dynamic_bodies: u32,
	allocator:              mem.Allocator,
	reservation_mark:       u64,
	reservation_active:     bool,
}
@(private)
Execution :: struct($Side: typeid) {
	stage:                  b3.World_Stage,
	side:                   Side,
	allocator:              mem.Allocator,
	initial_dynamic_bodies: u32,
	observations:           Sensor_Observations,
	network_identity:       Network_Identity,
}
@(private)
Image :: struct($Side: typeid) {
	snapshot:               b3.Snapshot,
	side:                   Side,
	asset_id:               u64,
	allocator:              mem.Allocator,
	initial_dynamic_bodies: u32,
	observations:           Sensor_Observations,
	network_identity:       Network_Identity,
	info:                   b3.Snapshot_Info,
}
// Diagnostic allocation ownership, not causal game state. Physics calls use one
// caller; these include detached owners after their source provider is destroyed.
@(private)
g_image_bytes, g_execution_bytes, g_comparison_bytes, g_total_external_requests: u64
owned_bytes :: proc() -> u64 {return(
		g_image_bytes +
		g_execution_bytes +
		g_comparison_bytes +
		g_codec_bytes +
		g_network_bytes \
	)}

Allocation_Profile :: struct {
	observed_live_peak,
	staged_live_peak,
	external_peak,
	largest_operation_requests,
	reservation_failures: u64,
}
@(private)
allocation_profile: Allocation_Profile
allocation_stats :: proc() -> Allocation_Profile {return allocation_profile}
@(private)
request_mark :: proc() -> u64 {
	engine, es := b3.engine_allocation_stats(
		
	); wrapper, ws := b3.snapshot_allocation_stats(); assert(es == .Ok && ws == .Ok)
	return engine.total_bytes + wrapper.total_bytes + g_total_external_requests
}
@(private)
reservation_end :: proc(a: ^Instance($Side)) -> ksim.World_Error {
	if !a.reservation_active {return .Ok}
	requests := request_mark() - a.reservation_mark
	allocation_profile.largest_operation_requests = max(
		allocation_profile.largest_operation_requests,
		requests,
	)
	a.reservation_active = false
	if requests >
	   a.config.reservation_bytes {allocation_profile.reservation_failures += 1; return .Budget}
	return .Ok
}
observe :: proc(a: ^Instance($Side)) -> (b3.Alpha_Observation, ksim.World_Error) {
	if a.lane == nil || a.published == nil {return {}, .Invalid}
	if e := ksim.world_owner_check(a.config.owner); e != .Ok {return {}, e}
	external := ksim.lane_world_owned_bytes(a.lane) + owned_bytes()
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		service := bg.service_get()
		if status := service.legacy_extra(service.user, 0, 0, 0, &external);
		   status != bg.OK {return {}, host_status(status)}
	}
	value, status := b3.alpha_observe(a.published.stage.world, external)
	return value, map_status(status)
}

@(private)
map_status :: proc(status: b3.Status) -> ksim.World_Error {
	#partial switch status {
	case .Ok:
		return .Ok
	case .Out_Of_Memory:
		return .Allocation_Failed
	case .Capacity:
		return .Capacity
	case .Incompatible:
		return .Incompatible
	case .Unsupported:
		return .Unsupported
	case .Invalid_Argument, .Invalid_Handle:
		return .Invalid
	case:
		return .Step_Failed
	}
}
@(private)
side_info_supported :: proc(info: ^reflect.Type_Info) -> bool {
	if info == nil {return false}
	if info == type_info_of(b3.World) ||
	   info == type_info_of(b3.Body) ||
	   info == type_info_of(b3.Shape) ||
	   info == type_info_of(b3.Joint) {return false}
	base := reflect.type_info_base(info)
	#partial switch v in base.variant {
	case reflect.Type_Info_Struct:
		if v.soa_kind != .None || .raw_union in v.flags {return false}
		for t in v.types[:v.field_count] {if !side_info_supported(t) {return false}}
		return true
	case reflect.Type_Info_Array:
		return side_info_supported(v.elem)
	case reflect.Type_Info_Enumerated_Array:
		return side_info_supported(v.elem)
	case reflect.Type_Info_Integer,
	     reflect.Type_Info_Rune,
	     reflect.Type_Info_Float,
	     reflect.Type_Info_Boolean:
		return true
	case reflect.Type_Info_Enum:
		return side_info_supported(v.base)
	case reflect.Type_Info_Bit_Set:
		return side_info_supported(v.underlying)
	case:
		return false
	}
}
@(private)
side_equal :: proc(left, right: rawptr, source: ^reflect.Type_Info) -> bool {
	info := reflect.type_info_base(source)
	#partial switch v in info.variant {
	case reflect.Type_Info_Struct:
		for t, i in v.types[:v.field_count] {
			a := rawptr(
				&((cast([^]u8)left)[v.offsets[i]]),
			); b := rawptr(&((cast([^]u8)right)[v.offsets[i]]))
			if !side_equal(a, b, t) {return false}
		}
		return true
	case reflect.Type_Info_Array:
		for i in 0 ..< v.count {if !side_equal(rawptr(&((cast([^]u8)left)[i * v.elem_size])), rawptr(&((cast([^]u8)right)[i * v.elem_size])), v.elem) {return false}}
		return true
	case reflect.Type_Info_Enumerated_Array:
		for i in 0 ..< v.count {if !side_equal(rawptr(&((cast([^]u8)left)[i * v.elem_size])), rawptr(&((cast([^]u8)right)[i * v.elem_size])), v.elem) {return false}}
		return true
	case:
		return mem.compare((cast([^]u8)left)[:info.size], (cast([^]u8)right)[:info.size]) == 0
	}
}

// Transfers world ownership only on success. It becomes available solely through
// staged tick operations; the caller's World owner is cleared after installation.
attach :: proc(
	a: ^Instance($Side),
	l: ^ksim.Lane,
	world: ^b3.World,
	initial: Side,
	fields: []ksim.World_Field_Type,
	cfg: Config,
	settle: ksim.Step_Proc = nil,
) -> ksim.World_Error {
	if a.lane != nil ||
	   l == nil ||
	   world == nil ||
	   world^ == 0 ||
	   cfg.asset_id == 0 {return .Invalid}
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		if bg.service_get().realm == 0 {return .Incompatible}
		if ksim.world_owner_is_empty(cfg.owner) ||
		   ksim.world_owner_is_empty(cfg.detached_owner) {return .Unsupported}
		allocator_context, allocator_status := bm.context_for(l.allocator)
		if allocator_status != bg.OK ||
		   cfg.allocator_context != allocator_context ||
		   cfg.additional_owned_bytes != 0 {return .Unsupported}
		if !bm.owns(allocator_context, a, u64(size_of(a^))) ||
		   !bm.owns(allocator_context, l, u64(size_of(l^))) ||
		   !bm.owns(allocator_context, l.ses, u64(size_of(l.ses^))) {return .Unsupported}
		if cfg.provider_user != rawptr(a) ||
		   ksim.world_owner_is_empty(cfg.provider_owner) {return .Unsupported}
		if l.user != nil &&
		   (cfg.author_user != l.user ||
				   ksim.world_owner_is_empty(cfg.author_owner)) {return .Unsupported}
	}
	if e := ksim.world_owner_check(cfg.owner, ksim.WORLD_OWNER_EXECUTE); e != .Ok {return e}
	if e := ksim.world_owner_check(cfg.detached_owner); e != .Ok {return e}
	if !ksim.world_value_supported(Side) ||
	   !side_info_supported(type_info_of(Side)) {return .Unsupported}
	for binding in fields {if !side_info_supported(
			type_info_of(binding.type),
		) {return .Unsupported}}
	if cfg.additional_owned_bytes > b3.ALPHA_RESOURCE_BYTES ||
	   cfg.reservation_bytes > b3.ALPHA_RESOURCE_BYTES {return .Budget}
	a.config =
		cfg; if a.config.reservation_bytes == 0 {a.config.reservation_bytes = 2 * 1024 * 1024}
	a.allocator = l.allocator
	// Check before temporary capture/open, and derive the initial-dynamic count
	// from actual cached native states rather than accepting a false declaration.
	request := b3.alpha_request_default(
		
	); request.additional_owned_bytes = cfg.additional_owned_bytes + u64(size_of(Instance(Side)) + size_of(Execution(Side))); request.reserved_bytes = a.config.reservation_bytes
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		var_extra: u64
		service := bg.service_get()
		if status := service.legacy_extra(
			service.user,
			0,
			0,
			a.config.reservation_bytes,
			&var_extra,
		); status != bg.OK {return host_status(status)}
		request.additional_owned_bytes = var_extra; request.reserved_bytes = 0
	}
	_, status := b3.alpha_check(
		world^,
		request,
	); if status == .Capacity {return .Budget}; if status != .Ok {return map_status(status)}
	snap, snapshot_status := b3.snapshot_capture(
		world^,
	); if snapshot_status != .Ok {return map_status(snapshot_status)}
	states: [b3.ALPHA_TOTAL_BODIES]b3.Body_State
	count, read_status := b3.snapshot_body_states(&snap, states[:]); b3.snapshot_destroy(&snap)
	if read_status != .Ok {return map_status(read_status)}
	a.initial_dynamic_bodies = 0
	for state in states[:count] {if state.type == .Dynamic {a.initial_dynamic_bodies += 1}}
	if a.initial_dynamic_bodies > b3.ALPHA_INITIAL_DYNAMIC_BODIES {return .Budget}
	exec, err := new(
		Execution(Side),
		a.allocator,
	); if err != nil || exec == nil {return .Allocation_Failed}
	exec.stage.world = world^; exec.side = initial; exec.allocator = a.allocator; exec.initial_dynamic_bodies = a.initial_dynamic_bodies; g_execution_bytes += u64(size_of(exec^)); g_total_external_requests += u64(size_of(exec^))
	a.active = exec; a.published = exec; a.lane = l
	provider := make_provider(a)
	error := ksim.lane_world_attach(
		l,
		provider,
		fields,
		{
			settle = settle,
			additional_owned_bytes = cfg.additional_owned_bytes + u64(size_of(Instance(Side))),
			reservation_bytes = a.config.reservation_bytes,
		},
	)
	if error != .Ok {
		exec.stage.world = 0; execution_close(Side, exec)
		a.active = nil; a.published = nil; a.lane = nil; a.reservation_active = false
		return error
	}
	world^ = 0
	return .Ok
}

detach :: proc(a: ^Instance($Side)) -> ksim.World_Error {
	if a.lane == nil {return .Ok}
	owner := a.config.provider_owner
	if e := ksim.world_owner_retain(owner); e != .Ok {return e}
	defer {_ = ksim.world_owner_drop(owner)}
	error := ksim.lane_world_detach(a.lane)
	if error == .Ok {a.lane = nil; a.active = nil; a.published = nil}
	return error
}
// Mutable Side/world are borrowed ONLY during the authored staged tick/settle.
state :: proc(a: ^Instance($Side)) -> ^Side {
	if ksim.world_owner_check(a.config.owner, ksim.WORLD_OWNER_EXECUTE) != .Ok {return nil}
	if a.lane == nil ||
	   !ksim.lane_world_busy(a.lane) ||
	   a.active == nil ||
	   a.active == a.published {return nil}
	return &a.active.side
}
world :: proc(a: ^Instance($Side)) -> (b3.World, ksim.World_Error) {
	if state(a) == nil {return 0, .Busy}
	w, status := b3.stage_world(&a.active.stage); return w, map_status(status)
}
// Turn a fallible authored native operation into an abort of the staged tick.
// Return immediately from the authored callback when this returns false.
require :: proc(a: ^Instance($Side), status: b3.Status) -> bool {
	if status == .Ok {return true}
	if a.lane != nil {ksim.lane_world_fail(a.lane, map_status(status))}
	return false
}
read :: proc(a: ^Instance($Side)) -> (Side, bool) {
	if ksim.world_owner_check(a.config.owner) != .Ok {return {}, false}
	if a.published == nil {return {}, false}; return a.published.side, true
}
checkpoint_side :: proc(
	checkpoint: ^ksim.World_Checkpoint,
	$Side: typeid,
) -> (
	Side,
	ksim.World_Error,
) {
	if e := ksim.world_checkpoint_owner_check(checkpoint); e != .Ok {return {}, e}
	if checkpoint == nil || checkpoint.image == nil {return {}, .Missing_Attachment}
	if checkpoint.side_type != Side {return {}, .Incompatible}
	image := cast(^Image(Side))checkpoint.image
	return image.side, .Ok
}
checkpoint_body_state :: proc(
	checkpoint: ^ksim.World_Checkpoint,
	key: b3.Body_Key,
	$Side: typeid,
) -> (
	b3.Body_State,
	ksim.World_Error,
) {
	if e := ksim.world_checkpoint_owner_check(checkpoint); e != .Ok {return {}, e}
	if checkpoint == nil || checkpoint.image == nil {return {}, .Missing_Attachment}
	if checkpoint.side_type != Side {return {}, .Incompatible}
	image := cast(^Image(Side))checkpoint.image
	value, status := b3.snapshot_body_state(&image.snapshot, key); return value, map_status(status)
}

// One checked historical cache read for pooled presentation. Capacity queries
// and insufficient output preserve caller storage per the authoritative C API.
// This never opens/steps a world or allocates one scratch world per body.
checkpoint_body_states :: proc(
	checkpoint:^ksim.World_Checkpoint,
	out:[]b3.Body_State,
	$Side:typeid,
)->(u32,ksim.World_Error) {
	if e:=ksim.world_checkpoint_owner_check(checkpoint);e!=.Ok {return 0,e}
	if checkpoint==nil || checkpoint.image==nil {return 0,.Missing_Attachment}
	if checkpoint.side_type!=Side {return 0,.Incompatible}
	image:=cast(^Image(Side))checkpoint.image
	if image.asset_id!=checkpoint.asset_id {return 0,.Incompatible}
	count,status:=b3.snapshot_body_states(&image.snapshot,out)
	return count,map_status(status)
}

// Complete normalized solver diagnostics, never a pose-only checkpoint view.
// Empty output queries capacity; Capacity writes no partial bytes.
checkpoint_dump :: proc(
	checkpoint: ^ksim.World_Checkpoint,
	out: []u8,
	$Side: typeid,
) -> (
	u64,
	ksim.World_Error,
) {
	if e := ksim.world_checkpoint_owner_check(checkpoint); e != .Ok {return 0, e}
	if checkpoint == nil || checkpoint.image == nil {return 0, .Missing_Attachment}
	if checkpoint.side_type != Side {return 0, .Incompatible}
	image := cast(^Image(Side))checkpoint.image
	if image.asset_id != checkpoint.asset_id {return 0, .Incompatible}
	required, status := b3.snapshot_dump(&image.snapshot, out); return required, map_status(status)
}
checkpoint_digests :: proc(
	checkpoint: ^ksim.World_Checkpoint,
	$Side: typeid,
) -> (
	b3.World_Digests,
	ksim.World_Error,
) {
	if e := ksim.world_checkpoint_owner_check(checkpoint); e != .Ok {return {}, e}
	if checkpoint == nil || checkpoint.image == nil {return {}, .Missing_Attachment}
	if checkpoint.side_type != Side {return {}, .Incompatible}
	image := cast(^Image(Side))checkpoint.image
	if image.asset_id != checkpoint.asset_id {return {}, .Incompatible}
	value, status := b3.snapshot_digests(&image.snapshot); return value, map_status(status)
}

@(private)
execution_close :: proc($Side: typeid, raw: rawptr) {
	if raw == nil {return}; exec := cast(^Execution(Side))raw; allocator := exec.allocator
	status := b3.stage_discard(&exec.stage); assert(status == .Ok)
	assert(
		g_execution_bytes >= u64(size_of(exec^)),
	); g_execution_bytes -= u64(size_of(exec^)); free(exec, allocator)
}
@(private)
image_release :: proc($Side: typeid, raw: rawptr) {
	if raw == nil {return}; image := cast(^Image(Side))raw; allocator := image.allocator
	status := b3.snapshot_destroy(
		&image.snapshot,
	); assert(status == .Ok, "native release rejected in protected origin")
	assert(
		g_image_bytes >= u64(size_of(image^)),
	); g_image_bytes -= u64(size_of(image^)); free(image, allocator)
}
@(private)
detached_admit :: proc(additional, reserved: u64) -> ksim.World_Error {
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		service := bg.service_get(); external: u64
		// All covered Core/provider/codec storage is already observed by Meter.
		// The caller's local/prospective diagnostic sum is never actual HOST LIVE.
		if status := service.legacy_extra(service.user, 0, 0, reserved, &external);
		   status != bg.OK {return host_status(status)}
		_, managed_status := b3.alpha_memory_check(external, 0)
		return managed_status == .Capacity ? .Budget : map_status(managed_status)
	}
	if additional > max(u64) - owned_bytes() {return .Budget}
	observation, status := b3.alpha_memory_check(additional + owned_bytes(), reserved)
	allocation_profile.observed_live_peak = max(
		allocation_profile.observed_live_peak,
		observation.live_bytes,
	)
	allocation_profile.external_peak = max(
		allocation_profile.external_peak,
		additional + owned_bytes(),
	)
	return status == .Capacity ? .Budget : map_status(status)
}
@(private)
make_provider :: proc(a: ^Instance($Side)) -> ksim.World_Provider {
	return {
		budget = sdk_budget(),
		user_owner = a.config.provider_owner,
		author_owner = a.config.author_owner,
		effect_owner = a.config.effect_owner,
		effect_user = a.config.effect_user,
		owner = a.config.owner,
		detached_owner = a.config.detached_owner,
		user = a,
		side_type = Side,
		asset_id = a.config.asset_id,
		initial_execution = a.published,
		capture = proc(user, raw: rawptr) -> (rawptr, ksim.World_Error) {
			a := cast(^Instance(Side))user; exec := cast(^Execution(Side))raw
			snap: b3.Snapshot; info: b3.Snapshot_Info; status: b3.Status
			if a.network_identity !=
			   (Network_Identity{}) {snap, info, status = b3.snapshot_capture_info(exec.stage.world)} else {snap, status = b3.snapshot_capture(exec.stage.world)}
			if status != .Ok {return nil, map_status(status)}
			if a.network_identity != (Network_Identity{}) &&
			   info.metrics.image_used >
				   b3.RECOVERY_MAX_SOURCE_IMAGE_BYTES {b3.snapshot_destroy(&snap); return nil, .Capacity}
			image, err := new(
				Image(Side),
				exec.allocator,
			); if err != nil || image == nil {b3.snapshot_destroy(&snap); return nil, .Allocation_Failed}
			image^ = {
				snap,
				exec.side,
				a.config.asset_id,
				exec.allocator,
				exec.initial_dynamic_bodies,
				exec.observations,
				exec.network_identity,
				info,
			}; g_image_bytes += u64(size_of(image^)); g_total_external_requests += u64(size_of(image^)); return image, .Ok
		},
		clone = proc(raw: rawptr) -> (rawptr, ksim.World_Error) {
			source := cast(^Image(Side))raw
			if error := detached_admit(u64(size_of(Image(Side))), 1024 * 1024);
			   error != .Ok {return nil, error}
			snap: b3.Snapshot; info := source.info; status: b3.Status
			if source.network_identity !=
			   (Network_Identity{}) {snap, info, status = b3.snapshot_clone_info(&source.snapshot)} else {snap, status = b3.snapshot_clone(&source.snapshot)}
			if status != .Ok {return nil, map_status(status)}
			if source.network_identity != (Network_Identity{}) &&
			   info.metrics.image_used >
				   b3.RECOVERY_MAX_SOURCE_IMAGE_BYTES {b3.snapshot_destroy(&snap); return nil, .Capacity}
			image, err := new(
				Image(Side),
				source.allocator,
			); if err != nil || image == nil {b3.snapshot_destroy(&snap); return nil, .Allocation_Failed}
			image^ = {
				snap,
				source.side,
				source.asset_id,
				source.allocator,
				source.initial_dynamic_bodies,
				source.observations,
				source.network_identity,
				info,
			}; g_image_bytes += u64(size_of(image^)); g_total_external_requests += u64(size_of(image^)); return image, .Ok
		},
		equal = proc(left, right: rawptr) -> (bool, ksim.World_Error) {
			a := cast(^Image(Side))left; b := cast(^Image(Side))right
			if a.asset_id != b.asset_id ||
			   a.initial_dynamic_bodies != b.initial_dynamic_bodies ||
			   !side_equal(&a.side, &b.side, type_info_of(Side)) ||
			   a.observations != b.observations ||
			   a.network_identity != b.network_identity {return false, .Ok}
			na, nb: u64
			if a.network_identity != (Network_Identity{}) {
				na = a.info.storage.normalized_bytes; nb = b.info.storage.normalized_bytes
				if na != nb {
					// Even a rare cached-length mismatch validates BOTH owners. A
					// corrupt resource cannot quietly become a successful false result.
					ca, ea := b3.snapshot_dump(
						&a.snapshot,
						nil,
					); cb, eb := b3.snapshot_dump(&b.snapshot, nil)
					if ea !=
					   .Ok {return false, map_status(ea)}; if eb != .Ok {return false, map_status(eb)}
					if ca != na || cb != nb {return false, .Incompatible}; return false, .Ok
				}
			} else {
				// Preserve the standalone P2 path without a cached network summary.
				da, sa := b3.snapshot_digests(
					&a.snapshot,
				); db, sb := b3.snapshot_digests(&b.snapshot)
				if sa !=
				   .Ok {return false, map_status(sa)}; if sb != .Ok {return false, map_status(sb)}
				if da.complete_solver_digest != db.complete_solver_digest {return false, .Ok}
				ea, eb: b3.Status
				na, ea = b3.snapshot_dump(
					&a.snapshot,
					nil,
				); nb, eb = b3.snapshot_dump(&b.snapshot, nil)
				if ea !=
				   .Ok {return false, map_status(ea)}; if eb != .Ok {return false, map_status(eb)}; if na != nb {return false, .Ok}
			}
			if error := detached_admit(na + nb, 0); error != .Ok {return false, error}
			g_comparison_bytes += na + nb; defer {g_comparison_bytes -= na + nb}
			aa, erra := make(
				[]u8,
				int(na),
				a.allocator,
			); if erra != nil || len(aa) != int(na) {return false, .Allocation_Failed}; defer delete(aa, a.allocator)
			bb, errb := make(
				[]u8,
				int(nb),
				b.allocator,
			); if errb != nil || len(bb) != int(nb) {return false, .Allocation_Failed}; defer delete(bb, b.allocator)
			ca, ea := b3.snapshot_dump(
				&a.snapshot,
				aa,
			); cb, eb := b3.snapshot_dump(&b.snapshot, bb)
			if ea !=
			   .Ok {return false, map_status(ea)}; if eb != .Ok {return false, map_status(eb)}
			if ca != na || cb != nb {return false, .Incompatible}
			return mem.compare(aa, bb) == 0, .Ok
		},
		release = proc(image: rawptr) {image_release(Side, image)},
		open = proc(user, image_raw: rawptr) -> (rawptr, ksim.World_Error) {
			a := cast(^Instance(Side))user; image := cast(^Image(Side))image_raw
			if (a.network_identity != Network_Identity{} &&
				   image.network_identity != a.network_identity) ||
			   image.asset_id != a.config.asset_id ||
			   image.initial_dynamic_bodies >
				   b3.ALPHA_INITIAL_DYNAMIC_BODIES {return nil, .Incompatible}
			stage, status := b3.stage_open(
				&image.snapshot,
			); if status != .Ok {return nil, map_status(status)}
			exec, err := new(
				Execution(Side),
				a.allocator,
			); if err != nil || exec == nil {b3.stage_discard(&stage); return nil, .Allocation_Failed}
			exec^ = {
				stage,
				image.side,
				a.allocator,
				image.initial_dynamic_bodies,
				image.observations,
				image.network_identity,
			}; g_execution_bytes += u64(size_of(exec^)); g_total_external_requests += u64(size_of(exec^)); return exec, .Ok
		},
		close = proc(raw: rawptr) {execution_close(Side, raw)},
		bind = proc(
			user, raw: rawptr,
		) {a := cast(^Instance(Side))user; a.active = cast(^Execution(Side))raw
			if a.active == a.published {a.reservation_active = false}},
		publish = proc(
			user, raw: rawptr,
		) {a := cast(^Instance(Side))user; a.reservation_active = false
			a.published = cast(^Execution(Side))raw
			if a.published != nil {a.initial_dynamic_bodies = a.published.initial_dynamic_bodies}},
		step = proc(user, raw: rawptr, tick: u64) -> ksim.World_Error {
			exec := cast(^Execution(Side))raw
			if status := b3.world_step_fixed(exec.stage.world);
			   status != .Ok {return map_status(status)}
			return collect_observations(exec.stage.world, &exec.observations)
		},
		admit = proc(user, raw: rawptr, admission: ksim.World_Admission) -> ksim.World_Error {
			a := cast(^Instance(Side))user; exec := cast(^Execution(Side))raw
			when !#config(
				BOX3D_REQUIRE_DOMAIN,
				false,
			) {if error := reservation_end(a); error != .Ok {return error}}
			request := b3.alpha_request_default(
				
			); request.initial_dynamic_bodies = exec.initial_dynamic_bodies
			request.prediction_ticks =
				admission.prediction_ticks; request.correction_ticks = admission.correction_ticks
			if admission.additional_owned_bytes > b3.ALPHA_RESOURCE_BYTES ||
			   owned_bytes() >
				   b3.ALPHA_RESOURCE_BYTES - admission.additional_owned_bytes {return .Budget}
			request.additional_owned_bytes =
				admission.additional_owned_bytes +
				owned_bytes(); request.reserved_bytes = admission.reserved_bytes
			when #config(BOX3D_REQUIRE_DOMAIN, false) {
				service := bg.service_get()
				if status := service.legacy_extra(
					service.user,
					0,
					0,
					admission.reserved_bytes,
					&request.additional_owned_bytes,
				); status != bg.OK {return host_status(status)}
				request.reserved_bytes = 0
			}
			allocation_profile.external_peak = max(
				allocation_profile.external_peak,
				request.additional_owned_bytes,
			)
			observation, status := b3.alpha_check(exec.stage.world, request)
			allocation_profile.observed_live_peak = max(
				allocation_profile.observed_live_peak,
				observation.live_bytes,
			)
			if exec !=
			   a.published {allocation_profile.staged_live_peak = max(allocation_profile.staged_live_peak, observation.live_bytes)}
			if !#config(BOX3D_REQUIRE_DOMAIN, false) &&
			   status == .Ok &&
			   admission.reserved_bytes !=
				   0 {a.reservation_active = true; a.reservation_mark = request_mark()}
			return status == .Capacity ? .Budget : map_status(status)
		},
		admit_detached = detached_admit,
	}
}

// Completed native outputs belong to the adapter image. Read this cache instead
// of native completed buffers, which are intentionally empty after stage_open.
Sensor_Observation :: struct {
	sensor, visitor: b3.Shape_Key,
	began:           u32,
}
Sensor_Observations :: struct {
	count:  u32,
	events: [128]Sensor_Observation,
}
@(private)
collect_observations :: proc(world: b3.World, out: ^Sensor_Observations) -> ksim.World_Error {
	native: [128]b3.Sensor_Event
	count, status := b3.world_sensor_events(
		world,
		native[:],
	); if status != .Ok {return map_status(status)}
	out^ = {
		count = count,
	}
	for e, i in native[:count] {
		sensor, ss := b3.shape_key_from_handle(
			e.sensor,
		); visitor, vs := b3.shape_key_from_handle(e.visitor)
		if ss != .Ok {return map_status(ss)}; if vs != .Ok {return map_status(vs)}
		out.events[i] = {sensor, visitor, e.began}
	}
	return .Ok
}
sensor_observations :: proc(a: ^Instance($Side)) -> (Sensor_Observations, ksim.World_Error) {
	if a.lane == nil || a.active == nil {return {}, .Invalid}
	return a.active.observations, .Ok
}
checkpoint_observations :: proc(
	cp: ^ksim.World_Checkpoint,
	$Side: typeid,
) -> (
	Sensor_Observations,
	ksim.World_Error,
) {
	if e := ksim.world_checkpoint_owner_check(cp); e != .Ok {return {}, e}
	if cp == nil || cp.image == nil {return {}, .Missing_Attachment}
	if cp.side_type != Side {return {}, .Incompatible}
	return (cast(^Image(Side))cp.image).observations, .Ok
}

// Optional production composition. Importing kit/sim or this pure protocol
// alone does not activate the Box3D module profile; native bindings register it
// only in BOX3D_REQUIRE_DOMAIN builds. Root's Core installs stable host hooks.
@(private)
sdk_budget :: proc "contextless" () -> ksim.World_Budget {
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		service := bg.service_get()
		return {
			user = service.user,
			begin = service.budget_begin,
			reconcile = service.budget_reconcile,
			end = service.budget_end,
		}
	} else {return {}}
}
@(private)
sdk_operation_begin :: proc "contextless" (bound: u64) -> (u64, ksim.World_Error) {
	when #config(BOX3D_REQUIRE_DOMAIN, false) {
		service := bg.service_get(); mark: u64
		status := service.budget_begin(service.user, bound, &mark)
		if status != bg.OK {return 0, host_status(status)}
		return mark, .Ok
	} else {return 0, .Ok}
}
@(private)
sdk_operation_end :: proc(mark: ^u64) {
	if mark == nil || mark^ == 0 {return}; value := mark^; mark^ = 0
	service := bg.service_get(); status := service.budget_end(service.user, value)
	assert(status == bg.OK || status == bg.CAPACITY)
}
@(private)
sdk_operation_finish :: proc "contextless" (mark: u64) -> ksim.World_Error {
	if mark == 0 {return .Ok}; service := bg.service_get()
	return host_status(service.budget_reconcile(service.user, mark))
}
when #config(BOX3D_REQUIRE_DOMAIN, false) {
	@(init)
	sdk_module_hook :: proc "contextless" () {
		if bg.module_add_hook(sdk_module_install) != bg.OK {intrinsics.trap()}
	}
	@(private)
	sdk_module_install :: proc "c" (service: ^bg.Service) -> bg.Status {
		if service == nil || service.realm == 0 {return bg.INVALID_ARGUMENT}
		return ksim.world_owner_realm_install(service.realm) == .Ok ? bg.OK : bg.INCOMPATIBLE
	}
}

// Caller owns the returned capability and drops it through stable Core after
// all typed operations/owners finish. A nonnull allocator/user context requires
// an actual Data_Lease; a code pin alone cannot grant detached-data lifetime.
sdk_owner_create :: proc(
	require_live_instance: bool,
	data: bg.Data_Lease = {},
) -> (
	ksim.World_Owner,
	ksim.World_Error,
) {
	service := bg.service_get()
	if service.realm == 0 || service.owner_create == nil {return {}, .Incompatible}
	if data.user != nil && (data.retain == nil || data.drop == nil) {return {}, .Unsupported}
	if data.user == nil && (data.retain != nil || data.drop != nil) {return {}, .Invalid}
	owner: bg.Owner; lease := data
	status := service.owner_create(service.user, require_live_instance ? 1 : 0, &lease, &owner)
	if status != bg.OK {return {}, host_status(status)}
	return owner, .Ok
}
// Build this context BEFORE the Lane/Session/schema/container. Its allocator
// data has actual retained ownership; source and detached capabilities differ.
// Callback users still require a separate explicit block lease/Owner.
SDK_Context :: struct {
	memory:         ^bm.Context,
	live, detached: ksim.World_Owner,
}
SDK_User_Owner :: struct {
	owner:           ksim.World_Owner,
	user:            rawptr,
	allocation_base: rawptr,
	allocation_size: u64,
}
sdk_user_owner_create :: proc(
	memory: ^bm.Context,
	allocation_base: rawptr,
	allocation_size: u64,
	user: rawptr,
	user_size: u64,
) -> (
	SDK_User_Owner,
	ksim.World_Error,
) {
	lease, status := bm.block_lease(memory, allocation_base, allocation_size, user, user_size)
	if status != bg.OK {return {}, host_status(status)}
	owner, error := sdk_owner_create(false, lease)
	if error != .Ok {return {}, error}
	return {
			owner = owner,
			user = user,
			allocation_base = allocation_base,
			allocation_size = allocation_size,
		},
		.Ok
}
sdk_user_owner_destroy :: proc(owned: ^SDK_User_Owner) -> ksim.World_Error {
	if owned == nil {return .Ok}
	if e := ksim.world_owner_drop(owned.owner); e != .Ok {return e}
	owned^ = {}; return .Ok
}
sdk_context_create :: proc() -> (owned: SDK_Context, error: ksim.World_Error) {
	memory, status := bm.create(bg.service_get(), bg.CATEGORY_KIT_CORE)
	if status != bg.OK {return {}, host_status(status)}
	lease := bm.data_lease(memory)
	live, le := sdk_owner_create(true, lease)
	if le != .Ok {_ = bm.destroy(&memory); return {}, le}
	detached, de := sdk_owner_create(false, lease)
	if de != .Ok {_ = ksim.world_owner_drop(live); _ = bm.destroy(&memory); return {}, de}
	return {memory, live, detached}, .Ok
}
sdk_context_config :: proc(
	owned: SDK_Context,
	asset_id: u64,
	provider: SDK_User_Owner = {},
	author: SDK_User_Owner = {},
	effects: SDK_User_Owner = {},
) -> Config {
	return {
		asset_id = asset_id,
		owner = owned.live,
		detached_owner = owned.detached,
		allocator_context = owned.memory,
		provider_user = provider.user,
		provider_owner = provider.owner,
		author_user = author.user,
		author_owner = author.owner,
		effect_owner = effects.owner,
		effect_user = effects.user,
	}
}
sdk_context_destroy :: proc(owned: ^SDK_Context) -> ksim.World_Error {
	if owned == nil {return .Ok}
	if !ksim.world_owner_is_empty(
		owned.live,
	) {if e := ksim.world_owner_drop(owned.live); e != .Ok {return e}; owned.live = {}}
	if !ksim.world_owner_is_empty(
		owned.detached,
	) {if e := ksim.world_owner_drop(owned.detached); e != .Ok {return e}; owned.detached = {}}
	if status := bm.destroy(&owned.memory); status != bg.OK {return host_status(status)}
	return .Ok
}
@(private)
host_status :: proc "contextless" (status: bg.Status) -> ksim.World_Error {
	switch status {
	case bg.OK:
		return .Ok
	case bg.OUT_OF_MEMORY:
		return .Allocation_Failed
	case bg.CAPACITY:
		return .Budget
	case bg.INCOMPATIBLE:
		return .Incompatible
	case bg.UNSUPPORTED:
		return .Unsupported
	case:
		return .Rejected
	}
}

// C-shaped cross-realm complete owner. Only this Core capsule travels between
// modules. Typed World_Checkpoint/Side/typeid/allocator structs stay in origin.
SDK_CHECKPOINT_DUMP :: u32(16)
SDK_CHECKPOINT_BODY_STATE :: u32(17)
SDK_CHECKPOINT_KEY_VALID :: u32(18)
SDK_Checkpoint_Dump_Args :: struct {
	out:      [^]u8,
	capacity: u64,
	required: ^u64,
}
SDK_Checkpoint_Body_Args :: struct {
	key:   u64,
	state: ^b3.Body_State,
}
@(private)
SDK_Checkpoint_Holder :: struct($Side: typeid) {
	checkpoint: ksim.World_Checkpoint,
	allocator:  mem.Allocator,
}
// Transfers the complete checkpoint only on success. The capsule dispatcher is
// called by stable Core with its generation/call pin already active; the whole
// typed destructor returns into Core before that pin/gate can be dropped.
sdk_checkpoint_capsule :: proc(
	checkpoint: ^ksim.World_Checkpoint,
	$Side: typeid,
	out: ^bg.Capsule,
) -> ksim.World_Error {
	if out == nil || checkpoint == nil {return .Invalid}
	if out.user != nil {return .Busy}
	if e := ksim.world_checkpoint_owner_check(checkpoint); e != .Ok {return e}
	if checkpoint.image == nil ||
	   checkpoint.side_type != Side ||
	   ksim.world_owner_is_empty(checkpoint.owner) {return .Unsupported}
	service := bg.service_get(
		
	); if service.realm == 0 || service.capsule_create == nil {return .Incompatible}
	holder, allocation_error := new(SDK_Checkpoint_Holder(Side), checkpoint.allocator)
	if allocation_error != nil || holder == nil {return .Allocation_Failed}
	holder.checkpoint = checkpoint^; holder.allocator = checkpoint.allocator
	dispatch := proc "c" (data: rawptr, operation: u32, args: rawptr) -> bg.Status {
		context = runtime.default_context()
		h := cast(^SDK_Checkpoint_Holder(Side))data
		if h == nil {return bg.INVALID_ARGUMENT}
		if e := ksim.world_checkpoint_owner_check(&h.checkpoint); e != .Ok {return bg.INCOMPATIBLE}
		switch operation {
		case bg.CAPSULE_DESTROY:
			allocator := h.allocator
			if e := ksim.world_checkpoint_destroy(&h.checkpoint); e != .Ok {return bg.INCOMPATIBLE}
			free(h, allocator); return bg.OK
		case bg.CAPSULE_CLONE:
			if args == nil {return bg.INVALID_ARGUMENT}
			cloned, error := ksim.world_checkpoint_clone(
				&h.checkpoint,
			); if error != .Ok {return bg.CAPACITY}
			result := sdk_checkpoint_capsule(&cloned, Side, (cast(^bg.Capsule_Clone_Args)args).out)
			if result != .Ok {_ = ksim.world_checkpoint_destroy(&cloned); return bg.CAPACITY}
			return bg.OK
		case SDK_CHECKPOINT_DUMP:
			if args == nil {return bg.INVALID_ARGUMENT}; a := cast(^SDK_Checkpoint_Dump_Args)args
			if a.required == nil ||
			   a.capacity > u64(max(int)) ||
			   (a.capacity != 0 && a.out == nil) {return bg.INVALID_ARGUMENT}
			bytes: []u8; if a.capacity != 0 {bytes = a.out[:int(a.capacity)]}
			required, error := checkpoint_dump(&h.checkpoint, bytes, Side)
			if error != .Ok && error != .Capacity {return bg.INCOMPATIBLE}
			a.required^ = required; return error == .Ok ? bg.OK : bg.CAPACITY
		case SDK_CHECKPOINT_BODY_STATE:
			if args == nil {return bg.INVALID_ARGUMENT}; a := cast(^SDK_Checkpoint_Body_Args)args
			if a.state == nil {return bg.INVALID_ARGUMENT}
			state, error := checkpoint_body_state(&h.checkpoint, b3.Body_Key(a.key), Side)
			if error != .Ok {return bg.INVALID_HANDLE}; a.state^ = state; return bg.OK
		case SDK_CHECKPOINT_KEY_VALID:
			if args == nil {return bg.INVALID_ARGUMENT}; a := cast(^SDK_Checkpoint_Body_Args)args
			_, error := checkpoint_body_state(&h.checkpoint, b3.Body_Key(a.key), Side)
			return error == .Ok ? bg.OK : bg.INVALID_HANDLE
		case:
			return bg.UNSUPPORTED
		}
	}
	capsule: bg.Capsule
	status := service.capsule_create(service.user, &checkpoint.owner, holder, dispatch, &capsule)
	if status != bg.OK {free(holder, checkpoint.allocator); return host_status(status)}
	checkpoint^ = {}; out^ = capsule; return .Ok
}
