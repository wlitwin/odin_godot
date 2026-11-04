package kit_box3d_net_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

checked_dump :: proc(cp: ^k.World_Checkpoint) -> []u8 {
	size, status := p.checkpoint_dump(cp, nil, Side); assert(status == .Ok)
	bytes := make(
		[]u8,
		int(size),
	); _, status = p.checkpoint_dump(cp, bytes, Side); assert(status == .Ok); return bytes
}
auxiliary :: proc(box: ^Box, cat: ^b.Recovery_Catalog) {
	box.peer =
		s.HOST_PEER; box.ses.send = send; box.ses.send_user = box; s.session_host_start(&box.ses, "equality-fixture"); setup(box, 3, cat)
}
@(test)
complete_equality_parity_failures_and_corrupt_equal_dump :: proc(t: ^testing.T) {
	host, client: Box; start_pair(&host, &client); cat := catalog(); defer b.recovery_catalog_destroy(&cat)
	setup(&host, 3, &cat); setup(&client, 3, &cat); defer destroy(&host); defer destroy(&client)
	a, ae := k.lane_world_checkpoint(
		&host.lane,
		0,
	); c, ce := k.lane_world_checkpoint(&client.lane, 0)
	testing.expect_value(
		t,
		ae,
		k.World_Error.Ok,
	); testing.expect_value(t, ce, k.World_Error.Ok); defer k.world_checkpoint_destroy(&a); defer k.world_checkpoint_destroy(&c)
	left := checked_dump(
		&a,
	); right := checked_dump(&c); testing.expect_value(t, mem.compare(left, right), 0); delete(left); delete(right)
	same, e := k.world_checkpoint_equal(
		&a,
		&c,
	); testing.expect_value(t, e, k.World_Error.Ok); testing.expect(t, same)
	when #config(KIT_PHYSICS_TEST_HOOKS, false) {
		before := p.owned_bytes()
		for control in p.Equality_Test_Control {
			equal, error := p.checkpoint_test_equality(&a, &c, Side, control)
			testing.expect(t, !equal && error != .Ok)
			if control == .Fail_Left ||
			   control ==
				   .Fail_Right {testing.expect_value(t, error, k.World_Error.Allocation_Failed)}
			testing.expect_value(t, p.owned_bytes(), before)
			equal, error = k.world_checkpoint_equal(
				&a,
				&c,
			); testing.expect_value(t, error, k.World_Error.Ok); testing.expect(t, equal)
		}
	}
	// Equal game/Side/pose fields cannot hide a solver-only gravity difference.
	aux := Box {
		initial_gravity = true,
	}; auxiliary(&aux, &cat)
	other, oe := k.lane_world_checkpoint(
		&aux.lane,
		0,
	); testing.expect_value(t, oe, k.World_Error.Ok)
	sa, _ := p.checkpoint_side(
		&a,
		Side,
	); sb, _ := p.checkpoint_side(&other, Side); testing.expect_value(t, sa, sb)
	da, _ := p.checkpoint_digests(
		&a,
		Side,
	); db, _ := p.checkpoint_digests(&other, Side); testing.expect_value(t, da.motion_digest, db.motion_digest)
	same, e = k.world_checkpoint_equal(
		&a,
		&other,
	); testing.expect_value(t, e, k.World_Error.Ok); testing.expect(t, !same)
	k.world_checkpoint_destroy(&other); destroy(&aux)
	// Side alone also participates even when every complete solver byte agrees.
	aux = Box {
		initial_side_delta = true,
	}; auxiliary(
		&aux,
		&cat,
	); other, oe = k.lane_world_checkpoint(&aux.lane, 0); testing.expect_value(t, oe, k.World_Error.Ok)
	left = checked_dump(
		&a,
	); right = checked_dump(&other); testing.expect_value(t, mem.compare(left, right), 0); delete(left); delete(right)
	same, e = k.world_checkpoint_equal(
		&a,
		&other,
	); testing.expect_value(t, e, k.World_Error.Ok); testing.expect(t, !same)
	k.world_checkpoint_destroy(&other); destroy(&aux)
}
