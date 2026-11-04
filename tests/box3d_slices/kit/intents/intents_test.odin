package kit_intent_tests

// Input-device metadata fixtures only: no native world or accepted runtime
// history is created or injected. Actual packet/publication proof is separate.
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import sim "godot:kit/sim"

fixture :: proc(rt:^app.Runtime,world:^sim.World_History,head,baseline,target:u64) {
 world.epoch=1;rt.lane.world=world;rt.lane.ticker.tick=head
 rt.role=.Client;rt.scripted=true;rt.seat=2;rt.target=target;rt.baseline=baseline
}

@(test)
prefetch_never_emits_early_and_abort_keeps_same_attempt :: proc(t:^testing.T) {
 rt:app.Runtime;world:sim.World_History;fixture(&rt,&world,32,0,240)
 app.intent_prepare(&rt)
 testing.expect(t,rt.intents.armed)
 for tick in 33..<40 {testing.expect(t,app.intent_sample(&rt,u64(tick)).kind==.None)}
 testing.expect(t,!rt.intents.plans[0].attempted)
 rt.lane.ticker.tick=39
 testing.expect(t,app.intent_sample(&rt,40).kind==.Spawn)
 testing.expect(t,!rt.intents.plans[0].published && !rt.intents.plans[0].transported)
 testing.expect(t,app.intent_sample(&rt,40).kind==.Spawn) // failed candidate retries same tick
 testing.expect(t,app.intent_sample(&rt,41).kind==.None) // never repeats on a new tick
 testing.expect_value(t,rt.intents.plans[0].attempt_tick,u64(40))
}

@(test)
two_unsampled_reset_links_keep_original_due :: proc(t:^testing.T) {
 rt:app.Runtime;world:sim.World_History;fixture(&rt,&world,32,0,240)
 app.intent_prepare(&rt)
 app.intent_rebase(&rt,39,58,4,8)
 testing.expect_value(t,rt.intents.plans[0].original,u64(40))
 testing.expect_value(t,rt.intents.plans[0].due,u64(59))
 app.intent_rebase(&rt,58,87,8,12)
 testing.expect_value(t,rt.intents.plans[0].original,u64(40))
 testing.expect_value(t,rt.intents.plans[0].due,u64(88))
 testing.expect_value(t,rt.intents.plans[0].recovery_serial,u64(12))
 testing.expect(t,!rt.failed)
}

@(test)
published_sample_without_packet_is_not_retargeted :: proc(t:^testing.T) {
 rt:app.Runtime;world:sim.World_History;fixture(&rt,&world,32,0,240)
 app.intent_prepare(&rt)
 rt.intents.plans[0].attempted=true;rt.intents.plans[0].attempt_tick=40
 rt.intents.plans[0].published=true // publication independently proven, packet not proven
 app.intent_rebase(&rt,40,58,4,8)
 testing.expect(t,rt.failed)
 testing.expect_value(t,rt.intents.plans[0].due,u64(40))
 testing.expect_value(t,rt.intents.plans[0].attempt_tick,u64(40))
}

@(test)
no_tick_after_end_is_explicit_failure :: proc(t:^testing.T) {
 rt:app.Runtime;world:sim.World_History;fixture(&rt,&world,32,0,87)
 app.intent_prepare(&rt)
 app.intent_rebase(&rt,39,87,4,8)
 testing.expect(t,rt.failed)
 testing.expect_value(t,rt.intents.plans[0].due,u64(88))
}

@(test)
fresh_source_catalog_does_not_recreate_retired_scenario_inputs :: proc(t:^testing.T) {
 rt:app.Runtime;world:sim.World_History;fixture(&rt,&world,104,104,360)
 app.intent_prepare(&rt)
 testing.expect_value(t,rt.intents.plans[0].original,u64(280))
 testing.expect_value(t,rt.intents.plans[5].original,u64(160))
 testing.expect(t,!rt.intents.armed)
}
