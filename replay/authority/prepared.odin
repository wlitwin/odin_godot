package replay_authority

import "core:mem"
import r "godot:replay"
import bg "godot:box3d/godot"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

// Owned copy held across coordinator preparation/claim. Ongoing replication may
// recycle its older slots without invalidating this exact proposed recovery point.
// Optional runtime metadata; Point and canonical bytes/wire remain unchanged.
Prepared_Ownership :: struct {container:r.Owned_Context}
Prepared :: struct {
 ownership:Prepared_Ownership,
 retained:r.Owner_Retains,
 cleanup,owned_active:bool,
 owned:net.Complete_Data,
 allocator:mem.Allocator,ready:bool,point:Point,bytes:[]u8,
}
@(private)
prepared_access :: proc(p:^Prepared)->bool {
 if p==nil || r.owned_context_access(p.ownership.container,p)!=.None{return false}
 return r.owner_retains_access(&p.retained)==.None
}
prepared_destroy :: proc(p: ^Prepared)->Error {
 if !prepared_access(p){return .Invalid}
 if !p.cleanup {
  p.ready=false
  bytes:=p.bytes;p.bytes=nil
  if p.owned_active {
   if net.complete_data_destroy(&p.owned)!=.None{return .Invalid}
  } else {delete(bytes,p.allocator)}
 }
 retained:=p.retained;p^={}
 if r.owner_retains_drop(&retained)!=.None{p.retained=retained;p.cleanup=true;return .Invalid}
 return .None
}
@(private)
prepared_sdk :: proc(model:net.Model($S,$C,$A,$E,$N))->bool {
 return model.complete_state && (bg.module_profile()!=0 || !r.owner_is_nil(model.complete_codec.ownership.allocator.owner))
}
@(private)
prepared_retain :: proc(p:^Prepared,ownership:Prepared_Ownership,required:bool)->(r.Owner_Retains,Error){
 if !prepared_access(p){return {},.Invalid}
 if p.ready || p.cleanup || p.retained.count!=0{return {},.Busy}
 if r.owned_context_access(ownership.container,p,required)!=.None{return {},.Invalid}
 retained:r.Owner_Retains;owners:=[?]r.Owner{ownership.container.owner}
 if r.owner_retains_acquire(&retained,owners[:])!=.None{r.owner_retains_drop(&retained);return {},.Invalid}
 return retained,.None
}

// A still-running former owner can retain its frozen world across coordinator
// restart. It must obtain a new epoch through Recover_Owner before restoring it.
prepared_capture :: proc(p: ^Prepared, server: ^net.Server($S, $C, $A, $E, $N), room, binding: u64,
                         codec: ^net.Checkpoint_Codec = nil, allocator := context.allocator,ownership:Prepared_Ownership={}) -> Error {
 if !prepared_access(p){return .Invalid}
 if p.ready{return .Busy}
 if !server.initialized || !server.cfg.require_permit || room==0 || binding==0{return .Invalid}
 retained,error:=prepared_retain(p,ownership,prepared_sdk(server.model));if error!=.None{return error}
 owned:net.Complete_Data;transferred:=false
 defer if !transferred{net.complete_data_destroy(&owned);r.owner_retains_drop(&retained)}
 cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
 if net.checkpoint_capture(server,&cp,allocator=allocator)!=.None{return .Invalid}
 encode_error:net.Error
 owned,encode_error=net.checkpoint_encode_owned(&cp,server.model,allocator,codec);if encode_error!=.None{return .Invalid}
 p^={ownership=ownership,retained=retained,owned_active=true,owned=owned,allocator=allocator,ready=true,bytes=owned.bytes,
  point={{room,server.cfg.epoch,binding,server.cfg.content},{sequence=1,tick=cp.frame.tick,bytes=u32(len(owned.bytes)),hash=rec.hash(owned.bytes)}}}
 transferred=true;return .None
}
prepared_copy :: proc(p:^Prepared,receiver:^rec.Receiver($S,$C,$A,$E,$N),archive:rec.Archive,
                      allocator:=context.allocator,ownership:Prepared_Ownership={})->Error {
 retained,error:=prepared_retain(p,ownership,prepared_sdk(receiver.model));if error!=.None{return error}
 owned:net.Complete_Data;transferred:=false
 defer if !transferred{net.complete_data_destroy(&owned);r.owner_retains_drop(&retained)}
 cp,found:=rec.receiver_checkpoint(receiver,archive);if !found{return .No_Checkpoint}
 encode_error:net.Error
 owned,encode_error=net.checkpoint_encode_owned(cp,receiver.model,allocator,&receiver.archive_codec);if encode_error!=.None{return .Invalid}
 if rec.hash(owned.bytes)!=archive.hash || len(owned.bytes)!=int(archive.bytes){return .Invalid}
 p^={ownership=ownership,retained=retained,owned_active=true,owned=owned,allocator=allocator,ready=true,bytes=owned.bytes,point={receiver.scope,archive}}
 transferred=true;return .None
}

prepared_restore :: proc(p: ^Prepared, server: ^net.Server($S, $C, $A, $E, $N), model: net.Model(S, C, A, E, N),
                         wire: tr.Transport, lease: ^Lease, local_seat: u16, preserve_pending: bool = false,
                         options: net.Resume_Options = {}, allocator := context.allocator, codec: ^net.Checkpoint_Codec = nil,runner_ownership:net.Runner_Ownership={}) -> net.Error {
	cp: net.Checkpoint(S, C, A, N)
	defer net.checkpoint_destroy(&cp)
	if err := prepared_decode(p, &cp, model, lease, allocator, codec); err != .None {return err}
	resume := options
	resume.epoch, resume.local_seat, resume.preserve_pending, resume.permit = lease.view.epoch, local_seat, preserve_pending, lease_permit(lease)
	if !cp.settings.require_permit {return .Invalid_Config}
	return net.server_restore(server, &cp, model, wire, resume, allocator,ownership=runner_ownership)
}

prepared_decode :: proc(p: ^Prepared, cp: ^net.Checkpoint($S, $C, $A, $N), model: net.Model(S, C, A, $E, N),
                        lease: ^Lease, allocator := context.allocator, codec: ^net.Checkpoint_Codec = nil) -> net.Error {
 if !prepared_access(p) || (prepared_sdk(model) && r.owner_is_nil(p.ownership.container.owner)){return .Invalid_Checkpoint}
	if !p.ready || !lease.require_owner || lease.view.recovered != p.point || !lease_live(lease, lease.view.epoch) {return .Fenced}
	if rec.hash(p.bytes) != p.point.archive.hash {return .Invalid_Checkpoint}
	if err := net.checkpoint_decode(cp, p.bytes, model, lease.content, allocator, codec); err != .None {return err}
	if !cp.settings.require_permit {net.checkpoint_destroy(cp); return .Invalid_Config}
	return .None
}
