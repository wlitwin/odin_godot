package main
import "core:os"
import "core:fmt"
import c "../corpus"

main :: proc() {
    assert(len(os.args) == 2)
    assert(c.verify() == 0)
    signature: [480]u8

    for &v, i in signature {
        v = u8(c.signature_byte(u32(i)))
    }

    trace := make([]u8, int(c.trace_size()))
    defer delete(trace)

    for &v, i in trace {
        v = u8(c.trace_byte(u32(i)))
    }

    path := fmt.aprintf("%s/signature.bin", os.args[1])
    defer delete(path)
    assert(os.write_entire_file(path, signature[:]) == nil)
    path2 := fmt.aprintf("%s/trace.bin", os.args[1])
    defer delete(path2)
    assert(os.write_entire_file(path2, trace) == nil)
    descriptor: [32]u8

    for &v, i in descriptor {
        v = u8(c.descriptor_byte(u32(i)))
    }

    path3 := fmt.aprintf("%s/descriptor.bin", os.args[1])
    defer delete(path3)
    assert(os.write_entire_file(path3, descriptor[:]) == nil)
    fmt.println("BOX3D_PROTOCOL_CORPUS_OK")
}
