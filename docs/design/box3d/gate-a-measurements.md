# Box3D native feasibility measurements

Recorded 2026-10-30 for P1.4, task `t_979cf60bfd7241f0`, board
`b_cdde1cdfea104035`. This is executed evidence; the independent
[Gate A report](gate-a.md) decides proceed, pivot or stop.

The required matrix passed **32/32 cases**: macOS arm64 and Linux x86-64,
Debug/Release, 100/500 initial dynamic bodies, four fixed seeds, 2,400 forward
ticks, H=128 and 1–30-tick rewinds. Linux executed in the pinned Debian amd64
Podman image using Rosetta on the arm64 host; this is observed x86-64 execution,
not a native Linux throughput claim or a remote CI run. Two additional Release
cases measured 32 initial dynamic bodies on macOS directly, rather than
extrapolating a smaller slice from larger cases.

Across all 34 cases: **121,642** ordinary complete-state byte/game
comparisons, **40,008** replayed ticks, **2,550**
rewinds, **646** distinct branch exercises and
**1,292** branch restore/next-step oracle comparisons;
zero reported mismatches. Comparisons use an independently advancing reference
world, not only a motion hash. Raw logs were rehashed and revalidated with the
strict version-2 parser before this report was generated.

## Source and correctness boundary

Selected Box3D `d421e45c828f6f853a145f726f0b9425d31146eb`, isolated snapshot
shim and flat C/Odin boundary are recorded in
[dependency.json](../../../box3d/dependency.json). The normalized solver format
is **2**, coverage `ogb3-d421e45c-solver-v2`.
Three explicitly hashed patches fix actual pinned-engine failures:

1. Unaligned free-list pointer access at odd allocator strides.
2. Misaligned shared hull/mesh blobs in packed compound geometry.
3. Skipped broadphase rebuilding when destruction removed the last moved proxy.
   This reproduced with three public-operation bodies and crashed the untouched
   500-body reference trajectory at tick 1,760. The patched reference and full
   rewind corpus complete all 2,400 ticks.

Native Debug, Release, full unsuppressed ASan+UBSan, ownership failure controls
and actual Odin integration are recorded in
[the lifecycle report](../../../tests/box3d_native/report.md) and
[stress support report](../../../tests/box3d_native/p1.4-support.md).
Native and owned-wrapper tracked bytes return to zero in teardown controls.
Inactive inline material is excluded from the versioned normalized comparison;
active material changes remain detected. Public world-domain saturation has
defined capacity results without an unguarded fingerprint probe or allocator
takeover.

Complete solver final digests differ in **all 16 matched macOS/Linux case pairs**,
while game-side final digests match. This establishes same-build restore/replay
agreement independently in each tested target. It does not establish exact
cross-target solver agreement, identify its cause, or authorize floating-point
P2P. Canonical recovery and mixed-target authority correction need their own
codec and measured agreement contracts; local opaque images do not supply them.

## Timing results

Each cell is **p50 / p95 / maximum in milliseconds** for one seed. Steady
step/save each have 2,273 samples after history fill. Normal restore and suffix
replay each have 75 samples. Suffix cost includes fixture game/solver advancement
plus history saves, excluding diagnostic byte comparison, memory accounting and
printed samples. It excludes initial restore; the Gate A review pairs those
samples rather than adding unrelated marginal quantiles. Step+save omits some
application/command/presentation work and is not a complete rendered-frame
measurement. Both build modes retain assertions, heavy validation, no fast math
and disabled FP contraction.

