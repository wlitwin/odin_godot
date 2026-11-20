package replay_scrapyard

import "core:fmt"
import "core:math"
import gd "godot:godot"
import rgd "godot:replay/godot"
import "godot:gdext"
import r "godot:replay"
import game "../shared/game"
import arena "../shared/arena"
import content "../shared/content"
import flow "../shared/flow"
import display "../shared/presentation"
import views "views"
import rt "godot:runtime"
import scenegd "godot:replay/godot/scene"

Textures :: struct {
    idle, run: [3]gd.Texture2d,
    zombies: [3]gd.Texture2d,
    floor, objects, weapons, ui: gd.Texture2d,
}


textures_load :: proc(t: ^Textures) -> bool {
    names := [3]string{"becca", "joe", "unknow"}

    for name, i in names {
        t.idle[i] = cast(gd.Texture2d)gd.load(fmt.ctprintf("res://assets/gz2/runner_%s_idle.png", name))
        t.run[i] = cast(gd.Texture2d)gd.load(fmt.ctprintf("res://assets/gz2/runner_%s_run.png", name))

        if t.idle[i] == nil || t.run[i] == nil {
            return false
        }
    }

    t.zombies[0] = cast(gd.Texture2d)gd.load("res://assets/gz2/zombie_puncher.png")
    t.zombies[1] = cast(gd.Texture2d)gd.load("res://assets/gz2/zombie_heavy.png")
    t.zombies[2] = cast(gd.Texture2d)gd.load("res://assets/gz2/zombie_cop.png")

    if t.zombies[0] == nil || t.zombies[1] == nil || t.zombies[2] == nil {
        return false
    }

    t.floor = cast(gd.Texture2d)gd.load("res://assets/gz2/bg_floor.png")
    t.objects = cast(gd.Texture2d)gd.load("res://assets/gz2/objects.png")
    t.weapons = cast(gd.Texture2d)gd.load("res://assets/gz2/weapons.png")
    t.ui = cast(gd.Texture2d)gd.load("res://assets/gz2/ui.png")
    return t.floor != nil && t.objects != nil && t.weapons != nil && t.ui != nil
}

release :: proc(texture: gd.Texture2d) {
    if texture != nil && gd.ref_counted_unreference(texture) {
        gdext.object_destroy(texture)
    }
}

textures_destroy :: proc(t: ^Textures) {
    for texture in t.idle {
        release(texture)
    }

    for texture in t.run {
        release(texture)
    }

    for texture in t.zombies {
        release(texture)
    }

    release(t.floor)
    release(t.objects)
    release(t.weapons)
    release(t.ui)
    t^ = {}
}

rect :: proc(parent: gd.Node, position, size: [2]f32, color: gd.Color) {
    node := gd.new_color_rect()
    gd.color_rect_set_color(node, color)
    gd.control_set_position(node, position, false)
    gd.control_set_size(node, size, false)
    gd.control_set_mouse_filter(node, .Mouse_Filter_Ignore)
    gd.add_child(parent, node)
}

build_arena :: proc(self: ^ReplayScrapyard, layout: arena.Layout) {
    if self.arena_node != nil {
        scenery_name(self.arena_node, "RetiredArena")
        gd.canvas_item_set_visible(self.arena_node, false)
        gd.node_queue_free(self.arena_node)
    }

    self.arena_node = gd.new_node2d()
    scenery_name(self.arena_node, "Arena")
    gd.add_child(self.world_node, self.arena_node)
    ground := gd.new_sprite2d()
    gd.sprite2d_set_texture(ground, self.textures.floor)
    gd.sprite2d_set_centered(ground, false)
    gd.sprite2d_set_region_enabled(ground, true)
    gd.sprite2d_set_region_rect(ground, {{0, 0}, {arena.WIDTH / 2, arena.HEIGHT / 2}})
    gd.canvas_item_set_texture_repeat(ground, .Texture_Repeat_Enabled)
    gd.node2d_set_scale(ground, {2, 2})
    gd.canvas_item_set_z_index(ground, -10)
    gd.add_child(self.arena_node, ground)
    scenery_dressing(self, layout.key)
    wall := gd.Color{0.28, 0.24, 0.20, 1}
    rect(self.arena_node, {0, 0}, {arena.WIDTH, 16}, wall)
    rect(self.arena_node, {0, arena.HEIGHT - 16}, {arena.WIDTH, 16}, wall)
    rect(self.arena_node, {0, 0}, {16, arena.HEIGHT}, wall)
    rect(self.arena_node, {arena.WIDTH - 16, 0}, {16, arena.HEIGHT}, wall)
    defs := arena.JUNK

    for cover in layout.covers {
        def := defs[cover.kind]
        node := gd.new_sprite2d()
        gd.sprite2d_set_texture(node, self.textures.objects)
        gd.sprite2d_set_region_enabled(node, true)
        gd.sprite2d_set_region_rect(
            node,
            {{f32(def.region[0]), f32(def.region[1])}, {f32(def.region[2]), f32(def.region[3])}},
        )
        gd.node2d_set_position(
            node,
            {f32(cover.x) + f32(cover.w) / 2, f32(cover.y) + f32(cover.h) / 2 + f32(def.art_dy)},
        )
        gd.node2d_set_scale(node, {2, 2})
        gd.add_child(self.arena_node, node)
    }

    self.gate = scenery_gate(self)
    self.arena_built, self.built_key = true, layout.key
}

