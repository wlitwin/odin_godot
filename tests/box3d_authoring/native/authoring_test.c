#include "authoring_catalog.h"
#include "state_dump.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void ogb3_snapshot_test_fail_allocation_after(int64_t);
extern void ogb3_recovery_test_fail_build_after(int64_t);
extern ogb3_status ogb3_recovery_test_mutate(const ogb3_recovery_catalog *,
    const uint8_t *,uint64_t,uint32_t,uint8_t *,uint64_t,uint64_t *);
#define OK(x) do {ogb3_status s_=(x);if(s_){fprintf(stderr,"status %d line %d\n",s_,__LINE__);abort();}} while(0)

static ogb3_recovery_asset_v2 asset(uint32_t id,uint32_t kind) {
  ogb3_recovery_asset_v2 a={0};a.version=2;a.struct_bytes=sizeof(a);a.base.id=id;a.base.kind=kind;return a;
}
static ogb3_world world(void) {
  ogb3_world_def d;ogb3_world w=0;OK(ogb3_world_def_default(&d));OK(ogb3_world_create(&d,&w));return w;
}
static ogb3_body body(ogb3_world w,int type,float x,float y,float z) {
  ogb3_body_def d;ogb3_body b=0;OK(ogb3_body_def_default(&d));d.type=type;d.enable_sleep=0;
  d.pose.position=(ogb3_vec3){x,y,z};OK(ogb3_body_create(w,&d,&b));return b;
}
static void equal(ogb3_world a,ogb3_world b) {
  uint64_t n=0,m=0;OK(ogb3_state_dump(a,NULL,0,&n));OK(ogb3_state_dump(b,NULL,0,&m));assert(n==m);
  uint8_t *x=malloc(n),*y=malloc(n);assert(x&&y);OK(ogb3_state_dump(a,x,n,&n));OK(ogb3_state_dump(b,y,n,&m));assert(!memcmp(x,y,n));free(x);free(y);
}
static uint64_t live(void) {
  ogb3_allocation_stats s;OK(ogb3_snapshot_allocation_stats(&s));return s.live_bytes;
}
static void descriptor_rejections(ogb3_recovery_config *cfg) {
  ogb3_vec3 p[]={{0,0,0},{1,0,0},{0,1,0},{0,0,1}};
  uint32_t idx[]={0,2,1};ogb3_recovery_asset_v2 a=asset(1,OGB3_RECOVERY_HULL);
  a.vertices=p;a.vertex_count=4;
  ogb3_recovery_catalog *c=NULL;
  for(unsigned mode=0;mode<9;mode++) {
    ogb3_recovery_asset_v2 v=a;ogb3_vec3 old=p[3];uint64_t before=live();
    switch(mode) {
    case 0:v.version=1;break;case 1:v.struct_bytes--;break;case 2:v.base.id=0;break;
    case 3:v.vertex_count=257;break;case 4:v.vertex_count=3;break;case 5:p[3]=(ogb3_vec3){1,1,0};break;
    case 6:p[3].x=NAN;break;case 7:v.indices=idx;v.triangle_count=1;break;case 8:v.base.a.x=1;break;
    }
    c=(void *)(uintptr_t)1;assert(ogb3_recovery_catalog_create_v2(cfg,&v,1,&c)!=OGB3_OK && !c);assert(live()==before);p[3]=old;
  }
  a=asset(1,OGB3_RECOVERY_MESH);a.vertices=p;a.vertex_count=4;a.indices=idx;a.triangle_count=1;
  for(unsigned mode=0;mode<5;mode++) {
    ogb3_recovery_asset_v2 v=a;uint32_t old=idx[2];uint64_t before=live();
    if(mode==0)idx[2]=4;if(mode==1)idx[2]=0;if(mode==2)v.indices=NULL;if(mode==3)v.triangle_count=0;if(mode==4)v.triangle_count=UINT32_MAX;
    c=(void *)(uintptr_t)1;assert(ogb3_recovery_catalog_create_v2(cfg,&v,1,&c)!=OGB3_OK && !c);assert(live()==before);idx[2]=old;
  }
  /* Distinct input arrays / order and an interior point, identical native hull. */
  ogb3_vec3 q[]={{0,0,1},{0,1,0},{1,0,0},{0,0,0},{.1f,.1f,.1f}};
  ogb3_recovery_asset_v2 aliases[2]={asset(1,OGB3_RECOVERY_HULL),asset(2,OGB3_RECOVERY_HULL)};
  aliases[0].vertices=p;aliases[0].vertex_count=4;aliases[1].vertices=q;aliases[1].vertex_count=5;
  uint64_t before=live();c=(void *)(uintptr_t)1;
  assert(ogb3_recovery_catalog_create_v2(cfg,aliases,2,&c)==OGB3_INVALID_ARGUMENT && !c);assert(live()==before);
  /* Fail each owned construction allocation; no partial catalog is published. */
  a=aliases[0];int succeeded=0;
  for(int64_t fail=0;fail<12;fail++) {
    before=live();ogb3_snapshot_test_fail_allocation_after(fail);c=NULL;
    ogb3_status s=ogb3_recovery_catalog_create_v2(cfg,&a,1,&c);ogb3_snapshot_test_fail_allocation_after(-1);
    if(!s){assert(c);ogb3_recovery_catalog_release(c);succeeded=1;assert(live()==before);break;}
    assert(s==OGB3_OUT_OF_MEMORY && !c);assert(live()==before);
  }
  assert(succeeded);puts("authoring descriptors/aliases/owned-construction-failure PASS");
}
static void primitive_v1(ogb3_recovery_config *cfg) {
  ogb3_recovery_asset a={.id=1,.kind=OGB3_RECOVERY_BOX,.a={.5f,.5f,.5f}};
  ogb3_recovery_catalog *c=NULL;OK(ogb3_recovery_catalog_create(cfg,&a,1,&c));
  ogb3_recovery_identity id;OK(ogb3_recovery_identity_get(c,&id));assert(id.recovery_format==1);
  ogb3_world w=world(),r=world();ogb3_body b=body(w,OGB3_DYNAMIC,0,2,0);ogb3_shape_def d;ogb3_shape shape=0;
  OK(ogb3_shape_def_default(&d));OK(ogb3_recovery_catalog_shape(c,1,b,&d,&shape));
  ogb3_snapshot *s=NULL,*decoded=NULL;OK(ogb3_snapshot_capture(w,&s));uint64_t n=0;OK(ogb3_recovery_write(c,s,NULL,0,&n,NULL));
  uint8_t *bytes=malloc(n);assert(bytes);OK(ogb3_recovery_write(c,s,bytes,n,&n,NULL));assert(bytes[8]==1);
  OK(ogb3_recovery_read(c,bytes,n,0,&decoded,NULL));OK(ogb3_snapshot_restore(r,decoded));equal(w,r);
  free(bytes);ogb3_snapshot_release(decoded);ogb3_snapshot_release(s);OK(ogb3_world_destroy(r));OK(ogb3_world_destroy(w));ogb3_recovery_catalog_release(c);
  puts("authoring legacy primitive constructor/format/roundtrip PASS");
}
static void advanced(ogb3_recovery_config *cfg) {
  ogb3_vec3 hull[]={{-.4f,0,-.4f},{.4f,0,-.4f},{0,.8f,0},{0,0,.5f}};
  ogb3_vec3 floor[]={{-8,0,-8},{-8,0,8},{8,0,-8},{8,0,8}};uint32_t floor_i[]={0,1,2,2,1,3};
  /* An externally baked 2x2 heightfield, represented only as deterministic Mesh. */
  ogb3_vec3 baked[]={{-2,0,-2},{-2,.25f,2},{2,.5f,-2},{2,.75f,2}};uint32_t baked_i[]={0,1,2,2,1,3};
  ogb3_recovery_asset_v2 a[6];
  a[0]=asset(1,OGB3_RECOVERY_BOX);a[0].base.a=(ogb3_vec3){.4f,.4f,.4f};
  a[1]=asset(2,OGB3_RECOVERY_SPHERE);a[1].base.radius=.4f;
  a[2]=asset(3,OGB3_RECOVERY_CAPSULE);a[2].base.a.y=-.25f;a[2].base.b.y=.25f;a[2].base.radius=.3f;
  a[3]=asset(4,OGB3_RECOVERY_HULL);a[3].vertices=hull;a[3].vertex_count=4;
  a[4]=asset(5,OGB3_RECOVERY_MESH);a[4].vertices=floor;a[4].vertex_count=4;a[4].indices=floor_i;a[4].triangle_count=2;
  a[5]=asset(6,OGB3_RECOVERY_MESH);a[5].vertices=baked;a[5].vertex_count=4;a[5].indices=baked_i;a[5].triangle_count=2;
  ogb3_recovery_catalog *c=NULL;OK(ogb3_recovery_catalog_create_v2(cfg,a,6,&c));
  ogb3_recovery_identity id;OK(ogb3_recovery_identity_get(c,&id));assert(id.recovery_format==2);
  /* Caller buffers can disappear immediately; the factory uses catalog copies. */
  memset(hull,0,sizeof(hull));memset(floor,0,sizeof(floor));memset(floor_i,0,sizeof(floor_i));memset(baked,0,sizeof(baked));memset(baked_i,0,sizeof(baked_i));
  ogb3_world w=world();ogb3_shape_def d;OK(ogb3_shape_def_default(&d));d.enable_contact_events=1;
  ogb3_shape shapes[6];ogb3_body bodies[6];
  for(unsigned i=0;i<4;i++){bodies[i]=body(w,OGB3_DYNAMIC,(float)i*2-3,1,0);OK(ogb3_recovery_catalog_shape(c,i+1,bodies[i],&d,shapes+i));}
  bodies[4]=body(w,OGB3_STATIC,0,0,0);OK(ogb3_recovery_catalog_shape(c,5,bodies[4],&d,shapes+4));
  bodies[5]=body(w,OGB3_STATIC,20,0,0);OK(ogb3_recovery_catalog_shape(c,6,bodies[5],&d,shapes+5));
  ogb3_shape bad=99;d.is_sensor=1;assert(ogb3_recovery_catalog_shape(c,5,bodies[4],&d,&bad)==OGB3_UNSUPPORTED && !bad);d.is_sensor=0;
  d.enable_sensor_events=1;assert(ogb3_recovery_catalog_shape(c,5,bodies[4],&d,&bad)==OGB3_UNSUPPORTED && !bad);d.enable_sensor_events=0;
  assert(ogb3_recovery_catalog_shape(c,5,bodies[0],&d,&bad)==OGB3_INVALID_ARGUMENT && !bad);
  for(unsigned i=0;i<90;i++)OK(ogb3_world_step(w,1.0f/60,4));
  ogb3_snapshot *source=NULL;OK(ogb3_snapshot_capture(w,&source));uint64_t n=0;
  ogb3_recovery_diagnostic diag={0};ogb3_status write_status=ogb3_recovery_write(c,source,NULL,0,&n,&diag);
  if(write_status)fprintf(stderr,"advanced write status%d section%u record%u field%u reason%u\n",write_status,diag.section,diag.record,diag.field,diag.reason);
  OK(write_status);assert(n && n<=cfg->max_bytes);
  uint8_t *bytes=malloc(n),*again=malloc(n),*mut=malloc(n+1024);assert(bytes&&again&&mut);
  OK(ogb3_recovery_write(c,source,bytes,n,&n,NULL));assert(bytes[8]==2);
  ogb3_snapshot *decoded=NULL;OK(ogb3_recovery_read(c,bytes,n,0,&decoded,NULL));
  uint64_t m=0;OK(ogb3_recovery_write(c,decoded,again,n,&m,NULL));assert(m==n&&!memcmp(bytes,again,n));
  ogb3_world r=world();OK(ogb3_snapshot_restore(r,decoded));equal(w,r);
  for(unsigned code=40;code<=43;code++) {
    uint64_t used=0;OK(ogb3_recovery_test_mutate(c,bytes,n,code,mut,n+1024,&used));
    ogb3_snapshot *out=(void *)(uintptr_t)1;uint64_t before=live();
    assert(ogb3_recovery_read(c,mut,used,0,&out,NULL)!=OGB3_OK && !out);assert(live()==before);equal(w,r);
  }
  /* Whole bytes, grammar, asset identity, resource bounds, and atomic failures. */
  for(unsigned i=0;i<3;i++) {
    memcpy(mut,bytes,n);uint64_t used=n;if(i==0)used--;if(i==1)mut[n-1]^=1;if(i==2)mut[80]^=1;
    ogb3_snapshot *out=(void *)(uintptr_t)1;assert(ogb3_recovery_read(c,mut,used,0,&out,NULL)!=OGB3_OK&&!out);
  }
  for(int64_t fail=0;fail<5;fail++) {
    uint64_t before=live();ogb3_recovery_test_fail_build_after(fail);ogb3_snapshot *out=NULL;
    ogb3_status status=ogb3_recovery_read(c,bytes,n,0,&out,NULL);ogb3_recovery_test_fail_build_after(-1);
    assert(status==OGB3_OUT_OF_MEMORY&&!out);assert(live()==before);equal(w,r);
  }
  ogb3_recovery_catalog_release(c);c=NULL;
  /* Native world and detached snapshots both survive catalog/source release. */
  ogb3_snapshot_release(source);source=NULL;
  OK(ogb3_world_destroy(w));ogb3_world another=world();OK(ogb3_snapshot_restore(another,decoded));equal(r,another);
  for(unsigned i=0;i<8;i++){OK(ogb3_world_step(r,1.0f/60,4));OK(ogb3_world_step(another,1.0f/60,4));equal(r,another);}
  ogb3_snapshot_release(decoded);OK(ogb3_world_destroy(r));OK(ogb3_world_destroy(another));
  free(bytes);free(again);free(mut);puts("authoring Hull/Mesh/baked-Mesh/canonical/cache-malformed/lifetime/continuation PASS");
}
int main(void) {
  assert(ogb3_build_fingerprint());uint64_t before=live();ogb3_recovery_config cfg;OK(ogb3_recovery_config_default(&cfg));
  uint32_t size=0,alignment=0,offset=0;OK(ogb3_authoring_asset_layout(3,&size,&alignment,&offset));assert(size==sizeof(ogb3_recovery_asset_v2)&&offset==48&&alignment==_Alignof(ogb3_recovery_asset_v2));
  descriptor_rejections(&cfg);primitive_v1(&cfg);advanced(&cfg);assert(live()==before);
  puts("Native authored catalog controls PASS");return 0;
}
