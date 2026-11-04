#!/usr/bin/env python3
"""Task-owned Linux tool install/preflight. Run only after Root's command grant."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ASSETS = {
    "odin": ("https://github.com/odin-lang/Odin/releases/download/dev-2026-04/odin-linux-amd64-dev-2026-04.tar.gz",
             "8bfa62d459f505609cd0343746b4116f3e6866eb2d5b4b91bb8365db72f04e47"),
    "godot": ("https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip",
              "c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba"),
    "templates": ("https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz",
                  "86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"),
}


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def elf(path):
    with Path(path).open("rb") as f:
        header = f.read(64)
    if header[:6] != b"\x7fELF\x02\x01":
        raise RuntimeError("not a little-endian ELF64 executable: " + str(path))
    machine = struct.unpack_from("<H", header, 18)[0]
    if machine != 62:
        raise RuntimeError("expected actual x86_64 ELF machine62: " + str(path))
    return {"machine": machine, "class": 64, "endian": "little", "sha256": sha(path)}


def command(argv):
    p = subprocess.run(argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    value = {"argv": argv, "exit": p.returncode, "output": p.stdout}
    if p.returncode:
        raise RuntimeError(json.dumps(value))
    return value


def elf_linkage(path):
    """Inspect actual ELF64 program headers and the runtime dynamic entries."""
    size = Path(path).stat().st_size
    with Path(path).open("rb") as f:
        header = f.read(64)
        if len(header) != 64 or header[:6] != b"\x7fELF\x02\x01":
            raise RuntimeError("unsupported dependency-inspection ELF")
        phoff = struct.unpack_from("<Q", header, 32)[0]
        phsize, phcount = struct.unpack_from("<HH", header, 54)
        if not phcount or phsize < 56 or phoff + phsize * phcount > size:
            raise RuntimeError("invalid program-header bounds")
        interp = False
        dynamic_segments = []
        needed = []
        for index in range(phcount):
            f.seek(phoff + index * phsize)
            ph = f.read(56)
            kind = struct.unpack_from("<I", ph)[0]
            offset = struct.unpack_from("<Q", ph, 8)[0]
            length = struct.unpack_from("<Q", ph, 32)[0]
            if kind not in (2, 3):
                continue
            if offset + length > size:
                raise RuntimeError("invalid interpreter/dynamic segment bounds")
            if kind == 3:  # PT_INTERP
                interp = True
            else:  # PT_DYNAMIC, actual DT_NEEDED/DT_NULL entries
                if not length or length % 16 or length > 1024 * 1024:
                    raise RuntimeError("invalid dynamic segment size")
                f.seek(offset)
                entries = f.read(length)
                terminated = False
                for at in range(0, length, 16):
                    tag, value = struct.unpack_from("<qQ", entries, at)
                    if tag == 0:
                        terminated = True
                        break
                    if tag == 1:
                        needed.append(value)
                if not terminated:
                    raise RuntimeError("dynamic segment lacks DT_NULL")
                dynamic_segments.append({"offset": offset, "bytes": length})
    return {"program_header_count": phcount, "has_interp": interp,
            "dynamic_segments": dynamic_segments, "dt_needed_offsets": needed,
            "static_no_interp_or_needed": not interp and not needed}


def dependencies(path, allow_static):
    linkage = elf_linkage(path)
    p = subprocess.run(["ldd", str(path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    record = {"argv": ["ldd", str(path)], "exit": p.returncode, "output": p.stdout, "elf_linkage": linkage}
    static_result = (allow_static and linkage["static_no_interp_or_needed"] and
                     p.returncode == 1 and p.stdout.strip() == "not a dynamic executable")
    if static_result:
        record["accepted"] = "STATIC_ELF_no_INTERP_no_DT_NEEDED"
    elif p.returncode == 0 and "not found" not in p.stdout.lower():
        if not allow_static and (not linkage["has_interp"] or not linkage["dt_needed_offsets"]):
            raise RuntimeError("Godot must have actual dynamic linkage: " + json.dumps(record))
        record["accepted"] = "ldd0_no_missing_dependencies"
    else:
        raise RuntimeError("dependency inspection failed: " + json.dumps(record))
    return record


def download(folder, name, url, expected):
    target = folder / Path(url).name
    if target.exists():
        if sha(target) != expected:
            raise RuntimeError("existing download hash mismatch: " + str(target))
        return target
    partial = target.with_name(target.name + ".partial")
    with partial.open("xb") as output:
        request = urllib.request.Request(url, headers={"User-Agent": "odin-box3d-gate-c"})
        with urllib.request.urlopen(request, timeout=120) as response:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        output.flush()
        os.fsync(output.fileno())
    if sha(partial) != expected:
        raise RuntimeError("download SHA mismatch (partial preserved): " + name)
    partial.rename(target)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--out", type=Path, default=Path("/out/toolchain"))
    parser.add_argument("--baseline-report", type=Path)
    args = parser.parse_args()
    tools = Path("/work/tools")
    downloads = tools / "downloads"
    if not args.verify_only:
        tools.mkdir(parents=True, exist_ok=True)
        downloads.mkdir(exist_ok=True)
    output = args.out
    output.mkdir(parents=True, exist_ok=False)
    report = {"result": "FAIL", "execution": "Rosetta-translated Linux x86_64 functional userspace",
              "native_x86_hardware": False, "performance_claim": False,
              "cross_target_determinism_claim": False, "kernel_uname": list(platform.uname()),
              "assets": {}, "commands": [], "verify_only": args.verify_only,
              "script_sha256": sha(Path(__file__))}
    try:
        baseline = None
        if args.verify_only:
            if args.baseline_report is None:
                raise RuntimeError("verify-only requires the retained installed-byte baseline report")
            baseline = json.loads(args.baseline_report.read_text())
            report["baseline_report"] = {"path": str(args.baseline_report), "sha256": sha(args.baseline_report)}
        for name, (url, expected) in ASSETS.items():
            path = downloads / Path(url).name if args.verify_only else download(downloads, name, url, expected)
            if not path.is_file() or sha(path) != expected:
                raise RuntimeError("existing verified archive missing/changed: " + name)
            report["assets"][name] = {"url": url, "path": str(path), "sha256": sha(path), "bytes": path.stat().st_size}
        unpack = tools / "odin-unpack"
        godot_dir = tools / "godot"
        binary_name = "Godot_v4.7.1-stable_linux.x86_64"
        templates = Path(os.environ["XDG_DATA_HOME"]) / "godot/export_templates/4.7.1.stable"
        if not args.verify_only:
            unpack.mkdir(exist_ok=False)
            with tarfile.open(report["assets"]["odin"]["path"]) as archive:
                for member in archive.getmembers():
                    destination = (unpack / member.name).resolve()
                    if not destination.is_relative_to(unpack.resolve()):
                        raise RuntimeError("Odin archive path escapes task directory")
                    if member.issym() or member.islnk():
                        link = ((destination.parent if member.issym() else unpack) / member.linkname).resolve()
                        if not link.is_relative_to(unpack.resolve()):
                            raise RuntimeError("Odin archive link escapes task directory")
                archive.extractall(unpack)
            compilers = [p for p in unpack.rglob("odin") if p.is_file()]
            if len(compilers) != 1:
                raise RuntimeError("expected exactly one actual Odin executable")
            (tools / "odin").symlink_to(compilers[0].parent, target_is_directory=True)
            godot_dir.mkdir(exist_ok=False)
            with zipfile.ZipFile(report["assets"]["godot"]["path"]) as archive:
                if binary_name not in archive.namelist():
                    raise RuntimeError("official Godot executable missing")
                (godot_dir / binary_name).write_bytes(archive.read(binary_name))
            (godot_dir / binary_name).chmod(0o755)
            templates.mkdir(parents=True, exist_ok=False)
            with zipfile.ZipFile(report["assets"]["templates"]["path"]) as archive:
                version = archive.read("templates/version.txt").decode().strip()
                if version != "4.7.1.stable":
                    raise RuntimeError("matching export template version differs: " + version)
                for name in ["linux_debug.x86_64", "linux_release.x86_64", "version.txt"]:
                    target = templates / name
                    target.write_bytes(archive.read("templates/" + name))
                    if name != "version.txt":
                        target.chmod(0o755)
        if (templates / "version.txt").read_text().strip() != "4.7.1.stable":
            raise RuntimeError("installed template version differs")
        odin = tools / "odin/odin"
        godot = godot_dir / binary_name
        report["elf"] = {"python3": elf(Path(sys.executable).resolve()), "odin": elf(odin), "godot": elf(godot),
                         "template_debug": elf(templates / "linux_debug.x86_64"),
                         "template_release": elf(templates / "linux_release.x86_64")}
        if baseline is not None:
            if any(info["sha256"] != baseline["elf"][name]["sha256"] for name, info in report["elf"].items()):
                raise RuntimeError("installed tool/template bytes changed from preserved baseline")
        for argv in [["uname", "-a"], ["dpkg", "--print-architecture"],
                     ["dpkg-query", "-W", "clang", "llvm", "lld", "cmake", "python3"],
                     ["clang", "--version"], ["clang", "-dumpmachine"], ["llvm-config", "--version"],
                     ["cmake", "--version"], [str(odin), "version"], [str(godot), "--headless", "--version"]]:
            report["commands"].append(command(argv))
        report["commands"].append(dependencies(odin, allow_static=True))
        report["commands"].append(dependencies(godot, allow_static=False))
        odin_version = report["commands"][7]["output"]
        godot_version = report["commands"][8]["output"]
        if "dev-2026-04" not in odin_version or "4.7.1.stable.official.a13da4feb" not in godot_version:
            raise RuntimeError("actual compiler/editor version differs")
        report["result"] = "PASS"
    except Exception as exc:
        report["error"] = repr(exc)
    finally:
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"result": report["result"], "report": str(output / "report.json")}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
