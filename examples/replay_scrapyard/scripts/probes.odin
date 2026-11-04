package replay_scrapyard

import gd "godot:godot"
import r "godot:replay"
import a "godot:replay/assets"
import rgd "godot:replay/godot"
import dg "godot:replay/telemetry"
import sc "godot:replay/schema"
import game "../shared/game"
import content "../shared/content"

@(gd_method)
replay_scrapyard_probe :: proc(self: ^ReplayScrapyard, name: string, wanted: gd.Int) -> gd.Int {
    field := name
    frame, ok := rgd.session_authority_state(self.session)
    seat := int(clamp(wanted, 1, game.SEATS)) - 1
    player := frame.state.players[seat]

    if value, found := probe_network(self, field, wanted); found {
        return value
    }

    if value, found := probe_persistence(self, field); found {
        return value
    }

    if value, found := probe_recovery(self, field); found {
        return value
    }

    if value, found := probe_presentation(self, field); found {
        return value
    }

    switch field {
    case "ready":
        return gd.Int(ok)
    case "projectiles":
        return gd.Int(frame.state.shots.count)
    case "props":
        count := gd.Int(0)

        for alive, i in frame.state.mobs.alive {
            if alive &&
               frame.state.mobs.values[i].hp > 0 &&
               frame.state.catalog.mobs[frame.state.mobs.values[i].kind].prop {
                count += 1
            }
        }

        return count
    case "stage":
        return gd.Int(frame.state.stage)
    case "leader":
        return gd.Int(frame.state.host)
    case "head":
        return gd.Int(frame.tick)
    case "seed":
        return gd.Int(frame.state.seed)
    case "floor":
        return gd.Int(frame.state.floor)
    case "players":
        count := gd.Int(0)

        for p in frame.state.players {
            if p.connected {
                count += 1
            }
        }

        return count
    case "in_yard":
        return gd.Int(player.in_yard)
    case "x":
        return gd.Int(player.position[0])
    case "y":
        return gd.Int(player.position[1])
    case "shown_x":
        return gd.Int(gd.node2d_get_position(self.rigs[seat].owner).x)
    case "look":
        return gd.Int(player.profile.look)
    case "iron":
        return gd.Int(player.in_yard ? player.gun_id : player.profile.iron)
    case "marked_ready":
        return gd.Int(player.profile.ready)
    case "dashes":
        return gd.Int(player.dashes)
    case "fx_mask":
        bits := gd.Int(0)

        for e in player.fx {
            if e.kind != 0 {
                bits |= gd.Int(1) << e.kind
            }
        }

        return bits
    case "mob_fx":
        index := int(clamp(wanted, 1, game.MAX_MOBS)) - 1
        bits := gd.Int(0)

        if frame.state.mobs.alive[index] {
            for e in frame.state.mobs.values[index].fx {
                if e.kind != 0 {
                    bits |= gd.Int(1) << e.kind
                }
            }
        }

        return bits
    case "mob_hp":
        return gd.Int(frame.state.mobs.values[int(clamp(wanted, 1, game.MAX_MOBS)) - 1].hp)
    case "zone_left":
        for alive, i in frame.state.zones.alive {
            if alive {
                return gd.Int(frame.state.zones.values[i].left)
            }
        }

        return 0
    case "gun_damage":
        return gd.Int(frame.state.catalog.guns[int(clamp(wanted, 0, content.MAX_GUNS - 1))].damage)
    case "catalog_mob_hp":
        return gd.Int(frame.state.catalog.mobs[int(clamp(wanted, 0, content.MAX_MOBS - 1))].hp)
    case "gun_count":
        return gd.Int(frame.state.catalog.gun_count)
    case "ability_count":
        return gd.Int(frame.state.catalog.ability_count)
    case "spray_bytes":
        return gd.Int(player.spray.image.bytes)
    case "asset_received":
        return gd.Int(self.assets[0].mesh.stats.rx_bytes)
    case "asset_installed":
        return gd.Int(self.assets[0].mesh.stats.installed)
    case "asset_requested":
        return gd.Int(self.assets[0].mesh.stats.requests)
    case "asset_rejected":
        return gd.Int(self.assets[0].mesh.stats.rejected)
    case "spray_cached":
        return gd.Int(a.cache_has(&self.assets[0].cache, player.spray.image))
    case "spray_stamp":
        return gd.Int(player.spray.stamp)
    case "spray_x":
        return gd.Int(player.spray.position[0])
    case "spray_y":
        return gd.Int(player.spray.position[1])
    case "spray_visible":
        return gd.Int(gd.canvas_item_is_visible(self.spray_rigs[seat].sprite))
    case "spray_pending":
        return gd.Int(gd.canvas_item_is_visible(self.spray_rigs[seat].marker))
    case "spray_local_bytes":
        return gd.Int(self.spray_local[0].ref.bytes)
    case "spray_storing":
        return gd.Int(self.spray_local[0].web.phase == .Checking || self.spray_local[0].web.phase == .Writing)
    case "spray_revision":
        return gd.Int(self.spray_local[0].web.revision)
    case "asset_installs":
        return gd.Int(self.assets[0].mesh.stats.installed)
    case "asset_tx":
        return gd.Int(self.assets[0].mesh.stats.tx_bytes)
    case "asset_rx":
        return gd.Int(self.assets[0].mesh.stats.rx_bytes)
    case "meta_claimed":
        return gd.Int(player.meta_claimed)
    case "run":
        return gd.Int(frame.state.run)
    case "clears":
        return gd.Int(frame.state.clears)
    case "wave":
        return gd.Int(frame.state.director.wave)
    case "pending":
        return gd.Int(frame.state.director.pending)
    case "director_alive":
        return gd.Int(frame.state.director.alive)
    case "rest_until":
        return gd.Int(frame.state.director.rest_until)
    case "spawn_index":
        return gd.Int(frame.state.spawn_index)
    case "depart":
        return gd.Int(frame.state.depart.left)
    case "over_until":
        return gd.Int(frame.state.over_until)
    case "parts":
        return gd.Int(player.parts)
    case "boost_damage":
        return gd.Int(player.boost_damage)
    case "boost_rate":
        return gd.Int(player.boost_rate)
    case "boost_speed":
        return gd.Int(player.boost_speed)
    case "revives":
        return gd.Int(player.revives)
    case "revive_progress":
        return gd.Int(player.revive.elapsed)
    case "scrap":
        return gd.Int(player.scrap)
    case "drops":
        return gd.Int(frame.state.drops.count)
    case "casts":
        return gd.Int(player.casts)
    case "ability0":
        return gd.Int(player.profile.abilities[0])
    case "ability1":
        return gd.Int(player.profile.abilities[1])
    case "cd0":
        return gd.Int(player.ability_cd[0].remaining)
    case "cd1":
        return gd.Int(player.ability_cd[1].remaining)
    case "lobs":
        return gd.Int(frame.state.lobs.count)
    case "landed":
        return gd.Int(frame.state.lobs_landed)
    case "zones":
        return gd.Int(frame.state.zones.count)
    case "zones_spawned":
        return gd.Int(frame.state.zones_spawned)
    case "zone_pulses":
        return gd.Int(frame.state.zone_pulses)
    case "spits":
        return gd.Int(frame.state.spits)
    case "pops":
        return gd.Int(frame.state.pops)
    case "slams":
        return gd.Int(frame.state.slams)
    case "adds":
        return gd.Int(frame.state.adds)
    case "barrels":
        return gd.Int(frame.state.barrel_blasts)
    case "defeated":
        return gd.Int(frame.state.defeated)
    case "status_applied":
        return gd.Int(frame.state.status_applied)
    case "reactions":
        return gd.Int(frame.state.reactions)
    case "dot_pulses":
        return gd.Int(frame.state.dot_pulses)
    case "cores":
        return gd.Int(player.cores)
    case "historical_queries":
        return gd.Int(player.historical_queries)
    case "rail_queries":
        return gd.Int(player.rail_queries)
    case "rejected_queries":
        return gd.Int(player.rejected_queries)
    case "query_status":
        return gd.Int(player.last_query)
    case "judged_tick":
        return gd.Int(player.last_judged)
    case "healed":
        return gd.Int(player.healed)
    case "blasts":
        return gd.Int(player.blasts)
    case "shots":
        return gd.Int(player.shots)
    case "ammo":
        return gd.Int(player.gun.ammo)
    case "gun_mode":
        return gd.Int(player.gun.mode)
    case "hp":
        return gd.Int(player.hp)
    case "kills":
        return gd.Int(player.kills)
    case "damage":
        return gd.Int(player.damage)

    case "mobs":
        count := gd.Int(0)

        for alive, i in frame.state.mobs.alive {
            if alive && frame.state.mobs.values[i].hp > 0 {
                count += 1
            }
        }

        return count
    case:
        return -1
    }
}