| Target | Build | Initial dynamic bodies | Seed | Steady step | Steady save | Restore | Suffix replay |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| macOS arm64 | Debug | 100 | 1 | 0.329/0.668/3.939 | 2.032/2.365/27.418 | 0.470/0.507/0.668 | 47.577/78.582/103.445 |
| macOS arm64 | Debug | 100 | 7 | 0.347/0.694/12.572 | 2.066/2.525/8.888 | 0.485/0.533/0.631 | 47.403/81.826/104.364 |
| macOS arm64 | Debug | 100 | 1234 | 0.334/0.664/1.598 | 2.039/2.337/5.200 | 0.470/0.536/0.613 | 29.485/77.708/100.151 |
| macOS arm64 | Debug | 100 | 3221344269 | 0.346/0.686/2.227 | 2.069/2.593/7.998 | 0.480/0.671/0.994 | 37.775/78.320/102.447 |
| macOS arm64 | Debug | 500 | 1 | 2.817/3.784/17.179 | 11.302/14.102/35.782 | 2.554/3.874/4.718 | 268.039/455.569/544.033 |
| macOS arm64 | Debug | 500 | 7 | 2.623/3.491/9.433 | 11.511/12.918/58.309 | 2.568/3.016/3.542 | 257.389/433.442/579.869 |
| macOS arm64 | Debug | 500 | 1234 | 2.756/3.852/5.762 | 11.611/12.995/24.710 | 2.605/3.267/4.999 | 184.805/460.104/563.117 |
| macOS arm64 | Debug | 500 | 3221344269 | 2.801/3.629/11.287 | 11.442/12.577/25.971 | 2.558/3.493/3.896 | 216.978/444.941/565.852 |
| macOS arm64 | Release | 100 | 1 | 0.064/0.085/0.669 | 1.335/1.591/7.586 | 0.417/0.482/0.764 | 25.426/44.560/47.485 |
| macOS arm64 | Release | 100 | 7 | 0.062/0.079/0.280 | 1.328/1.546/3.799 | 0.413/0.471/0.884 | 26.084/43.881/46.975 |
| macOS arm64 | Release | 100 | 1234 | 0.061/0.080/0.306 | 1.327/1.672/5.540 | 0.414/0.545/0.852 | 16.860/42.479/53.498 |
| macOS arm64 | Release | 100 | 3221344269 | 0.059/0.077/0.104 | 1.321/1.563/3.175 | 0.403/0.458/0.469 | 20.372/42.481/45.156 |
| macOS arm64 | Release | 500 | 1 | 0.370/0.516/2.514 | 7.243/8.292/27.372 | 2.201/3.459/5.605 | 137.000/233.140/243.356 |
| macOS arm64 | Release | 500 | 7 | 0.415/0.615/9.023 | 7.599/10.294/29.413 | 2.369/3.308/4.948 | 154.245/277.655/314.299 |
| macOS arm64 | Release | 500 | 1234 | 0.408/0.576/5.216 | 7.476/9.349/22.477 | 2.264/2.960/5.916 | 97.648/248.247/259.356 |
| macOS arm64 | Release | 500 | 3221344269 | 0.407/0.600/2.590 | 7.309/10.005/26.046 | 2.306/3.173/4.689 | 117.951/244.006/349.830 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1 | 0.782/1.363/5.141 | 2.093/2.456/9.062 | 0.531/0.948/1.698 | 57.730/102.755/154.553 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 7 | 0.804/1.410/12.292 | 2.135/2.700/46.188 | 0.552/0.888/3.996 | 58.657/105.283/246.910 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1234 | 0.803/1.392/6.926 | 2.139/2.577/33.105 | 0.542/0.707/2.738 | 36.675/97.398/151.594 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 3221344269 | 0.840/1.400/11.572 | 2.184/2.434/26.539 | 0.558/0.663/4.025 | 49.426/98.902/168.512 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1 | 5.079/6.372/11.031 | 11.830/13.211/35.312 | 2.735/3.348/4.271 | 309.332/528.611/734.361 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 7 | 4.741/6.147/12.463 | 11.882/13.195/19.616 | 2.705/3.739/5.264 | 298.072/515.066/743.671 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1234 | 4.902/6.428/11.626 | 11.479/13.175/28.405 | 2.658/3.430/3.881 | 199.569/514.860/735.732 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 3221344269 | 5.268/6.901/16.835 | 12.282/16.398/54.471 | 2.930/5.719/8.670 | 257.599/566.224/709.717 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1 | 0.105/0.137/0.953 | 1.302/1.422/3.016 | 0.450/0.570/1.911 | 25.921/43.748/51.332 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 7 | 0.117/0.300/2.176 | 1.352/2.311/4.811 | 0.490/1.223/2.701 | 28.987/55.333/82.764 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1234 | 0.107/0.154/3.845 | 1.313/1.487/5.145 | 0.457/0.527/1.939 | 16.847/44.633/67.453 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 3221344269 | 0.109/0.144/2.256 | 1.312/1.471/6.398 | 0.457/0.551/1.959 | 21.172/43.776/61.429 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1 | 0.636/0.919/8.925 | 7.153/8.374/74.379 | 2.323/2.833/3.817 | 137.384/249.300/301.313 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 7 | 0.563/0.875/3.289 | 7.082/8.247/21.656 | 2.312/2.779/4.125 | 137.453/248.683/281.491 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1234 | 0.588/0.935/5.715 | 7.186/9.072/27.657 | 2.337/3.044/5.402 | 93.653/245.871/291.642 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 3221344269 | 0.591/0.862/3.644 | 7.159/8.153/22.598 | 2.340/3.575/11.876 | 114.351/242.563/310.840 |
| macOS arm64, bounded slice | Release | 32 | 1 | 0.014/0.017/0.040 | 0.332/0.357/2.531 | 0.108/0.130/0.262 | 6.101/10.340/11.161 |
| macOS arm64, bounded slice | Release | 32 | 7 | 0.014/0.017/0.177 | 0.335/0.360/3.127 | 0.105/0.132/0.152 | 6.431/10.798/14.927 |

