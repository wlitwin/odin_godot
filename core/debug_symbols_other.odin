#+build darwin, windows
package core

script_debug_symbols_register :: proc(gen: ^Script_Generation) {}

script_debug_symbols_retire :: proc(gen: ^Script_Generation) {}

debug_symbols_self_register :: proc() {}

when ODIN_OS == .Darwin {
    debug_symbol_read_begin :: proc "contextless" () {}

    debug_symbol_read_end :: proc "contextless" () {}

    debug_symbol_lookup :: proc "contextless" (address: rawptr, info: ^Dl_info) -> (cstring, uintptr) {
        return nil, 0
    }
}
