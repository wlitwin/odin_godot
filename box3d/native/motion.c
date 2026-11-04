#include "motion.h"
#include "api_internal.h"
#include "box3d/box3d.h"
#include "box3d/collision.h"
#include "physics_world.h"
#include "body.h"
#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#define REQUIRE(x) do {if(!(x))return OGB3_INVALID_ARGUMENT;} while(0)
static b3WorldId wid(ogb3_world w){b3WorldId id;memcpy(&id,&w,sizeof(id));return id;}
static b3BodyId bid(ogb3_body b){b3BodyId id;memcpy(&id,&b,sizeof(id));return id;}
static uint64_t shape_bits(b3ShapeId s){uint64_t out;memcpy(&out,&s,sizeof(out));return out;}
static b3Vec3 v3(ogb3_vec3 v){return (b3Vec3){v.x,v.y,v.z};}
static ogb3_vec3 ov(b3Vec3 v){return (ogb3_vec3){v.x,v.y,v.z};}
static b3Quat quat(ogb3_quat q){return (b3Quat){{q.x,q.y,q.z},q.w};}
static ogb3_quat oq(b3Quat q){return (ogb3_quat){q.v.x,q.v.y,q.v.z,q.s};}
static int finite_v(ogb3_vec3 v){return isfinite(v.x)&&isfinite(v.y)&&isfinite(v.z)&&fabsf(v.x)<=1e8f&&fabsf(v.y)<=1e8f&&fabsf(v.z)<=1e8f;}
static int finite_q(ogb3_quat q){return isfinite(q.x)&&isfinite(q.y)&&isfinite(q.z)&&isfinite(q.w)&&b3IsNormalizedQuat(quat(q));}
static int pose_ok(ogb3_pose p){return finite_v(p.position)&&finite_q(p.rotation);}
static int nonnegative(float v){return isfinite(v)&&v>=0;}
static int zero(const void *p,size_t n){const unsigned char *b=p;for(size_t i=0;i<n;i++)if(b[i])return 0;return 1;}
static ogb3_status world_check(ogb3_world w){uint32_t valid=0;ogb3_status s=ogb3_world_valid(w,&valid);if(s)return s;if(!valid)return OGB3_INVALID_HANDLE;b3World *world=b3GetWorldFromId(wid(w));if(world->locked)return OGB3_INVALID_ARGUMENT;ogb3_world_counters c;s=ogb3_world_get_counters(w,&c);if(s)return s;uint32_t dynamic=0;for(int i=0;i<world->bodies.count;i++)if(world->bodies.data[i].id==i&&world->bodies.data[i].type==b3_dynamicBody)dynamic++;return c.body_count>35||c.shape_count>35||dynamic>32?OGB3_CAPACITY:OGB3_OK;}
static void base_out(ogb3_motion_joint_def *d,b3JointDef b){
 d->local_frame_a=(ogb3_pose){ov(b.localFrameA.p),oq(b.localFrameA.q)};
 d->local_frame_b=(ogb3_pose){ov(b.localFrameB.p),oq(b.localFrameB.q)};
 d->force_threshold=b.forceThreshold;d->torque_threshold=b.torqueThreshold;
 d->constraint_hertz=b.constraintHertz;d->constraint_damping_ratio=b.constraintDampingRatio;d->collide_connected=b.collideConnected;
}
static void base_in(b3JointDef *b,const ogb3_motion_joint_def *d,ogb3_body a,ogb3_body c){
 b->bodyIdA=bid(a);b->bodyIdB=bid(c);b->localFrameA=(b3Transform){v3(d->local_frame_a.position),quat(d->local_frame_a.rotation)};
 b->localFrameB=(b3Transform){v3(d->local_frame_b.position),quat(d->local_frame_b.rotation)};
 b->forceThreshold=d->force_threshold;b->torqueThreshold=d->torque_threshold;b->constraintHertz=d->constraint_hertz;b->constraintDampingRatio=d->constraint_damping_ratio;b->collideConnected=d->collide_connected;
}
ogb3_status ogb3_motion_joint_default(uint32_t kind,ogb3_motion_joint_def *out){
 REQUIRE(out&&kind>=OGB3_PIN&&kind<=OGB3_WHEEL);ogb3_motion_joint_def d={0};d.version=1;d.kind=kind;
 switch(kind){
 case OGB3_HINGE:{b3RevoluteJointDef b=b3DefaultRevoluteJointDef();base_out(&d,b.base);
 d.axis.hertz=b.hertz;
 d.axis.damping_ratio=b.dampingRatio;
 d.axis.target=b.targetAngle;
 d.axis.lower=b.lowerAngle;
 d.axis.upper=b.upperAngle;
 d.axis.motor_speed=b.motorSpeed;
 d.axis.max_motor=b.maxMotorTorque;
 d.axis.flags=(b.enableSpring?1u:0u)|(b.enableLimit?2u:0u)|(b.enableMotor?4u:0u);
 break;}
 case OGB3_SLIDER:{b3PrismaticJointDef b=b3DefaultPrismaticJointDef();base_out(&d,b.base);
 d.axis.hertz=b.hertz;
 d.axis.damping_ratio=b.dampingRatio;
 d.axis.target=b.targetTranslation;
 d.axis.lower=b.lowerTranslation;
 d.axis.upper=b.upperTranslation;
 d.axis.motor_speed=b.motorSpeed;
 d.axis.max_motor=b.maxMotorForce;
 d.axis.flags=(b.enableSpring?1u:0u)|(b.enableLimit?2u:0u)|(b.enableMotor?4u:0u);
 break;}
 case OGB3_DISTANCE:{b3DistanceJointDef b=b3DefaultDistanceJointDef();base_out(&d,b.base);
 d.distance.axis.hertz=b.hertz;
 d.distance.axis.damping_ratio=b.dampingRatio;
 d.distance.axis.lower=b.minLength;
 d.distance.axis.upper=b.maxLength;
 d.distance.axis.motor_speed=b.motorSpeed;
 d.distance.axis.max_motor=b.maxMotorForce;
 d.distance.length=b.length;
 d.distance.lower_spring_force=b.lowerSpringForce;
 d.distance.upper_spring_force=b.upperSpringForce;
 d.distance.axis.flags=(b.enableSpring?1u:0u)|(b.enableLimit?2u:0u)|(b.enableMotor?4u:0u);
 break;}
 case OGB3_PIN:
 case OGB3_SPHERICAL:{b3SphericalJointDef b=b3DefaultSphericalJointDef();base_out(&d,b.base);
 d.spherical.hertz=b.hertz;
 d.spherical.damping_ratio=b.dampingRatio;
 d.spherical.cone_angle=b.coneAngle;
 d.spherical.lower_twist=b.lowerTwistAngle;
 d.spherical.upper_twist=b.upperTwistAngle;
 d.spherical.max_motor_torque=b.maxMotorTorque;
 d.spherical.target_rotation=oq(b.targetRotation);
 d.spherical.motor_velocity=ov(b.motorVelocity);
 d.spherical.flags=(b.enableSpring?1u:0u)|(b.enableConeLimit?2u:0u)|(b.enableTwistLimit?4u:0u)|(b.enableMotor?8u:0u);
 if(kind==OGB3_PIN)d.spherical.flags=0;
 break;}
 case OGB3_MOTOR:{b3MotorJointDef b=b3DefaultMotorJointDef();base_out(&d,b.base);
 d.motor.linear_velocity=ov(b.linearVelocity);
 d.motor.angular_velocity=ov(b.angularVelocity);
 d.motor.max_velocity_force=b.maxVelocityForce;
 d.motor.max_velocity_torque=b.maxVelocityTorque;
 d.motor.linear_hertz=b.linearHertz;
 d.motor.linear_damping_ratio=b.linearDampingRatio;
 d.motor.angular_hertz=b.angularHertz;
 d.motor.angular_damping_ratio=b.angularDampingRatio;
 d.motor.max_spring_force=b.maxSpringForce;
 d.motor.max_spring_torque=b.maxSpringTorque;
 break;}
 case OGB3_WELD:{b3WeldJointDef b=b3DefaultWeldJointDef();base_out(&d,b.base);
 d.weld.linear_hertz=b.linearHertz;
 d.weld.angular_hertz=b.angularHertz;
 d.weld.linear_damping_ratio=b.linearDampingRatio;
 d.weld.angular_damping_ratio=b.angularDampingRatio;
 break;}
 case OGB3_WHEEL:{b3WheelJointDef b=b3DefaultWheelJointDef();base_out(&d,b.base);
 d.wheel.suspension_hertz=b.suspensionHertz;
 d.wheel.suspension_damping_ratio=b.suspensionDampingRatio;
 d.wheel.lower_suspension=b.lowerSuspensionLimit;
 d.wheel.upper_suspension=b.upperSuspensionLimit;
 d.wheel.max_spin_torque=b.maxSpinTorque;
 d.wheel.spin_speed=b.spinSpeed;
 d.wheel.steering_hertz=b.steeringHertz;
 d.wheel.steering_damping_ratio=b.steeringDampingRatio;
 d.wheel.target_steering_angle=b.targetSteeringAngle;
 d.wheel.max_steering_torque=b.maxSteeringTorque;
 d.wheel.lower_steering=b.lowerSteeringLimit;
 d.wheel.upper_steering=b.upperSteeringLimit;
 d.wheel.flags=(b.enableSuspensionSpring?1u:0u)|(b.enableSuspensionLimit?2u:0u)|(b.enableSpinMotor?4u:0u)|(b.enableSteering?8u:0u)|(b.enableSteeringLimit?16u:0u);
 break;}
 default:return OGB3_INVALID_ARGUMENT;}*out=d;return OGB3_OK;}
