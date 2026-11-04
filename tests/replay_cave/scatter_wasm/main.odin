package scatter_wasm
import "base:runtime"
import cave "../../../examples/replay_cavecrawl/shared/cave"
last: cave.Scatter

@(export)
run :: proc "c" (seed: u32, depth: u32) -> u32 {
    context = runtime.default_context()
    last = cave.scatter(seed, u8(depth))
    return last.checksum
}

@(export)
coordinate :: proc "c" (index: u32) -> u32 {
    return index < 20 ? (index % 2 == 0 ? u32(last.items[index / 2].x) : u32(last.items[index / 2].y)) : 0
}
