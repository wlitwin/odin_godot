package main

import "core:fmt"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import gd "godot:replay/godot"
import cave "godot:examples/replay_cavecrawl/shared/cave"

main :: proc() {
 assert(len(os.args)==2 && cave.CONTENT==0x4341564552504c33)
 names:=[4]string{"waiting","pending","spawning","rest"}
 for name,index in names {
  floors:=cave.FLOORS;if name=="rest" {floors[0].waves={0=0,1=1};floors[0].rests={0=40,1=5}}
  world:=cave.initial(floors=floors,staging=name=="waiting")
  server:net.Server(cave.World,cave.Control,cave.Action,cave.Event,cave.SEATS)
  cfg:=net.DEFAULT_CONFIG;cfg.content=cave.CONTENT;cfg.hz=cave.HZ
  assert(net.server_init(&server,r.Frame(cave.World){state=world},cave.model(),{},cfg,local_seat=1)==.None)
  assert(net.server_set_local_token(&server,gd.session_token("cave-director-legacy"))==.None)
  counts:=[4]int{4,5,22,10}
  for _ in 0..<counts[index] {assert(net.server_step(&server)==.None)}
  cp:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);assert(net.checkpoint_capture(&server,&cp)==.None)
  bytes,error:=net.checkpoint_encode(&cp,cave.model());assert(error==.None)
  path:=fmt.aprintf("%s/%s.replay",os.args[1],name);assert(os.write_entire_file(path,bytes)==nil)
  fmt.printf("LEGACY_DIRECTOR name=%s tick=%d director=%v live=%d\n",name,cp.frame.tick,cp.frame.state.director,cp.frame.state.dwellers.count)
  delete(path);delete(bytes);net.checkpoint_destroy(&cp);net.server_destroy(&server)
 }
}
