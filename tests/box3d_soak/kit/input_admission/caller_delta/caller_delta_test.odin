package caller_delta_test

// Actual helper import; fixed finite-input expectations describe the FROZEN
// original arithmetic. No copied executable clamp, Lane, clock or runtime.
import "core:encoding/json"
import "core:os"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import legacy "godot:tests/box3d_slices/kit/intents"

Vector :: struct {
    name:            string,
    delta:           f64,
    target:          u64,
    eligible:        f64,
    offered_by_room: [9]f64,
}

vectors :: [?]Vector {
    {"zero", 0, 0, 0, {0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {
        "fraction",
        1.0 / 120,
        0,
        1.0 / 120,
        {0, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120},
    },
    {
        "one_tick",
        1.0 / 60,
        0,
        1.0 / 60,
        {0, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60},
    },
    {
        "two_tick",
        2.0 / 60,
        0,
        2.0 / 60,
        {0, 1.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60},
    },
    {
        "above_old_cap",
        1,
        0,
        2.0 / 60,
        {0, 1.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60, 2.0 / 60},
    },
    {
        "one_remaining",
        1,
        17,
        1.0 / 60,
        {0, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60, 1.0 / 60},
    },
    {"at_end", 1, 16, 0, {0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {"past_end", 1, 15, 0, {0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {
        "target_fraction",
        1.0 / 120,
        17,
        1.0 / 120,
        {0, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120},
    },
}

write_json :: proc(name: string, value: $T) {
    bytes, e := json.marshal(value)
    assert(e == nil)
    defer delete(bytes)
    assert(os.write_entire_file(name, bytes) == nil)
}

bits :: proc(value: f64) -> u64 {
    return transmute(u64)value
}

@(test)
actual_helper_matches_frozen_original_finite_arithmetic :: proc(t: ^testing.T) {
    cases := 0
    all_match := true

    for vector in vectors {
        for room in 0 ..= 8 {
            confirmed := u64(8 + room)
            client := app.caller_delta_plan(vector.delta, vector.target, 16, confirmed, true)
            host := app.caller_delta_plan(vector.delta, vector.target, 16, confirmed, false)
            client_ok :=
                bits(client.eligible_delta) == bits(vector.eligible) &&
                bits(client.offered_delta) == bits(vector.offered_by_room[room]) &&
                bits(client.unforwarded_delta) == bits(vector.eligible - vector.offered_by_room[room])
            expected_disposition :=
                vector.offered_by_room[room] < vector.eligible ? app.Caller_Delta_Disposition.Unaccounted : app.Caller_Delta_Disposition.Forwarded
            client_ok = client_ok && client.disposition == expected_disposition
            host_ok :=
                bits(host.eligible_delta) == bits(vector.eligible) &&
                bits(host.offered_delta) == bits(vector.eligible) &&
                host.unforwarded_delta == 0 &&
                host.disposition == .Forwarded
            testing.expect(t, client_ok, vector.name)
            testing.expect(t, host_ok, vector.name)
            all_match = all_match && client_ok && host_ok
            cases += 2
        }
    }

    // Still finite/nonnegative and head>=confirmed: depth beyond8 saturates room0.
    saturated := app.caller_delta_plan(1.0 / 60, 0, 16, 0, true)
    testing.expect(
        t,
        saturated.offered_delta == 0 &&
        saturated.unforwarded_delta == 1.0 / 60 &&
        saturated.disposition == .Unaccounted,
    )
    all_match = all_match && saturated.offered_delta == 0 && saturated.unforwarded_delta == 1.0 / 60
    cases += 1
    write_json("differential.json", struct {
        scope:     string,
        cases:     int,
        all_match: bool,
    }{"pure_actualhelper_finite_nonnegative_head_ge_confirmed_bitexact_noNative_or_Runtimeproof", cases, all_match})
}

// Existing metadata-only controls invoked once, unchanged. No world/history.
@(test)
legacy_prefetch_abort :: proc(t: ^testing.T) {
    legacy.prefetch_never_emits_early_and_abort_keeps_same_attempt(t)
}

@(test)
legacy_reset_links :: proc(t: ^testing.T) {
    legacy.two_unsampled_reset_links_keep_original_due(t)
}

@(test)
legacy_published_identity :: proc(t: ^testing.T) {
    legacy.published_sample_without_packet_is_not_retargeted(t)
}

@(test)
legacy_end_failure :: proc(t: ^testing.T) {
    legacy.no_tick_after_end_is_explicit_failure(t)
}

@(test)
legacy_fresh_catalog :: proc(t: ^testing.T) {
    legacy.fresh_source_catalog_does_not_recreate_retired_scenario_inputs(t)
}
