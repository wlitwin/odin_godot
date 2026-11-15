#include "authoring_catalog.h"
#include "api_internal.h"
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#if UINTPTR_MAX == UINT64_MAX
_Static_assert(sizeof(ogb3_recovery_asset_v2) == 72 &&
               _Alignof(ogb3_recovery_asset_v2) == 8 &&
               offsetof(ogb3_recovery_asset_v2, vertices) == 48 &&
               offsetof(ogb3_recovery_asset_v2, indices) == 56 &&
               offsetof(ogb3_recovery_asset_v2, vertex_count) == 64,
               "authoring asset v2 foreign layout");
#endif

ogb3_status ogb3_authoring_asset_layout(uint32_t field, uint32_t *size,
                                       uint32_t *alignment, uint32_t *offset) {
  static const uint32_t offsets[] = {
      offsetof(ogb3_recovery_asset_v2, version),
      offsetof(ogb3_recovery_asset_v2, struct_bytes),
      offsetof(ogb3_recovery_asset_v2, base),
      offsetof(ogb3_recovery_asset_v2, vertices),
      offsetof(ogb3_recovery_asset_v2, indices),
      offsetof(ogb3_recovery_asset_v2, vertex_count),
      offsetof(ogb3_recovery_asset_v2, triangle_count)};
  if (!size || !alignment || !offset || field >= sizeof(offsets)/sizeof(offsets[0]))
    return OGB3_INVALID_ARGUMENT;
  *size = sizeof(ogb3_recovery_asset_v2);
  *alignment = _Alignof(ogb3_recovery_asset_v2);
  *offset = offsets[field];
  return OGB3_OK;
}

static int point_valid(ogb3_vec3 v) {
  return isfinite(v.x) && isfinite(v.y) && isfinite(v.z) &&
         fabsf(v.x) <= 1e6f && fabsf(v.y) <= 1e6f && fabsf(v.z) <= 1e6f;
}
static void subtract(double out[3], ogb3_vec3 a, ogb3_vec3 b) {
  out[0]=(double)a.x-b.x;out[1]=(double)a.y-b.y;out[2]=(double)a.z-b.z;
}
static void cross(double out[3], const double a[3], const double b[3]) {
  out[0]=a[1]*b[2]-a[2]*b[1];out[1]=a[2]*b[0]-a[0]*b[2];out[2]=a[0]*b[1]-a[1]*b[0];
}
static int nonzero(const double a[3]) { return a[0]!=0 || a[1]!=0 || a[2]!=0; }

/* Validate trusted call data before the engine sees it. Counts/byte products
 * are bounded before any caller array is traversed. Primitive semantics are
 * checked by the unchanged legacy validator in recovery_codec.c. */
ogb3_status ogb3_authoring_asset_validate(const ogb3_recovery_asset_v2 *a,
                                         uint64_t *input_bytes) {
  if (!a || !input_bytes || a->version != OGB3_AUTHORING_ASSET_VERSION ||
      a->struct_bytes != sizeof(*a) || !a->base.id || a->base.reserved)
    return OGB3_INVALID_ARGUMENT;
  *input_bytes=0;
  if (a->base.kind >= OGB3_RECOVERY_BOX && a->base.kind <= OGB3_RECOVERY_CAPSULE)
    return a->vertices || a->indices || a->vertex_count || a->triangle_count ? OGB3_INVALID_ARGUMENT : OGB3_OK;
  if (a->base.kind != OGB3_RECOVERY_HULL && a->base.kind != OGB3_RECOVERY_MESH)
    return OGB3_UNSUPPORTED;
  if (memcmp(&a->base.a, &(ogb3_vec3){0}, sizeof(ogb3_vec3)) ||
      memcmp(&a->base.b, &(ogb3_vec3){0}, sizeof(ogb3_vec3)) || a->base.radius != 0)
    return OGB3_INVALID_ARGUMENT;
  uint64_t bytes=(uint64_t)a->vertex_count*sizeof(ogb3_vec3) +
                 (uint64_t)a->triangle_count*3*sizeof(uint32_t);
  if (bytes > OGB3_AUTHORING_MAX_GEOMETRY_BYTES)
    return OGB3_CAPACITY;
  if (!a->vertices || a->vertex_count < (a->base.kind==OGB3_RECOVERY_HULL ? 4u : 3u))
    return OGB3_INVALID_ARGUMENT;
  if (a->base.kind==OGB3_RECOVERY_HULL &&
      (a->vertex_count>OGB3_AUTHORING_MAX_HULL_POINTS || a->indices || a->triangle_count))
    return OGB3_INVALID_ARGUMENT;
  if (a->base.kind==OGB3_RECOVERY_MESH && (!a->indices || !a->triangle_count))
    return OGB3_INVALID_ARGUMENT;
  for (uint32_t i=0;i<a->vertex_count;i++) if (!point_valid(a->vertices[i])) return OGB3_INVALID_ARGUMENT;
  if (a->base.kind==OGB3_RECOVERY_HULL) {
    double axis[3]={0},normal[3]={0},v[3];
    for (uint32_t i=1;i<a->vertex_count && !nonzero(axis);i++) subtract(axis,a->vertices[i],a->vertices[0]);
    for (uint32_t i=1;i<a->vertex_count && !nonzero(normal);i++) {subtract(v,a->vertices[i],a->vertices[0]);cross(normal,axis,v);}
    int volume=0;
    for (uint32_t i=1;i<a->vertex_count;i++) {subtract(v,a->vertices[i],a->vertices[0]);if (normal[0]*v[0]+normal[1]*v[1]+normal[2]*v[2]!=0) volume=1;}
    if (!volume) return OGB3_INVALID_ARGUMENT;
  } else {
    for (uint32_t i=0;i<a->triangle_count;i++) {
      uint32_t x=a->indices[3*i],y=a->indices[3*i+1],z=a->indices[3*i+2];
      if (x>=a->vertex_count || y>=a->vertex_count || z>=a->vertex_count || x==y || y==z || x==z)
        return OGB3_INVALID_ARGUMENT;
      double ab[3],ac[3],n[3];subtract(ab,a->vertices[y],a->vertices[x]);subtract(ac,a->vertices[z],a->vertices[x]);cross(n,ab,ac);
      if (!nonzero(n)) return OGB3_INVALID_ARGUMENT;
    }
  }
  *input_bytes=bytes;
  return OGB3_OK;
}

ogb3_status ogb3_recovery_catalog_shape(const ogb3_recovery_catalog *catalog,
                                       uint32_t id, ogb3_body body,
                                       const ogb3_shape_def *def, ogb3_shape *out) {
  if (!out) return OGB3_INVALID_ARGUMENT;
  *out=0;
  if (!catalog || !def) return OGB3_INVALID_ARGUMENT;
  ogb3_catalog_asset_view a;
  ogb3_status status=ogb3_catalog_asset_lookup(catalog,id,&a);
  if (status) return status;
  switch (a.kind) {
  case OGB3_RECOVERY_BOX:return ogb3_shape_box(body,def,&a.a,out);
  case OGB3_RECOVERY_SPHERE:return ogb3_shape_sphere(body,def,&a.a,a.radius,out);
  case OGB3_RECOVERY_CAPSULE:return ogb3_shape_capsule(body,def,&a.a,&a.b,a.radius,out);
  case OGB3_RECOVERY_HULL:
  case OGB3_RECOVERY_MESH:return ogb3_shape_geometry(body,def,a.geometry,out);
  default:return OGB3_UNSUPPORTED;
  }
}
