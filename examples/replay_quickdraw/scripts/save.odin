package replay_quickdraw

import "core:fmt"
import "core:reflect"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/duel"
import storagegd "godot:replay/godot/storage"

save_path :: proc(self:^ReplayQuickdraw)->string {
 value:=gd.line_edit_get_text(self.ui[0].save_path);defer gd.free_string(value)
 return strings.clone(strings.trim_space(gd.gd_string_to_odin(value)),context.temp_allocator)
}
@(gd_method)
replay_quickdraw_on_save :: proc(self:^ReplayQuickdraw)->bool {
 if !self.ready || !self.session.ready || !self.session.authority || self.session.fenced {return false}
 if self.room.ready {return self.online.enabled && rgd.room_save(&self.room)==.None}
 when gd.IS_WEB {return browser_save_submit(self)}
 result:=rgd.session_save(self.session,save_path(self))
 if result.error!=.None {gd.set_string(self.ui[0].save_notice,"text","Could not save. Check the file path and write access.");return false}
 frame,_:=rgd.session_authority_state(self.session)
 self.saved_tick=frame.tick;self.saved_hash=u64(replay_quickdraw_probe_hash(self,gd.Int(frame.tick)))
 gd.set_string(self.ui[0].save_notice,"text",fmt.ctprintf("Saved duel at tick %d",frame.tick))
 gd.print_str(fmt.tprintf("RQ_SAVED tick=%d hash=%d",self.saved_tick,self.saved_hash));return true
}
@(gd_method)
replay_quickdraw_on_resume_solo :: proc(self:^ReplayQuickdraw) {connect_duel(self,"solo",false,true)}
@(gd_method)
replay_quickdraw_on_resume_host :: proc(self:^ReplayQuickdraw) {connect_duel(self,"host",false,true)}

resume_duel :: proc(self:^ReplayQuickdraw,opts:rgd.Session_Options)->net.Error {
 if self.room.ready || quickdraw_int("RQ_COORD_PORT",0)!=0 {ui_notice(self,"File resume is available for direct sessions.");return .Wrong_Phase}
 if opts.role!=.Solo && opts.role!=.Host && opts.role!=.Server {ui_notice(self,"Choose Resume solo or Resume host.");return .Wrong_Phase}
 when gd.IS_WEB {
  slot:=&self.browser_save[0].slot;key,valid:=browser_save_key(self)
  if !valid || key!=slot.key || opts.role!=.Solo || slot.phase!=.Ready || !slot.has_checkpoint {ui_notice(self,"No readable saved duel is available in this slot.");return .Invalid_Checkpoint}
  return restore_duel(self,&slot.checkpoint,opts)
 } else {
 cp:net.Checkpoint(game.World,game.Controls,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 result:=storagegd.checkpoint_read(&cp,game.model(),save_path(self),game.CONTENT)
 if result.error!=.None {
  ui_notice(self,result.error==.Open ? "Could not open the saved duel. Check the file path." : "The saved duel is damaged or from a different version.")
  return result.network!=.None ? result.network : net.Error.Invalid_Checkpoint
 }
 return restore_duel(self,&cp,opts)
 }
}
restore_duel :: proc(self:^ReplayQuickdraw,cp:^net.Checkpoint(game.World,game.Controls,game.Action,game.SEATS),opts:rgd.Session_Options)->net.Error {
 if cp.settings.require_permit || cp.header.policy_id!=0 {ui_notice(self,"This duel requires its room recovery service.");return .Checkpoint_Policy}
 if cp.header.epoch==max(u64) {ui_notice(self,"The saved duel cannot begin another session.");return .Invalid_Checkpoint}
 seat,found:=net.checkpoint_seat(cp,opts.token)
 if opts.role==.Server {
  if cp.header.local_seat!=0 {ui_notice(self,"This duel was saved by a player host.");return .Invalid_Input};seat=0
 } else if !found || seat!=cp.header.local_seat {ui_notice(self,"Use the host profile that saved this duel.");return .Invalid_Input}
 self.session=&self.standalone
 // Direct file resume retires pending commands and schedules departed peers.
 // Coordinated migration retains its independent authorization/pending policy.
 err:=rgd.session_resume(self.session,cp,game.model(),opts,{epoch=cp.header.epoch+1,local_seat=seat})
 if err!=.None {ui_notice(self,"Could not start the saved duel. Check the host port.");return err}
 frame,ok:=r.current(&self.session.server.timeline)
 self.restored_exact=ok && reflect.equal(frame,cp.frame)
 self.restored_tick=cp.frame.tick;self.restored_hash=u64(replay_quickdraw_probe_hash(self,gd.Int(cp.frame.tick)))
 self.ui[0].was_playing=cp.frame.state.started
 gd.set_string(self.ui[0].save_notice,"text",opts.role==.Solo ? "Saved duel restored for solo play." : "Saved duel restored — players can rejoin.")
 gd.print_str(fmt.tprintf("RQ_RESTORED tick=%d hash=%d exact=%v epoch=%d",self.restored_tick,self.restored_hash,self.restored_exact,self.session.server.cfg.epoch))
 return .None
}
@(gd_method)
replay_quickdraw_save_probe :: proc(self:^ReplayQuickdraw,key:string)->gd.Int {
 switch key {case "saved_tick":return gd.Int(self.saved_tick);case "saved_hash":return gd.Int(self.saved_hash);case "restored_tick":return gd.Int(self.restored_tick);case "restored_hash":return gd.Int(self.restored_hash);case "exact":return gd.Int(self.restored_exact)}
 frame,ok:=rgd.session_authority_state(self.session);if !ok {return -1};w:=frame.state
 switch key {
 case "combat":return gd.Int(w.players[0].boots && w.players[0].fire_cd>0 && w.players[1].hp==0 && w.players[1].respawn_at>w.clock && w.bullets.count>0 && w.history.entries[w.clock%32].valid)
 case "fire_cd":return gd.Int(w.players[0].fire_cd)
 case "respawn":return gd.Int(w.players[1].respawn_at)
 }
 return -1
}
