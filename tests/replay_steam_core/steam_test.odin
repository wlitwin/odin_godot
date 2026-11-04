package steam_core_test
import "core:testing"
import transportgd "godot:replay/godot/transport"

@(test)
opaque_steam_ids_reject_bad_endpoints_without_overflow :: proc(t: ^testing.T) {
    for text in ([]string{"", "0", "-1", "+1", "1_2", " 123", "18446744073709551616", "999999999999999999999"}) {
        _, ok := transportgd.steam_parse_id(text)
        testing.expect(t, !ok)
    }

    value, ok := transportgd.steam_parse_id("76561198000000001")
    testing.expect(t, ok && value == 76561198000000001)
    value, ok = transportgd.steam_parse_id("18446744073709551615")
    testing.expect(t, ok && value == max(u64))
}

@(test)
missing_runtime_and_invalid_config_fail_before_engine_calls :: proc(t: ^testing.T) {
    s: transportgd.Steam
    config := transportgd.STEAM_CONFIG
    testing.expect_value(t, transportgd.steam_open(&s, config, true), transportgd.Steam_Error.Not_Initialized)
    config.max_peers = 0
    testing.expect_value(t, transportgd.steam_open(&s, config, true), transportgd.Steam_Error.Invalid_Config)
    config = transportgd.STEAM_CONFIG
    testing.expect_value(t, transportgd.steam_open(&s, config, false), transportgd.Steam_Error.Invalid_Config)
    runtime: transportgd.Steam_Runtime
    testing.expect_value(t, transportgd.steam_runtime_init(&runtime, 0), transportgd.Steam_Error.Invalid_Config)
}
