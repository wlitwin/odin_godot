#+build windows
package core

// Windows counterpart of core/debug_launch.odin: NO debugger menu items yet. The lldb
// launcher story is signals/dSYM/osascript-shaped (macOS + Linux); on Windows the
// native debugging path would be Visual Studio / WinDbg / RemedyBG attaching to the
// game process with the .pdb the build already emits — wire that up when the Windows
// crash-capture (SEH) work lands. Registering nothing keeps the Tools menu honest.

import "godot:godot"

@(private)
debug_register_menu_items :: proc(plug: godot.Editor_Plugin) {
}
