//gd:extends CanvasLayer
//gd:class LevelUpMenu
package survivors_scripts

// ----------------------------------------------------------------------------
// LevelUpMenu — on a level-up the Game pauses the tree and calls present(), which draws 3
// RANDOM UpgradeConfigs from the pool and shows each on a Button (name + description). The
// player clicks one -> apply it to the player (typed) -> ask the Game to resume (or show the
// next owed choice). Its CanvasLayer process_mode is Always, so it keeps working while paused.
//
// FEATURES: a big bank of typed custom-resource `@export` slots (the upgrade pool — the
// numbered fields are deliberate: EXPORT fields have no array form, each is an Inspector
// slot); an `@onready` ARRAY (`Panel/Choice%d`) wiring the three Buttons in one declaration;
// ONE indexed `@(gd_connect = "...%d:pressed")` handler with the pressed button's index bound
// as the trailing arg (replaces per-button stubs); reading a custom resource's String fields
// generically (gd.get_string); typed cross-script calls into the player (apply_upgrade) and
// the Game (after_pick) found by group (rt.first_script_in_group).
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

	// child controls — the onready ARRAY form: one declaration resolves Panel/Choice0..2
	// (the `%d` is substituted with 0-based indices at READY).
	choices: [3]gd.Button `gd:"onready=Panel/Choice%d"`,

	// the 3 currently-offered upgrades
	offered:  [3]^gd.Resource,
	noffered: int,
}

levelup_menu_ready :: proc(self: ^LevelupMenu) {
	gd.set_bool(self.owner, "visible", false)
	// (Each Choice button's `pressed` is wired declaratively — see levelup_menu_on_choice.)
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
	for i in 0 ..< 3 {
		btn := self.choices[i]
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

	// Typed, class-checked group lookups — one call replaces the find-node + rt.script_of pair.
	if p := rt.first_script_in_group(self.owner, GROUP_PLAYER, Player); p != nil {
		player_apply_upgrade(p, cfg)
	}
	if g := rt.first_script_in_group(self.owner, GROUP_GAME, Game); g != nil {
		game_after_pick(g)
	}
}

// on_choice — THE button handler: the indexed @(gd_connect) probes Panel/Choice0, 1, 2 and
// connects each button's `pressed` here with that button's index BOUND as the trailing arg.
// One @(gd_method) replaces the three per-button stubs — and the test can still invoke it
// exactly the way a click would: `levelup.call("on_choice", 0)`.
@(gd_method, gd_connect = "Panel/Choice%d:pressed")
levelup_menu_on_choice :: proc(self: ^LevelupMenu, idx: gd.Int) {
	levelup_menu_choose(self, int(idx))
}
