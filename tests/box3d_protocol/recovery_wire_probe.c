/* Independent public-ABI probe. Each malformed case executes in its own process.
 * This does not import diagnostic dumps or use private engine structures. */
#include "api.h"
#include "owned_snapshot.h"
#include "state_dump.h"
#include "recovery_codec.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OK(call) assert((call)==OGB3_OK)
typedef struct {
    uint64_t used,capacity,geometry,normalized,wrapper,native;
    uint32_t count;
} SnapshotInfo;
#define INFO_ARGS(i) &(i).used,&(i).capacity,&(i).geometry,&(i).count,&(i).normalized,&(i).wrapper,&(i).native
static int same_info(SnapshotInfo a,SnapshotInfo b){
    return a.used==b.used&&a.capacity==b.capacity&&a.geometry==b.geometry&&a.count==b.count&&
           a.normalized==b.normalized&&a.wrapper==b.wrapper&&a.native==b.native;
}
static ogb3_world fixture(void){
    ogb3_world_def wd;OK(ogb3_world_def_default(&wd));wd.gravity=(ogb3_vec3){0};
    ogb3_world world;OK(ogb3_world_create(&wd,&world));
    ogb3_body_def bd;OK(ogb3_body_def_default(&bd));ogb3_body a,b;
    OK(ogb3_body_create(world,&bd,&a));bd.type=OGB3_DYNAMIC;bd.pose.position.y=1.9f;
    OK(ogb3_body_create(world,&bd,&b));
    ogb3_shape_def sd;OK(ogb3_shape_def_default(&sd));ogb3_shape shape;
    OK(ogb3_shape_box(a,&sd,&(ogb3_vec3){1,1,1},&shape));
    OK(ogb3_shape_box(b,&sd,&(ogb3_vec3){1,1,1},&shape));
    /* Keep native default break thresholds while exercising both contact and
     * joint state. This guards valid field-specific finite sentinels too. */
    ogb3_hinge_def hd;OK(ogb3_hinge_def_default(&hd));hd.body_a=a;hd.body_b=b;
    hd.local_frame_a.position.y=1.9f;hd.collide_connected=1;
    hd.enable_motor=1;hd.motor_speed=.25f;hd.max_motor_torque=2;
    ogb3_joint joint;OK(ogb3_joint_hinge_create(world,&hd,&joint));
    for(int i=0;i<3;i++)OK(ogb3_world_step_fixed(world));return world;
}
static uint8_t* read_file(const char*path,size_t*size){
    FILE*f=fopen(path,"rb");assert(f);assert(!fseek(f,0,SEEK_END));long n=ftell(f);assert(n>=0&&n<=1024*1024);
    assert(!fseek(f,0,SEEK_SET));uint8_t*data=malloc(n?(size_t)n:1);assert(data);
    assert(fread(data,1,(size_t)n,f)==(size_t)n);assert(!fclose(f));*size=(size_t)n;return data;
}
int main(int argc,char**argv){
    assert(argc==3);
    ogb3_recovery_config config;OK(ogb3_recovery_config_default(&config));
    ogb3_recovery_asset asset={.id=1,.kind=OGB3_RECOVERY_BOX,.a={1,1,1}};
    ogb3_recovery_catalog*catalog=NULL;OK(ogb3_recovery_catalog_create(&config,&asset,1,&catalog));
    ogb3_world published=fixture();uint64_t original=0,motion=0;
    OK(ogb3_state_digest(published,&original,&motion));
    if(!strcmp(argv[1],"encode")){
        ogb3_allocation_stats admission_before,admission_after;
        OK(ogb3_engine_allocation_stats(&admission_before));
        uint64_t admitted=0;ogb3_recovery_diagnostic admission_diagnostic;
        OK(ogb3_recovery_world_admit(catalog,published,0,&admitted,&admission_diagnostic));
        OK(ogb3_engine_allocation_stats(&admission_after));
        assert(admission_before.total_calls==admission_after.total_calls);
        assert(admission_before.live_bytes==admission_after.live_bytes);
        uint64_t unchanged=0;OK(ogb3_state_digest(published,&unchanged,&motion));assert(unchanged==original);
        ogb3_snapshot*image=NULL;SnapshotInfo captured,queried,cloned;
        OK(ogb3_snapshot_capture_info(published,&image,INFO_ARGS(captured)));
        OK(ogb3_snapshot_info(image,INFO_ARGS(queried)));assert(same_info(captured,queried));
        ogb3_snapshot*clone=NULL;OK(ogb3_snapshot_clone_info(image,&clone,INFO_ARGS(cloned)));
        assert(same_info(captured,cloned));ogb3_snapshot_release(clone);
        uint64_t n=0;ogb3_recovery_diagnostic diagnostic;
        OK(ogb3_recovery_write(catalog,image,NULL,0,&n,&diagnostic));uint8_t*data=malloc((size_t)n);assert(data);
        assert(admitted==n);
        OK(ogb3_recovery_write(catalog,image,data,n,&n,&diagnostic));
        FILE*f=fopen(argv[2],"wb");assert(f);assert(fwrite(data,1,(size_t)n,f)==n);assert(!fclose(f));
        free(data);ogb3_snapshot_release(image);
        printf("{\"encoded_bytes\":%llu}\n",(unsigned long long)n);
    }else{
        assert(!strcmp(argv[1],"read"));size_t n=0;uint8_t*data=read_file(argv[2],&n);
        ogb3_allocation_stats before_engine,before_owned,after_engine,after_owned;
        OK(ogb3_engine_allocation_stats(&before_engine));OK(ogb3_snapshot_allocation_stats(&before_owned));
        ogb3_snapshot*image=NULL;ogb3_recovery_diagnostic diagnostic;
        ogb3_status status=ogb3_recovery_read(catalog,data,n,0,&image,&diagnostic);
        if(status==OGB3_OK){
            assert(image);ogb3_world_def def;OK(ogb3_world_def_default(&def));ogb3_world candidate;
            OK(ogb3_world_create(&def,&candidate));OK(ogb3_snapshot_restore(candidate,image));
            for(int i=0;i<8;i++)OK(ogb3_world_step_fixed(candidate));
            OK(ogb3_world_destroy(candidate));ogb3_snapshot_release(image);
        }else assert(image==NULL);
        uint64_t actual=0;OK(ogb3_state_digest(published,&actual,&motion));assert(actual==original);
        OK(ogb3_engine_allocation_stats(&after_engine));OK(ogb3_snapshot_allocation_stats(&after_owned));
        assert(after_engine.live_bytes==before_engine.live_bytes);assert(after_owned.live_bytes==before_owned.live_bytes);
        printf("{\"status\":%d,\"section\":%u,\"record\":%u,\"field\":%u,\"reason\":%u,\"offset\":%llu}\n",
               status,diagnostic.section,diagnostic.record,diagnostic.field,diagnostic.reason,(unsigned long long)diagnostic.offset);
        free(data);
    }
    OK(ogb3_world_destroy(published));ogb3_recovery_catalog_release(catalog);
    ogb3_allocation_stats engine,owned;OK(ogb3_engine_allocation_stats(&engine));OK(ogb3_snapshot_allocation_stats(&owned));
    assert(engine.live_bytes==0&&owned.live_bytes==0);return 0;
}
