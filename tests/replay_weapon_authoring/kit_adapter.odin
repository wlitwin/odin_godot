package scrapyard_scripts
import gd "godot:godot"
import ks "godot:kit/session"
import kn "godot:kit/net"

@(gd_method)
scrapyard_weapon_probe :: proc(self:^Scrapyard,key:string,seat:gd.Int)->gd.Int {
 if key=="seat" {return gd.Int(self.ses.me)}
 if key=="ready" {return gd.Int(self.started)}
 if key=="catalog" {return gd.Int(gun_count())}
 if key=="players" {return gd.Int(ks.session_count(&self.ses,connected_only=true))}
 if key=="stage" {return self.world!=nil ? gd.Int(self.world.stage)+1 : -1}
 if key=="enemy_hp" {hp:=0;for _,m in self.mobs {hp+=int(m.health.hp)};return gd.Int(hp)}
 if key=="living" {n:=0;for _,m in self.mobs {if m.health.hp>0 {n+=1}};return gd.Int(n)}
 if key=="damage_total" || key=="kills_total" {
  col,ok:=ks.session_stat_find(&self.ses,key=="damage_total" ? "damage" : "kills");if !ok {return -1}
  return gd.Int(ks.session_stat(&self.ses,1,col)+ks.session_stat(&self.ses,2,col))
 }
 g:=gun_row(7)
 switch key {case "damage":return gd.Int(g.dmg);case "cooldown":return gd.Int(g.cooldown);case "mag":return gd.Int(g.knobs.mag);case "reload":return gd.Int(g.knobs.reload_ticks);case "jam":return gd.Int(g.knobs.jam_per_mille);case "speed":return gd.Int(g.speed);case "ttl":return gd.Int(g.ttl)}
 if seat<1 || seat>2 {return -1}
 if key=="declared" {claim:=seat_claim(self,kn.Player_Id(seat));return gd.Int(claim.look==0 && claim.iron==0)}
 r,ok:=runner_of(self,kn.Player_Id(seat));if !ok {return -1}
 switch key {case "iron":return gd.Int(r.gun);case "hp":return gd.Int(r.health.hp);case "spent","local_spent":return gd.Int(r.weapon.spent);case "ammo":return gd.Int(r.weapon.ammo);case "mode","local_mode":return gd.Int(r.weapon.mode)}
 if r.rig.gun!=nil {rect:=gd.sprite2d_get_region_rect(r.rig.gun);switch key {case "region_x":return gd.Int(rect.position.x);case "region_y":return gd.Int(rect.position.y);case "region_w":return gd.Int(rect.size.x);case "region_h":return gd.Int(rect.size.y)}}
 return -1
}
@(gd_method)
scrapyard_weapon_name :: proc(self:^Scrapyard)->gd.String {return gd.new_string_odin(gun_row(7).name)}
@(gd_method)
scrapyard_weapon_label :: proc(self:^Scrapyard)->gd.String {return self.hud!=nil ? gd.label_get_text(self.hud.ammo_gun) : gd.new_string_odin("")}
@(gd_method)
scrapyard_weapon_swap :: proc(self:^Scrapyard)->bool {return bool(scrapyard_dev_buy(self,5))}
@(gd_method)
scrapyard_weapon_fire :: proc(self:^Scrapyard,held:bool) {scrapyard_dev_autofire(self,held ? 60 : 0)}
@(gd_method)
scrapyard_weapon_target :: proc(self:^Scrapyard) {scrapyard_dev_spawn(self,1,2,120,0)}
