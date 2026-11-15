package replay_godot_scene

import "core:math"
import "core:mem"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"

Audio_Cue :: struct {
    stream:   gd.Audio_Stream,
    position: [2]f32,
    gain_db:  f32,
    pitch:    f32,
    spatial:  bool,
}

Audio_Voice :: struct {
    world:   gd.Audio_Stream_Player2d,
    screen:  gd.Audio_Stream_Player,
    id:      r.Event_Id,
    slot:    u64,
    gain_db: f32,
    tagged:  bool,
}

Audio_Pool :: struct {
    allocator:                                    mem.Allocator,
    world, screen:                                []Audio_Voice,
    next_world, next_screen:                      int,
    volume:                                       f32,
    played, stopped, duplicates, refused, stolen: u64,
}

audio_pool_init :: proc(
    pool: ^Audio_Pool,
    parent: gd.Node,
    world_voices: int = 12,
    screen_voices: int = 3,
    allocator := context.allocator,
) -> bool {
    if parent == nil ||
       len(pool.world) != 0 ||
       len(pool.screen) != 0 ||
       world_voices < 1 ||
       screen_voices < 1 ||
       world_voices + screen_voices > 128 {
        return false
    }

    pool.allocator, pool.volume = allocator, 1
    pool.world = make([]Audio_Voice, world_voices, allocator)
    pool.screen = make([]Audio_Voice, screen_voices, allocator)

    for &voice in pool.world {
        voice.world = gd.new_audio_stream_player2d()
        gd.add_child(parent, voice.world)
        gd.audio_stream_player2d_set_max_distance(voice.world, 1100)
        gd.audio_stream_player2d_set_attenuation(voice.world, 1.2)
    }

    for &voice in pool.screen {
        voice.screen = gd.new_audio_stream_player()
        gd.add_child(parent, voice.screen)
    }

    return true
}

@(private)
audio_voice_stop :: proc(voice: ^Audio_Voice) {
    if voice.world != nil {
        gd.audio_stream_player2d_stop(voice.world)
        gd.audio_stream_player2d_set_stream(voice.world, nil)
    }

    if voice.screen != nil {
        gd.audio_stream_player_stop(voice.screen)
        gd.audio_stream_player_set_stream(voice.screen, nil)
    }

    voice.tagged = false
}

audio_pool_clear :: proc(pool: ^Audio_Pool) {
    for &voice in pool.world {
        audio_voice_stop(&voice)
    }

    for &voice in pool.screen {
        audio_voice_stop(&voice)
    }
}

audio_pool_destroy :: proc(pool: ^Audio_Pool) {
    audio_pool_clear(pool)

    for voice in pool.world {
        if voice.world != nil {
            gd.node_queue_free(voice.world)
        }
    }

    for voice in pool.screen {
        if voice.screen != nil {
            gd.node_queue_free(voice.screen)
        }
    }

    delete(pool.world, pool.allocator)
    delete(pool.screen, pool.allocator)
    pool^ = {}
}

@(private)
audio_voice_volume :: proc(voice: ^Audio_Voice, volume: f32) {
    db := volume <= 0 ? f32(-80) : voice.gain_db + 20 * math.log10(volume)

    if voice.world != nil {
        gd.audio_stream_player2d_set_volume_db(voice.world, gd.Float(db))
    }

    if voice.screen != nil {
        gd.audio_stream_player_set_volume_db(voice.screen, gd.Float(db))
    }
}

audio_pool_volume :: proc(pool: ^Audio_Pool, volume: f32) -> bool {
    if math.is_nan(volume) || math.is_inf(volume) || volume < 0 || volume > 1 {
        return false
    }

    pool.volume = volume

    for &voice in pool.world {
        audio_voice_volume(&voice, volume)
    }

    for &voice in pool.screen {
        audio_voice_volume(&voice, volume)
    }

    return true
}

// Streams are borrowed for the call; Godot's player retains its own reference.
// A full voice pool steals in round-robin order, keeping audio work bounded.
@(private)
audio_cue_valid :: proc(cue: Audio_Cue) -> bool {
    if cue.stream == nil ||
       cue.pitch <= 0 ||
       math.is_nan(cue.pitch) ||
       math.is_inf(cue.pitch) ||
       math.is_nan(cue.gain_db) ||
       math.is_inf(cue.gain_db) {
        return false
    }

    for value in cue.position {
        if math.is_nan(value) || math.is_inf(value) {
            return false
        }
    }

    return true
}

audio_play :: proc(pool: ^Audio_Pool, cue: Audio_Cue, id: r.Event_Id = {}, slot: u64 = 0) -> bool {
    if !audio_cue_valid(cue) {
        return false
    }

    voices := cue.spatial ? pool.world : pool.screen

    if len(voices) == 0 {
        return false
    }

    next := cue.spatial ? &pool.next_world : &pool.next_screen
    voice := &voices[next^]
    next^ = (next^ + 1) % len(voices)

    if voice.world != nil && gd.audio_stream_player2d_is_playing(voice.world) ||
       voice.screen != nil && gd.audio_stream_player_is_playing(voice.screen) {
        pool.stolen += 1
    }

    audio_voice_stop(voice)
    voice.id, voice.slot, voice.gain_db, voice.tagged = id, slot, cue.gain_db, id.epoch != 0
    audio_voice_volume(voice, pool.volume)

    if cue.spatial {
        gd.node2d_set_position(voice.world, cue.position)
        gd.audio_stream_player2d_set_stream(voice.world, cue.stream)
        gd.audio_stream_player2d_set_pitch_scale(voice.world, gd.Float(cue.pitch))
        gd.audio_stream_player2d_play(voice.world, 0)
    } else {
        gd.audio_stream_player_set_stream(voice.screen, cue.stream)
        gd.audio_stream_player_set_pitch_scale(voice.screen, gd.Float(cue.pitch))
        gd.audio_stream_player_play(voice.screen, 0)
    }

    pool.played += 1
    return true
}

// Begin consumes the event once. Confirm/Update never replay the clip. Cancel
// stops only voices still owned by this ID, leaving its consumption tombstone.
audio_change :: proc(
    pool: ^Audio_Pool,
    log: ^v.One_Shots,
    change: v.Change($T),
    cue: Audio_Cue,
    slot: u64 = 0,
) -> bool {
    if change.kind == .Begin {
        if !audio_cue_valid(cue) || len(cue.spatial ? pool.world : pool.screen) == 0 {
            return false
        }

        result := v.one_shot_note(log, change.occurrence.id, slot)

        if result == .Duplicate {
            pool.duplicates += 1
            return false
        }

        if result != .New {
            pool.refused += 1
            return false
        }

        return audio_play(pool, cue, change.occurrence.id, slot)
    }

    sets := [2][]Audio_Voice{pool.world, pool.screen}

    for voices in sets {
        for &voice in voices {
            if !voice.tagged || voice.id != change.occurrence.id || voice.slot != slot {
                continue
            }

            if change.kind == .Cancel {
                audio_voice_stop(&voice)
                pool.stopped += 1
            }

            if change.kind == .Update && voice.world != nil {
                gd.node2d_set_position(voice.world, cue.position)
            }
        }
    }

    return false
}
