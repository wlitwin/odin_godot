Independent-process Box3D network gate (P3.5)

Run inside the development shell, against a frozen native archive with its
adjacent build-manifest.json. Outputs must be fresh immutable directories.

    python3 tests/box3d_network/build.py --archive ABS/Debug/libogb3.a --out ABS/endpoints-Debug --schema
    python3 tests/box3d_network/build.py --archive ABS/Release/libogb3.a --out ABS/endpoints-Release --schema
    odin build tests/box3d_protocol/inspect -collection:godot=. -out:ABS/inspect
    python3 tests/box3d_network/matrix.py --debug ABS/endpoints-Debug --release ABS/endpoints-Release --out ABS/matrix --inspector ABS/inspect

Linux uses the existing /work/odin/odin through --odin on build.py and the
existing frozen Linux native archive, in separate /work scratch. Use the actual
resolved host path for podman cp; preserve the user's VM.

The transport is actual local TCP framing, with a bounded test-only logical
Unreliable impairment adapter. Reliable frames remain copied, retained and in
order. Kit Stream ordering is independent of Reliable traffic. This does not
certify ENet/UDP/Godot deployment or throughput. test_relay.py exercises mixed
channel ordering over actual sockets. Endpoint packet_received logs are actual
consumption; relay socket_scheduled/socket_write logs are not that evidence.

Control commands contain tick/lifecycle/diagnostic coordination only, never
solver truth. Both existing framework runners own all simulation and recovery.
Same-target/configuration confirmed signatures, exact final five-part bytes,
accepted decisions/provenance, scripted applied actions, pending-end deadlines,
effect delivery lifecycle/payloads, owner budgets and shutdown are assertions.
Wrong build/catalog/rules/schema, malformed authority packets and an explicitly
lying faulty test model are meaningful negative controls. First production
traces survive and must pass the native-free inspector's exact roundtrip.

The matrix is functional. Whole-call 4 ms correction remains UNMET GateB/P4.4.
