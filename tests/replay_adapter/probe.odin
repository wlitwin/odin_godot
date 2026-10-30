package replay_scrapyard
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import d "godot:replay/definitions"
import v "godot:replay/view"
import game "../shared/game"
import content "../shared/content"
import display "../shared/presentation"
import views "views"
import scenegd "godot:replay/godot/scene"

Adapter_Capture :: struct {script:^views.ScrapEnemyView,handle:r.Handle(game.Mob),count:int}
adapter_capture :: proc(c:^Adapter_Capture,h:r.Handle(game.Mob),script:^views.ScrapEnemyView) {c.script=script;c.handle=h;c.count+=1}
@(gd_method)
replay_scrapyard_adapter_check :: proc(self:^ReplayScrapyard)->bool {
    descriptor:=views.scrap_enemy_view_replay_binding()
    if descriptor.view.present!=views.enemy_view_present || descriptor.view.validate!=views.enemy_view_validate ||
       descriptor.view.retired!=views.enemy_view_retire || descriptor.configure!=views.enemy_view_configure {return false}
    assets:scenegd.Archetype_Assets(content.Mob);defer scenegd.archetype_assets_destroy(&assets)
    if !enemy_archetypes_load(&assets) {return false}
    style:=assets.registry.entries[6].value.local.appearance
    before:=gd.ref_counted_get_reference_count(style)
    owner:scenegd.Script_Archetypes(game.Mob,display.Mob_View,views.ScrapEnemyView,views.ScrapEnemyStyle);defer scenegd.script_archetypes_destroy(&owner)
    select:=proc(value:display.Mob_View)->u32{return u32(value.kind)}
    if scenegd.script_archetypes_init(&owner,&assets,self.world_node,2,select,descriptor).error!=.None {return false}
    if gd.ref_counted_get_reference_count(style)!=before+1 {return false}
    scenegd.archetype_assets_destroy(&assets)
    if gd.ref_counted_get_reference_count(style)!=before {return false}
    items:=[2]v.View_Item(game.Mob,display.Mob_View){0={handle={0,1},source=.Observed,view={scale={1,1},color={1,1,1,1},value={kind=6,hp=12,scale=1.3,tint={1,1,1,1}}}}}
    report:=scenegd.script_archetypes_present(&owner,{1,1},items[:1]);if report.error!=.None {content_report(&report);return false}
    capture:Adapter_Capture;scenegd.script_archetypes_visit(&owner,&capture,adapter_capture)
    if capture.count!=1 || capture.script==nil || capture.handle!=(r.Handle(game.Mob){0,1}) {return false}
    first:=capture.script
    if scenegd.script_archetypes_present(&owner,{1,1},items[:1]).error!=.None || scenegd.script_archetypes_stats(&owner).skipped_paints!=1 {return false}
    if scenegd.script_archetypes_present(&owner,{2,1},items[:1]).error!=.None || !first.retired {return false}
    capture={};scenegd.script_archetypes_visit(&owner,&capture,adapter_capture)
    if capture.script==first || capture.count!=1 || scenegd.script_archetypes_stats(&owner).created!=2 {return false}
    items[1]=items[0]
    report=scenegd.script_archetypes_present(&owner,{2,1},items[:]);if report.error==.None || !strings.contains(d.report_message(&report),"duplicate") || scenegd.script_archetypes_stats(&owner).count!=1 {return false}
    items[0].view.value.kind=7
    report=scenegd.script_archetypes_present(&owner,{2,1},items[:1]);if report.error==.None || !strings.contains(d.report_path(&report),"archetype=7") {return false}
    scenegd.script_archetypes_destroy(&owner)
    if gd.ref_counted_get_reference_count(style)!=before-1 {return false}

    // A checked but deliberately rejected appearance exercises diagnostics and
    // partially attached cleanup without relying on engine error logging.
    if !enemy_archetypes_load(&assets) {return false}
    descriptor.configure=proc(_: ^views.ScrapEnemyView,_:^views.ScrapEnemyStyle)->d.Report {return d.problem(.Invalid,"Charge","deliberate component rejection")}
    if scenegd.script_archetypes_init(&owner,&assets,self.world_node,2,select,descriptor).error!=.None {return false}
    items[0].view.value.kind=6
    report=scenegd.script_archetypes_present(&owner,{3,1},items[:1]);text:=d.report_path(&report)
    if report.error==.None || !strings.contains(text,"archetype=6") || !strings.contains(text,"res://entities/mob.tscn") || !strings.contains(text,"entity=4294967297") || !strings.contains(text,"Charge") {content_report(&report);return false}
    if scenegd.script_archetypes_stats(&owner).count!=0 {return false}
    gd.print_str(fmt.tprintf("REPLAY_ADAPTER_DIAGNOSTIC %s: %s",text,d.report_message(&report)))

    node:=scenegd.scene_instance(self.world_node,"res://entities/runner.tscn");if node==nil {return false};defer gdext.object_destroy(node)
    fixed:scenegd.Script_Binding(display.Runner_View,views.ScrapRunnerView);defer scenegd.script_release(&fixed)
    config:=views.scrap_runner_view_replay_binding()
    if config.present!=views.runner_view_present || config.validate!=views.runner_view_validate {return false}
    if scenegd.script_bind(&fixed,cast(gd.Node2d)node,config).error!=.None {return false}
    identity:=fixed.script
    value:=display.Runner_View{visible=true,alive=true,epoch=1,generation=1,tint={1,1,1,1}}
    if !scenegd.script_present(&fixed,value) {return false}
    value.epoch,value.generation,value.warp=2,2,3
    if !scenegd.script_present(&fixed,value) || fixed.script!=identity || fixed.script.value.generation!=2 {return false}
    batch:scenegd.Resource_Batch;defer scenegd.resource_batch_destroy(&batch)
    if scenegd.resource_batch_load(&batch,"res://archetypes/enemies",8).error!=.None || batch.count!=7 {return false}
    count:=batch.count
    if scenegd.resource_batch_load(&batch,"res://absent",8).error==.None || batch.count!=count {return false}
    gd.print_str("REPLAY_ADAPTER_BINDINGS_OK generated=true retained=true scope=true duplicate=true iteration=true fixed_runner=true batch=true")
    return true
}
