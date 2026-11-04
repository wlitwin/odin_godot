package main
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import sc "godot:replay/schema"
import net "godot:replay/net"
import delta "godot:replay/delta"
import game "sample:game"

Meta :: struct {
    baseline_id, target_id, baseline_hash, schema: string,
    bytes:                                         int,
}

main :: proc() {
    assert(len(os.args) == 4)
    a, ea := os.read_entire_file(os.args[1], context.allocator)
    assert(ea == nil)
    defer delete(a)
    b, eb := os.read_entire_file(os.args[2], context.allocator)
    assert(eb == nil)
    defer delete(b)
    metadata, em := os.read_entire_file(os.args[3], context.allocator)
    assert(em == nil)
    defer delete(metadata)
    meta: Meta
    assert(json.unmarshal(metadata, &meta) == nil)
    client := new(net.Client(game.World, game.Control, game.Action, game.Event, game.SEATS))
    defer free(client)
    left, right := client.pending, client.pending
    schema: sc.Schema
    options := sc.DEFAULT_OPTIONS
    options.projection = .Public
    assert(sc.init(&schema, type_of(left), options).error == .None)
    defer sc.destroy(&schema)
    fingerprint, parsed := strconv.parse_u64(meta.schema)
    assert(parsed && fingerprint == schema.fingerprint)
    assert(len(a) == meta.bytes && len(a) == len(b) && len(a) == schema.wire_size)
    baseline_hash, hash_ok := strconv.parse_u64(meta.baseline_hash)
    assert(hash_ok && sc.digest(a) == baseline_hash)
    assert(sc.decode(&schema, &left, a).error == .None && sc.decode(&schema, &right, b).error == .None)
    baseline_id, id_ok := strconv.parse_u64(meta.baseline_id)
    target_id, target_ok := strconv.parse_u64(meta.target_id)
    assert(id_ok && target_ok && left.snapshot_id == baseline_id && right.snapshot_id == target_id)
    model := game.model()
    assert(model.state_valid(left.frame.state) && model.state_valid(right.frame.state))
    assert(left.generation == right.generation && left.serial == right.serial && right.frame.tick >= left.frame.tick)
    diffs := make([]sc.Difference, len(schema.fields))
    defer delete(diffs)
    report := sc.diff_encoded(&schema, a, b, diffs)
    assert(report.report.error == .None && report.count == report.total)
    changed := 0

    for value, i in a {
        if value != b[i] {
            changed += 1
        }
    }

    out := make([]u8, delta.LZ4_MAX_OUTPUT)
    defer delete(out)
    restored := make([]u8, len(a))
    defer delete(restored)
    work := new(delta.Lz4_Workspace)
    defer free(work)
    scratch := make([]u8, 2 * len(a))
    defer delete(scratch)
    size, kind, valid := delta.encode_smallest(a, b, out, work)
    assert(valid)

    if kind == .Lz4 {
        assert(delta.lz4_xor_apply(a, out[:size], restored))
    } else {
        assert(delta.apply(a, out[:size], restored))
    }

    assert(mem.compare(b, restored) == 0)
    grouped, ok := delta.shuffle_lz4_encode(&schema, a, b, out, work, scratch)
    assert(ok)
    assert(delta.shuffle_lz4_apply(&schema, a, out[:grouped], restored, scratch) && mem.compare(b, restored) == 0)
    fmt.printf(
        "SNAPSHOT_PAIR_VALID base=%d target=%d bytes=%d changed=%d fields=%d plain=%d grouped=%d kind=%v\n",
        left.frame.tick,
        right.frame.tick,
        len(a),
        changed,
        report.total,
        size,
        grouped,
        kind,
    )
    fmt.println("path,kind,width,changed_bytes")

    for d in diffs[:report.count] {
        field := schema.fields[d.field]
        count := 0

        for i in field.wire_offset ..< field.wire_offset + field.width {
            if a[i] != b[i] {
                count += 1
            }
        }

        fmt.printf("%s,%v,%d,%d\n", d.path, d.kind, d.width, count)
    }

    for &v, i in scratch[:len(a)] {
        v = a[i] ~ b[i]
    }

    assert(os.write_entire_file(fmt.tprintf("%s.xor", os.args[2]), scratch[:len(a)]) == nil)
    assert(sc.shuffle(&schema, scratch[:len(a)], scratch[len(a):]))
    assert(os.write_entire_file(fmt.tprintf("%s.grouped-xor", os.args[2]), scratch[len(a):]) == nil)
}
