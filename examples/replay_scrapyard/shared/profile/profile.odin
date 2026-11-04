package scrapyard_profile

import sc "godot:replay/schema"
import game "../game"

LEGACY_CONTENT :: u64(0x52535950524f4631)

CONTENT :: u64(0x52535950524f4632)

KIND :: u16(0x5250)

Legacy_Record :: struct {
    identity: [32]u8,
    profile: game.Profile,
    epoch, tick: u64,
}

Record :: struct {
    identity: [32]u8,
    profile: game.Profile,
    epoch, tick: u64,
    automatic: u8,
}

Error :: enum {
    None,
    Codec,
    Identity,
    Value,
}

valid :: proc(record: Record) -> bool {
    bits := u8(0)

    for b in record.identity {
        bits |= b
    }

    return(
        record.automatic & ~AUTOMATIC_ALL == 0 &&
        bits != 0 &&
        game.profile_valid(record.profile) &&
        !record.profile.ready \
    )
}

encode :: proc(record: Record) -> ([]u8, Error) {
    if !valid(record) {
        return nil, .Value
    }

    codec: sc.Schema
    defer sc.destroy(&codec)

    if sc.init(&codec, Record).error != .None {
        return nil, .Codec
    }

    bytes := make([]u8, sc.HEADER_BYTES + codec.wire_size)

    if sc.pack(&codec, record, {kind = KIND, epoch = 1, tick = record.tick, content = CONTENT}, bytes).error != .None {
        delete(bytes)
        return nil, .Codec
    }

    return bytes, .None
}

decode :: proc(bytes: []u8, identity: [32]u8) -> (Record, Error) {
    meta, _, inspection := sc.inspect(bytes)

    if inspection.error != .None {
        return {}, .Codec
    }

    codec: sc.Schema
    defer sc.destroy(&codec)
    record: Record

    if meta.content == LEGACY_CONTENT {
        if sc.init(&codec, Legacy_Record).error != .None {
            return {}, .Codec
        }

        old: Legacy_Record
        framed, result := sc.unpack(&codec, &old, bytes, {kind = KIND, epoch = 1, content = LEGACY_CONTENT})

        if result.error != .None || framed.tick != old.tick {
            return {}, .Codec
        }

        // Older profiles stored concrete choices. Never reinterpret them as AUTO.
        record = {
            identity = old.identity,
            profile = old.profile,
            epoch = old.epoch,
            tick = old.tick,
        }
    } else {
        if sc.init(&codec, Record).error != .None {
            return {}, .Codec
        }

        framed, result := sc.unpack(&codec, &record, bytes, {kind = KIND, epoch = 1, content = CONTENT})

        if result.error != .None || framed.tick != record.tick {
            return {}, .Codec
        }
    }

    if record.identity != identity {
        return {}, .Identity
    }

    if !valid(record) {
        return {}, .Value
    }

    return record, .None
}
