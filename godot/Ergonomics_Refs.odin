package godot

import gdext "godot:gdext"

// Consume one owned RefCounted reference. Nil is harmless. This does not clear
// the caller's handle and must not be applied to a borrowed reference.
release_ref :: proc "contextless" (object:Ref_Counted) {
	if object!=nil && ref_counted_unreference(object) {gdext.object_destroy(object)}
}
