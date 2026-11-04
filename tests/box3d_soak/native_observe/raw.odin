package native_observe_test

import "core:fmt"
import bg "godot:box3d/godot"

// Caller owns this transient diagnostic buffer through SDK Meter. Encoding
// occurs only AFTER the public apply method has returned through real Core.
RAW_JSON_BYTES :: 1024 * 512 + 4096

raw_write :: proc(owner: ^Owner, out: []u8) -> (string, bg.Status) {
    if status := check(owner, bg.READ); status != bg.OK {
        return "", status
    }

    return raw_block_write(owner.block, out)
}

@(private)
raw_block_write :: proc(block: ^Block, out: []u8) -> (string, bg.Status) {
    if block.count > 1024 {
        return "", bg.CORRUPT
    }

    if len(out) < 4096 {
        return "", bg.CAPACITY
    }

    header := fmt.bprintf(
        out,
        "{{\"abi_version\":%d,\"struct_bytes\":%d,\"mode\":%d,\"capacity\":%d,\"count\":%d,\"stack_depth\":%d,\"error_flags\":%d,\"state\":%d,\"scope_token\":%d,\"domain_cookie\":%d,\"next_span_id\":%d,\"root_count\":%d,\"clock_reads\":%d,\"clock_errors\":%d,\"overflow_count\":%d,\"nesting_errors\":%d,\"last_clock_us\":%d,\"phase_mask\":%d,\"stack\":[",
        block.version,
        block.struct_bytes,
        block.mode,
        block.capacity,
        block.count,
        block.stack_depth,
        block.error_flags,
        block.state,
        block.token,
        block.cookie,
        block.next_span_id,
        block.root_count,
        block.clock_reads,
        block.clock_errors,
        block.overflow_count,
        block.nesting_errors,
        block.last_clock_us,
        block.phase_mask,
    )
    at := len(header)

    for value, index in block.stack {
        if len(out) - at < 64 {
            return "", bg.CAPACITY
        }

        text := fmt.bprintf(out[at:], "%s%d", index == 0 ? "" : ",", value)
        at += len(text)
    }

    if len(out) - at < 32 {
        return "", bg.CAPACITY
    }

    text := fmt.bprintf(out[at:], "],\"spans\":[")
    at += len(text)

    for span, index in block.spans[:block.count] {
        if len(out) - at < 1024 {
            return "", bg.CAPACITY
        }

        row := fmt.bprintf(
            out[at:],
            "%s{{\"id\":%d,\"parent_id\":%d,\"root_ordinal\":%d,\"phase\":%d,\"native_status\":%d,\"start_us\":%d,\"end_us\":%d}}",
            index == 0 ? "" : ",",
            span.id,
            span.parent_id,
            span.root_ordinal,
            span.phase,
            span.status,
            span.start_us,
            span.end_us,
        )
        at += len(row)
    }

    if len(out) - at < 2 {
        return "", bg.CAPACITY
    }

    out[at] = ']'
    out[at + 1] = '}'
    at += 2
    return string(out[:at]), bg.OK
}

PHASE_NAMES :: [13]string {
    "",
    "native.step.fixed",
    "native.snapshot.capture",
    "native.snapshot.serialize",
    "native.snapshot.normalize",
    "native.snapshot.finalize",
    "native.snapshot.validate",
    "native.admission.world",
    "native.recovery.read",
    "native.recovery.parse_validate",
    "native.recovery.build",
    "native.recovery.verify_reencode",
    "native.recovery.write",
}

phases_write :: proc(owner: ^Owner, out: []u8) -> (string, bg.Status) {
    if status := check(owner, bg.READ); status != bg.OK {
        return "", status
    }

    return phases_block_write(owner.block, out)
}

@(private)
phases_block_write :: proc(block: ^Block, out: []u8) -> (string, bg.Status) {
    names := PHASE_NAMES

    if block.count > 1024 || len(out) < 2 {
        return "", bg.CAPACITY
    }

    if block.error_flags != 0 ||
       block.clock_errors != 0 ||
       block.overflow_count != 0 ||
       block.nesting_errors != 0 ||
       block.stack_depth != 0 {
        return "[]", bg.OK
    }

    out[0] = '['
    at := 1

    for span, index in block.spans[:block.count] {
        if span.phase == 0 ||
           span.phase >= len(PHASE_NAMES) ||
           span.end_us < span.start_us ||
           span.end_us - span.start_us > max(u64) / 1000 {
            return "", bg.CORRUPT
        }

        if len(out) - at < 2048 {
            return "", bg.CAPACITY
        }

        row := fmt.bprintf(
            out[at:],
            "%s{{\"name\":\"%s\",\"duration_ns\":%d,\"clock_domain\":\"godot_ticks_usec\",\"start_us\":%d,\"end_us\":%d,\"relation\":\"native_nested_in_whole\",\"native_span_id\":%d,\"native_parent_id\":%d,\"native_root_ordinal\":%d,\"native_phase\":%d,\"native_status\":%d}}",
            index == 0 ? "" : ",",
            names[span.phase],
            (span.end_us - span.start_us) * 1000,
            span.start_us,
            span.end_us,
            span.id,
            span.parent_id,
            span.root_ordinal,
            span.phase,
            span.status,
        )
        at += len(row)
    }

    out[at] = ']'
    at += 1
    return string(out[:at]), bg.OK
}

// Synthetic SERIALIZER control, never submitted to Native and never a timing
// sample. The same raw/derived code must retain values outside float/int64.
precision_write :: proc(owner: ^Owner, out: []u8) -> (string, bg.Status) {
    if status := check(owner, bg.READ); status != bg.OK {
        return "", status
    }

    block, error := new(Block, owner.allocator)

    if error != nil || block == nil {
        return "", bg.OUT_OF_MEMORY
    }

    defer free(block, owner.allocator)
    block.version = 1
    block.struct_bytes = 49392
    block.mode = 2
    block.capacity = 1024
    block.count = 1
    block.state = 2
    block.token = max(u64)
    block.cookie = max(u64)
    block.next_span_id = 2
    block.root_count = 1
    block.clock_reads = 2
    block.phase_mask = 4095
    block.spans[0] = {1, 0, 1, 9007199254740993, 9007199254740994, 2, 0}
    block.last_clock_us = 9007199254740994

    if len(out) < 4096 {
        return "", bg.CAPACITY
    }

    prefix := fmt.bprintf(out, "{{\"synthetic_not_timing_sample\":true,\"native_raw\":")
    at := len(prefix)
    raw, status := raw_block_write(block, out[at:])

    if status != bg.OK {
        return "", status
    }

    at += len(raw)
    separator := fmt.bprintf(out[at:], ",\"native_phases\":")
    at += len(separator)
    phases, ps := phases_block_write(block, out[at:])

    if ps != bg.OK {
        return "", ps
    }

    at += len(phases)
    out[at] = '}'
    at += 1
    return string(out[:at]), bg.OK
}
