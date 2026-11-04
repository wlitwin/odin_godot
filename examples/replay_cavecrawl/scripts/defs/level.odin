//gd:extends Resource
//gd:class ReplayCaveLevelDef
package cave_definitions

import gd "godot:godot"

ReplayCaveLevelDef :: struct {
    owner:       gd.Resource,
    scene:       ^gd.Resource `gd:"export,resource=PackedScene"`,
    gems:        gd.Int `gd:"export,range=0:99:1"`,
    torches:     gd.Int `gd:"export,range=0:99:1"`,
    wave_counts: gd.Packed_Int32_Array `gd:"export"`,
    wave_rests:  gd.Packed_Int32_Array `gd:"export"`,
    /// Rectangle used by Replay's pure navigation model; keep it aligned with
    /// the scene's authored rift/navigation geometry.
    rift_min:    gd.Vector2 `gd:"export"`,
    rift_max:    gd.Vector2 `gd:"export"`,
}
