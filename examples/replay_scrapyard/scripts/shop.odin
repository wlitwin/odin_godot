package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"
import content "../shared/content"

// The original counter is an authored scene. Prices come from the same constants
// as the reducer; cards and shortcuts share this local convenience gate. The
// authority still validates every submitted action, including affordability.
shop_can :: proc(player: game.Player, card: int) -> bool {
	if card < 0 || card >= 9 || !player.connected || !player.in_yard {
		return false
	}
	if card == 8 {
		return true
	}
	if card >= 4 {
		prices := game.PART_PRICES
		part := u8(card - 4)
		return !game.has_part(player.parts, part) && player.cores >= prices[part]
	}
	prices := game.SHOP_PRICES
	if player.scrap < prices[card + 1] {
		return false
	}
	switch card {
	case 0:
		return player.boost_damage < max(u8)
	case 1:
		return player.boost_rate < max(u8)
	case 2:
		return player.boost_speed < max(u8)
	case 3:
		return player.hp < game.max_health(player.parts)
	}
	return false
}

shop_submit :: proc(self: ^ReplayScrapyard, card: int) {
	if self.menu_open || !self.session.ready || gd.control_has_focus(self.chat_input, false) {
		return
	}
	seat := rgd.session_seat(self.session)
	state, ok := rgd.session_state(self.session)
	if !ok || seat == 0 || state.state.stage != .Clear || !shop_can(state.state.players[seat - 1], card) {
		return
	}
	if card >= 4 && card < 8 {
		issue(self, {kind = .Workshop, item = u8(card - 4)})
	} else {
		issue(self, {kind = .Buy, item = card == 8 ? u8(5) : u8(card + 1)})
	}
}

@(gd_method, gd_connect = "UI/Shop/Card%d:pressed")
replay_scrapyard_on_shop_card :: proc(self: ^ReplayScrapyard, card: gd.Int) {
	if card < 0 || card >= 9 {
		return
	}
	shop_submit(self, int(card))
}

shop_wants_mouse :: proc(self: ^ReplayScrapyard) -> bool {
	if !gd.canvas_item_is_visible_in_tree(self.shop) {
		return false
	}
	// Local coordinates remain correct if the scene or viewport is scaled.
	point := gd.canvas_item_get_local_mouse_position(self.shop)
	size := gd.control_get_size(self.shop)
	return point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y
}

shop_paint :: proc(self: ^ReplayScrapyard, world: ^game.World, player: game.Player, inside: bool) {
	open := inside && world.stage == .Clear
	gd.canvas_item_set_visible(self.shop, open)
	if !open {
		return
	}
	gd.set_string(
		self.shop_wallet,
		"text",
		fmt.ctprintf(
			"THE COUNTER — scrap %d · cores %d   (keys 1–8 buy · 9 swaps iron)",
			player.scrap,
			player.cores,
		),
	)
	prices := game.SHOP_PRICES
	faces := [9]cstring {
		0 = fmt.ctprintf("+1 DMG\n%d scrap\nlv %d", prices[1], player.boost_damage),
		1 = fmt.ctprintf("+RATE\n%d scrap\nlv %d", prices[2], player.boost_rate),
		2 = fmt.ctprintf("+SPEED\n%d scrap\nlv %d", prices[3], player.boost_speed),
		3 = fmt.ctprintf("PATCH UP\n%d scrap\nhp %d/%d", prices[4], player.hp, game.max_health(player.parts)),
	}
	names := [4]string{"BELT", "PLATE", "CATALYST", "MAGNET"}
	part_prices := game.PART_PRICES
	for name, i in names {
		faces[4 + i] =
			game.has_part(player.parts, u8(i)) ? fmt.ctprintf("%s\nOWNED", name) : fmt.ctprintf("%s\n%d cores", name, part_prices[i])
	}
	next := content.next_gun(&world.catalog, player.gun_id)
	faces[8] = fmt.ctprintf("SWAP IRON\n> %s\nfree", content.name_string(&world.catalog.guns[next].name))
	hints := [9]cstring {
		"+1 damage on every slug you fire — this run only",
		"a faster trigger — this run only",
		"faster legs — this run only",
		"patch back to FULL hp — the plate's extra included",
		"BELT-FEED: a permanently faster trigger",
		"PLATED FRAME: +4 max hp, kept after a wipe",
		"CATALYST: slime and burn last half again as long",
		"MAGNET: scrap leaps to you from farther out",
		"trade your iron for the next on the rack — free",
	}
	hint: cstring = "point at a card to see what it does · gather at the east gate to descend"
	hovered, focused := -1, -1
	for button, i in self.shop_cards {
		gd.set_string(button, "text", faces[i])
		gd.base_button_set_disabled(button, self.menu_open || !shop_can(player, i))
		if gd.base_button_is_hovered(button) {
			hovered = i
		}
		if gd.control_has_focus(button, true) {
			focused = i
		}
	}
	if hovered >= 0 {
		hint = hints[hovered]
	} else if focused >= 0 {
		hint = hints[focused]
	}
	gd.set_string(self.shop_hint, "text", hint)
}

// Keyboard shortcuts retain the shop card order used by the authored UI.
capture_shop_shortcuts :: proc(self: ^ReplayScrapyard) {
	buys := [5]cstring{"rsy_buy1", "rsy_buy2", "rsy_buy3", "rsy_buy4", "rsy_buy5"}
	parts := [4]cstring{"rsy_part0", "rsy_part1", "rsy_part2", "rsy_part3"}
	for key, i in buys {
		if gd.is_action_just_pressed(key) {
			shop_submit(self, i < 4 ? i : 8)
		}
	}
	for key, i in parts {
		if gd.is_action_just_pressed(key) {
			shop_submit(self, 4 + i)
		}
	}
}
