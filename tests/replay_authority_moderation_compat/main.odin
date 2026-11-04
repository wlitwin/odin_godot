package main
import "core:fmt"
import a "godot:replay/authority"
import old "./reference"
import tr "godot:replay/transport"

Clock :: struct {
    now: u64,
}

clock :: proc(user: rawptr) -> (u64, bool) {
    return (cast(^Clock)user).now, true
}

main :: proc() {
    memory: tr.Memory
    assert(tr.memory_init(&memory, 1, {3, 64, 16384, 2048}))
    defer tr.memory_destroy(&memory)
    ends: [3]tr.Memory_Endpoint

    for &e, i in ends {
        assert(tr.memory_open(&memory, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in ends {
        w := tr.memory_transport(&e)
        tr.close(&w)
    }

    time: Clock
    endpoint, _ := a.endpoint("127.0.0.1", 45000)
    record := a.record_make(44, 55, {1, 101})
    record.members[0] = {
        identity          = {1, 101},
        endpoint          = endpoint,
        enabled           = true,
        can_host          = true,
        trusted_authority = true,
    }
    service: a.Service
    defer a.service_destroy(&service)
    assert(a.service_init(&service, record, proc(_: rawptr, _: u64, _: a.Record) -> bool {
            return true
        }, nil, {&time, clock}, tr.memory_transport(&ends[0]), []a.Credential{{{1, 101}, {0 = 21}}}) == .None)
    lease: old.Lease
    assert(old.lease_init(&lease, {1, 101}, 44, 55, {&time, clock}, true) == .None)
    client: old.Rpc_Client
    defer old.rpc_client_destroy(&client)
    assert(old.rpc_client_init(&client, &lease, {0 = 21}, {0 = 11}, tr.memory_transport(&ends[1])))
    assert(old.rpc_begin(&client, {verb = .Start}) == .None)

    for tick in u64(0) ..< 20 {
        time.now = tick * 10
        tr.memory_advance(&memory, tick)
        a.service_pump(&service)
        old.rpc_client_pump(&client)
    }

    reply, ok := old.rpc_completed(&client)
    assert(ok && reply.result == .None && reply.view.epoch == 1)
    fmt.println("AUTHORITY_OLD_CLIENT_NEW_SERVICE_OK")
    // Reverse direction: old service, new client; the ordinary schema/domain are
    // byte-compatible. The separate removal kind must be ignored by the old service.
    old_endpoint, _ := old.endpoint("127.0.0.1", 45001)
    old_record := old.record_make(45, 55, {1, 101})
    old_record.members[0] = {
        identity          = {1, 101},
        endpoint          = old_endpoint,
        enabled           = true,
        can_host          = true,
        trusted_authority = true,
    }
    old_service: old.Service
    defer old.service_destroy(&old_service)
    assert(old.service_init(&old_service, old_record, proc(_: rawptr, _: u64, _: old.Record) -> bool {
            return true
        }, nil, {&time, clock}, tr.memory_transport(&ends[2]), []old.Credential{{{1, 101}, {0 = 22}}}) == .None)
    modern_lease: a.Lease
    assert(a.lease_init(&modern_lease, {1, 101}, 45, 55, {&time, clock}, true) == .None)
    modern: a.Rpc_Client
    defer a.rpc_client_destroy(&modern)
    assert(
        a.rpc_client_init(&modern, &modern_lease, {0 = 22}, {0 = 12}, tr.memory_transport(&ends[1]), coordinator = 3),
    )
    assert(a.rpc_begin(&modern, {verb = .Start}) == .None)

    for tick in u64(20) ..< 40 {
        time.now = tick * 10
        tr.memory_advance(&memory, tick)
        old.service_pump(&old_service)
        a.rpc_client_pump(&modern)
    }

    current, done := a.rpc_completed(&modern)
    assert(done && current.result == .None && current.view.epoch == 1)
    revision := old_service.coordinator.record.revision
    assert(a.rpc_remove(&modern, 1, {2, 102}) == .None)
    assert(!old.service_receive(&old_service, 2, modern.txb[:modern.count]))
    assert(old_service.coordinator.record.revision == revision)
    fmt.println("AUTHORITY_NEW_CLIENT_OLD_SERVICE_OK removal_ignored=true")
}
