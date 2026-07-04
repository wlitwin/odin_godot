//gd:extends Resource
//gd:class CaveLevelDef
package cavecrawl_scripts

// One FLOOR of the campaign, as a data asset (.tres): which scene is its
// stage, what the chest holds, how the waves come. The scene carries the
// authored HALF the wire never sees — backdrop, decoration, and the spawn
// MARKERS (ChestSpawn / DoorSpawn / Den1 / Den2) the host reads positions
// from. Designers add floors by making a scene + a .tres and dropping them
// in cave.tscn's inspector slots; no code changes.

import gd "godot:godot"

Level_Def :: struct {
	owner:       gd.Resource,
	scene:       ^gd.Resource `gd:"export,resource=PackedScene"`, // the floor's stage (markers + decoration), loaded LOCALLY by every peer
	gems:        gd.Int `gd:"export,range=0:99:1"`, // chest stock
	torches:     gd.Int `gd:"export,range=0:99:1"`,
	wave_counts: gd.Packed_Int32_Array `gd:"export"`, // dwellers per wave
	wave_rests:  gd.Packed_Int32_Array `gd:"export"`, // calm ticks after each wave clears
}
