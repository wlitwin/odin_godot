"""Build a Room-enabled game's native import and Web release, and zip the HTML5 bundle."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import zipfile
import web_rtc_template as rtc

ROOT = Path(__file__).resolve().parents[1]

def run(argv, env):
    subprocess.run([str(arg) for arg in argv], check=True, env=env)

def build(project, name, box3d):
    cache = project / ".cache"
    cache.mkdir(exist_ok=True)
    env = dict(os.environ, ODIN_GODOT_ROOT=str(ROOT), BINARYEN_CORES="1")
    godot = env.get("GODOT") or shutil.which("godot")
    if not godot:
        raise SystemExit("Set GODOT to Godot 4.7.1.")
    if box3d:
        native_target = "macos" if platform.system()=="Darwin" else "linux"
        remembered = project / ".godot/odin_godot/toolchain" / ("box3d_native_"+native_target)
        if not env.get("BOX3D_NATIVE_LIBRARY") and remembered.is_file():
            path = remembered.read_text().strip()
            if Path(path).is_file(): env["BOX3D_NATIVE_LIBRARY"]=path
        if not env.get("BOX3D_NATIVE_LIBRARY"):
            run(["bash",ROOT/"build/build_box3d.sh","Release",cache/"box3d"],env)
            ext = "dylib" if native_target=="macos" else "so"
            env["BOX3D_NATIVE_LIBRARY"]=str(cache/"box3d/build/Release"/("libogb3."+ext))
        if not env.get("BOX3D_WEB_ARCHIVE"):
            result=subprocess.check_output(["bash",str(ROOT/"build/build_box3d.sh"),"WebSIMD",str(cache/"box3d")],env=env,text=True)
            env["BOX3D_WEB_ARCHIVE"]=json.loads(result.splitlines()[-1])["archive"]
    else:
        env.pop("BOX3D_WEB_ARCHIVE",None)
        env.pop("BOX3D_NATIVE_LIBRARY",None)
    record=cache/"rtc-template/template-record.json"
    if not record.is_file():
        data = Path.home()/"Library/Application Support" if platform.system()=="Darwin" else Path(os.getenv("XDG_DATA_HOME",Path.home()/".local/share"))
        source=Path(os.getenv("GODOT_WEB_TEMPLATE",data/("Godot" if platform.system()=="Darwin" else "godot")/"export_templates/4.7.1.stable/web_dlink_release.zip"))
        rtc.derive(source,record.parent)
    with tempfile.TemporaryDirectory(prefix="itch-",dir=cache) as tmp:
        stage=Path(tmp)/"project"
        stage.mkdir()
        files=subprocess.check_output(["git","-C",str(project),"ls-files","-co","--exclude-standard","-z"]).decode().split("\0")
        for rel in filter(None,files):
            path=Path(rel)
            if path.parts[0] in ("tests","docs") or not (path.suffix in (".gd",".uid",".tscn",".tres",".odin",".gdextension",".gdshader",".png",".wav",".ogg") or rel in ("project.godot","export_presets.cfg","build.sh")):
                continue
            dst=stage/path
            dst.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(project/path,dst)
        rtc.select(record,stage)
        run(["bash",stage/"build.sh"],env)
        export=Path(tmp)/"web"
        export.mkdir()
        result=subprocess.run([godot,"--headless","--path",str(stage),"--export-release","Web",str(export/"index.html")],
                              env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        if result.returncode or "SCRIPT ERROR" in result.stdout or "ERROR:" in result.stdout:
            raise RuntimeError("Godot Web export failed.\n"+result.stdout)

        for leaf in ("index.html","index.js","index.wasm","index.side.wasm","index.pck","libodin_godot.wasm"):
            if not (export/leaf).is_file(): raise RuntimeError("missing Web export file "+leaf)
        archive=Path(tmp)/(name+"-html5.zip")
        with zipfile.ZipFile(archive,"x",zipfile.ZIP_DEFLATED,compresslevel=6) as zipout:
            for file in sorted(export.iterdir()):
                if file.is_file(): zipout.write(file,file.name)
        out=project/"out"
        out.mkdir(exist_ok=True)
        archive.replace(out/archive.name)
        print(out/archive.name)

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project",type=Path)
    parser.add_argument("name")
    parser.add_argument("--box3d",action="store_true")
    a=parser.parse_args()
    build(a.project.resolve(),a.name,a.box3d)
