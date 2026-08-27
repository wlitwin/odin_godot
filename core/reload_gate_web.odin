#+build wasm32, wasm64p32
package core

// Browser builds are single-threaded and do not support hot reload/dlopen. Keep the
// shared callback sites source-identical while compiling their ownership gate to zero
// work; using the native condition-variable path in a single-threaded wasm runtime can
// trap when it attempts to wait.

@(private)
script_access_enter :: proc "contextless" () {}

@(private)
script_access_leave :: proc "contextless" () {}

@(private)
script_reload_can_begin :: proc "contextless" () -> bool {return true}

@(private)
script_reload_begin :: proc "contextless" () {}

@(private)
script_reload_end :: proc "contextless" () {}