@(gd_method)
replay_scrapyard_probe_hash :: proc(self: ^ReplayScrapyard, tick: gd.Int) -> gd.Int {
    if !self.session.ready || tick < 0 {
        return -1
    }

    f: r.Frame(game.World)
    found := false

    if self.session.authority {
        value, available := r.read(&self.session.server.timeline, u64(tick))
        f = value
        found = available
    } else {
        c := &self.session.client
        at := int(u64(tick) % u64(c.cfg.history))

        if c.observed_valid[at] && c.observed[at].tick == u64(tick) {
            f = c.observed[at]
            found = true
        }
    }

    if !found {
        return -1
    }

    codec := self.session.authority ? &self.session.server.codecs.state : &self.session.client.codecs.state
    bytes := make([]u8, codec.wire_size, context.temp_allocator)

    if sc.encode(codec, f.state, bytes).error != .None {
        return -1
    }

    return gd.Int(sc.digest(bytes) & 0x7fff_ffff_ffff_ffff)
}

probe_network :: proc(self: ^ReplayScrapyard, field: string, wanted: gd.Int) -> (gd.Int, bool) {
    switch field {
    case "ping_known":
        return gd.Int(wanted > 0 && wanted <= game.SEATS && dg.read(&self.diagnostics[0], u16(wanted)).known), true
    case "ping_ms":
        return (wanted > 0 && wanted <= game.SEATS ? gd.Int(dg.read(&self.diagnostics[0], u16(wanted)).round_trip_ms) : -1),
            true
    case "ping_epoch":
        return gd.Int(self.diagnostics[0].scope.epoch), true

    case "frag_rejected":
        return gd.Int(self.session.rtc.fragments.stats.rejected), true
    case "facts":
        return gd.Int(self.session.client.facts_contiguous), true
    case "confirmed":
        return gd.Int(
                self.session.authority ? self.session.server.timeline.confirmed : self.session.client.timeline.confirmed,
            ),
            true
    case "predhead":
        return gd.Int(self.session.client.timeline.head), true
    case "pending_snapshot":
        return self.session.client.has_pending ? gd.Int(self.session.client.pending.frame.tick) : -1, true
    case "fullsnaps":
        return gd.Int(
                self.session.authority ? self.session.server.stats.full_snapshots : self.session.client.stats.full_snapshots,
            ),
            true
    case "deltasnaps":
        return gd.Int(
                self.session.authority ? self.session.server.stats.delta_snapshots : self.session.client.stats.delta_snapshots,
            ),
            true
    case "badacks":
        return gd.Int(self.session.server.stats.rejected_acks), true
    case "phase":
        return self.session.authority ? -1 : gd.Int(self.session.client.phase), true
    case "resyncs":
        return gd.Int(self.session.client.stats.resyncs), true
    case "watch_catchups":
        return gd.Int(self.session.client.stats.watch_catchups), true
    case "resync_reason":
        return gd.Int(self.session.client.resync_notice.reason), true
    case "large_snapshots":
        return gd.Int(self.session.server.stats.large_reliable_snapshots), true
    case "fragmented_snapshots":
        return gd.Int(self.session.server.stats.fragmented_snapshots), true
    case "reuse_enabled":
        return gd.Int(!self.session.authority && self.session.client.reuse_equal_corrections), true
    case "reused_correction_ticks":
        return self.session.authority ? 0 : gd.Int(self.session.client.stats.reused_correction_ticks), true
    case "lz4_snapshots":
        return gd.Int(
                self.session.authority ? self.session.server.stats.lz4_snapshots : self.session.client.stats.lz4_snapshots,
            ),
            true
    case "snapshot_parts_sent":
        return gd.Int(self.session.server.stats.snapshot_parts_sent), true
    case "snapshot_parts_received":
        return gd.Int(self.session.client.stats.snapshot_parts_received), true
    case "snapshot_parity_sent":
        return gd.Int(
                self.session.authority ? self.session.server.stats.snapshot_parity_sent : self.session.client.stats.snapshot_parity_sent,
            ),
            true
    case "snapshot_parity_received":
        return gd.Int(
                self.session.authority ? self.session.server.stats.snapshot_parity_received : self.session.client.stats.snapshot_parity_received,
            ),
            true
    case "snapshot_parity_bytes":
        return gd.Int(
                self.session.authority ? self.session.server.stats.snapshot_parity_bytes : self.session.client.stats.snapshot_parity_bytes,
            ),
            true
    case "snapshot_shards_recovered":
        return gd.Int(
                self.session.authority ? self.session.server.stats.snapshot_shards_recovered : self.session.client.stats.snapshot_shards_recovered,
            ),
            true
    case "snapshot_parts_expired":
        return gd.Int(self.session.client.stats.snapshot_parts_expired), true
    case "shuffled_snapshots":
        return gd.Int(
                self.session.authority ? self.session.server.stats.shuffled_snapshots : self.session.client.stats.shuffled_snapshots,
            ),
            true
    case "shuffle_attempts":
        return gd.Int(
                self.session.authority ? self.session.server.stats.shuffle_attempts : self.session.client.stats.shuffle_attempts,
            ),
            true
    case "shuffle_bytes_saved":
        return gd.Int(
                self.session.authority ? self.session.server.stats.shuffle_bytes_saved : self.session.client.stats.shuffle_bytes_saved,
            ),
            true
    case "snapshot_every":
        return gd.Int(
                self.session.authority ? self.session.server.cfg.snapshot_every : self.session.client.cfg.snapshot_every,
            ),
            true
    case "snapshot_latest":
        return gd.Int(self.session.client.snapshot_latest), true
    case "action_copy_batches":
        return gd.Int(
                self.session.authority ? self.session.server.stats.action_copy_batches : self.session.client.stats.action_copy_batches,
            ),
            true
    case "action_copies":
        return gd.Int(
                self.session.authority ? self.session.server.stats.action_copies : self.session.client.stats.action_copies,
            ),
            true
    case "action_copy_bytes":
        return gd.Int(
                self.session.authority ? self.session.server.stats.action_copy_bytes : self.session.client.stats.action_copy_bytes,
            ),
            true
    case "action_copy_oversize":
        return gd.Int(
                self.session.authority ? self.session.server.stats.action_copy_oversize : self.session.client.stats.action_copy_oversize,
            ),
            true
    case "fact_repair_requests":
        return gd.Int(
                self.session.authority ? self.session.server.stats.fact_repair_requests : self.session.client.stats.fact_repair_requests,
            ),
            true
    case "fact_repairs":
        return gd.Int(
                self.session.authority ? self.session.server.stats.fact_repairs : self.session.client.stats.fact_repairs,
            ),
            true
    case "fact_repair_bytes":
        return gd.Int(
                self.session.authority ? self.session.server.stats.fact_repair_bytes : self.session.client.stats.fact_repair_bytes,
            ),
            true
    case "fact_repair_oversize":
        return gd.Int(
                self.session.authority ? self.session.server.stats.fact_repair_oversize : self.session.client.stats.fact_repair_oversize,
            ),
            true
    case "baseline_misses":
        return gd.Int(
                self.session.authority ? self.session.server.stats.baseline_misses : self.session.client.stats.baseline_misses,
            ),
            true
    case "egress_deferred":
        return gd.Int(self.session.server.stats.egress_deferred), true
    case "tx_bytes":
        return gd.Int(
                self.session.authority ? self.session.server.stats.tx_bytes : self.session.client.stats.tx_bytes,
            ),
            true
    case "rx_bytes":
        return gd.Int(
                self.session.authority ? self.session.server.stats.rx_bytes : self.session.client.stats.rx_bytes,
            ),
            true
    case "authority":
        return gd.Int(self.session.authority), true
    case "epoch":
        return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch), true
    case "hz":
        return gd.Int(self.session.options.network.hz), true
    }

    return -1, false
}

