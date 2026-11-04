package replay_module_test

import "core:testing"
import b "godot:box3d"

@(test)
actual_domain_contract_and_shared_ledger_bindings_preserve_rejected_owners :: proc(t: ^testing.T) {
    before, bs := b.engine_allocation_stats()
    testing.expect_value(t, bs, b.Status.Ok)
    contract, status := b.domain_contract_get()
    testing.expect_value(t, status, b.Status.Ok)
    testing.expect_value(t, contract.size, u32(size_of(b.Domain_Contract)))
    testing.expect_value(t, contract.version, b.DOMAIN_CONTRACT_VERSION)
    testing.expect(
        t,
        contract.cookie != 0 &&
        contract.abi_version == b.ABI_VERSION &&
        contract.logical_version == b.STATE_DUMP_VERSION &&
        contract.resource_version == b.SNAPSHOT_VERSION &&
        contract.recovery_version == b.RECOVERY_FORMAT,
    )
    testing.expect_value(t, b.domain_contract_check(contract), b.Status.Ok)
    testing.expect_value(t, b.abi_check(), b.Status.Ok)
    first, fs := b.host_owner_open(contract.cookie, 0x52504c594d4f4431, 1)
    testing.expect_value(t, fs, b.Status.Ok)
    second, ss := b.host_owner_open(contract.cookie, 0x52504c594d4f4432, 1)
    testing.expect_value(t, ss, b.Status.Ok)
    defer b.host_owner_close(contract.cookie, &second)
    defer b.host_owner_close(contract.cookie, &first)
    testing.expect_value(t, b.host_owner_set(contract.cookie, first, 1024, 2048), b.Status.Ok)
    testing.expect_value(t, b.host_owner_set(contract.cookie, second, 4096, 8192), b.Status.Ok)
    stats, ls := b.host_ledger_get(contract.cookie)
    testing.expect_value(t, ls, b.Status.Ok)
    testing.expect_value(t, stats.host_live_bytes, u64(5120))
    testing.expect_value(t, stats.host_reserved_bytes, u64(10240))
    testing.expect_value(t, stats.owner_count, u32(2))
    testing.expect(t, stats.ledger_storage_bytes > 0)
    required, ms := b.host_memory_check(contract.cookie, first, 2048, 1024)
    testing.expect_value(t, ms, b.Status.Ok)
    testing.expect_value(t, required, u64(2048 + 1024 + 4096 + 8192))
    old := first
    testing.expect_value(t, b.host_owner_close(contract.cookie + 1, &first), b.Status.Incompatible)
    testing.expect_value(t, first, old)
    testing.expect_value(t, b.host_owner_set(contract.cookie, first, b.HOST_LIMIT_BYTES, 0), b.Status.Capacity)
    info, is := b.host_owner_get(contract.cookie, first)
    testing.expect_value(t, is, b.Status.Ok)
    testing.expect_value(t, info.live_bytes, u64(1024))
    testing.expect_value(t, info.reserved_bytes, u64(2048))
    testing.expect_value(t, b.host_owner_close(contract.cookie, &first), b.Status.Ok)
    testing.expect_value(t, first, b.Host_Owner(0))
    stale := old
    testing.expect_value(t, b.host_owner_close(contract.cookie, &stale), b.Status.Invalid_Handle)
    testing.expect_value(t, stale, old)
    testing.expect_value(t, b.host_owner_close(contract.cookie, &second), b.Status.Ok)
    end, es := b.host_ledger_get(contract.cookie)
    testing.expect_value(t, es, b.Status.Ok)
    testing.expect_value(t, end.host_live_bytes + end.host_reserved_bytes, u64(0))
    testing.expect_value(t, end.owner_count, u32(0))
    after, as := b.engine_allocation_stats()
    testing.expect_value(t, as, b.Status.Ok)
    testing.expect_value(t, after.total_calls, before.total_calls)
    testing.expect_value(t, after.live_bytes, before.live_bytes)
}
