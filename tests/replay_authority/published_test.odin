package replay_authority_test

import "core:testing"
import auth "godot:replay/authority"

@(test)
published_recovery_keeps_dedicated_infrastructure_and_final_release_requirements :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger, .Dedicated)
    before := ledger.record
    testing.expect_value(t, auth.coordinator_recover_published(&c, B, 1, 2, point(), 1000), auth.Error.Denied)
    testing.expect_value(t, ledger.record, before)
    testing.expect_value(t, auth.coordinator_recover_published(&c, C, 1, 2, point(), 1000), auth.Error.None)
    testing.expect(t, ledger.record.owner == C && ledger.record.epoch == 2 && ledger.record.recovered == point())
    c = {}
    ledger = {}
    setup(&c, &ledger)
    prepare(&c)
    testing.expect_value(
        t,
        auth.coordinator_release(&c, A, {A, 44, 1, c.record.revision}, point(), 0),
        auth.Error.None,
    )
    before = ledger.record
    testing.expect_value(t, auth.coordinator_recover_published(&c, C, 1, 2, point(9), 1000), auth.Error.No_Checkpoint)
    testing.expect_value(t, ledger.record, before)
    testing.expect_value(t, auth.coordinator_recover_published(&c, C, 1, 2, point(), 1000), auth.Error.None)
}
