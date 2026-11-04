#!/usr/bin/env python3
"""SOURCE ONLY until Root grants: exact registered commands, direct file/wait supervision."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import time

from pipeline import NATIVE_TESTS, source_map
from toolchain import sha


def stop_owned(process):
    """Only the fresh child's own session/group, never a container-wide signal."""
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)


def binary_map(build):
    result = {}
    for path in sorted(build.rglob("*")):
        if not path.is_file():
            continue
        with path.open("rb") as f:
            header = f.read(20)
        # Executable/shared ELF images; relocatable build objects are not DSOs.
        if len(header) >= 20 and header[:6] == b"\x7fELF\x02\x01" and struct.unpack_from("<H", header, 16)[0] in (2, 3):
            if struct.unpack_from("<H", header, 18)[0] != 62:
                raise RuntimeError("Debug image is not actual ELF x86_64: " + str(path))
            result[str(path.relative_to(build))] = sha(path)
    if not result:
        raise RuntimeError("no actual Debug executables/DSOs to fence")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--phase-bound", type=int, default=3600)
    args = parser.parse_args()
    if args.phase_bound != 3600:
        raise SystemExit("the selected phase bound remains exactly3600")
    args.out.mkdir(parents=True, exist_ok=False)
    build = args.build_dir.resolve(strict=True)
    cache = build.parent.parent
    repo = Path("/work/native-v1/repo")
    env = os.environ.copy()
    # Same explicit exports made by the original unchanged Native driver.
    env.update(OGB3_REPO=str(repo), OGB3_CACHE=str(cache), OGB3_CONFIG=build.name,
               CC="/usr/bin/clang", JOBS="2", CMAKE_ARGS=json.dumps(["-DCMAKE_C_COMPILER=/usr/bin/clang"]))
    report = {"result": "INCOMPLETE", "actual_ctest_run_pass": False,
              "supervision": "direct Popen/waitpid; stdout+stderr files, no output pipes",
              "adaptation": "new task-only supervisor; no Native driver/CMake/test-source/assertion edits",
              "source_script_sha256": sha(Path(__file__)), "build_dir": str(build),
              "environment": env, "phase_bound_seconds": args.phase_bound, "tests": [],
              "prior_attempt": "RootCANCELLED_INCOMPLETE_SUPERVISION remains unchanged",
              "scope": "translated-linux-x86_64 functional; no hardware/performance/equality claim"}
    deadline = time.monotonic() + args.phase_bound
    try:
        prior_inputs = Path("/out/native-v1/source-inputs.json")
        inputs = json.loads(prior_inputs.read_text())
        if inputs != source_map(repo, "native"):
            raise RuntimeError("preserved Native inputs differ from the compiled attempt")
        report["native_source_inputs"] = {"path": str(prior_inputs), "sha256": sha(prior_inputs)}
        binaries = binary_map(build)
        report["binary_sha256_before"] = binaries
        registration = args.out / "registered-tests.json"
        # This queries the real CTest registration only; it executes no tests.
        argv = ["ctest", "--test-dir", str(build), "--show-only=json-v1"]
        with registration.open("xb") as output, (args.out / "registration.stderr").open("xb") as errors:
            process = subprocess.Popen(argv, cwd=build, env=env, stdin=subprocess.DEVNULL,
                                       stdout=output, stderr=errors, start_new_session=True)
            try:
                code = process.wait(timeout=min(30, deadline - time.monotonic()))
            except BaseException:
                stop_owned(process)
                raise
        report["registration"] = {"argv": argv, "exit": code, "path": str(registration), "sha256": sha(registration)}
        if code:
            raise RuntimeError("actual CTest registration query failed")
        tests = json.loads(registration.read_text())["tests"]
        if len(tests) != 12 or {t["name"] for t in tests} != NATIVE_TESTS:
            raise RuntimeError("registration is not the exact selected12-test set")
        dart = (build / "DartConfiguration.tcl").read_text()
        found = re.search(r"^TimeOut:\s*([0-9.]+)\s*$", dart, re.MULTILINE)
        if found is None:
            raise RuntimeError("cannot preserve actual CTest default timeout")
        default_timeout = float(found[1])
        report["ctest_default_timeout_seconds"] = default_timeout
        passed = set()
        for test in tests:  # actual registration order; never drop/rewrite a case
            properties = {p["name"]: p["value"] for p in test.get("properties", [])}
            supported = {"WORKING_DIRECTORY", "DEPENDS", "TIMEOUT", "ENVIRONMENT", "LABELS", "PROCESSORS", "RUN_SERIAL", "WILL_FAIL"}
            if set(properties) - supported or properties.get("WILL_FAIL", False):
                raise RuntimeError("unsupported test property must not be silently omitted: " + json.dumps(test))
            dependencies = properties.get("DEPENDS", [])
            if isinstance(dependencies, str):
                dependencies = dependencies.split(";")
            if not set(dependencies) <= passed:
                raise RuntimeError("actual registered dependency order not satisfied")
            child_env = dict(env)
            overrides = properties.get("ENVIRONMENT", [])
            if isinstance(overrides, str):
                overrides = overrides.split(";")
            for value in overrides:
                key, val = value.split("=", 1)
                child_env[key] = val
            command = test["command"]
            cwd = Path(properties.get("WORKING_DIRECTORY", str(build)))
            entry = {"name": test["name"], "argv": command, "cwd": str(cwd),
                     "properties": properties, "environment": child_env,
                     "log": str(args.out / (test["name"] + ".log")),
                     "executable_sha256": sha(command[0])}
            report["tests"].append(entry)
            test_timeout = float(properties.get("TIMEOUT", default_timeout))
            bound = deadline - time.monotonic()
            if test_timeout > 0:
                bound = min(test_timeout, bound)
            if bound <= 0:
                raise RuntimeError("unchanged phase bound exhausted")
            with Path(entry["log"]).open("xb") as output:
                process = subprocess.Popen(command, cwd=cwd, env=child_env, stdin=subprocess.DEVNULL,
                                           stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
                entry["actual_pid"] = process.pid
                (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
                try:
                    entry["actual_exit"] = process.wait(timeout=bound)
                except BaseException:
                    stop_owned(process)
                    raise
            entry["log_sha256"] = sha(entry["log"])
            if entry["actual_exit"] != 0:
                raise RuntimeError("first actual direct-command failure: " + entry["name"])
            passed.add(entry["name"])
        report["actual_passed_commands"] = len(passed)
        report["source_fence_unchanged"] = inputs == source_map(repo, "native")
        if not report["source_fence_unchanged"]:
            raise RuntimeError("Native source changed during direct command execution")
        report["binary_sha256_after"] = binary_map(build)
        report["binary_fence_unchanged"] = binaries == report["binary_sha256_after"]
        if not report["binary_fence_unchanged"]:
            raise RuntimeError("Debug executable/DSO identity changed")
        report["result"] = "DIRECT_REGISTERED_TEST_COMMANDS_PASS"
    except BaseException as exc:
        report["result"] = "INCOMPLETE"
        report["error"] = repr(exc)
    finally:
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"result": report["result"], "actual_ctest_run_pass": False,
                      "report": str(args.out / "report.json")}))
    return 0 if report["result"] == "DIRECT_REGISTERED_TEST_COMMANDS_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
