package replay_view

import "core:mem"
import r "godot:replay"

MAX_INDEX_CAPACITY :: 65536
Index_Error :: enum {None, Invalid, Capacity, Duplicate}
// Bounded presentation identity lookup. Zero is reserved for an empty bucket.
// Rebuild after removals; entries are not silently evicted. Keep the owner stable.
Key_Index :: struct {
    allocator:mem.Allocator,
    keys:[]u64,
    values:[]int,
    occupied:[]u32,
    capacity,count:int,
    probes:u64,
}
key_index_init :: proc(index:^Key_Index,capacity:int,allocator:=context.allocator)->bool {
    if len(index.keys)!=0 || capacity<1 || capacity>MAX_INDEX_CAPACITY {return false}
    buckets:=2;for buckets<capacity*2 {buckets*=2}
    index.allocator,index.capacity=allocator,capacity
    index.keys=make([]u64,buckets,allocator);index.values=make([]int,buckets,allocator)
    index.occupied=make([]u32,capacity,allocator)
    return true
}
key_index_destroy :: proc(index:^Key_Index) {delete(index.keys,index.allocator);delete(index.values,index.allocator);delete(index.occupied,index.allocator);index^={}}
key_index_clear :: proc(index:^Key_Index) {
    // Sparse owners clear only occupied buckets; dense owners retain contiguous
    // clearing. Recorded bucket indices are bounded by the allocated table.
    if index.count*4<len(index.keys) {for at in index.occupied[:index.count] {index.keys[at]=0}}
    else {for &key in index.keys {key=0}}
    index.count=0
}
key_index_put :: proc(index:^Key_Index,key:u64,value:int)->Index_Error {
    if len(index.keys)==0 || key==0 {return .Invalid}
    at:=key_index_bucket(key,len(index.keys))
    for _ in 0..<len(index.keys) {
        index.probes+=1
        if index.keys[at]==key {return .Duplicate}
        if index.keys[at]==0 {
            if index.count==index.capacity {return .Capacity}
            index.occupied[index.count]=u32(at)
            index.keys[at],index.values[at]=key,value;index.count+=1;return .None
        }
        at=(at+1)&(len(index.keys)-1)
    }
    return .Capacity
}
key_index_get :: proc(index:^Key_Index,key:u64)->(int,bool) {
    if len(index.keys)==0 || key==0 {return 0,false}
    at:=key_index_bucket(key,len(index.keys))
    for _ in 0..<len(index.keys) {
        index.probes+=1
        if index.keys[at]==0 {return 0,false}
        if index.keys[at]==key {return index.values[at],true}
        at=(at+1)&(len(index.keys)-1)
    }
    return 0,false
}
// Pool/timeline identity is supplied by the owning view pool. Within it, retain
// the complete generation and index instead of aliasing reused entity slots.
handle_key :: proc(handle:r.Handle($T))->u64 {
    if handle.generation==0 || handle.index==max(u32) {return 0}
    return u64(handle.generation)<<32 | (u64(handle.index)+1)
}
@(private)
key_index_bucket :: proc(key:u64,buckets:int)->int {
    value:=key
    value=(value~(value>>30))*0xbf58476d1ce4e5b9
    value=(value~(value>>27))*0x94d049bb133111eb
    value=value~(value>>31)
    return int(value&u64(buckets-1))
}
