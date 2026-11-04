//gd:extends Node
//gd:class CallbackConsumer
package callback_consumer
import "base:runtime"
import "core:thread"
import b "godot:box3d"
import gd "godot:godot"
import rt "godot:runtime"

CallbackConsumer :: struct {
    owner:  gd.Node,
    handle: rt.Managed_Callable,
    worker: gd.Callable,
}

@(gd_method)
consumer_accept :: proc(self: ^CallbackConsumer, packet: gd.Packed_Byte_Array) -> bool {
    packet := packet
    view := gd.packed_byte_array_view(&packet)

    if len(view) != size_of(rt.Managed_Callable) || self.handle.token != 0 {
        return false
    }

    bytes: [size_of(rt.Managed_Callable)]u8
    copy(bytes[:], view)
    value := transmute(rt.Managed_Callable)bytes

    if value.token == 0 {
        return false
    }

    self.handle = value
    return true
}

@(gd_method)
consumer_value :: proc(self: ^CallbackConsumer) -> gd.Callable {
    return self.handle.value
}

@(gd_method)
consumer_live :: proc(self: ^CallbackConsumer) -> gd.Int {
    s, status := rt.managed_callable_stats()
    return status == 0 ? gd.Int(s.live_records) : -1
}

@(gd_method)
consumer_pending :: proc(self: ^CallbackConsumer) -> gd.Int {
    s, status := rt.managed_callable_stats()
    return status == 0 ? gd.Int(s.pending_records) : -1
}

@(gd_method)
consumer_collect :: proc(self: ^CallbackConsumer) -> gd.Int {
    return gd.Int(rt.managed_callable_collect())
}

@(gd_method)
consumer_close :: proc(self: ^CallbackConsumer) -> gd.Int {
    return gd.Int(rt.managed_callable_close(&self.handle))
}

@(gd_method)
consumer_cookie :: proc(self: ^CallbackConsumer) -> gd.Int {
    c, s := b.domain_contract_get()
    return s == .Ok ? gd.Int(c.cookie) : 0
}

@(gd_method)
consumer_storage :: proc(self: ^CallbackConsumer) -> gd.Int {
    s, status := rt.managed_callable_stats()
    return status == 0 ? gd.Int(s.storage_bytes) : -1
}

@(gd_method)
consumer_clone_worker :: proc(self: ^CallbackConsumer) -> bool {
    if self.handle.token == 0 {
        return false
    }

    self.worker = gd.new_callable_callable(self.handle.value)
    return true
}

@(gd_method)
consumer_free_worker :: proc(self: ^CallbackConsumer) -> bool {
    // The main handle must have closed first; the worker owns the last engine copy.
    if self.handle.token != 0 {
        return false
    }

    value := self.worker
    self.worker = {}
    t := thread.create(proc(t: ^thread.Thread) {
        v := cast(^gd.Callable)t.data
        gd.free_callable(v^)
    })
    t.data = &value
    thread.start(t)
    thread.join(t)
    thread.destroy(t)
    return true
}

@(gd_method)
consumer_wrong_thread :: proc(self: ^CallbackConsumer) -> bool {
    before := self.handle

    Result :: struct {
        handle: rt.Managed_Callable,
        status: i32,
    }

    data := Result {
        handle = before,
    }
    t := thread.create(proc(t: ^thread.Thread) {
        p := cast(^Result)t.data
        p.status = i32(rt.managed_callable_close(&p.handle))
    })
    t.data = &data
    thread.start(t)
    thread.join(t)
    thread.destroy(t)
    return data.status == 5 && transmute([5]u64)data.handle == transmute([5]u64)before
}

@(gd_method)
consumer_forged :: proc(self: ^CallbackConsumer) -> bool {
    before := self.handle
    forged := before
    forged.token += 1 << 16
    copy := forged

    if rt.managed_callable_close(&forged) != 2 || transmute([5]u64)forged != transmute([5]u64)copy {
        return false
    }

    forged = before
    bits := transmute([4]uintptr)forged.value
    bits[0] ~= 1
    forged.value = transmute(gd.Callable)bits
    copy = forged
    return rt.managed_callable_close(&forged) == 2 && transmute([5]u64)forged == transmute([5]u64)copy
}

baseline_live: u64

@(gd_method)
consumer_baseline :: proc(self: ^CallbackConsumer) -> bool {
    c, status := b.domain_contract_get()

    if status != .Ok {
        return false
    }

    stats, s := b.host_ledger_get(c.cookie)

    if s != .Ok {
        return false
    }

    baseline_live = stats.host_live_bytes
    return stats.host_reserved_bytes == 0 && stats.engine_live_bytes == 0 && stats.snapshot_live_bytes == 0
}

@(gd_method)
consumer_clean :: proc(self: ^CallbackConsumer) -> bool {
    c, status := b.domain_contract_get()

    if status != .Ok {
        return false
    }

    stats, s := b.host_ledger_get(c.cookie)

    if s != .Ok {
        return false
    }

    return(
        stats.host_live_bytes == baseline_live &&
        stats.host_reserved_bytes == 0 &&
        stats.engine_live_bytes == 0 &&
        stats.snapshot_live_bytes == 0 \
    )
}
