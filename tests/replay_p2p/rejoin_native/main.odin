package main
import "core:fmt"
import c "../rejoin_corpus"

main :: proc() {
    for seed in u64(1) ..= 4 {
        fmt.printf("P2P_REJOIN_CASE seed=%d hash=%d\n", seed, c.verify_case(seed))
    }
}
