package kit_netcfg_test

import "core:testing"
import kcfg "godot:kit/netcfg"
import ksess "godot:kit/session"

@(test)
named_profiles_are_complete_and_coherent :: proc(t: ^testing.T) {
	for profile in ([]kcfg.Network_Profile{
		kcfg.Network_Profile.Friends_Coop,
		kcfg.Network_Profile.Listen_Server_Action,
		kcfg.Network_Profile.Dedicated_Competitive,
	}) {
		cfg := kcfg.network_profile(profile)
		caps := kcfg.Network_Capabilities{
			has_lane = true,
			all_inputs_validated = true,
		}
		testing.expect_value(t, kcfg.network_config_check(cfg, caps), kcfg.Network_Config_Error.None)
		testing.expect_value(t, cfg.profile, profile)
		testing.expect(t, cfg.session.tick_hz > 0)
		testing.expect(t, cfg.session.traffic.reliable.packets_per_second > 0)
		testing.expect(t, cfg.session.traffic.reliable.bytes_per_second > 0)
		testing.expect(t, cfg.session.traffic.stream.packets_per_second > 0)
		testing.expect(t, cfg.session.traffic.stream.bytes_per_second > 0)
		testing.expect(t, cfg.session.traffic.actions.packets_per_second > 0)
		testing.expect(t, cfg.session.traffic.actions.bytes_per_second > 0)
		testing.expect(t, cfg.lane.slots > cfg.lane.lead_max)
		testing.expect(t, cfg.lane.slots > cfg.lane.rewind_max)
		envelope := kcfg.network_profile_envelope(profile)
		testing.expect(t, envelope.players >= cfg.session.max_players)
		testing.expect(t, envelope.replicated_entities >= envelope.active_entities_per_recipient)
		testing.expect_value(t, cfg.lane.snapshot_budget, envelope.snapshot_bytes_per_recipient)
	}
}

@(test)
profile_envelopes_publish_measured_scale_bounds :: proc(t: ^testing.T) {
	friends := kcfg.network_profile_envelope(.Friends_Coop)
	listen := kcfg.network_profile_envelope(.Listen_Server_Action)
	dedicated := kcfg.network_profile_envelope(.Dedicated_Competitive)
	testing.expect_value(t, friends.players, 8)
	testing.expect_value(t, friends.replicated_entities, 2000)
	testing.expect_value(t, listen.predicted_entities_per_client, 128)
	testing.expect_value(t, dedicated.predicted_entities_per_client, 512)
	testing.expect_value(t, dedicated.max_resim_ticks, 8)

	bad := kcfg.network_profile(.Listen_Server_Action)
	bad.lane.snapshot_budget = -1
	testing.expect_value(
		t,
		kcfg.network_config_check(bad, {has_lane = true, all_inputs_validated = true}),
		kcfg.Network_Config_Error.Lane_Snapshot_Budget,
	)
}

@(test)
zero_config_is_the_friends_profile :: proc(t: ^testing.T) {
	want := kcfg.network_profile(.Friends_Coop)
	got := kcfg.network_config_resolve({})
	testing.expect_value(t, got, want)
}

@(test)
ordinary_fields_are_explicit_overrides :: proc(t: ^testing.T) {
	cfg := kcfg.network_profile(.Listen_Server_Action)
	cfg.session.max_players = 4
	cfg.lane.rewind_max = 22
	cfg.lane.echo_inputs = true
	cfg.lane.tolerance = 0.5
	err := kcfg.network_config_check(cfg, {
		has_lane = true,
		all_inputs_validated = true,
	})
	testing.expect_value(t, err, kcfg.Network_Config_Error.None)
	testing.expect_value(t, cfg.session.max_players, 4)
	testing.expect_value(t, cfg.lane.rewind_max, 22)
}

@(test)
cross_field_and_trust_errors_are_typed :: proc(t: ^testing.T) {
	echo := kcfg.network_profile(.Listen_Server_Action)
	echo.lane.echo_inputs = true
	testing.expect_value(
		t,
		kcfg.network_config_check(echo, {has_lane = true, all_inputs_validated = true}),
		kcfg.Network_Config_Error.Echo_Requires_Tolerance,
	)

	dedicated := kcfg.network_profile(.Dedicated_Competitive)
	testing.expect_value(
		t,
		kcfg.network_config_check(dedicated, {has_lane = true}),
		kcfg.Network_Config_Error.Dedicated_Input_Validator_Missing,
	)
	dedicated.session.fingerprint = ksess.FINGERPRINT_NONE
	testing.expect_value(
		t,
		kcfg.network_config_check(dedicated, {has_lane = true, all_inputs_validated = true}),
		kcfg.Network_Config_Error.Dedicated_Fingerprint_Disabled,
	)
	dedicated = kcfg.network_profile(.Dedicated_Competitive)
	dedicated.session.traffic.actions.bytes_per_second = 0
	testing.expect_value(
		t,
		kcfg.network_config_check(dedicated, {has_lane = true, all_inputs_validated = true}),
		kcfg.Network_Config_Error.Dedicated_Traffic_Unbounded,
	)
}

@(test)
configure_installs_the_materialized_session_half :: proc(t: ^testing.T) {
	s: ksess.Session
	cfg := kcfg.network_profile(.Friends_Coop)
	cfg.session.max_players = 3
	got := kcfg.network_configure(&s, cfg)
	testing.expect_value(t, got.session.max_players, 3)
	testing.expect_value(t, s.cfg.max_players, 3)
}
