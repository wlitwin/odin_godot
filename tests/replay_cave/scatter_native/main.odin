package main
import "core:fmt"
import cave "../../../examples/replay_cavecrawl/shared/cave"

main :: proc() {
    seeds := [4]u32{1, 1337, 123456, max(u32)}

    for seed in seeds {
        for depth in u8(1) ..= 2 {
            data := cave.scatter(seed, depth)
            fmt.printf("%d %d %d", seed, depth, data.checksum)

            for item in data.items {
                fmt.printf(" %d %d", item.x, item.y)
            }

            fmt.println()
        }
    }
}
