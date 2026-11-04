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
records. Joint marker transform is identity; local_frame_a/b explicitly describe
rigid frames in each body's space. body_a/body_b are durable keys local to World.
Missing/self/cross-World references, two Static bodies, duplicate keys, unsupported
flags, invalid frames/limits and nonfinite values fail before extraction.

Pin uses Spherical with angular features disabled. Hinge is Revolute about localZ;
Slider is Prismatic about localX. Wheel suspension/steering use frameA X and spin
uses frameB Z, matching the pinned engine. No second constraint or mover solver.
Unused named settings are exact zero records. Pin/Spherical target quaternion is
identity. Only motion-containing Worlds emit schema2; unchanged body/shape-only
Worlds retain schema1 JSON. Existing shared parser/baker owns IDs/content/bounds
and actual native construction. Current profile permits one joint at a time.
