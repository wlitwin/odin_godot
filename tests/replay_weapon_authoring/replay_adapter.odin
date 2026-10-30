package replay_scrapyard
import gd "godot:godot"
import rgd "godot:replay/godot"
import c "../shared/content"

@(gd_method)
replay_scrapyard_weapon_probe :: proc(self:^ReplayScrapyard,key:string,seat:gd.Int)->gd.Int {
 if key=="seat" {return gd.Int(rgd.session_seat(self.session))}
 frame,ok:=rgd.session_authority_state(self.session)
 if key=="ready" {return gd.Int(ok && frame.state.stage!=.Staging)}
 if !ok {return -1}
 if key=="catalog" {return gd.Int(frame.state.catalog.gun_count)}
 if key=="stage" {return gd.Int(frame.state.stage)}
 if key=="players" {n:=0;for p in frame.state.players {if p.connected {n+=1}};return gd.Int(n)}
 if key=="enemy_hp" || key=="living" {n:=0;for alive,i in frame.state.mobs.alive {if alive {m:=frame.state.mobs.values[i];n+=key=="enemy_hp" ? int(m.hp) : int(m.hp>0)}};return gd.Int(n)}
 if key=="damage_total" {return gd.Int(frame.state.players[0].damage+frame.state.players[1].damage)}
 if key=="kills_total" {return gd.Int(frame.state.players[0].kills+frame.state.players[1].kills)}
 g:=frame.state.catalog.guns[7]
 switch key {case "damage":return gd.Int(g.damage);case "cooldown":return gd.Int(g.cooldown);case "mag":return gd.Int(g.mechanism.mag);case "reload":return gd.Int(g.mechanism.reload_ticks);case "jam":return gd.Int(g.mechanism.jam_per_mille);case "speed":return gd.Int(g.speed);case "ttl":return gd.Int(g.ttl)}
 if seat<1 || seat>2 {return -1}
 player:=frame.state.players[seat-1]
 if key=="declared" {return gd.Int(player.meta_claimed && player.profile.look==0 && player.profile.iron==0)}
 if key=="local_spent" || key=="local_mode" {
  predicted,present:=rgd.session_state(self.session);if !present {return -1}
  gun:=predicted.state.players[seat-1].gun;return key=="local_spent" ? gd.Int(gun.spent) : gd.Int(gun.mode)
 }
 switch key {case "iron":return gd.Int(player.gun_id);case "hp":return gd.Int(player.hp);case "spent":return gd.Int(player.gun.spent);case "ammo":return gd.Int(player.gun.ammo);case "mode":return gd.Int(player.gun.mode);case "marked_ready":return gd.Int(player.profile.ready)}
 if self.rigs[seat-1].gun!=nil {rect:=gd.sprite2d_get_region_rect(self.rigs[seat-1].gun);switch key {case "region_x":return gd.Int(rect.position.x);case "region_y":return gd.Int(rect.position.y);case "region_w":return gd.Int(rect.size.x);case "region_h":return gd.Int(rect.size.y)}}
 return -1
}
@(gd_method)
replay_scrapyard_weapon_name :: proc(self:^ReplayScrapyard)->gd.String {
 frame,ok:=rgd.session_authority_state(self.session);if !ok {return gd.new_string_odin("")};return gd.new_string_odin(c.name_string(&frame.state.catalog.guns[7].name))
}
@(gd_method)
replay_scrapyard_weapon_label :: proc(self:^ReplayScrapyard)->gd.String {return gd.label_get_text(cast(gd.Label)gd.get_node(self.owner,"UI/CombatHUD/Ammo/Gun"))}
@(gd_method)
replay_scrapyard_weapon_swap :: proc(self:^ReplayScrapyard)->bool {return replay_scrapyard_dev_buy(self,5,false)}
@(gd_method)
replay_scrapyard_weapon_fire :: proc(self:^ReplayScrapyard,held:bool) {replay_scrapyard_dev_aim(self,1,0,held)}
@(gd_method)
replay_scrapyard_weapon_target :: proc(self:^ReplayScrapyard) {replay_scrapyard_dev_spawn(self,1,2,120,0)}
