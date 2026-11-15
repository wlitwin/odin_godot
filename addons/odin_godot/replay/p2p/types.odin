package replay_p2p

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

VERSION :: u64(2)
WINDOW :: 16
MAX_PACKET :: 8192
HELLO :: u16(0x7101)
INPUTS :: u16(0x7102)

Error :: enum {
    None,
    Invalid_Config,
    Invalid_Model,
    Schema,
    Not_Ready,
    Waiting,
    Capacity,
    Invalid_Input,
    Time,
    Transport,
    Simulation,
    History,
    Conflict,
    Diverged,
    Invalid_Archive,
    Replay_Mismatch,
}

Phase :: enum u8 {
    Connecting,
    Running,
    Disconnected,
    Failed,
    Diverged,
}

Config :: struct {
    session, epoch, content: u64,
    hz:                      u32,
    history:                 int,
    delay, max_prediction:   u32,
    events_per_tick:         int,
    retry_ms, timeout_ms:    u64,
}

DEFAULT_CONFIG :: Config {
    session         = 1,
    epoch           = 1,
    content         = 1,
    hz              = 60,
    history         = 128,
    delay           = 2,
    max_prediction  = 8,
    events_per_tick = 32,
    retry_ms        = 50,
    timeout_ms      = 5000,
}

Model :: struct($S, $I, $E: typeid, $N: int) {
    step:        proc(state: ^S, inputs: [N]I, ctx: ^r.Step(E)),
    input_valid: proc(input: I) -> bool,
    state_valid: proc(state: S) -> bool,
    hold:        proc(previous: I) -> I,
    neutral:     I,
    user:        rawptr,
}

Stats :: struct {
    rx_bytes,
    tx_bytes,
    rejected,
    duplicate_inputs,
    rollbacks,
    replayed_ticks,
    stalls,
    predicted_inputs,
    max_replay_depth: u64,
}

Result :: struct {
    error:    Error,
    tick:     u64,
    captured: bool,
}

Mismatch :: struct {
    tick:                    u64,
    peer:                    u16,
    local_hash, remote_hash: u64,
}

@(private)
Input_Record :: struct($I: typeid) {
    tick:  u64,
    value: I,
    valid: bool,
}

@(private)
Hash_Record :: struct {
    tick, value: u64,
    valid:       bool,
}

@(private)
Hello :: struct {
    session, contract, initial_tick, initial_hash, received: u64,
}

@(private)
Packet :: struct($I: typeid) {
    contract, start:      u64,
    count:                u8,
    ack, hash_tick, hash: u64,
    values:               [WINDOW]I,
}

// Owns storage; keep at a stable address. The transport and model.user are borrowed.
Runner :: struct($State, $Input, $Event: typeid, $Seats: int) {
    allocator:                                                                            mem.Allocator,
    ready, time_set:                                                                      bool,
    phase:                                                                                Phase,
    error:                                                                                Error,
    cfg:                                                                                  Config,
    model:                                                                                Model(
        State,
        Input,
        Event,
        Seats,
    ),
    wire:                                                                                 tr.Transport,
    roster:                                                                               [Seats]tr.Peer_Id,
    local:                                                                                u16,
    timeline:                                                                             r.Timeline(
        State,
        [Seats]Input,
        Event,
    ),
    inputs:                                                                               []Input_Record(Input),
    hashes:                                                                               []Hash_Record,
    held:                                                                                 [Seats]Input,
    received, acknowledged, last_seen, sent_at:                                           [Seats]u64,
    hello_seen, sent_once:                                                                [Seats]bool,
    remote_hash:                                                                          [Seats]Hash_Record,
    initial_tick, initial_hash, contract, sampled, dirty, hash_tick, chain, now, started: u64,
    state_codec, input_codec, event_codec, hello_codec, packet_codec:                     sc.Schema,
    state_bytes, event_bytes, tx, rx:                                                     []u8,
    event_scratch:                                                                        []r.Occurrence(Event),
    stats:                                                                                Stats,
    profile:                                                                              Profile,
    mismatch:                                                                             Mismatch,
}