probe_persistence :: proc(self: ^ReplayScrapyard, field: string) -> (gd.Int, bool) {
    switch field {
    case "saved_tick":
        return gd.Int(self.saved_run[0].saved_tick), true
    case "saved_hash":
        return self.saved_run[0].saved_hash, true
    case "save_pending":
        return gd.Int(self.saved_run[0].phase == .Checking || self.saved_run[0].phase == .Writing), true
    case "save_error":
        return gd.Int(self.saved_run[0].phase == .Failed), true
    case "save_revision":
        return gd.Int(self.saved_run[0].revision), true
    case "save_ok":
        return gd.Int(self.saved_run[0].ok), true
    case "restored_tick":
        return gd.Int(self.saved_run[0].restored_tick), true
    case "restored_hash":
        return self.saved_run[0].restored_hash, true
    case "automatic":
        return gd.Int(self.local_profile[0].automatic), true
    case "saved_automatic":
        return gd.Int(self.local_profile[0].record.automatic), true
    case "profile_writes":
        return gd.Int(self.local_profile[0].writes), true
    case "profile_loaded":
        return gd.Int(self.local_profile[0].has_record), true
    case "profile_error":
        return gd.Int(self.local_profile[0].error), true
    case "profile_writing":
        return gd.Int(self.local_profile[0].writing), true
    case "profile_revision":
        return gd.Int(self.local_profile[0].revision), true
    }

    return -1, false
}

