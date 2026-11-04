package caller_capacity_retention_test

// Seven additional PURE groups. Boundaries/receipts are synthetic metadata,
// never a live Lane/Kernel/Native claim. No Runtime create/frame/destroy calls.
import "core:encoding/json"
import "core:os"
import "core:reflect"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"

bits :: proc(x: f64) -> u64 {
    return transmute(u64)x
}

boundary :: proc(acc: f64 = 0) -> app.Caller_Boundary {
    return {
        available = true,
        ready = true,
        head = 10,
        confirmed = 10,
        epoch = 1,
        received_sequence = 3,
        dt = DT,
        scale = 1,
        acc = acc,
        status = .Ok,
    }
}

balanced :: proc(t: ^testing.T, a: app.Caller_Account) {
    testing.expect(t, a.valid && app.caller_account_valid(a, DT, 1))
    testing.expect(t, a.pending >= 0 && a.unresolved >= 0 && a.pending + a.unresolved <= 8 * DT && a.excluded >= 0)
}

recorded_offer :: proc() -> app.Caller_Account {
    return app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, 1, 3, 130, true, false)
}

@(test)
other_receipts_no_offer_and_unresolved_preserve_prior_behavior :: proc(t: ^testing.T) {
    a := recorded_offer()
    retained := app.caller_credit_settle(a, .NotOwned, 0, DT, 1)
    balanced(t, retained)
    testing.expect(
        t,
        bits(retained.pending) == bits(a.pending + a.offered) &&
        retained.lane_owned == 0 &&
        bits(retained.excluded) == bits(a.excluded),
    )
    unresolved := app.caller_credit_settle(a, .Unresolved, 0, DT, 1)
    balanced(t, unresolved)
    testing.expect(
        t,
        bits(unresolved.pending) == bits(a.pending) &&
        bits(unresolved.unresolved) == bits(a.offered) &&
        unresolved.lane_owned == 0 &&
        bits(unresolved.excluded) == bits(a.excluded),
    )
    no_offer := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, 1, 0, 130, true, false)
    zero := app.caller_credit_settle(no_offer, .No_Offer, 0, DT, 1)
    balanced(t, zero)
    testing.expect(
        t,
        no_offer.offered == 0 &&
        bits(zero.pending) == bits(no_offer.pending) &&
        bits(zero.excluded) == bits(no_offer.excluded),
    )
    held := app.caller_credit_offer(
        {pending_seconds = DT, unresolved_offer_seconds = DT},
        DT / 2,
        DT,
        1,
        3,
        130,
        true,
        false,
    )
    unchanged := app.caller_credit_settle(held, .OwnedAll, 0, DT, 1)
    balanced(t, unchanged)
    testing.expect(
        t,
        held.offered == 0 &&
        unchanged.unresolved == DT &&
        bits(unchanged.pending) == bits(held.pending) &&
        bits(unchanged.excluded) == bits(held.excluded),
    )
    // Unsupported zero-offer OwnedAll metadata must not acquire capacity credit.
    deferred := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, 1, 0, 6, true, true)
    forced_zero := app.caller_credit_settle(deferred, .OwnedAll, 0, DT, 1)
    balanced(t, forced_zero)
    testing.expect(
        t,
        deferred.offered == 0 &&
        bits(forced_zero.pending) == bits(deferred.pending) &&
        bits(forced_zero.excluded) == bits(deferred.excluded),
    )
}

@(test)
fractional_zero_and_partial_success_debit_exact_offer :: proc(t: ^testing.T) {
    a := app.caller_credit_offer({}, DT / 2, DT, 1, 8, 130, true, false)
    before := boundary()
    after := before
    after.acc = a.offered
    receipt, q := app.caller_credit_receipt(before, after, 0, a.offered)
    testing.expect(t, receipt == .OwnedAll)
    fractional := app.caller_credit_settle(a, receipt, q, DT, 1)
    balanced(t, fractional)
    testing.expect(t, bits(fractional.lane_owned) == bits(a.offered) && bits(fractional.scaled_receipt) == bits(q))
    none := app.caller_credit_offer({}, 0, DT, 1, 8, 130, true, false)
    receipt, q = app.caller_credit_receipt(before, before, 0, none.offered)
    testing.expect(t, receipt == .No_Offer)
    zero := app.caller_credit_settle(none, receipt, q, DT, 1)
    balanced(t, zero)
    testing.expect(t, zero.lane_owned == 0)
    a = recorded_offer()
    before = boundary(DT / 2)
    after = before
    after.head += 1
    after.acc = before.acc + a.offered - DT
    after.status = .Step_Failed
    receipt, q = app.caller_credit_receipt(before, after, 1, a.offered)
    testing.expect(t, receipt == .OwnedAll)
    partial := app.caller_credit_settle(a, receipt, q, DT, 1, 130, true)
    balanced(t, partial)
    testing.expect(
        t,
        bits(partial.lane_owned) == bits(a.offered) && partial.pending <= 8 * DT && partial.unresolved == 0,
    )
    after = before
    after.status = .Step_Failed
    receipt, q = app.caller_credit_receipt(before, after, 0, a.offered)
    testing.expect(t, receipt == .NotOwned)
    first_failed := app.caller_credit_settle(a, receipt, q, DT, 1, 130, true)
    balanced(t, first_failed)
    testing.expect(t, first_failed.lane_owned == 0 && bits(first_failed.excluded) == bits(a.excluded))
}

