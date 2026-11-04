package room_schema_metadata_test

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"
import sc "godot:replay/schema"
import auth "godot:replay/authority"
import p "godot:replay/provision"

Limited :: struct {
    track:         ^mem.Tracking_Allocator,
    source:        mem.Allocator,
    limit, denied: int,
}

limited_allocate :: proc(
    data: rawptr,
    mode: runtime.Allocator_Mode,
    size, alignment: int,
    old: rawptr,
    old_size: int,
    location: runtime.Source_Code_Location,
) -> (
    []u8,
    runtime.Allocator_Error,
) {
    f := cast(^Limited)data

    if size > 0 &&
       (mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed) &&
       len(f.track.allocation_map) >= f.limit {
        f.denied += 1
        return nil, .Out_Of_Memory
    }

    return f.source.procedure(f.source.data, mode, size, alignment, old, old_size, location)
}

@(test)
coexisting_real_room_storage_schemas_fit_4096_allocation_slots :: proc(t: ^testing.T) {
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    limited := Limited {
        track  = &tracker,
        source = mem.tracking_allocator(&tracker),
        limit  = 4096,
    }
    allocator := mem.Allocator {
        data      = &limited,
        procedure = limited_allocate,
    }
    schemas: [5]sc.Schema
    types := [5]typeid{auth.Record, p.Bundle, p.Enrollment_Record, auth.Request, auth.Reply}

    defer {
        for &schema in schemas {
            sc.destroy(&schema)
        }

        testing.expect_value(t, len(tracker.allocation_map), 0)
    }

    for T, i in types {
        report := sc.init(&schemas[i], T, allocator = allocator)
        testing.expect(
            t,
            report.error == .None,
            fmt.tprintf("actual type=%v error=%v live_allocations=%d", T, report.error, len(tracker.allocation_map)),
        )

        if report.error != .None {
            return
        }

        baseline: sc.Schema
        testing.expect_value(t, sc.init(&baseline, T).error, sc.Error.None)
        testing.expect_value(t, string(schemas[i].canonical[:]), string(baseline.canonical[:]))
        testing.expect_value(t, schemas[i].fingerprint, baseline.fingerprint)
        testing.expect_value(t, schemas[i].wire_size, baseline.wire_size)
        sc.destroy(&baseline)
    }

    testing.expect_value(t, limited.denied, 0)
    fmt.printf(
        "ROOM_SCHEMA_METADATA actual_live_allocations=%d bytes=%d limit=4096\n",
        len(tracker.allocation_map),
        tracker.current_memory_allocated,
    )
}
