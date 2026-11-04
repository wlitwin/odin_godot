package world_v2_caller_test

// PURE caller arithmetic/receipt fixtures only. Boundary values and receipt
// metadata below do not execute or impersonate a real Lane/World/Native.
import "core:encoding/json"
import "core:os"
import "core:reflect"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import recorded "godot:tests/box3d_soak/kit/caller_capacity_retention"

DT :: f64(1.0 / 60)

bits :: proc(x: f64) -> u64 {
    return transmute(u64)x
}

boundary :: proc(scale: f64, acc: f64 = 0) -> app.Caller_Boundary {
    return {
        available = true,
        ready = true,
        head = 10,
        confirmed = 9,
        epoch = 1,
        received_sequence = 3,
        dt = DT,
        scale = scale,
        acc = acc,
        status = .Ok,
    }
}

balanced :: proc(t: ^testing.T, a: app.Caller_Account, scale: f64) {
    testing.expect(t, a.valid && app.caller_account_valid(a, DT, scale))
    testing.expect(t, a.pending >= 0 && a.unresolved >= 0 && a.pending + a.unresolved <= 8 * DT && a.excluded >= 0)
}

@(test)
ordinary_scaled_caller_fractional_zero_and_exact_offer_ownership :: proc(t: ^testing.T) {
    scales := [3]f64{.98, 1, 1.02}

    for scale in scales {
        testing.expect(t, app.caller_domain(DT, scale))
        a := app.caller_credit_offer({}, DT / 2, DT, scale, 8, 130, true, false, 0)
        before := boundary(scale)
        after := before
        after.acc = a.offered * scale
        receipt, q := app.caller_credit_receipt(before, after, 0, a.offered)
        testing.expect(t, receipt == .OwnedAll)
        fractional := app.caller_credit_settle(a, receipt, q, DT, scale, 130, true, before.acc)
        balanced(t, fractional, scale)
        testing.expect(
            t,
            bits(fractional.lane_owned) == bits(a.offered) &&
            bits(fractional.scaled_receipt) == bits(q) &&
            a.offered <= 2 * DT,
        )
        zero := app.caller_credit_offer({}, 0, DT, scale, 8, 130, true, false, 0)
        receipt, q = app.caller_credit_receipt(before, before, 0, zero.offered)
        testing.expect(t, receipt == .No_Offer)
        no_offer := app.caller_credit_settle(zero, receipt, q, DT, scale, 130, true, 0)
        balanced(t, no_offer, scale)
        testing.expect(t, no_offer.lane_owned == 0)
        before = boundary(scale, DT / 4)
        a = app.caller_credit_offer({}, 2 * DT, DT, scale, 2, 130, true, false, before.acc)
        after = before
        after.head += 1
        after.acc = before.acc + a.offered * scale - DT
        after.status = .Step_Failed
        receipt, q = app.caller_credit_receipt(before, after, 1, a.offered)
        testing.expect(t, receipt == .OwnedAll)
        partial := app.caller_credit_settle(a, receipt, q, DT, scale, 130, true, before.acc)
        balanced(t, partial, scale)
        testing.expect(t, bits(partial.lane_owned) == bits(a.offered) && before.acc + a.offered * scale <= 2 * DT)
    }

    // The Host still follows the unchanged unscaled planner, without client credit.
    host := app.caller_delta_plan(DT / 2, 0, 0, 0, false)
    testing.expect(t, bits(host.offered_delta) == bits(DT / 2) && host.unforwarded_delta == 0)
}

@(test)
first_failure_and_uncertified_changes_retain_or_quarantine :: proc(t: ^testing.T) {
    scales := [3]f64{.98, 1, 1.02}

    for scale in scales {
        before := boundary(scale, DT / 2)
        a := app.caller_credit_offer({}, 2 * DT, DT, scale, 2, 130, true, false, before.acc)
        after := before
        after.status = .Step_Failed
        receipt, q := app.caller_credit_receipt(before, after, 0, a.offered)
        testing.expect(t, receipt == .NotOwned)
        failed := app.caller_credit_settle(a, receipt, q, DT, scale, 130, true, before.acc)
        balanced(t, failed, scale)
        testing.expect(t, failed.lane_owned == 0 && bits(failed.pending) == bits(a.pending + a.offered))

        for variant in 0 ..< 3 {
            after = before

            switch variant {
            case 0:
                after.scale = scale == 1.02 ? .98 : 1.02
            case 1:
                after.epoch += 1
            case 2:
                after.received_sequence += 1
            }

            receipt, q = app.caller_credit_receipt(before, after, 0, a.offered)
            testing.expect(t, receipt == .Unresolved)
            unresolved := app.caller_credit_settle(a, receipt, q, DT, scale, 130, true, before.acc)
            balanced(t, unresolved, scale)
            testing.expect(t, unresolved.lane_owned == 0 && bits(unresolved.unresolved) == bits(a.offered))
            held := app.caller_credit_offer(
                {pending_seconds = unresolved.pending, unresolved_offer_seconds = unresolved.unresolved},
                DT / 2,
                DT,
                scale,
                8,
                130,
                true,
                false,
                before.acc,
            )
            testing.expect(
                t,
                held.valid &&
                held.disposition == .Hold &&
                held.offered == 0 &&
                bits(held.pending) == bits(unresolved.pending) &&
                bits(held.unresolved) == bits(unresolved.unresolved),
            )
        }
    }
}

