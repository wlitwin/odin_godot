#include "motion.h"
#include "authoring_catalog.h"
#include "state_dump.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern ogb3_status ogb3_recovery_test_mutate(const ogb3_recovery_catalog *,const uint8_t *,uint64_t,uint32_t,uint8_t *,uint64_t,uint64_t *);
extern void ogb3_recovery_test_fail_build_after(int64_t);
#define OK(x) do{ogb3_status s_=(x);if(s_){fprintf(stderr,"status%d line%d\n",s_,__LINE__);abort();}}while(0)
static uint64_t live(void){ogb3_allocation_stats a;OK(ogb3_snapshot_allocation_stats(&a));return a.live_bytes;}
static ogb3_world world(void){ogb3_world_def d;OK(ogb3_world_def_default(&d));d.gravity=(ogb3_vec3){0};d.enable_sleep=0;ogb3_world w=0;OK(ogb3_world_create(&d,&w));return w;}
static ogb3_body make_body(ogb3_world w,int type,float x,float y,float z,ogb3_vec3 size){
 ogb3_body_def d;OK(ogb3_body_def_default(&d));d.type=type;d.pose.position=(ogb3_vec3){x,y,z};d.enable_sleep=0;ogb3_body b=0;OK(ogb3_body_create(w,&d,&b));
 ogb3_shape_def shape;OK(ogb3_shape_def_default(&shape));ogb3_shape s=0;OK(ogb3_shape_box(b,&shape,&size,&s));return b;
}
static void equal(ogb3_world a,ogb3_world b){uint64_t n=0,m=0;OK(ogb3_state_dump(a,NULL,0,&n));OK(ogb3_state_dump(b,NULL,0,&m));assert(n==m);uint8_t *x=malloc(n),*y=malloc(n);assert(x&&y);OK(ogb3_state_dump(a,x,n,&n));OK(ogb3_state_dump(b,y,n,&m));assert(!memcmp(x,y,n));free(x);free(y);}
static void configure(ogb3_motion_joint_def *d){
 switch(d->kind){
 case OGB3_PIN:break;
 case OGB3_HINGE:case OGB3_SLIDER:d->axis=(ogb3_joint_axis){7,2,.5f,.1f,-.4f,.4f,.2f,3};break;
 case OGB3_DISTANCE:d->distance.axis=(ogb3_joint_axis){7,2,.5f,0,.5f,2,.2f,3};d->distance.length=1;d->distance.lower_spring_force=-100;d->distance.upper_spring_force=100;break;
 case OGB3_SPHERICAL:d->spherical.flags=15;d->spherical.hertz=2;d->spherical.damping_ratio=.5f;d->spherical.cone_angle=.8f;d->spherical.lower_twist=-.5f;d->spherical.upper_twist=.5f;d->spherical.max_motor_torque=3;d->spherical.motor_velocity=(ogb3_vec3){.1f,.2f,.3f};d->spherical.target_rotation=(ogb3_quat){sinf(.1f),0,0,cosf(.1f)};break;
 case OGB3_MOTOR:d->motor=(ogb3_joint_motor){{.5f,0,0},{.1f,.2f,.3f},10,10,2,.5f,2,.5f,10,10};break;
 case OGB3_WELD:d->weld=(ogb3_joint_weld){2,3,.5f,.5f};break;
 case OGB3_WHEEL:d->wheel=(ogb3_joint_wheel){31,2,.5f,-.5f,.5f,3,.2f,2,.5f,.1f,3,-.3f,.3f};break;
 }
}
static void joints(void){
 for(uint32_t kind=OGB3_PIN;kind<=OGB3_WHEEL;kind++){
  uint64_t before=live();ogb3_world w=world(),r=world();ogb3_body a=make_body(w,OGB3_STATIC,0,0,0,(ogb3_vec3){.25f,.25f,.25f});ogb3_body b=make_body(w,OGB3_DYNAMIC,0,1,0,(ogb3_vec3){.25f,.25f,.25f});
  ogb3_motion_joint_def d;OK(ogb3_motion_joint_default(kind,&d));configure(&d);OK(ogb3_body_get_key(a,&d.body_a));OK(ogb3_body_get_key(b,&d.body_b));
  uint64_t hash,mode;OK(ogb3_state_digest(w,&hash,&mode));
  ogb3_motion_joint_def bad=d;ogb3_joint_key out=99;bad.body_b=bad.body_a;assert(ogb3_motion_joint_create(w,&bad,&out)==OGB3_INVALID_ARGUMENT&&!out);
  bad=d;bad.local_frame_a.rotation=(ogb3_quat){0};assert(ogb3_motion_joint_create(w,&bad,&out)==OGB3_INVALID_ARGUMENT&&!out);
  bad=d;bad.constraint_hertz=NAN;assert(ogb3_motion_joint_create(w,&bad,&out)==OGB3_INVALID_ARGUMENT&&!out);
  bad=d;bad.reserved=1;assert(ogb3_motion_joint_create(w,&bad,&out)==OGB3_INVALID_ARGUMENT&&!out);
  uint64_t after,mode2;OK(ogb3_state_digest(w,&after,&mode2));assert(after==hash&&mode2==mode);
  ogb3_joint_key key=0;OK(ogb3_motion_joint_create(w,&d,&key));assert(key);assert(ogb3_motion_joint_create(w,&d,&out)==OGB3_CAPACITY&&!out);
  for(int i=0;i<8;i++)OK(ogb3_world_step_fixed(w));
  ogb3_snapshot *snapshot=NULL,*clone=NULL;OK(ogb3_snapshot_capture(w,&snapshot));OK(ogb3_snapshot_clone(snapshot,&clone));
  OK(ogb3_snapshot_restore(r,snapshot));equal(w,r);OK(ogb3_snapshot_restore(w,clone));equal(w,r);
  ogb3_recovery_config config;OK(ogb3_recovery_config_default(&config));ogb3_recovery_asset_v2 asset={.version=2,.struct_bytes=sizeof(asset),.base={.id=1,.kind=OGB3_RECOVERY_BOX,.a={.25f,.25f,.25f}}};
  ogb3_recovery_catalog *catalog=NULL;OK(ogb3_recovery_catalog_create_v3(&config,&asset,1,&catalog));
  ogb3_recovery_identity identity;OK(ogb3_recovery_identity_get(catalog,&identity));assert(identity.recovery_format==3);
  uint64_t n=0;OK(ogb3_recovery_write(catalog,snapshot,NULL,0,&n,NULL));uint8_t *bytes=malloc(n),*again=malloc(n),*mutated=malloc(n+1024);assert(bytes&&again&&mutated);
  OK(ogb3_recovery_write(catalog,snapshot,bytes,n,&n,NULL));assert(bytes[8]==3);ogb3_snapshot *decoded=NULL;OK(ogb3_recovery_read(catalog,bytes,n,0,&decoded,NULL));
  uint64_t m=0;OK(ogb3_recovery_write(catalog,decoded,again,n,&m,NULL));assert(m==n&&!memcmp(bytes,again,n));
  OK(ogb3_snapshot_restore(r,decoded));equal(w,r);
  for(uint32_t code=60;code<=64;code++){
   uint64_t size=0;OK(ogb3_recovery_test_mutate(catalog,bytes,n,code,mutated,n+1024,&size));ogb3_snapshot *candidate=(void *)(uintptr_t)1;uint64_t allocations=live();
   assert(ogb3_recovery_read(catalog,mutated,size,0,&candidate,NULL)!=OGB3_OK&&!candidate);assert(live()==allocations);equal(w,r);
  }
  ogb3_recovery_catalog *old=NULL;OK(ogb3_recovery_catalog_create_v2(&config,&asset,1,&old));ogb3_snapshot *candidate=(void *)(uintptr_t)1;assert(ogb3_recovery_read(old,bytes,n,0,&candidate,NULL)!=OGB3_OK&&!candidate);ogb3_recovery_catalog_release(old);
  for(int fail=0;fail<4;fail++){uint64_t allocations=live();ogb3_recovery_test_fail_build_after(fail);candidate=NULL;assert(ogb3_recovery_read(catalog,bytes,n,0,&candidate,NULL)==OGB3_OUT_OF_MEMORY&&!candidate);ogb3_recovery_test_fail_build_after(-1);assert(live()==allocations);}
  ogb3_recovery_catalog_release(catalog);ogb3_snapshot_release(snapshot);ogb3_snapshot_release(clone);OK(ogb3_world_destroy(w));w=world();OK(ogb3_snapshot_restore(w,decoded));equal(w,r);ogb3_snapshot_release(decoded);
  for(int i=0;i<5;i++){OK(ogb3_world_step_fixed(w));OK(ogb3_world_step_fixed(r));equal(w,r);}
  ogb3_joint j=0;OK(ogb3_joint_resolve(w,key,&j));OK(ogb3_joint_destroy(j));OK(ogb3_world_destroy(w));OK(ogb3_world_destroy(r));free(bytes);free(again);free(mutated);assert(live()==before);
  printf("motion joint kind%u actual-create/full-solver/canonical/scratch/source-free/malformed PASS\n",kind);
 }
}
/* Exact accepted schema2 Distance default from the framework fixture: inactive
 * 0/0 bounds, rest length1, coincident world-space anchors. Exercise admission
 * and complete canonical state at the two boundaries the adapters consume. */
