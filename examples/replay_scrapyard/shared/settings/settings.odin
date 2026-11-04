package scrapyard_settings

import sc "godot:replay/schema"

CONTENT :: u64(0x5253595345543031)

KIND :: u16(0x5354)

Value :: struct {
    version: u16,
    volume: u8,
    shake_off, fullscreen: bool,
}

DEFAULT :: Value {
    version = 1,
    volume = 8,
}

valid :: proc(value: Value) -> bool {
    return value.version == 1 && value.volume <= 10
}

encode :: proc(value: Value) -> ([]u8, bool) {
    if !valid(value) {
        return nil, false
    }

    codec: sc.Schema
    defer sc.destroy(&codec)

    if sc.init(&codec, Value).error != .None {
        return nil, false
    }

    bytes := make([]u8, sc.HEADER_BYTES + codec.wire_size)

    if sc.pack(&codec, value, {kind = KIND, epoch = 1, content = CONTENT}, bytes).error != .None {
        delete(bytes)
        return nil, false
    }

    return bytes, true
}

decode :: proc(bytes: []u8) -> (Value, bool) {
    codec: sc.Schema
    defer sc.destroy(&codec)

    if sc.init(&codec, Value).error != .None {
        return {}, false
    }

    value: Value
    _, report := sc.unpack(&codec, &value, bytes, {kind = KIND, epoch = 1, content = CONTENT})
    return value, report.error == .None && valid(value)
}
