package block_corpus

import "core:reflect"
import current "godot:replay/schema"
import previous "../reference"

Mode :: enum u8 {
    Zero  = 0,
    Other = 7,
}

Required :: enum u16 {
    First = 2,
    Last  = 9,
}

Secret :: struct {
    flag:   bool,
    number: f32,
}

Data :: struct {
    counter:  u64,
    floats:   [64]f32,
    byte:     u8,
    aligned:  u64,
    secret:   Secret `replay:"authority"`,
    flags:    [64]bool,
    modes:    [64]Mode,
    required: Required,
    be:       u32be,
}

verify :: proc() -> u32 {
    for public in 0 ..< 2 {
        a: current.Schema
        b: previous.Schema
        ao := current.DEFAULT_OPTIONS
        bo := previous.DEFAULT_OPTIONS

        if public == 1 {
            ao.projection = .Public
            bo.projection = .Public
        }

        if current.init(&a, Data, ao).error != .None || previous.init(&b, Data, bo).error != .None {
            return 1
        }

        defer current.destroy(&a)
        defer previous.destroy(&b)

        if a.fingerprint != b.fingerprint || a.wire_size != b.wire_size {
            return 2
        }

        // The optimization may only inspect bytes already covered by a direct copy.
        grouped := 0

        for block in a.validation_blocks {
            if block.count > 1 {
                contained := false

                for span in a.spans {
                    if !span.reverse &&
                       block.offset >= span.offset &&
                       block.offset + block.size <= span.offset + span.size &&
                       block.wire_offset - span.wire_offset == block.offset - span.offset {
                        contained = true
                        break
                    }
                }

                if !contained {
                    return 3
                }

                grouped += 1
            }
        }

        if grouped == 0 {
            return 4
        }

        left := make([]u8, a.wire_size)
        defer delete(left)
        right := make([]u8, b.wire_size)
        defer delete(right)

        for mode in 0 ..< 4 {
            value: Data
            raw := (cast([^]u8)&value)[:size_of(Data)]

            for &byte in raw {
                byte = 0xa5
            } // padding stays poisoned after declared fields are assigned

            value.counter = 0
            value.byte = 0
            value.aligned = 0
            value.secret = {}
            value.required = .First
            value.be = u32be(0x11223344)

            for &f, i in value.floats {
                f = mode == 1 || mode == 2 && i % 7 == 0 ? f32(i + 1) : 0
            }

            for &v, i in value.flags {
                v = mode == 1 || mode == 2 && i % 7 == 0
            }

            for &v, i in value.modes {
                v = mode == 1 || mode == 2 && i % 7 == 0 ? .Other : .Zero
            }

            if mode == 3 {
                value.required = Required(0)
            } // zero must not bypass a nonzero-only enum

            if public == 1 {
                value.secret.number = transmute(f32)u32(0x7fc00000)
            }

            for &byte in left {
                byte = 0x55
            }

            copy(right, left)
            ra := current.encode(&a, value, left)
            rb := previous.encode(&b, value, right)

            if int(ra.error) != int(rb.error) || ra.path != rb.path || !reflect.equal(left, right, true) {
                return 5
            }

            if mode == 3 {
                if ra.error != .Invalid_Value {
                    return 6
                }

                continue
            }

            if ra.error != .None {
                return 7
            }

            for index in 0 ..< len(left) {
                saved := left[index]
                left[index] ~= 0x81
                da := value
                db := value
                ca := current.decode(&a, &da, left)
                cb := previous.decode(&b, &db, left)

                if int(ca.error) != int(cb.error) || ca.path != cb.path || !same(da, db) {
                    return 8
                }

                if ca.error != .None && !same(da, value) {
                    return 9
                }

                left[index] = saved
            }

            // Mutate constrained native storage too: every byte, including padding and
            // excluded secret storage, must match the old first-error and output behavior.
            for index in 0 ..< len(raw) {
                saved := raw[index]
                raw[index] ~= 0x81

                for &byte in left {
                    byte = 0x55
                }

                copy(right, left)
                ca := current.encode(&a, value, left)
                cb := previous.encode(&b, value, right)

                if int(ca.error) != int(cb.error) || ca.path != cb.path || !reflect.equal(left, right, true) {
                    return 10
                }

                raw[index] = saved
            }
        }
    }

    return 0
}

// Float equality here is bit equality, including NaN in an excluded field.
same :: proc(a, b: Data) -> bool {
    left, right := a, b

    for f, i in a.floats {
        if transmute(u32)f != transmute(u32)b.floats[i] {
            return false
        }

        left.floats[i], right.floats[i] = 0, 0
    }

    if transmute(u32)a.secret.number != transmute(u32)b.secret.number {
        return false
    }

    left.secret.number, right.secret.number = 0, 0
    return reflect.equal(left, right, true)
}
