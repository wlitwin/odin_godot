package replay_scrapyard_test

import "core:strings"
import "core:testing"
import co "godot:replay/comms"
import lb "godot:replay/lobby"
import game "../../examples/replay_scrapyard/shared/game"
import flow "../../examples/replay_scrapyard/shared/flow"

news_has :: proc(lines: []co.Payload, text: string) -> bool {
	for p in lines {payload := p; if strings.contains(string(payload.text[:payload.length]), text) {return true}}
	return false
}

@(test)
legacy_profile_names_are_safe_for_chat_without_changing_game_validation :: proc(t: ^testing.T) {
	w := game.initial(); before := flow.news_state(&w)
	w.players[0].connected = true
	for text in ([3]string{"Axle\u2028keeper", "Axle\u0085keeper", "   "}) {
		w.players[0].profile.name = game.name(text)
		testing.expect(t, game.name_valid(w.players[0].profile.name))
		after := flow.news_state(&w); lines, count := flow.news_lines(before, after)
		testing.expect_value(t, count, 1); testing.expect(t, news_has(lines[:count], "runner 1 rolls up"))
		name := after.players[0].name; testing.expect_value(t, lb.text(&name), "runner 1")
		for line in lines[:count] {testing.expect(t, co.valid(line, true))}
	}
}

@(test)
yard_news_reports_edges_once_and_keeps_roster_identity_separate :: proc(t: ^testing.T) {
	w := game.initial(); before := flow.news_state(&w)
	w.players[0].connected = true; w.players[0].profile.name = game.name("Axle")
	after := flow.news_state(&w); lines, count := flow.news_lines(before, after)
	testing.expect_value(t, count, 1); testing.expect(t, news_has(lines[:count], "Axle rolls up"))
	_, count = flow.news_lines(after, after); testing.expect_value(t, count, 0)
	before = after; w.players[0].profile.name = game.name("Brake"); after = flow.news_state(&w)
	_, count = flow.news_lines(before, after); testing.expect_value(t, count, 0)
	before = after; w.players[0].connected = false; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "Brake is gone"))
	before = after; w.players[0].connected = true; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "Brake climbs back"))
}

@(test)
yard_news_covers_waves_gate_cancel_and_reset_without_false_horde_on_boss_floor :: proc(t: ^testing.T) {
	w := run_world(); w.stage = .Staging; before := flow.news_state(&w)
	w.stage = .Yard; w.director.wave = 1; after := flow.news_state(&w)
	lines, count := flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "the yard opens"))
	before = after; w.wave_count = 3; w.director.wave = 2; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "wave 2 of 3 rolls in"))
	before = after; w.stage = .Clear; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "floor clear"))
	before = after; w.depart.left = 180; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "platform shudders"))
	before = after; w.depart.left = 0; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "platform holds"))
	before = after; w.floor = 2; w.stage = .Yard; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "floor 2 — deeper"))
	before = after; w.stage = .Over; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "yard goes quiet"))
	before = after; w.run += 1; w.floor = 1; w.stage = .Yard; after = flow.news_state(&w)
	lines, count = flow.news_lines(before, after); testing.expect(t, news_has(lines[:count], "parts and cores stay"))
	w.rules = game.RUN_RULES; w.floor = 12; testing.expect(t, !flow.news_state(&w).horde)
	w.floor = 3; testing.expect(t, flow.news_state(&w).horde)
	for line in lines[:count] {testing.expect(t, line.kind == .System && co.valid(line, true))}
	before = flow.News_State{floor = 4, stage = .Yard, boss = true}
	after = before; after.boss = false; after.stage = .Clear
	lines, count = flow.news_lines(before, after)
	testing.expect_value(t, count, 2)
	testing.expect(t, news_has(lines[:1], "TITAN falls") && news_has(lines[1:2], "floor clear"))
}
