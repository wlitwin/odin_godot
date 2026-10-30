#+build darwin, linux
package enrollment_probe

import "core:fmt"
import "core:os"
import "core:time"
import gd "godot:godot"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"
import adapter "godot:replay/godot/provision_sqlite"

Native :: struct {store: db.Client_Store, backing: rgd.Enrollment_Backing, probe: ^EnrollmentProbe}
native_open :: proc(self: ^EnrollmentProbe) -> (rgd.Enrollment_Backing, bool) {
	n := new(Native); self.native = n; n.probe = self
	if db.client_open(&n.store, gd.env_string("ENROLLMENT_DB", ""), "active", 55, self.stage == 1) != .None {return {}, false}
	n.backing = adapter.backing(&n.store)
	return {n, native_load, native_commit}, true
}
native_load :: proc(user: rawptr) -> (p.Enrollment_Record, bool, p.Enrollment_Error) {
	n := cast(^Native)user; return n.backing.load(n.backing.user)
}
native_commit :: proc(user: rawptr, expected: u64, next: p.Enrollment_Record) -> (u64, p.Enrollment_Error) {
	n := cast(^Native)user
	if n.probe.stage == 2 && next.state == .Ready {
		_, available := p.enrollment_grant(&n.probe.profile.value); assert(!available)
		hash := grant_hash(next.grant); defer delete(hash)
		assert(os.write_entire_file(gd.env_string("ENROLLMENT_FINGERPRINT", ""), hash) == nil)
		gd.print_str(fmt.tprintf("ENROLLMENT_GRANT_RECEIVED fingerprint=%s", hash))
		for {time.sleep(100 * time.Millisecond)}
	}
	return n.backing.commit(n.backing.user, expected, next)
}
native_tls :: proc(self: ^EnrollmentProbe) -> bool {
	cert := gd.new_x509_certificate(); gd.ref_counted_init_ref(cert); defer unref(cert)
	path := gd.new_string_odin(gd.env_string("PROVISION_CERT", "")); defer gd.free_string(path)
	if gd.x509_certificate_load(cert, path) != .Ok {return false}
	self.tls = gd.tls_options_client(cert, gd.string_empty()); return self.tls != nil
}
native_finish :: proc(self: ^EnrollmentProbe, hash: string) -> bool {
	bytes, err := os.read_entire_file(gd.env_string("ENROLLMENT_FINGERPRINT", ""), context.allocator); defer delete(bytes)
	if err != nil || string(bytes) != hash {return false}
	return os.write_entire_file(gd.env_string("PROVISION_DONE", ""), "done") == nil
}
native_close :: proc(self: ^EnrollmentProbe) {if self.native != nil {n := cast(^Native)self.native; db.client_close(&n.store); free(n)}}
