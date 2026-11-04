package replay_recovery

import "core:mem"

import replay "godot:replay"
import net "godot:replay/net"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

receiver_init :: proc(r: ^Receiver($S, $C, $A, $E, $N), scope: Scope, source: tr.Peer_Id, wire: tr.Transport,
                      model: net.Model(S, C, A, E, N), cfg := DEFAULT_CONFIG, allocator := context.allocator,ownership:Receiver_Ownership={}) -> Error {
	if r.ready || r.receiver_cleanup{return .Wrong_Phase}
	if model.complete_state && model.complete_codec.transfer_budget.reserve==nil{return .Invalid_Config}
 if error:=tf.ownership_validate(ownership.transfer,allocator,&r.transfer,wire.user,r,nil,model.complete_codec.transfer_budget.user);error!=.None{return error}
 if error:=receiver_ownership_check(ownership,model,allocator,&r.model,r.policy_user);error!=.None{return error}
 r.receiver_ownership=ownership
 owners:=[?]replay.Owner{ownership.transfer.allocator.owner,ownership.policy.owner,ownership.model.owner,ownership.transfer.container.owner}
 if replay.owner_retains_acquire(&r.receiver_retains,owners[:])!=.None || net.model_ownership_retain(&r.receiver_retains,model)!=.None{
  retained:=r.receiver_retains;r^={};if replay.owner_retains_drop(&retained)!=.None{r.receiver_retains=retained;r.receiver_cleanup=true};return .Invalid_Config
 }
 committed_owner:=false;defer if !committed_owner{receiver_destroy(r)}
	if !config_valid(scope, source, cfg) || (model.step == nil && model.step_view == nil) || model.hold == nil ||
	   model.control_valid == nil || model.state_valid == nil || !model.control_valid(model.neutral) {return .Invalid_Config}
	r.model = model
	if model.complete_state {
		if model.complete_codec.reserve(model.complete_codec.catalog,net.PHYSICS_SCHEMA_RESERVE)!=.None{return .Capacity}
	}
	defer if model.complete_state {model.complete_codec.release(model.complete_codec.catalog,net.PHYSICS_SCHEMA_RESERVE)}
	if net.checkpoint_codec_init(&r.archive_codec, S, C, A, E, N, allocator = allocator,ownership=ownership.codec) != .None { return .Invalid_Archive}
	accept := proc(user: rawptr, archive: Archive, bytes: []u8) -> bool {return receiver_accept(cast(^Receiver(S, C, A, E, N))user, archive, bytes)}
	if err := tf.blob_init(&r.transfer, scope, source, wire, net.CHECKPOINT_KIND, accept, r, cfg, allocator,kind_base=KIND_BASE,max_bytes=net.MAX_CHECKPOINT_BYTES,budget=model.complete_codec.transfer_budget,ownership=ownership.transfer); err != .None { return err}
	if model.complete_state {
		bytes:=net.checkpoint_codec_owned_bytes(&r.archive_codec)
		if bytes>net.PHYSICS_SCHEMA_RESERVE || tf.budget_charge_owner(&r.transfer.budget,bytes)!=.None{return .Capacity}
	}
	schema,offset,ready:=net.checkpoint_frame_layout(&r.archive_codec)
 if !ready {return .Invalid_Archive}
 if !model.complete_state {r.transfer.layout={schema,offset}}
 committed_owner=true
 return .None
}

receiver_destroy :: proc(r: ^Receiver($S, $C, $A, $E, $N))->Error {
 if error:=receiver_owner_entry(r,.Read);error!=.None{return error}
 if !r.receiver_cleanup {
  if net.checkpoint_destroy(&r.current.checkpoint)!=.None || net.checkpoint_destroy(&r.previous.checkpoint)!=.None{return .Invalid_Config}
  if net.checkpoint_codec_destroy(&r.archive_codec)!=.None{return .Invalid_Config}
  if blob_destroy(&r.transfer)!=.None{return .Invalid_Config}
 }
 retained:=r.receiver_retains;r^={}
 if replay.owner_retains_drop(&retained)!=.None{r.receiver_retains=retained;r.receiver_cleanup=true;return .Invalid_Config}
 return .None
}

