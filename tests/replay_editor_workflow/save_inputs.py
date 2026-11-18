"""Exercise the shipped save/worker boundary in an isolated, real editor.

The worker records saved bytes; semantic content baking remains covered by the
Scrapyard editor acceptance. No Odin build is needed for this editor-only test.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
work = Path(tempfile.mkdtemp(prefix="replay-save-inputs-")).resolve()
print("Replay save evidence:", work, flush=True)
(work / "project.godot").write_text('''config_version=5
[application]
config/name="Replay save checks"
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/replay_authoring/plugin.cfg", "res://addons/acceptance/plugin.cfg")
''')
(work / "replay_authoring.json").write_text(json.dumps({
    "version": 1, "worker": "res://worker.py", "status_action": "status",
    "inputs": [
        {"id": "definition", "label": "Definition", "kind": "resource", "default": "res://first.tres"},
        {"id": "latency", "label": "Latency", "kind": "choice", "choices": [{"label": "Typical", "value": 80}, {"label": "Adverse", "value": 150}]},
        {"id": "name", "label": "Draft name", "kind": "text"}],
    "actions": [
        {"id": "validate", "label": "Validate", "kind": "worker", "inputs": ["definition", "latency", "name"]},
        {"id": "bake", "label": "Bake", "kind": "worker", "inputs": ["definition", "latency", "name"]},
        {"id": "status", "label": "Status", "kind": "worker", "save": False}]}))
subprocess.run([sys.executable, str(ROOT / "replay/editor/install.py"), str(work)], check=True)
(work / "value.gd").write_text('''@tool
extends Resource
@export var amount: int = 0
@export var children: Array[Resource] = []
@export var mapping: Dictionary = {}
''')
(work / "scene.gd").write_text('''@tool
extends Node
@export var payload: Resource
@export var number: int = 0
''')
(work / "logic.gd").write_text('extends RefCounted\nconst VALUE = 1\n')
(work / "first.tres").write_text('''[gd_resource type="Resource" script_class="" load_steps=3 format=3]
[ext_resource type="Script" path="res://value.gd" id="1"]
[sub_resource type="Resource" id="Child"]
script = ExtResource("1")
amount = 3
[resource]
script = ExtResource("1")
amount = 1
mapping = {"nested": [SubResource("Child")]}
''')
(work / "second.tres").write_text('''[gd_resource type="Resource" load_steps=2 format=3]
[ext_resource type="Script" path="res://value.gd" id="1"]
[resource]
script = ExtResource("1")
amount = 2
''')
(work / "main.tscn").write_text('''[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scene.gd" id="1"]
[ext_resource type="Script" path="res://value.gd" id="2"]
[sub_resource type="Resource" id="Payload"]
script = ExtResource("2")
amount = 4
[node name="Main" type="Node"]
script = ExtResource("1")
payload = SubResource("Payload")
''')
shutil.copy2(work / "main.tscn", work / "other.tscn")
shutil.copy2(work / "main.tscn", work / "closed.tscn")
shutil.copy2(work / "main.tscn", work / "released.tscn")
shutil.copy2(work / "main.tscn", work / "child.tscn")
(work / "parent.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://child.tscn" id="1"]\n[node name="Parent" type="Node"]\n[node name="Child" parent="." instance=ExtResource("1")]\n')

addon = work / "addons/acceptance"
addon.mkdir(parents=True)
(addon / "plugin.cfg").write_text('[plugin]\nname="Save acceptance"\nscript="plugin.gd"\n')
shutil.copy2(Path(__file__).with_name("save_inputs.gd"), addon / "plugin.gd")
# A bounded worker observes exactly what a separate validator can read. Its
# completion gate makes the edit-during-job check deterministic.
(work / "worker.py").write_text('from pathlib import Path\nimport json, time\n\ndef run(ctx, action, inputs):\n    root = ctx.project\n    history = root / ".godot/invocations.json"\n    calls = json.loads(history.read_text()) if history.exists() else []\n    calls.append(ctx.request)\n    history.write_text(json.dumps(calls))\n    if action == "status" and (root / ".godot/fail_status").exists():\n        raise RuntimeError("Status cannot read the content receipt")\n    if action == "status":\n        ctx.job.progress("Checking status")\n        gate = root / ".godot/hold_status"\n        snapshot = {}\n    else:\n        snapshot = {name: (root/name).read_text() for name in ("first.tres", "second.tres", "main.tscn", "other.tscn", "closed.tscn", "released.tscn", "logic.gd", "child.tscn", "parent.tscn")}\n        ctx.job.publish(ok=False, running=True, message="Worker read saved inputs", issues=[], snapshot=snapshot)\n        gate = root / ".godot/hold_worker"\n    deadline = time.monotonic() + 30\n    while gate.exists():\n        if ctx.job.cancel.exists(): raise RuntimeError("Cancelled")\n        if time.monotonic() > deadline: raise RuntimeError("test completion gate deadline")\n        time.sleep(.03)\n    if action != "status": (root / ".godot/artifact.json").write_text(json.dumps(snapshot))\n    return {"ok": True, "stale": False, "message": "Saved inputs checked", "issues": [], "snapshot": snapshot, "request": ctx.request}\n')

original = Path(os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")).resolve()
engine = work / ".engine"
engine.mkdir()
if original.parent.name == "MacOS" and original.parent.parent.name == "Contents":
    bundle = original.parents[2]
    subprocess.run(["/bin/cp", "-c", "-R", str(bundle), str(engine / bundle.name)], check=True)
    godot = engine / bundle.name / "Contents/MacOS" / original.name
else:
    godot = engine / original.name
    shutil.copy2(original, godot)
(engine / "_sc_").touch()
for phase in ("import", "editor"):
    command = [str(godot), "--headless", "--editor", "--path", str(work)]
    if phase == "import":
        command += ["--quit-after", "50"]
    log_path = work / (phase + ".log")
    with log_path.open("w") as log:
        try:
            result = subprocess.run(command, env=os.environ | {"REPLAY_SAVE_CHECK": "1" if phase == "editor" else "0"},
                                    stdout=log, stderr=subprocess.STDOUT, timeout=120)
        except subprocess.TimeoutExpired:
            print(log_path.read_text(errors="replace")[-8000:])
            raise
    output = log_path.read_text(errors="replace")
    checked = output
    if phase == "editor":
        # Intentional write failures must emit exactly their engine
        # diagnostic inside the named interval. Every other error still fails.
        for label, path in (("RESOURCE", "second.tres"), ("SCENE", "main.tscn"), ("CLOSED_SCENE", "closed.tscn")):
            block = re.search(f"EXPECTED_{label}_SAVE_FAILURE_BEGIN(.*?)EXPECTED_{label}_SAVE_FAILURE_END", output, re.S)
            expected = f"ERROR: Cannot save file 'res://{path}'."
            if block is None or re.findall(r"^ERROR:.*$", block[1], re.M) != [expected]:
                print(output[-8000:])
                raise RuntimeError(f"Missing or unexpected {label} failure diagnostic; evidence: {work}")
            checked = checked.replace(expected, "EXPECTED SAVE ERROR", 1)
    if result.returncode or any(s in checked for s in ("SCRIPT ERROR:", "\nERROR:", "leaked at exit")) or (phase == "editor" and "REPLAY_SAVE_INPUTS_OK" not in output):
        print(output[-8000:])
        raise RuntimeError(f"{phase} failed; evidence: {work}")
    print(phase, "PASS", flush=True)
print("REPLAY_SAVE_INPUTS_OK", work)
