package owned_wasm

import r "godot:replay"
import own "godot:replay/owned"
import sc "godot:replay/schema"

@(require) instantiate :: proc() {
    s: own.State(own.Pose3)
    rules := own.Rules(own.Pose3) {
        valid = proc(user: rawptr, value: own.Pose3) -> bool {
            return own.pose3_valid(value, {{-100, -100, -100}, {100, 100, 100}, 100, 20})
        },
    }
    own.init(&s, {1, 0, 1}, 1, 0, 1, own.Pose3{rotation = {0, 0, 0, 1}}, rules)
    own.offer(&s, 2, 1, 20)
    driver: own.Driver
    choice := own.drive(&driver, s, 2, 1, 1, true)
    sample, _ := own.capture(&driver, choice.baseline)
    own.accept(&s, 2, sample, 2, rules)
    own.drive(&driver, s, 2, 1, 2, true)
    claim, _ := own.capture_context(&driver, s.value)
    own.read_context(&s, 2, claim, 2, rules)
    own.bind_epoch(&s, 2, 3)
    own.valid(s, rules)
    own.sample_valid(sample, rules)
    codec: sc.Schema
    sc.init(&codec, r.Frame(own.State(own.Pose3)))
    sc.destroy(&codec)
}
