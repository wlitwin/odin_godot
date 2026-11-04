package main
import "core:fmt"
import corpus "shared"

main :: proc() {
    code, hash, cases := corpus.verify()
    assert(code == 0, fmt.tprintf("shuffle corpus %d", code))
    fmt.printf("SHUFFLE_CORPUS_OK cases=%d hash=%d\n", cases, hash)
}
