package evolution_test
import "core:testing"
import "core:strings"
import e "godot:replay/evolution"

Old :: struct {
    score: u16,
    name:  [4]u8,
}

New :: struct {
    score: u16,
    extra: u8,
    name:  [4]u8,
}

@(test)
explicit_defaults_and_preservation :: proc(t: ^testing.T) {
    old := Old{9, {1, 2, 3, 4}}
    value, report := e.copy_preserved(old, New{extra = 7}, []string{"$.extra"})
    testing.expect(t, report.error == .None && value.score == 9 && value.extra == 7 && value.name == old.name)
    testing.expect(t, e.verify_preserved(old, value, []string{"$.extra"}).error == .None)
    value.score = 8
    testing.expect(t, e.verify_preserved(old, value, []string{"$.extra"}).error != .None)
    _, report = e.copy_preserved(old, New{}, []string{})
    testing.expect(t, report.error != .None)
    _, report = e.copy_preserved(old, New{}, []string{"$.extra", "$.score"})
    testing.expect(t, report.error != .None)
    _, report = e.copy_preserved(old, struct {
        score: u32,
        name:  [4]u8,
    }{}, []string{})
    testing.expect(t, report.error != .None)
}

@(test)
freeze_has_no_live_dependencies_and_rejects_unsupported :: proc(t: ^testing.T) {
    source, report := e.freeze(Old, "frozen", "World_1")
    defer delete(source)
    testing.expect(
        t,
        report.error == .None && strings.contains(source, "score: u16") && !strings.contains(source, "import"),
    )
    bad, problem := e.freeze(struct {
            pointer: ^u8,
        }, "frozen", "Bad")
    defer delete(bad)
    testing.expect(t, problem.error != .None && bad == "")
}

@(test)
privacy_and_enum_contract_changes_require_authored_conversion :: proc(t: ^testing.T) {
    before := struct {
        secret: u16 `replay:"authority"`,
    }{1}
    _, report := e.copy_preserved(before, struct {
        secret: u16,
    }{}, []string{})
    testing.expect(t, report.error != .None)

    A :: enum u8 {
        One = 1,
    }

    B :: enum i8 {
        One = 1,
    }

    _, report = e.copy_preserved(struct {
        value: A,
    }{.One}, struct {
        value: B,
    }{.One}, []string{})
    testing.expect(t, report.error != .None)
}

@(test)
bit_meanings_and_enumerated_array_changes_are_not_silently_copied :: proc(t: ^testing.T) {
    A :: enum u8 {
        Attack = 0,
        Block  = 1,
    }

    B :: enum u8 {
        Heal  = 0,
        Block = 1,
    }

    _, report := e.copy_preserved(struct {
        flags: bit_set[A;u8],
    }{}, struct {
        flags: bit_set[B;u8],
    }{}, []string{})
    testing.expect(t, report.error != .None)
    _, report = e.copy_preserved(struct {
        values: [A]u8,
    }{}, struct {
        values: [B]u8,
    }{}, []string{})
    testing.expect(t, report.error != .None)
}
