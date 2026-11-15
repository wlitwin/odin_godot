package debug_symbols_test

import "core:fmt"
import "core:os"
import "core:testing"
import symbols "godot:core/debug_symbols"

put :: proc(data: []u8, offset: int, value: u64, size: int) {
    for i in 0 ..< size {
        data[offset + i] = u8(value >> uint(8 * i))
    }
}

fixture :: proc() -> []u8 {
    data := make([]u8, 8192)
    copy(data[:7], []u8{127, 'E', 'L', 'F', 2, 1, 1})
    put(data, 16, 3, 2)
    put(data, 18, 62, 2)
    put(data, 20, 1, 4)
    put(data, 32, 64, 8)
    put(data, 40, 128, 8)
    put(data, 52, 64, 2)
    put(data, 54, 56, 2)
    put(data, 56, 1, 2)
    put(data, 58, 64, 2)
    put(data, 60, 4, 2)
    // One executable load segment, beginning with the ELF header.
    put(data, 64, 1, 4)
    put(data, 68, 5, 4)
    put(data, 96, 8192, 8)
    put(data, 104, 8192, 8)
    // Section1: allocated executable code; section2: symbols; section3: strings.
    put(data, 192 + 4, 1, 4)
    put(data, 192 + 8, 6, 8)
    put(data, 192 + 16, 4096, 8)
    put(data, 192 + 24, 4096, 8)
    put(data, 192 + 32, 256, 8)
    put(data, 256 + 4, 2, 4)
    put(data, 256 + 24, 512, 8)
    put(data, 256 + 32, 48, 8)
    put(data, 256 + 40, 3, 4)
    put(data, 256 + 56, 24, 8)
    put(data, 320 + 4, 3, 4)
    put(data, 320 + 24, 640, 8)
    put(data, 320 + 32, 32, 8)
    put(data, 536, 1, 4)
    put(data, 540, 2, 1)
    put(data, 542, 1, 2)
    put(data, 544, 4096, 8)
    put(data, 552, 32, 8)
    copy(data[641:], "fixture::local")
    return data
}

@(test)
exact_function_ranges_and_load_bias :: proc(t: ^testing.T) {
    data := fixture()
    defer delete(data)
    image, ok := symbols.parse(data, 0x100000)
    testing.expect(t, ok)

    if !ok {
        return
    }

    defer symbols.destroy(&image)
    name, start := symbols.lookup(&image, 0x101008)
    testing.expect(t, string(name) == "fixture::local" && start == 0x101000)

    for address in ([?]uintptr{0x100fff, 0x101020, 0x101080}) {
        absent, _ := symbols.lookup(&image, address)
        testing.expect(t, absent == nil, "gaps and endpoints must not inherit a preceding name")
    }

    symbols.destroy(&image)
    put(data, 16, 2, 2) // ET_EXEC symbols already carry absolute virtual addresses.
    image, ok = symbols.parse(data, 0x100000)
    testing.expect(t, ok)

    if ok {
        name, start = symbols.lookup(&image, 0x1008)
        testing.expect(t, string(name) == "fixture::local" && start == 0x1000)
    }
}

@(test)
malformed_stripped_and_unsized_symbols_do_not_guess :: proc(t: ^testing.T) {
    for variant in 0 ..< 11 {
        data := fixture()

        switch variant {
        case 0:
            put(data, 40, max(u64) - 4, 8)
        case 1:
            put(data, 256 + 4, 0, 4) // stripped .symtab
        case 2:
            put(data, 536, 32, 4) // name outside string table
        case 3:
            for i in 641 ..< 672 {
                data[i] = 'x'
            } // missing NUL
        case 4:
            put(data, 552, 0, 8) // unsized function
        case 5:
            put(data, 552, 512, 8) // outside executable section
        case 6:
            put(data, 192 + 8, 2, 8) // non-executable section
        case 7:
            put(data, 544, max(u64) - 4, 8) // overflowing virtual range
        case 8:
            put(data, 256 + 56, 0, 8) // invalid symbol stride
        case 9:
            put(data, 320 + 32, max(u64), 8) // overflowing string extent
        case 10:
            put(data, 256 + 40, 4, 4) // string section index out of range
        }

        image, ok := symbols.parse(data, 0x100000)
        testing.expect(t, !ok, fmt.tprintf("variant%d", variant))

        if ok {
            symbols.destroy(&image)
        }

        delete(data)
    }

    data := fixture()
    defer delete(data)

    for cut in ([?]int{0, 1, 63, 64, 119, 127, 383, 535, 559, 671, 4096, 8191}) {
        image, ok := symbols.parse(data[:cut], 0x100000)
        testing.expect(t, !ok, fmt.tprintf("truncated at%d", cut))

        if ok {
            symbols.destroy(&image)
        }
    }
}

@(test)
retirement_keeps_borrowed_names_until_read_exit :: proc(t: ^testing.T) {
    data := fixture()
    defer delete(data)
    path := fmt.aprintf("/tmp/odin-debug-symbol-fixture-%p.elf", raw_data(data))
    defer delete(path)
    testing.expect(t, os.write_entire_file(path, data) == nil)
    defer os.remove(path)
    registration := symbols.register(path, 0x200000)
    testing.expect(t, registration != nil)

    if registration == nil {
        return
    }

    symbols.read_begin()
    unknown, _ := symbols.cached_lookup(0x201008, 0x300000)
    testing.expect(t, unknown == nil, "an unrelated loaded image cannot inherit a cached name")
    name, start := symbols.cached_lookup(0x201008, 0x200000)
    testing.expect(t, string(name) == "fixture::local" && start == 0x201000)
    symbols.retire(registration)
    testing.expect(t, string(name) == "fixture::local")
    missing, _ := symbols.cached_lookup(0x201008, 0x200000)
    testing.expect(t, missing == nil)

    // Another image can occupy the same load base after loader release. Its
    // gaps must not resolve through the retired generation's old ranges.
    put(data, 544, 4160, 8)

    for i in 641 ..< 672 {
        data[i] = 0
    }

    copy(data[641:], "fixture::replacement")
    testing.expect(t, os.write_entire_file(path, data) == nil)
    replacement := symbols.register(path, 0x200000)
    testing.expect(t, replacement != nil)

    if replacement != nil {
        old_address, _ := symbols.cached_lookup(0x201008, 0x200000)
        new_name, new_start := symbols.cached_lookup(0x201048, 0x200000)
        testing.expect(t, old_address == nil, "a reused image base must not inherit retired function ranges")
        testing.expect(t, string(new_name) == "fixture::replacement" && new_start == 0x201040)
        testing.expect(t, string(name) == "fixture::local", "an existing reader retains its original borrowed name")
        symbols.retire(replacement)
    }

    symbols.read_end()
    symbols.retire(registration) // collect retired storage; repeated retirement is safe
}
