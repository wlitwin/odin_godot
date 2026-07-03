#+build windows
package core

import "core:strings"
import win32 "core:sys/windows"

// Windows counterpart of dladdr for core_dll_dir (scripts_native.odin):
// GetModuleHandleExW(FROM_ADDRESS) resolves the module containing a given address,
// GetModuleFileNameW then yields its on-disk path. GetModuleHandleExW is missing
// from core:sys/windows, so it is declared here.

@(private = "file")
GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT: win32.DWORD : 0x00000002
@(private = "file")
GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS: win32.DWORD : 0x00000004

foreign import kernel32_ "system:Kernel32.lib"
@(default_calling_convention = "system")
foreign kernel32_ {
	GetModuleHandleExW :: proc(dwFlags: win32.DWORD, lpModuleName: win32.LPCWSTR, phModule: ^win32.HMODULE) -> win32.BOOL ---
}

// Directory of the module (dll) containing `addr` — an address inside one of OUR procs,
// never the exe. UNCHANGED_REFCOUNT so we don't pin our own dll.
@(private)
core_dll_dir_windows :: proc(addr: rawptr, allocator := context.allocator) -> (string, bool) {
	mod: win32.HMODULE
	flags := GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT
	if bool(GetModuleHandleExW(flags, cast(win32.LPCWSTR)addr, &mod)) {
		buf: [win32.MAX_PATH_WIDE]u16
		n := win32.GetModuleFileNameW(mod, cast(win32.LPWSTR)raw_data(buf[:]), u32(len(buf)))
		if n > 0 && int(n) < len(buf) {
			path, cerr := win32.utf16_to_utf8_alloc(buf[:n], context.temp_allocator)
			if cerr == nil {
				idx := strings.last_index_byte(path, '\\')
				if fidx := strings.last_index_byte(path, '/'); fidx > idx {
					idx = fidx
				}
				if idx >= 0 {
					return strings.clone(path[:idx], allocator), true
				}
			}
		}
	}
	return "", false
}
