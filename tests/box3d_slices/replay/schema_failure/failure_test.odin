package schema_failure_test

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"
import sc "godot:replay/schema"

Mode :: enum u8 {None=0, Wide=7}
Small :: struct {flag:bool,number:u32}
Array :: struct {values:[20]Small}
Enum :: struct {mode:Mode,mask:bit_set[Mode;u8]}
Choice :: union {Small,Array,Enum}
Validated :: struct {rows:[40]struct {flag:bool,value:f32,mode:Mode}}

Failing :: struct {source:mem.Allocator,after,requests,denied:int}
fail_proc :: proc(data:rawptr,mode:runtime.Allocator_Mode,size,alignment:int,old:rawptr,old_size:int,loc:runtime.Source_Code_Location)->([]u8,runtime.Allocator_Error){
 f:=cast(^Failing)data
 if (mode==.Alloc || mode==.Alloc_Non_Zeroed || mode==.Resize || mode==.Resize_Non_Zeroed) && size>0 {
  f.requests+=1
  if f.after>=0 && f.requests>f.after{f.denied+=1;return nil,.Out_Of_Memory}
 }
 return f.source.procedure(f.source.data,mode,size,alignment,old,old_size,loc)
}

@(test)
nil_allocator_never_publishes_ready_schema :: proc(t:^testing.T){
 schema:sc.Schema
 report:=sc.init(&schema,Small,allocator=mem.nil_allocator())
 testing.expect_value(t,report.error,sc.Error.Allocation_Failed)
 testing.expect_value(t,report.path,"")
 testing.expect(t,!schema.ready)
 testing.expect_value(t,schema.fingerprint,u64(0))
 testing.expect_value(t,schema.shuffle_fingerprint,u64(0))
 sc.destroy(&schema);sc.destroy(&schema)
}

sweep :: proc(t:^testing.T,$T:typeid){
 baseline:sc.Schema
 testing.expect_value(t,sc.init(&baseline,T).error,sc.Error.None)
 defer sc.destroy(&baseline)
 tracker:mem.Tracking_Allocator
 mem.tracking_allocator_init(&tracker,context.allocator);defer mem.tracking_allocator_destroy(&tracker)
 counted:=Failing{source=mem.tracking_allocator(&tracker),after=-1}
 full:sc.Schema
 testing.expect_value(t,sc.init(&full,T,allocator={data=&counted,procedure=fail_proc}).error,sc.Error.None)
 requests:=counted.requests
 testing.expect_value(t,string(full.canonical[:]),string(baseline.canonical[:]))
 testing.expect_value(t,full.fingerprint,baseline.fingerprint)
 sc.destroy(&full)
 for limit in 0..<requests {
  failing:=Failing{source=mem.tracking_allocator(&tracker),after=limit}
  schema:sc.Schema
  report:=sc.init(&schema,T,allocator={data=&failing,procedure=fail_proc})
  testing.expect(t,failing.denied>0)
  testing.expect(t,report.error==.Allocation_Failed,fmt.tprintf("%v fail after %d",typeid_of(T),limit))
  testing.expect_value(t,report.path,"")
  testing.expect(t,!schema.ready)
  testing.expect_value(t,schema.fingerprint,u64(0))
  testing.expect_value(t,schema.shuffle_fingerprint,u64(0))
  sc.destroy(&schema);sc.destroy(&schema)
  testing.expect_value(t,len(tracker.allocation_map),0)
  if report.error==.None{return}
 }
 fmt.printf("SCHEMA_FAILURE_SWEEP type=%v allocation_sites=%d\n",typeid_of(T),requests)
}

@(test) simple_allocation_sweep :: proc(t:^testing.T){sweep(t,Small)}
@(test) array_allocation_sweep :: proc(t:^testing.T){sweep(t,Array)}
@(test) enum_allocation_sweep :: proc(t:^testing.T){sweep(t,Enum)}
@(test) union_allocation_sweep :: proc(t:^testing.T){sweep(t,Choice)}
@(test) compiled_validation_allocation_sweep :: proc(t:^testing.T){sweep(t,Validated)}

@(test)
semantic_diagnostic_path_allocation_can_fail_without_allocating_an_error :: proc(t:^testing.T){
 Invalid :: struct {reference:^u32}
 tracker:mem.Tracking_Allocator;mem.tracking_allocator_init(&tracker,context.allocator);defer mem.tracking_allocator_destroy(&tracker)
 counted:=Failing{source=mem.tracking_allocator(&tracker),after=-1}
 schema:sc.Schema
 testing.expect_value(t,sc.init(&schema,Invalid,allocator={data=&counted,procedure=fail_proc}).error,sc.Error.Unsupported_Type)
 sc.destroy(&schema)
 counted.after=counted.requests-1;counted.requests=0
 report:=sc.init(&schema,Invalid,allocator={data=&counted,procedure=fail_proc})
 testing.expect_value(t,report.error,sc.Error.Allocation_Failed)
 testing.expect_value(t,report.path,"")
 testing.expect(t,!schema.ready)
 sc.destroy(&schema);sc.destroy(&schema)
 testing.expect_value(t,len(tracker.allocation_map),0)
}
