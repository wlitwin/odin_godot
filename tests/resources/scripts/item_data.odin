//gd:extends Resource
//gd:class ItemData
package resources_scripts

// ----------------------------------------------------------------------------
// ItemData — a CUSTOM RESOURCE authored in Odin (`//gd:extends Resource`). A Resource
// is RefCounted (not in the scene tree), so it has no _ready/_process; it is a pure data
// container. Its `@export` fields are STORAGE properties, which means the engine's text
// resource serializer (`.tres`) writes them out and reads them back — alongside a ref to
// this very script — so a saved `.tres` reconstructs a live ItemData with its script
// attached and its values restored.
//
// Fields:
//   - name/value: plain @export scalars (round-trip through .tres).
//   - icon:       a typed-resource @export slot (a Texture2D picker in the Inspector).
//   - item_total(): a custom method, callable from GDScript AND after a .tres reload,
//     proving the loaded resource still has its Odin script bound + dispatching.
// ----------------------------------------------------------------------------

import gd "godot:godot"

ItemData :: struct {
	owner: gd.Resource,
	name:  gd.String `gd:"export"`,
	value: gd.Int    `gd:"export,range=0:999"`,
	icon:  ^gd.Resource `gd:"export,resource=Texture2D"`,
}

// item_total — a custom @(gd_method). Returns a value derived from the @export `value`
// so a successful call after a .tres reload proves BOTH that the script re-bound AND that
// the @export value survived the round-trip (value 10 -> 110).
@(gd_method)
item_data_item_total :: proc(self: ^ItemData) -> int {
	return int(self.value) + 100
}
