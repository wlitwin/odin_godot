package hello_game

import r "godot:replay"
import v "godot:replay/view"

// Detached presentation output. This tiny World is smaller than this full view batch. No scene nodes, resources or history pointers escape.
Actor_Views :: struct {items:[CAPACITY]v.View_Item(Actor,u8),count:int,shots:u32}
project_actor_views :: proc(world:World)->Actor_Views {
    result:=Actor_Views{shots=world.shots}
    for actor,i in world.actors.values {
        if !world.actors.alive[i] {continue}
        color:=actor.owner==0 ? [4]f32{0.35,0.85,1,1} : [4]f32{1,0.62,0.3,1}
        result.items[result.count]={
            handle=r.Handle(Actor){u32(i),world.actors.generations[i]},
            view={pose={position=actor.body.position},scale=actor.body.half_size/8,color=color,value=actor.owner},
            source=.Predicted,
        }
        result.count+=1
    }
    return result
}
