#+build darwin, linux, windows
package core

// ----------------------------------------------------------------------------
// Format on save — `odinfmt` (ships with ols) run from the save path (core/saver.odin):
// the file that lands on disk is formatted, the OPEN EDITOR BUFFER is updated to match
// (as ONE undoable operation, caret/scroll preserved, no unsaved dot), and the script
// resource's source is kept in sync.
//
// Behavior contract:
//   * Controlled by the `odin_godot/format_on_save` project setting; defaults ON when
//     odinfmt is resolvable, silently OFF when it isn't (only a user who EXPLICITLY set
//     the setting true gets a one-time "odinfmt not found" warning — a default must
//     never nag people who don't use ols/odinfmt).
//   * A source odinfmt rejects (mid-edit syntax errors are NORMAL) saves UNFORMATTED —
//     saving must never fail or alter code because it doesn't parse yet; the validator's
//     squiggles already report the syntax error.
//   * A project-root `odinfmt.json` is honored (passed via -config).
//
// odinfmt resolution mirrors ols (core/complete.odin): setting -> env -> PATH — plus a
// sibling-of-ols fallback, because the ols distribution ships both binaries side by side
// (a user who configured `odin_godot/ols_bin` gets odinfmt for free).
// ----------------------------------------------------------------------------

import "godot:godot"

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"

@(private = "file")
warned_no_odinfmt: bool

// The `odin_godot/format_on_save` setting; absent == true (see contract above — the
// missing-binary case degrades to a silent no-op, so default-on is safe).
@(private = "file")
format_on_save_enabled :: proc() -> bool {
	ps := godot.singleton_project_settings()
	key := godot.new_string_cstring("odin_godot/format_on_save")
	if !bool(godot.project_settings_has_setting(ps, key)) {
		return true
	}
	def := godot.Variant{}
	v := godot.project_settings_get_setting(ps, key, def)
	return bool(godot.variant_to_bool(&v))
}

// Explicitly-enabled check for the one-time warning: only a user who SET the setting
// (to true) has expressed intent strong enough to warrant a missing-binary warning.
@(private = "file")
format_explicitly_enabled :: proc() -> bool {
	ps := godot.singleton_project_settings()
	key := godot.new_string_cstring("odin_godot/format_on_save")
	if !bool(godot.project_settings_has_setting(ps, key)) {
		return false
	}
	def := godot.Variant{}
	v := godot.project_settings_get_setting(ps, key, def)
	return bool(godot.variant_to_bool(&v))
}

@(private = "file")
resolve_odinfmt :: proc(allocator := context.allocator) -> (string, bool) {
	if bin, ok := resolve_bin("odin_godot/odinfmt_bin", "ODINFMT", "odinfmt", allocator); ok {
		return bin, true
	}
	// Sibling of a resolved ols: the ols repo builds/ships odinfmt alongside it.
	if ols_bin, ok := resolve_bin("odin_godot/ols_bin", "OLS", "ols", context.temp_allocator); ok {
		if idx := strings.last_index_byte(ols_bin, '/'); idx >= 0 {
			cand := strings.concatenate({ols_bin[:idx], "/odinfmt"}, allocator)
			if os.exists(cand) {
				return cand, true
			}
			delete(cand, allocator)
		}
	}
	return "", false
}

// format_odin_source — run odinfmt over `source`, returning the formatted text.
// ok=false on ANY problem (no odinfmt, odinfmt rejected the source, empty result) —
// the caller saves the original bytes unchanged.
//
// Mechanics: the source is written to a temp overlay file (odinfmt takes a path;
// TMPDIR, never the project — a stray .odin inside res:// would be scanned as a
// script), formatted to captured stdout, stderr dropped. A project-root odinfmt.json
// is forwarded with -config so user style settings apply.
@(private)
format_odin_source :: proc(source: string, allocator := context.allocator) -> (formatted: string, ok: bool) {
	if source == "" {
		return "", false
	}
	odinfmt_bin, found := resolve_odinfmt(context.temp_allocator)
	if !found {
		if !warned_no_odinfmt && format_explicitly_enabled() {
			warned_no_odinfmt = true
			editor_msg_warn(
				"odin_godot: `odinfmt` not found but `odin_godot/format_on_save` is enabled — " +
				"saving without formatting. Fix: set the `odin_godot/odinfmt_bin` project setting " +
				"(odinfmt ships with ols), or put it on the editor's PATH.",
			)
		}
		return "", false
	}

	tmpdir := os.get_env("TMPDIR", context.temp_allocator)
	if tmpdir == "" {
		tmpdir = "/tmp"
	}
	tmpdir = strings.trim_suffix(tmpdir, "/")
	overlay := fmt.tprintf("%s/.odin_godot_fmt.odin", tmpdir)
	out_file := fmt.tprintf("%s/.odin_godot_fmt.out", tmpdir)
	if werr := os.write_entire_file(overlay, transmute([]u8)source); werr != nil {
		return "", false
	}
	defer os.remove(overlay)
	defer os.remove(out_file)

	// Forward the project's odinfmt.json when present (odinfmt discovers config by
	// walking up from the FILE, and the overlay lives in TMPDIR — outside the project).
	config_arg := ""
	{
		gres := godot.new_string_cstring("res://odinfmt.json")
		pg := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
		cfg := string_to_odin(pg, context.temp_allocator)
		if cfg != "" && os.exists(cfg) {
			config_arg = fmt.tprintf(" -config:%s", shell_quote(cfg, context.temp_allocator))
		}
	}

	cmd := fmt.ctprintf(
		"%s%s %s > %s 2>/dev/null",
		shell_quote(odinfmt_bin, context.temp_allocator),
		config_arg,
		shell_quote(overlay, context.temp_allocator),
		shell_quote(out_file, context.temp_allocator),
	)
	if libc.system(cmd) != 0 {
		return "", false // odinfmt rejected it (normal mid-edit) — save unformatted
	}
	data, rerr := os.read_entire_file(out_file, allocator)
	if rerr != nil || len(data) == 0 {
		return "", false
	}
	return string(data), true
}