@(test)
captured_end_budget_limits_restoration_without_shrinking_existing_pending :: proc(t: ^testing.T) {
    a := recorded_offer()
    at_end := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 8, true)
    balanced(t, at_end)
    testing.expect(t, bits(at_end.pending) == bits(a.pending) && bits(at_end.excluded) == bits(a.excluded))
    below_existing := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 1, true)
    balanced(t, below_existing)
    testing.expect(
        t,
        bits(below_existing.pending) == bits(a.pending) && bits(below_existing.excluded) == bits(a.excluded),
    )
    enough := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 9, true)
    balanced(t, enough)
    testing.expect(
        t,
        enough.pending == 6.5 * DT && enough.excluded == 0 && enough.pending + enough.lane_owned <= 9 * DT,
    )
    short := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, 1, 3, 1, true, false)
    short_settled := app.caller_credit_settle(short, .OwnedAll, short.offered, DT, 1, 1, true)
    balanced(t, short_settled)
    testing.expect(
        t,
        short.end_excluded > 0 &&
        short_settled.pending == 0 &&
        bits(short_settled.end_excluded) == bits(short.end_excluded) &&
        bits(short_settled.excluded) == bits(short.excluded),
    )
}

@(test)
raw_end_and_previously_settled_exclusions_are_not_new_credit :: proc(t: ^testing.T) {
    a := recorded_offer()
    a.raw_excess = 2 * DT
    settled := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 130, true)
    balanced(t, settled)
    testing.expect(
        t,
        settled.pending == 6.5 * DT && bits(settled.raw_excess) == bits(a.raw_excess) && settled.pending < 8 * DT,
    )
    testing.expect(
        t,
        bits(settled.capacity_excluded) == bits(a.capacity_excluded) &&
        bits(settled.end_excluded) == bits(a.end_excluded),
    )
    blocked := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 8, true)
    balanced(t, blocked)
    testing.expect(t, blocked.excluded > 0)
    later := app.caller_credit_settle(blocked, .OwnedAll, blocked.offered, DT, 1)
    balanced(t, later)
    testing.expect(t, reflect.equal(later, blocked))
    end_clipped := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, 1, 3, 1, true, false)
    end_result := app.caller_credit_settle(end_clipped, .OwnedAll, end_clipped.offered, DT, 1, 1, true)
    balanced(t, end_result)
    testing.expect(
        t,
        end_result.excluded >= end_clipped.end_excluded &&
        bits(end_result.end_excluded) == bits(end_clipped.end_excluded),
    )
}

@(test)
fresh_offer_guard_keeps_ULP_three_quarters_repetition_idempotent :: proc(t: ^testing.T) {
    cap := 8 * DT
    upper := transmute(f64)(bits(cap) + 1)
    ulp := upper - cap
    eligible := 3 * ulp / 4
    a := app.caller_credit_offer({pending_seconds = cap}, eligible, DT, 1, 3, 130, true, false)
    testing.expect(t, a.valid && a.lane_owned == 0 && a.offered > 0 && a.capacity_excluded > eligible)
    once := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 130, true)
    balanced(t, once)
    testing.expect(
        t,
        once.lane_owned > 0 && once.excluded > 0 && bits(once.capacity_excluded) == bits(a.capacity_excluded),
    )
    twice := app.caller_credit_settle(once, .OwnedAll, once.offered, DT, 1, 130, true)
    balanced(t, twice)
    testing.expect(t, reflect.equal(twice, once))
    regular := recorded_offer()
    fresh := app.caller_credit_settle(regular, .OwnedAll, regular.offered, DT, 1, 130, true)
    balanced(t, fresh)
    testing.expect(t, fresh.pending > regular.pending && fresh.excluded < regular.excluded)
    bytes, error := json.marshal(struct {
        scope:                                                                                          string,
        cap, ulp, eligible, offer_capacity, once_pending, once_excluded, twice_pending, twice_excluded: u64,
    } {
        "PURE ULP fixture, actual imported helpers, not live ownership",
        bits(cap),
        bits(ulp),
        bits(eligible),
        bits(a.capacity_excluded),
        bits(once.pending),
        bits(once.excluded),
        bits(twice.pending),
        bits(twice.excluded),
    })
    testing.expect(t, error == nil)

    if error == nil {
        defer delete(bytes)
        testing.expect(t, os.write_entire_file("retention-ulp.json", bytes) == nil)
    }
}

