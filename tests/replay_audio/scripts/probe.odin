//gd:extends Node
//gd:class ReplayAudioProbe
package replay_audio_probe

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import scenegd "godot:replay/godot/scene"

ReplayAudioProbe :: struct {
    owner:   gd.Node,
    tone:    gd.Audio_Stream,
    until:   u64,
    done:    bool,
    capture: gd.Audio_Effect_Capture,
    held:    scenegd.Audio_Pool,
    mixed:   bool,
}

replay_audio_probe_ready :: proc(self: ^ReplayAudioProbe) {
    self.tone = cast(gd.Audio_Stream)gd.load("res://tone.wav")

    if self.tone == nil {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    if !exercise(self) {
        gd.print_str("REPLAY_AUDIO_FAIL playback contract")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    self.capture = gd.new_audio_effect_capture()
    gd.ref_counted_init_ref(self.capture)
    gd.audio_effect_capture_set_buffer_length(self.capture, 0.5)
    gd.audio_server_add_bus_effect(gd.singleton_audio_server(), 0, self.capture, -1)
    scenegd.audio_pool_init(&self.held, self.owner, 1, 1)
    scenegd.audio_play(&self.held, {stream = self.tone, pitch = 1, spatial = false})
    self.until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000
}

exercise :: proc(self: ^ReplayAudioProbe) -> bool {
    pool: scenegd.Audio_Pool

    if !scenegd.audio_pool_init(&pool, self.owner, 1, 1) {
        return false
    }

    defer scenegd.audio_pool_destroy(&pool)
    log: v.One_Shots
    v.one_shots_init(&log, 1, history = 4, per_tick = 4)
    defer v.one_shots_destroy(&log)
    cue := scenegd.Audio_Cue {
        stream   = self.tone,
        position = {10, 20},
        pitch    = 1,
        spatial  = true,
    }
    change := v.Change(u8) {
        kind = .Begin,
        occurrence = {id = {1, 1, 5, 1}},
    }
    bad := cue
    bad.pitch = 0

    if scenegd.audio_change(&pool, &log, change, bad) || !scenegd.audio_change(&pool, &log, change, cue) {
        return false
    }

    if scenegd.audio_change(&pool, &log, change, cue) || pool.played != 1 || pool.duplicates != 1 {
        return false
    }

    change.kind = .Confirm
    scenegd.audio_change(&pool, &log, change, cue)
    change.kind = .Update
    cue.position = {20, 30}
    scenegd.audio_change(&pool, &log, change, cue)

    if pool.played != 1 || gd.node2d_get_position(pool.world[0].world) != cue.position {
        return false
    }

    change.kind = .Cancel
    scenegd.audio_change(&pool, &log, change, cue)
    change.kind = .Begin

    if scenegd.audio_change(&pool, &log, change, cue) || pool.stopped != 1 {
        return false
    }

    change.occurrence.id.key = 2

    if !scenegd.audio_change(&pool, &log, change, cue) {
        return false
    }

    old := change
    change.occurrence.id.key = 3

    if !scenegd.audio_change(&pool, &log, change, cue) {
        return false
    }

    old.kind = .Cancel
    scenegd.audio_change(&pool, &log, old, cue)

    if pool.stopped != 1 || pool.world[0].id != change.occurrence.id || !pool.world[0].tagged {
        return false
    }

    if !scenegd.audio_pool_volume(&pool, 0.3) || scenegd.audio_pool_volume(&pool, 2) {
        return false
    }

    cue.spatial = false

    if !scenegd.audio_play(&pool, cue) {
        return false
    }

    if pool.played != 4 {
        return false
    }

    scenegd.audio_pool_clear(&pool)

    if pool.world[0].tagged || pool.screen[0].tagged {
        return false
    }

    gd.print_str(
        fmt.tprintf(
            "REPLAY_AUDIO_CONTRACT played=%d duplicates=%d stopped=%d",
            pool.played,
            pool.duplicates,
            pool.stopped,
        ),
    )
    return true
}

replay_audio_probe_process :: proc(self: ^ReplayAudioProbe, dt: f64) {
    if self.done || self.tone == nil {
        return
    }

    if !self.mixed {
        frames := gd.audio_effect_capture_get_frames_available(self.capture)

        if frames > 0 {
            buffer := gd.audio_effect_capture_get_buffer(self.capture, gd.Int(min(frames, 4096)))
            defer gd.free_packed_vector2_array(buffer)

            for i in 0 ..< gd.packed_vector2_array_size(&buffer) {
                sample := gd.packed_vector2_array_get(&buffer, i)

                if abs(sample.x) + abs(sample.y) > 0.0001 {
                    self.mixed = true
                    break
                }
            }
        }

        if self.mixed {
            gd.print_str("REPLAY_AUDIO_PCM_OK")
            scenegd.audio_pool_destroy(&self.held)
            gd.audio_server_remove_bus_effect(gd.singleton_audio_server(), 0, 0)
            gd.release_ref(self.capture)
            self.capture = nil
        } else if gd.time_get_ticks_msec(gd.singleton_time()) > self.until {
            gd.print_str("REPLAY_AUDIO_FAIL silent mixer")
            gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        }

        return
    }

    if gd.ref_counted_get_reference_count(self.tone) == 1 {
        gd.release_ref(self.tone)
        self.tone = nil
        self.done = true
        gd.print_str("REPLAY_AUDIO_OK")
        gd.scene_tree_quit(gd.get_tree(self.owner), 0)
    } else if gd.time_get_ticks_msec(gd.singleton_time()) > self.until {
        gd.print_str("REPLAY_AUDIO_FAIL retained stream")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
    }
}

replay_audio_probe_exit_tree :: proc(self: ^ReplayAudioProbe) {
    scenegd.audio_pool_destroy(&self.held)

    if self.capture != nil {
        gd.audio_server_remove_bus_effect(gd.singleton_audio_server(), 0, 0)
        gd.release_ref(self.capture)
        self.capture = nil
    }

    gd.release_ref(self.tone)
    self.tone = nil
}
