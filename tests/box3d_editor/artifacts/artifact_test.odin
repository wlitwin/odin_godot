package box3d_editor_artifact_native_test

import "core:encoding/json"
import "core:fmt"
import "core:testing"
import a "godot:box3d/authoring"
import b "godot:box3d"
import f "godot:tests/box3d_authoring/pure"

@(test)
detached_loaded_artifact_builds_real_six_shapes_after_all_source_storage_gone :: proc(t: ^testing.T) {
    input: f.Fixture
    f.fixture_init(&input)
    bytes, error := json.marshal(input.scene)
    testing.expect(t, error == nil)

    if error != nil {
        return
    }

    artifact, p := a.artifact_create(bytes, a.import_metadata("res://authored-scene.tscn", "fixture-v1"))
    delete(bytes)
    testing.expect_value(t, p.error, a.Artifact_Error.None)

    if p.error != .None {
        return
    }

    loaded, lp := a.artifact_load(artifact.encoded)
    a.artifact_destroy(&artifact)
    testing.expect_value(t, lp.error, a.Artifact_Error.None)

    if lp.error != .None {
        return
    }

    input = {}
    built, bp := a.build(&loaded.scene, 0x454449544f523501)
    a.artifact_destroy(&loaded)

    defer {
        testing.expect_value(t, a.built_destroy(&built), b.Status.Ok)
        engine, es := b.engine_allocation_stats()
        wrapper, ws := b.snapshot_allocation_stats()
        testing.expect(t, es == .Ok && ws == .Ok && engine.live_bytes == 0 && wrapper.live_bytes == 0)
        fmt.printf("EDITOR_ARTIFACT_CLEANUP native=%d wrapper=%d\n", engine.live_bytes, wrapper.live_bytes)
    }

    testing.expect_value(t, bp.error, a.Error.None)

    if bp.error != .None {
        return
    }

    counts, cs := b.world_counters(built.world)
    testing.expect(t, cs == .Ok && counts.body_count == 8 && counts.shape_count == 8)
    testing.expect_value(t, b.world_step_fixed(built.world), b.Status.Ok)
    fmt.println(
        "EDITOR_ARTIFACT_NATIVE six_shapes=6 sensor=1 transformed_box=1 source_free=true no_editor_tick_owner=true",
    )
}
