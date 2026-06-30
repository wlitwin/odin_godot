//gd:extends Area2D
//gd:class Coin
//gd:signal collected(value: int)
package showcase_scripts

// ----------------------------------------------------------------------------
// Coin — an Area2D that, on _ready, wires its OWN `body_entered` signal to its Odin
// `collect` method (pure-Odin in-game wiring; no GDScript). When the player's body
// overlaps the coin, Godot fires `body_entered` -> our `collect`, which bumps the shared
// score, emits the script-declared `collected` signal, and removes the coin.
//
// `value` is an @export so each coin in the scene can be worth a different amount.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Coin :: struct {
	owner: gd.Area2d,
	value: gd.Int `gd:"export"`,
	// Typed-collection exports (regression for the `array=`/`dict=` hints): these must render
	// the Inspector's typed-array / typed-dictionary editors, i.e. emit the exact same
	// PropertyInfo (hint Type_String, encoded hint_string) GDScript produces for Array[int] /
	// Dictionary[String,int].
	tags:    gd.Array `gd:"export,array=int"`,
	rewards: gd.Dictionary `gd:"export,dict=String;int"`,
	taken:   bool, // private guard so a coin is only collected once
}

coin_ready :: proc(self: ^Coin) {
	if self.value == 0 {self.value = 1}
}

// collect(body) — the body_entered target. `@(gd_connect="body_entered")` auto-wires
// owner.body_entered -> this method on _ready (no manual connect needed). Bumps the shared
// score, emits `collected`, and frees the coin. `body` is the entering node.
@(gd_method, gd_connect = "body_entered")
coin_collect :: proc(self: ^Coin, body: ^gd.Node2d) {
	if self.taken {return}
	self.taken = true
	game_state_add(self.value)
	coin_emit_collected(self, i64(self.value)) // generated from //gd:signal
	gd.node_queue_free(self.owner)
}
