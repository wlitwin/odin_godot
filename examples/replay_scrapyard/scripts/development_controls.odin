package replay_scrapyard

import gd "godot:godot"
import game "../shared/game"
import content "../shared/content"

@(gd_method)
replay_scrapyard_dev_loadout :: proc(self: ^ReplayScrapyard, look, iron: gd.Int) {
	self.local_profile[0].automatic &~= u8(3)
	self.choices[0].look, self.choices[0].iron = u8(clamp(look, 0, 2)), u8(clamp(iron, 0, content.MAX_GUNS - 1))
	self.selected = true
	declare(self)
}

@(gd_method)
replay_scrapyard_dev_drive :: proc(self: ^ReplayScrapyard, x, y: gd.Int, dash: bool) {
	self.manual, self.manual_move = true, {f32(clamp(x, -1, 1)), f32(clamp(y, -1, 1))}
	self.manual_aim = self.manual_move
	self.dash_next = self.dash_next || dash
}

@(gd_method)
replay_scrapyard_dev_abilities :: proc(self: ^ReplayScrapyard, first, second: gd.Int) {
	self.local_profile[0].automatic &~= u8(12)
	self.choices[0].abilities = {
		u8(clamp(first, 1, content.MAX_ABILITIES - 1)),
		u8(clamp(second, 1, content.MAX_ABILITIES - 1)),
	}
	self.selected = true
	declare(self)
}

@(gd_method)
replay_scrapyard_dev_cast :: proc(self: ^ReplayScrapyard, slot: gd.Int, x, y: gd.Float, point: bool) -> bool {
	if slot < 0 || slot > 1 {
		return false
	}
	return issue(self, game.Action{kind = .Cast, slot = u8(slot), aim = {f32(x), f32(y)}, aim_is_point = point})
}

@(gd_method)
replay_scrapyard_dev_aim :: proc(self: ^ReplayScrapyard, x, y: gd.Float, firing: bool) {
	self.manual, self.auto_combat, self.manual_move = true, false, {}
	self.manual_aim = unit({f32(x), f32(y)})
	self.manual_fire = firing
}

@(gd_method)
replay_scrapyard_dev_combat :: proc(self: ^ReplayScrapyard, enabled: bool) {
	self.auto_combat = enabled
	self.auto_gate = false
	self.manual = true
	self.manual_move = {}
	self.manual_fire = false
}

@(gd_method)
replay_scrapyard_dev_gate :: proc(self: ^ReplayScrapyard, enabled: bool) {
	self.auto_gate = enabled
	self.auto_combat = false
	self.manual = true
	self.manual_move = {}
	self.manual_fire = false
}

@(gd_method)
replay_scrapyard_dev_buy :: proc(self: ^ReplayScrapyard, item: gd.Int, part: bool) -> bool {
	return issue(self, game.Action{kind = part ? .Workshop : .Buy, item = u8(clamp(item, 0, 255))})
}

@(gd_method)
replay_scrapyard_dev_revive :: proc(self: ^ReplayScrapyard, held: bool) {
	self.manual = true
	self.manual_revive = held
}