@(test)
adjacent_cap_domain_invalid_and_store_preserve_existing_credit :: proc(t: ^testing.T) {
    cap := 8 * DT
    pending_values := [3]f64{transmute(f64)(bits(cap) - 1), cap, transmute(f64)(bits(cap) + 1)}

    for pending in pending_values {
        a := app.caller_credit_offer({pending_seconds = pending}, DT / 2, DT, 1, 3, 130, true, false)
        settled := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, 1, 130, true)

        if pending <= cap {
            balanced(t, settled)
            testing.expect(t, settled.pending <= cap)
        } else {
            testing.expect(t, !a.valid && !settled.valid)
        }
    }

    nan := transmute(f64)u64(0x7ff8000000000000)
    inf := transmute(f64)u64(0x7ff0000000000000)
    scales := [5]f64{0, .98, 1.02, nan, inf}

    for scale in scales {
        a := app.caller_credit_offer({}, DT, DT, scale, 3, 130, true, false)
        settled := app.caller_credit_settle(a, .OwnedAll, a.offered, DT, scale, 130, true)
        testing.expect(t, !a.valid && !settled.valid)
        // Synthetic Runtime POD solely as caller_store's metadata container.
        // No Runtime create/frame/destroy, Node, SDK, World or Lane is executed.
        container: app.Runtime
        container.caller_credit = {
            pending_seconds          = DT,
            unresolved_offer_seconds = DT / 2,
        }
        prior := container.caller_credit
        app.caller_store(&container, settled)
        testing.expect(
            t,
            reflect.equal(container.caller_credit, prior) && container.caller_account.disposition == .Invalid,
        )
    }

    wrong_dt := app.caller_credit_offer({}, DT, DT / 2, 1, 3, 130, true, false)
    testing.expect(
        t,
        !wrong_dt.valid && !app.caller_credit_settle(wrong_dt, .OwnedAll, wrong_dt.offered, DT / 2, 1).valid,
    )
}

@(test)
finite_actual_helper_property_matrix_conserves_and_stays_strictly_bounded :: proc(t: ^testing.T) {
    pendings := [4]f64{0, DT / 2, 6 * DT, 8 * DT}
    eligibles := [4]f64{0, DT / 2, DT, 2 * DT}
    rooms := [4]u64{0, 1, 3, 8}
    ends := [5]u64{0, 0, 1, 8, 130}
    cases := 0

    for pending in pendings {
        for eligible in eligibles {
            for room in rooms {
                for end_ticks, index in ends {
                    end_limited := index != 0
                    a := app.caller_credit_offer(
                        {pending_seconds = pending},
                        eligible,
                        DT,
                        1,
                        room,
                        end_ticks,
                        end_limited,
                        false,
                    )
                    receipt := a.offered > 0 ? app.Caller_Receipt.OwnedAll : app.Caller_Receipt.No_Offer
                    result := app.caller_credit_settle(a, receipt, a.offered, DT, 1, end_ticks, end_limited)
                    balanced(t, result)
                    testing.expect(
                        t,
                        result.pending >= a.pending &&
                        result.excluded >= result.end_excluded &&
                        result.excluded <= a.excluded,
                    )
                    testing.expect(
                        t,
                        bits(result.capacity_excluded) == bits(a.capacity_excluded) &&
                        bits(result.end_excluded) == bits(a.end_excluded) &&
                        bits(result.raw_excess) == bits(a.raw_excess),
                    )
                    testing.expect(t, bits(result.lane_owned) == bits(a.offered) && result.unresolved == 0)
                    again := app.caller_credit_settle(result, receipt, a.offered, DT, 1, end_ticks, end_limited)
                    testing.expect(t, reflect.equal(again, result))
                    cases += 1
                }
            }
        }
    }

    testing.expect(t, cases == 320)
    bytes, error := json.marshal(struct {
        scope: string,
        cases: int,
    }{"PURE finite actual-helper properties; no live receipt/Kernel/Native proof", cases})
    testing.expect(t, error == nil)

    if error == nil {
        defer delete(bytes)
        testing.expect(t, os.write_entire_file("retention-properties.json", bytes) == nil)
    }
}