The 100/500-body optimized deep-rewind tails do not fit an unconditional
16.667 ms frame budget. The directly measured 32-body supplement is a candidate
for a bounded alpha, not proof of arbitrary scene costs. It reaches 35 total
bodies/shapes, 147 reference contacts and one joint; integrated Kit/Replay,
networking and presentation costs still need measurement. Use actual paired
operation data and explicit prediction/repair limits when selecting an envelope.

## Retained and peak requested memory

Values are MiB. Native and wrapper history are retained-resource maxima;
the normalized cache is **part of wrapper history**, not extra memory to add.
Global high-water values include fixture verification, temporary scratch and
branch activity. Reference dumps are benchmark-only. Do not add separate maxima
and call the result an exact simultaneous deployment peak. Current caches and
per-capture geometry registries are real retained costs even if a future
optimization could reduce duplication.

| Target | Build | Bodies | Seed | Native history | Wrapper history | Included normalized cache | Engine high water | Wrapper high water | Reference dump ring |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| macOS arm64 | Debug | 100 | 1 | 65.90 | 37.68 | 37.66 | 68.50 | 37.97 | 37.66 |
| macOS arm64 | Debug | 100 | 7 | 65.94 | 37.68 | 37.66 | 68.26 | 37.97 | 37.66 |
| macOS arm64 | Debug | 100 | 1234 | 66.35 | 37.68 | 37.66 | 68.51 | 37.97 | 37.66 |
| macOS arm64 | Debug | 100 | 3221344269 | 65.65 | 37.68 | 37.66 | 67.78 | 37.97 | 37.66 |
| macOS arm64 | Debug | 500 | 1 | 402.25 | 202.06 | 202.03 | 413.01 | 203.61 | 202.03 |
| macOS arm64 | Debug | 500 | 7 | 411.33 | 202.10 | 202.07 | 421.32 | 203.65 | 202.07 |
| macOS arm64 | Debug | 500 | 1234 | 433.19 | 202.04 | 202.01 | 443.63 | 203.59 | 202.01 |
| macOS arm64 | Debug | 500 | 3221344269 | 414.34 | 202.04 | 202.01 | 424.56 | 203.59 | 202.01 |
| macOS arm64 | Release | 100 | 1 | 65.90 | 37.68 | 37.66 | 68.50 | 37.97 | 37.66 |
| macOS arm64 | Release | 100 | 7 | 65.94 | 37.68 | 37.66 | 68.26 | 37.97 | 37.66 |
| macOS arm64 | Release | 100 | 1234 | 66.35 | 37.68 | 37.66 | 68.51 | 37.97 | 37.66 |
| macOS arm64 | Release | 100 | 3221344269 | 65.65 | 37.68 | 37.66 | 67.78 | 37.97 | 37.66 |
| macOS arm64 | Release | 500 | 1 | 402.25 | 202.06 | 202.03 | 413.01 | 203.61 | 202.03 |
| macOS arm64 | Release | 500 | 7 | 411.33 | 202.10 | 202.07 | 421.32 | 203.65 | 202.07 |
| macOS arm64 | Release | 500 | 1234 | 433.19 | 202.04 | 202.01 | 443.63 | 203.59 | 202.01 |
| macOS arm64 | Release | 500 | 3221344269 | 414.34 | 202.04 | 202.01 | 424.56 | 203.59 | 202.01 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1 | 65.90 | 37.68 | 37.66 | 68.50 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 7 | 65.93 | 37.68 | 37.66 | 68.26 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1234 | 66.35 | 37.68 | 37.66 | 68.51 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 3221344269 | 65.65 | 37.68 | 37.66 | 67.77 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1 | 402.24 | 202.06 | 202.03 | 413.01 | 203.61 | 202.03 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 7 | 411.33 | 202.10 | 202.07 | 421.31 | 203.65 | 202.07 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1234 | 433.19 | 202.04 | 202.01 | 443.63 | 203.59 | 202.01 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 3221344269 | 414.34 | 202.04 | 202.01 | 424.56 | 203.59 | 202.01 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1 | 65.90 | 37.68 | 37.66 | 68.50 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 7 | 65.93 | 37.68 | 37.66 | 68.26 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1234 | 66.35 | 37.68 | 37.66 | 68.51 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 3221344269 | 65.65 | 37.68 | 37.66 | 67.77 | 37.97 | 37.66 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1 | 402.24 | 202.06 | 202.03 | 413.01 | 203.61 | 202.03 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 7 | 411.33 | 202.10 | 202.07 | 421.31 | 203.65 | 202.07 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1234 | 433.19 | 202.04 | 202.01 | 443.63 | 203.59 | 202.01 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 3221344269 | 414.34 | 202.04 | 202.01 | 424.56 | 203.59 | 202.01 |
| macOS arm64, bounded slice | Release | 32 | 1 | 20.85 | 9.78 | 9.76 | 21.99 | 9.86 | 9.76 |
| macOS arm64, bounded slice | Release | 32 | 7 | 20.85 | 9.79 | 9.76 | 22.00 | 9.86 | 9.76 |

