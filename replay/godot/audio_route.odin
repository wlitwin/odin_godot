package replay_godot

import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"

Audio_Route :: struct($Event:typeid) {
    pool:Audio_Pool,
    ledger:v.One_Shots,
    project:proc(rawptr,Event)->(Audio_Cue,bool),user:rawptr,
    project_change:proc(rawptr,v.Change(Event))->(Audio_Cue,bool),
    policy:v.Route_Policy,
}
audio_route_init :: proc(p:^Audio_Route($Event),parent:gd.Node,epoch:u64,project:proc(rawptr,Event)->(Audio_Cue,bool),
                         user:rawptr=nil,policy:v.Route_Policy=.Journal,world_voices:int=12,screen_voices:int=3,
                         baseline:u64=0,history:int=512,per_tick:int=40,allocator:=context.allocator)->bool {
    if project==nil || !audio_route_open(p,parent,epoch,user,policy,world_voices,screen_voices,baseline,history,per_tick,allocator) {return false}
    p.project=project;return true
}
// Contextual routes can use stamped IDs/ticks for deterministic pitch and
// historical victim placement without maintaining a side-channel current event.
audio_route_init_change :: proc(p:^Audio_Route($Event),parent:gd.Node,epoch:u64,project:proc(rawptr,v.Change(Event))->(Audio_Cue,bool),
                         user:rawptr=nil,policy:v.Route_Policy=.Journal,world_voices:int=12,screen_voices:int=3,
                         baseline:u64=0,history:int=512,per_tick:int=40,allocator:=context.allocator)->bool {
    if project==nil || !audio_route_open(p,parent,epoch,user,policy,world_voices,screen_voices,baseline,history,per_tick,allocator) {return false}
    p.project_change=project;return true
}
@(private)
audio_route_open :: proc(p:^Audio_Route($Event),parent:gd.Node,epoch:u64,user:rawptr,policy:v.Route_Policy,world_voices,screen_voices:int,
                         baseline:u64,history,per_tick:int,allocator:=context.allocator)->bool {
    if len(p.ledger.batches)!=0 || !r.value_supported(Event) || policy>.Confirmed {return false}
    if !v.one_shots_init(&p.ledger,epoch,baseline,history,per_tick,allocator) {return false}
    if !audio_pool_init(&p.pool,parent,world_voices,screen_voices,allocator) {audio_route_destroy(p);return false}
    p.user,p.policy=user,policy;return true
}
audio_route_destroy :: proc(p:^Audio_Route($Event)) {audio_pool_destroy(&p.pool);v.one_shots_destroy(&p.ledger);p^={}}
audio_route_change :: proc(p:^Audio_Route($Event),change:v.Change(Event))->bool {
    if p.project==nil && p.project_change==nil || change.occurrence.id.epoch!=p.ledger.epoch {return false}
    mapped:=change
    if mapped.kind==.Cancel {return audio_change(&p.pool,&p.ledger,mapped,{})}
    if p.policy==.Confirmed && !mapped.confirmed && mapped.kind!=.Confirm {return false}
    cue:Audio_Cue;include:bool
    if p.project_change!=nil {cue,include=p.project_change(p.user,change)} else {cue,include=p.project(p.user,mapped.occurrence.value)}
    if !include {mapped.kind=.Cancel;return audio_change(&p.pool,&p.ledger,mapped,{})}
    if p.policy==.Confirmed && mapped.kind==.Confirm {mapped.kind=.Begin}
    return audio_change(&p.pool,&p.ledger,mapped,cue)
}
audio_route_epoch :: proc(p:^Audio_Route($Event),epoch,baseline:u64)->bool {
    if !v.one_shots_reset(&p.ledger,epoch,baseline) {return false};audio_pool_clear(&p.pool);return true
}
audio_route_retire :: proc(p:^Audio_Route($Event),through:u64)->bool {return v.one_shots_retire(&p.ledger,through)}
