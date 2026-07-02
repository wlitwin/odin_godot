#+build darwin, linux
package core

// ----------------------------------------------------------------------------
// Editor-launched native debugging: Project > Tools >
//   * "Debug Game (LLDB)"            — opens a terminal window running the game under
//                                      lldb (auto-run; panics/crashes freeze in place).
//   * "Debug Game (Break at Cursor)" — same, plus a breakpoint on the line the caret is
//                                      sitting on in the script editor. The game halts
//                                      exactly where you're looking.
//   * "Generate VS Code Debug Config" — writes .vscode/launch.json + tasks.json so F5 in
//                                      VS Code (CodeLLDB) debugs the game with clickable
//                                      breakpoints in .odin files.
//
// Odin scripts are AOT-native with full DWARF (built -debug -use-single-module), so lldb
// is the real debugger: line breakpoints, stepping, `frame variable` with live struct
// fields. Godot's own debugger panel can never do this (it drives the GDScript VM; our
// procs are C-ABI function pointers to it). What the editor contributes here is the
// plumbing lldb needs and a user should never have to type: the editor's own executable
// path (THE Godot binary to debug), the project dir, and the addon's launcher script —
// build/debug_game.sh, which handles the macOS SIP re-sign + lldb quirks.
//
// lldb is interactive, so the session must live in a real terminal: macOS gets one via
// `osascript` telling Terminal.app (works for a Finder-launched editor too); Linux tries
// the common terminal emulators in order. Windows: core/debug_launch_windows.odin (no
// menu items — the raw-signal/SEH debugging story there is still open).
// ----------------------------------------------------------------------------

import "godot:gdext"
import "godot:godot"

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"

// Registered from export_plugin.odin pl_enter_tree (editor-level init only).
@(private)
debug_register_menu_items :: proc(plug: godot.Editor_Plugin) {
    dbg_name := godot.new_string_cstring("Debug Game (LLDB)")
    godot.editor_plugin_add_tool_menu_item(plug, dbg_name, make_menu_callable(debug_menu_call))
    cur_name := godot.new_string_cstring("Debug Game (Break at Cursor)")
    godot.editor_plugin_add_tool_menu_item(plug, cur_name, make_menu_callable(debug_cursor_menu_call))
    vs_name := godot.new_string_cstring("Generate VS Code Debug Config")
    godot.editor_plugin_add_tool_menu_item(plug, vs_name, make_menu_callable(vscode_menu_call))
}

// ---------------------------------------------------------------------------
// Shared path plumbing. Everything temp-allocated: menu calls are one-shot,
// main-thread, and the per-frame arena reset reclaims it.
// ---------------------------------------------------------------------------

@(private = "file")
editor_executable :: proc() -> string {
    return string_to_odin(godot.os_get_executable_path(godot.singleton_os()), context.temp_allocator)
}

@(private = "file")
project_dir :: proc() -> string {
    res := godot.new_string_cstring("res://")
    g := godot.project_settings_globalize_path(godot.singleton_project_settings(), res)
    dir := string_to_odin(g, context.temp_allocator)
    return strings.trim_suffix(dir, "/")
}

// The consumer launcher shipped with the addon. Missing == the addon predates it —
// say so instead of failing with a bash "No such file" in a flash-closed terminal.
@(private = "file")
launcher_path :: proc() -> (path: string, ok: bool) {
    root := odin_collection_root()
    defer delete(root)
    if root == "" {
        editor_msg_error("odin_godot: couldn't locate the addon — set the `odin_godot/root` project setting, then retry.")
        return "", false
    }
    path = fmt.tprintf("%s/build/debug_game.sh", root)
    if !os.exists(path) {
        editor_msg_error(
            fmt.tprintf(
                "odin_godot: %s not found — your addon predates the debugger launcher; " +
                "refresh addons/odin_godot from a current build.",
                path,
            ),
        )
        return "", false
    }
    return path, true
}

// ---------------------------------------------------------------------------
// Opening a terminal window running `bash -c <cmd>`.
// ---------------------------------------------------------------------------

// AppleScript string literal escaping (backslash + double quote).
@(private = "file")
applescript_escape :: proc(s: string) -> string {
    b := strings.builder_make(context.temp_allocator)
    for i in 0 ..< len(s) {
        if s[i] == '\\' || s[i] == '"' {
            strings.write_byte(&b, '\\')
        }
        strings.write_byte(&b, s[i])
    }
    return strings.to_string(b)
}

