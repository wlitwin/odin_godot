package storm_corpus
import scenario "godot:replay/testing"
import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_scrapyard/shared/game"
verify :: proc()->(u64,bool) {
 w:=game.initial(encounter_count=0);w.stage=.Yard;w.players[0].connected,w.players[0].in_yard=true,true;w.players[0].position={500,1040}
 w.catalog.mobs[game.STORMCALLER].speed=0
 if !game.spawn_mob(&w,game.STORMCALLER,{600,1040}) {return 0,false};w.mobs.values[0].next_act=0
 cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT;model:=game.model();model.reset_player=nil
 drive:proc(^net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS),u64)->net.Error
 result:=scenario.takeover(r.Frame(game.World){state=w},model,cfg,20,70,drive)
 return result.report.hash,result.report.phase==.Complete && result.before.state.mobs.values[0].tele.left==26 &&
     result.after.state.players[0].hp==8 && result.after.state.mobs.values[0].tele.left==0
}