static int axis_ok(const ogb3_joint_axis *a){return !(a->flags&~7u)&&nonnegative(a->hertz)&&nonnegative(a->damping_ratio)&&isfinite(a->target)&&isfinite(a->lower)&&isfinite(a->upper)&&a->lower<=a->upper&&isfinite(a->motor_speed)&&nonnegative(a->max_motor);}
static int joint_ok(const ogb3_motion_joint_def *d){
 if(!d||d->version!=1||d->kind<1||d->kind>8||d->reserved||!d->body_a||!d->body_b||d->body_a==d->body_b||d->collide_connected>1||!pose_ok(d->local_frame_a)||!pose_ok(d->local_frame_b)||!nonnegative(d->force_threshold)||!nonnegative(d->torque_threshold)||!nonnegative(d->constraint_hertz)||!nonnegative(d->constraint_damping_ratio))return 0;
 ogb3_motion_joint_def rest=*d;
 switch(d->kind){
 case OGB3_HINGE:case OGB3_SLIDER:
  if(!axis_ok(&d->axis))return 0;
  if(d->kind==OGB3_HINGE&&(d->axis.lower< -3.1101767f||d->axis.upper>3.1101767f||fabsf(d->axis.target)>3.1415927f))return 0;
  memset(&rest.axis,0,sizeof(rest.axis));break;
 case OGB3_DISTANCE:
  if(!axis_ok(&d->distance.axis)||d->distance.axis.target!=0||d->distance.axis.lower<0||d->distance.length<=0||!isfinite(d->distance.length)||!isfinite(d->distance.lower_spring_force)||!isfinite(d->distance.upper_spring_force)||d->distance.lower_spring_force>d->distance.upper_spring_force||((d->distance.axis.flags&6)&&!(d->distance.axis.flags&1)))return 0;
  memset(&rest.distance,0,sizeof(rest.distance));break;
 case OGB3_PIN:case OGB3_SPHERICAL:{const ogb3_joint_spherical *s=&d->spherical;
  if((s->flags&~15u)||(d->kind==OGB3_PIN&&s->flags)||!nonnegative(s->hertz)||!nonnegative(s->damping_ratio)||!nonnegative(s->max_motor_torque)||!nonnegative(s->cone_angle)||s->cone_angle>1.5707964f||!isfinite(s->lower_twist)||!isfinite(s->upper_twist)||s->lower_twist>s->upper_twist||s->lower_twist< -3.1101767f||s->upper_twist>3.1101767f||!finite_q(s->target_rotation)||!finite_v(s->motor_velocity))return 0;
  memset(&rest.spherical,0,sizeof(rest.spherical));break;}
 case OGB3_MOTOR:{const ogb3_joint_motor *s=&d->motor;
  if(!finite_v(s->linear_velocity)||!finite_v(s->angular_velocity)||!nonnegative(s->max_velocity_force)||!nonnegative(s->max_velocity_torque)||!nonnegative(s->linear_hertz)||!nonnegative(s->linear_damping_ratio)||!nonnegative(s->angular_hertz)||!nonnegative(s->angular_damping_ratio)||!nonnegative(s->max_spring_force)||!nonnegative(s->max_spring_torque))return 0;
  memset(&rest.motor,0,sizeof(rest.motor));break;}
 case OGB3_WELD:{const ogb3_joint_weld *s=&d->weld;if(!nonnegative(s->linear_hertz)||!nonnegative(s->angular_hertz)||!nonnegative(s->linear_damping_ratio)||!nonnegative(s->angular_damping_ratio))return 0;memset(&rest.weld,0,sizeof(rest.weld));break;}
 case OGB3_WHEEL:{const ogb3_joint_wheel *s=&d->wheel;
  if((s->flags&~31u)||!nonnegative(s->suspension_hertz)||!nonnegative(s->suspension_damping_ratio)||!isfinite(s->lower_suspension)||!isfinite(s->upper_suspension)||s->lower_suspension>s->upper_suspension||!nonnegative(s->max_spin_torque)||!isfinite(s->spin_speed)||!nonnegative(s->steering_hertz)||!nonnegative(s->steering_damping_ratio)||!isfinite(s->target_steering_angle)||!nonnegative(s->max_steering_torque)||!isfinite(s->lower_steering)||!isfinite(s->upper_steering)||s->lower_steering>s->upper_steering)return 0;
  memset(&rest.wheel,0,sizeof(rest.wheel));break;}
 default:return 0;}
 return zero(&rest.axis,sizeof(rest.axis))&&zero(&rest.distance,sizeof(rest.distance))&&zero(&rest.spherical,sizeof(rest.spherical))&&zero(&rest.motor,sizeof(rest.motor))&&zero(&rest.weld,sizeof(rest.weld))&&zero(&rest.wheel,sizeof(rest.wheel));
}
ogb3_status ogb3_motion_joint_create(ogb3_world w,const ogb3_motion_joint_def *d,ogb3_joint_key *out){
 REQUIRE(out);*out=0;REQUIRE(joint_ok(d));ogb3_status s=world_check(w);if(s)return s;
 ogb3_world_counters counters;s=ogb3_world_get_counters(w,&counters);if(s)return s;if(counters.joint_count>=1)return OGB3_CAPACITY;
 ogb3_body a=0,c=0;s=ogb3_body_resolve(w,d->body_a,&a);if(s)return s;s=ogb3_body_resolve(w,d->body_b,&c);if(s)return s;
 REQUIRE(b3Body_GetType(bid(a))!=b3_staticBody||b3Body_GetType(bid(c))!=b3_staticBody);
 b3JointId id={0};switch(d->kind){
 case OGB3_HINGE:{b3RevoluteJointDef b=b3DefaultRevoluteJointDef();base_in(&b.base,d,a,c);
 b.hertz=d->axis.hertz;
 b.dampingRatio=d->axis.damping_ratio;
 b.targetAngle=d->axis.target;
 b.lowerAngle=d->axis.lower;
 b.upperAngle=d->axis.upper;
 b.motorSpeed=d->axis.motor_speed;
 b.maxMotorTorque=d->axis.max_motor;
 b.enableSpring=(d->axis.flags&1u)!=0;
 b.enableLimit=(d->axis.flags&2u)!=0;
 b.enableMotor=(d->axis.flags&4u)!=0;
 id=b3CreateRevoluteJoint(wid(w),&b);break;}
 case OGB3_SLIDER:{b3PrismaticJointDef b=b3DefaultPrismaticJointDef();base_in(&b.base,d,a,c);
 b.hertz=d->axis.hertz;
 b.dampingRatio=d->axis.damping_ratio;
 b.targetTranslation=d->axis.target;
 b.lowerTranslation=d->axis.lower;
 b.upperTranslation=d->axis.upper;
 b.motorSpeed=d->axis.motor_speed;
 b.maxMotorForce=d->axis.max_motor;
 b.enableSpring=(d->axis.flags&1u)!=0;
 b.enableLimit=(d->axis.flags&2u)!=0;
 b.enableMotor=(d->axis.flags&4u)!=0;
 id=b3CreatePrismaticJoint(wid(w),&b);break;}
 case OGB3_DISTANCE:{b3DistanceJointDef b=b3DefaultDistanceJointDef();base_in(&b.base,d,a,c);
 b.hertz=d->distance.axis.hertz;
 b.dampingRatio=d->distance.axis.damping_ratio;
 b.minLength=d->distance.axis.lower;
 b.maxLength=d->distance.axis.upper;
 b.motorSpeed=d->distance.axis.motor_speed;
 b.maxMotorForce=d->distance.axis.max_motor;
 b.length=d->distance.length;
 b.lowerSpringForce=d->distance.lower_spring_force;
 b.upperSpringForce=d->distance.upper_spring_force;
 b.enableSpring=(d->distance.axis.flags&1u)!=0;
 b.enableLimit=(d->distance.axis.flags&2u)!=0;
 b.enableMotor=(d->distance.axis.flags&4u)!=0;
 id=b3CreateDistanceJoint(wid(w),&b);
 /* The pinned constructor floors minLength but not maxLength: accepted 0/0
  * would otherwise become an inverted native range, even with limits off.
  * Normalize both through the public stable-range contract before publishing
  * the key; canonical validation still rejects every inverted solver range. */
 if(id.index1)b3DistanceJoint_SetLengthRange(id,b.minLength,b.maxLength);
 break;}
 case OGB3_PIN:
 case OGB3_SPHERICAL:{b3SphericalJointDef b=b3DefaultSphericalJointDef();base_in(&b.base,d,a,c);
 b.hertz=d->spherical.hertz;
 b.dampingRatio=d->spherical.damping_ratio;
 b.coneAngle=d->spherical.cone_angle;
 b.lowerTwistAngle=d->spherical.lower_twist;
 b.upperTwistAngle=d->spherical.upper_twist;
 b.maxMotorTorque=d->spherical.max_motor_torque;
 b.targetRotation=quat(d->spherical.target_rotation);
 b.motorVelocity=v3(d->spherical.motor_velocity);
 b.enableSpring=(d->spherical.flags&1u)!=0;
 b.enableConeLimit=(d->spherical.flags&2u)!=0;
 b.enableTwistLimit=(d->spherical.flags&4u)!=0;
 b.enableMotor=(d->spherical.flags&8u)!=0;
 id=b3CreateSphericalJoint(wid(w),&b);break;}
 case OGB3_MOTOR:{b3MotorJointDef b=b3DefaultMotorJointDef();base_in(&b.base,d,a,c);
 b.linearVelocity=v3(d->motor.linear_velocity);
 b.angularVelocity=v3(d->motor.angular_velocity);
 b.maxVelocityForce=d->motor.max_velocity_force;
 b.maxVelocityTorque=d->motor.max_velocity_torque;
 b.linearHertz=d->motor.linear_hertz;
 b.linearDampingRatio=d->motor.linear_damping_ratio;
 b.angularHertz=d->motor.angular_hertz;
 b.angularDampingRatio=d->motor.angular_damping_ratio;
 b.maxSpringForce=d->motor.max_spring_force;
 b.maxSpringTorque=d->motor.max_spring_torque;
 id=b3CreateMotorJoint(wid(w),&b);break;}
 case OGB3_WELD:{b3WeldJointDef b=b3DefaultWeldJointDef();base_in(&b.base,d,a,c);
 b.linearHertz=d->weld.linear_hertz;
 b.angularHertz=d->weld.angular_hertz;
 b.linearDampingRatio=d->weld.linear_damping_ratio;
 b.angularDampingRatio=d->weld.angular_damping_ratio;
 id=b3CreateWeldJoint(wid(w),&b);break;}
 case OGB3_WHEEL:{b3WheelJointDef b=b3DefaultWheelJointDef();base_in(&b.base,d,a,c);
 b.suspensionHertz=d->wheel.suspension_hertz;
 b.suspensionDampingRatio=d->wheel.suspension_damping_ratio;
 b.lowerSuspensionLimit=d->wheel.lower_suspension;
 b.upperSuspensionLimit=d->wheel.upper_suspension;
 b.maxSpinTorque=d->wheel.max_spin_torque;
 b.spinSpeed=d->wheel.spin_speed;
 b.steeringHertz=d->wheel.steering_hertz;
 b.steeringDampingRatio=d->wheel.steering_damping_ratio;
 b.targetSteeringAngle=d->wheel.target_steering_angle;
 b.maxSteeringTorque=d->wheel.max_steering_torque;
 b.lowerSteeringLimit=d->wheel.lower_steering;
 b.upperSteeringLimit=d->wheel.upper_steering;
 b.enableSuspensionSpring=(d->wheel.flags&1u)!=0;
 b.enableSuspensionLimit=(d->wheel.flags&2u)!=0;
 b.enableSpinMotor=(d->wheel.flags&4u)!=0;
 b.enableSteering=(d->wheel.flags&8u)!=0;
 b.enableSteeringLimit=(d->wheel.flags&16u)!=0;
 id=b3CreateWheelJoint(wid(w),&b);break;}
 default:return OGB3_INVALID_ARGUMENT;}
 if(!id.index1)return OGB3_OUT_OF_MEMORY;ogb3_joint handle;memcpy(&handle,&id,sizeof(handle));s=ogb3_joint_get_key(handle,out);if(s)b3DestroyJoint(id,true);return s;
}

