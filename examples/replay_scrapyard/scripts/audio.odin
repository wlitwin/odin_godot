package replay_scrapyard

import "core:fmt"
import "core:math"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/game"
import sound "../shared/audio"
import flow "../shared/flow"
import scenegd "godot:replay/godot/scene"

Audio :: struct {
    route: scenegd.Audio_Route(net.Net_Event(game.Event)),
    observer: sound.Observer,
    streams: [sound.Sfx]gd.Audio_Stream,
    music: [5]gd.Audio_Stream,
    deck: [2]gd.Audio_Stream_Player,
    level: [2]f32,
    active, track: int,
    ready, scoped: bool,
    view_reset: u64,
    volume: f32,
    shake, shake_clock: f32,
    played: [sound.Sfx]u64,
    jitter: u32,
}

audio_ready :: proc(self: ^ReplayScrapyard) -> bool {
    a := &self.audio[0]
    a.track = -1
    a.volume = 0.8

    if scrap_int("RSY_AUDIO", 1) == 0 || scrap_param("RSY_ROLE", "") == "server" {
        return true
    }

    if !scenegd.audio_route_init_change(
        &a.route,
        self.world_node,
        1,
        audio_project,
        self,
        history = 1024,
        per_tick = net.WIRE_EVENTS,
    ) {
        return false
    }

    for cue in sound.Sfx {
        a.streams[cue] = cast(gd.Audio_Stream)gd.load(fmt.ctprintf("res://assets/sfx/%s.wav", sound.file_name(cue)))

        if a.streams[cue] == nil {
            return false
        }
    }

    for &deck in a.deck {
        deck = gd.new_audio_stream_player()
        gd.add_child(self.owner, deck)
    }

    a.ready = true
    audio_volume(self, 0.8)
    return true
}

audio_volume :: proc(self: ^ReplayScrapyard, volume: f32) {
    self.audio[0].volume = volume
    scenegd.audio_pool_volume(&self.audio[0].route.pool, volume)
}

audio_cue :: proc(self: ^ReplayScrapyard, cue: sound.Cue) -> scenegd.Audio_Cue {
    return {
        stream = self.audio[0].streams[cue.kind],
        position = cue.position,
        gain_db = sound.gain(cue.kind),
        pitch = 1,
        spatial = cue.spatial,
    }
}

audio_direct :: proc(self: ^ReplayScrapyard, cue: sound.Cue) {
    if !self.audio[0].ready {
        return
    }

    value := audio_cue(self, cue)

    if cue.spatial {
        a := &self.audio[0]
        a.jitter = a.jitter * 1664525 + 1013904223
        value.pitch = 0.92 + f32(a.jitter >> 16 & 255) / 255 * 0.16
    }

    if scenegd.audio_play(&self.audio[0].route.pool, value) {
        self.audio[0].played[cue.kind] += 1
    }

    self.audio[0].shake = min(self.audio[0].shake + cue.jolt, 8)
}

audio_prepare :: proc(self: ^ReplayScrapyard) {
    a := &self.audio[0]

    if !a.ready || !self.session.ready {
        return
    }

    epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
    baseline := self.session.authority ? u64(0) : self.session.client.journal.baseline

    if !a.scoped || epoch != a.route.ledger.epoch {
        if self.session.authority {
            baseline = self.session.server.timeline.head

            for change in self.session.changes[:self.session.change_count] {
                if change.kind == .Begin && change.occurrence.id.epoch == epoch && change.occurrence.id.tick > 0 {
                    baseline = min(baseline, change.occurrence.id.tick - 1)
                }
            }
        }

        if epoch == a.route.ledger.epoch {
            scenegd.audio_route_retire(&a.route, baseline)
        } else {
            scenegd.audio_route_epoch(&a.route, epoch, baseline)
        }

        scenegd.audio_pool_clear(&a.route.pool)
        a.observer = {}
        a.scoped = true
    }

    if !self.session.authority && self.session.client.view_reset != a.view_reset {
        a.observer = {}
        a.view_reset = self.session.client.view_reset
        scenegd.audio_pool_clear(&a.route.pool)
    }

    frontier :=
        self.session.authority ? self.session.server.timeline.head : min(self.session.client.journal.confirmed, self.session.client.journal.watch_tick)
    floor := max(baseline, frontier > 512 ? frontier - 512 : 0)

    if floor > a.route.ledger.floor {
        scenegd.audio_route_retire(&a.route, floor)
    }
}

