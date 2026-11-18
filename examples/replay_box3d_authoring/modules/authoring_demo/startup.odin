package replay_authoring_demo

import "base:runtime"
import "core:fmt"
import gd "godot:godot"
import physicsgd "godot:replay/godot/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"

error_set :: proc(self: ^ReplayAuthoringDemo, text: string) {
    if self.error_count == 0 {
        self.error_count = copy(self.error_text[:], transmute([]u8)text)
    }

    self.failed = true
}

startup :: proc(self: ^ReplayAuthoringDemo) -> bool {
    self.owners_before, self.owners_before_observed = owner_count_observe()

    if !self.owners_before_observed {
        error_set(self, "cleanup.owner_baseline unavailable")
        return false
    }

    self.role = "host"
    role := gd.env_string("BOX3D_SAMPLE_ROLE", "host")

    switch role {
    case "host", "Host":
        self.hosting = true
    case "client", "Client":
        self.role = "client"
    case:
        error_set(self, "config.ROLE must be host or client")
        return false
    }

    self.scripted = gd.env_int("BOX3D_SAMPLE_SCRIPTED", 0) != 0
    ticks := gd.env_int("BOX3D_SAMPLE_TICKS", self.scripted ? 120 : 0)
    port := gd.env_int("BOX3D_SAMPLE_PORT", 49742)

    if ticks < 0 || ticks > 216000 || (self.scripted && ticks == 0) || port < 1 || port > 65535 {
        error_set(self, "config.TICKS/PORT")
        return false
    }

    self.target = u64(ticks)
    self.frame_budget = 36000

    if self.target > 120 {
        self.frame_budget += 4 * (self.target - 120)
    }

    source := gd.get_node(self.owner, "AuthoredWorld")
    self.output = gd.env_string("BOX3D_SAMPLE_OUTPUT", "", allocator = runtime.heap_allocator())
    options := physicsgd.authored_options(self.hosting ? .Host : .Client)
    options.port = u16(port)
    options.address = "127.0.0.1"
    options.network.snapshot_every = 1
    options.replication.transport.egress_per_second = 8 * 1024 * 1024
    options.replication.transport.egress_per_pump = 1024 * 1024
    options.replication.transport.burst_bytes = 1024 * 1024
    // Existing application lane, same sample terminal envelope as replay_box3d.
    // It cannot acknowledge or alter any framework input/physics packet.
    options.replication.application_handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
        return len(bytes) == 512 && string(bytes[:8]) == "RB3TAIL1"
    }
    options.token[0] = self.hosting ? u8(101) : u8(202)
    report := physicsgd.authored_open(&self.physics,source,model(),initial_game,rules(),options,profile=PROFILE)
    if report.error != .None {
        error_set(self, net.setup_describe(&report))
        return false
    }
    self.state = physicsgd.authored_data(&self.physics)
    self.content = self.physics.content
    gd.node_queue_free(source) // Runtime retains only detached authored/native values.

    if native_image_count() != 1 {
        error_set(self, "Native.loaded_images must equal1")
        return false
    }

    self.ready = true
    self.go = self.hosting && !self.scripted
    log_json("SAMPLE_READY", struct {
        framework, role, content_sha256, mode: string,
        native_images:                         int,
    }{"Replay", self.role, hash_hex(self.content), self.scripted ? "scripted" : "interactive", native_image_count()})
    return true
}

replay_authoring_demo_ready :: proc(self: ^ReplayAuthoringDemo) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if !startup(self) {
        finish(self)
    }
}
