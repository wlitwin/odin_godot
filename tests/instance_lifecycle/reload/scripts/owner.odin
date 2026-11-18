//gd:extends Node
//gd:class ReloadOwner
//gd:tool
package reload_owner
import gd "godot:godot"
import "godot:gdext"
import "core:fmt"
ReloadOwner :: struct {
    owner: gd.Node,
    left, right: i64, // PRIVATE_LAYOUT
}
reload_owner_ready :: proc(self: ^ReloadOwner) {self.left=11;self.right=22}
reload_owner_finalize :: proc(self: ^ReloadOwner) {gd.print_str(fmt.tprintf("RELOAD_FINAL_%d",reload_owner_version(self)))}
@(gd_method)
reload_owner_version :: proc(self: ^ReloadOwner) -> i64 {return 1} // BODY_VERSION
@(gd_method)
reload_owner_value :: proc(self: ^ReloadOwner) -> i64 {return self.left*100+self.right}
