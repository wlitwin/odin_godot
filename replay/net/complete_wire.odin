package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

COMPLETE_HEADER_BYTES :: 32 + bd.SIGNATURE_BYTES
Complete_Purpose :: enum u32 {Welcome=1, Snapshot=2, Archive=3}

Complete_Data :: struct {
	bytes: []u8,
	allocator: mem.Allocator,
	_release: proc(rawptr,u64),
	_catalog: rawptr,
 lifetime:Container_Lifetime,
}
Complete_Inspection :: struct {
	purpose: Complete_Purpose,
	signature: bd.Signature,
	metadata, attachment: []u8,
	frame: bd.Frame_View,
}
// Adopt only after successful allocation. Failure leaves the caller owning
// its bytes and callback charge, so it can roll back without partial transfer.
complete_data_adopt :: proc(bytes:[]u8,allocator:mem.Allocator,codec:Complete_Codec($S,$E))->(Complete_Data,Error){
 life:Container_Lifetime
 if error:=container_acquire(&life,codec.ownership,allocator,codec.catalog,#config(BOX3D_REQUIRE_DOMAIN,false));error!=.None{container_drop(&life);return {},error}
 return {bytes=bytes,allocator=allocator,_release=codec.release,_catalog=codec.catalog,lifetime=life},.None
}
complete_data_destroy :: proc(data: ^Complete_Data)->Error {
 if data==nil{return .None}
 if error:=container_access(&data.lifetime);error!=.None{return error}
 life:=data.lifetime
 if !life.cleanup {
  n:=len(data.bytes);delete(data.bytes,data.allocator)
  if data._release!=nil{data._release(data._catalog,u64(n))}
 }
 data^={}
 if error:=container_drop(&life);error!=.None{life.cleanup=true;data.lifetime=life;return error}
 return .None
}

complete_encode :: proc(codec: Complete_Codec($S,$E), checkpoint: ^r.Complete_Checkpoint(S,E), purpose: Complete_Purpose,
                         metadata: []u8, state, occurrence: ^sc.Schema, allocator:=context.allocator) -> (Complete_Data,Error) {
	if purpose<.Welcome || purpose>.Archive || len(metadata)>65536 {return {},.Invalid_Frame}
	view,view_error:=complete_view(codec,checkpoint,state,occurrence,allocator)
	if view_error!=.None {return {},view_error};defer complete_view_destroy(&view)
	signature,signature_error:=bd.sign(view.frame)
	if signature_error!=.None {return {},.Invalid_Frame}
	attachment_bytes,attachment_error:=codec.encode(codec.catalog,checkpoint,nil)
	if attachment_error!=.None {return {},attachment_error}
	if attachment_bytes<=0 || attachment_bytes>int(codec.max_attachment_bytes) {return {},.Capacity}
	total:=COMPLETE_HEADER_BYTES+32+len(metadata)+attachment_bytes
	for part in bd.Part {total+=len(view.frame.parts[part])}
	if total>COMPLETE_MAX_BYTES {return {},.Capacity}
	if error:=codec.reserve(codec.catalog,u64(total));error!=.None {return {},error}
	storage,allocation_error:=mem.alloc_bytes(total,allocator=allocator)
	if allocation_error!=.None || len(storage)!=total {
		if len(storage)!=0 {delete(storage,allocator)}
		codec.release(codec.catalog,u64(total));return {},.Capacity
	}
	result,owner_error:=complete_data_adopt(storage,allocator,codec)
 if owner_error!=.None{delete(storage,allocator);codec.release(codec.catalog,u64(total));return {},owner_error}
	committed:=false;defer if !committed {complete_data_destroy(&result)}
	copy(storage[:8],"RPLPHY01")
	complete_put32(storage[8:12],COMPLETE_WIRE_VERSION);complete_put32(storage[12:16],u32(purpose))
	complete_put32(storage[16:20],u32(len(metadata)));complete_put32(storage[20:24],u32(attachment_bytes))
	complete_put32(storage[24:28],u32(total));complete_put32(storage[28:32],0)
	_,encoded_signature:=bd.signature_encode(signature,storage[32:COMPLETE_HEADER_BYTES])
	if encoded_signature!=.None {return {},.Invalid_Frame}
	at:=COMPLETE_HEADER_BYTES
	copy(storage[at:at+len(metadata)],metadata);at+=len(metadata)
	for part in bd.Part {source:=view.frame.parts[part];copy(storage[at:at+len(source)],source);at+=len(source)}
	actual,write_error:=codec.encode(codec.catalog,checkpoint,storage[at:at+attachment_bytes])
	if write_error!=.None || actual!=attachment_bytes {return {},write_error==.None?Error.Invalid_Frame:write_error}
	at+=attachment_bytes;digest:=bd.hash_bytes(storage[:at]);copy(storage[at:at+32],digest[:])
	committed=true;return result,.None
}

// Borrows input only. All declared bounds, metadata, identity and diagnostic
// hashes are checked before any native decode or framework state mutation.
complete_inspect :: proc(bytes: []u8, expected: bd.Identity, epoch: u64) -> (Complete_Inspection,Error) {
	if len(bytes)<COMPLETE_HEADER_BYTES+32 || len(bytes)>COMPLETE_MAX_BYTES || string(bytes[:8])!="RPLPHY01" {return {},.Invalid_Frame}
	if complete_get32(bytes[8:12])!=COMPLETE_WIRE_VERSION || complete_get32(bytes[28:32])!=0 || int(complete_get32(bytes[24:28]))!=len(bytes) {return {},.Invalid_Frame}
	purpose:=Complete_Purpose(complete_get32(bytes[12:16]))
	if purpose<.Welcome || purpose>.Archive {return {},.Invalid_Frame}
	meta_bytes:=int(complete_get32(bytes[16:20]));attachment_bytes:=int(complete_get32(bytes[20:24]))
	if meta_bytes>65536 || attachment_bytes<=0 || attachment_bytes>COMPLETE_MAX_BYTES {return {},.Capacity}
	signature,signature_error:=bd.signature_decode(bytes[32:COMPLETE_HEADER_BYTES])
	if signature_error!=.None || signature.identity!=expected || signature.epoch!=epoch {return {},.Checkpoint_Contract}
	count:=u64(COMPLETE_HEADER_BYTES+32+meta_bytes+attachment_bytes)
	for size in signature.lengths {if size>u64(COMPLETE_MAX_BYTES)-min(count,u64(COMPLETE_MAX_BYTES)) {return {},.Capacity};count+=size}
	if count!=u64(len(bytes)) {return {},.Invalid_Frame}
	digest:=bd.hash_bytes(bytes[:len(bytes)-32]);if string(digest[:])!=string(bytes[len(bytes)-32:]) {return {},.Invalid_Frame}
	result:=Complete_Inspection{purpose=purpose,signature=signature,frame={identity=expected,epoch=epoch,tick=signature.tick}}
	at:=COMPLETE_HEADER_BYTES
	result.metadata=bytes[at:at+meta_bytes];at+=meta_bytes
	for part in bd.Part {size:=int(signature.lengths[part]);result.frame.parts[part]=bytes[at:at+size];at+=size}
	result.attachment=bytes[at:at+attachment_bytes]
	recomputed,recompute_error:=bd.sign(result.frame)
	if recompute_error!=.None || bd.compare(signature,recomputed)!=.Match {return {},.Invalid_Frame}
	return result,.None
}

complete_decode_image :: proc(codec: Complete_Codec($S,$E), inspection: Complete_Inspection, frame: r.Frame(S),
                               state, occurrence: ^sc.Schema, allocator:=context.allocator) -> (r.Complete_Checkpoint(S,E),Error) {
 life:Container_Lifetime
 if error:=container_acquire(&life,codec.ownership,allocator,codec.catalog,#config(BOX3D_REQUIRE_DOMAIN,false));error!=.None{container_drop(&life);return {},error}
 defer container_drop(&life)

	if !complete_codec_valid(codec) || inspection.signature.identity!=codec.identity || frame.tick!=inspection.signature.tick {return {},.Checkpoint_Contract}
	if len(inspection.attachment)>int(codec.max_attachment_bytes) {return {},.Capacity}
	event_bytes:=inspection.frame.parts[.Occurrences]
	if len(event_bytes)<4 {return {},.Invalid_Frame}
	count:=int(complete_get32(event_bytes[:4]))
	if count>WIRE_EVENTS || len(event_bytes)!=4+count*occurrence.wire_size {return {},.Invalid_Frame}
	if int(inspection.signature.lengths[.Game])!=state.wire_size {return {},.Invalid_Frame}
	if count!=0 && u64(size_of(r.Occurrence(E)))>u64(COMPLETE_MAX_BYTES)/u64(count) {return {},.Capacity}
	temporary_bytes:=u64(state.wire_size)+u64(count)*u64(size_of(r.Occurrence(E)))
	if temporary_bytes>COMPLETE_MAX_BYTES {return {},.Capacity}
	if error:=codec.reserve(codec.catalog,temporary_bytes);error!=.None {return {},error}
	defer codec.release(codec.catalog,temporary_bytes)
	canonical_state,canonical_error:=mem.alloc_bytes(state.wire_size,allocator=allocator)
	if canonical_error!=.None {return {},.Capacity};defer delete(canonical_state,allocator)
	if sc.encode(state,frame.state,canonical_state).error!=.None || string(canonical_state)!=string(inspection.frame.parts[.Game]) {return {},.Invalid_Frame}
	event_pointer,event_allocation_error:=mem.alloc(count*size_of(r.Occurrence(E)),align_of(r.Occurrence(E)),allocator)
	if event_allocation_error!=.None {return {},.Capacity};defer mem.free(event_pointer,allocator)
	events:=(cast([^]r.Occurrence(E))event_pointer)[:count]
	for &event,index in events {
		at:=4+index*occurrence.wire_size
		if sc.decode(occurrence,&event,event_bytes[at:at+occurrence.wire_size]).error!=.None || event.id.epoch!=inspection.signature.epoch || event.id.tick!=frame.tick {return {},.Invalid_Frame}
		for prior in events[:index] {if prior.id==event.id {return {},.Invalid_Frame}}
	}
	checkpoint,decode_error:=codec.decode(codec.catalog,frame,inspection.signature.epoch,events,inspection.attachment)
	if decode_error!=.None {r.complete_checkpoint_destroy(&checkpoint);return {},decode_error}
	committed:=false;defer if !committed {r.complete_checkpoint_destroy(&checkpoint)}
	view,view_error:=complete_view(codec,&checkpoint,state,occurrence,allocator)
	if view_error!=.None {return {},view_error};defer complete_view_destroy(&view)
	actual,sign_error:=bd.sign(view.frame)
	if sign_error!=.None || bd.compare(inspection.signature,actual)!=.Match {return {},.Invalid_Frame}
	committed=true;return checkpoint,.None
}

@(private) complete_put32 :: proc(dst:[]u8,value:u32){for i in 0..<4 {dst[i]=u8(value>>uint(i*8))}}
@(private) complete_get32 :: proc(src:[]u8)->u32{value:u32;for i in 0..<4 {value|=u32(src[i])<<uint(i*8)};return value}
