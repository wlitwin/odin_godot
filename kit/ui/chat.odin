package kit_ui

// The CHAT BOX (toolkit phase 2): a bounded scrollback of kit/comms lines and
// a line to speak into, anchored in the bottom-left corner. Same
// contract as the lobby — kit/ui builds controls, the GAME wires the input
// and repaints on events:
//
//     self.chat = kui.chat_make(self.owner)
//     gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")
//     // on_chat(text): kcomms.comms_say(&self.comms, text); kui.chat_clear_input(&self.chat)
//     kui.chat_refresh(&self.chat, &self.comms)   // on any Ev_Line

import gd "godot:godot"
import "godot:gdext"
import kcomms "godot:kit/comms"
import "core:fmt"

// Rows painted; the comms log keeps more (scrollback UI can come later).
CHAT_SHOW :: 8

Chat :: struct {
	root:      gd.Control, // bottom-left VBox under the owner node
	lines_box: gd.Control,
	input:     gd.Line_Edit,
	rows:      [dynamic]gd.Label, // reused across refreshes
}

// Build the chat box under `parent`. Call from ready(); show it when the
// session is up (chat with nobody wired is just a text box).
chat_make :: proc(parent: gd.Node) -> Chat {
	ch: Chat
	ch.root = cast(gd.Control)gd.new_v_box_container()
	gd.node_set_name(cast(gd.Node)ch.root, gd.new_string_name_cstring("Chat", true))
	gd.add_child(parent, cast(gd.Node)ch.root)
	// A bottom-LEFT column, not bottom-wide — the bottom edge is shared real
	// estate (prompt, legends). Pinned a strip above the edge; grow=Begin
	// means new lines push the box UP from that pinned bottom, the classic
	// chat shape. Offsets are anchor-relative, so it tracks window resizes.
	gd.control_set_anchors_preset(ch.root, .Preset_Bottom_Left, false)
	gd.control_set_v_grow_direction(ch.root, .Grow_Direction_Begin)
	gd.control_set_offset(ch.root, .Left, 8)
	gd.control_set_offset(ch.root, .Top, -30)
	gd.control_set_offset(ch.root, .Bottom, -30)

	ch.lines_box = cast(gd.Control)gd.new_v_box_container()
	gd.add_child(cast(gd.Node)ch.root, cast(gd.Node)ch.lines_box)

	ch.input = gd.new_line_edit()
	gd.set_string(cast(gd.Object)ch.input, "placeholder_text", "say something...")
	gd.control_set_custom_minimum_size(cast(gd.Control)ch.input, {240, 0})
	gd.add_child(cast(gd.Node)ch.root, cast(gd.Node)ch.input)
	return ch
}

// Adopt a game-authored chat scene (full replacement — see ui.odin's header).
// The CONTRACT, by node name at any depth:
//
//   Lines (any container — the scrollback rows land here) · Input (LineEdit)
//
// The scene owns its own anchoring; the kit only pours lines and reads the
// input. Row Labels are kit-created — theme them from the scene root.
chat_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene) -> Chat {
	ch: Chat
	node := gd.instantiate(scene)
	gd.add_child(parent, node)
	ch.root = cast(gd.Control)node
	ch.lines_box = cast(gd.Control)adopt_child(node, "Lines", "chat")
	ch.input = cast(gd.Line_Edit)adopt_child(node, "Input", "chat")
	return ch
}

chat_destroy :: proc(ch: ^Chat) {
	delete(ch.rows)
	ch^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

chat_show :: proc(ch: ^Chat, visible: bool) {
	gd.set_bool(cast(gd.Object)ch.root, "visible", visible)
}

chat_clear_input :: proc(ch: ^Chat) {
	gd.set_string(cast(gd.Object)ch.input, "text", "")
}

// Repaint the last CHAT_SHOW lines from the comms log: "name: text" for
// speech, "* text" for system lines. Rows (Labels) are reused; extras hide.
chat_refresh :: proc(ch: ^Chat, c: ^kcomms.Comms) {
	lines := kcomms.comms_lines(c)
	first := max(0, len(lines) - CHAT_SHOW)
	shown := lines[first:]
	for line, i in shown {
		row: gd.Label
		if i < len(ch.rows) {
			row = ch.rows[i]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)ch.lines_box, cast(gd.Node)row)
			append(&ch.rows, row)
		}
		gd.set_bool(cast(gd.Object)row, "visible", true)
		if line.player == kcomms.SYSTEM_LINE {
			gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("* %s", line.text))
		} else {
			name := kcomms.comms_line_name(c, line)
			gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s: %s", name, line.text))
		}
	}
	for i in len(shown) ..< len(ch.rows) {
		gd.set_bool(cast(gd.Object)ch.rows[i], "visible", false)
	}
}

// The whole text_submitted handler: extract (clamped — the utf8 length
// report exceeds the buffer on long lines, a bounds-check trap two games
// hit), say it, clear the box, and PUT THE KEYS BACK ON THE WHEEL. The
// focus release is the part that gets forgotten: without it a keyboard
// player's WASD stays trapped in the chat box after every message. `sent`
// (the game's latch) stops the submitting Enter from immediately re-opening
// chat when the game binds Enter to "talk".
chat_submit :: proc(ch: ^Chat, c: ^kcomms.Comms, text: gd.String, sent: ^bool = nil) {
	text := text
	buf: [512]u8
	// gdext direct: the ergonomics layer has no gd.String→odin-string extractor
	// yet (gd.get_string reads an Object property, not a signal's String value).
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&text, cast(cstring)&buf[0], len(buf) - 1)
	if n > 0 {
		kcomms.comms_say(c, string(buf[:min(int(n), len(buf) - 1)]))
	}
	chat_clear_input(ch)
	gd.control_release_focus(cast(gd.Control)ch.input)
	if sent != nil {
		sent^ = true
	}
}