@(private = "file")
open_terminal :: proc(cmd: string) -> bool {
    when ODIN_OS == .Darwin {
        // `do script` opens a new Terminal window running cmd in the user's shell and
        // returns immediately; `activate` brings it in front of the editor. Two quoting
        // layers: cmd -> AppleScript string literal (applescript_escape), then the whole
        // AppleScript program -> shell word (shell_quote — cmd is full of single quotes
        // from its own shell_quote'ing, so the -e argument can NOT be '-quoted inline).
        program := fmt.tprintf(
            `tell application "Terminal" to do script "%s"`,
            applescript_escape(cmd),
        )
        script := fmt.tprintf(
            `osascript -e %s -e 'tell application "Terminal" to activate' >/dev/null 2>&1`,
            shell_quote(program, context.temp_allocator),
        )
        ccmd := strings.clone_to_cstring(script, context.temp_allocator)
        return libc.system(ccmd) == 0
    } else {
        // No standard "the" terminal on Linux — try the usual suspects in order. Each
        // takes a `bash -c <cmd>` payload; nohup+& detaches it from the editor process
        // (xterm -e otherwise blocks the editor main thread until the session ends).
        q := shell_quote(cmd, context.temp_allocator)
        candidates := [4]string{
            fmt.tprintf("x-terminal-emulator -e bash -c %s", q),
            fmt.tprintf("gnome-terminal -- bash -c %s", q),
            fmt.tprintf("konsole -e bash -c %s", q),
            fmt.tprintf("xterm -e bash -c %s", q),
        }
        names := [4]string{"x-terminal-emulator", "gnome-terminal", "konsole", "xterm"}
        for name, i in names {
            probe := strings.clone_to_cstring(
                fmt.tprintf("command -v %s >/dev/null 2>&1", name),
                context.temp_allocator,
            )
            if libc.system(probe) != 0 {continue}
            launch := strings.clone_to_cstring(
                fmt.tprintf("nohup %s >/dev/null 2>&1 &", candidates[i]),
                context.temp_allocator,
            )
            return libc.system(launch) == 0
        }
        editor_msg_error(
            "odin_godot: no terminal emulator found (tried x-terminal-emulator, gnome-terminal, " +
            "konsole, xterm) — run build/debug_game.sh from your own terminal instead.",
        )
        return false
    }
}

// Compose + launch `debug_game.sh` with an optional breakpoint spec.
@(private = "file")
launch_debug_session :: proc(break_spec: string) {
    launcher, ok := launcher_path()
    if !ok {return}
    exe := editor_executable()
    proj := project_dir()
    b := strings.builder_make(context.temp_allocator)
    fmt.sbprintf(
        &b,
        "bash %s --godot %s --run",
        shell_quote(launcher, context.temp_allocator),
        shell_quote(exe, context.temp_allocator),
    )
    if break_spec != "" {
        fmt.sbprintf(&b, " --break %s", shell_quote(break_spec, context.temp_allocator))
    }
    fmt.sbprintf(&b, " %s", shell_quote(proj, context.temp_allocator))
    if open_terminal(strings.to_string(b)) {
        msg := "odin_godot: lldb session opened in a terminal window."
        if break_spec != "" {
            msg = fmt.tprintf("odin_godot: lldb session opened — breakpoint at %s.", break_spec)
        }
        godot.print_str(msg)
    } else {
        editor_msg_error("odin_godot: couldn't open a terminal for the lldb session.")
    }
}

// ---------------------------------------------------------------------------
// Menu bodies.
// ---------------------------------------------------------------------------

@(private = "file")
debug_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    if err != nil {err.error = .Ok}
    launch_debug_session("")
}

// Caret position of the script editor's current buffer -> "file.odin:LINE".
// Returns "" (with a user-facing warning) when nothing usable is open.
@(private = "file")
cursor_break_spec :: proc() -> string {
    ei := godot.singleton_editor_interface()
    if ei == nil {return ""}
    se := godot.editor_interface_get_script_editor(ei)
    if se == nil {return ""}
    script := godot.script_editor_get_current_script(se)
    if script == nil {
        editor_msg_warn("odin_godot: no script open — open the .odin file and put the caret on the target line.")
        return ""
    }
    path := string_to_odin(godot.resource_get_path(cast(godot.Resource)script), context.temp_allocator)
    if !strings.has_suffix(path, ".odin") {
        editor_msg_warn(fmt.tprintf("odin_godot: current script is not Odin (%s) — lldb breakpoints only apply to .odin scripts.", path))
        return ""
    }
    current := godot.script_editor_get_current_editor(se)
    if current == nil {return ""}
    code_edit := godot.script_editor_base_get_base_editor(current)
    if code_edit == nil {return ""}
    line := godot.text_edit_get_caret_line(cast(godot.Text_Edit)code_edit, 0)
    base := path
    if idx := strings.last_index_byte(path, '/'); idx >= 0 {
        base = path[idx + 1:]
    }
    return fmt.tprintf("%s:%d", base, line + 1) // caret line is 0-based; DWARF lines are 1-based
}

