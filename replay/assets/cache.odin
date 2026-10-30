package replay_assets

import "core:mem"
import tf "godot:replay/transfer"
import sc "godot:replay/schema"

ID :: distinct [32]u8
// Value-only reference: safe in frames, schemas and checkpoints. Bytes live in a
// separate cache; changing content produces a different ID.
Ref :: struct {id: ID, bytes: u32}
REF_BYTES :: 36
MAX_ASSET_BYTES :: tf.MAX_BYTES - sc.HEADER_BYTES - REF_BYTES
Error :: enum {None, Invalid_Config, Not_Ready, Invalid_Ref, Integrity, Capacity, Missing, Pinned, Invalid_Buffer, Invalid_Content}
Cache_Config :: struct {entries, max_asset_bytes, max_total_bytes: int}
DEFAULT_CACHE_CONFIG :: Cache_Config{32,128*1024,4*1024*1024}

Cache :: struct {
 ready: bool,
 allocator: mem.Allocator,
 cfg: Cache_Config,
 items: []Item,
 bytes, count: int,
}
@(private)
Item :: struct {ref: Ref, data: []u8, pins: u32}

ref_valid :: proc(ref: Ref) -> bool {return ref.id != (ID{}) && ref.bytes > 0 && ref.bytes <= MAX_ASSET_BYTES}
reference :: proc(bytes: []u8) -> Ref {
 if len(bytes)==0 || len(bytes)>MAX_ASSET_BYTES {return {}}
 return {ID(tf.hash(bytes)),u32(len(bytes))}
}
cache_init :: proc(c: ^Cache, cfg := DEFAULT_CACHE_CONFIG, allocator := context.allocator) -> Error {
 if c.ready || cfg.entries<1 || cfg.entries>1024 || cfg.max_asset_bytes<1 || cfg.max_asset_bytes>MAX_ASSET_BYTES ||
    cfg.max_total_bytes<cfg.max_asset_bytes || cfg.max_total_bytes>64*1024*1024 {return .Invalid_Config}
 c.allocator,c.cfg=allocator,cfg
 c.items=make([]Item,cfg.entries,allocator); c.ready=true; return .None
}
cache_destroy :: proc(c: ^Cache) {
 for item in c.items {delete(item.data,c.allocator)}
 delete(c.items,c.allocator); c^={}
}
@(private)
cache_index :: proc(c: ^Cache, ref: Ref) -> int {
 if !c.ready || !ref_valid(ref) {return -1}
 for item,i in c.items {if item.ref==ref {return i}}
 return -1
}
cache_has :: proc(c: ^Cache, ref: Ref) -> bool {return cache_index(c,ref)>=0}

// Returns the total available, writing at most len(dst), without exposing bytes.
cache_refs :: proc(c: ^Cache, dst: []Ref) -> int {
 count:=0
 if c.ready {for item in c.items {if item.ref!=(Ref{}) {if count<len(dst) {dst[count]=item.ref};count+=1}}}
 return count
}

// Preflight before allocation/mutation. Capacity never evicts unrelated content;
// callers release pins and explicitly discard assets no longer needed.
cache_put :: proc(c: ^Cache, bytes: []u8, expected: Ref = {}) -> (Ref, Error) {
 if !c.ready {return {},.Not_Ready}
 if len(bytes)==0 || len(bytes)>c.cfg.max_asset_bytes {return {},.Capacity}
 ref:=reference(bytes)
 if expected!=(Ref{}) && (!ref_valid(expected) || expected!=ref) {return {},.Integrity}
 free:=-1
 for item,i in c.items {
  if item.ref.id==ref.id {
   if item.ref!=ref {return {},.Integrity}
   for b,j in bytes {if b!=item.data[j] {return {},.Integrity}}
   return ref,.None
  }
  if item.ref==(Ref{}) {free=i}
 }
 if free<0 || len(bytes)>c.cfg.max_total_bytes-c.bytes {return {},.Capacity}
 copy_bytes:=make([]u8,len(bytes),c.allocator); copy(copy_bytes,bytes)
 c.items[free]={ref=ref,data=copy_bytes}; c.bytes+=len(bytes); c.count+=1
 return ref,.None
}

// Copies prevent an ordinary cache read from mutating hash-addressed content.
cache_read :: proc(c: ^Cache, ref: Ref, dst: []u8) -> Error {
 index:=cache_index(c,ref); if index<0 {return .Missing}
 if len(dst)!=int(ref.bytes) {return .Invalid_Buffer}
 copy(dst,c.items[index].data); return .None
}
cache_copy :: proc(c: ^Cache, ref: Ref, allocator := context.allocator) -> ([]u8, Error) {
 if !cache_has(c,ref) {return nil,.Missing}
 bytes:=make([]u8,int(ref.bytes),allocator)
 if err:=cache_read(c,ref,bytes); err!=.None {delete(bytes,allocator);return nil,err}
 return bytes,.None
}
cache_pin :: proc(c: ^Cache, ref: Ref) -> Error {
 index:=cache_index(c,ref); if index<0 {return .Missing}
 if c.items[index].pins==max(u32) {return .Capacity}
 c.items[index].pins+=1; return .None
}
cache_unpin :: proc(c: ^Cache, ref: Ref) -> Error {
 index:=cache_index(c,ref); if index<0 {return .Missing}
 if c.items[index].pins==0 {return .Pinned}
 c.items[index].pins-=1; return .None
}
cache_discard :: proc(c: ^Cache, ref: Ref) -> Error {
 index:=cache_index(c,ref); if index<0 {return .Missing}
 if c.items[index].pins!=0 {return .Pinned}
 c.bytes-=len(c.items[index].data); c.count-=1
 delete(c.items[index].data,c.allocator); c.items[index]={}; return .None
}