typedef struct {
 ogb3_motion_filter filter;
 ogb3_motion_hit hits[OGB3_MOTION_MAX_HITS];
 uint32_t count;ogb3_status status;
} Query;
static ogb3_status query_begin(ogb3_world w,const ogb3_motion_filter *f,Query *q){
 REQUIRE(f&&f->include_sensors<=1&&!f->reserved);
 ogb3_status s=world_check(w);if(s)return s;
 if(f->exclude_body){ogb3_body b=0;s=ogb3_body_resolve(w,f->exclude_body,&b);if(s)return s;}
 memset(q,0,sizeof(*q));q->filter=*f;return OGB3_OK;
}
static int shape_info(Query *q,b3ShapeId id,ogb3_motion_hit *hit){
 if(q->status)return 0;
 if(!q->filter.include_sensors&&b3Shape_IsSensor(id))return 0;
 uint64_t shape=shape_bits(id);ogb3_body body=0;
 q->status=ogb3_shape_get_body(shape,&body);if(q->status)return 0;
 q->status=ogb3_body_get_key(body,&hit->body);if(q->status)return 0;
 if(hit->body==q->filter.exclude_body)return 0;
 q->status=ogb3_shape_get_key(shape,&hit->shape);return !q->status;
}
static void add_hit(Query *q,const ogb3_motion_hit *h){
 if(q->count<OGB3_MOTION_MAX_HITS)q->hits[q->count]=*h;
 if(q->count==UINT32_MAX)q->status=OGB3_CAPACITY;else q->count++;
}
static bool overlap_cb(b3ShapeId id,void *ctx){Query *q=ctx;ogb3_motion_hit hit={0};if(shape_info(q,id,&hit))add_hit(q,&hit);return !q->status;}
static float cast_cb(b3ShapeId id,b3Pos point,b3Vec3 normal,float fraction,uint64_t material,int triangle,int child,void *ctx){
 (void)material;Query *q=ctx;ogb3_motion_hit hit={0};
 if(shape_info(q,id,&hit)){
  hit.point=(ogb3_vec3){(float)point.x,(float)point.y,(float)point.z};hit.normal=ov(normal);hit.fraction=fraction;hit.triangle=triangle;hit.child=child;
  if(!finite_v(hit.point)||!finite_v(hit.normal)||!isfinite(fraction)||fraction<0||fraction>1)q->status=OGB3_CORRUPT;else add_hit(q,&hit);
 }
 return q->status?0:1;
}
static int float_order(float a,float b){if(a<b)return -1;if(a>b)return 1;uint32_t x,y;memcpy(&x,&a,4);memcpy(&y,&b,4);return (x>y)-(x<y);}
static int vec_order(ogb3_vec3 a,ogb3_vec3 b){int c=float_order(a.x,b.x);if(!c)c=float_order(a.y,b.y);if(!c)c=float_order(a.z,b.z);return c;}
static int hit_order(const void *a,const void *b){const ogb3_motion_hit *x=a,*y=b;int c=float_order(x->fraction,y->fraction);if(c)return c;
 if(x->shape!=y->shape)return (x->shape>y->shape)-(x->shape<y->shape);
 if(x->triangle!=y->triangle)return (x->triangle>y->triangle)-(x->triangle<y->triangle);
 if(x->child!=y->child)return (x->child>y->child)-(x->child<y->child);
 c=vec_order(x->point,y->point);if(!c)c=vec_order(x->normal,y->normal);return c;
}
static ogb3_status query_end(Query *q,ogb3_motion_hit *out,uint32_t capacity,uint32_t *count){
 if(q->status)return q->status;
 *count=q->count;if(q->count>OGB3_MOTION_MAX_HITS||capacity<q->count)return OGB3_CAPACITY;
 qsort(q->hits,q->count,sizeof(q->hits[0]),hit_order);
 if(q->count)memcpy(out,q->hits,(size_t)q->count*sizeof(*out));return OGB3_OK;
}
static b3QueryFilter native_filter(const ogb3_motion_filter *f){return (b3QueryFilter){.categoryBits=f->category_bits,.maskBits=f->mask_bits};}
static int capsule_ok(const ogb3_motion_capsule *c){return c&&finite_v(c->center1)&&finite_v(c->center2)&&isfinite(c->radius)&&c->radius>0&&c->radius<=1e6f;}
ogb3_status ogb3_query_aabb(ogb3_world w,const ogb3_vec3 *lo,const ogb3_vec3 *hi,const ogb3_motion_filter *f,ogb3_motion_hit *out,uint32_t capacity,uint32_t *count){
 REQUIRE(lo&&hi&&finite_v(*lo)&&finite_v(*hi)&&lo->x<=hi->x&&lo->y<=hi->y&&lo->z<=hi->z&&count&&(!capacity||out));
 Query q;ogb3_status s=query_begin(w,f,&q);if(s)return s;b3World_OverlapAABB(wid(w),(b3AABB){v3(*lo),v3(*hi)},native_filter(f),overlap_cb,&q);return query_end(&q,out,capacity,count);
}
ogb3_status ogb3_query_ray(ogb3_world w,const ogb3_vec3 *origin,const ogb3_vec3 *translation,const ogb3_motion_filter *f,ogb3_motion_hit *out,uint32_t capacity,uint32_t *count){
 REQUIRE(origin&&translation&&finite_v(*origin)&&finite_v(*translation)&&count&&(!capacity||out));
 Query q;ogb3_status s=query_begin(w,f,&q);if(s)return s;b3World_CastRay(wid(w),v3(*origin),v3(*translation),native_filter(f),cast_cb,&q);return query_end(&q,out,capacity,count);
}
ogb3_status ogb3_query_capsule(ogb3_world w,const ogb3_vec3 *origin,const ogb3_motion_capsule *capsule,const ogb3_motion_filter *f,ogb3_motion_hit *out,uint32_t capacity,uint32_t *count){
 REQUIRE(origin&&finite_v(*origin)&&capsule_ok(capsule)&&count&&(!capacity||out));
 Query q;ogb3_status s=query_begin(w,f,&q);if(s)return s;b3Vec3 points[]={v3(capsule->center1),v3(capsule->center2)};b3ShapeProxy proxy={points,2,capsule->radius};
 b3World_OverlapShape(wid(w),v3(*origin),&proxy,native_filter(f),overlap_cb,&q);return query_end(&q,out,capacity,count);
}
ogb3_status ogb3_query_capsule_cast(ogb3_world w,const ogb3_vec3 *origin,const ogb3_motion_capsule *capsule,const ogb3_vec3 *translation,const ogb3_motion_filter *f,ogb3_motion_hit *out,uint32_t capacity,uint32_t *count){
 REQUIRE(origin&&translation&&finite_v(*origin)&&finite_v(*translation)&&capsule_ok(capsule)&&count&&(!capacity||out));
 Query q;ogb3_status s=query_begin(w,f,&q);if(s)return s;b3Vec3 points[]={v3(capsule->center1),v3(capsule->center2)};b3ShapeProxy proxy={points,2,capsule->radius};
 b3World_CastShape(wid(w),v3(*origin),&proxy,v3(*translation),native_filter(f),cast_cb,&q);return query_end(&q,out,capacity,count);
}
typedef struct {b3CollisionPlane plane;ogb3_shape_key shape;ogb3_vec3 point;} Plane;
typedef struct {Query query;Plane planes[OGB3_MOTION_MAX_PLANES];uint32_t count;} Planes;
static bool mover_filter(b3ShapeId id,void *ctx){Query *q=ctx;ogb3_motion_hit h={0};return shape_info(q,id,&h);}
static bool plane_cb(b3ShapeId id,const b3PlaneResult *planes,int count,void *ctx){
 Planes *p=ctx;ogb3_motion_hit hit={0};if(!shape_info(&p->query,id,&hit))return !p->query.status;
 /* The pinned public world callback has a 64-plane per-shape buffer with no
  * overflow bit. A full batch cannot certify completeness: fail closed. */
 if(count>=64){p->query.status=OGB3_CAPACITY;return false;}
 for(int i=0;i<count;i++){
  if(!b3IsValidPlane(planes[i].plane)||!finite_v(ov(planes[i].point))){p->query.status=OGB3_CORRUPT;return false;}
  if(p->count>=OGB3_MOTION_MAX_PLANES){p->query.status=OGB3_CAPACITY;return false;}
  p->planes[p->count++]=(Plane){.plane={.plane=planes[i].plane,.pushLimit=FLT_MAX,.clipVelocity=true},.shape=hit.shape,.point=ov(planes[i].point)};
 }return true;
}
static int plane_order(const void *a,const void *b){const Plane *x=a,*y=b;if(x->shape!=y->shape)return (x->shape>y->shape)-(x->shape<y->shape);
 int c=vec_order(ov(x->plane.plane.normal),ov(y->plane.plane.normal));if(!c)c=float_order(x->plane.plane.offset,y->plane.plane.offset);if(!c)c=vec_order(x->point,y->point);return c;
}
static ogb3_status gather(ogb3_world w,const ogb3_character_config *cfg,ogb3_vec3 position,Planes *p,b3CollisionPlane *solver){
 p->count=0;p->query.status=OGB3_OK;p->query.filter=cfg->filter;
 b3Capsule capsule={v3(cfg->capsule.center1),v3(cfg->capsule.center2),cfg->capsule.radius};
 b3World_CollideMover(wid(w),v3(position),&capsule,native_filter(&cfg->filter),plane_cb,p);
 if(p->query.status)return p->query.status;
 qsort(p->planes,p->count,sizeof(p->planes[0]),plane_order);
 for(uint32_t i=0;i<p->count;i++)solver[i]=p->planes[i].plane;return OGB3_OK;
}
ogb3_status ogb3_character_step(ogb3_world w,const ogb3_character_config *cfg,const ogb3_character_state *state,float dt,ogb3_character_result *out){
 REQUIRE(cfg&&state&&out&&cfg->version==1&&cfg->max_slides>=1&&cfg->max_slides<=8&&capsule_ok(&cfg->capsule)&&finite_v(cfg->up)&&finite_v(state->position)&&finite_v(state->velocity)&&finite_v(state->ground_normal)&&state->grounded<=1&&!state->reserved&&isfinite(cfg->floor_cosine)&&cfg->floor_cosine>=0&&cfg->floor_cosine<=1&&isfinite(dt)&&(dt==0||dt==1.0f/60.0f));
 float norm=b3Dot(v3(cfg->up),v3(cfg->up));REQUIRE(fabsf(norm-1)<.0001f);
 Query q;ogb3_status s=query_begin(w,&cfg->filter,&q);if(s)return s;
 ogb3_character_result result={.state=*state};if(dt==0){*out=result;return OGB3_OK;}
 ogb3_vec3 position=state->position; b3Vec3 target=b3MulAdd(v3(position),dt,v3(state->velocity));
 Planes planes; b3CollisionPlane solver[OGB3_MOTION_MAX_PLANES];
 b3Capsule capsule={v3(cfg->capsule.center1),v3(cfg->capsule.center2),cfg->capsule.radius};
 for(uint32_t i=0;i<cfg->max_slides;i++){
  s=gather(w,cfg,position,&planes,solver);if(s)return s;
  b3Vec3 desired=b3Sub(target,v3(position));b3PlaneSolverResult solved=b3SolvePlanes(desired,solver,(int)planes.count);
  if(!finite_v(ov(solved.delta)))return OGB3_CORRUPT;
  if(solved.iterationCount>=20)return OGB3_CAPACITY;
  float fraction=b3World_CastMover(wid(w),v3(position),&capsule,solved.delta,native_filter(&cfg->filter),mover_filter,&q);
  if(q.status)return q.status;if(!isfinite(fraction)||fraction<0||fraction>1)return OGB3_CORRUPT;
  b3Vec3 delta=b3MulSV(fraction,solved.delta);position=ov(b3Add(v3(position),delta));result.iterations=i+1;
  if(b3LengthSquared(delta)<.000001f||b3LengthSquared(b3Sub(target,v3(position)))<.000001f)break;
 }
 s=gather(w,cfg,position,&planes,solver);if(s)return s;
 b3PlaneSolverResult clipped=b3SolvePlanes(b3MulSV(dt,v3(state->velocity)),solver,(int)planes.count);
 if(clipped.iterationCount>=20)return OGB3_CAPACITY;
 result.state.position=position;result.state.velocity=ov(b3ClipVector(v3(state->velocity),solver,(int)planes.count));
 result.state.grounded=0;result.state.ground_shape=0;result.state.ground_normal=(ogb3_vec3){0};
 float best=cfg->floor_cosine;
 for(uint32_t i=0;i<planes.count;i++){
  const b3Plane *p=&solver[i].plane;float dot=b3Dot(p->normal,v3(cfg->up));
  if(p->offset>=-.01f&&dot>=best&&(!result.state.grounded||dot>best||planes.planes[i].shape<result.state.ground_shape)){
   result.state.grounded=1;result.state.ground_shape=planes.planes[i].shape;result.state.ground_normal=ov(p->normal);best=dot;
  }
 }
 result.displacement=ov(b3Sub(v3(position),v3(state->position)));result.plane_count=planes.count;
 if(!finite_v(result.state.position)||!finite_v(result.state.velocity)||!finite_v(result.displacement))return OGB3_CORRUPT;
 *out=result;return OGB3_OK;
}

