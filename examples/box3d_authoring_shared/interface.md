Shared authored sample interface (P5.4)

Main root is Sample:Node3D with script res://modules/authoring_demo/demo.odin.
Kit class KitAuthoringDemo / Replay class ReplayAuthoringDemo. Direct source
child path AuthoredWorld instances content/world.tscn; its namespace is
box3d.authored.sample.v1. Drivers extract once and free authoring source nodes;
view never reads them. Source assets are identical in both siblings.

Body keys ground,pendulum,player,sensor; Resource keys <body>.shape. Ground
Static at(0,-.25,0), box half(5,.25,5). Pendulum Dynamic at(-2,2,0), half(.2,.75,.2).
Player Dynamic sphere at(0,.5,0),radius.35. Sensor Static box at(0,.2,0),half(1.5,.2,1.5).
Hinge pendulum.hinge ground->pendulum, local anchors(-2,3.25,0)/(0,1,0), Z limits±.75.
No automatic physics nodes or extra character/joint profile.

Exact methods accepted by p/q:
status()->JSON String: framework,role,phase,head,confirmed,error; reset_supported.
presentation()->JSON String: {version:1,bodies:[{key:string,position:[3],rotation:[x,y,z,w]}]}.
control(x:i32,z:i32,pulse:bool), request_reset()->bool, close()->bool.
No native handles/instance IDs in presentation. U64 logical IDs stay opaque strings.
Shared five control bytes, x/z±1+Space bool. Both seats act on same player;
agreed impulse scales axes.04/pulse.2. UI only latches raw input; each driver's
existing fixed60 framework boundary samples it. SCRIPTED1 skips UI control calls.
Replay public manual reset is unsupported; status disables its button, false is
shown explicitly. No replacement recovery protocol.

Env: BOX3D_SAMPLE_ROLE(host/client),PORT,TICKS,SCRIPTED,OUTPUT. Root/p/q own
networking/owner/canonical-state and automated bounded behavior. The GDScript
view only reads copied driver values, updates MeshInstance3D proxies/camera/HUD
and requests existing controls/reset/close. It has no _physics_process/tick/solver.

Preparation: python3 examples/box3d_authoring_shared/prepare.py --framework kit
(or replay) --out NEW --native-library VERIFIED_NATIVE [--native-sha256 SHA]
[--build --odin ODIN --godot GODOT]. Builds standard Core/scripts/modules with
-o:speed and ordinary debug, never Native; all output/generation is staged.
Open NEW/project/project.godot or run official Godot with --path NEW/project.
Root owns real dual-process runs; stage/build reports are not runtime acceptance.
