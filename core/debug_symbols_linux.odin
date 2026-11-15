package core

import symbols "debug_symbols"

// Load local ELF names while file I/O and allocation are permitted. Lookups
// during debug capture or a fatal signal only borrow this preloaded metadata.
script_debug_symbols_register :: proc(gen: ^Script_Generation) {
    if gen == nil || gen.dll.odin_scripts_boot == nil {
        return
    }

    info: Dl_info

    if dladdr(cast(rawptr)gen.dll.odin_scripts_boot, &info) != 0 && info.dli_fname != nil {
        gen.debug_symbols = symbols.register(string(info.dli_fname), uintptr(info.dli_fbase), core_allocator())
    }
}

script_debug_symbols_retire :: proc(gen: ^Script_Generation) {
    if gen == nil {
        return
    }

    symbols.retire(cast(^symbols.Registration)gen.debug_symbols)
    gen.debug_symbols = nil
}

debug_symbols_self_register :: proc() {
    @(static) registered: bool

    if registered {
        return
    }

    registered = true
    info: Dl_info

    if dladdr(cast(rawptr)debug_symbols_self_register, &info) != 0 && info.dli_fname != nil {
        _ = symbols.register(string(info.dli_fname), uintptr(info.dli_fbase), core_allocator())
    }
}

debug_symbol_read_begin :: proc "contextless" () {
    symbols.read_begin()
}

debug_symbol_read_end :: proc "contextless" () {
    symbols.read_end()
}

debug_symbol_lookup :: proc "contextless" (address: rawptr, info: ^Dl_info) -> (cstring, uintptr) {
    if info == nil {
        return nil, 0
    }

    return symbols.cached_lookup(uintptr(address), uintptr(info.dli_fbase))
}