probe_recovery :: proc(self: ^ReplayScrapyard, field: string) -> (gd.Int, bool) {
    switch field {
    case "backup_tick":
        return gd.Int(self.recovery_probe[0].point.archive.tick), true
    case "backup_sequence":
        return gd.Int(
                self.session.authority ? self.session.link.outgoing.acknowledged.archive.sequence : self.recovery_probe[0].point.archive.sequence,
            ),
            true
    case "lobby_backup":
        return gd.Int(
                self.recovery_probe[0].point.archive.sequence != 0 &&
                self.recovery_probe[0].frame.state.stage == .Staging &&
                game.all_ready(&self.recovery_probe[0].frame.state),
            ),
            true
    case "asset_prepare_wait":
        if !self.room.candidate.ready || !self.spray_dependencies[0].valid {
            return 0, true
        }

        for ref in self.spray_dependencies[0].refs {
            if ref != (a.Ref{}) && !a.cache_has(&self.assets[0].cache, ref) {
                return 1, true
            }
        }

        return 0, true
    case "backup_spray":
        return gd.Int(
                self.recovery_probe[0].frame.state.players[0].spray.image.bytes > 0 &&
                self.recovery_probe[0].frame.state.players[0].spray.stamp > 0,
            ),
            true
    case "active_backup":
        return gd.Int(
                self.recovery_probe[0].point.archive.sequence != 0 &&
                active_combat(self.recovery_probe[0].frame.state),
            ),
            true
    case "restored_exact":
        return gd.Int(self.recovery_probe[0].exact), true
    case "restored_active":
        return gd.Int(self.recovery_probe[0].active), true
    case "recovery_tick":
        return gd.Int(self.room.recovery.checkpoint_tick), true
    case "recovery_ready":
        return gd.Int(self.room.recovery.ready), true
    case "recovery_kind":
        return gd.Int(self.room.lease.view.recovery), true
    case "lost_ticks":
        return gd.Int(self.room.recovery.known_lost_ticks), true
    case "interruption":
        return gd.Int(self.room.recovery.interruption_ms), true
    case "room_phase":
        return gd.Int(self.room.phase), true
    case "control_error":
        return gd.Int(self.room.control_error), true
    case "link_error":
        return gd.Int(self.session.link.error), true
    case "link_model_error":
        return gd.Int(self.session.link.model_error), true
    case "archive_bytes":
        return gd.Int(self.room.recovery.archive_bytes), true
    case "frozen_tick":
        return gd.Int(self.room.frozen_tick), true
    case "authority_head":
        return gd.Int(self.session.server.timeline.head), true
    case "seat":
        return gd.Int(rgd.session_seat(self.session)), true
    }

    return -1, false
}

