//gd:extends Node
//gd:class ReplayRtcGame
package replay_rtc_probe

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import view "godot:replay/view"
import rgd "godot:replay/godot"
import game "godot:examples/replay_hello/shared/hello"

ReplayRtcGame :: struct {
 owner:gd.Node,
 session:rgd.Session(game.World,game.Controls,game.Action,game.Event,2),
 schema:sc.Schema,
 ready,failed,room_reported,issued,done:bool,
 started:u64,
}
@(gd_method="borrowed_args")
replay_rtc_game_start :: proc(self:^ReplayRtcGame,role,url,room:gd.String) {
 a,b,c:=probe_string(role),probe_string(url),probe_string(room);defer delete(a);defer delete(b);defer delete(c)
 options:=rgd.SESSION_OPTIONS
 options.role=a=="host" ? .Host : a=="observer" ? .Observer : .Client
 options.backend=.Rtc;options.rtc={url=b,room=c}
 options.token=rgd.session_token(a);options.network.content=0x5245504c41594831
 if sc.init(&self.schema,game.World).error!=.None {game_fail(self,"schema");return}
 if err:=rgd.session_open(&self.session,r.Frame(game.World){},game.network_model(),options);err!=.None {game_fail(self,fmt.tprintf("open %v",err));return}
 self.started=u64(gd.time_get_ticks_msec(gd.singleton_time()));self.ready=true
 gd.print_str("REPLAY_RTC_GAME_BOOT")
}
replay_rtc_game_process :: proc(self:^ReplayRtcGame,dt:f64) {
 if !self.ready || self.failed {return}
 s:=&self.session
 control:game.Controls
 if s.role==.Client {control.move[0]=1}
 if err:=rgd.session_frame(s,dt,control);err!=.None {game_fail(self,fmt.tprintf("frame %v",err));return}
 changes:[net.WIRE_EVENTS*8]view.Change(net.Net_Event(game.Event))
 rgd.session_changes(s,changes[:])
 if s.rtc.registered && !self.room_reported {self.room_reported=true;gd.print_str(fmt.tprintf("REPLAY_RTC_GAME_ROOM %s id=%d",s.rtc.room,s.rtc.id))}
 if s.rtc.error!=.None {game_fail(self,fmt.tprintf("adapter %v",s.rtc.error));return}
 if s.role==.Client && s.client.phase==.Running && !self.issued {
  if _,err:=rgd.session_issue(s,game.Action{fire=true});err!=.None {game_fail(self,"action");return};self.issued=true
 }
 frame,ok:=rgd.session_authority_state(s)
 if ok && !self.done && frame.state.shots==1 && frame.state.actors.count==2 {
  actor,exists:=r.pool_get(&frame.state.actors,frame.state.players[1])
  if exists && actor.body.position[0]>=291.9 {
   bytes:[16384]u8
   if sc.encode(&self.schema,frame.state,bytes[:]).error!=.None {game_fail(self,"encode");return}
   self.done=true
   gd.print_str(fmt.tprintf("REPLAY_RTC_GAME_STATE id=%d hash=%d tick=%d shots=%d x=%.2f",s.rtc.id,sc.digest(bytes[:self.schema.wire_size]),frame.tick,frame.state.shots,actor.body.position[0]))
  }
 }
 if !self.done && u64(gd.time_get_ticks_msec(gd.singleton_time()))-self.started>60000 {game_fail(self,"timeout")}
}
replay_rtc_game_exit_tree :: proc(self:^ReplayRtcGame) {rgd.session_close(&self.session);sc.destroy(&self.schema)}
game_fail :: proc(self:^ReplayRtcGame,reason:string) {self.failed=true;gd.print_str(fmt.tprintf("REPLAY_RTC_FAIL game %s",reason))}