@(test)
recorded_restoration_scaled_accumulator_end_budget_and_fresh_guard :: proc(t: ^testing.T) {
    recorded.recorded_owned_current_capacity_should_remain_pending(t)
    scales := [3]f64{.98, 1, 1.02}

    for scale in scales {
        acc := DT / 4
        a := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, scale, 3, 130, true, false, acc)
        q := a.offered * scale
        settled := app.caller_credit_settle(a, .OwnedAll, q, DT, scale, 130, true, acc)
        balanced(t, settled, scale)
        testing.expect(
            t,
            settled.pending >= a.pending &&
            settled.excluded <= a.excluded &&
            bits(settled.lane_owned) == bits(a.offered),
        )
        testing.expect(
            t,
            bits(settled.capacity_excluded) == bits(a.capacity_excluded) &&
            bits(settled.end_excluded) == bits(a.end_excluded),
        )
        again := app.caller_credit_settle(settled, .OwnedAll, q, DT, scale, 130, true, acc)
        testing.expect(t, reflect.equal(again, settled))
        end_offer := app.caller_credit_offer({pending_seconds = 8 * DT}, DT / 2, DT, scale, 3, 2, true, false, acc)
        end_result := app.caller_credit_settle(
            end_offer,
            .OwnedAll,
            end_offer.offered * scale,
            DT,
            scale,
            2,
            true,
            acc,
        )
        balanced(t, end_result, scale)
        testing.expect(
            t,
            end_result.pending == 0 &&
            bits(end_result.end_excluded) == bits(end_offer.end_excluded) &&
            end_result.excluded >= end_result.end_excluded,
        )
        eligible := app.caller_eligible_delta(DT, 11, 10, DT, scale, acc)
        testing.expect(t, bits(eligible) == bits((DT - acc) / scale))
    }
}

@(test)
finite_scaled_properties_and_invalid_input_store_preservation :: proc(t: ^testing.T) {
    scales := [3]f64{.98, 1, 1.02}
    pendings := [3]f64{0, DT / 2, 8 * DT}
    eligibles := [3]f64{0, DT / 2, 2 * DT}
    rooms := [3]u64{0, 1, 8}
    accs := [2]f64{0, DT / 2}
    ends := [4]u64{0, 0, 1, 130}
    cases := 0

    for scale in scales {
        for pending in pendings {
            for eligible in eligibles {
                for room in rooms {
                    for acc in accs {
                        for end, index in ends {
                            limited := index != 0
                            a := app.caller_credit_offer(
                                {pending_seconds = pending},
                                eligible,
                                DT,
                                scale,
                                room,
                                end,
                                limited,
                                false,
                                acc,
                            )
                            receipt := a.offered > 0 ? app.Caller_Receipt.OwnedAll : app.Caller_Receipt.No_Offer
                            q := a.offered * scale
                            result := app.caller_credit_settle(a, receipt, q, DT, scale, end, limited, acc)
                            balanced(t, result, scale)
                            testing.expect(
                                t,
                                a.offered <= 2 * DT &&
                                result.pending >= a.pending &&
                                result.excluded >= result.end_excluded &&
                                bits(result.lane_owned) == bits(a.offered),
                            )
                            testing.expect(
                                t,
                                bits(result.capacity_excluded) == bits(a.capacity_excluded) &&
                                bits(result.end_excluded) == bits(a.end_excluded),
                            )
                            repeated := app.caller_credit_settle(result, receipt, q, DT, scale, end, limited, acc)
                            testing.expect(t, reflect.equal(repeated, result))
                            cases += 1
                        }
                    }
                }
            }
        }
    }

    testing.expect(t, cases == 648)
    nan := transmute(f64)u64(0x7ff8000000000000)
    inf := transmute(f64)u64(0x7ff0000000000000)
    bad := [5]f64{0, .979, 1.021, nan, inf}

    for scale in bad {
        testing.expect(t, !app.caller_domain(DT, scale))
        a := app.caller_credit_offer({}, DT, DT, scale, 3, 130, true, false, 0)
        testing.expect(t, !a.valid)
        // Only a synthetic metadata container for the existing pure store helper.
        holder: app.Runtime
        holder.caller_credit = {
            pending_seconds          = DT,
            unresolved_offer_seconds = DT / 2,
        }
        prior := holder.caller_credit
        app.caller_store(&holder, a)
        testing.expect(t, reflect.equal(holder.caller_credit, prior) && holder.caller_account.disposition == .Invalid)
    }

    testing.expect(
        t,
        app.caller_eligible_delta(nan, 0, 0, DT, 1, 0) < 0 &&
        app.caller_eligible_delta(DT, 0, 0, DT, 1, -DT) < 0 &&
        !app.caller_domain(DT / 2, 1),
    )
    bytes, error := json.marshal(struct {
            scope: string,
            cases: int,
        }{"PURE Worldv2 caller metadata/properties; no Lane/World/Native execution", cases})
    testing.expect(t, error == nil)

    if error == nil {
        defer delete(bytes)
        testing.expect(t, os.write_entire_file("world-v2-caller-properties.json", bytes) == nil)
    }
}
