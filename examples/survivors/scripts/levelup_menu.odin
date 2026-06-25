//gd:extends CanvasLayer
//gd:class LevelUpMenu
package survivors_scripts

// ----------------------------------------------------------------------------
// LevelUpMenu — on a level-up the Game pauses the tree and calls present(), which draws 3
// RANDOM UpgradeConfigs from the pool and shows each on a Button (name + description). The
// player clicks one -> apply it to the player (typed) -> ask the Game to resume (or show the
// next owed choice). Its CanvasLayer process_mode is Always, so it keeps working while paused.
//
// FEATURES: a big bank of typed custom-resource `@export` slots (the upgrade pool); `@onready`
// button/label refs; `gd.connect_to` wiring each Button's `pressed` to a @(gd_method) handler;
// reading a custom resource's String fields generically (gd.get_string); typed cross-script
// calls into the player (apply_upgrade) and the Game (after_pick).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:fmt"
import "core:math/rand"

POOL :: 10

LevelupMenu :: struct {
	owner: gd.Node,

	// The upgrade pool — assign UpgradeConfig .tres assets in the Inspector.
	upgrade0: ^gd.Resource `gd:"export,resource=UpgradeConfig,group=Upgrade Pool"`,
	upgrade1: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade2: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade3: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade4: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade5: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade6: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade7: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade8: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,
	upgrade9: ^gd.Resource `gd:"export,resource=UpgradeConfig"`,

	// child controls
	choice0: gd.Node `gd:"onready=Panel/Choice0"`,
	choice1: gd.Node `gd:"onready=Panel/Choice1"`,
	choice2: gd.Node `gd:"onready=Panel/Choice2"`,

	// the 3 currently-offered upgrades
	offered:  [3]^gd.Resource,
	noffered: int,
}

levelup_menu_ready :: proc(self: ^LevelupMenu) {
	gd.set_bool(self.owner, "visible", false)
	if self.choice0 != nil {gd.connect_to(self.choice0, "pressed", self.owner, "pick0")}
	if self.choice1 != nil {gd.connect_to(self.choice1, "pressed", self.owner, "pick1")}
	if self.choice2 != nil {gd.connect_to(self.choice2, "pressed", self.owner, "pick2")}
}

@(private = "file")
levelup_menu_pool :: proc(self: ^LevelupMenu) -> [POOL]^gd.Resource {
	return [POOL]^gd.Resource{
		self.upgrade0, self.upgrade1, self.upgrade2, self.upgrade3, self.upgrade4,
		self.upgrade5, self.upgrade6, self.upgrade7, self.upgrade8, self.upgrade9,
	}
}

// present — draw 3 distinct random upgrades and show the menu. Called by the Game on level-up.
levelup_menu_present :: proc(self: ^LevelupMenu) {
	pool := levelup_menu_pool(self)

	// Collect the non-nil slots' indices.
	idx: [POOL]int
	n := 0
	for i in 0 ..< POOL {
		if pool[i] != nil {idx[n] = i; n += 1}
	}
	if n == 0 {return}

	// Fisher-Yates partial shuffle to draw up to 3 distinct picks.
	pick := 3
	if pick > n {pick = n}
	for i in 0 ..< pick {
		j := i + int(rand.int31()) % (n - i)
		idx[i], idx[j] = idx[j], idx[i]
	}

	self.noffered = pick
	buttons := [3]gd.Node{self.choice0, self.choice1, self.choice2}
	for i in 0 ..< 3 {
		btn := buttons[i]
		if btn == nil {continue}
		if i < pick {
			cfg := pool[idx[i]]
			self.offered[i] = cfg
			name := gd.get_string(cast(gd.Object)cfg, "name")
			desc := gd.get_string(cast(gd.Object)cfg, "description")
			gd.set_string(btn, "text", fmt.ctprintf("%s\n%s", name, desc))
			gd.set_bool(btn, "visible", true)
		} else {
			gd.set_bool(btn, "visible", false)
		}
	}

	gd.set_bool(self.owner, "visible", true)
}

@(private = "file")
levelup_menu_choose :: proc(self: ^LevelupMenu, i: int) {
	if i < 0 || i >= self.noffered {return}
	cfg := self.offered[i]
	if cfg == nil {return}

	player := find_player(self.owner)
	if player != nil {
		p := rt.script_of(player, Player)
		if p != nil {player_apply_upgrade(p, cfg)}
	}
	game := find_game(self.owner)
	if game != nil {
		g := rt.script_of(game, Game)
		if g != nil {game_after_pick(g)}
	}
}

// The three button handlers (each Button's `pressed` is connected to one in _ready). They are
// @(gd_method) so the engine can dispatch the signal to them — and the test can invoke them
// exactly the way a click would.
@(gd_method)
levelup_menu_pick0 :: proc(self: ^LevelupMenu) {levelup_menu_choose(self, 0)}
@(gd_method)
levelup_menu_pick1 :: proc(self: ^LevelupMenu) {levelup_menu_choose(self, 1)}
@(gd_method)
levelup_menu_pick2 :: proc(self: ^LevelupMenu) {levelup_menu_choose(self, 2)}
