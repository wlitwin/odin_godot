package lookup

import "core:strings"

// ----------------------------------------------------------------------------
// The PURE symbol -> (class, member) mapping for OdinLanguage._lookup_code (goto-definition).
// No Godot deps, so it is unit-tested headless (tests/lookup). The Godot-facing glue
// (ClassDB classification + building the LookupResult Dictionary) lives in core/lookup.odin.
// ----------------------------------------------------------------------------

// Map a clicked binding symbol to its (snake class, member). `class_set` is the authoritative set
// of snake class prefixes (the `godot/*.gen.odin` basenames). Strips a leading `gd.` qualifier,
// then takes the LONGEST snake class `P` such that `symbol == P` OR (`P` is a prefix of `symbol`
// AND the char right after `P` is `_`). The `_`-boundary check disambiguates `node` vs `node2d`
// for `node2d_set_position` (only `node2d` matches — the char after `node` is `2`).
//   - `symbol == P`     -> the class itself (is_class = true, member = "")
//   - otherwise         -> member = symbol[len(P)+1:]
//   - no class matches  -> ok = false (caller returns the graceful-miss shape)
// Returned `class_snake`/`member` are sub-slices of `symbol_in` (no allocation).
resolve_symbol :: proc(symbol_in: string, class_set: map[string]bool) -> (class_snake: string, member: string, is_class: bool, ok: bool) {
    symbol := symbol_in
    if strings.has_prefix(symbol, "gd.") {
        symbol = symbol[3:]
    }
    if symbol == "" {
        return "", "", false, false
    }
    best := ""
    for name in class_set {
        if len(name) <= len(best) {
            continue // can't beat the current longest match
        }
        if symbol == name {
            best = name
        } else if len(symbol) > len(name) && strings.has_prefix(symbol, name) && symbol[len(name)] == '_' {
            best = name
        }
    }
    if best == "" {
        return "", "", false, false
    }
    if symbol == best {
        return best, "", true, true
    }
    return best, symbol[len(best) + 1:], false, true
}
