# Box3D bounds and authority tests

This suite keeps shared Native enforcement and the distinct Kit and Replay
entry points separate. It uses public constructors, codecs and transports, with
explicitly malformed candidates and unchanged-state/cleanup oracles. Existing
malformed recovery, authoring, motion and H128 cases remain separate evidence.

`run.py` defaults to an inspectable plan and starts no jobs. Use explicit Odin and
current Native paths/SHA, a new output outside the repository, and `--suite
native|common|kit|replay|all`. Root schedules `--execute` after a coherent source freeze.
One test thread preserves each process's global Native allocation accounting.
The Native groups use the public C headers and require an explicit absolute
`--cc` when executing; the Kit/Replay groups use the selected Odin compiler.

These standalone fixtures do not prove Core/Meter shared Host quota or hardware
CPU properties. The genuine SDK64MiB pressure and exported production evidence
remain in `../box3d_production/report.json`. A trusted raw body factory is not the
untrusted canonical/admission boundary. Likewise, Kit proposal sanitizers must
not be replayed blindly over signed canonical authority data.
