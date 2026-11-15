package replay_physics

import "core:mem"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import r "godot:replay"

// Converts the immutable shared bake to this adapter's value configuration.
// Catalog geometry remains owned by Built_Scene/Image/Working, not Config.
// Existing spawn uses a neutral default Shape_Def; authored initial shape
// materials/filter/sensor flags are already present in the actual native world.
authoring_config :: proc(scene: ^ba.Baked_Scene) -> (Config, r.Error) {
    if scene == nil ||
       (scene.data.schema_version != ba.LEGACY_SCHEMA_VERSION && scene.data.schema_version != ba.SCHEMA_VERSION) ||
       len(scene.data.assets) == 0 ||
       len(scene.data.assets) > MAX_ASSETS {
        return {}, .Invalid_Config
    }

    cfg := Config {
        asset_id    = authoring_content_id(scene.content_hash),
        build_id    = b.build_fingerprint(),
        asset_count = u32(len(scene.data.assets)),
    }

    if cfg.asset_id == 0 || cfg.build_id == 0 {
        return {}, .Invalid_Config
    }

    for body in scene.data.bodies {
        if body.definition.type == .Dynamic {
            cfg.initial_dynamic_bodies += 1
        }
    }

    for asset, index in scene.data.assets {
        value := Asset {
            id           = asset.catalog_id,
            shape        = b.shape_def_default(),
            half_extents = asset.a,
            center_a     = asset.a,
            center_b     = asset.b,
            radius       = asset.radius,
        }

        switch asset.native_kind {
        case .Box:
            value.kind = .Box
        case .Sphere:
            value.kind = .Sphere
        case .Capsule:
            value.kind = .Capsule
        case .Hull:
            value.kind = .Hull
        case .Mesh:
            value.kind = .Mesh
        }

        cfg.assets[index] = value
    }

    if !valid_config(cfg) {
        return {}, .Invalid_Config
    }

    return cfg, .None
}

// Captures a complete initial checkpoint using the existing Replay provider.
// It borrows the native world; built remains owned by the caller. The returned
// checkpoint independently retains its immutable trusted catalog and geometry.
// Copy logical-map keys into ordinary Game values as needed, never native
// handles or Godot objects. Use the same Config/catalog with network_codec_init.
authoring_checkpoint :: proc(
    built: ^ba.Built_Scene,
    config: Config,
    frame: r.Frame($S),
    $E: typeid,
    epoch: u64 = 1,
    allocator: mem.Allocator = context.allocator,
    ownership: Owner_Context = {},
) -> (
    r.Complete_Checkpoint(S, E),
    r.Error,
) {
    if built == nil || built.world == 0 || config.asset_id != authoring_content_id(built.content_hash) {
        return {}, .Invalid_Config
    }

    return checkpoint_make(frame, E, built.world, config, epoch, allocator, ownership, &built.catalog)
}

@(private)
authoring_content_id :: proc(hash: [32]u8) -> u64 {
    value: u64

    for i in 0 ..< 8 {
        value |= u64(hash[i]) << uint(8 * i)
    }

    return value
}
