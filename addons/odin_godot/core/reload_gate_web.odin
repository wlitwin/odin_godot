#+build wasm32, wasm64p32
package core

import "base:runtime"

// One supported engine thread, no hot reload. Retain a real protected-call depth
// and callback temporary lifetime; do not replace owner EXECUTE checks by no-ops.
@(private)
web_script_access_depth: u32
@(private)
web_outer_temp: runtime.Arena_Temp

@(private)
script_access_enter :: proc "contextless" () {
    if !box3d_web_on_thread() {
        return
    }

    if web_script_access_depth == max(u32) {
        runtime.trap()
    }

    if web_script_access_depth == 0 {
        web_temp_ensure()
        context = runtime.default_context()
        web_outer_temp = runtime.arena_temp_begin(&web_temp_arena)
    }

    web_script_access_depth += 1
}

@(private)
script_access_leave :: proc "contextless" () {
    if !box3d_web_on_thread() {
        return
    }

    if web_script_access_depth == 0 {
        runtime.trap()
    }

    web_script_access_depth -= 1

    if web_script_access_depth == 0 {
        context = runtime.default_context()
        runtime.arena_temp_end(web_outer_temp)
        web_outer_temp = {}
    }
}

@(private)
script_reload_can_begin :: proc "contextless" () -> bool {
    return true
}

@(private)
script_reload_begin :: proc "contextless" () {}

@(private)
script_reload_end :: proc "contextless" () {}
