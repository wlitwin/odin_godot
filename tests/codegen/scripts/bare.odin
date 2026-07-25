//gd:extends Node2D
//gd:class BareProbe
package codegen_scripts

// BareProbe — pins BARE-import block composition: `import "godot:play"` (no
// alias) must bind the target's package name and compose exactly like the
// aliased form. It used to silently skip the embed — the struct compiled,
// the game ran, and the block's fields just never replicated. run.sh greps
// the consolidated odin_godot_scripts.gen.odin for the health descriptor entries.

import gd "godot:godot"
import "godot:play"

BareProbe :: struct {
	owner:  gd.Node2d,
	health: play.Health, // hp/max must land in BareProbe's Entity_Desc
}
