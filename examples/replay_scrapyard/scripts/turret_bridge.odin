package replay_scrapyard

import gd "godot:godot"
import net "godot:replay/net"
import r "godot:replay"
import rgd "godot:replay/godot"
import v "godot:replay/view"
import game "../shared/game"
import display "../shared/presentation"
import views "views"

Turret_Bridge :: struct {
	pool: rgd.View_Pool2(game.Turret, display.Turret_View, ^views.ScrapTurretView),
	binding: rgd.Script_View(display.Turret_View, views.ScrapTurretView),
	scope: v.Scope_Tracker(Combat_View_Key),
}

turret_bridge_init :: proc(self: ^ReplayScrapyard) -> bool {
	bridge := &self.turret_bridge[0]
	bridge.binding = views.scrap_turret_view_replay_binding()
	return rgd.view_pool_load(
		&bridge.pool,
		self.world_node,
		"res://entities/turret.tscn",
		game.MAX_TURRETS,
		rgd.script_view_binding(&bridge.binding),
	)
}

turret_bridge_close :: proc(self: ^ReplayScrapyard) {
	rgd.view_pool_destroy(&self.turret_bridge[0].pool)
	self.turret_bridge[0] = {}
}

turret_bridge_paint :: proc(self: ^ReplayScrapyard, world: game.World) {
	bridge := &self.turret_bridge[0]
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	reset := self.session.authority ? u64(0) : self.session.client.view_reset
	scope, error := v.scope_update(
		&bridge.scope,
		{epoch, reset, world.clock},
		Combat_View_Key{world.run, world.floor},
		true,
	)
	if error != .None {
		fail(self, "turret view scope")
		return
	}
	batch := display.turrets(world)
	if rgd.view_pool_present(&bridge.pool, scope, batch.items[:batch.count]) != .None {
		report := rgd.view_pool_problem(&bridge.pool)
		content_report(&report)
		fail(self, "turret view")
	}
}

turret_intent_capture :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16) -> bool {
	if self.turret_intent[0].captured {
		return false
	}
	handle, mounted := game.turret_for(world, seat)
	if !mounted {
		handle, mounted = game.turret_nearest(world, seat)
		if !mounted {
			return false
		}
		return net.intent_capture(&self.turret_intent[0], game.Action{kind = .Turret_Mount, turret = handle}) == .None
	}
	return net.intent_capture(&self.turret_intent[0], game.Action{kind = .Turret_Dismount, turret = handle}) == .None
}

turret_intent_submit :: proc(self: ^ReplayScrapyard) {
	if self.room.ready {
		rgd.room_intent(&self.room, &self.turret_intent[0])
	} else {
		rgd.session_intent(self.session, &self.turret_intent[0])
	}
}

@(gd_method)
replay_scrapyard_dev_turret_use :: proc(self: ^ReplayScrapyard) -> bool {
	if !self.development {
		return false
	}
	frame, ok := rgd.session_state(self.session)
	seat := rgd.session_seat(self.session)
	if !ok || seat == 0 {
		return false
	}
	return turret_intent_capture(self, &frame.state, seat)
}

@(gd_method)
replay_scrapyard_turret_probe :: proc(self: ^ReplayScrapyard, key: string, seat: gd.Int) -> gd.Int {
	frame, ok := rgd.session_authority_state(self.session)
	if !ok {
		return -1
	}
	switch key {
	case "count":
		return gd.Int(frame.state.turrets.count)
	case "views":
		return gd.Int(rgd.view_pool_stats(&self.turret_bridge[0].pool).count)
	case "pending":
		return gd.Int(self.turret_intent[0].pending_count)
	case "refused":
		return gd.Int(self.turret_intent[0].refused)
	case "mounted":
		if seat < 1 || seat > game.SEATS {
			return -1
		}
		return gd.Int(game.turret_operator(&frame.state, u16(seat)))
	}
	for alive, i in frame.state.turrets.alive {
		if alive {
			t := frame.state.turrets.values[i]
			switch key {
			case "ammo":
				return gd.Int(t.ammo)
			case "operator":
				return gd.Int(t.operator.seat)
			case "generation":
				return gd.Int(frame.state.turrets.generations[i])
			case "x":
				return gd.Int(t.position[0])
			case "y":
				return gd.Int(t.position[1])
			}
		}
	}
	return 0
}