ogb3_status ogb3_motion_layout(uint32_t type,uint32_t field,uint32_t *size,uint32_t *alignment,uint32_t *offset){
 REQUIRE(size&&alignment&&offset);switch(type){
 case 1:{static const uint32_t fields[]={offsetof(ogb3_joint_axis,flags),offsetof(ogb3_joint_axis,hertz),offsetof(ogb3_joint_axis,damping_ratio),offsetof(ogb3_joint_axis,target),offsetof(ogb3_joint_axis,lower),offsetof(ogb3_joint_axis,upper),offsetof(ogb3_joint_axis,motor_speed),offsetof(ogb3_joint_axis,max_motor)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_axis);*alignment=_Alignof(ogb3_joint_axis);*offset=fields[field];return OGB3_OK;}
 case 2:{static const uint32_t fields[]={offsetof(ogb3_joint_distance,axis),offsetof(ogb3_joint_distance,length),offsetof(ogb3_joint_distance,lower_spring_force),offsetof(ogb3_joint_distance,upper_spring_force)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_distance);*alignment=_Alignof(ogb3_joint_distance);*offset=fields[field];return OGB3_OK;}
 case 3:{static const uint32_t fields[]={offsetof(ogb3_joint_spherical,flags),offsetof(ogb3_joint_spherical,hertz),offsetof(ogb3_joint_spherical,damping_ratio),offsetof(ogb3_joint_spherical,cone_angle),offsetof(ogb3_joint_spherical,lower_twist),offsetof(ogb3_joint_spherical,upper_twist),offsetof(ogb3_joint_spherical,max_motor_torque),offsetof(ogb3_joint_spherical,target_rotation),offsetof(ogb3_joint_spherical,motor_velocity)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_spherical);*alignment=_Alignof(ogb3_joint_spherical);*offset=fields[field];return OGB3_OK;}
 case 4:{static const uint32_t fields[]={offsetof(ogb3_joint_motor,linear_velocity),offsetof(ogb3_joint_motor,angular_velocity),offsetof(ogb3_joint_motor,max_velocity_force),offsetof(ogb3_joint_motor,max_velocity_torque),offsetof(ogb3_joint_motor,linear_hertz),offsetof(ogb3_joint_motor,linear_damping_ratio),offsetof(ogb3_joint_motor,angular_hertz),offsetof(ogb3_joint_motor,angular_damping_ratio),offsetof(ogb3_joint_motor,max_spring_force),offsetof(ogb3_joint_motor,max_spring_torque)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_motor);*alignment=_Alignof(ogb3_joint_motor);*offset=fields[field];return OGB3_OK;}
 case 5:{static const uint32_t fields[]={offsetof(ogb3_joint_weld,linear_hertz),offsetof(ogb3_joint_weld,angular_hertz),offsetof(ogb3_joint_weld,linear_damping_ratio),offsetof(ogb3_joint_weld,angular_damping_ratio)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_weld);*alignment=_Alignof(ogb3_joint_weld);*offset=fields[field];return OGB3_OK;}
 case 6:{static const uint32_t fields[]={offsetof(ogb3_joint_wheel,flags),offsetof(ogb3_joint_wheel,suspension_hertz),offsetof(ogb3_joint_wheel,suspension_damping_ratio),offsetof(ogb3_joint_wheel,lower_suspension),offsetof(ogb3_joint_wheel,upper_suspension),offsetof(ogb3_joint_wheel,max_spin_torque),offsetof(ogb3_joint_wheel,spin_speed),offsetof(ogb3_joint_wheel,steering_hertz),offsetof(ogb3_joint_wheel,steering_damping_ratio),offsetof(ogb3_joint_wheel,target_steering_angle),offsetof(ogb3_joint_wheel,max_steering_torque),offsetof(ogb3_joint_wheel,lower_steering),offsetof(ogb3_joint_wheel,upper_steering)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_joint_wheel);*alignment=_Alignof(ogb3_joint_wheel);*offset=fields[field];return OGB3_OK;}
 case 7:{static const uint32_t fields[]={offsetof(ogb3_motion_joint_def,version),offsetof(ogb3_motion_joint_def,kind),offsetof(ogb3_motion_joint_def,body_a),offsetof(ogb3_motion_joint_def,body_b),offsetof(ogb3_motion_joint_def,local_frame_a),offsetof(ogb3_motion_joint_def,local_frame_b),offsetof(ogb3_motion_joint_def,force_threshold),offsetof(ogb3_motion_joint_def,torque_threshold),offsetof(ogb3_motion_joint_def,constraint_hertz),offsetof(ogb3_motion_joint_def,constraint_damping_ratio),offsetof(ogb3_motion_joint_def,collide_connected),offsetof(ogb3_motion_joint_def,reserved),offsetof(ogb3_motion_joint_def,axis),offsetof(ogb3_motion_joint_def,distance),offsetof(ogb3_motion_joint_def,spherical),offsetof(ogb3_motion_joint_def,motor),offsetof(ogb3_motion_joint_def,weld),offsetof(ogb3_motion_joint_def,wheel)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_motion_joint_def);*alignment=_Alignof(ogb3_motion_joint_def);*offset=fields[field];return OGB3_OK;}
 case 8:{static const uint32_t fields[]={offsetof(ogb3_motion_filter,category_bits),offsetof(ogb3_motion_filter,mask_bits),offsetof(ogb3_motion_filter,exclude_body),offsetof(ogb3_motion_filter,include_sensors),offsetof(ogb3_motion_filter,reserved)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_motion_filter);*alignment=_Alignof(ogb3_motion_filter);*offset=fields[field];return OGB3_OK;}
 case 9:{static const uint32_t fields[]={offsetof(ogb3_motion_capsule,center1),offsetof(ogb3_motion_capsule,center2),offsetof(ogb3_motion_capsule,radius)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_motion_capsule);*alignment=_Alignof(ogb3_motion_capsule);*offset=fields[field];return OGB3_OK;}
 case 10:{static const uint32_t fields[]={offsetof(ogb3_motion_hit,shape),offsetof(ogb3_motion_hit,body),offsetof(ogb3_motion_hit,point),offsetof(ogb3_motion_hit,normal),offsetof(ogb3_motion_hit,fraction),offsetof(ogb3_motion_hit,triangle),offsetof(ogb3_motion_hit,child),offsetof(ogb3_motion_hit,reserved)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_motion_hit);*alignment=_Alignof(ogb3_motion_hit);*offset=fields[field];return OGB3_OK;}
 case 11:{static const uint32_t fields[]={offsetof(ogb3_character_config,version),offsetof(ogb3_character_config,max_slides),offsetof(ogb3_character_config,capsule),offsetof(ogb3_character_config,up),offsetof(ogb3_character_config,floor_cosine),offsetof(ogb3_character_config,filter)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_character_config);*alignment=_Alignof(ogb3_character_config);*offset=fields[field];return OGB3_OK;}
 case 12:{static const uint32_t fields[]={offsetof(ogb3_character_state,position),offsetof(ogb3_character_state,velocity),offsetof(ogb3_character_state,ground_normal),offsetof(ogb3_character_state,ground_shape),offsetof(ogb3_character_state,grounded),offsetof(ogb3_character_state,reserved)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_character_state);*alignment=_Alignof(ogb3_character_state);*offset=fields[field];return OGB3_OK;}
 case 13:{static const uint32_t fields[]={offsetof(ogb3_character_result,state),offsetof(ogb3_character_result,displacement),offsetof(ogb3_character_result,iterations),offsetof(ogb3_character_result,plane_count)};
 REQUIRE(field<sizeof(fields)/sizeof(fields[0]));*size=sizeof(ogb3_character_result);*alignment=_Alignof(ogb3_character_result);*offset=fields[field];return OGB3_OK;}
 default:return OGB3_INVALID_ARGUMENT;}}
