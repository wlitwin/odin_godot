#+build !darwin
#+build !linux
package enrollment_probe

import rgd "godot:replay/godot"

native_open :: proc(self: ^EnrollmentProbe) -> (rgd.Enrollment_Backing, bool) {
    return {}, true
}

native_tls :: proc(self: ^EnrollmentProbe) -> bool {
    return true
}

native_finish :: proc(self: ^EnrollmentProbe, hash: string) -> bool {
    return true
}

native_close :: proc(self: ^EnrollmentProbe) {}
