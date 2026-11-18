#!/usr/bin/env python3
"""Remember resolved tools locally; explicit environment selections take priority.

The cache is disposable Godot editor data, never required project configuration.
Backend paths remain inputs to the existing profile/identity validation.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


TOOLS = {"odin": "ODIN", "ols": "OLS", "odinfmt": "ODINFMT", "emcc": "EMCC"}


def cache_path(project):
    return Path(project) / ".godot" / "odin_godot" / "toolchain"


def read_cache(project):
    values = {}
    for key in (*TOOLS, "python3", "root", "box3d_native_macos", "box3d_native_linux", "box3d_native_windows", "box3d_web"):
        try:
            values[key] = (cache_path(project) / key).read_text().removesuffix("\n")
        except (OSError, UnicodeError):
            pass
    return values


def executable(value):
    found = shutil.which(value) if value else None
    return str(Path(found).absolute()) if found else ""


def resolve_tool(key, cache, env):
    explicit = env.get(TOOLS[key], "")
    if explicit and explicit != key:
        found = executable(explicit)
        if not found and key == "odin":
            raise ValueError(f"{TOOLS[key]} executable not found: {explicit}")
        return found
    return executable(key) or executable(cache.get(key, ""))


def resolve_backend(project, key, target, cache, env):
    variable = "BOX3D_WEB_ARCHIVE" if key == "web" else "BOX3D_NATIVE_LIBRARY"
    selected = env.get(variable, "") or cache.get("box3d_" + key, "")
    if not selected and key != "web":
        # Projects built before tool caching already record their native choice.
        for record in (Path(project) / "addons/odin_godot/bin" / target / "box3d-runtime.json",
                       Path(project) / "bin/box3d-runtime.json"):
            try:
                value = json.loads(record.read_text())
                if value.get("target") == target:
                    selected = value.get("source_library", "")
                    if selected:
                        break
            except (OSError, ValueError, AttributeError):
                continue
    if selected and not Path(selected).is_file():
        raise ValueError(f"Selected Box3D input is missing: {selected}. Build the backend again and set {variable} once.")
    return str(Path(selected).resolve()) if selected else ""


def resolved(project, target, env):
    cache = read_cache(project)
    values = {key: resolve_tool(key, cache, env) for key in TOOLS}
    if not values["odin"]:
        raise ValueError("Odin compiler not found. Set ODIN to its executable or build once from the toolchain shell.")
    backend_key = "web" if target == "web" else "native_" + target
    values["box3d_" + backend_key] = resolve_backend(project, backend_key, target, cache, env)
    if any("\n" in value or "\r" in value for value in values.values()):
        raise ValueError("Newlines are unsupported in toolchain paths")
    return values


def remember(project, root, values):
    directory = cache_path(project)
    directory.mkdir(parents=True, exist_ok=True)
    values = dict(values, root=str(Path(root).resolve()), python3=sys.executable)
    # Separate atomic entries let simultaneous native/web builds remember their
    # own targets without losing another build's settings. Plain paths also let
    # the shell bootstrap Python when GUI launches do not inherit it on PATH.
    for key, value in values.items():
        if not value:
            continue
        if "\n" in value or "\r" in value:
            raise ValueError("Newlines are unsupported in toolchain paths")
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as output:
                temporary = Path(output.name)
                output.write(value + "\n")
            os.replace(temporary, directory / key)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--target", choices=("macos", "linux", "windows", "web"), required=True)
    parser.add_argument("--remember", action="store_true")
    parser.add_argument("--root", type=Path)
    args = parser.parse_args()
    values = resolved(args.project, args.target, os.environ)
    if args.remember:
        if args.root is None:
            parser.error("--remember requires --root")
        remember(args.project, args.root, values)
    else:
        for key in ("odin", "emcc", "box3d_web" if args.target == "web" else "box3d_native_" + args.target):
            print(values[key])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Odin setup: {error}", file=sys.stderr)
        raise SystemExit(1)
