#+build !freestanding
package schema_game

import "core:testing"
import knet "godot:kit/net"
import rt "godot:runtime"
import data "packets"
import codes "tags"

@(test)
profile_and_messages_use_declaring_scope :: proc(t: ^testing.T) {
    testing.expect_value(t, len(rt.registration_errors()), 0)
    first, second: Game
    count: i32
    classes := rt.odin_scripts_manifest(&count)
    installed := false
    for descriptor in classes[:count] {
        if string(descriptor.name) == "Game" {
            descriptor.lifecycle.ready(&first)
            descriptor.lifecycle.ready(&second)
            installed = true
        }
    }
    testing.expect(t, installed)
    testing.expect_value(t, first.ses.prof_size, 4)
    testing.expect_value(t, second.ses.prof_size, 4)
    game_messages(&first, &first.ses)
    game_messages(&second, &second.ses)
    writer := knet.writer_make()
    defer knet.writer_destroy(&writer)
    knet.write_pod(&writer, data.Payload{value = 7})
    route := first.ses.app[codes.PING]
    reader := knet.reader_make(knet.writer_bytes(&writer))
    route.handler(route.user, 1, 1, &reader)
    testing.expect_value(t, first.received, i64(7))
    testing.expect_value(t, second.received, i64(0))
    reader = knet.reader_make(knet.writer_bytes(&writer))
    route = second.ses.app[codes.PING]
    route.handler(route.user, 2, 2, &reader)
    testing.expect_value(t, second.received, i64(7))
    reader = knet.reader_make(knet.writer_bytes(&writer)[:1])
    route.handler(route.user, 2, 2, &reader)
    testing.expect(t, reader.err)
    testing.expect_value(t, second.received, i64(7))
    knet.write_u8(&writer, 0)
    reader = knet.reader_make(knet.writer_bytes(&writer))
    route.handler(route.user, 2, 2, &reader)
    testing.expect(t, reader.err)
    testing.expect_value(t, second.received, i64(7))
}

@(test)
codec_and_blend_keep_tag_scope :: proc(t: ^testing.T) {
    field := game_net_desc.fields[0]
    testing.expect(t, field.wire == .Custom && field.lerp == .Custom)
    testing.expect(t, field.codec.size == 4 || field.codec.size == 8)
    value: i32 = -12345
    encoded: [8]u8
    decoded: i32
    field.codec.encode(&encoded, &value)
    field.codec.decode(&decoded, &encoded)
    testing.expect_value(t, decoded, value)
    a, b, middle: i32 = 10, 20, 0
    field.blend(&middle, &a, &b, 0.5)
    testing.expect_value(t, middle, i32(15))
}
