package evolution_schema_fixture

SOURCE_CONTENT :: u64(1)
TARGET_CONTENT :: u64(2)

Source_Item :: struct {
    id: u16,
    hp: i16,
}
Target_Item :: struct {
    id:    u16,
    hp:    i16,
    boost: u8,
}
Source :: struct {
    clock: u64,
    items: [2]Source_Item,
}
Target :: struct {
    clock: u64,
    items: [2]Target_Item,
    limit: u16,
}

ADDED :: [3]string{"$.items[0].boost", "$.items[1].boost", "$.limit"}
