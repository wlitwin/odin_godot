package replay_cavecrawl

import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import d "godot:replay/definitions"
import defs "defs"
import game "../shared/cave"
import scenegd "godot:replay/godot/scene"

// Bake the complete set before replacing any live definition or scene reference.
// This game embeds values in World/checkpoints, so no external definition lookup
// or retained store is needed during replay. Presentation scenes stay owned here.
definitions_load :: proc(self:^ReplayCave)->bool {
    store:d.Store([2]game.Floor)
    report:=d.init(&store,1);defer d.destroy(&store)
    if report.error!=.None {return definitions_error(&report)}
    resources:=[2]^gd.Resource{self.floor1_def,self.floor2_def}
    ref:d.Ref
    ref,report=scenegd.bake(&store,resources,game.CONTENT,definitions_extract)
    if report.error!=.None {return definitions_error(&report)}
    values,found:=d.get(&store,ref);if !found {return false}
    scenes:[2]gd.Packed_Scene
    for resource,i in resources {
        definition:=rt.script_of(cast(gd.Object)resource,defs.ReplayCaveLevelDef)
        scenes[i]=cast(gd.Packed_Scene)definition.scene;gd.ref_counted_reference(scenes[i])
    }
    definitions_close(self)
    self.definitions,self.floor_scenes=values,scenes
    gd.print_str(fmt.tprintf("REPLAY_CAVE_DEFINITIONS floors=2 waves=%d/%d gems=%d/%d content=%d",values[0].wave_count,values[1].wave_count,values[0].gems,values[1].gems,ref.content))
    return true
}
definitions_extract :: proc(resources:[2]^gd.Resource,ctx:^scenegd.Bake_Context)->[2]game.Floor {
    values:[2]game.Floor
    for resource,i in resources {
        values[i]=definition_extract(resource,ctx)
        if ctx.report.error!=.None {
            // Copy the full indexed path before replacing the bounded report.
            report:=ctx.report
            path:=d.report_path(&report)
            separator:=len(path)>0 && path[0]!='.' ? ".scene/" : ""
            ctx.report=d.problem(report.error,fmt.tprintf("$.floors[%d]%s%s",i,separator,path),d.report_message(&report))
            return {}
        }
    }
    return values
}
definition_extract :: proc(resource:^gd.Resource,ctx:^scenegd.Bake_Context)->game.Floor {
    if resource==nil {scenegd.bake_fail(ctx,"","missing resource");return {}}
    definition:=rt.script_of(cast(gd.Object)resource,defs.ReplayCaveLevelDef)
    if definition==nil {scenegd.bake_fail(ctx,"","expected ReplayCaveLevelDef");return {}}
    value:=game.Floor{
        gems=u16(scenegd.bake_int(ctx,definition.gems,0,99,".gems")),
        torches=u16(scenegd.bake_int(ctx,definition.torches,0,99,".torches")),
        rift={min=definition.rift_min,max=definition.rift_max},
    }
    if ctx.report.error!=.None {return {}}
    counts,rests:=definition.wave_counts,definition.wave_rests
    count:=gd.packed_int32_array_size(&counts)
    if count<1 || count>game.MAX_WAVES || gd.packed_int32_array_size(&rests)!=count {
        scenegd.bake_fail(ctx,".wave_counts","wave counts and rests must have equal lengths 1..8");return {}
    }
    value.wave_count=u8(count)
    for j in 0..<count {
        value.waves[j]=u16(scenegd.bake_int(ctx,gd.packed_int32_array_get(&counts,j),0,255,fmt.tprintf(".wave_counts[%d]",j)))
        value.rests[j]=u16(scenegd.bake_int(ctx,gd.packed_int32_array_get(&rests,j),0,65535,fmt.tprintf(".wave_rests[%d]",j)))
    }
    root:=scenegd.bake_scene2(ctx,cast(gd.Packed_Scene)definition.scene,".scene")
    if root==nil {return {}}
    paths:=[4]string{"ChestSpawn","DoorSpawn","Den1","Den2"};points:[4]gd.Vector2
    for path,j in paths {
        point,ok:=scenegd.bake_marker2(ctx,root,path)
        if !ok {return {}};points[j]=point
    }
    value.chest,value.door,value.dens=points[0],points[1],{points[2],points[3]}
    if !game.floor_valid(value) {scenegd.bake_fail(ctx,".geometry","invalid floor geometry or wave plan");return {}}
    return value
}
definitions_error :: proc(report:^d.Report)->bool {
    gd.print_str(fmt.tprintf("REPLAY_CAVE_DEFINITION_FAIL %s: %s",d.report_path(report),d.report_message(report)));return false
}
definitions_close :: proc(self:^ReplayCave) {for scene in self.floor_scenes {gd.release_ref(scene)};self.floor_scenes={}}
