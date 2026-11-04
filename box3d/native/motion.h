#ifndef OGB3_MOTION_H
#define OGB3_MOTION_H
#include "api.h"
#ifdef __cplusplus
extern "C" {
#endif
#define OGB3_MOTION_VERSION 1u
#define OGB3_MOTION_RECOVERY_FORMAT 3u
#define OGB3_MOTION_MAX_HITS 256u
#define OGB3_MOTION_MAX_PLANES 256u
enum { OGB3_PIN=1, OGB3_HINGE=2, OGB3_SLIDER=3, OGB3_SPHERICAL=4,
       OGB3_DISTANCE=5, OGB3_MOTOR=6, OGB3_WELD=7, OGB3_WHEEL=8 };
/* Hinge/Slider/Distance flags: spring1, limit2, motor4. Angular units radians;
 * Slider/Distance linear units metres. Hinge local Z, Slider local X.
 * Distance bounds use the engine's stable minimum/maximum length range,
 * including an inactive 0/0 input range; rest length remains independent. */
typedef struct {
  uint32_t flags;
  float hertz,damping_ratio,target,lower,upper,motor_speed,max_motor;
} ogb3_joint_axis;
typedef struct {
  ogb3_joint_axis axis;
  float length,lower_spring_force,upper_spring_force;
} ogb3_joint_distance;
/* spring1, cone2, twist4, motor8; Pin requires all flags zero. */
typedef struct {
  uint32_t flags;
  float hertz,damping_ratio,cone_angle,lower_twist,upper_twist,max_motor_torque;
  ogb3_quat target_rotation;
  ogb3_vec3 motor_velocity;
} ogb3_joint_spherical;
typedef struct {
  ogb3_vec3 linear_velocity,angular_velocity;
  float max_velocity_force,max_velocity_torque,linear_hertz,linear_damping_ratio,
        angular_hertz,angular_damping_ratio,max_spring_force,max_spring_torque;
} ogb3_joint_motor;
typedef struct {float linear_hertz,angular_hertz,linear_damping_ratio,angular_damping_ratio;} ogb3_joint_weld;
/* suspensionSpring1, suspensionLimit2, spinMotor4, steering8, steeringLimit16.
 * Wheel frame axes follow the pinned engine: suspension X(A), spin Z(B), steering X(A). */
typedef struct {
  uint32_t flags;
  float suspension_hertz,suspension_damping_ratio,lower_suspension,upper_suspension,
        max_spin_torque,spin_speed,steering_hertz,steering_damping_ratio,
        target_steering_angle,max_steering_torque,lower_steering,upper_steering;
} ogb3_joint_wheel;
/* Only the named settings for kind are used; all other settings must be zero.
 * Pin is Spherical with angular spring/limits/motor disabled; Hinge=Revolute,
 * Slider=Prismatic. body keys resolve in the supplied actual execution world.
 * Return a world-independent Joint_Key; no new global map or hidden owner. */
typedef struct {
  uint32_t version,kind;
  ogb3_body_key body_a,body_b;
  ogb3_pose local_frame_a,local_frame_b;
  float force_threshold,torque_threshold,constraint_hertz,constraint_damping_ratio;
  uint32_t collide_connected,reserved;
  ogb3_joint_axis axis;
  ogb3_joint_distance distance;
  ogb3_joint_spherical spherical;
  ogb3_joint_motor motor;
  ogb3_joint_weld weld;
  ogb3_joint_wheel wheel;
} ogb3_motion_joint_def;
OGB3_API ogb3_status ogb3_motion_joint_default(uint32_t kind,ogb3_motion_joint_def *);
OGB3_API ogb3_status ogb3_motion_joint_create(ogb3_world,const ogb3_motion_joint_def *,ogb3_joint_key *);

typedef struct {
  uint64_t category_bits,mask_bits;
  ogb3_body_key exclude_body;
  uint32_t include_sensors,reserved;
} ogb3_motion_filter;
typedef struct {ogb3_vec3 center1,center2;float radius;} ogb3_motion_capsule;
typedef struct {
  ogb3_shape_key shape;
  ogb3_body_key body;
  ogb3_vec3 point,normal;
  float fraction;
  int32_t triangle,child;
  uint32_t reserved;
} ogb3_motion_hit;
/* Complete results, sorted by fraction then Shape_Key/triangle/child/geometry;
 * AABB/overlap have fraction0 and zero point/normal. No truncated prefix is
 * published. count is exact even on Capacity; NULL/0 is a read-only size query.
 * Result/mover caps do not increase the existing 35-shape world profile. */
OGB3_API ogb3_status ogb3_query_aabb(ogb3_world,const ogb3_vec3 *lo,const ogb3_vec3 *hi,const ogb3_motion_filter *,ogb3_motion_hit *,uint32_t capacity,uint32_t *count);
OGB3_API ogb3_status ogb3_query_ray(ogb3_world,const ogb3_vec3 *origin,const ogb3_vec3 *translation,const ogb3_motion_filter *,ogb3_motion_hit *,uint32_t,uint32_t *);
OGB3_API ogb3_status ogb3_query_capsule(ogb3_world,const ogb3_vec3 *origin,const ogb3_motion_capsule *,const ogb3_motion_filter *,ogb3_motion_hit *,uint32_t,uint32_t *);
OGB3_API ogb3_status ogb3_query_capsule_cast(ogb3_world,const ogb3_vec3 *origin,const ogb3_motion_capsule *,const ogb3_vec3 *translation,const ogb3_motion_filter *,ogb3_motion_hit *,uint32_t,uint32_t *);

typedef struct {
  uint32_t version,max_slides; /* 1..8; bounded invocation count, no hidden tick */
  ogb3_motion_capsule capsule; /* endpoints relative to state.position */
  ogb3_vec3 up;
  float floor_cosine; /* [0,1], dot(normal,up)>=floor_cosine */
  ogb3_motion_filter filter;
} ogb3_character_config;
typedef struct {
  ogb3_vec3 position,velocity,ground_normal;
  ogb3_shape_key ground_shape;
  uint32_t grounded,reserved;
} ogb3_character_state;
typedef struct {
  ogb3_character_state state;
  ogb3_vec3 displacement;
  uint32_t iterations,plane_count;
} ogb3_character_result;
/* Pure world-read + POD output; state is caller-owned Game/Side. dt=0 is an
 * exact no-op; otherwise dt must be the existing fixed 1/60 f32. Actual engine
 * CastMover/CollideMover/SolvePlanes/ClipVector; no body writes or clock.
 * Any error leaves out unchanged, including plane capacity/iteration failure. */
OGB3_API ogb3_status ogb3_character_step(ogb3_world,const ogb3_character_config *,const ogb3_character_state *,float dt,ogb3_character_result *out);
/* type1..13 in declaration order: axis,distance,spherical,motor,weld,wheel,
 * joint_def,filter,capsule,hit,character_config,state,result.
 * field is the declaration-order field index; reports actual sizeof/alignment. */
OGB3_API ogb3_status ogb3_motion_layout(uint32_t type,uint32_t field,uint32_t *size,uint32_t *alignment,uint32_t *offset);
#ifdef __cplusplus
}
#endif
#endif
