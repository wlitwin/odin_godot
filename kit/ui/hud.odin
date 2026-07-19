package kit_ui

// HUD widgets (toolkit phases 3+4): the INTERACT PROMPT ("E — open chest"),
// the INVENTORY GRID / hotbar, the HEALTH BAR, and the ABILITY BAR. Same
// contract as everything in kit/ui — build controls, never own flow: the
// game decides what the prompt says (usually from kinter.pick each frame)
// and when things repaint (state deltas, cast attempts).

import gd "godot:godot"
import kcombat "godot:kit/combat"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import "core:fmt"
import "core:strings"

// ---- interact prompt -------------------------------------------------------------

Prompt :: struct {
	label: gd.Label, // centered above the bottom edge
}

prompt_make :: proc(parent: gd.Node) -> Prompt {
	p: Prompt
	p.label = gd.new_label()
	gd.node_set_name(cast(gd.Node)p.label, gd.new_string_name_cstring("Prompt", true))
	gd.add_child(parent, cast(gd.Node)p.label)
	gd.control_set_anchors_preset(cast(gd.Control)p.label, .Preset_Center_Bottom, false)
	// Presets set ANCHORS only — an auto-sizing label at the exact bottom
	// edge otherwise grows DOWN, off screen. Grow up from a lifted baseline
	// (offsets are anchor-relative, so this tracks the bottom on resize),
	// and keep the center as the text changes width.
	gd.control_set_v_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Begin)
	gd.control_set_h_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Both)
	gd.control_set_offset(cast(gd.Control)p.label, .Top, -34)
	gd.control_set_offset(cast(gd.Control)p.label, .Bottom, -34)
	gd.set_bool(cast(gd.Object)p.label, "visible", false)
	return p
}

// What the player could use right now; "" hides the prompt.
prompt_set :: proc(p: ^Prompt, text: string) {
	set_text(cast(gd.Object)p.label, text)
	gd.set_bool(cast(gd.Object)p.label, "visible", text != "")
}

// ---- inventory grid / hotbar -------------------------------------------------------

// One row of slot cells. With `selected` it doubles as a hotbar (the
// selection marker is textual, like everything here — stock theme, no art).
Inv :: struct {
	root:  gd.Control, // HBox
	cells: [dynamic]gd.Label,
}

inv_make :: proc(parent: gd.Node, capacity: int) -> Inv {
	inv: Inv
	inv.root = cast(gd.Control)gd.new_h_box_container()
	gd.node_set_name(cast(gd.Node)inv.root, gd.new_string_name_cstring("Inventory", true))
	gd.add_child(parent, cast(gd.Node)inv.root)
	for _ in 0 ..< capacity {
		cell := gd.new_label()
		gd.add_child(cast(gd.Node)inv.root, cast(gd.Node)cell)
		append(&inv.cells, cell)
	}
	return inv
}

inv_destroy :: proc(inv: ^Inv) {
	delete(inv.cells)
	inv^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

inv_show :: proc(inv: ^Inv, visible: bool) {
	gd.set_bool(cast(gd.Object)inv.root, "visible", visible)
}

// ---- health bar ---------------------------------------------------------------

HP_CELLS :: 10

Health_Bar :: struct {
	label: gd.Label,
}

hp_make :: proc(parent: gd.Node) -> Health_Bar {
	hb: Health_Bar
	hb.label = gd.new_label()
	gd.node_set_name(cast(gd.Node)hb.label, gd.new_string_name_cstring("Health", true))
	gd.add_child(parent, cast(gd.Node)hb.label)
	return hb
}

// Text blocks over stock theme: "hp ▓▓▓▓▓▓▓░░░ 70/100". Zero art to install,
// and a test can read the exact fill back out of the tree.
// A play.Health block feeds this directly: `kui.hp_refresh(&hb,
// i32(r.health.hp), i32(r.health.max))` — the widget speaks plain ints on
// purpose, so no layer owns it.
hp_refresh :: proc(hb: ^Health_Bar, current, max_hp: i32) {
	filled := 0
	if max_hp > 0 {
		filled = clamp(int((current * HP_CELLS + max_hp - 1) / max_hp), 0, HP_CELLS)
	}
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, "hp ")
	for i in 0 ..< HP_CELLS {
		strings.write_string(&b, i < filled ? "\xE2\x96\x93" : "\xE2\x96\x91") // ▓ / ░
	}
	fmt.sbprintf(&b, " %d/%d", current, max_hp)
	gd.set_string(cast(gd.Object)hb.label, "text", fmt.ctprintf("%s", strings.to_string(b)))
}

