package kit_module_owner_test

import "base:runtime"
import "core:mem"
import "core:testing"
import net "godot:kit/net"
import session "godot:kit/session"
import sim "godot:kit/sim"

Pure_Image :: struct {
	value: u32,
}
Allocator_Context :: struct {
	base:        mem.Allocator,
	owner:       ^Owner_Context,
	free_checks: u32,
}
checked_allocator :: proc(a: ^Allocator_Context) -> mem.Allocator {
	return {
		data = a,
		procedure = proc(
			data: rawptr,
			mode: mem.Allocator_Mode,
			size, alignment: int,
			old: rawptr,
			old_size: int,
			location: runtime.Source_Code_Location,
		) -> (
			[]u8,
			mem.Allocator_Error,
		) {
			a := cast(^Allocator_Context)data
			if mode == .Free &&
			   old !=
				   nil {assert(a.owner.references > 0, "producer owner dropped before fields/allocator cleanup"); a.free_checks += 1}
			return a.base.procedure(a.base.data, mode, size, alignment, old, old_size, location)
		},
	}
}
pure_provider :: proc(live, detached: sim.World_Owner) -> sim.World_Provider {
	initial := new(Pure_Image); initial.value = 19
	return {
		owner = live,
		detached_owner = detached,
		side_type = u32,
		asset_id = 19,
		initial_execution = initial,
		capture = proc(user, execution: rawptr) -> (rawptr, sim.World_Error) {image := new(
				Pure_Image,
			)
			image^ = (cast(^Pure_Image)execution)^
			return image, .Ok},
		clone = proc(opaque: rawptr) -> (rawptr, sim.World_Error) {image := new(Pure_Image)
			image^ = (cast(^Pure_Image)opaque)^
			return image, .Ok},
		equal = proc(
			a, b: rawptr,
		) -> (
			bool,
			sim.World_Error,
		) {return (cast(^Pure_Image)a).value == (cast(^Pure_Image)b).value, .Ok},
		release = proc(image: rawptr) {free(image)},
		open = proc(user, image: rawptr) -> (rawptr, sim.World_Error) {execution := new(Pure_Image)
			execution^ = (cast(^Pure_Image)image)^
			return execution, .Ok},
		close = proc(execution: rawptr) {free(execution)},
		bind = proc(user, execution: rawptr) {},
		publish = proc(user, execution: rawptr) {},
		step = proc(
			user, execution: rawptr,
			tick: u64,
		) -> sim.World_Error {(cast(^Pure_Image)execution).value += 1; return .Ok},
		admit = proc(
			user, execution: rawptr,
			request: sim.World_Admission,
		) -> sim.World_Error {return(
				request.additional_owned_bytes + request.reserved_bytes <= sim.WORLD_MEMORY_BYTES ? .Ok : .Budget \
			)},
		admit_detached = proc(additional, reserved: u64) -> sim.World_Error {return(
				additional + reserved <= sim.WORLD_MEMORY_BYTES ? .Ok : .Budget \
			)},
	}
}
@(test)
complete_owner_spans_fields_allocator_and_survives_source_free :: proc(t: ^testing.T) {
	testing.expect_value(t, sim.world_owner_realm_install(71), sim.World_Error.Ok)
	shared := new(Owner_Context)
	shared.protected = true; shared.source_alive = true
	live_owner, detached_owner := owner(shared), owner(shared)
	detached_owner.context_caps =
		sim.WORLD_OWNER_MANAGED_DATA | sim.WORLD_OWNER_INDEPENDENT_CONTEXT
	// The source container already owns its allocator before participant attach.
	testing.expect_value(t, sim.world_owner_retain(live_owner), sim.World_Error.Ok)
	allocator_context := new(
		Allocator_Context,
	); allocator_context.base = context.allocator; allocator_context.owner = shared
	lane := new(sim.Lane); ses := new(session.Session); ses.is_host = true; ses.me = 1
	sim.lane_init(lane, ses, 0, cfg = {slots = 128})
	// The live generation protects history cleanup. The detached generation also
	// protects its allocator data; model both as explicit retained managed context.
	allocator_context.owner = shared
	lane.allocator = checked_allocator(allocator_context)
	value := new(u32); value^ = 37
	@(static) fields := []net.Field_Desc{{offset = 0, size = size_of(u32), flags = {.Predicted}}}
	desc := net.Entity_Desc {
		fields = fields,
	}
	sim.lane_track(lane, 1, value, &desc, 1)
	provider := pure_provider(live_owner, detached_owner)
	testing.expect_value(
		t,
		sim.lane_world_attach(
			lane,
			provider,
			[]sim.World_Field_Type{sim.world_field_type(1, u32)},
		),
		sim.World_Error.Ok,
	)
	// Use detached allocator owner for the complete checkpoint fields only.
	lane.world.allocator = checked_allocator(allocator_context)
	checkpoint, error := sim.lane_world_checkpoint(
		lane,
		0,
	); testing.expect_value(t, error, sim.World_Error.Ok)
	testing.expect_value(t, shared.references, i32(4))
	shared.protected = false
	pointer := raw_data(checkpoint.fields)
	testing.expect_value(t, sim.world_checkpoint_destroy(&checkpoint), sim.World_Error.Rejected)
	testing.expect_value(
		t,
		raw_data(checkpoint.fields),
		pointer,
	); testing.expect_value(t, shared.references, i32(4))
	shared.protected = true
	testing.expect_value(t, sim.lane_world_detach(lane), sim.World_Error.Ok)
	testing.expect_value(t, shared.references, i32(2))
	sim.lane_destroy(lane)
	testing.expect_value(t, sim.world_owner_drop(live_owner), sim.World_Error.Ok)
	free(value); free(lane); free(ses) // source container is actually gone
	shared.source_alive = false
	testing.expect_value(
		t,
		sim.world_owner_check(live_owner, sim.WORLD_OWNER_EXECUTE),
		sim.World_Error.Rejected,
	)
	testing.expect_value(t, shared.references, i32(1))
	clone, clone_error := sim.world_checkpoint_clone(
		&checkpoint,
	); testing.expect_value(t, clone_error, sim.World_Error.Ok)
	testing.expect_value(t, shared.references, i32(2))
	equal, eq_error := sim.world_checkpoint_equal(
		&checkpoint,
		&clone,
	); testing.expect_value(t, eq_error, sim.World_Error.Ok); testing.expect(t, equal)
	testing.expect_value(t, sim.world_checkpoint_destroy(&checkpoint), sim.World_Error.Ok)
	testing.expect_value(t, sim.world_checkpoint_destroy(&clone), sim.World_Error.Ok)
	testing.expect_value(
		t,
		shared.references,
		i32(0),
	); testing.expect(t, allocator_context.free_checks > 0)
	free(allocator_context); free(shared)
	testing.expect_value(t, sim.world_checkpoint_owned_bytes(), u64(0))
}

