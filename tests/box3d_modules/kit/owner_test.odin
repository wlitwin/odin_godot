package kit_module_owner_test

import "core:testing"
import bg "godot:box3d/godot"
import sim "godot:kit/sim"

Owner_Context :: struct {
	references, checks, retains, drops: i32,
	protected, source_alive, deny_drop: bool,
}
owner :: proc(lease_context: ^Owner_Context, realm: u64 = 71) -> sim.World_Owner {
	return {
		user = lease_context,
		realm = realm,
		context_caps = sim.WORLD_OWNER_MANAGED_DATA | sim.WORLD_OWNER_WEAK_INSTANCE,
		check = proc "c" (user: rawptr, access: u32) -> bg.Status {
			c := cast(^Owner_Context)user; c.checks += 1
			if !c.protected ||
			   (access == sim.WORLD_OWNER_EXECUTE && !c.source_alive) {return 1}; return 0
		},
		retain = proc "c" (user: rawptr) -> bg.Status {c := cast(^Owner_Context)user
			if !c.protected {return 1}
			c.references += 1
			c.retains += 1
			return 0},
		drop = proc "c" (user: rawptr) -> bg.Status {c := cast(^Owner_Context)user
			if !c.protected || c.references <= 0 || c.deny_drop {return 1}
			c.references -= 1
			c.drops += 1
			return 0},
	}
}
@(test)
optional_owner_requires_realm_protected_origin_and_actual_lease_context :: proc(t: ^testing.T) {
	testing.expect_value(t, sim.world_owner_check({}), sim.World_Error.Ok)
	testing.expect_value(t, sim.world_owner_retain({}), sim.World_Error.Ok)
	testing.expect_value(t, sim.world_owner_drop({}), sim.World_Error.Ok)
	testing.expect_value(t, sim.world_owner_realm_install(71), sim.World_Error.Ok)
	lease_context := new(
		Owner_Context,
	); lease_context.source_alive = true; capability := owner(lease_context)
	testing.expect_value(t, sim.world_owner_retain(capability), sim.World_Error.Rejected)
	testing.expect_value(t, lease_context.references, i32(0))
	other_realm := owner(lease_context, 72); checks := lease_context.checks
	testing.expect_value(t, sim.world_owner_check(other_realm), sim.World_Error.Incompatible)
	testing.expect_value(t, lease_context.checks, checks)
	borrowed := capability; borrowed.context_caps = sim.WORLD_OWNER_WEAK_INSTANCE
	testing.expect_value(t, sim.world_owner_check(borrowed), sim.World_Error.Invalid)
	lease_context.protected = true
	testing.expect_value(t, sim.world_owner_retain(capability), sim.World_Error.Ok)
	testing.expect_value(
		t,
		sim.world_owner_check(capability, sim.WORLD_OWNER_EXECUTE),
		sim.World_Error.Ok,
	)
	lease_context.source_alive = false
	testing.expect_value(
		t,
		sim.world_owner_check(capability, sim.WORLD_OWNER_EXECUTE),
		sim.World_Error.Rejected,
	)
	testing.expect_value(t, sim.world_owner_check(capability), sim.World_Error.Ok)
	lease_context.protected = false
	testing.expect_value(t, sim.world_owner_drop(capability), sim.World_Error.Rejected)
	testing.expect_value(t, lease_context.references, i32(1))
	lease_context.protected = true
	testing.expect_value(t, sim.world_owner_drop(capability), sim.World_Error.Ok)
	testing.expect_value(
		t,
		lease_context.references,
		i32(0),
	); testing.expect_value(t, lease_context.retains, lease_context.drops)
	free(lease_context) // actual lease_context memory released, no code-pin-only promise
}