// format_sync_editor_buffer — if `path` is the script open in the ACTIVE script editor,
// replace its buffer with `formatted` so the user's view matches the file just written.
//
//   * ONE complex operation (begin/end + select_all + insert_text_at_caret) — the
//     reformat is a single Ctrl+Z step and, unlike set_text, does NOT clear the undo
//     history.
//   * caret + vertical scroll restored (clamped by the engine if lines shifted).
//   * tag_saved_version — the buffer now equals what's on disk; no phantom unsaved dot.
//
// A saved-but-not-focused script (Save All) is NOT synced — its buffer keeps the
// unformatted text and simply reformats on ITS next save; disk is always formatted.
@(private)
format_sync_editor_buffer :: proc(path: godot.String, formatted: string) {
	ei := godot.singleton_editor_interface()
	if ei == nil {
		return
	}
	se := godot.editor_interface_get_script_editor(ei)
	if se == nil {
		return
	}
	script := godot.script_editor_get_current_script(se)
	if script == nil {
		return
	}
	cur := godot.resource_get_path(cast(godot.Resource)script)
	cur_odin := string_to_odin(cur, context.temp_allocator)
	path_odin := string_to_odin(path, context.temp_allocator)
	if cur_odin != path_odin {
		return
	}
	current := godot.script_editor_get_current_editor(se)
	if current == nil {
		return
	}
	code_edit := godot.script_editor_base_get_base_editor(current)
	if code_edit == nil {
		return
	}
	te := cast(godot.Text_Edit)code_edit

	caret_line := godot.text_edit_get_caret_line(te, 0)
	caret_col := godot.text_edit_get_caret_column(te, 0)
	scroll := godot.text_edit_get_scroll_vertical(te)

	godot.text_edit_begin_complex_operation(te)
	godot.text_edit_select_all(te)
	s := godot.new_string_odin(formatted)
	godot.text_edit_insert_text_at_caret(te, s, -1)
	godot.text_edit_end_complex_operation(te)

	godot.text_edit_set_caret_line(te, godot.Int(caret_line), true, true, 0, 0)
	godot.text_edit_set_caret_column(te, godot.Int(caret_col), true, 0)
	godot.text_edit_set_scroll_vertical(te, scroll)
	godot.text_edit_tag_saved_version(te)
}

// format_for_save — the saver's one entry point: returns the text to WRITE for `path`
// (formatted when possible, the original otherwise) and updates the resource + open
// buffer when formatting changed anything.
//
// Gating: in the EDITOR the default-on setting applies; outside it (headless tools,
// tests) only an EXPLICIT `format_on_save = true` formats — the default must never
// mutate sources from a non-editor process, but a process that asked by name gets it
// (this is also what makes the behavior testable headless; see tests/save).
@(private)
format_for_save :: proc(
	resource: godot.Script,
	path: godot.String,
	source: string,
	allocator := context.allocator,
) -> string {
	if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		if !format_on_save_enabled() {
			return source
		}
	} else if !format_explicitly_enabled() {
		return source
	}
	formatted, ok := format_odin_source(source, allocator)
	if !ok || formatted == source {
		if ok {delete(formatted, allocator)}
		return source
	}
	// Keep the resource's in-memory source consistent with the bytes hitting disk —
	// get_source_code callers (validation overlays, future saves) must see the same text.
	fs := godot.new_string_odin(formatted)
	godot.script_set_source_code(resource, fs)
	format_sync_editor_buffer(path, formatted)
	return formatted
}
