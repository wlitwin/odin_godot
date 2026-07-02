//gd:extends Node
//gd:class Probe
package export_types_scripts

// ----------------------------------------------------------------------------
// Probe — a breadth test for @export across the Variant-type spectrum + export hints.
//
// Every field below is surfaced to GDScript/Inspector through the generic core
// marshalling (per-type Variant<->type constructors). The struct-tag hint specs drive the
// Inspector editor widgets:
//   - range=MIN:MAX[:STEP]  -> a numeric slider
//   - enum=A:B:C            -> a dropdown of named int values
//   - multiline             -> a multi-line text box
//   - resource=Texture2D    -> a typed resource picker
// See docs/authoring-guide for the full type list + hint syntax.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Probe :: struct {
	owner:       gd.Node,
	// scalar atoms with hints
	health:      i32 `gd:"export,range=0:100:5"`, // ranged int (narrowed to i32)
	mode:        i32 `gd:"export,enum=Idle:Walk:Run"`, // enum-int dropdown
	description: gd.String `gd:"export,multiline"`, // multi-line text
	// math structs (whole-struct Variants, no narrowing)
	velocity:    gd.Vector3 `gd:"export"`,
	tint:        gd.Color `gd:"export"`,
	grid:        gd.Vector2i `gd:"export"`,
	// container / path / packed
	scores:      gd.Packed_Int32_Array `gd:"export"`,
	target:      gd.Node_Path `gd:"export"`,
	// typed resource picker
	texture:     gd.Object `gd:"export,resource=Texture2D"`,
	// typed arrays (tag form) — BOTH set from the scene file (regression: scene-assigned
	// typed-array exports used to crash inst_set during SceneState::instantiate; the
	// suite previously only exercised the Inspector/set() path).
	nums:        gd.Array `gd:"export,array=int"`,
	table:       gd.Array `gd:"export,array=Resource"`,
}
