# Box3D upstream reproduction baseline

Recorded 2026-10-30 on macOS arm64 for P0.1, board `b_cdde1cdfea104035`.
This report records executed checks, separately from upstream feature claims.
It supplies evidence for both the Kit and Replay integration designs; neither
framework adapter is implemented by these upstream builds.

## Exact revisions

| Component | Standalone rollback baseline | multi-box-3d game baseline |
|---|---|---|
| Top-level repository | `pdaddyo/rollback-in-a-box` at `9e1fe882a0ea4eb52e160d5754a752580b4db462` | `pdaddyo/multi-box-3d` at `987f4ca44d0065676f17cab35edad57fcbb63b13` |
| rollback-in-a-box | Same as top level | Git submodule `91e01dc75e8dfe3fbd890f21361e27b31fa2e994` |
| Box3D | `d421e45c828f6f853a145f726f0b9425d31146eb` | `540ea387b0c02bf714fbfdcc8fb88c039c35fe6f` |
| godot-cpp | `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` (`godot-4.5-stable`) | Same |

These are different physics/snapshot baselines. The game's tests exercise its
older pinned shim and cannot establish correctness of the current standalone
engine-neutral extraction. Its submodule was not advanced for this audit.

Sources: [standalone dependency setup](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/gdext/setup_deps.sh),
[game dependency setup](https://github.com/pdaddyo/multi-box-3d/blob/987f4ca44d0065676f17cab35edad57fcbb63b13/gdext/setup_deps.sh),
[game submodule](https://github.com/pdaddyo/rollback-in-a-box/tree/91e01dc75e8dfe3fbd890f21361e27b31fa2e994).

## Executed environment and build settings

- macOS 15.8, build 24H23, arm64.
- Apple Clang 16.0.0 (`clang-1600.0.26.6`), Xcode SDK 15.2.
- CMake 3.31.3, GNU Make 3.81, Python 3.9.6.
- Godot `/Applications/Godot.app/Contents/MacOS/Godot`, verified
  `4.7.1.stable.official.a13da4feb`.
- Debug GDExtension builds, `GODOTCPP_TARGET=template_debug`, arm64,
  C++17 and position-independent code. Generated compile commands show
  `-ffp-contract=off` in Box3D, the shim, the neutral core, and game simulation;
  no fast-math flag was enabled. Debug compilation used `-g`.
- Used `Unix Makefiles` instead of documented `Ninja` because Ninja was absent
  from both the host PATH and this repository's Nix development shell. This
  changes the build executor; source pins and simulation compiler flags were
  kept. Standalone compilation used eight jobs, game compilation six.
- The Nix development shell successfully resolved Odin dev-2026-04 and the
  same installed Godot; it was not needed to compile these C/C++ projects.

## Reproduction commands

Run each project in a separate scratch checkout. Restore its listed revision
before dependency setup; the game setup initializes its exact Git submodule.

```sh
git clone https://github.com/pdaddyo/rollback-in-a-box.git rollback-in-a-box
git -C rollback-in-a-box checkout --detach 9e1fe882a0ea4eb52e160d5754a752580b4db462
cd rollback-in-a-box
./gdext/setup_deps.sh
cmake -S gdext -B gdext/build-debug -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Debug -DGODOTCPP_TARGET=template_debug \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build gdext/build-debug --parallel 8
python3 tools/generate_bindings.py --check
GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tests/run_all.sh
```

```sh
git clone https://github.com/pdaddyo/multi-box-3d.git multi-box-3d
git -C multi-box-3d checkout --detach 987f4ca44d0065676f17cab35edad57fcbb63b13
cd multi-box-3d
./gdext/setup_deps.sh
cmake -S gdext -B gdext/build-debug -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Debug -DGODOTCPP_TARGET=template_debug \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build gdext/build-debug --parallel 6
GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tests/run_all.sh
```

## Results

The standalone Debug GDExtension built successfully. All 14 standalone headless
suites passed in 10.88 seconds, including raw API creation of six shape families
and nine joint families, restore/resimulation diagnostics, two/three/four-player
impairment cases, scope telemetry, recording/playback, and negative edge cases.
The game's exact-pinned Debug GDExtension also built successfully. Its full
headless runner passed all ten suites plus the two-process real-UDP test in
44.12 seconds. Scene/demo wiring, 600-frame diagnostic determinism and 16
rewinds, vehicle dynamics and 24 rewinds, all 52 part types across 13 samples,
droids, creatures, recording/playback and impaired loopback completed.

| Executed check | Observed result |
|---|---|
| Current standalone Debug GDExtension | Build passes |
| Current standalone generated binding coverage | Pass; 695 functions |
| Current standalone headless runner | 14/14 suites pass, exit 0 |
| Current neutral core without Godot | 101-body restore/resimulation smoke passes |
| Game at exact submodule/Box3D pins | Debug build passes |
| Game headless runner | 10/10 suites plus two-process UDP pass, exit 0 |

The recorded runner durations include process startup and tests on this host;
they are not the later snapshot/save/restore/replay performance benchmark.

Selected standalone output:

```text
raw api: OK functions=695 shapes=6 joints=9
compat: OK fingerprint=397738ffcc4056a1
loopback jitter loss: OK safe=1069 compared=61 rollbacks=[241,267]
4p asymmetric: OK safe=913 compared=61 rollbacks=[368, 379, 368, 358]
partial resim scoping: OK safe=677 compared=61 rollbacks=165
edge world snapshots: OK cases=10
edge world hashing: OK cases=9
edge session: OK cases=11
edge replay: OK cases=9
=== all tests passed ===
```

Negative marshaling and replay-lifecycle tests deliberately emit native `ERROR:`
guard diagnostics and corrupt-file messages. Their case checks and suite exit
statuses passed. The log contains no `SCRIPT ERROR:`, `Parse Error:` or `FAIL:`.
This distinction matters when inspecting the raw log: native guard diagnostics
are not a failed positive-path test.

Selected game output:

```text
smoke: OK (bodies=28, hash=6659768200539870231)
scene solo: OK (sim frame 118, 36 bodies)
demo solo: OK (frame 239, bodies 11, meshes 17, base hp 40)
determinism: lockstep OK (600 frames, final hash 7263763670055497844, bodies 53)
determinism: rollback OK (16 rollbacks, final hash 7263763670055497844)
vehicle: rollback OK (24 rollbacks, final hash 8124578669989092479)
samples: all 13 valid, all 52 part types covered
loopback[lat=4-12 loss=25 uneven]: OK  safe=3561 compared=91 rollback_frames=[1411,1311] stalls=[279,213] adv=[0.00,0.00]
vehicle-loopback[lat=3-9 loss=15 uneven]: OK  safe=3704 compared=91 rollback_frames=[926,754] stalls=[136,70] adv=[0.00,0.00]
peer0: frame 1200 hash -7515194666449427853 rollbacks 0 stalls 0
peer1: frame 1200 hash -7515194666449427853 rollbacks 0 stalls 1
netsync: OK (hashes match)
=== all tests passed ===
```

The real-UDP case uses localhost ports 7801/7802 and reached matching frame-1200
diagnostic hashes. It is a clean-delivery test, with zero rollback frames;
loss/jitter and actual rollback are exercised by the separate in-process
loopback cases. No `SCRIPT ERROR:`, `Parse Error:`, `FAIL:`, `WARNING:` or native
`ERROR:` appeared in the game runner log. Its Steam autoload initialized the
installed client, but live-account Steam gameplay was not tested. Account
identifiers from local logs are intentionally omitted here.

The standalone generated binding check passed:

```text
Box3D API: 695 functions, 108 structs, 215 enum constants
```

A separate scratch C++ executable linked only the current `core` static library
and its pinned Box3D library. `otool -L` lists only libc++ and libSystem, with no
Godot dynamic dependency. It created 100 dynamic boxes and a static floor,
recorded 240 frames, restored frame 60 and matched all 180 subsequent diagnostic
hashes, then added a sphere, restored frame zero, verified the sphere and its
body-table entry disappeared, and matched all 240 subsequent diagnostic hashes.
It also checked restored frame counters and live-body counts.

```text
PASS neutral core: 101 bodies, 240-tick baseline, 180+240 replayed hashes, spawned-body rollback; final=f82df34ea1c56292
```

This is observed motion-hash agreement and lifecycle/count agreement, not proof
that every hidden solver field matches. The upstream world hash covers live
transforms and awake velocities, combined with wrapper side-state; contacts,
joint internals, ID pools and sleep timers are not a complete part of that hash.
A full solver-state digest and corresponding mutation tests remain a Gate A
acceptance requirement. See the [snapshot audit](snapshot-audit.md).

## Evidence and limits

Scratch checkouts, generated compile commands, logs, and the standalone harness
are under:

```text
/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-phase0-qu5lt6zn/baseline/
```

The report retains the important observations and exact revisions; scratch paths
are local working evidence and may be removed by system temporary-file cleanup.
The standalone harness source and executable are `neutral-core-smoke.cpp` and
`neutral-core-smoke`; its successful output is `neutral-core-smoke.log`.

No tracked upstream files were modified. Godot import generated an untracked
`docs/logo.png.import` sidecar in the standalone scratch clone.

Recorded runner log SHA-256 values:

| Log | SHA-256 |
|---|---|
| `rollback-in-a-box-tests.log` | `8a4a48a2715a88a93cd6950fee3c15b8bce7bc553cdd4a24f2895f5b0a160a8b` |
| `multi-box-3d-tests.log` | `05d288c30eb24afecbed661c64de34543d660c809ee74d78bbde85f12c8de037` |

These checks do not establish Kit integration, Replay integration, canonical
cross-build recovery, cross-platform determinism, release-build behavior,
performance budgets, or interactive rendering quality. Those remain separate
roadmap acceptance gates. Upstream peer-session tests also do not select or
replace either sibling framework's authority/network model.

## Standalone native smoke source

For reproduction, save this as `neutral-core-smoke.cpp` beside the standalone
checkout, then compile from the checkout after its Debug core target is built:

```sh
/usr/bin/clang++ -std=c++17 -ffp-contract=off \
  -Icore/include -Icore/include/box3d_rollback -Igdext/extern/box3d/include \
  ../neutral-core-smoke.cpp \
  gdext/build-debug/core/libbox3d_rollback_neutral.a \
  gdext/build-debug/extern/box3d/src/libbox3dd.a -o ../neutral-core-smoke
../neutral-core-smoke
```

Assertions must remain enabled. This harness does not constitute the later full
solver-state digest or random-rewind performance benchmark.

```cpp
#include "box3d_rollback/rb_world.h"
#include <array>
#include <cassert>
#include <cstdio>

int main() {
    const int64_t neutral_inputs[2] = {0,0};
    rb::RollbackWorld world;
    world.create_world();
    world.add_static_box({0,-1,0}, {30,1,30});
    for (int i=0;i<100;++i) {
        world.add_dynamic_box({float(i%10)*1.1f-5.0f,2.0f+float(i/10)*1.1f,0}, {0.5f,0.5f,0.5f});
    }
    world.init_snapshots(2);
    std::array<uint64_t,241> hashes{};
    hashes[0]=world.get_state_hash();
    assert(world.save_state(0));
    for (int tick=1;tick<=240;++tick) {
        world.step_frame(neutral_inputs,2);
        hashes[tick]=world.get_state_hash();
        if(tick==60) assert(world.save_state(1));
    }
    assert(world.load_state(1));
    assert(world.get_frame()==60 && world.get_live_body_count()==101);
    assert(world.get_state_hash()==hashes[60]);
    for(int tick=61;tick<=240;++tick) {
        world.step_frame(neutral_inputs,2);
        assert(world.get_state_hash()==hashes[tick]);
    }
    world.add_dynamic_sphere({0,20,0},0.5f);
    assert(world.get_live_body_count()==102);
    assert(world.load_state(0));
    assert(world.get_frame()==0 && world.get_live_body_count()==101);
    assert(world.get_state_hash()==hashes[0]);
    for(int tick=1;tick<=240;++tick) {
        world.step_frame(neutral_inputs,2);
        assert(world.get_state_hash()==hashes[tick]);
    }
    std::printf("PASS neutral core: 101 bodies, 240-tick baseline, 180+240 replayed hashes, spawned-body rollback; final=%016llx\n", static_cast<unsigned long long>(hashes[240]));
}
```
