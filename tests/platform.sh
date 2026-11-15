#!/usr/bin/env bash
# Native fixture paths must match the artifacts built for the current host.
# Source this after resolving ROOT; it does not install traps or change options.
odin_godot_test_platform_init() {
    case "$1" in
        Darwin)
            ODIN_GODOT_TEST_PLATFORM=macos
            ODIN_GODOT_TEST_LIB_EXT=dylib
            ;;
        Linux)
            ODIN_GODOT_TEST_PLATFORM=linux
            ODIN_GODOT_TEST_LIB_EXT=so
            ;;
        MINGW*|MSYS*|CYGWIN*)
            ODIN_GODOT_TEST_PLATFORM=windows
            ODIN_GODOT_TEST_LIB_EXT=dll
            ;;
        *)
            echo "Unsupported native fixture host: $1" >&2
            return 2
            ;;
    esac
    export ODIN_GODOT_TEST_PLATFORM ODIN_GODOT_TEST_LIB_EXT
}

odin_godot_test_platform_init "$(uname -s)"

# Godot's native export layout differs between a macOS app bundle and Linux.
odin_godot_test_export_paths() {
    local project="$1" bundle="$2" macos_executable="$3" machine="${4:-$(uname -m)}"
    case "$ODIN_GODOT_TEST_PLATFORM" in
        macos)
            ODIN_GODOT_TEST_EXPORT_PRESET=macOS
            ODIN_GODOT_TEST_EXPORT_PATH="$project/out/$bundle.app"
            ODIN_GODOT_TEST_EXPORTED_EXE="$ODIN_GODOT_TEST_EXPORT_PATH/Contents/MacOS/$macos_executable"
            ODIN_GODOT_TEST_EXPORTED_LIBDIR="$ODIN_GODOT_TEST_EXPORT_PATH/Contents/Frameworks"
            ;;
        linux)
            case "$machine" in
                x86_64|amd64) machine=x86_64 ;;
                aarch64|arm64) machine=arm64 ;;
                *) echo "Unsupported Linux export architecture: $machine" >&2; return 2 ;;
            esac
            ODIN_GODOT_TEST_EXPORT_PRESET="Linux $machine"
            ODIN_GODOT_TEST_EXPORT_PATH="$project/out/$bundle.$machine"
            ODIN_GODOT_TEST_EXPORTED_EXE="$ODIN_GODOT_TEST_EXPORT_PATH"
            ODIN_GODOT_TEST_EXPORTED_LIBDIR="$project/out"
            ;;
        *)
            echo "No native export fixture for $ODIN_GODOT_TEST_PLATFORM" >&2
            return 2
            ;;
    esac
}
