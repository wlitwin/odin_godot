package scrapyard_game
import "core:testing"
import "core:mem"
import "core:fmt"
import r "godot:replay"
import sc "godot:replay/schema"

mask_before :: proc(w: World) -> u8 {
    return(
        u8(before_state_valid(w)) |
        u8(before_combat_valid(w)) << 1 |
        u8(before_abilities_valid(w)) << 2 |
        u8(before_run_valid(w)) << 3 |
        u8(before_ordnance_valid(w)) << 4 |
        u8(before_effects_valid(w)) << 5 \
    )
}

mask_after :: proc(w: ^World) -> u8 {
    return(
        u8(state_valid_borrowed(w)) |
        u8(combat_valid_borrowed(w)) << 1 |
        u8(abilities_valid_borrowed(w)) << 2 |
        u8(run_valid_borrowed(w)) << 3 |
        u8(ordnance_valid_borrowed(w)) << 4 |
        u8(effects_valid_borrowed(w)) << 5 \
    )
}

@(test)
borrowed_validation_matches_original_for_every_scalar_field :: proc(t: ^testing.T) {
    world := initial(encounter_count = 0)
    world.stage = .Yard
    world.players[0].connected, world.players[0].in_yard = true, true
    world.players[0].position = {320, 1040}

    for i in 0 ..< 40 {
        assert(spawn_mob(&world, 0, {f32(700 + (i % 8) * 50), f32(180 + (i / 8) * 50)}))
    }

    events: [128]r.Occurrence(Event)

    for tick in 1 ..= 48 {
        ctx := r.Step(Event) {
            tick   = u64(tick),
            epoch  = 1,
            events = events[:],
        }
        step(&world, [SEATS]Control{}, 0, 0, &ctx)
        assert(ctx.error == .None)
    }

    assert(state_valid(world))
    codec: sc.Schema
    assert(sc.init(&codec, World).error == .None)
    defer sc.destroy(&codec)
    saved := make([]u8, size_of(World))
    defer delete(saved)
    cases := 0

    for field in codec.fields {
        for variant in 0 ..< 2 {
            value := world
            bytes := (cast([^]u8)&value)[:size_of(World)]
            bits := variant == 0 ? u64(0) : max(u64)

            if field.kind == .Boolean {
                bits = u64(variant)
            }

            if field.kind == .Enumeration {
                bits = u64(i64(field.enum_values[variant == 0 ? 0 : len(field.enum_values) - 1]))
            }

            if field.kind == .Float {
                bits = variant == 0 ? 0 : field.width == 4 ? 0x7fc00000 : 0x7ff8000000000000
            }

            for i in 0 ..< field.width {
                at := field.offset + (field.big_endian ? field.width - i - 1 : i)
                bytes[at] = u8(bits >> uint(i * 8))
            }

            copy(saved, bytes)
            expected := mask_before(value)
            actual := mask_after(&value)

            if expected != actual || mem.compare(saved, bytes) != 0 {
                testing.expect(
                    t,
                    false,
                    fmt.tprintf(
                        "validator mismatch or mutation at %s variant %d: %d/%d",
                        field.path,
                        variant,
                        expected,
                        actual,
                    ),
                )
                return
            }

            cases += 1
        }
    }

    fmt.printf(
        "BORROWED_VALIDATION_EQUIVALENT fields=%d cases=%d validators=6 unchanged=true\n",
        len(codec.fields),
        cases,
    )
}
