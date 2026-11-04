package kit_physics

// Deliberate fault injection, absent from ordinary package builds. These helpers
// expose no native pointer and restore every changed byte/allocator before return.
import "core:mem"
import sim "godot:kit/sim"

when #config(KIT_PHYSICS_TEST_HOOKS, false) {
	foreign import test_native {"system:" + #config(BOX3D_LIBRARY, "native/libogb3.a")}
	foreign test_native {
		ogb3_snapshot_test_image :: proc "c" (snapshot: rawptr, size: ^u64) -> [^]u8 ---
	}
	Equality_Test_Control :: enum {
		Fail_Left,
		Fail_Right,
		Corrupt_Left,
		Corrupt_Right,
		Length_Left_Corrupt_Right,
		Length_Right_Corrupt_Left,
	}
	checkpoint_test_equality :: proc(
		left, right: ^sim.World_Checkpoint,
		$Side: typeid,
		control: Equality_Test_Control,
	) -> (
		bool,
		sim.World_Error,
	) {
		if left == nil ||
		   right == nil ||
		   left.image == nil ||
		   right.image == nil ||
		   left.side_type != Side ||
		   right.side_type != Side {return false, .Invalid}
		a := cast(^Image(Side))left.image; b := cast(^Image(Side))right.image
		aa, ba :=
			a.allocator,
			b.allocator; an, bn := a.info.storage.normalized_bytes, b.info.storage.normalized_bytes
		defer {a.allocator = aa; b.allocator = ba; a.info.storage.normalized_bytes = an
			b.info.storage.normalized_bytes = bn}
		if control == .Fail_Left {a.allocator = mem.nil_allocator()}
		if control == .Fail_Right {b.allocator = mem.nil_allocator()}
		if control == .Length_Left_Corrupt_Right {a.info.storage.normalized_bytes += 1}
		if control == .Length_Right_Corrupt_Left {b.info.storage.normalized_bytes += 1}
		corrupt :=
			control == .Corrupt_Left ||
			control == .Corrupt_Right ||
			control == .Length_Left_Corrupt_Right ||
			control == .Length_Right_Corrupt_Left
		if corrupt {
			owner := control == .Corrupt_Left || control == .Length_Right_Corrupt_Left ? a : b
			size: u64; bytes := ogb3_snapshot_test_image(owner.snapshot._handle, &size)
			if bytes == nil || size == 0 {return false, .Invalid}
			bytes[size - 1] ~= 1; defer {bytes[size - 1] ~= 1}
			return left.equal(left.image, right.image)
		}
		return left.equal(left.image, right.image)
	}
}
