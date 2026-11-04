package main
import "core:fmt"
import "core:os"
import c "godot:core"
main :: proc() {
	if len(os.args) != 3 {os.exit(2)}
	data, error := os.read_entire_file(
		os.args[1],
		context.allocator,
	); if error != nil {os.exit(3)}; defer delete(data)
	arch := c.Box3D_Binary_Arch.ARM64; if os.args[2] == "x64" {arch = .X86_64}
	result := c.box3d_binary_admit(data, arch)
	fmt.print(
		"{",
	); fmt.printf("\"error\":%q,\"offset\":%d,\"symbols\":%d,\"dependencies\":%d,\"native_imports\":%d,\"canonical\":%v", result.error, result.offset, result.symbols, result.dependencies, result.native_imports, result.canonical_native); fmt.print("}\n")
}