// Full change context preserves deterministic pitch and historical wound lookup.
audio_project :: proc(raw: rawptr, change: v.Change(net.Net_Event(game.Event))) -> (scenegd.Audio_Cue, bool) {
    self := cast(^ReplayScrapyard)raw

    if change.occurrence.value.kind != .Gameplay {
        return {}, false
    }

    event := change.occurrence.value.value
    cue, ok := sound.gameplay(event)

    if !ok {
        return {}, false
    }

    value := audio_cue(self, cue)
    id := change.occurrence.id

    if event.kind == .Hurt && (change.kind == .Begin || change.kind == .Update) {
        wound, found := presentation_wound(self, event, id)

        if !found {
            return {}, false
        }

        value.position = wound.victim
    }

    value.pitch = .92 + f32((id.tick ~ id.source ~ id.key) * 1664525 >> 16 & 255) / 255 * .16
    return value, true
}

audio_event :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
    a := &self.audio[0]

    if !a.ready {
        return
    }

    if scenegd.audio_route_change(&a.route, change) {
        event := change.occurrence.value.value
        cue, _ := sound.gameplay(event)
        a.played[cue.kind] += 1

        if event.kind == .Hurt && event.seat == rgd.session_seat(self.session) || event.kind == .Blast {
            a.shake = min(a.shake + 4, 8)
        }
    }
}

audio_frame :: proc(self: ^ReplayScrapyard, dt: f64) {
    a := &self.audio[0]

    if !a.ready {
        return
    }

    world: ^game.World
    frame, ok := rgd.session_authority_state(self.session)

    if ok {
        world = &frame.state
        epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
        cues: [64]sound.Cue
        count := sound.observe(&a.observer, epoch, &frame, cues[:])

        for cue in cues[:count] {
            audio_direct(self, cue)
        }
    }

    want := sound.music_track(world)

    if want != a.track {
        if a.music[want] == nil {
            paths := [5]cstring {
                "res://assets/bgm/bgm-menu.mp3",
                "res://assets/bgm/bgm-combat-1.mp3",
                "res://assets/bgm/bgm-combat-2.mp3",
                "res://assets/bgm/bgm-combat-3.mp3",
                "res://assets/bgm/bgm-combat-over.mp3",
            }
            a.music[want] = cast(gd.Audio_Stream)gd.load(paths[want])

            if a.music[want] != nil {
                gd.audio_stream_mp3_set_loop(cast(gd.Audio_Stream_Mp3)a.music[want], true)
            }
        }

        if a.music[want] != nil {
            a.active = 1 - a.active
            a.track = want
            a.level[a.active] = 0
            gd.audio_stream_player_set_stream(a.deck[a.active], a.music[want])
            gd.audio_stream_player_set_volume_db(a.deck[a.active], -80)
            gd.audio_stream_player_play(a.deck[a.active], 0)
            gd.print_str(fmt.tprintf("RSY_MUSIC track=%d", want))
        }
    }

    for &level, i in a.level {
        level = i == a.active ? min(level + f32(dt) * 1.1, 1) : max(level - f32(dt) * 1.1, 0)
        gain := level * a.volume
        gd.audio_stream_player_set_volume_db(
            a.deck[i],
            gd.Float(gain <= 0.001 ? f32(-80) : -8 + 20 * math.log10(gain)),
        )

        if i != a.active && level <= 0.001 {
            gd.audio_stream_player_stop(a.deck[i])
        }
    }

    a.shake = max(0, a.shake - f32(dt) * 20)
    a.shake_clock += f32(dt)
    amount := self.settings[0].value.shake_off ? f32(0) : a.shake
    gd.camera2d_set_offset(self.camera, {math.cos(a.shake_clock * 97) * amount, math.sin(a.shake_clock * 71) * amount})
}

audio_close :: proc(self: ^ReplayScrapyard) {
    a := &self.audio[0]
    scenegd.audio_route_destroy(&a.route)

    for deck in a.deck {
        if deck != nil {
            gd.audio_stream_player_stop(deck)
            gd.audio_stream_player_set_stream(deck, nil)
        }
    }

    for stream in a.streams {
        gd.release_ref(stream)
    }

    for stream in a.music {
        gd.release_ref(stream)
    }

    a^ = {}
}
