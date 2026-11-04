// Test fixture only. Does not implement or simulate SDK generation/domain guards.
// A real host owner must retain Context independently of Source_Instance and
// guard every allocator callback through complete cleanup and producer return.
package replay_module_fixture

import "core:mem"

Log :: struct {
 instances_created,instances_freed,contexts_created,contexts_freed:u64,
 context_retains,context_releases:u64,
}
Context :: struct {
 log:^Log,
 references:u32,
 backing:mem.Allocator,
 tracker:mem.Tracking_Allocator,
 immutable_parameter:u64,
}
Source_Instance :: struct {ctx:^Context,backing:mem.Allocator}

source_create :: proc(log:^Log,parameter:u64,allocator:=context.allocator)->^Source_Instance {
 ctx:=new(Context,allocator);ctx.log=log;ctx.references=1;ctx.backing=allocator;ctx.immutable_parameter=parameter
 mem.tracking_allocator_init(&ctx.tracker,allocator,allocator)
 instance:=new(Source_Instance,allocator);instance.ctx=ctx;instance.backing=allocator
 log.instances_created+=1;log.contexts_created+=1;return instance
}
context_retain :: proc(ctx:^Context) {
 assert(ctx!=nil && ctx.references>0 && ctx.references<max(u32));ctx.references+=1;ctx.log.context_retains+=1
}
context_release :: proc(owner:^^Context) {
 if owner==nil || owner^==nil{return}
 ctx:=owner^;owner^=nil;assert(ctx.references>0);ctx.references-=1;ctx.log.context_releases+=1
 if ctx.references!=0{return}
 assert(ctx.tracker.current_memory_allocated==0,"whole event/allocator cleanup must precede final context release")
 mem.tracking_allocator_destroy(&ctx.tracker);ctx.log.contexts_freed+=1;mem.free(ctx,ctx.backing)
}
source_destroy :: proc(owner:^^Source_Instance) {
 if owner==nil || owner^==nil{return}
 instance:=owner^;owner^=nil
 log:=instance.ctx.log;context_release(&instance.ctx)
 log.instances_freed+=1;mem.free(instance,instance.backing)
}
// Borrowed allocator: its data points inside Context. Code residency alone cannot
// keep that data valid. An owning complete checkpoint must retain Context first.
context_allocator :: proc(ctx:^Context)->mem.Allocator {
 assert(ctx!=nil && ctx.references>0);return mem.tracking_allocator(&ctx.tracker)
}
