package box3d_authoring

import b "godot:box3d/types"

owned_bytes :: proc(scene: ^Baked_Scene) -> u64 {
    if scene == nil {
        return 0
    }

    n :=
        len(scene.data.namespace) +
        len(scene.data.bodies) * size_of(Baked_Body) +
        len(scene.data.shapes) * size_of(Baked_Shape) +
        len(scene._asset_storage) * size_of(Baked_Asset) +
        len(scene._resource_storage) * size_of(Baked_Resource)

    for body in scene.data.bodies {
        n += len(body.stable_key)
    }

    for shape in scene.data.shapes {
        n += len(shape.stable_key)
    }

    for resource in scene.data.resources {
        n += len(resource.stable_key)
    }

    n += len(scene.data.joints) * size_of(Baked_Joint) + len(scene.data.characters) * size_of(Baked_Character)

    for joint in scene.data.joints {
        n += len(joint.stable_key)
    }

    for character in scene.data.characters {
        n += len(character.stable_key)
    }

    for asset in scene.data.assets {
        n += len(asset.stable_key) + len(asset.vertices) * size_of(b.Vec3) + len(asset.indices) * size_of(u32)
    }

    return u64(n)
}