// ---- ability bar ----------------------------------------------------------------

Ability_Bar :: struct {
	root:  gd.Control, // HBox
	cells: [dynamic]gd.Label,
}

abilities_make :: proc(parent: gd.Node, capacity: int) -> Ability_Bar {
	bar: Ability_Bar
	bar.root = cast(gd.Control)gd.new_h_box_container()
	gd.node_set_name(cast(gd.Node)bar.root, gd.new_string_name_cstring("Abilities", true))
	gd.add_child(parent, cast(gd.Node)bar.root)
	for _ in 0 ..< capacity {
		cell := gd.new_label()
		gd.add_child(cast(gd.Node)bar.root, cast(gd.Node)cell)
		append(&bar.cells, cell)
	}
	return bar
}

abilities_destroy :: proc(bar: ^Ability_Bar) {
	delete(bar.cells)
	bar^ = {}
}

// Repaint from the defs and the replicated cooldown array: "[rock]" ready,
// "[rock 1.2s]" cooling, "[rock $]" ready-but-unaffordable. Cooldowns count
// NET TICKS — pass `session_tick_hz(&ses)` so the seconds shown are true at
// any configured rate (the default only matches a session left at knet's
// 20 Hz; a 60 Hz game that omits it shows cooldowns 3× too long).
//
// BOTH ability models feed this one widget — kcombat.Ability_Def is the def
// vocabulary at every layer since play went canonical-shelf. A slot-array
// game passes its Cooldowns bundle (`c.cds[:]`); a play-block game gathers
// its blocks' countdowns into a local array beside the same def rows:
//
//     kui.abilities_refresh(&bar, defs, []u16{r.slime.cd, r.ignite.cd}, gold, hz)
//
// (kit/ui can never import play — the arrow points play → kit — and it
// never needs to: the shared def table IS the flip.)
abilities_refresh :: proc(bar: ^Ability_Bar, defs: []kcombat.Ability_Def, cds: []u16, resource: i32, tick_rate := knet.DEFAULT_TICK_HZ) {
	for cell, i in bar.cells {
		if i >= len(defs) {
			gd.set_string(cast(gd.Object)cell, "text", "")
			continue
		}
		text: cstring
		switch {
		case i < len(cds) && cds[i] > 0:
			text = fmt.ctprintf("[%s %.1fs]", defs[i].name, f32(cds[i]) / f32(tick_rate))
		case resource < defs[i].cost:
			text = fmt.ctprintf("[%s $]", defs[i].name)
		case:
			text = fmt.ctprintf("[%s]", defs[i].name)
		}
		gd.set_string(cast(gd.Object)cell, "text", text)
	}
}

// Repaint from a slot array: "torch x3", "-" when empty, the selected cell
// bracketed. Call when the bag changes (a state delta, a confirmed command).
inv_refresh :: proc(inv: ^Inv, slots: []kitems.Slot, table: ^kitems.Table, selected := -1) {
	for cell, i in inv.cells {
		body: string
		if i < len(slots) && slots[i].item != kitems.ITEM_NONE {
			body = fmt.tprintf("%s x%d", kitems.items_name(table, slots[i].item), slots[i].count)
		} else {
			body = "-"
		}
		text := i == selected ? fmt.ctprintf("[%s]", body) : fmt.ctprintf(" %s ", body)
		gd.set_string(cast(gd.Object)cell, "text", text)
	}
}
