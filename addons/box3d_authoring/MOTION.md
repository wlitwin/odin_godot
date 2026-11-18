Motion authoring schema2

Box3DCharacterMover3D is configuration/initial POD only. It has no process hook,
physics query, hidden clock or live runtime. Position comes from rigid local
ancestry to World; config capsule/up and initial_velocity are explicit World-frame
vectors. Mover marker rotation must be identity; grounding/ground shape begin at
zero and arise only from real mover results stored by the framework Game/Side.
`exclude_body` is an optional explicit body stable key, never a native key.

Named Node3D classes: Box3DPinJoint3D, Box3DHingeJoint3D, Box3DSliderJoint3D,
Box3DSphericalJoint3D, Box3DDistanceJoint3D, Box3DMotorJoint3D, Box3DWeldJoint3D,
Box3DWheelJoint3D. Reusable settings Resources export the exact shared named
records. New joints use viewport anchors: the Node3D transform places/orients A,
and anchor_b_offset is B's full transform relative to that marker. Body pickers
display names/paths while body_a/body_b remain durable keys local to World.
The shared frame resolver derives local_frame_a/b in each body's space for the
detached schema. Advanced body-local mode keeps those fields authoritative;
the marker transform does not alter them. Existing owned scenes explicitly use
body-local mode to preserve their original definitions. Switching modes preserves
both endpoint positions and orientations or refuses the change without mutation.
Missing/self/cross-World references, two Static bodies, duplicate keys, unsupported
flags, invalid frames/limits and nonfinite values fail before extraction.

Godot's transform inheritance rule applies: a plain Node interrupts the chain.
Detached extraction reconstructs the same effective transforms as the live editor.
Move/rotate the joint node to edit viewport anchor A; drag B's handle or edit its
relative transform for a separate endpoint. Body-local mode exposes A/B position
handles and explicit transform fields. Cancel restores the exact previous value;
commit is one undo action. Distance target/rest length remains independently
authored, including when placing anchors at the body origins.

Pin uses Spherical with angular features disabled. Hinge is Revolute about localZ;
Slider is Prismatic about localX. Wheel suspension/steering use frameA X and spin
uses frameB Z, matching the pinned engine. No second constraint or mover solver.
Unused named settings are exact zero records. Pin/Spherical target quaternion is
identity. All Worlds emit schema2, with empty motion arrays for body/shape-only
scenes. The shared parser/baker owns IDs/content/bounds
and actual native construction. Joint families share the selected backend's
capacity, which defaults to 256. The SDK builder writes matching capacities into
the project's addon copy; see [Configure capacities](../../docs/box3d/capacities.md).
