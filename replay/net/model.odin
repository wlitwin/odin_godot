package replay_net

import r "godot:replay"
import "core:crypto/sha2"
import "core:mem"

@(private)
network_step :: proc(state: ^$State, input: Batch($Control, $Action, $Seats), ctx: ^r.Step(Net_Event($Event))) {
	model := cast(^Model(State, Control, Action, Event, Seats))ctx.user
 if model==nil || model_context_check(model^, #config(BOX3D_REQUIRE_DOMAIN,false) && model.complete_state)!=.None {ctx.error=.External_State;return}
	if !authority_observation_valid(model.authority,input.authority,Seats) {r.abort(ctx); return}
	if (input.prediction_group == 0) != (input.prediction_seat == 0) {r.abort(ctx); return}
	if input.prediction_group != 0 && (input.prediction_group != model.group.id || input.prediction_seat == 0 || int(input.prediction_seat) > Seats) {r.abort(ctx); return}
	for control in input.controls {if !model.control_valid(control) {r.abort(ctx); return}}
	storage: [GAME_EVENTS]r.Occurrence(Event)
	game_ctx := r.Step(Event){tick = ctx.tick, epoch = ctx.epoch, events = storage[:], user = model.user, execution = ctx.execution}
	managed := r.execution_identity(ctx.execution) != 0
	if model.complete_state && !managed {ctx.error = .Incomplete_State; return}
	if model.reset_player != nil {
		for i in 0 ..< Seats {
			if input.fresh & (u64(1) << uint(i)) != 0 {model.reset_player(state, u16(i + 1), &game_ctx)}
		}
	}
	if input.authority.known {model.authority.apply(state,input.authority,&game_ctx)}
	if game_ctx.error != .None {ctx.error = game_ctx.error; return}
	if model.step_view != nil {model.step_view(state, input.controls, input.views, input.joins, input.leaves, &game_ctx)} else {
		model.step(state, input.controls, input.joins, input.leaves, &game_ctx)
	}
	if managed {if error:=r.execution_status(ctx.execution);error!=.None{ctx.error=error;return}}
	if game_ctx.error!=.None{ctx.error=game_ctx.error;return}
	for present, i in input.has_action {
		if !present {continue}
		applied := false
		reason := input.rejections[i]
		if reason == .None && model.action != nil {
			before := state^
			count := game_ctx.count
			before_events := storage
			point: r.External_Savepoint
			if managed {
				var_err: r.Error
				point, var_err = r.execution_savepoint(ctx.execution)
				if var_err != .None {ctx.error = var_err; return}
			}
			applied = model.action(state, u16(i + 1), input.actions[i], &game_ctx)
			if !applied {
				if managed {
					err := r.execution_savepoint_restore(ctx.execution, &point)
					if err != .None {r.execution_savepoint_release(&point); ctx.error = err; return}
				}
				state^ = before; storage = before_events; game_ctx.count = count; reason = .Predicate
			}
			if managed {r.execution_savepoint_release(&point);if error:=r.execution_status(ctx.execution);error!=.None{ctx.error=error;return}}
		}
		// Gameplay source zero is reserved for protocol action verdicts.
		r.emit(ctx, 0, input.sequences[i] << 8 | u64(i + 1), Net_Event(Event){
			kind = .Action_Result, seat = u16(i + 1), sequence = input.sequences[i], applied = applied, reason = reason,
		})
	}
	if game_ctx.error != .None {ctx.error = game_ctx.error; return}
	if input.prediction_group != 0 && !model.group.valid(state^, input.prediction_seat) {r.abort(ctx); return}
	for event in storage[:game_ctx.count] {
		if event.id.source == 0 {ctx.error = .Invalid_Event; return}
		seat := model.event_owner != nil ? model.event_owner(event.value) : 0
		r.emit(ctx, event.id.source, event.id.key, Net_Event(Event){value = event.value, seat = seat})
	}
}

@(private)
config_valid :: proc(cfg: Config) -> bool {
	return cfg.epoch != 0 && cfg.content != 0 && cfg.hz > 0 && cfg.hz <= 240 &&
	       cfg.history >= 32 && cfg.history <= 1024 && cfg.lead >= 2 && cfg.lead < u32(cfg.history) && cfg.max_prediction >= cfg.lead + 2 &&
	       cfg.max_future >= cfg.lead + 2 && cfg.max_future < u32(cfg.history) &&
	       cfg.max_prediction < u32(cfg.history - 2) && cfg.snapshot_every > 0 && cfg.snapshot_every <= 30 &&
	       cfg.watch_delay < u32(cfg.history / 2) &&
	       cfg.timeout_ms >= 1000 && cfg.timeout_ms <= 120000 && cfg.packets_per_pump > 0 &&
	       cfg.packets_per_pump <= 256 && cfg.bytes_per_pump >= 65536 && cfg.bytes_per_pump <= 1024 * 1024 &&
	       cfg.snapshot_history >= 2 && cfg.snapshot_history <= 64 && cfg.egress_bytes_per_second >= 8192 &&
	       cfg.egress_bytes_per_second <= 16 * 1024 * 1024 && cfg.egress_bytes_per_pump >= 8192 && cfg.egress_bytes_per_pump <= 1024 * 1024 &&
	       cfg.unreliable_packet_limit >= 512 && cfg.unreliable_packet_limit <= 65536 && cfg.max_rewind < u32(cfg.history) &&
	       cfg.max_view_span > 0 && cfg.max_view_span < u32(cfg.history) && cfg.view_slack <= 30
}

@(private)
token_valid :: proc(token: Token) -> bool {
	bits := u8(0)
	for b in token {bits |= b}
	return bits != 0
}

@(private)
token_digest :: proc(token: Token) -> [32]u8 {
	data := token
	ctx: sha2.Context_256
	sha2.init_256(&ctx)
	sha2.update(&ctx, data[:])
	digest: [32]u8
	sha2.final(&ctx, digest[:])
	return digest
}

// No native backend dependency. A nonnil owner opts into exact context checks;
// strict complete mode additionally requires explicit allocator/model owners.
@(private)
owned_context_check :: proc(binding:Owned_Context,data:rawptr,managed:bool,access:r.Owner_Access=.Execute)->Error {
 if error:=r.owner_access(binding.owner,access);error!=.None{return .Invalid_Model}
 if (data!=nil && !r.owner_is_nil(binding.owner) && binding.data!=data) ||
    (managed && data!=nil && r.owner_is_nil(binding.owner)){return .Invalid_Model}
 return .None
}
@(private)
model_context_check :: proc(model:Model($S,$C,$A,$E,$N),managed:bool,access:r.Owner_Access=.Execute)->Error {
 if model.complete_state && complete_codec_owner_check(model.complete_codec)!=.None{return .Invalid_Model}
 if error:=owned_context_check(model.user_context,model.user,managed,access);error!=.None{return error}
 return owned_context_check(model.action_admission_context,model.action_admission_user,managed,access)
}
@(private)
runner_managed :: proc(ownership:Runner_Ownership)->bool {
 return !r.owner_is_nil(ownership.allocator.owner) || !r.owner_is_nil(ownership.model.owner)
}
@(private)
runner_context_check :: proc(ownership:Runner_Ownership,allocator:mem.Allocator,model:rawptr,complete:bool,access:r.Owner_Access=.Execute)->Error {
 managed:=runner_managed(ownership)
 when #config(BOX3D_REQUIRE_DOMAIN,false) {if complete && !managed{return .Invalid_Model}}
 if !managed{return .None}
 if r.owner_is_nil(ownership.allocator.owner) || r.owner_is_nil(ownership.model.owner){return .Invalid_Model}
 external:=r.External{owner=ownership.allocator.owner,owner_allocator_data=ownership.allocator.data}
 if error:=r.owner_contexts_check(external,allocator);error!=.None{return .Invalid_Model}
 if error:=r.owner_access(ownership.allocator.owner,access);error!=.None{return .Invalid_Model}
 return owned_context_check(ownership.model,model,true,access)
}
// The model block is retained last and released last. It may be a declared
// subfield of the very Server/Client allocation being destroyed.
@(private)
runner_retain :: proc(retains:^Runner_Retains,ownership:Runner_Ownership,model:^Model($S,$C,$A,$E,$N))->Error {
 owners:=[?]r.Owner{ownership.allocator.owner,model.user_context.owner,model.action_admission_context.owner,
  ownership.wire.owner,ownership.permit.owner,ownership.profile_clock.owner,ownership.profile_sample.owner,
  ownership.identity.owner,ownership.admission.owner,ownership.model.owner}
 for owner in owners {
  if r.owner_is_nil(owner){continue}
  if error:=r.owner_retain(owner);error!=.None{return .Invalid_Model}
  retains.owners[retains.count]=owner;retains.count+=1
 }
 return .None
}
@(private)
runner_drop :: proc(retains:^Runner_Retains)->Error {
 return r.owner_retains_drop(retains)==.None?Error.None:Error.Invalid_Model
}

// Operation/owner adapters may retain these explicit raw application contexts;
// code/allocator ownership does not imply either context is owned.
model_ownership_check :: proc(model:Model($S,$C,$A,$E,$N),managed:bool,access:r.Owner_Access=.Execute)->Error{return model_context_check(model,managed,access)}
model_ownership_retain :: proc(retains:^r.Owner_Retains,model:Model($S,$C,$A,$E,$N))->Error {
 owners:=[?]r.Owner{model.user_context.owner,model.action_admission_context.owner}
 return r.owner_retains_acquire(retains,owners[:])==.None?Error.None:Error.Invalid_Model
}
