package kit_ui

// The CHAT BOX (toolkit phase 2): a bounded scrollback of kit/comms lines and
// a line to speak into, anchored across the bottom of the screen. Same
// contract as the lobby — kit/ui builds controls, the GAME wires the input
// and repaints on events:
//
//     self.chat = kui.chat_make(self.owner)
//     gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")
//     // on_chat(text): kcomms.comms_say(&self.comms, text); kui.chat_clear_input(&self.chat)
//     kui.chat_refresh(&self.chat, &self.comms)   // on any Ev_Line

import gd "godot:godot"
import kcomms "godot:kit/comms"
import "core:fmt"

// Rows painted; the comms log keeps more (scrollback UI can come later).
CHAT_SHOW :: 8

Chat :: struct {
	root:      gd.Control, // bottom-wide VBox under the owner node
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
	gd.control_set_anchors_preset(ch.root, .Preset_Bottom_Wide, false)

	ch.lines_box = cast(gd.Control)gd.new_v_box_container()
	gd.add_child(cast(gd.Node)ch.root, cast(gd.Node)ch.lines_box)

	ch.input = gd.new_line_edit()
	gd.set_string(cast(gd.Object)ch.input, "placeholder_text", "say something...")
	gd.add_child(cast(gd.Node)ch.root, cast(gd.Node)ch.input)
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
