package replay_net_parts_reference

import r "godot:replay"
import "core:crypto/sha2"

@(private)
network_step :: proc(state: ^$State, input: Batch($Control, $Action, $Seats), ctx: ^r.Step(Net_Event($Event))) {
    model := cast(^Model(State, Control, Action, Event, Seats))ctx.user

    if (input.prediction_group == 0) != (input.prediction_seat == 0) {
        r.abort(ctx)
        return
    }

    if input.prediction_group != 0 &&
       (input.prediction_group != model.group.id || input.prediction_seat == 0 || int(input.prediction_seat) > Seats) {
        r.abort(ctx)
        return
    }

    for control in input.controls {
        if !model.control_valid(control) {
            r.abort(ctx)
            return
        }
    }

    storage: [GAME_EVENTS]r.Occurrence(Event)
    game_ctx := r.Step(Event) {
        tick   = ctx.tick,
        epoch  = ctx.epoch,
        events = storage[:],
        user   = model.user,
    }

    if model.reset_player != nil {
        for i in 0 ..< Seats {
            if input.fresh & (u64(1) << uint(i)) != 0 {
                model.reset_player(state, u16(i + 1), &game_ctx)
            }
        }
    }

    if model.step_view != nil {
        model.step_view(state, input.controls, input.views, input.joins, input.leaves, &game_ctx)
    } else {
        model.step(state, input.controls, input.joins, input.leaves, &game_ctx)
    }

    for present, i in input.has_action {
        if !present {
            continue
        }

        applied := false
        reason := input.rejections[i]

        if reason == .None && model.action != nil {
            before := state^
            count := game_ctx.count
            before_events := storage
            applied = model.action(state, u16(i + 1), input.actions[i], &game_ctx)

            if !applied {
                state^ = before
                storage = before_events
                game_ctx.count = count
                reason = .Predicate
            }
        }

        // Gameplay source zero is reserved for protocol action verdicts.
        r.emit(
            ctx,
            0,
            input.sequences[i] << 8 | u64(i + 1),
            Net_Event(Event) {
                kind = .Action_Result,
                seat = u16(i + 1),
                sequence = input.sequences[i],
                applied = applied,
                reason = reason,
            },
        )
    }

    if game_ctx.error != .None {
        ctx.error = game_ctx.error
        return
    }

    if input.prediction_group != 0 && !model.group.valid(state^, input.prediction_seat) {
        r.abort(ctx)
        return
    }

    for event in storage[:game_ctx.count] {
        if event.id.source == 0 {
            ctx.error = .Invalid_Event
            return
        }

        seat := model.event_owner != nil ? model.event_owner(event.value) : 0
        r.emit(ctx, event.id.source, event.id.key, Net_Event(Event){value = event.value, seat = seat})
    }
}

@(private)
config_valid :: proc(cfg: Config) -> bool {
    return(
        cfg.epoch != 0 &&
        cfg.content != 0 &&
        cfg.hz > 0 &&
        cfg.hz <= 240 &&
        cfg.history >= 32 &&
        cfg.history <= 1024 &&
        cfg.lead >= 2 &&
        cfg.lead < u32(cfg.history) &&
        cfg.max_prediction >= cfg.lead + 2 &&
        cfg.max_future >= cfg.lead + 2 &&
        cfg.max_future < u32(cfg.history) &&
        cfg.max_prediction < u32(cfg.history - 2) &&
        cfg.snapshot_every > 0 &&
        cfg.snapshot_every <= 30 &&
        cfg.watch_delay < u32(cfg.history / 2) &&
        cfg.timeout_ms >= 1000 &&
        cfg.timeout_ms <= 120000 &&
        cfg.packets_per_pump > 0 &&
        cfg.packets_per_pump <= 256 &&
        cfg.bytes_per_pump >= 65536 &&
        cfg.bytes_per_pump <= 1024 * 1024 &&
        cfg.snapshot_history >= 2 &&
        cfg.snapshot_history <= 64 &&
        cfg.egress_bytes_per_second >= 8192 &&
        cfg.egress_bytes_per_second <= 16 * 1024 * 1024 &&
        cfg.egress_bytes_per_pump >= 8192 &&
        cfg.egress_bytes_per_pump <= 1024 * 1024 &&
        cfg.unreliable_packet_limit >= 512 &&
        cfg.unreliable_packet_limit <= 65536 &&
        cfg.max_rewind < u32(cfg.history) &&
        cfg.max_view_span > 0 &&
        cfg.max_view_span < u32(cfg.history) &&
        cfg.view_slack <= 30 \
    )
}

@(private)
token_valid :: proc(token: Token) -> bool {
    bits := u8(0)

    for b in token {
        bits |= b
    }

    return bits != 0
}

@(private)
token_digest :: proc(token: Token) -> [32]u8 {
    data := token
    ctx: sha2.Context_256
    sha2.init_256(&ctx)
    sha2.update(&ctx, data[:])
    digest: [32]u8
    sha2.final(&ctx, digest[:])
    return digest
}
