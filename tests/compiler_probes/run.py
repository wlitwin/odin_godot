"""Exercise threaded generic-overload checking and verify selected dimensions.

Odin #6526/#7052: a rejected candidate must not specialize shared array counts.
The repeated checks target that reported race; any failure stops the gate.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

work = Path(os.environ.get("COMPILER_PROBES_OUT") or tempfile.mkdtemp(prefix="odin-compiler-probes-")).resolve()
work.mkdir(parents=True, exist_ok=True)
source = work / "fixture"
source.mkdir()
odin = os.environ.get("ODIN") or shutil.which("odin")
if not odin:
    raise SystemExit("Odin is required; run inside nix develop")

parts = ["""package main
empty_tail :: proc(a: $A/[$Count]$Element, b: $B/[0]Element) -> int {return -1}
four_tail :: proc(a: $A/[$Count]$Element, b: $B/[4]Element) -> int {return Count}
select_dimensions :: proc {empty_tail, four_tail}
"""]
names = []
expected = []
for typ in ("f32", "f64", "u32", "i64"):
    for count in range(1, 17):
        name = f"case_{typ}_{count}"
        names.append(name)
        expected.append(str(count))
        parts.append(f"{name} :: proc() -> int {{a: [{count}]{typ}; b: [4]{typ}; return select_dimensions(a,b)}}\n")
parts.append("@(require) main :: proc() {\n")
parts.append("calls := [?]proc()->int{" + ",".join(names) + "}\n")
parts.append("expected := [?]int{" + ",".join(expected) + "}\n")
parts.append('for call,index in calls {assert(call()==expected[index], "overload probe changed a generic dimension")}\n}\n')
(source / "main.odin").write_text("".join(parts))

results = []
print("Compiler probe evidence:", work, flush=True)
for iteration in range(4):
    binary = work / (f"native-{iteration}" + (".exe" if os.name == "nt" else ""))
    commands = [
        ("build", [odin, "build", str(source), "-out:" + str(binary)]),
        ("run", [str(binary)]),
        ("wasm", [odin, "check", str(source), "-target:freestanding_wasm32", "-no-entry-point"]),
    ]
    for phase, command in commands:
        log = work / f"{iteration}-{phase}.log"
        with log.open("w") as output:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=60)
        results.append({"iteration": iteration, "phase": phase, "command": command, "exit": result.returncode})
        (work / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        if result.returncode:
            print(log.read_text(errors="replace")[-5000:])
            raise SystemExit(f"Compiler probe {iteration}/{phase} failed; evidence: {work}")
print("COMPILER_PROBES_OK", flush=True)
