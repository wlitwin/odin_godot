#+build darwin, linux, windows
package core

import "core:fmt"
import "core:mem"
import "core:os"
import bg "godot:box3d/godot"

@(private)
box3d_binary_host_arch :: proc "contextless" () -> Box3D_Binary_Arch {
	return .ARM64 when ODIN_ARCH == .arm64 else .X86_64
}
// Read a single open file, bound allocation before reading, and reject growth or
// shrinkage. Callers validate and load a unique copy of THESE bytes, never reopen
// the original published filename after inspection.
@(private)
box3d_admission_read :: proc(path: string) -> ([]u8, bool) {
	file, error := os.open(path)
	if error != nil {return nil, false}
	defer os.close(file)
	info, stat_error := os.fstat(file, context.temp_allocator)
	if stat_error != nil ||
	   info.size <= 0 ||
	   info.size > BOX3D_BINARY_MAX_BYTES {return nil, false}
	allocation, allocation_error := mem.alloc(int(info.size), 1, context.allocator)
	if allocation_error != nil {return nil, false}
	data := (cast([^]u8)allocation)[:int(info.size)]
	n, read_error := os.read_at(file, data, 0)
	if read_error != nil || n != len(data) {delete(data); return nil, false}
	extra: [1]u8
	more, _ := os.read_at(file, extra[:], info.size)
	if more != 0 {delete(data); return nil, false}
	return data, true
}
@(private)
box3d_admission_check :: proc(path: string, data: []u8) -> bool {
	when !BOX3D_HOST_ENABLED {return true}
	result := box3d_binary_admit(data, box3d_binary_host_arch())
	if result.error != .None {
		gdext_print(
			"ODIN_BOX3D_MODULE_CONTRACT_REJECTED",
			fmt.tprintf("%s preflight=%v offset=%d", path, result.error, result.offset),
		)
		return false
	}
	// Load the one SDK-controlled native image before the module's canonical
	// dependency is resolved. Existing ABI/cookie/build checks still follow dlopen.
	if !box3d_native_initialize(
		
	) {gdext_print("ODIN_BOX3D_MODULE_CONTRACT_REJECTED", fmt.tprintf("%s controlled Native unavailable", path)); return false}
	return true
}

// A process-qualified exclusive file prevents two Godot processes from ever
// rewriting the other's mapped generation. Names remain in the module directory
// so controlled @loader_path/$ORIGIN relative dependencies retain their meaning.
@(private)
box3d_admission_copy :: proc(base: string, data: []u8) -> (string, bool) {
	for _ in 0 ..< 16 {
		reload_counter += 1
		path := fmt.aprintf("%s.r%d.p%d%s", base, reload_counter, os.get_pid(), SCRIPTS_DLL_EXT)
		file, error := os.open(path, {.Write, .Create, .Excl})
		if error != nil {delete(path); continue}
		written := 0
		ok := true
		for written < len(data) {
			n, write_error := os.write(file, data[written:])
			if write_error != nil || n <= 0 {ok = false; break}
			written += n
		}
		os.close(file)
		if !ok {os.remove(path); delete(path); return "", false}
		return path, true
	}
	return "", false
}

@(private)
BOX3D_CORE_EXPECTED_BUILD :: #config(BOX3D_EXPECTED_BUILD, "")
@(private)
BOX3D_CORE_EXPECTED_TARGET :: #config(BOX3D_EXPECTED_TARGET, "")
// Public pure helper for independent exact-byte config controls. No Native
// initialization, module registration, TLS context or object allocation.
box3d_native_identity_matches :: proc "contextless" (actual: [32]u8, encoded: string) -> bool {
	text := encoded
	if len(text) >= 7 && text[:7] == "sha256:" {text = text[7:]}
	if len(text) != 64 {return false}
	for value, i in actual {
		got := u8(0)
		for c in text[2 * i:2 * i + 2] {
			got <<= 4
			if c >= '0' &&
			   c <=
				   '9' {got |= u8(c - '0')} else if c >= 'a' && c <= 'f' {got |= u8(c - 'a' + 10)} else if c >= 'A' && c <= 'F' {got |= u8(c - 'A' + 10)} else {return false}
		}
		if got != value {return false}
	}
	return true
}
@(private)
box3d_core_native_expected :: proc "contextless" (contract: bg.Domain_Contract) -> bool {
	return(
		box3d_native_identity_matches(contract.build, BOX3D_CORE_EXPECTED_BUILD) &&
		box3d_native_identity_matches(contract.target, BOX3D_CORE_EXPECTED_TARGET) \
	)
}
