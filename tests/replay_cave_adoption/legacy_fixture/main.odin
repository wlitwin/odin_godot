package main
import "core:fmt"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import storagegd "godot:replay/godot/storage"
main :: proc() {
 assert(len(os.args)==2 && cave.CONTENT==0x4341564552504c37)
 names:=[1]string{"old-host-carrier"}
 for name in names {
  w:=cave.initial();w.clock=100;w.lobby.present,w.lobby.ready=1,1
  w.players[0]={initialized=true,connected=true,position=cave.floor(1).door,hp=65,stamina=3}
  w.director={wave=2,done=true};w.door_open=true
  w.relic={position={570,168},carrier=1,version=7}
  
  server:net.Server(cave.World,cave.Control,cave.Action,cave.Event,cave.SEATS);cfg:=net.DEFAULT_CONFIG;cfg.content=cave.CONTENT;cfg.hz=cave.HZ
  assert(net.server_init(&server,r.Frame(cave.World){state=cave.initial()},cave.model(),{},cfg,local_seat=1)==.None)
  assert(net.server_set_local_token(&server,storagegd.session_token("cave-adoption-legacy"))==.None);assert(net.server_step(&server)==.None)
  assert(r.reset_checkpoint(&server.timeline,r.Frame(cave.World){tick=100,state=w},1)==.None)
  cp:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);assert(net.checkpoint_capture(&server,&cp)==.None)
  bytes,error:=net.checkpoint_encode(&cp,cave.model());assert(error==.None)
  assert(os.write_entire_file(fmt.tprintf("%s/%s.replay",os.args[1],name),bytes)==nil)
  fmt.printf("CAVE_C7_ADOPTION name=%s tick=%d relic=%v\n",name,cp.frame.tick,w.relic)
  delete(bytes);net.checkpoint_destroy(&cp);net.server_destroy(&server)
 }
}
