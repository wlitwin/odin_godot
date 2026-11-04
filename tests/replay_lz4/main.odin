package main
import "core:fmt"
import "core:c"
import ref "vendor:compress/lz4"
import corpus "shared"

main :: proc() {
    code, hash := corpus.verify()
    assert(code == 0, fmt.tprintf("corpus %d", code))
    fmt.printf("LZ4_CORPUS_OK cases=768 hash=%d\n", hash)
    code = corpus.verify_reference(proc(src, dst: []u8) -> int {
        return int(ref.compress_default(raw_data(src), raw_data(dst), c.int(len(src)), c.int(len(dst))))
    }, proc(src, dst: []u8) -> int {
        return int(ref.decompress_safe(raw_data(src), raw_data(dst), c.int(len(src)), c.int(len(dst))))
    })
    assert(code == 0, fmt.tprintf("reference %d", code))
    fmt.printf("LZ4_REFERENCE_OK version=%d cases=768\n", ref.versionNumber())
}
