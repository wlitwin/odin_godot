package generic_containers

import gd "godot:godot"

// This deliberately differs from the caller's Local_Type.
Local_Type :: struct { axis: i64 }

Input :: struct($T: typeid, $N: int) {
    items: [N]T,
    native: Local_Type,
}

Envelope :: struct($T: typeid, $N: int) { body: Input(T, N) }

@(gd_input)
Numeric_Input :: struct($T: typeid, $N: int, $E: typeid) {
    move: [N]T `gd:"range=-1:1"`,
    flags: u16 `gd:"mask=0x03"`,
    mode: E `gd:"enum"`,
}

Block :: struct($T: typeid) {
    data: T `gd:"replicate"`,
    cache: ^T,
    views: []T,
    values: [dynamic]T `gd:"backup"`,
    lookup: map[u32]T `gd:"backup"`,
    changed: proc(value: T),
}
Wrap :: struct($T: typeid) { state: Block(T) }

Signals :: struct($T: typeid) { changed: gd.Signal1(T) `gd:"args=value"` }

@(gd_input)
Vector_Input :: struct($T: typeid) { move: T `gd:"unit"` }

Event_Queue :: struct($T: typeid) { events: [dynamic]T }
