# build_scripts.ps1 — Windows: compile the odin_godot CORE dll + a project's SCRIPTS dll natively.
#
# The Windows counterpart of build/build_scripts.sh (bash, hardcodes .dylib). Building NATIVELY on
# Windows with the MSVC toolchain (Visual Studio Build Tools) is the SUPPORTED Odin Windows path and
# avoids the cross-compile stack-probe (__chkstk) ABI mismatch that the macOS-cross prebuilt dll hit
# (it crashed with "Illegal Instruction" at startup). So by default this builds BOTH:
#   - the CORE  -> <Root>\bin\windows\libodin_godot.dll   (the GDExtension; the .gdextension points here)
#   - scriptgen -> the codegen preprocessor
#   - the SCRIPTS dll -> <Project>\bin\libodinscripts.dll (the core loads this at res://bin/libodinscripts.dll)
# Pass -SkipCore to build only the scripts (e.g. you trust an existing core dll).
#
# Requirements: odin.exe (on PATH or -Odin) AND a working Odin link toolchain — run this from a
# "x64 Native Tools Command Prompt for VS" so link.exe + the Windows SDK are set up. See SETUP-WINDOWS.md.
#
# Usage (from that prompt, in the project folder):
#   powershell -ExecutionPolicy Bypass -File addons\odin_godot\build\build_scripts.ps1 `
#       -Root addons\odin_godot -Project . -Odin C:\odin\odin.exe
#
# Both dlls are built WITH debug info (-debug) so a crash yields a real backtrace.
# (Best-effort port — if a step fails it prints the exact command it ran; please report it.)

param(
    [Parameter(Mandatory = $true)][string]$Root,     # path to addons\odin_godot (the collection root + core/ source)
    [Parameter(Mandatory = $true)][string]$Project,  # path to the Godot project (must contain scripts\)
    [string]$Odin = "odin",                           # odin.exe, or an absolute path to it
    [switch]$SkipCore                                 # build only the scripts dll
)

$ErrorActionPreference = "Stop"
$Root    = (Resolve-Path $Root).Path
$Project = (Resolve-Path $Project).Path
$Scripts = Join-Path $Project "scripts"
$Bin     = Join-Path $Project "bin"
$WinBin  = Join-Path $Root "bin\windows"
New-Item -ItemType Directory -Force -Path $Bin    | Out-Null
New-Item -ItemType Directory -Force -Path $WinBin | Out-Null

if (-not (Test-Path $Scripts)) { throw "no scripts\ folder in project: $Scripts" }

function Run([string]$exe, [string[]]$argv) {
    Write-Host "> $exe $($argv -join ' ')"
    & $exe @argv
    if ($LASTEXITCODE -ne 0) { throw "command failed (exit $LASTEXITCODE): $exe $($argv -join ' ')" }
}

# 1. Build the CORE GDExtension dll natively (unless -SkipCore). This is the one that crashed when
#    cross-compiled from macOS; built natively with MSVC it uses the real __chkstk.
if (-not $SkipCore) {
    $core = Join-Path $WinBin "libodin_godot.dll"
    Remove-Item -Force -ErrorAction SilentlyContinue $core
    Run $Odin @("build", (Join-Path $Root "core"), "-collection:godot=$Root", "-build-mode:dll", "-out:$core", "-debug")
}

# 2. Build the scriptgen preprocessor.
$scriptgenExe = Join-Path $Root "scriptgen\scriptgen.exe"
Run $Odin @("build", (Join-Path $Root "scriptgen"), "-collection:godot=$Root", "-out:$scriptgenExe", "-debug")

# 3. Generate the *.gen.odin siblings beside the authored sources.
Run $scriptgenExe @($Scripts)

# 4. Compile the scripts package into the DLL the core loads (res://bin/libodinscripts.dll).
$out = Join-Path $Bin "libodinscripts.dll"
Remove-Item -Force -ErrorAction SilentlyContinue $out
Run $Odin @("build", $Scripts, "-collection:godot=$Root", "-build-mode:dll",
            "-custom-attribute:gd_method", "-custom-attribute:gd_connect", "-custom-attribute:gd_rpc",
            "-out:$out", "-debug")

Write-Host ""
if (-not $SkipCore) { Write-Host "Built core:    $(Join-Path $WinBin 'libodin_godot.dll')" }
Write-Host "Built scripts: $out"
Write-Host "Open the project in Godot and press Play."