@(test)
declined_last_drop_preserves_only_retry_owner_after_whole_payload_cleanup :: proc(t: ^testing.T) {
	testing.expect_value(t, sim.world_owner_realm_install(71), sim.World_Error.Ok)
	shared := new(Owner_Context); shared.protected = true; shared.source_alive = true
	capability := owner(shared)
	testing.expect_value(t, sim.world_owner_retain(capability), sim.World_Error.Ok)
	lane: sim.Lane; ses := session.Session {
		is_host = true,
		me      = 1,
	}
	sim.lane_init(&lane, &ses, 0)
	provider := pure_provider({}, capability)
	testing.expect_value(t, sim.lane_world_attach(&lane, provider, nil), sim.World_Error.Ok)
	cp, e := sim.lane_world_checkpoint(&lane, 0); testing.expect_value(t, e, sim.World_Error.Ok)
	sim.lane_destroy(&lane)
	testing.expect_value(t, sim.world_owner_drop(capability), sim.World_Error.Ok)
	testing.expect_value(t, shared.references, i32(1))
	shared.deny_drop = true
	testing.expect_value(t, sim.world_checkpoint_destroy(&cp), sim.World_Error.Rejected)
	testing.expect(t, cp.image == nil && raw_data(cp.fields) == nil)
	testing.expect(t, !sim.world_owner_is_empty(cp.owner))
	testing.expect_value(t, sim.world_checkpoint_owned_bytes(), u64(0))
	testing.expect_value(t, shared.references, i32(1))
	shared.deny_drop = false
	testing.expect_value(t, sim.world_checkpoint_destroy(&cp), sim.World_Error.Ok)
	testing.expect_value(t, sim.world_checkpoint_destroy(&cp), sim.World_Error.Ok)
	testing.expect_value(t, shared.references, i32(0))
	sim.lane_destroy(&lane); free(shared)
}
