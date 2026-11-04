package kit_fresh_intent_test

// These are explicitly metadata-only fixtures. They do not own or invent a
// network, accepted ledger, tick history, publication, or packet receipt.
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import common "godot:examples/box3d_common"
import legacy "godot:tests/box3d_slices/kit/intents"

metadata :: proc(rt:^app.Runtime,attempted:bool) {
 rt.scripted=true;rt.seat=2;rt.target=300
 rt.intents.initialized=true;rt.intents.armed=true
 rt.intents.plans[0]={original=40,due=40,attempted=attempted}
 if attempted {rt.intents.plans[0].attempt_tick=40;rt.intents.plans[0].attempt_head=39}
}

@(test)
aborted_published_or_transported_attempt_keeps_exact_identity :: proc(t:^testing.T) {
 for flags in 0..<4 {
  rt:app.Runtime;metadata(&rt,true)
  rt.intents.plans[0].published=flags&1!=0
  rt.intents.plans[0].transported=flags&2!=0
  before:=rt.intents.plans[0]
  testing.expect_value(t,app.intent_sample(&rt,40),common.Action{.Spawn})
  testing.expect_value(t,rt.intents.plans[0],before)
  testing.expect_value(t,app.intent_sample(&rt,41),common.Action{})
  testing.expect_value(t,rt.intents.plans[0],before)
  testing.expect(t,!rt.failed)
 }
}

@(test)
no_network_metadata_path_and_original_window_bound_unchanged :: proc(t:^testing.T) {
 ordinary:app.Runtime;metadata(&ordinary,false)
 testing.expect_value(t,app.intent_sample(&ordinary,40),common.Action{.Spawn})
 testing.expect(t,ordinary.intents.plans[0].attempt_tick==40 && !ordinary.failed)
 last:app.Runtime;metadata(&last,false)
 testing.expect_value(t,app.intent_sample(&last,48),common.Action{.Spawn})
 testing.expect(t,last.intents.plans[0].original==40 && last.intents.plans[0].due==40 && last.intents.plans[0].attempt_tick==48)
 expired:app.Runtime;metadata(&expired,false)
 testing.expect_value(t,app.intent_sample(&expired,49),common.Action{})
 testing.expect(t,expired.failed && !expired.intents.plans[0].attempted && expired.intents.plans[0].original==40 && expired.intents.plans[0].due==40)
}

// Invoke each existing pure test once, unchanged, in this coherent test build.
@(test) legacy_prefetch_abort :: proc(t:^testing.T) {legacy.prefetch_never_emits_early_and_abort_keeps_same_attempt(t)}
@(test) legacy_two_reset_links :: proc(t:^testing.T) {legacy.two_unsampled_reset_links_keep_original_due(t)}
@(test) legacy_published_without_packet :: proc(t:^testing.T) {legacy.published_sample_without_packet_is_not_retargeted(t)}
@(test) legacy_end_failure :: proc(t:^testing.T) {legacy.no_tick_after_end_is_explicit_failure(t)}
@(test) legacy_fresh_catalog :: proc(t:^testing.T) {legacy.fresh_source_catalog_does_not_recreate_retired_scenario_inputs(t)}
