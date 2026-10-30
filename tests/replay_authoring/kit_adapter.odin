package scrapyard_scripts

import gd "godot:godot"
import ks "godot:kit/session"
import kn "godot:kit/net"

// Read-only observations and existing development/input drivers. No feature law.
@(gd_method)
scrapyard_authoring_probe :: proc(self:^Scrapyard,key:string,seat:gd.Int)->gd.Int {
 if key=="seat" {return gd.Int(self.ses.me)}
 if key=="players" {return gd.Int(ks.session_count(&self.ses,connected_only=true))}
 if key=="ready" {return gd.Int(self.started)}
 if key=="stage" {return self.world!=nil ? gd.Int(self.world.stage)+1 : -1}
 if seat<1 || seat>3 {return -1}
 if key=="cash" {col,ok:=ks.session_stat_find(&self.ses,"scrap");return ok ? gd.Int(ks.session_stat(&self.ses,kn.Player_Id(seat),col)) : -1}
 r,ok:=runner_of(self,kn.Player_Id(seat));if !ok {return -1}
 switch key {case "hp":return gd.Int(r.health.hp);case "x":return gd.Int(r.x);case "y":return gd.Int(r.y)}
 return -1
}
@(gd_method)
scrapyard_authoring_hold :: proc(self:^Scrapyard,held:bool) {scrapyard_dev_use(self,held ? 60 : 0)}
@(gd_method)
scrapyard_authoring_grant :: proc(self:^Scrapyard,seat,amount:gd.Int)->bool {
 if !self.ses.is_host || seat<1 || seat>3 || amount<1 {return false};scrapyard_dev_grant_scrap(self,seat,amount);return true
}
@(gd_method)
scrapyard_authoring_down :: proc(self:^Scrapyard,seat:gd.Int)->bool {
 if !self.ses.is_host || seat<1 || seat>3 {return false};scrapyard_dev_down(self,seat);return true
}
@(gd_method)
scrapyard_authoring_prompt :: proc(self:^Scrapyard)->string {
 if self.hud==nil {return ""};value:=gd.label_get_text(self.hud.prompt);defer gd.free_string(value);return gd.gd_string_to_odin(value)
}
