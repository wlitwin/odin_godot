package replay_definitions

import "core:mem"
import sc "godot:replay/schema"

Error :: enum {None,Invalid,Schema,Capacity,Missing,In_Use,Collision}
// Portable content identity. Semantic identifies gameplay interpretation; schema
// and content cover canonical values. These checksums are not authentication.
Ref :: struct {semantic,schema,content:u64}
Report :: struct {error:Error,path:[256]u8,message:[256]u8,path_count,message_count:u16}
problem :: proc(error:Error,path,message:string)->Report {
    result:=Report{error=error}
    result.path_count=u16(copy(result.path[:],transmute([]u8)path))
    result.message_count=u16(copy(result.message[:],transmute([]u8)message))
    return result
}
report_path :: proc(report:^Report)->string {return transmute(string)report.path[:report.path_count]}
report_message :: proc(report:^Report)->string {return transmute(string)report.message[:report.message_count]}
Entry :: struct($Value:typeid) {ref:Ref,value:Value,pins:u32,live:bool}
// Single owner, serialized access. Entries never change once published. Callers
// receive copies and explicitly pin versions needed by history/checkpoints.
Store :: struct($Value:typeid) {
    schema:sc.Schema,
    entries:[]Entry(Value),
    bytes,compare:[]u8,
    allocator:mem.Allocator,
    ready:bool,
}
init :: proc(store:^Store($Value),capacity:int,allocator:=context.allocator)->Report {
    if store.ready || store.schema.initialized || capacity<1 || capacity>65536 {return problem(.Invalid,"$","invalid store or capacity")}
    store.allocator=allocator
    report:=sc.init(&store.schema,Value,allocator=allocator)
    if report.error!=.None {return problem(.Schema,report.path,"definition must have a bounded canonical value schema")}
    store.entries=make([]Entry(Value),capacity,allocator)
    store.bytes=make([]u8,store.schema.wire_size,allocator);store.compare=make([]u8,store.schema.wire_size,allocator)
    store.ready=true;return {}
}
// Refuse destruction while a retained dependency remains pinned. Also cleans up
// failed initialization. No implicit eviction or replacement of old definitions.
destroy :: proc(store:^Store($Value))->Error {
    for entry in store.entries {if entry.pins!=0 {return .In_Use}}
    sc.destroy(&store.schema);delete(store.entries,store.allocator);delete(store.bytes,store.allocator);delete(store.compare,store.allocator);store^={};return .None
}
publish :: proc{publish_basic,publish_validated}
@(private)
publish_basic :: proc(store:^Store($Value),value:Value,semantic:u64)->(Ref,Report) {
    validator:proc(Value)->Report
    return publish_validated(store,value,semantic,validator)
}
@(private)
publish_validated :: proc(store:^Store($Value),value:Value,semantic:u64,validate:proc(Value)->Report)->(Ref,Report) {
    if !store.ready || semantic==0 {return {},problem(.Invalid,"$","store must be ready and semantic version nonzero")}
    encoded:=sc.encode(&store.schema,value,store.bytes)
    if encoded.error!=.None {return {},problem(.Schema,encoded.path,"invalid canonical definition value")}
    if validate!=nil {if report:=validate(value);report.error!=.None {return {},report}}
    ref:=Ref{semantic,store.schema.fingerprint,sc.digest(store.bytes)}
    vacancy:=-1
    for entry,i in store.entries {
        if !entry.live {if vacancy<0 {vacancy=i};continue}
        if entry.ref!=ref {continue}
        report:=sc.encode(&store.schema,entry.value,store.compare)
        if report.error!=.None {return {},problem(.Invalid,"$","store metadata was mutated")}
        for byte,j in store.bytes {if byte!=store.compare[j] {return {},problem(.Collision,"$","content checksum collision")}}
        return ref,{}
    }
    if vacancy<0 {return {},problem(.Capacity,"$","definition store is full; release unused versions explicitly")}
    store.entries[vacancy]={ref=ref,value=value,live=true};return ref,{}
}
get :: proc(store:^Store($Value),ref:Ref)->(Value,bool) {
    for entry in store.entries {if entry.live && entry.ref==ref {return entry.value,true}}
    return {},false
}
pin :: proc(store:^Store($Value),ref:Ref)->Error {
    for &entry in store.entries {if entry.live && entry.ref==ref {if entry.pins==max(u32) {return .Capacity};entry.pins+=1;return .None}}
    return .Missing
}
unpin :: proc(store:^Store($Value),ref:Ref)->Error {
    for &entry in store.entries {if entry.live && entry.ref==ref {if entry.pins==0 {return .Invalid};entry.pins-=1;return .None}}
    return .Missing
}
remove :: proc(store:^Store($Value),ref:Ref)->Error {
    for &entry in store.entries {if entry.live && entry.ref==ref {if entry.pins!=0 {return .In_Use};entry={};return .None}}
    return .Missing
}
