/* Upgrade-specific regression over real Native state. No framework state, fake
 * packet parser or successful counter/head assignment. */
#include "api.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include "box3d/box3d.h"
#include "physics_world.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define OK(x) do{ogb3_status status_=(x);if(status_){fprintf(stderr,"line%d status%d\n",__LINE__,status_);abort();}}while(0)
extern ogb3_status ogb3_recovery_test_mutate(const ogb3_recovery_catalog*,const uint8_t*,uint64_t,uint32_t,uint8_t*,uint64_t,uint64_t*);
static b3WorldId native_world(ogb3_world packed){b3WorldId id;memcpy(&id,&packed,sizeof id);return id;}
static b3BodyId native_body(ogb3_body packed){b3BodyId id;memcpy(&id,&packed,sizeof id);return id;}
static ogb3_world world(void){ogb3_world_def d;ogb3_world w=0;OK(ogb3_world_def_default(&d));OK(ogb3_world_create(&d,&w));return w;}
static ogb3_body box(ogb3_world w,int type,float y,ogb3_vec3 half){
 ogb3_body_def d;OK(ogb3_body_def_default(&d));d.type=type;d.pose.position.y=y;d.enable_sleep=0;
 ogb3_body b=0;OK(ogb3_body_create(w,&d,&b));ogb3_shape_def sd;ogb3_shape s=0;OK(ogb3_shape_def_default(&sd));OK(ogb3_shape_box(b,&sd,&half,&s));return b;
}
static uint8_t* dump(ogb3_world w,uint64_t*n){OK(ogb3_state_dump(w,NULL,0,n));uint8_t*p=malloc(*n);assert(p);OK(ogb3_state_dump(w,p,*n,n));return p;}
static void matches(ogb3_world w,const uint8_t*expected,uint64_t n){uint64_t size=0;uint8_t*p=dump(w,&size);assert(size==n&&!memcmp(p,expected,n));free(p);}
static void same(ogb3_world a,ogb3_world b){uint64_t n=0;uint8_t*p=dump(a,&n);matches(b,p,n);free(p);}
static void check_new_fields(ogb3_world w,ogb3_body_key key){
 b3WorldId id=native_world(w);assert(b3World_GetRestitutionIterations(id)==5);
 assert(b3World_IsRestitutionPropagationEnabled(id));
 assert(b3World_GetIsotropicInertiaTolerance(id)==.73f);
 ogb3_body b=0;OK(ogb3_body_resolve(w,key,&b));assert(b3Body_GetSafetyFactor(native_body(b))==2.0f);
 b3World*n=b3GetWorldFromId(id);assert(n->fatAABBs.count==n->shapes.count&&n->fatAABBs.count==3&&n->simdWidth==4);
}
int main(void){
 assert(ogb3_state_version()==4);ogb3_world source=world();
 box(source,OGB3_STATIC,-.5f,(ogb3_vec3){5,.5f,5});
 ogb3_body a=box(source,OGB3_DYNAMIC,.55f,(ogb3_vec3){.5f,.5f,.5f});
 box(source,OGB3_DYNAMIC,1.6f,(ogb3_vec3){.5f,.5f,.5f});
 b3WorldId native=native_world(source);
 b3World_SetRestitutionIterations(native,5);b3World_EnableRestitutionPropagation(native,true);
 b3World_SetIsotropicInertiaTolerance(native,.73f);b3Body_SetSafetyFactor(native_body(a),2.0f);
 ogb3_body_key key=0;OK(ogb3_body_get_key(a,&key));
 for(int i=0;i<30;i++)OK(ogb3_world_step_fixed(source));
 check_new_fields(source,key);
 ogb3_recovery_config cfg;OK(ogb3_recovery_config_default(&cfg));
 ogb3_recovery_asset assets[]={{.id=1,.kind=OGB3_RECOVERY_BOX,.a={5,.5f,5}},
                             {.id=2,.kind=OGB3_RECOVERY_BOX,.a={.5f,.5f,.5f}}};
 ogb3_recovery_catalog*catalog=NULL;OK(ogb3_recovery_catalog_create(&cfg,assets,2,&catalog));
 ogb3_recovery_identity identity;OK(ogb3_recovery_identity_get(catalog,&identity));assert(identity.solver_format==4);
 ogb3_snapshot*saved=NULL,*decoded=NULL;OK(ogb3_snapshot_capture(source,&saved));uint64_t size=0;
 OK(ogb3_recovery_write(catalog,saved,NULL,0,&size,NULL));
 uint8_t*bytes=malloc(size),*bad=malloc(size+1024);assert(bytes&&bad);
 OK(ogb3_recovery_write(catalog,saved,bytes,size,&size,NULL));assert(bytes[12]==4);
 uint64_t n=0;uint8_t*before=dump(source,&n);
 /* Real two-proxy tree exercises the replacement for the retired move-array
  * relation: a moved leaf without its required ancestor marker. */
 uint64_t bad_size=0;OK(ogb3_recovery_test_mutate(catalog,bytes,size,6,bad,size+1024,&bad_size));
 ogb3_allocation_stats e0,e1,w0,w1;OK(ogb3_engine_allocation_stats(&e0));OK(ogb3_snapshot_allocation_stats(&w0));
 ogb3_snapshot*rejected=(void*)(uintptr_t)1;
 assert(ogb3_recovery_read(catalog,bad,bad_size,0,&rejected,NULL)==OGB3_CORRUPT&&!rejected);
 OK(ogb3_engine_allocation_stats(&e1));OK(ogb3_snapshot_allocation_stats(&w1));
 assert(e0.total_calls==e1.total_calls&&e0.live_bytes==e1.live_bytes&&w0.live_bytes==w1.live_bytes);matches(source,before,n);
 puts("upgrade paired-tree moved-leaf/ancestor mismatch rejected before Native allocation; publication retained PASS");
 OK(ogb3_recovery_read(catalog,bytes,size,0,&decoded,NULL));
 OK(ogb3_world_destroy(source)); /* Snapshot/catalog are independent owners. */
 ogb3_world a_world=world(),b_world=world();
 OK(ogb3_snapshot_restore(a_world,saved));OK(ogb3_snapshot_restore(b_world,decoded));
 check_new_fields(a_world,key);check_new_fields(b_world,key);matches(a_world,before,n);same(a_world,b_world);
 ogb3_snapshot_release(saved);ogb3_snapshot_release(decoded);ogb3_recovery_catalog_release(catalog);
 for(int i=0;i<8;i++){OK(ogb3_world_step_fixed(a_world));OK(ogb3_world_step_fixed(b_world));same(a_world,b_world);}
 OK(ogb3_world_destroy(a_world));OK(ogb3_world_destroy(b_world));free(bytes);free(bad);free(before);
 OK(ogb3_engine_allocation_stats(&e1));OK(ogb3_snapshot_allocation_stats(&w1));assert(!e1.live_bytes&&!w1.live_bytes);
 printf("upgrade nondefault restitution/propagation/inertia-tolerance/body-safety/fatAABBs captured+canonical+source-free+8step exact continuation; native%llu wrapper%llu PASS\n",(unsigned long long)e1.live_bytes,(unsigned long long)w1.live_bytes);
 return 0;
}
