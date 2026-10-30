#+build !darwin
#+build !linux
#+build !windows
package replay_authority

@(private)
native_milliseconds :: proc(user: rawptr) -> (u64, bool) {return 0, false}