@(private = "file")
debug_cursor_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    if err != nil {err.error = .Ok}
    spec := cursor_break_spec()
    if spec == "" {return} // warned inside
    launch_debug_session(spec)
}

// ---------------------------------------------------------------------------
// VS Code config generation.
// ---------------------------------------------------------------------------

// Where debug_game.sh puts the debuggable (get-task-allow re-signed) Godot copy.
// KEEP IN SYNC with godot_dbg() in build/debug_game.sh. Linux debugs the binary as-is.
@(private = "file")
debuggable_godot_path :: proc(exe: string) -> string {
    when ODIN_OS == .Darwin {
        tmp := os.get_env("TMPDIR", context.temp_allocator)
        if tmp == "" {tmp = "/tmp"}
        return fmt.tprintf("%s/odin-godot-lldb/Godot-dbg", strings.trim_suffix(tmp, "/"))
    } else {
        return exe
    }
}

@(private = "file")
write_if_absent :: proc(path: string, content: string) -> bool {
    if os.exists(path) {
        editor_msg_warn(fmt.tprintf("odin_godot: %s already exists — leaving it untouched.", path))
        return false
    }
    if werr := os.write_entire_file(path, transmute([]byte)content); werr != nil {
        editor_msg_error(fmt.tprintf("odin_godot: couldn't write %s.", path))
        return false
    }
    return true
}

@(private = "file")
vscode_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    if err != nil {err.error = .Ok}

    launcher, ok := launcher_path()
    if !ok {return}
    exe := editor_executable()
    proj := project_dir()

    // Prepare the debuggable copy NOW so launch.json's `program` exists before the
    // first F5; the preLaunchTask re-runs this to keep it fresh across Godot updates.
    prep := fmt.tprintf(
        "bash %s --prepare-only --godot %s >/dev/null 2>&1",
        shell_quote(launcher, context.temp_allocator),
        shell_quote(exe, context.temp_allocator),
    )
    _ = libc.system(strings.clone_to_cstring(prep, context.temp_allocator))

    vsdir := fmt.tprintf("%s/.vscode", proj)
    if !os.exists(vsdir) {
        if mkerr := os.make_directory(vsdir); mkerr != nil {
            editor_msg_error(fmt.tprintf("odin_godot: couldn't create %s.", vsdir))
            return
        }
    }

    // JSONC (VS Code accepts comments in these files). Odin's fmt supports `{}`-style
    // placeholders ALONGSIDE % verbs, so every literal JSON brace must be doubled —
    // a bare `{` prints `%!(MISSING CLOSE BRACE)` into the file (yes, verified).
    program := debuggable_godot_path(exe)
    launch := fmt.tprintf(
        `{{
    // Debug the Godot game with native Odin-script breakpoints (requires the CodeLLDB
    // extension, marketplace id "vadimcn.vscode-lldb"). Generated by odin_godot -
    // Project > Tools > Generate VS Code Debug Config. Set breakpoints directly in
    // your .odin files; the Variables pane shows script structs and args.
    "version": "0.2.0",
    "configurations": [
        {{
            "type": "lldb",
            "request": "launch",
            "name": "Debug Godot Game (Odin)",
            "program": "%s",
            "args": ["--path", "${{workspaceFolder}}"],
            "cwd": "${{workspaceFolder}}",
            "preLaunchTask": "odin_godot: prepare debuggable Godot"
        }}
    ]
}}
`,
        program,
    )
    tasks := fmt.tprintf(
        `{{
    // Refreshes the re-signed, debugger-attachable Godot copy that launch.json points
    // at (macOS SIP forbids attaching to the stock binary). Generated by odin_godot.
    "version": "2.0.0",
    "tasks": [
        {{
            "label": "odin_godot: prepare debuggable Godot",
            "type": "shell",
            "command": "bash '%s' --prepare-only --godot '%s'"
        }}
    ]
}}
`,
        launcher,
        exe,
    )

    wrote := 0
    if write_if_absent(fmt.tprintf("%s/launch.json", vsdir), launch) {wrote += 1}
    if write_if_absent(fmt.tprintf("%s/tasks.json", vsdir), tasks) {wrote += 1}
    if wrote > 0 {
        godot.print_str(
            fmt.tprintf(
                "odin_godot: wrote %d file(s) into %s — install the CodeLLDB extension, open the project in VS Code, set breakpoints in .odin files, F5.",
                wrote,
                vsdir,
            ),
        )
    }
}
