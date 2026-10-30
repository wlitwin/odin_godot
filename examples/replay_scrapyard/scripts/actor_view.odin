package replay_scrapyard

import v "godot:replay/view"
import net "godot:replay/net"
import game "../shared/game"
import views "views"

// Route occurrence identity; the authored runner and weapon scenes own visuals.
runner_effect :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
	if change.occurrence.value.kind != .Gameplay {
		return
	}
	event := change.occurrence.value.value
	if event.seat == 0 || event.seat > game.SEATS {
		return
	}
	if change.occurrence.id.key == game.TURRET_SHOT_KEY {
		return
	}
	if event.kind != .Shot && event.kind != .Hurt {
		return
	}
	views.runner_view_cue(
		self.rigs[event.seat - 1],
		event.kind == .Shot,
		change.kind,
		change.occurrence.id,
		event.generation,
	)
}
