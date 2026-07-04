package kit_ui

// HUD widgets (toolkit phase 3): the INTERACT PROMPT ("E — open chest") and
// the INVENTORY GRID / hotbar. Same contract as everything in kit/ui — build
// controls, never own flow: the game decides what the prompt says (usually
// from kinter.pick each frame) and when the grid repaints (bag deltas).

import gd "godot:godot"
import kitems "godot:kit/items"
import "core:fmt"

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
	gd.set_bool(cast(gd.Object)p.label, "visible", false)
	return p
}

// What the player could use right now; "" hides the prompt.
prompt_set :: proc(p: ^Prompt, text: cstring) {
	gd.set_string(cast(gd.Object)p.label, "text", text)
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
