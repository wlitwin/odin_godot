package replay_quickdraw

import "core:strings"
import "core:strconv"
import gd "godot:godot"

quickdraw_param :: proc(key: cstring, fallback: string = "") -> string {
    name := string(key)
    query := strings.to_lower(name[len("RQ_"):], context.temp_allocator)
    return gd.launch_param(key, query, fallback)
}

quickdraw_int :: proc(key: cstring, fallback: int) -> int {
    text := quickdraw_param(key, "")

    if text == "" {
        return fallback
    }

    value, ok := strconv.parse_int(text)
    return ok ? value : -1
}
