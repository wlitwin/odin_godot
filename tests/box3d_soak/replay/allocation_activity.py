"""Integer-only differences of existing public allocation observations.

No allocation-call count is inferred from Meter's live-block count. Categories
overlap the source/receiver contexts and must never be summed with them.
"""


def difference(before, after):
    if before.get("ok") is not True or after.get("ok") is not True:
        raise ValueError("allocation observation failed")

    def integer(record, name):
        value = record[name]
        if type(value) is not int or value < 0:
            raise ValueError("invalid allocation counter: " + name)
        return value

    result = {
        "scope": "public repair/Core return; snapshots outside timer and before extra oracle",
        "overlap": "contexts are included in categories; never sum these groups",
        "meter_allocation_calls": None,
        "meter_allocation_calls_reason": "existing stats expose live blocks and requested bytes, not cumulative call count",
        "groups": {},
    }
    for name in ("source", "receiver", "provider_category", "core_category",
                 "native_engine", "snapshot_wrapper"):
        a, z = before[name], after[name]
        if integer(a, "status") != 0 or integer(z, "status") != 0:
            raise ValueError("allocation status failure: " + name)
        group = {"live_bytes_delta": integer(z, "live_bytes") - integer(a, "live_bytes")}
        requested = "total_bytes" if name in ("native_engine", "snapshot_wrapper") else "requested_bytes"
        requested_delta = integer(z, requested) - integer(a, requested)
        if requested_delta < 0:
            raise ValueError("cumulative requested counter regressed: " + name)
        group["successful_requested_bytes_delta"] = requested_delta
        if name in ("native_engine", "snapshot_wrapper"):
            calls_delta = integer(z, "total_calls") - integer(a, "total_calls")
            if calls_delta < 0:
                raise ValueError("native allocation counter regressed: " + name)
            group["allocation_calls_delta"] = calls_delta
        else:
            group["live_blocks_before"] = integer(a, "live_blocks")
            group["live_blocks_after"] = integer(z, "live_blocks")
            group["live_blocks_delta"] = group["live_blocks_after"] - group["live_blocks_before"]
        result["groups"][name] = group
    return result
