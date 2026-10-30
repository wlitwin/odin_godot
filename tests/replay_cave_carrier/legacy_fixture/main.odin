package main
import "core:fmt"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import gd "godot:replay/godot"
import cave "godot:examples/replay_cavecrawl/shared/cave"
main :: proc() {
 assert(len(os.args)==2 && cave.CONTENT==0x4341564552504c36)
 names:=[2]string{"dead","disconnected"}
 for name in names {
  w:=cave.initial();w.clock=100;w.lobby.present,w.lobby.ready=1,1
  w.players[0]={initialized=true,connected=true,position={220,150},hp=0,stamina=3,respawn_at=104}
  w.director={wave=2,done=true}
  w.relic={position={230,138},carrier=1,version=7}
  if name=="disconnected" {w.players[0].connected=false;w.players[0].hp=65;w.players[0].respawn_at=0;w.lobby.present,w.lobby.ready=0,0}
  server:net.Server(cave.World,cave.Control,cave.Action,cave.Event,cave.SEATS);cfg:=net.DEFAULT_CONFIG;cfg.content=cave.CONTENT;cfg.hz=cave.HZ
  assert(net.server_init(&server,r.Frame(cave.World){state=cave.initial()},cave.model(),{},cfg,local_seat=1)==.None)
  assert(net.server_set_local_token(&server,gd.session_token("cave-carrier-legacy"))==.None);assert(net.server_step(&server)==.None)
  assert(r.reset_checkpoint(&server.timeline,r.Frame(cave.World){tick=100,state=w},1)==.None)
  cp:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);assert(net.checkpoint_capture(&server,&cp)==.None)
  bytes,error:=net.checkpoint_encode(&cp,cave.model());assert(error==.None)
  assert(os.write_entire_file(fmt.tprintf("%s/%s.replay",os.args[1],name),bytes)==nil)
  fmt.printf("CAVE_C6_CARRIER name=%s tick=%d relic=%v\n",name,cp.frame.tick,w.relic)
  delete(bytes);net.checkpoint_destroy(&cp);net.server_destroy(&server)
 }
}
