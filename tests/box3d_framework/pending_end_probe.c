#include "api.h"
#include "owned_snapshot.h"
#include <assert.h>
#include <stdio.h>

#define OK(call) assert((call) == OGB3_OK)

static unsigned ends(ogb3_world world) {
    ogb3_sensor_event events[8];
    uint32_t count = 0, result = 0;
    OK(ogb3_world_sensor_events(world, events, 8, &count));
    for (uint32_t i = 0; i < count; ++i)
        result += events[i].began == 0;
    return result;
}

int main(void) {
    ogb3_world_def wd;
    OK(ogb3_world_def_default(&wd));
    wd.gravity = (ogb3_vec3){0};
    ogb3_world source, restored;
    OK(ogb3_world_create(&wd, &source));
    ogb3_body_def bd;
    OK(ogb3_body_def_default(&bd));
    ogb3_body sensor, visitor;
    OK(ogb3_body_create(source, &bd, &sensor));
    ogb3_shape_def sd;
    OK(ogb3_shape_def_default(&sd));
    sd.is_sensor = sd.enable_sensor_events = 1;
    ogb3_shape shape;
    OK(ogb3_shape_box(sensor, &sd, &(ogb3_vec3){1, 1, 1}, &shape));
    bd.type = OGB3_DYNAMIC;
    OK(ogb3_body_create(source, &bd, &visitor));
    sd.is_sensor = 0;
    OK(ogb3_shape_sphere(visitor, &sd, &(ogb3_vec3){0}, .25f, &shape));
    OK(ogb3_world_step_fixed(source));
    // This is the same ordering as a native mutation in a post-step network action.
    OK(ogb3_body_destroy(sensor));
    ogb3_snapshot *checkpoint;
    OK(ogb3_snapshot_capture(source, &checkpoint));
    OK(ogb3_world_create(&wd, &restored));
    OK(ogb3_snapshot_restore(restored, checkpoint));
    OK(ogb3_world_step_fixed(source));
    OK(ogb3_world_step_fixed(restored));
    unsigned expected = ends(source), actual = ends(restored);
    printf("pending_sensor_end baseline=%u restored=%u\n", expected, actual);
    OK(ogb3_world_step_fixed(source));
    OK(ogb3_world_step_fixed(restored));
    unsigned expected_next = ends(source), actual_next = ends(restored);
    printf("following_step baseline=%u restored=%u\n", expected_next, actual_next);
    OK(ogb3_world_destroy(source));
    OK(ogb3_world_destroy(restored));
    ogb3_snapshot_release(checkpoint);
    return expected == 1 && actual == 1 && expected_next == 0 && actual_next == 0 ? 0 : 1;
}
