//gd:extends Node
//gd:class EnrollmentProbe
package enrollment_probe

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import rgd "godot:replay/godot"

EnrollmentProbe :: struct {
    owner:                              gd.Node,
    profile:                            rgd.Enrollment_Profile,
    connection:                         rgd.Provision_Connection,
    native:                             rawptr,
    tls:                                gd.Tls_Options,
    url:                                string,
    started:                            u64,
    stage:                              int,
    loaded, announced, done, connected: bool,
}

param :: proc(key, fallback: string) -> string {
    when gd.IS_WEB {
        value := gd.web_query(key)
        return value != "" ? value : fallback
    } else {
        return gd.env_string(fmt.ctprintf("%s", key), fallback)
    }
}

unref :: proc(object: gd.Ref_Counted) {
    if object != nil && gd.ref_counted_unreference(object) {
        gdext.object_destroy(object)
    }
}

enrollment_probe_ready :: proc(self: ^EnrollmentProbe) {
    self.url = strings.clone(param("ENROLLMENT_URL", ""))
    self.stage = int(param("ENROLLMENT_STAGE", "0")[0] - '0')
    self.started = gd.time_get_ticks_msec(gd.singleton_time())
    backing, ok := native_open(self)

    if !ok ||
       !rgd.enrollment_profile_open(
               &self.profile,
               self.url,
               55,
               "replay-enrollment-fixture",
               param("ENROLLMENT_SLOT", "active"),
               backing,
               gd.IS_WEB,
           ) {
        fail(self, "profile open")
        return
    }
}

request_hash :: proc(self: ^EnrollmentProbe) -> string {
    bytes: [p.PACKET_BYTES]u8
    count := p.request_pack(&self.profile.value.protocol, self.profile.value.record.request, bytes[:])
    return fmt.aprintf("%x", rec.hash(bytes[:count]))
}

grant_hash :: proc(grant: p.Grant) -> string {
    g := grant
    bytes: [48]u8
    copy(bytes[:32], g.key[:])
    copy(bytes[32:], g.token[:])
    return fmt.aprintf("%x", rec.hash(bytes[:]))
}

announce :: proc(self: ^EnrollmentProbe, label: string) {
    if self.announced {
        return
    }

    hash := request_hash(self)
    defer delete(hash)
    gd.print_str(fmt.tprintf("ENROLLMENT_%s revision=%d request=%s", label, self.profile.value.revision, hash))
    self.announced = true
}

enrollment_probe_process :: proc(self: ^EnrollmentProbe, dt: f64) {
    if self.done {
        return
    }

    if gd.time_get_ticks_msec(gd.singleton_time()) - self.started > 90000 {
        fail(self, "timeout")
        return
    }

    rgd.enrollment_profile_frame(&self.profile)
    e := &self.profile.value

    if e.phase == .Failed {
        fail(self, fmt.tprintf("profile %v", e.error))
        return
    }

    if e.phase == .Loading {
        return
    }

    go := false

    when gd.IS_WEB {
        // Test controls contain no credentials; they only pause a state boundary.
        code := gd.new_string_odin("globalThis.enrollmentGo===true ? 1 : 0")
        defer gd.free_string(code)
        value := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), code, true)
        defer gd.variant_destroy(&value)
        go = gd.variant_to_int(&value) == 1

        if e.phase == .Empty && (self.stage == 5 || self.stage == 6) {
            announce(self, "EMPTY")

            if !go {
                return
            }

            self.announced = false
        }
    }

    if e.phase == .Empty {
        claim: p.Secret
        crypto := gd.new_crypto()
        gd.ref_counted_init_ref(crypto)
        bytes := gd.crypto_generate_random_bytes(crypto, 32)
        view := gd.packed_byte_array_view(&bytes)

        if len(view) == 32 {
            copy(claim[:], view)
        }

        gd.free_packed_byte_array(bytes)
        unref(crypto)

        if claim == (p.Secret{}) {
            fail(self, "entropy")
            return
        }

        endpoint, _ := auth.endpoint("127.0.0.1", 45001)
        room: u64 = param("ENROLLMENT_ROOM", "44") == "45" ? 45 : 44
        q := p.Request {
            version  = p.PROTOCOL,
            verb     = .Create,
            room     = room,
            content  = 55,
            claim    = claim,
            endpoint = endpoint,
        }

        if !rgd.enrollment_profile_begin(&self.profile, q) {
            fail(self, "begin")
            return
        }

        rgd.enrollment_profile_frame(&self.profile)
        return
    }

    if e.phase == .Pending && (self.stage == 1 || self.stage == 6) {
        announce(self, "REQUEST_STORED")

        if self.stage == 6 || !go {
            return
        }
    }

    if e.phase == .Ready {
        grant, ready := p.enrollment_grant(e)

        if !ready {
            fail(self, "ready grant")
            return
        }

        hash := grant_hash(grant)
        defer delete(hash)
        announce(self, "READY")
        gd.print_str(fmt.tprintf("ENROLLMENT_CREDENTIAL fingerprint=%s", hash))

        if self.stage == 3 {
            self.done = true
            return
        }

        if !native_finish(self, hash) {
            fail(self, "fingerprint")
            return
        }

        gd.print_str(fmt.tprintf("ENROLLMENT_OK revision=%d connected=%t", e.revision, self.connected))
        self.done = true

        when !gd.IS_WEB {
            gd.scene_tree_quit(gd.get_tree(self.owner), 0)
        }

        return
    }

    if e.phase != .Pending {
        return
    }

    if !self.connected {
        if !native_tls(self) || rgd.provision_connect(&self.connection, self.url, self.tls, gd.IS_WEB) != .None {
            fail(self, "connection")
            return
        }

        self.connected = true
    }

    if err := rgd.provision_enrollment_frame(&self.connection, &self.profile); err != .None {
        fail(self, fmt.tprintf("protocol %v", err))
        return
    }
}

fail :: proc(self: ^EnrollmentProbe, reason: string) {
    gd.print_str(fmt.tprintf("ENROLLMENT_FAIL %s connected=%t", reason, self.connected))
    self.done = true

    when !gd.IS_WEB {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
    }
}

enrollment_probe_exit_tree :: proc(self: ^EnrollmentProbe) {
    rgd.provision_disconnect(&self.connection)
    rgd.enrollment_profile_close(&self.profile)
    native_close(self)
    unref(self.tls)
    delete(self.url)
}
