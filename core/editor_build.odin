#+build darwin, linux, windows
package core

import "godot:gdext"
import "core:sync"

// Editor addons use the same coordinator, compiler settings, diagnostics and
// reload path as Project > Tools > Build Odin Scripts. Never spawn another build.
editor_request_build :: proc "contextless" (_: ^OdinEditorPlugin) {
    context = gdext.godot_context()
    reload_request(force = true)
}

// Stable editor-only status: 0 idle, 1 building, 2 failed, 3 compiler missing.
editor_build_state :: proc "contextless" (_: ^OdinEditorPlugin) -> i64 {
    context = gdext.godot_context()
    sync.lock(&g_reload.mutex)
    defer sync.unlock(&g_reload.mutex)
    if g_reload.build_running || g_reload.build_pending || g_reload.swap_ready { return 1 }
    if g_reload.missing_compiler { return 3 }
    if g_reload.last_build_failed || len(g_reload.admission_failures) > 0 { return 2 }
    return 0
}
