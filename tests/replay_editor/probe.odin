package replay_scrapyard
import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import rt "godot:runtime"
import "godot:gdext"
import r "godot:replay"
import rgd "godot:replay/godot"
import d "godot:replay/definitions"
import v "godot:replay/view"
import views "views"
import game "../shared/game"
import display "../shared/presentation"
import content "../shared/content"
import scenegd "godot:replay/godot/scene"

@(gd_method)
replay_scrapyard_editor_binding_check :: proc(self: ^ReplayScrapyard, path: string, expected: bool) -> bool {
    // A directly loaded scene must already own a valid appearance. Archetype
    // pools instead validate components before their configure callback runs.
    config := scenegd.Script_View(display.Mob_View, views.ScrapEnemyView) {
        present = views.enemy_view_present,
        validate = proc(script: ^views.ScrapEnemyView) -> d.Report {
            if report := views.enemy_view_validate(script); report.error != .None {
                return report
            }

            if !views.enemy_style_valid(script.skin) {
                return d.problem(.Invalid, "$appearance", "invalid ScrapEnemyStyle frames, texture or timing")
            }

            return {}
        },
        retired = views.enemy_view_retire,
    }
    pool: scenegd.View_Pool2(game.Mob, display.Mob_View, ^views.ScrapEnemyView)

    if !scenegd.view_pool_load(
        &pool,
        self.world_node,
        fmt.ctprintf("%s", path),
        1,
        scenegd.script_view_binding(&config),
    ) {
        return false
    }

    defer scenegd.view_pool_destroy(&pool)
    items := [1]v.View_Item(game.Mob, display.Mob_View) {
        {
            handle = {0, 1},
            source = .Observed,
            view = {scale = {1, 1}, color = {1, 1, 1, 1}, value = {hp = 10, scale = 2, tint = {1, 1, 1, 1}}},
        },
    }
    result := scenegd.view_pool_present(&pool, {1, 0}, items[:])

    if !expected {
        return result == .Attach && pool.nodes.count == 0
    }

    if result != .None || pool.entries[0].rig == nil || !pool.entries[0].rig.ready || !pool.entries[0].rig.painted {
        return false
    }

    first := pool.entries[0].rig

    if scenegd.view_pool_present(&pool, {2, 0}, items[:]) != .None {
        return false
    }

    return first.retired && first != pool.entries[0].rig
}

@(gd_method)
replay_scrapyard_editor_catalog_hash :: proc(self: ^ReplayScrapyard) -> gd.Int {
    before, available := rgd.session_authority_state(self.session)
    candidate, ok := content_load()
    after, still := rgd.session_authority_state(self.session)
    assert(available == still && reflect.equal(before, after))
    return ok ? gd.Int(content.fingerprint(candidate)) : -1
}

@(gd_method)
replay_scrapyard_editor_registry_count :: proc(self: ^ReplayScrapyard) -> gd.Int {
    owner: scenegd.Archetype_Assets(content.Mob)
    defer scenegd.archetype_assets_destroy(&owner)
    before, available := rgd.session_authority_state(self.session)
    ok := enemy_archetypes_load(&owner)
    after, still := rgd.session_authority_state(self.session)

    if available != still || !reflect.equal(before, after) {
        return -2
    }

    if !ok {
        return -1
    }

    // The loader has released every candidate Resource. The registry must still
    // own live scenes/appearances and support independent scene instances.
    for slot in owner.registry.entries {
        if slot.present {
            node := gd.instantiate(slot.value.local.scene)

            if node == nil {
                return -3
            }

            gd.add_child(self.world_node, node)
            script := rt.script_of(node, views.ScrapEnemyView)
            style := rt.script_of(cast(gd.Object)slot.value.local.appearance, views.ScrapEnemyStyle)
            valid := script != nil && views.enemy_view_configure(script, style).error == .None
            gdext.object_destroy(node)

            if !valid {
                return -4
            }
        }
    }

    return gd.Int(owner.registry.count)
}