runner_scenes_init :: proc(self: ^ReplayScrapyard) -> bool {
    for &view, i in self.rigs {
        node := scenegd.scene_instance(self.world_node, "res://entities/runner.tscn")
        report := scenegd.script_bind(
            &self.runner_bindings[i],
            cast(gd.Node2d)node,
            views.scrap_runner_view_replay_binding(),
        )

        if report.error != .None {
            content_report(&report)
            return false
        }

        view = self.runner_bindings[i].script
        scenery_name(view.owner, fmt.tprintf("Runner%d", i + 1))
        gd.canvas_item_set_visible(view.owner, false)
    }

    return true
}

paint :: proc(self: ^ReplayScrapyard, predicted, truth: ^r.Frame(game.World), dt: f64) {
    sample, ready := rgd.session_render_sample(self.session, .Observed, &self.render_cursor, combat_contact)
    if !ready {return}
    observed := interpolate_observation(&sample)
    w := &observed

    if !self.arena_built || self.built_key != w.layout.key {
        build_arena(self, w.layout)
        gd.print_str(fmt.tprintf("RSY_ARENA seed=%d floor=%d sum=%d", w.seed, w.floor, w.layout.checksum))
    }

    seat := rgd.session_seat(self.session)
    epoch := sample.scope.epoch
    self.bot_scene[0] = observed
    turret_bridge_paint(self, observed)
    paint_runner_views(self, &observed, epoch)
    camera_paint(self, &observed, seat)
    inside := seat > 0 && w.players[seat - 1].in_yard

    if seat == 0 {
        for player in w.players {
            inside = inside || player.in_yard
        }
    }

    gd.canvas_item_set_visible(self.world_node, inside)
    gd.canvas_item_set_visible(self.lobby, !inside)
    muster_paint(self, w, seat, inside)
    combat_paint(self, observed, predicted.state, seat, dt)
    abilities_paint(self, &observed, seat, dt)
    paint_ability_cooldowns(self, w, predicted.state.players[seat > 0 ? seat - 1 : 0], seat, inside)
    hud_present(
        self.hud,
        display.hud(observed, predicted.state.players[seat > 0 ? seat - 1 : 0], predicted.tick, seat, inside),
        gd.control_get_size(self.shop).y,
    )
    status := gameplay_status(w, predicted.state.players[seat > 0 ? seat - 1 : 0], seat, inside)
    shop_paint(self, &truth.state, predicted.state.players[seat > 0 ? seat - 1 : 0], inside && seat > 0)
    scenery_gate_paint(self, w, seat, dt)
    transitions_paint(self.transitions, inside ? flow.derive(w, sample.tick, seat) : flow.View{})
    status = session_status(self, w, seat, inside, status)
    gd.set_string(self.status, "text", status)
    paint_profile_status(self)
    flow_paint(self, w)
}

combat_contact :: proc(e: game.Event) -> bool {
    return e.kind == .Wall || e.kind == .Blast || e.kind == .Hit || e.kind == .Hurt
}

interpolate_observation :: proc(sample: ^rgd.Render_Sample(game.World)) -> (world: game.World) {
    a, b := &sample.from.state, &sample.to.state
    world = sample.alpha >= 1 ? b^ : a^
    if sample.from.tick == sample.to.tick || sample.alpha >= 1 ||
       a.run != b.run || a.floor != b.floor || a.layout.key != b.layout.key {return}
    for &player, i in world.players {
        next := b.players[i]
        if player.connected && next.connected && player.generation == next.generation && player.warp == next.warp {
            player.position += (next.position - player.position) * sample.alpha
        }
    }
    blend_positions :: proc(from, to: ^r.Pool($T,$N), alpha: f32) {
        for &entity, i in from.values {
            if from.alive[i] && to.alive[i] && from.generations[i] == to.generations[i] {
                entity.position += (to.values[i].position - entity.position) * alpha
            }
        }
    }
    blend_positions(&world.mobs, &b.mobs, sample.alpha)
    blend_positions(&world.drops, &b.drops, sample.alpha)
    blend_positions(&world.shots, &b.shots, sample.alpha)
    blend_positions(&world.lobs, &b.lobs, sample.alpha)
    return
}

paint_runner_views :: proc(self: ^ReplayScrapyard, world: ^game.World, epoch: u64) {
    for player, i in world.players {
        scenegd.script_present(
            &self.runner_bindings[i],
            display.runner(world^, player, player.position, epoch, u16(i+1)),
        )
    }
}

paint_ability_cooldowns :: proc(
    self: ^ReplayScrapyard,
    w: ^game.World,
    predicted_player: game.Player,
    seat: u16,
    inside: bool,
) {
    player := predicted_player
    gd.set_string(self.ability_label, "text", "")

    if inside && seat > 0 {
        first, second := game.ability_id(&player, 0), game.ability_id(&player, 1)
        gd.set_string(
            self.ability_label,
            "text",
            fmt.ctprintf(
                "Q  %s  %.1fs   |   E  %s  %.1fs",
                content.name_string(&w.catalog.abilities[first].name),
                f32(player.ability_cd[0].remaining) / 60,
                content.name_string(&w.catalog.abilities[second].name),
                f32(player.ability_cd[1].remaining) / 60,
            ),
        )
    }
}

unit :: proc(vector: [2]f32) -> [2]f32 {
    length := math.sqrt(vector[0] * vector[0] + vector[1] * vector[1])
    return length > 0 ? vector / length : [2]f32{}
}

runner_scenes_close :: proc(self: ^ReplayScrapyard) {
    for &binding in self.runner_bindings {
        scenegd.script_release(&binding)
    }

    self.rigs = {}
}
