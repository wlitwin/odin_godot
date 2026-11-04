package replay_authority

// Lease time must advance during system sleep as well as process suspension.
// Unsupported targets deliberately fail closed; a browser embedding must supply
// and verify an appropriate clock instead of assuming performance.now qualifies.
native_clock :: proc() -> Clock_Source {
    return {read = native_milliseconds}
}
