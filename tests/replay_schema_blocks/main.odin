package main
import "core:fmt"
import c "shared"

main :: proc() {
    code := c.verify()
    fmt.printf("SCHEMA_BLOCK_CORPUS result=%d\n", code)
    assert(code == 0)
}
