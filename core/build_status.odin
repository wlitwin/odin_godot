#+build darwin, linux, windows
package core

// ----------------------------------------------------------------------------
// Build-status surfacing for the reload-on-save coordinator (core/reload.odin):
//
//   1. A TOOLBAR WIDGET (a Label in the editor's top toolbar, EditorPlugin
//      CONTAINER_TOOLBAR): "building…" while a background scripts build runs,
//      "build FAILED" (red, sticky) after a broken save, a transient green
//      "live ✓ (X.Xs)" once the rebuilt dll is swapped in. The Output dock says
//      all of this too — but the Output is often closed, and a status light must
//      be visible without opening anything. Hidden when idle: an always-on badge
//      is noise, the widget exists to answer "is the editor doing something?".
//
//   2. THE PLAY GATE (EditorPlugin._build, dispatched from export_plugin.odin):
//      Godot calls _build on every editor plugin when the user presses Play, and
//      a `false` return CANCELS the run — the same hook C# uses to compile before
//      launch. Without it, save-then-Play raced the background build and silently
//      ran the PREVIOUS dll (the atomic publish keeps the old file until the new
//      one is done). Now Play blocks (bounded) until an in-flight build settles,
//      and refuses to launch on a failed build instead of running stale code.
//
// Both read the coordinator's state under its mutex; the widget is driven from
// the lv_frame pump (main thread), the gate runs on the main thread inside the
// Play press. Editor-only by construction: the widget is created in _enter_tree
// of the editor plugin, and _build is only ever invoked by the editor.
// ----------------------------------------------------------------------------

import "godot:godot"

import "core:fmt"
import "core:sync"
import "core:time"

@(private = "file")
Status_Phase :: enum {
	Hidden,
	Building,
	Failed,
	Live, // transient success flash
}

@(private = "file")
g_status: struct {
	label:        godot.Label, // nil until the editor plugin creates it
	phase:        Status_Phase,
	live_started: time.Tick, // when the Live flash began (hide after LIVE_FLASH)
}

@(private = "file")
LIVE_FLASH :: 4 * time.Second

// How long Play will wait for an in-flight build before giving up. Script builds run
// ~1-5s; the cap only exists so a wedged build can never brick the Play button.
@(private = "file")
PLAY_GATE_CAP :: 60 * time.Second

// build_status_create — construct the toolbar Label and park it in the editor's top
// toolbar. Called from OdinEditorPlugin._enter_tree (editor only, once).
//
// The label stays PERMANENTLY visible with a RESERVED width; "hidden" is empty text.
// Why: the Play gate (below) blocks the main thread and repaints via force_draw, but
// container re-layout rides the message queue, which does NOT flush while blocked — a
// label that becomes visible (or grows) mid-block would render unlaid-out. A fixed
// footprint whose TEXT changes needs no layout pass, so the badge can appear even
// inside the blocking wait. When idle the reserved strip is empty and invisible.
@(private)
build_status_create :: proc(plug: godot.Editor_Plugin) {
	label := godot.new_label()
	godot.control_set_custom_minimum_size(cast(godot.Control)label, godot.Vector2{170, 0})
	godot.label_set_vertical_alignment(label, .Center)
	// Clip instead of growing: a text whose natural width exceeded the reserved 170px
	// would raise the minimum size and queue a container re-sort — exactly the deferred
	// layout the blocked-main-thread repaint can't have.
	godot.label_set_clip_text(label, true)
	godot.editor_plugin_add_control_to_container(plug, .Container_Toolbar, cast(godot.Control)label)
	g_status.label = label
	g_status.phase = .Hidden
}

// build_status_destroy — detach + free the Label on plugin _exit_tree (editor shutdown
// or plugin disable), so the tree never holds a control whose callbacks live in an
// unloading dll.
@(private)
build_status_destroy :: proc(plug: godot.Editor_Plugin) {
	if g_status.label == nil {
		return
	}
	godot.editor_plugin_remove_control_from_container(plug, .Container_Toolbar, cast(godot.Control)g_status.label)
	godot.node_queue_free(cast(godot.Node)g_status.label)
	g_status.label = nil
	g_status.phase = .Hidden
}

@(private = "file")
status_apply :: proc(text: string, color: godot.Color, tooltip: cstring) {
	l := g_status.label
	s := godot.new_string_odin(text)
	godot.label_set_text(l, s)
	fc := godot.new_string_name_cstring("font_color", true)
	godot.control_add_theme_color_override(cast(godot.Control)l, fc, color)
	tt := godot.new_string_cstring(tooltip)
	godot.control_set_tooltip_text(cast(godot.Control)l, tt)
}

