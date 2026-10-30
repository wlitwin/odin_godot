package replay_godot

import "core:strings"
import "core:mem"
import net "godot:replay/net"
import sc "godot:replay/schema"
import r "godot:replay"

Browser_Save_Phase :: enum {Closed,Reading,Ready,Writing,Failed}
Browser_Save_Error :: enum {None,Store,Codec,Identity,Policy,Busy}
// Local, self-contained authority archives. Room/permit or custom-policy recovery
// and external asset dependencies require their own approved application flow.
Browser_Checkpoint :: struct($S,$C,$A,$E:typeid,$N:int) {
	phase:Browser_Save_Phase,error:Browser_Save_Error,store_error:Browser_Store_Error,network_error:net.Error,
	op:Browser_Store_Op,namespace,key:string,allocator:mem.Allocator,
	model:net.Model(S,C,A,E,N),content:u64,token:net.Token,
	checkpoint,writing:net.Checkpoint(S,C,A,N),has_checkpoint:bool,
	revision,receipt_serial,saved_tick,saved_hash:u64,last_success:bool,
	frame_codec:sc.Schema,
}
browser_checkpoint_open :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N),namespace,key:string,
                                model:net.Model(S,C,A,E,N),content:u64,token:net.Token)->bool {
	if p.phase!=.Closed || !browser_identity_valid(token) || content==0 {return false}
	p.allocator=context.allocator;p.namespace,p.key=strings.clone(namespace),strings.clone(key)
	p.model,p.content,p.token=model,content,token
	if sc.init(&p.frame_codec,r.Frame(S),allocator=p.allocator).error!=.None {p.error=.Codec;p.phase=.Failed;return false}
	if !browser_store_read(&p.op,p.namespace,p.key,net.MAX_CHECKPOINT_BYTES) {browser_checkpoint_fail(p,.Store);return false}
	p.phase=.Reading;return true
}
browser_checkpoint_fail :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N),error:Browser_Save_Error) {
	if p.phase==.Writing {p.receipt_serial+=1;p.last_success=false}
	p.error,p.store_error=error,p.op.error;p.phase=.Failed
	browser_store_close(&p.op);net.checkpoint_destroy(&p.writing)
}
browser_checkpoint_validate :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N),cp:^net.Checkpoint(S,C,A,N))->Browser_Save_Error {
	if cp.settings.require_permit || cp.header.policy_id!=0 {return .Policy}
	_,found:=net.checkpoint_seat(cp,p.token);return found ? .None : .Identity
}
browser_checkpoint_frame :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N)) {
	if p.phase!=.Reading && p.phase!=.Writing {return}
	if browser_store_poll(&p.op)!=.Complete {return}
	if p.phase==.Reading && p.op.error==.Missing {
		p.revision=0;p.has_checkpoint=false;browser_store_close(&p.op);p.phase=.Ready;return
	}
	if p.op.error!=.None {browser_checkpoint_fail(p,.Store);return}
	if p.phase==.Reading {
		bytes,err:=browser_store_bytes(&p.op,p.allocator);defer delete(bytes,p.allocator)
		if err!=.None {p.op.error=err;browser_checkpoint_fail(p,.Store);return}
		p.network_error=net.checkpoint_decode(&p.checkpoint,bytes,p.model,p.content,p.allocator)
		if p.network_error!=.None {browser_checkpoint_fail(p,.Codec);return}
		if error:=browser_checkpoint_validate(p,&p.checkpoint);error!=.None {browser_checkpoint_fail(p,error);return}
		p.has_checkpoint=true
	} else {
		net.checkpoint_destroy(&p.checkpoint);p.checkpoint=p.writing;p.writing={};p.has_checkpoint=true
		p.receipt_serial+=1;p.last_success=true;p.saved_tick=p.checkpoint.frame.tick
		bytes:=make([]u8,p.frame_codec.wire_size,p.allocator);defer delete(bytes,p.allocator)
		if sc.encode(&p.frame_codec,p.checkpoint.frame,bytes).error!=.None {p.last_success=false;p.error=.Codec;p.phase=.Failed;browser_store_close(&p.op);return}
		p.saved_hash=sc.digest(bytes)
	}
	p.revision=p.op.revision;browser_store_close(&p.op);p.phase=.Ready
}
// Capture once while the game keeps running. true means submitted; inspect the
// completion receipt. The slot's previously observed revision is never refreshed
// merely to permit a write, so a stale tab cannot silently replace a newer save.
browser_checkpoint_save :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N),s:^Session(S,C,A,E,N))->bool {
	if p.phase!=.Ready || !s.ready || !s.authority || s.fenced || s.token!=p.token || s.server.cfg.content!=p.content {return false}
	p.network_error=net.checkpoint_capture(&s.server,&p.writing,allocator=p.allocator)
	if p.network_error!=.None {p.error=.Codec;return false}
	if error:=browser_checkpoint_validate(p,&p.writing);error!=.None {p.error=error;net.checkpoint_destroy(&p.writing);return false}
	bytes,err:=net.checkpoint_encode(&p.writing,p.model,p.allocator);defer delete(bytes,p.allocator)
	if err!=.None {p.network_error=err;p.error=.Codec;net.checkpoint_destroy(&p.writing);return false}
	p.phase=.Writing;p.last_success=false;p.error=.None
	if !browser_store_write(&p.op,p.namespace,p.key,bytes,p.revision,net.MAX_CHECKPOINT_BYTES) {browser_checkpoint_fail(p,.Store);return false}
	return true
}
browser_checkpoint_close :: proc(p:^Browser_Checkpoint($S,$C,$A,$E,$N)) {
	browser_store_close(&p.op);net.checkpoint_destroy(&p.checkpoint);net.checkpoint_destroy(&p.writing)
	sc.destroy(&p.frame_codec);delete(p.namespace,p.allocator);delete(p.key,p.allocator);p^={}
}
