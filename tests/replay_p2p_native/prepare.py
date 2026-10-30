from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
for source, name in [('replay_duel', 'duel'), ('replay_duel_service', 'service')]:
    shutil.copytree(root / 'examples' / source, out / name, ignore=shutil.ignore_patterns('bin', 'out', '.godot', 'node_modules', '*.gen.odin'))
project = out / 'duel'
scene = project / 'duel.tscn'
text = scene.read_text().replace('load_steps=3', 'load_steps=4')
text = text.replace('[node name="ReplayDuel"', '[ext_resource type="Script" path="res://native_fixture.gd" id="3"]\n[node name="ReplayDuel"', 1)
text += '\n[node name="NativeFixture" type="Node" parent="."]\nscript = ExtResource("3")\n'
scene.write_text(text)
(project / 'native_fixture.gd').write_text('''extends Node
var invitation_written := false
var reported := false
var unavailable_reported := false
func _process(_delta: float) -> void:
    var invitation: String = get_parent().call("party_invite")
    var destination := OS.get_environment("RDP_INVITE_FILE")
    if not invitation_written and not invitation.is_empty() and not destination.is_empty():
        var file := FileAccess.open(destination, FileAccess.WRITE)
        if file == null:
            push_error("Native fixture invitation write failed")
            get_tree().quit(1)
            return
        file.store_string(invitation)
        file.close()
        invitation_written = true
        print("RDP_INVITATION_STORED")
    if not unavailable_reported and bool(get_parent().call("control_unavailable")):
        print("RDP_CONTROL_UNAVAILABLE")
        unavailable_reported = true
    if not reported and int(get_parent().call("probe", 6)) >= int(OS.get_environment("RDP_UNTIL")):
        print(get_parent().call("native_receipt"))
        reported = true
''')
with (project / 'scripts/duel.odin').open('a') as file:
    file.write('''
// Read-only test receipt; no test input or admission decisions.
@(gd_method)
replay_duel_native_receipt :: proc(self:^ReplayDuel)->string {
    return fmt.tprintf("RDP_NATIVE_LINK serial=%d sent=%d received=%d confirmed=%d target_port=%d",
        self.direct.serial,self.direct.link.stats.sent,self.direct.link.stats.received,
        self.direct.link.stats.confirmed,self.direct.endpoint.port)
}
@(gd_method)
replay_duel_control_unavailable :: proc(self:^ReplayDuel)->bool {
    return self.online.failed && !self.online.ready && self.online.registration.phase==.Failed
}
''')
