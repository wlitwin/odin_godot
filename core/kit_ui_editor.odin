#+build darwin, linux, windows
package core

import "godot:gdext"
import gd "godot:godot"
import "core:fmt"
import "core:os"

// The ordinary Tools menu creates editable scenes; no addon activation or
// external file-manager step is required. Existing work is never overwritten.
@(private)
kit_ui_templates_call :: proc "c" (
    _: rawptr,
    _: [^]gdext.VariantPtr,
    _: i64,
    _: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()

    if error != nil {
        error.error = .Ok
    }

    templates := [?]struct {
        name, data: string,
    } {
        {"lobby", #load("../kit/ui/templates/lobby.tscn")},
        {"chat", #load("../kit/ui/templates/chat.tscn")},
        {"scoreboard", #load("../kit/ui/templates/scoreboard.tscn")},
    }
    directory := gd.new_string_cstring("res://ui")
    defer gd.free_string(directory)
    absolute := gd.project_settings_globalize_path(gd.singleton_project_settings(), directory)
    defer gd.free_string(absolute)
    path := string_to_odin(absolute, context.temp_allocator)

    if !os.exists(path) {
        if err := os.make_directory_all(path); err != nil {
            editor_msg_error(fmt.tprintf("Kit UI: cannot create %s: %v", path, err))
            return
        }
    }

    for template in templates {
        filename := fmt.tprintf("%s/kit_%s.tscn", path, template.name)

        if os.exists(filename) {
            editor_msg_warn(fmt.tprintf("Kit UI: keeping existing res://ui/kit_%s.tscn.", template.name))
            continue
        }

        if err := os.write_entire_file(filename, transmute([]u8)template.data); err != nil {
            editor_msg_error(fmt.tprintf("Kit UI: cannot write %s: %v", filename, err))
            return
        }
    }

    rescan_editor_filesystem()
    gd.print_str(
        "Kit UI scenes are in res://ui. Open a scene and select Bindings to assign controls; use the scenes in kboot.Options.",
    )
}
