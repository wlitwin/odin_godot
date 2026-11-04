package main
import "core:fmt"
import corpus "../corpus"

main :: proc() {
    result := corpus.run()
    assert(result.ok)
    fmt.printf("%d %d %d\n", result.fingerprint, result.hash, result.frames)
}
