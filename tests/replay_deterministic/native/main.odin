package main
import "core:fmt"
import corpus "../../../examples/replay_duel/shared/corpus"

main :: proc() {
    seeds := [4]u64{0, 1, 42, 0x12345678}

    for seed in seeds {
        result := corpus.run(seed, 2400)
        assert(result.ok)
        fmt.printf(
            "%d %d %d %d %d %d\n",
            seed,
            result.hash,
            result.shots,
            result.hits,
            result.kills[0],
            result.kills[1],
        )
    }
}