// Latest fully validated candidate. The previous acknowledged archive can also
// remain available; takeover must request the exact receipt authorized by the
// room coordinator, rather than assuming latest implies legitimate leadership.
receiver_latest :: proc(r: ^Receiver($S, $C, $A, $E, $N)) -> (Receipt, bool) {
 if error:=receiver_owner_entry(r);error!=.None{return {},false}
	return r.current.receipt, r.ready && r.current.checkpoint.ready
}

// Read-only borrow until the next receive/destroy. Never destroy or mutate it.
// This supports persisting the archive and restoring into a separate runtime.
receiver_checkpoint :: proc(r: ^Receiver($S, $C, $A, $E, $N), archive: Archive) -> (^net.Checkpoint(S, C, A, N), bool) {
 if error:=receiver_owner_entry(r);error!=.None{return nil,false}
	if !r.ready {return nil, false}
	if r.current.checkpoint.ready && r.current.receipt.archive == archive {return &r.current.checkpoint, true}
	if r.previous.checkpoint.ready && r.previous.receipt.archive == archive {return &r.previous.checkpoint, true}
	return nil, false
}

receiver_receive :: proc(r: ^Receiver($S, $C, $A, $E, $N), from: tr.Peer_Id, bytes: []u8, now_ms: u64, channel: tr.Channel = .Unreliable) -> Received {
 if error:=receiver_owner_entry(r);error!=.None{return .Rejected}
	return blob_receive(&r.transfer, from, bytes, now_ms,channel)
}

receiver_update :: proc(r: ^Receiver($S, $C, $A, $E, $N), now_ms: u64) -> Error {
 if error:=receiver_owner_entry(r);error!=.None{return error}
	return blob_update(&r.transfer, now_ms)
}

@(private)
receiver_accept :: proc(r: ^Receiver($S, $C, $A, $E, $N), archive: Archive, bytes: []u8) -> bool {
 if error:=receiver_owner_entry(r);error!=.None{return false}
	candidate: net.Checkpoint(S, C, A, N)
	if net.checkpoint_decode(&candidate, bytes, r.model, r.scope.content, r.allocator, &r.archive_codec) != .None {
		net.checkpoint_destroy(&candidate); return false
	}
	if candidate.header.epoch != r.scope.epoch || candidate.header.tick != archive.tick ||
	   (candidate.header.policy_id != 0 && r.policy_valid == nil) ||
	   (r.policy_valid != nil && !r.policy_valid(r.policy_user, candidate.header.policy_id, candidate.policy_data)) {
		net.checkpoint_destroy(&candidate); return false
	}
	if r.offer.retain_sequence == 0 || r.offer.retain_sequence == r.current.receipt.archive.sequence {
		net.checkpoint_destroy(&r.previous.checkpoint)
		r.previous = r.current; r.current = {}
	} else {net.checkpoint_destroy(&r.current.checkpoint)}
	r.current.checkpoint = candidate
	r.current.receipt = {archive, r.clock.now}
	return true
}

@(private)
receiver_ownership_check :: proc(ownership:Receiver_Ownership,model:net.Model($S,$C,$A,$E,$N),allocator:mem.Allocator,model_data,policy_data:rawptr,access:replay.Owner_Access=.Execute)->Error {
 managed:=!replay.owner_is_nil(ownership.transfer.container.owner)
 when #config(BOX3D_REQUIRE_DOMAIN,false){if !managed{return .Invalid_Config}}
 if replay.owned_context_access(ownership.model,model_data,managed,access)!=.None || replay.owned_context_access(ownership.policy,policy_data,managed,access)!=.None{return .Invalid_Config}
 if net.model_ownership_check(model,managed,access)!=.None{return .Invalid_Config}
 return .None
}
@(private)
receiver_owner_entry :: proc(r:^Receiver($S,$C,$A,$E,$N),access:replay.Owner_Access=.Execute)->Error {
 if replay.owner_retains_access(&r.receiver_retains,access)!=.None{return .Invalid_Config}
 if r.receiver_cleanup{return access==.Read?Error.None:Error.Invalid_Config}
 return receiver_ownership_check(r.receiver_ownership,r.model,r.allocator,&r.model,r.policy_user,access)
}
