package scrapyard_content50

// Frozen canonical schema 8767771076300027651. No live type dependencies.
Action_50 :: struct {
    kind: enum u8 {
        Profile   = 0,
        Ready     = 1,
        Start     = 2,
        Cast      = 3,
        Buy       = 4,
        Workshop  = 5,
        Set_Spray = 6,
        Stamp     = 7,
        Dev_Spawn = 8,
        Dev_Edit  = 9,
        Dash      = 10,
    },
    profile: struct {
        meta: struct {
            cores: u32,
            parts: u8,
        },
        name: struct {
            count: u8,
            bytes: [31]u8,
        },
        look: u8,
        iron: u8,
        abilities: [2]u8,
        ready: bool,
    },
    ready: bool,
    slot: u8,
    aim: [2]f32,
    aim_is_point: bool,
    item: u8,
    image: struct {
        id: [32]u8,
        bytes: u32,
    },
    development: struct {
        kind: enum u8 {
            Hurt        = 0,
            Jam         = 1,
            Status      = 2,
            Grant_Scrap = 3,
            Grant_Cores = 4,
            Smite       = 5,
        },
        seat: u16,
        amount: u32,
        status: u8,
    },
}
