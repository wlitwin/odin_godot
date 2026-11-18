//gd:extends Node
//gd:class LifetimeProbe
package lifetime_probe

import gd "godot:godot"
import "godot:gdext"
import "core:fmt"
import rt "godot:runtime"
import steam "godot:kit/steamgd"

LifetimeProbe :: struct {
    owner:                     gd.Node,
    case_id:                   i64 `gd:"export"`,
    payload:                   ^gd.Resource `gd:"export,set=lifetime_probe_set_payload"`,
    value:                     i64 `gd:"export,get=lifetime_probe_get_value"`,
    exits, unregisters, ticks: i64,
}

Audit :: struct {
    finals, exits, unregisters, child_alive, resource_alive: i64,
}

audits: [16]Audit
accessor_after: [16]i64
signal_calls: [16]i64

lifetime_probe_ready :: proc(self: ^LifetimeProbe) {
    gd.print_str(fmt.tprintf("LIFETIME_READY %d", self.case_id))
}

lifetime_probe_exit_tree :: proc(self: ^LifetimeProbe) {
    self.exits += 1
}

lifetime_probe_process :: proc(self: ^LifetimeProbe, delta: f64) {
    self.ticks += 1
}

lifetime_probe_finalize :: proc(self: ^LifetimeProbe) {
    if self.case_id == 0 {
        return
    }

    row := &audits[self.case_id]
    row.finals += 1
    row.exits = self.exits
    row.unregisters = self.unregisters
    path := gd.new_node_path_cstring("Child")
    row.child_alive = i64(gd.node_get_node_or_null(self.owner, path) != nil)
    gd.free_node_path(path)
    row.resource_alive = i64(
        self.payload != nil &&
        gd.get_string(cast(gd.Object)self.payload, "resource_name", context.temp_allocator) == "retained",
    )
    gd.print_str(
        fmt.tprintf(
            "LIFETIME_FINAL %d exits=%d unregisters=%d child=%d resource=%d",
            self.case_id,
            row.exits,
            row.unregisters,
            row.child_alive,
            row.resource_alive,
        ),
    )
}

@(gd_method)
lifetime_probe_unregister_child :: proc(self: ^LifetimeProbe) {
    self.unregisters += 1
}

@(gd_method)
lifetime_probe_audit :: proc(self: ^LifetimeProbe, id: i64, field: i64) -> i64 {
    a := audits[id]

    switch field {
    case 0:
        return a.finals
    case 1:
        return a.exits
    case 2:
        return a.unregisters
    case 3:
        return a.child_alive
    case 4:
        return a.resource_alive
    case 5:
        return accessor_after[id]
    case 6:
        return signal_calls[id]
    }

    return -1
}

@(gd_method)
lifetime_probe_ticks :: proc(self: ^LifetimeProbe) -> i64 {
    return self.ticks
}

lifetime_probe_get_value :: proc(self: ^LifetimeProbe) -> i64 {
    if self.case_id == 5 {
        gd.object_set_script(cast(gd.Object)self.owner, {})
        self.value = 42
        accessor_after[5] = self.value
    }

    return self.value
}

lifetime_probe_set_payload :: proc(self: ^LifetimeProbe, value: ^gd.Resource) {
    self.payload = value

    if self.case_id == 6 {
        gd.object_set_script(cast(gd.Object)self.owner, {})
        accessor_after[6] = i64(
            gd.get_string(cast(gd.Object)self.payload, "resource_name", context.temp_allocator) == "retained",
        )
    }
}

@(gd_method, gd_connect = "/root/Source:ping")
lifetime_probe_on_ping :: proc(self: ^LifetimeProbe, value: i64) {
    signal_calls[self.case_id] += value
}

@(gd_method)
lifetime_probe_manual_policy :: proc(self: ^LifetimeProbe) -> bool {
    automatic, manual := false, false
    count: i32
    data := rt.odin_scripts_manifest(&count)

    for desc in data[:int(count)] {
        if string(desc.name) == "AutoStack" {
            automatic = bool(desc.owns_state) && desc.lifecycle.finalize != nil
        }

        if string(desc.name) == "ManualStack" {
            manual = bool(desc.owns_state) && desc.lifecycle.finalize == nil
        }
    }

    return automatic && manual
}

steam_subscription: steam.Subscription

@(gd_method)
lifetime_probe_steam_open :: proc(self: ^LifetimeProbe) -> bool {
    return steam.listen(&steam_subscription, self.owner, "on_created", "on_joined", "on_requested")
}

@(gd_method)
lifetime_probe_steam_close :: proc(self: ^LifetimeProbe) {
    steam.unlisten(&steam_subscription)
}

@(gd_method)
lifetime_probe_on_created :: proc(self: ^LifetimeProbe, result, lobby: i64) {
    signal_calls[9] += 1
}

@(gd_method)
lifetime_probe_on_joined :: proc(self: ^LifetimeProbe, lobby, perms: i64, locked: bool, response: i64) {
    signal_calls[10] += 1
}

@(gd_method)
lifetime_probe_on_requested :: proc(self: ^LifetimeProbe, lobby, friend: i64) {
    signal_calls[11] += 1
}

@(gd_method)
lifetime_probe_auto_order :: proc(self: ^LifetimeProbe) -> bool {
    return auto_final_calls == 1 && auto_rider_before == 1
}
