//gd:extends Node
//gd:class Holder
package resources_scripts

// ----------------------------------------------------------------------------
// Holder — a NODE script with a RESOURCE-TYPED @export slot. In the Inspector this is a
// resource picker filtered (by hint_string) to `ItemData`; a custom ItemData `.tres` can
// be dropped into it. The slot stores the assigned Resource Object; the GDScript driver
// reads it back and calls a method off it to prove the custom resource survives being
// assigned through a typed @export.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Holder :: struct {
	owner: gd.Node,
	data:  ^gd.Resource `gd:"export,resource=ItemData"`,
}
