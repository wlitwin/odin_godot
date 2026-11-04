//gd:extends Resource
//gd:class ScrapEnemyStyle
package scrap_views

import gd "godot:godot"

// Cosmetic authoring only. Gameplay numbers remain in data/mobs/*.tres.
ScrapEnemyStyle :: struct {
    owner: gd.Resource,
    texture: ^gd.Resource `gd:"export,resource=Texture2D"`,
    columns: gd.Int `gd:"export,range=1:32:1"`,
    walk_frames: gd.Int `gd:"export,range=1:32:1"`,
    attack_frames: gd.Int `gd:"export,range=1:32:1"`,
    idle_frames: gd.Int `gd:"export,range=1:32:1"`,
    death_frames: gd.Int `gd:"export,range=1:32:1"`,
    fps: f32 `gd:"export,range=1:60:1"`,
    death_fps: f32 `gd:"export,range=1:60:1"`,
    tint: gd.Color `gd:"export"`,
    region_position: gd.Vector2 `gd:"export"`,
    region_size: gd.Vector2 `gd:"export"`,
}

enemy_style_valid :: proc(style: ^ScrapEnemyStyle) -> bool {
    if style == nil ||
       style.texture == nil ||
       style.columns < 1 ||
       style.columns > 32 ||
       !(style.fps > 0 && style.fps <= 60) ||
       !(style.death_fps > 0 && style.death_fps <= 60) {
        return false
    }

    for count in ([4]gd.Int{style.walk_frames, style.attack_frames, style.idle_frames, style.death_frames}) {
        if count < 1 || count > style.columns {
            return false
        }
    }

    return true
}