// build_status_pump — drive the widget from the reload coordinator's state. Called every
// editor frame from lv_frame; cheap when idle (one mutex peek + an enum compare), and it
// only touches the UI on a phase TRANSITION.
@(private)
build_status_pump :: proc() {
	if g_status.label == nil {
		return
	}
	sync.lock(&g_reload.mutex)
	building := g_reload.build_running || g_reload.build_pending
	failed := g_reload.last_build_failed
	build_ms := g_reload.last_build_ms
	sync.unlock(&g_reload.mutex)

	desired := g_status.phase
	switch {
	case building:
		desired = .Building
	case failed:
		desired = .Failed
	case g_status.phase == .Building:
		// Build just settled cleanly -> flash success (the dll swap lands this same
		// pump chain, reload_pump runs first).
		desired = .Live
	case g_status.phase == .Live:
		if time.tick_since(g_status.live_started) > LIVE_FLASH {
			desired = .Hidden
		}
	case g_status.phase == .Failed:
		// `failed` cleared without a new build starting can't happen (only a build
		// result mutates it), but normalize anyway.
		desired = .Hidden
	}
	if desired == g_status.phase {
		return
	}
	g_status.phase = desired

	switch desired {
	case .Hidden:
		status_apply("", godot.Color{1, 1, 1, 1}, "")
	case .Building:
		status_apply(
			"Odin: building…",
			godot.Color{0.98, 0.86, 0.4, 1.0}, // editor warning yellow
			"Odin scripts are compiling. Play waits for this to finish.",
		)
	case .Failed:
		status_apply(
			"Odin: build FAILED",
			godot.Color{1.0, 0.44, 0.41, 1.0}, // editor error red
			"The scripts build failed — compiler errors are in the Output panel. " +
			"Play is blocked until a build succeeds.",
		)
	case .Live:
		g_status.live_started = time.tick_now()
		status_apply(
			fmt.tprintf("Odin: live ✓ %.1fs", build_ms / 1000),
			godot.Color{0.55, 0.92, 0.55, 1.0}, // success green
			"Scripts rebuilt and hot-swapped — your last save is live.",
		)
	}
}

// build_gate_before_play — the body of OdinEditorPlugin._build (see export_plugin.odin).
// Returns whether Play may proceed. Blocks the main thread while a build is in flight —
// deliberately: that is the entire point (the alternative is silently running the OLD
// dll), it is how the C# integration behaves, and script builds are seconds.
//
// VISIBILITY while blocked: with unsaved changes, Play runs try_autosave (which saves
// the scripts, kicking the rebuild) and call_build (this gate) in ONE main-thread stack
// — no editor frame renders in between, so without help the badge would never appear
// for exactly the save-then-Play flow it most matters for. So the gate paints the badge
// itself and repaints via RenderingServer.force_draw inside the wait (rendering only —
// deliberately NOT DisplayServer input processing, which could re-enter the editor from
// inside _build). The fixed-footprint label (see build_status_create) makes the text
// change safe without a message-queue layout flush.
@(private)
build_gate_before_play :: proc() -> bool {
	announced := false
	start := time.tick_now()
	for {
		sync.lock(&g_reload.mutex)
		busy := g_reload.build_running || g_reload.build_pending
		failed := g_reload.last_build_failed
		sync.unlock(&g_reload.mutex)

		if !busy {
			if failed {
				editor_msg_error(
					"odin_godot: not starting the game — the last scripts build FAILED, so it would run " +
					"your OLD code. Fix the compiler errors (Output panel), save, and Play again.",
				)
				return false
			}
			if announced {
				godot.print_str("odin_godot: scripts build finished — starting the game.")
			}
			return true
		}
		if !announced {
			announced = true
			godot.print_str("odin_godot: waiting for the scripts build to finish before Play…")
			if g_status.label != nil {
				g_status.phase = .Building // keep the pump's state machine consistent afterwards
				status_apply(
					"Odin: building…",
					godot.Color{0.98, 0.86, 0.4, 1.0},
					"Play is waiting for the Odin scripts build to finish.",
				)
			}
		}
		if time.tick_since(start) > PLAY_GATE_CAP {
			editor_msg_error(
				"odin_godot: scripts build still running after 60s — not starting the game. " +
				"If the build is genuinely wedged, check the Output panel / bin/.odin_reload.log.",
			)
			return false
		}
		if g_status.label != nil {
			// Repaint so the badge (set above) is actually seen during the block. ~10fps
			// is plenty for a status light and keeps the forced full-editor redraws cheap.
			godot.rendering_server_force_draw(godot.singleton_rendering_server(), true, 0)
		}
		time.sleep(100 * time.Millisecond)
	}
}