probe_presentation :: proc(self: ^ReplayScrapyard, field: string) -> (gd.Int, bool) {
    switch field {
    case "camera_seat":
        return self.camera_follow.active ? gd.Int(self.camera_follow.seat) : 0, true
    case "music_track":
        return gd.Int(self.audio[0].track), true
    case "sound_plays":
        return gd.Int(self.audio[0].route.pool.played), true
    case "sound_duplicates":
        return gd.Int(self.audio[0].route.pool.duplicates), true
    case "sound_refused":
        return gd.Int(self.audio[0].route.pool.refused), true
    case "sound_cancels":
        return gd.Int(self.audio[0].route.pool.stopped), true
    case "volume":
        return gd.Int(self.settings[0].value.volume), true
    case "shake_off":
        return gd.Int(self.settings[0].value.shake_off), true
    case "settings_error":
        return gd.Int(self.settings[0].error), true
    case "settings_pending":
        return gd.Int(self.settings[0].phase != .Ready), true
    case "menu_open":
        return gd.Int(self.menu_open), true
    case "tally_open":
        return gd.Int(self.tally_open), true
    case "dev_result":
        return self.development_result, true
    case "dev_reason":
        return self.development_reason, true
    case "shot_effects":
        return gd.Int(self.shot_effects - self.shot_cancels), true
    case "dash_effects":
        return gd.Int(self.dash_effects - self.dash_cancels), true
    }

    return -1, false
}