Raw results also retain game/history/reference metadata, fixed simulation sizes,
per-operation engine allocation requests and cumulative owned-wrapper requests.
Wrapper counters cover Resource/owner/slots/normalized buffers/world leases and
digest temporaries. Flat-API geometry bookkeeping, allocator headers/rounding,
general call-stack/runtime and Odin allocation overhead remain outside requested
bytes. These are not RSS values. This timed owner replaces history as it replays;
a framework's transactional suffix must reserve and measure additional staging.

## Actual accepted-reference workloads

The C helper uses public counters with the measured archive's exact compiler/ABI
flags. A baseline-only entry point comes from the same tracked fixture and must
reproduce each case's final complete solver **and** game digests. These are peaks
along that accepted reference trajectory, not speculative branch-oracle peaks.
Moving-tree height is the maximum dynamic/kinematic tree height, excluding static.

| Target | Build | Initial dynamic | Seed | Total bodies | Shapes | Contacts | Joints | Islands | Moving tree height |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| macOS arm64 | Debug | 100 | 1 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Debug | 100 | 7 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Debug | 100 | 1234 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Debug | 100 | 3221344269 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Debug | 500 | 1 | 503 | 503 | 4675 | 1 | 500 | 25 |
| macOS arm64 | Debug | 500 | 7 | 503 | 503 | 4675 | 1 | 500 | 26 |
| macOS arm64 | Debug | 500 | 1234 | 503 | 503 | 4675 | 1 | 500 | 24 |
| macOS arm64 | Debug | 500 | 3221344269 | 503 | 503 | 4675 | 1 | 500 | 24 |
| macOS arm64 | Release | 100 | 1 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Release | 100 | 7 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Release | 100 | 1234 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Release | 100 | 3221344269 | 103 | 103 | 819 | 1 | 100 | 11 |
| macOS arm64 | Release | 500 | 1 | 503 | 503 | 4675 | 1 | 500 | 25 |
| macOS arm64 | Release | 500 | 7 | 503 | 503 | 4675 | 1 | 500 | 26 |
| macOS arm64 | Release | 500 | 1234 | 503 | 503 | 4675 | 1 | 500 | 24 |
| macOS arm64 | Release | 500 | 3221344269 | 503 | 503 | 4675 | 1 | 500 | 24 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 7 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 1234 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Debug | 100 | 3221344269 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1 | 503 | 503 | 4675 | 1 | 500 | 25 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 7 | 503 | 503 | 4675 | 1 | 500 | 26 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 1234 | 503 | 503 | 4675 | 1 | 500 | 24 |
| Linux x86-64 (Podman/Rosetta) | Debug | 500 | 3221344269 | 503 | 503 | 4675 | 1 | 500 | 24 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 7 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 1234 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Release | 100 | 3221344269 | 103 | 103 | 819 | 1 | 100 | 11 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1 | 503 | 503 | 4675 | 1 | 500 | 25 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 7 | 503 | 503 | 4675 | 1 | 500 | 26 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 1234 | 503 | 503 | 4675 | 1 | 500 | 24 |
| Linux x86-64 (Podman/Rosetta) | Release | 500 | 3221344269 | 503 | 503 | 4675 | 1 | 500 | 24 |
| macOS arm64, bounded slice | Release | 32 | 1 | 35 | 35 | 147 | 1 | 32 | 7 |
| macOS arm64, bounded slice | Release | 32 | 7 | 35 | 35 | 147 | 1 | 32 | 7 |

