package admission_test
import "core:testing"
import c "godot:core"

@(test)
core_expected_native_identity_exact_and_prefixed :: proc(t: ^testing.T) {
    value: [32]u8

    for &v, i in value {
        v = u8(i)
    }

    hex :: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    testing.expect(t, c.box3d_native_identity_matches(value, hex))
    testing.expect(t, c.box3d_native_identity_matches(value, "sha256:" + hex))
    wrong := value
    wrong[0] = 255
    testing.expect(t, !c.box3d_native_identity_matches(wrong, "sha256:" + hex))
    testing.expect(
        t,
        !c.box3d_native_identity_matches(
            value,
            "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        ),
    )
    testing.expect(t, !c.box3d_native_identity_matches(value, ""))
    testing.expect(
        t,
        !c.box3d_native_identity_matches(
            value,
            "sha256:x00102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
        ),
    )
}
