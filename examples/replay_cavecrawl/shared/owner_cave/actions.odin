package owner_cave

import "core:math"
import "core:reflect"
import o "godot:replay/owned"
import lb "godot:replay/lobby"
import base "../cave"

Origin_Kind :: enum u8 {Accepted_Pose, Owner_Pose}
Action :: struct {
 verb:base.Verb,
 index:u16,
 generation:u32,
 aim:[2]f32,
 lobby:lb.Command,
 origin_kind:Origin_Kind,
 origin:o.Action_Context(o.Pose2),
}
command :: proc(a:Action)->base.Action {return {a.verb,a.index,a.generation,a.aim,a.lobby}}
needs_origin :: proc(verb:base.Verb)->bool {
 return verb==.Take || verb==.Door || verb==.Grab || verb==.Throw || verb==.Revive || verb==.Carry
}
action_valid :: proc(a:Action)->bool {
 if !base.action_valid(command(a)) || a.origin_kind>.Owner_Pose {return false}
 if a.origin_kind==.Accepted_Pose {return reflect.equal(a.origin,o.Action_Context(o.Pose2){})}
 return needs_origin(a.verb) && o.context_valid(a.origin,rules())
}
CAST_LEASH :: f32(64)
cast_origin :: proc(claimed,anchor:[2]f32)->[2]f32 {
 delta:=claimed-anchor;distance:=math.sqrt(delta[0]*delta[0]+delta[1]*delta[1])
 if distance<=CAST_LEASH {return claimed}
 return anchor+delta*(CAST_LEASH/distance)
}