## Reproduction and retained evidence

[The benchmark README](../../../tests/box3d_bench/README.md) documents the runner,
strict record/phase/sample schema, workload profiler and measurement domains.
Source/patch hashes, compiler commands, SIMD/precision/assert macros, binary and
archive hashes, CPU/OS/Odin versions, load, per-case raw logs/results and helper
source hashes remain with each run.

Local artifact roots are temporary working evidence that system cleanup may remove:

- macOS arm64: `/private/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-goal-t4jbbj4v/bench-gate-a-macos-final`; summary SHA-256 `30c6b7d6326680872a99b83d9695afb20aff2e0bdb8abcef3aa8897d3241a028`, counts SHA-256 `db6a3a7db32b09e3cd09343e2999d0b6d070c1891d78e63f9d07e8a6f2d78525`.

- Linux x86-64 (Podman/Rosetta): `/private/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-goal-t4jbbj4v/bench-gate-a-linux-final`; summary SHA-256 `9266211081eb13181e3e7d82758c1a10336c84d854bb476921fd036879c82539`, counts SHA-256 `f40b93c1ef0658ff1ebdc58016456b924390f41cc90b0a7ef227f54208e78c99`.

- macOS arm64, bounded slice: `/private/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-goal-t4jbbj4v/bench-slice32-release`; summary SHA-256 `d66722b1a3c9557b691eae1af4388756700cc9c870554bdb6b053ec7b2ee44a5`, counts SHA-256 `e3166d8d3c7fceeb670db0cd9af8184c8457380f59307dfb83f38189e552511d`.


The herdr-tasks finish report copies machine-readable summaries, workload counts
and verification metadata into persistent task storage. These checks do not
claim that framework adapters, portable transfer, editor authoring, export/runtime
parity or production hardening are implemented.
