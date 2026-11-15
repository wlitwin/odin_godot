#+build windows, darwin
package api_docs_fixture

// Value state with a generic payload.
State :: struct($T: typeid) {
    // The current value.
    value: T,
    count: int, // Current item count.
    dirty: bool, // Whether the value changed.
}

Kind :: enum u8 {
    // Normal execution.
    Normal = 7,
    Replay, // Rebuilt from history.
}

// A multiline call whose body must stay out of the reference.
advance :: proc(
    state: ^State($T),
    count: int = 3,
) -> (value: T, ok: bool) where size_of(T) > 0 {
    SECRET_BODY_MARKER := 123
    return state.value, SECRET_BODY_MARKER > 0
}

when ODIN_OS == .Windows {
    platform_open :: proc(value: u32) -> bool { return value != 0 }
} else {
    platform_open :: proc(value: u64) -> bool { return value != 0 }
}

choose :: proc{choose_u32, choose_u64}
choose_u32 :: proc(value: u32) -> u32 { return value }
@(private = "file")
choose_u64 :: proc(value: u64) -> u64 { return value }

@(private)
hidden :: proc() {}

State32 :: State(u32)
Callback :: proc(value: int) -> bool
MESSAGE :: `A literal with braces {{ value }} and <tags>.`