static void distance_default_boundaries(void){
 uint64_t allocations=live();ogb3_world w=world(),scratch=world();
 ogb3_body anchor=make_body(w,OGB3_STATIC,0,-.5f,0,(ogb3_vec3){8,.5f,8});
 ogb3_body actor=make_body(w,OGB3_DYNAMIC,-3,2,0,(ogb3_vec3){.25f,.25f,.25f});
 make_body(w,OGB3_STATIC,2,1,0,(ogb3_vec3){.25f,1,3});
 ogb3_motion_joint_def d;OK(ogb3_motion_joint_default(OGB3_DISTANCE,&d));
 d.distance=(ogb3_joint_distance){.length=1};d.constraint_damping_ratio=1;
 d.local_frame_a.position=(ogb3_vec3){-3,2.5f,0};
 OK(ogb3_body_get_key(anchor,&d.body_a));OK(ogb3_body_get_key(actor,&d.body_b));
 ogb3_joint_key key=0;OK(ogb3_motion_joint_create(w,&d,&key));assert(key);
 ogb3_recovery_config config;OK(ogb3_recovery_config_default(&config));
 ogb3_recovery_asset_v2 assets[]={
  {.version=2,.struct_bytes=sizeof(ogb3_recovery_asset_v2),.base={.id=1,.kind=OGB3_RECOVERY_BOX,.a={8,.5f,8}}},
  {.version=2,.struct_bytes=sizeof(ogb3_recovery_asset_v2),.base={.id=2,.kind=OGB3_RECOVERY_BOX,.a={.25f,.25f,.25f}}},
  {.version=2,.struct_bytes=sizeof(ogb3_recovery_asset_v2),.base={.id=3,.kind=OGB3_RECOVERY_BOX,.a={.25f,1,3}}}
 };
 ogb3_recovery_catalog *catalog=NULL;OK(ogb3_recovery_catalog_create_v3(&config,assets,3,&catalog));
 for(unsigned tick=0;tick<=1;tick++){
  uint64_t required=0;ogb3_recovery_diagnostic diagnostic={0};
  OK(ogb3_recovery_world_admit(catalog,w,0,&required,&diagnostic));assert(required);
  ogb3_snapshot *saved=NULL,*decoded=NULL;OK(ogb3_snapshot_capture(w,&saved));
  uint64_t n=0;OK(ogb3_recovery_write(catalog,saved,NULL,0,&n,&diagnostic));assert(n==required);
  uint8_t *bytes=malloc(n),*again=malloc(n),*bad=malloc(n+1024);assert(bytes&&again&&bad);
  OK(ogb3_recovery_write(catalog,saved,bytes,n,&n,&diagnostic));
  OK(ogb3_recovery_read(catalog,bytes,n,0,&decoded,&diagnostic));
  uint64_t m=0;OK(ogb3_recovery_write(catalog,decoded,again,n,&m,&diagnostic));assert(m==n&&!memcmp(bytes,again,n));
  OK(ogb3_snapshot_restore(scratch,decoded));equal(w,scratch);
  /* Inverted native bounds remain invalid even with enableLimit=false. */
  uint64_t bad_size=0;OK(ogb3_recovery_test_mutate(catalog,bytes,n,65,bad,n+1024,&bad_size));
  ogb3_snapshot *rejected=(void *)(uintptr_t)1;assert(ogb3_recovery_read(catalog,bad,bad_size,0,&rejected,&diagnostic)==OGB3_CORRUPT&&!rejected);
  OK(ogb3_snapshot_restore(w,saved));equal(w,scratch);
  ogb3_snapshot_release(decoded);ogb3_snapshot_release(saved);free(bytes);free(again);free(bad);
  if(!tick){OK(ogb3_world_step_fixed(w));OK(ogb3_world_step_fixed(scratch));equal(w,scratch);}
  printf("motion accepted-default Distance coincident-anchors tick%u admission/canonical/full-state/strict-inverted-reject PASS\n",tick);
 }
 ogb3_recovery_catalog_release(catalog);OK(ogb3_world_destroy(w));OK(ogb3_world_destroy(scratch));assert(live()==allocations);
}
static void query_and_mover(void){
 ogb3_world w=world(),scratch=world();ogb3_vec3 box={.5f,.5f,.5f};ogb3_body obstacle=make_body(w,OGB3_STATIC,0,0,0,box);make_body(w,OGB3_STATIC,0,0,3,box);
 ogb3_motion_filter filter={1,UINT64_MAX,0,0,0};ogb3_vec3 lo={-1,-1,-1},hi={1,1,4};ogb3_motion_hit hits[256],sentinel;memset(&sentinel,0xa5,sizeof(sentinel));hits[0]=sentinel;uint32_t n=0;
 assert(ogb3_query_aabb(w,&lo,&hi,&filter,NULL,0,&n)==OGB3_CAPACITY&&n==2);
 assert(ogb3_query_aabb(w,&lo,&hi,&filter,hits,1,&n)==OGB3_CAPACITY&&n==2&&!memcmp(hits,&sentinel,sizeof(sentinel)));
 OK(ogb3_query_aabb(w,&lo,&hi,&filter,hits,256,&n));assert(n==2&&hits[0].shape<hits[1].shape&&hits[0].body&&hits[1].body);
 ogb3_vec3 origin={0,0,-3},translation={0,0,8};OK(ogb3_query_ray(w,&origin,&translation,&filter,hits,256,&n));assert(n==2&&hits[0].fraction<hits[1].fraction);
 ogb3_motion_capsule capsule={{0,-.2f,0},{0,.2f,0},.2f};OK(ogb3_query_capsule_cast(w,&origin,&capsule,&translation,&filter,hits,256,&n));assert(n==2&&hits[0].fraction<hits[1].fraction);
 origin=(ogb3_vec3){0};OK(ogb3_query_capsule(w,&origin,&capsule,&filter,hits,256,&n));assert(n==1);
 OK(ogb3_body_get_key(obstacle,&filter.exclude_body));OK(ogb3_query_capsule(w,&origin,&capsule,&filter,hits,256,&n));assert(n==0);filter.exclude_body=0;
 filter.mask_bits=0;OK(ogb3_query_aabb(w,&lo,&hi,&filter,hits,256,&n));assert(n==0);filter.mask_bits=UINT64_MAX;
 ogb3_snapshot *s=NULL;OK(ogb3_snapshot_capture(w,&s));OK(ogb3_snapshot_restore(scratch,s));ogb3_snapshot_release(s);
 ogb3_motion_hit other[256];uint32_t count=0;origin=(ogb3_vec3){0,0,-3};OK(ogb3_query_ray(w,&origin,&translation,&filter,hits,256,&n));OK(ogb3_query_ray(scratch,&origin,&translation,&filter,other,256,&count));assert(n==count&&!memcmp(hits,other,(size_t)n*sizeof(hits[0])));
 OK(ogb3_world_destroy(scratch));OK(ogb3_world_destroy(w));
 w=world();make_body(w,OGB3_STATIC,0,-.5f,0,(ogb3_vec3){10,.5f,10});make_body(w,OGB3_STATIC,2,2,0,(ogb3_vec3){.5f,2,10});
 ogb3_character_config config={.version=1,.max_slides=8,.capsule={{0,.3f,0},{0,.9f,0},.3f},.up={0,1,0},.floor_cosine=.7f,.filter=filter};
 ogb3_character_state state={.position={0,.01f,0},.velocity={180,-1,60}};ogb3_character_result result;
 uint64_t full,motion;OK(ogb3_state_digest(w,&full,&motion));OK(ogb3_character_step(w,&config,&state,0,&result));assert(!memcmp(&state,&result.state,sizeof(state))&&result.iterations==0);
 OK(ogb3_character_step(w,&config,&state,1.0f/60,&result));assert(result.state.position.x<1.25f&&result.state.position.z>.5f&&result.state.position.y>=-.02f&&result.state.grounded&&result.plane_count>0);
 uint64_t full_after,motion_after;OK(ogb3_state_digest(w,&full_after,&motion_after));assert(full==full_after&&motion==motion_after);
 ogb3_character_result unchanged;memset(&unchanged,0xa5,sizeof(unchanged));result=unchanged;assert(ogb3_character_step(w,&config,&state,NAN,&result)==OGB3_INVALID_ARGUMENT&&!memcmp(&result,&unchanged,sizeof(result)));
 assert(ogb3_character_step(w,&config,&state,.02f,&result)==OGB3_INVALID_ARGUMENT&&!memcmp(&result,&unchanged,sizeof(result)));
 config.capsule.radius=-1;assert(ogb3_character_step(w,&config,&state,1.0f/60,&result)==OGB3_INVALID_ARGUMENT&&!memcmp(&result,&unchanged,sizeof(result)));
 OK(ogb3_world_destroy(w));
 /* A genuine inclined box tests floor-angle classification, not a fabricated
  * normal. The same geometry is walkable at cos=.7 and steep at cos=.95. */
 w=world();ogb3_body slope=make_body(w,OGB3_STATIC,0,-.5f,0,(ogb3_vec3){10,.5f,10});ogb3_pose pose={{0,-.5f,0},{0,0,sinf(.2617994f),cosf(.2617994f)}};OK(ogb3_body_set_pose(slope,&pose));
 config.capsule=capsule;config.capsule.center1=(ogb3_vec3){0,.3f,0};config.capsule.center2=(ogb3_vec3){0,.9f,0};config.capsule.radius=.3f;
 state=(ogb3_character_state){.position={0,.4f,0},.velocity={0,-30,0}};config.floor_cosine=.7f;
 OK(ogb3_character_step(w,&config,&state,1.0f/60,&result));assert(result.state.grounded&&result.state.ground_normal.y>.8f&&result.state.ground_normal.y<.9f);
 config.floor_cosine=.95f;OK(ogb3_character_step(w,&config,&state,1.0f/60,&result));assert(!result.state.grounded);OK(ogb3_world_destroy(w));
 /* Exact equal-distance ties sort by world-independent key; sensor selection
  * is explicit. The complete-hit read publishes nothing on short capacity. */
 w=world();make_body(w,OGB3_STATIC,0,0,0,box);ogb3_body sensor=make_body(w,OGB3_STATIC,0,0,0,box);
 ogb3_shape_def sd;OK(ogb3_shape_def_default(&sd));sd.is_sensor=1;ogb3_shape sensor_shape;OK(ogb3_shape_sphere(sensor,&sd,&(ogb3_vec3){0},.4f,&sensor_shape));
 origin=(ogb3_vec3){0,0,-3};translation=(ogb3_vec3){0,0,6};filter.include_sensors=0;
 OK(ogb3_query_ray(w,&origin,&translation,&filter,hits,256,&n));assert(n==2&&hits[0].fraction==hits[1].fraction&&hits[0].shape<hits[1].shape);
 lo=(ogb3_vec3){-1,-1,-1};hi=(ogb3_vec3){1,1,1};filter.include_sensors=1;OK(ogb3_query_aabb(w,&lo,&hi,&filter,hits,256,&n));assert(n==3);filter.include_sensors=0;OK(ogb3_query_aabb(w,&lo,&hi,&filter,hits,256,&n));assert(n==2);
 OK(ogb3_world_destroy(w));
 w=world();for(int i=0;i<36;i++)make_body(w,OGB3_STATIC,(float)i*2,0,0,box);hits[0]=sentinel;n=99;
 assert(ogb3_query_aabb(w,&lo,&hi,&filter,hits,256,&n)==OGB3_CAPACITY&&n==99&&!memcmp(hits,&sentinel,sizeof(sentinel)));OK(ogb3_world_destroy(w));
 puts("motion deterministic keys/ties/complete-capacity/filter/self-exclude/capsule/actual-mover-slide-floor-slope/read-only PASS");
}
int main(void){assert(ogb3_build_fingerprint());uint64_t allocations=live();uint32_t size,align,offset;OK(ogb3_motion_layout(7,2,&size,&align,&offset));assert(size==sizeof(ogb3_motion_joint_def)&&offset==8&&align==8);distance_default_boundaries();joints();query_and_mover();assert(live()==allocations);puts("Native motion controls PASS");return 0;}
