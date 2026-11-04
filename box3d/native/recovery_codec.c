#include "native_observe_internal.h"
/* Canonical solver field codec for pinned Box3D 33626332. No framework state.
 * Wire values become bounded owned DTO fields; only verified DTOs can build
 * native execution. Native allocation OOM retains the documented fatal
 * boundary. */
#include "recovery_codec.h"
#include "authoring_catalog.h"
#include "api_internal.h"
#include "owned_snapshot_internal.h"
#include "motion.h"
#include "body.h"
#include "box3d/box3d.h"
#include "box3d/collision.h"
#include "contact.h"
#include "island.h"
#include "joint.h"
#include "physics_world.h"
#include "recording.h"
#include "sensor.h"
#include "shape.h"
#include "solver_set.h"
#include "state_dump.h"
#include "table.h"
#include "dynamic_tree.h"
#include "world_snapshot.h"
#include <assert.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

void *ogb3_snapshot_internal_alloc(size_t);
void ogb3_snapshot_internal_free(void *);
_Static_assert(sizeof(int) == 4 && INT_MIN == (-2147483647 - 1) &&
                   sizeof(bool) == 1 && sizeof(b3BodyType) == 4 &&
                   sizeof(b3ShapeType) == 4 && sizeof(b3JointType) == 4,
               "fixed canonical scalar widths");
_Static_assert(sizeof(float) == 4 && FLT_RADIX == 2 && FLT_MANT_DIG == 24 &&
                   FLT_MAX_EXP == 128,
               "binary32 codec");
#define WIRE_HEADER 192u
#define SECTIONS 12u
#define BUDGET (64ull * 1024 * 1024)
/* Recovery-only staging headroom; tracked requested bytes still checked per
 * DTO/native allocation and before returning an owned image. */
#define RECOVERY_NATIVE_RESERVE (4ull * 1024 * 1024)
/* Pinned mesh_contact.c query buffer, not a caller-adjustable quality bound. */
#define MESH_CONTACT_TRIANGLES 256u
#ifndef OGB3_RECOVERY_BUILD_ID
#define OGB3_RECOVERY_BUILD_ID "manual-build-not-admitted"
#endif
/* SHA256 implementation, fixed-word arithmetic, no external runtime. */
typedef struct {
  uint32_t h[8];
  uint64_t bytes;
  uint8_t block[64];
  uint32_t used;
} Hash;
static uint32_t rotr(uint32_t x, unsigned n) {
  return (x >> n) | (x << (32 - n));
}
static const uint32_t hk[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu,
    0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u, 0xd807aa98u, 0x12835b01u,
    0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u,
    0xc19bf174u, 0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
    0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau, 0x983e5152u,
    0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u,
    0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu,
    0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u,
    0xd6990624u, 0xf40e3585u, 0x106aa070u, 0x19a4c116u, 0x1e376c08u,
    0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu,
    0x682e6ff3u, 0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
    0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u};
static const uint32_t initial_hash[8] = {0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u,
                                         0xa54ff53au, 0x510e527fu, 0x9b05688cu,
                                         0x1f83d9abu, 0x5be0cd19u};
static void hash_block(Hash *s, const uint8_t *p) {
  uint32_t w[64];
  for (unsigned i = 0; i < 16; i++)
    w[i] = (uint32_t)p[4 * i] << 24 | (uint32_t)p[4 * i + 1] << 16 |
           (uint32_t)p[4 * i + 2] << 8 | p[4 * i + 3];
  for (unsigned i = 16; i < 64; i++) {
    uint32_t a = w[i - 15], b = w[i - 2];
    w[i] = w[i - 16] + (rotr(a, 7) ^ rotr(a, 18) ^ (a >> 3)) + w[i - 7] +
           (rotr(b, 17) ^ rotr(b, 19) ^ (b >> 10));
  }
  uint32_t a = s->h[0], b = s->h[1], c = s->h[2], d = s->h[3], e = s->h[4],
           f = s->h[5], g = s->h[6], h = s->h[7];
  for (unsigned i = 0; i < 64; i++) {
    uint32_t t = h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) +
                 ((e & f) ^ (~e & g)) + hk[i] + w[i],
             u = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) +
                 ((a & b) ^ (a & c) ^ (b & c));
    h = g;
    g = f;
    f = e;
    e = d + t;
    d = c;
    c = b;
    b = a;
    a = t + u;
  }
  s->h[0] += a;
  s->h[1] += b;
  s->h[2] += c;
  s->h[3] += d;
  s->h[4] += e;
  s->h[5] += f;
  s->h[6] += g;
  s->h[7] += h;
}
static void hash_init(Hash *s) {
  memset(s, 0, sizeof(*s));
  memcpy(s->h, initial_hash, sizeof(s->h));
}
static void hash_add(Hash *s, const void *data, size_t size) {
  const uint8_t *p = data;
  s->bytes += size;
  while (size) {
    size_t n = 64 - s->used;
    if (n > size)
      n = size;
    memcpy(s->block + s->used, p, n);
    s->used += (uint32_t)n;
    p += n;
    size -= n;
    if (s->used == 64) {
      hash_block(s, s->block);
      s->used = 0;
    }
  }
}
static void hash_finish(Hash *s, uint8_t out[32]) {
  uint64_t bits = s->bytes * 8;
  uint8_t tail[128] = {0x80};
  size_t n = s->used < 56 ? 56 - s->used : 120 - s->used;
  hash_add(s, tail, n);
  for (unsigned i = 0; i < 8; i++)
    tail[i] = (uint8_t)(bits >> (56 - 8 * i));
  hash_add(s, tail, 8);
  for (unsigned i = 0; i < 8; i++)
    for (unsigned j = 0; j < 4; j++)
      out[4 * i + j] = (uint8_t)(s->h[i] >> (24 - 8 * j));
}
static void digest(const void *p, size_t n, uint8_t out[32]) {
  Hash h;
  hash_init(&h);
  hash_add(&h, p, n);
  hash_finish(&h, out);
}
static uint64_t load_le(const uint8_t *p, unsigned n) {
  uint64_t x = 0;
  for (unsigned i = 0; i < n; i++)
    x |= (uint64_t)p[i] << (8 * i);
  return x;
}
static void store_le(uint8_t *p, uint64_t x, unsigned n) {
  for (unsigned i = 0; i < n; i++)
    p[i] = (uint8_t)(x >> (8 * i));
}
static int zero_bytes(const void *p, size_t n) {
  const uint8_t *b = p;
  for (size_t i = 0; i < n; i++)
    if (b[i])
      return 0;
  return 1;
}

typedef struct {
  ogb3_recovery_asset desc;
  b3BoxHull box;
  ogb3_geometry *geometry;
  ogb3_vec3 *vertices;
  uint32_t *indices;
  uint32_t vertex_count, triangle_count;
} Asset;
struct ogb3_recovery_catalog {
  uint32_t refs, count;
  ogb3_recovery_config limits;
  ogb3_recovery_identity identity;
  uint64_t fingerprint, target;
  Asset assets[OGB3_RECOVERY_MAX_ASSETS];
};
typedef union Block Block;
union Block {
  struct {
    Block *next;
  } link;
  max_align_t alignment;
};
typedef struct Codec {
  const ogb3_recovery_catalog *catalog;
  uint8_t *data;
  uint64_t size, pos, allocated, external, section_end;
  int reading;
  ogb3_status status;
  Block *blocks;
  uint32_t section, record, field;
  ogb3_recovery_diagnostic *diagnostic;
} Codec;
static void reject(Codec *c, ogb3_status status, uint32_t reason) {
  if (c->status)
    return;
  c->status = status;
  if (c->diagnostic)
    *c->diagnostic = (ogb3_recovery_diagnostic){c->pos, c->section, c->record,
                                                c->field, reason};
}
static int memory_admit(uint64_t extra, uint64_t reserve) {
  ogb3_allocation_stats e, w;
  if (ogb3_engine_allocation_stats(&e) || ogb3_snapshot_allocation_stats(&w))
    return 0;
  if (e.live_bytes > BUDGET || w.live_bytes > BUDGET - e.live_bytes)
    return 0;
  uint64_t used = e.live_bytes + w.live_bytes;
  if (extra > BUDGET - used)
    return 0;
  return reserve <= BUDGET - used - extra;
}
static void *dto_alloc(Codec *c, size_t n) {
  if (c->status || !n)
    return NULL;
  if (n > c->catalog->limits.max_dto_bytes ||
      c->allocated > c->catalog->limits.max_dto_bytes - n ||
      sizeof(Block) > c->catalog->limits.max_dto_bytes - c->allocated - n ||
      !memory_admit(c->external, n + sizeof(Block))) {
    reject(c, OGB3_CAPACITY, 1);
    return NULL;
  }
  Block *b = ogb3_snapshot_internal_alloc(sizeof(*b) + n);
  if (!b) {
    reject(c, OGB3_OUT_OF_MEMORY, 2);
    return NULL;
  }
  b->link.next = c->blocks;
  c->blocks = b;
  c->allocated += sizeof(*b) + n;
  memset(b + 1, 0, n);
  return b + 1;
}
static void dto_free(Codec *c) {
  while (c->blocks) {
    Block *b = c->blocks;
    c->blocks = b->link.next;
    ogb3_snapshot_internal_free(b);
  }
}
static void scalar(Codec *c, void *p, unsigned n, int kind) {
  if (c->status)
    return;
  c->field++;
  if (c->reading) {
    if (c->pos > c->size || n > c->size - c->pos ||
        (c->section_end &&
         (c->pos > c->section_end || n > c->section_end - c->pos))) {
      reject(c, OGB3_CORRUPT, 3);
      return;
    }
    uint64_t v = load_le(c->data + c->pos, n);
    if (n == 8)
      memcpy(p, &v, 8);
    else if (n == 4) {
      uint32_t x = (uint32_t)v;
      memcpy(p, &x, 4);
    } else if (n == 2) {
      uint16_t x = (uint16_t)v;
      memcpy(p, &x, 2);
    } else {
      uint8_t x = (uint8_t)v;
      memcpy(p, &x, 1);
    }
  } else if (c->data && c->pos + n <= c->size) {
    uint64_t v = 0;
    if (n == 8)
      memcpy(&v, p, 8);
    else if (n == 4) {
      uint32_t x;
      memcpy(&x, p, 4);
      v = x;
    } else if (n == 2) {
      uint16_t x;
      memcpy(&x, p, 2);
      v = x;
    } else
      v = *(uint8_t *)p;
    store_le(c->data + c->pos, v, n);
  }
  if (c->pos > UINT64_MAX - n) {
    reject(c, OGB3_CAPACITY, 4);
    return;
  }
  c->pos += n;
  if (kind == 1 || kind == 3 || kind == 4) {
    float x;
    memcpy(&x, p, 4);
    if (!isfinite(x) || (kind == 1 && fabsf(x) > 1e12f) ||
        (kind == 3 && fabsf(x) > 1e12f && fabsf(x) != FLT_MAX) ||
        (kind == 4 && (x < 0 || (x > 1e12f && x != FLT_MAX))))
      reject(c, OGB3_CORRUPT, 5);
  }
  if (kind == 2 && *(uint8_t *)p > 1)
    reject(c, OGB3_CORRUPT, 6);
}
#define F(c, x)                                                                \
  scalar(c, &(x), sizeof(x), _Generic((x), float: 1, _Bool: 2, default: 0))
static void u32(Codec *c, uint32_t *x) { scalar(c, x, 4, 0); }
static void s32(Codec *c, int *x) {
  _Static_assert(sizeof(int) == 4, "index width");
  scalar(c, x, 4, 0);
}
static void u64(Codec *c, uint64_t *x) { scalar(c, x, 8, 0); }
static uint32_t count(Codec *c, uint32_t value, uint32_t max) {
  u32(c, &value);
  if (value > max)
    reject(c, OGB3_CAPACITY, 7);
  return value;
}
/* BEGIN CODEC SCALAR FIELDS */
static void f_b3Body(Codec* d, b3Body* v) {
    F(d, v->setIndex);
    F(d, v->localIndex);
    F(d, v->headContactKey);
    F(d, v->contactCount);
    F(d, v->headShapeId);
    F(d, v->shapeCount);
    F(d, v->headChainId);
    F(d, v->headJointKey);
    F(d, v->jointCount);
    F(d, v->islandId);
    F(d, v->islandIndex);
    F(d, v->sleepThreshold);
    F(d, v->sleepTime);
    F(d, v->sleepVelocity);
    F(d, v->safetyFactor);
    F(d, v->mass);
    F(d, v->flags);
    F(d, v->type);
}
static void f_b3Vec3(Codec* d, b3Vec3* v) {
    F(d, v->x);
    F(d, v->y);
    F(d, v->z);
}
static void f_b3Quat(Codec* d, b3Quat* v) {
    f_b3Vec3(d, &v->v);
    F(d, v->s);
}
static void f_b3WorldTransform(Codec* d, b3WorldTransform* v) {
    f_b3Vec3(d, &v->p);
    f_b3Quat(d, &v->q);
}
static void f_b3Pos(Codec* d, b3Pos* v) {
    F(d, v->x);
    F(d, v->y);
    F(d, v->z);
}
static void f_b3Matrix3(Codec* d, b3Matrix3* v) {
    f_b3Vec3(d, &v->cx);
    f_b3Vec3(d, &v->cy);
    f_b3Vec3(d, &v->cz);
}
static void f_b3BodySim(Codec* d, b3BodySim* v) {
    f_b3WorldTransform(d, &v->transform);
    f_b3Pos(d, &v->center);
    F(d, v->flags);
    scalar(d,&v->minExtent,4,3);
    f_b3Vec3(d, &v->maxExtent);
    f_b3Quat(d, &v->rotation0);
    f_b3Pos(d, &v->center0);
    f_b3Vec3(d, &v->localCenter);
    f_b3Vec3(d, &v->force);
    f_b3Vec3(d, &v->torque);
    F(d, v->invMass);
    f_b3Matrix3(d, &v->inertia);
    f_b3Matrix3(d, &v->invInertiaLocal);
    f_b3Matrix3(d, &v->invInertiaWorld);
    F(d, v->linearDamping);
    F(d, v->angularDamping);
    F(d, v->gravityScale);
    F(d, v->bodyId);
}
static void f_b3BodyState(Codec* d, b3BodyState* v) {
    f_b3Vec3(d, &v->linearVelocity);
    f_b3Vec3(d, &v->angularVelocity);
    f_b3Vec3(d, &v->deltaPosition);
    F(d, v->flags);
    f_b3Quat(d, &v->deltaRotation);
}
static void f_b3JointEdge(Codec* d, b3JointEdge* v) {
    F(d, v->bodyId);
    F(d, v->prevKey);
    F(d, v->nextKey);
}
static void f_b3Joint(Codec* d, b3Joint* v) {
    F(d, v->setIndex);
    F(d, v->colorIndex);
    F(d, v->localIndex);
    f_b3JointEdge(d, &v->edges[0]);
    f_b3JointEdge(d, &v->edges[1]);
    F(d, v->islandId);
    F(d, v->islandIndex);
    F(d, v->type);
    F(d, v->collideConnected);
}
static void f_b3Transform(Codec* d, b3Transform* v) {
    f_b3Vec3(d, &v->p);
    f_b3Quat(d, &v->q);
}
static void f_b3Softness(Codec* d, b3Softness* v) {
    F(d, v->biasRate);
    F(d, v->massScale);
    F(d, v->impulseScale);
}
static void f_b3JointSim_base(Codec* d, b3JointSim* v) {
    F(d, v->jointId);
    F(d, v->bodyIdA);
    F(d, v->bodyIdB);
    F(d, v->type);
    f_b3Transform(d, &v->localFrameA);
    f_b3Transform(d, &v->localFrameB);
    F(d, v->invMassA);
    F(d, v->invMassB);
    f_b3Matrix3(d, &v->invIA);
    f_b3Matrix3(d, &v->invIB);
    F(d, v->constraintHertz);
    F(d, v->constraintDampingRatio);
    f_b3Softness(d, &v->constraintSoftness);
    scalar(d,&v->forceThreshold,4,4);
    scalar(d,&v->torqueThreshold,4,4);
    F(d, v->fixedRotation);
}
static void f_b3Vec2(Codec* d, b3Vec2* v) {
    F(d, v->x);
    F(d, v->y);
}
static void f_b3RevoluteJoint(Codec* d, b3RevoluteJoint* v) {
    f_b3Vec3(d, &v->linearImpulse);
    f_b3Vec2(d, &v->perpImpulse);
    F(d, v->springImpulse);
    F(d, v->motorImpulse);
    F(d, v->lowerImpulse);
    F(d, v->upperImpulse);
    F(d, v->hertz);
    F(d, v->dampingRatio);
    scalar(d,&v->maxMotorTorque,4,d->catalog->identity.recovery_format>=3?4:1);
    F(d, v->motorSpeed);
    F(d, v->targetAngle);
    F(d, v->lowerAngle);
    F(d, v->upperAngle);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->rotationAxisZ);
    f_b3Vec3(d, &v->perpAxisX);
    f_b3Vec3(d, &v->perpAxisY);
    f_b3Vec3(d, &v->deltaCenter);
    F(d, v->deltaAngle);
    F(d, v->axialMass);
    f_b3Softness(d, &v->springSoftness);
    F(d, v->enableSpring);
    F(d, v->enableMotor);
    F(d, v->enableLimit);
}
static void f_b3DistanceJoint(Codec* d, b3DistanceJoint* v) {
    F(d, v->length);
    F(d, v->hertz);
    F(d, v->dampingRatio);
    scalar(d,&v->lowerSpringForce,4,3);
    scalar(d,&v->upperSpringForce,4,3);
    F(d, v->minLength);
    F(d, v->maxLength);
    scalar(d,&v->maxMotorForce,4,4);
    F(d, v->motorSpeed);
    F(d, v->impulse);
    F(d, v->lowerImpulse);
    F(d, v->upperImpulse);
    F(d, v->motorImpulse);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Vec3(d, &v->anchorA);
    f_b3Vec3(d, &v->anchorB);
    f_b3Vec3(d, &v->deltaCenter);
    f_b3Softness(d, &v->distanceSoftness);
    F(d, v->axialMass);
    F(d, v->enableSpring);
    F(d, v->enableLimit);
    F(d, v->enableMotor);
}
static void f_b3MotorJoint(Codec* d, b3MotorJoint* v) {
    f_b3Vec3(d, &v->linearVelocity);
    f_b3Vec3(d, &v->angularVelocity);
    scalar(d,&v->maxVelocityForce,4,4);
    scalar(d,&v->maxVelocityTorque,4,4);
    F(d, v->linearHertz);
    F(d, v->linearDampingRatio);
    scalar(d,&v->maxSpringForce,4,4);
    F(d, v->angularHertz);
    F(d, v->angularDampingRatio);
    scalar(d,&v->maxSpringTorque,4,4);
    f_b3Vec3(d, &v->linearVelocityImpulse);
    f_b3Vec3(d, &v->angularVelocityImpulse);
    f_b3Vec3(d, &v->linearSpringImpulse);
    f_b3Vec3(d, &v->angularSpringImpulse);
    f_b3Softness(d, &v->linearSpring);
    f_b3Softness(d, &v->angularSpring);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->deltaCenter);
    f_b3Matrix3(d, &v->angularMass);
}
static void f_b3PrismaticJoint(Codec* d, b3PrismaticJoint* v) {
    f_b3Vec2(d, &v->perpImpulse);
    f_b3Vec3(d, &v->angularImpulse);
    F(d, v->springImpulse);
    F(d, v->motorImpulse);
    F(d, v->lowerImpulse);
    F(d, v->upperImpulse);
    F(d, v->hertz);
    F(d, v->dampingRatio);
    scalar(d,&v->maxMotorForce,4,4);
    F(d, v->motorSpeed);
    F(d, v->targetTranslation);
    F(d, v->lowerTranslation);
    F(d, v->upperTranslation);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->jointAxis);
    f_b3Vec3(d, &v->perpAxisY);
    f_b3Vec3(d, &v->perpAxisZ);
    f_b3Vec3(d, &v->deltaCenter);
    F(d, v->deltaAngle);
    f_b3Matrix3(d, &v->rotationMass);
    f_b3Softness(d, &v->springSoftness);
    F(d, v->enableSpring);
    F(d, v->enableLimit);
    F(d, v->enableMotor);
}
static void f_b3SphericalJoint(Codec* d, b3SphericalJoint* v) {
    f_b3Vec3(d, &v->linearImpulse);
    f_b3Vec3(d, &v->springImpulse);
    f_b3Vec3(d, &v->motorImpulse);
    F(d, v->lowerTwistImpulse);
    F(d, v->upperTwistImpulse);
    F(d, v->swingImpulse);
    F(d, v->hertz);
    F(d, v->dampingRatio);
    scalar(d,&v->maxMotorTorque,4,4);
    f_b3Vec3(d, &v->motorVelocity);
    F(d, v->lowerTwistAngle);
    F(d, v->upperTwistAngle);
    F(d, v->coneAngle);
    f_b3Quat(d, &v->targetRotation);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->deltaCenter);
    f_b3Vec3(d, &v->swingAxis);
    f_b3Vec3(d, &v->twistJacobian);
    f_b3Matrix3(d, &v->rotationMass);
    F(d, v->swingMass);
    F(d, v->twistMass);
    f_b3Softness(d, &v->springSoftness);
    F(d, v->enableSpring);
    F(d, v->enableMotor);
    F(d, v->enableConeLimit);
    F(d, v->enableTwistLimit);
}
static void f_b3WeldJoint(Codec* d, b3WeldJoint* v) {
    F(d, v->linearHertz);
    F(d, v->linearDampingRatio);
    F(d, v->angularHertz);
    F(d, v->angularDampingRatio);
    f_b3Softness(d, &v->linearSpring);
    f_b3Softness(d, &v->angularSpring);
    f_b3Vec3(d, &v->linearImpulse);
    f_b3Vec3(d, &v->angularImpulse);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->deltaCenter);
    f_b3Matrix3(d, &v->angularMass);
}
static void f_b3WheelJoint(Codec* d, b3WheelJoint* v) {
    f_b3Vec2(d, &v->linearImpulse);
    f_b3Vec2(d, &v->angularImpulse);
    F(d, v->spinImpulse);
    scalar(d,&v->maxSpinTorque,4,4);
    F(d, v->spinSpeed);
    F(d, v->suspensionSpringImpulse);
    F(d, v->lowerSuspensionImpulse);
    F(d, v->upperSuspensionImpulse);
    F(d, v->lowerSuspensionLimit);
    F(d, v->upperSuspensionLimit);
    F(d, v->suspensionHertz);
    F(d, v->suspensionDampingRatio);
    F(d, v->steeringSpringImpulse);
    F(d, v->lowerSteeringImpulse);
    F(d, v->upperSteeringImpulse);
    F(d, v->lowerSteeringLimit);
    F(d, v->upperSteeringLimit);
    F(d, v->targetSteeringAngle);
    scalar(d,&v->maxSteeringTorque,4,4);
    F(d, v->steeringHertz);
    F(d, v->steeringDampingRatio);
    F(d, v->indexA);
    F(d, v->indexB);
    f_b3Transform(d, &v->frameA);
    f_b3Transform(d, &v->frameB);
    f_b3Vec3(d, &v->deltaCenter);
    F(d, v->spinMass);
    F(d, v->suspensionMass);
    F(d, v->steeringMass);
    f_b3Softness(d, &v->suspensionSoftness);
    f_b3Softness(d, &v->steeringSoftness);
    F(d, v->enableSpinMotor);
    F(d, v->enableSuspensionSpring);
    F(d, v->enableSuspensionLimit);
    F(d, v->enableSteering);
    F(d, v->enableSteeringLimit);
    F(d, v->enableSteeringMotor);
}
static void f_b3AABB(Codec* d, b3AABB* v) {
    f_b3Vec3(d, &v->lowerBound);
    f_b3Vec3(d, &v->upperBound);
}
static void f_b3Filter(Codec* d, b3Filter* v) {
    F(d, v->categoryBits);
    F(d, v->maskBits);
    F(d, v->groupIndex);
}
static void f_b3Shape_base(Codec* d, b3Shape* v) {
    F(d, v->bodyId);
    F(d, v->prevShapeId);
    F(d, v->nextShapeId);
    F(d, v->sensorIndex);
    F(d, v->proxyKey);
    F(d, v->type);
    F(d, v->density);
    F(d, v->explosionScale);
    F(d, v->aabbMargin);
    f_b3AABB(d, &v->aabb);
    f_b3Vec3(d, &v->localCentroid);
    F(d, v->materialCount);
    f_b3Filter(d, &v->filter);
    F(d, v->flags);
}
static void f_b3ContactEdge(Codec* d, b3ContactEdge* v) {
    F(d, v->bodyId);
    F(d, v->prevKey);
    F(d, v->nextKey);
}
static void f_b3Contact_base(Codec* d, b3Contact* v) {
    F(d, v->setIndex);
    F(d, v->colorIndex);
    F(d, v->localIndex);
    f_b3ContactEdge(d, &v->edges[0]);
    f_b3ContactEdge(d, &v->edges[1]);
    F(d, v->shapeIdA);
    F(d, v->shapeIdB);
    F(d, v->childIndex);
    F(d, v->islandId);
    F(d, v->islandIndex);
    F(d, v->flags);
    f_b3Quat(d, &v->cachedRotationA);
    f_b3Quat(d, &v->cachedRotationB);
    f_b3Transform(d, &v->cachedRelativePose);
    F(d, v->friction);
    F(d, v->restitution);
    F(d, v->rollingResistance);
    f_b3Vec3(d, &v->tangentVelocity);
}
static void f_b3Visitor(Codec* d, b3Visitor* v) {
    F(d, v->shapeId);
    F(d, v->generation);
}
static void f_b3IslandSim(Codec* d, b3IslandSim* v) {
    F(d, v->islandId);
}
static void f_b3ContactSpec(Codec* d, b3ContactSpec* v) {
    F(d, v->contactId);
    F(d, v->manifoldStart);
    F(d, v->manifoldCount);
}
static void f_b3SetItem(Codec* d, b3SetItem* v) {
    F(d, v->key);
    F(d, v->hash);
}
static void f_b3SurfaceMaterial(Codec* d, b3SurfaceMaterial* v) {
    F(d, v->friction);
    F(d, v->restitution);
    F(d, v->rollingResistance);
    f_b3Vec3(d, &v->tangentVelocity);
    F(d, v->userMaterialId);
}
static void f_b3SATCache(Codec* d, b3SATCache* v) {
    scalar(d,&v->separation,4,3);
    F(d, v->type);
    F(d, v->indexA);
    F(d, v->indexB);
}
static void f_b3Capacity(Codec* d, b3Capacity* v) {
    F(d, v->staticShapeCount);
    F(d, v->dynamicShapeCount);
    F(d, v->staticBodyCount);
    F(d, v->dynamicBodyCount);
    F(d, v->contactCount);
}
static void f_b3ContactLink(Codec* d, b3ContactLink* v) {
    F(d, v->contactId);
    F(d, v->bodyIdA);
    F(d, v->bodyIdB);
}
static void f_b3JointLink(Codec* d, b3JointLink* v) {
    F(d, v->jointId);
    F(d, v->bodyIdA);
    F(d, v->bodyIdB);
}
static void f_b3ManifoldPoint(Codec* d, b3ManifoldPoint* v) {
    f_b3Vec3(d, &v->anchorA);
    f_b3Vec3(d, &v->anchorB);
    F(d, v->separation);
    F(d, v->normalImpulse);
    F(d, v->totalNormalImpulse);
    F(d, v->normalVelocity);
    F(d, v->baseSeparation);
    F(d, v->featureId);
    F(d, v->triangleIndex);
    F(d, v->persisted);
}
/* END CODEC SCALAR FIELDS */

static void f_joint(Codec *c, b3JointSim *v) {
  f_b3JointSim_base(c, v);
  if (v->type != b3_revoluteJoint && c->catalog->identity.recovery_format < OGB3_MOTION_RECOVERY_FORMAT) {
    reject(c, c->reading ? OGB3_CORRUPT : OGB3_UNSUPPORTED, 20);
    return;
  }
  switch(v->type) {
  case b3_revoluteJoint:f_b3RevoluteJoint(c,&v->revoluteJoint);break;
  case b3_distanceJoint:f_b3DistanceJoint(c,&v->distanceJoint);break;
  case b3_motorJoint:f_b3MotorJoint(c,&v->motorJoint);break;
  case b3_prismaticJoint:f_b3PrismaticJoint(c,&v->prismaticJoint);break;
  case b3_sphericalJoint:f_b3SphericalJoint(c,&v->sphericalJoint);break;
  case b3_weldJoint:f_b3WeldJoint(c,&v->weldJoint);break;
  case b3_wheelJoint:f_b3WheelJoint(c,&v->wheelJoint);break;
  default:reject(c,c->reading?OGB3_CORRUPT:OGB3_UNSUPPORTED,20);break;
  }
}
static void f_manifold(Codec *c, b3Manifold *v) {
  F(c, v->pointCount);
  if (v->pointCount < 0 || v->pointCount > 4) {
    reject(c, OGB3_CORRUPT, 21);
    return;
  }
  for (int i = 0; i < v->pointCount; i++)
    f_b3ManifoldPoint(c, v->points + i);
  f_b3Vec3(c, &v->normal);
  F(c, v->twistImpulse);
  f_b3Vec3(c, &v->frictionImpulse);
  f_b3Vec3(c, &v->rollingImpulse);
}
static void f_simplex(Codec *c, b3SimplexCache *v) {
  F(c, v->metric);
  F(c, v->count);
  if (v->count > 4) {
    reject(c, OGB3_CORRUPT, 22);
    return;
  }
  for (unsigned i = 0; i < v->count; i++) {
    F(c, v->indexA[i]);
    F(c, v->indexB[i]);
  }
}
static void f_int(Codec *c, int *v) { s32(c, v); }
#define ARRAY(c, a, fn, max)                                                   \
  do {                                                                         \
    uint32_t ac = count(c, (uint32_t)(a).count, max);                          \
    if (c->reading) {                                                          \
      (a).count = (a).capacity = (int)ac;                                      \
      (a).data = dto_alloc(c, (size_t)ac * sizeof(*(a).data));                 \
    }                                                                          \
    for (uint32_t ai = 0; ai < ac && !c->status; ai++) {                       \
      c->record = ai;                                                          \
      fn(c, (a).data + ai);                                                    \
    }                                                                          \
  } while (0)
static void f_bits(Codec *c, b3BitSet *b) {
  uint32_t n =
      count(c, b->blockCount, (c->catalog->limits.max_tree_nodes + 63) / 64);
  if (c->reading) {
    b->blockCount = b->blockCapacity = n;
    b->bits = dto_alloc(c, (size_t)n * 8);
  }
  for (uint32_t i = 0; i < n && !c->status; i++)
    u64(c, b->bits + i);
}
static void f_pool(Codec *c, b3IdPool *p) {
  s32(c, &p->nextIndex);
  if (p->nextIndex < 0 ||
      (uint32_t)p->nextIndex > c->catalog->limits.max_sparse_slots) {
    reject(c, OGB3_CAPACITY, 23);
    return;
  }
  ARRAY(c, p->freeArray, f_int, (uint32_t)p->nextIndex);
}
static void f_tree(Codec *c, b3DynamicTree *t) {
  F(c,t->version); F(c,t->nodeEnd); F(c,t->pairFreeList);
  F(c,t->proxyCount); F(c,t->proxyCapacity); F(c,t->proxyFreeList); F(c,t->dfsOrdered);
  if(t->nodeEnd<2 || (t->nodeEnd&1) ||
     (uint32_t)t->nodeEnd>c->catalog->limits.max_tree_nodes ||
     t->proxyCapacity<1 || (uint32_t)t->proxyCapacity>c->catalog->limits.max_tree_nodes ||
     t->proxyCount<0 || t->proxyCount>t->proxyCapacity){reject(c,OGB3_CAPACITY,24);return;}
  if(c->reading){
    t->nodeCapacity=t->nodeEnd;
    t->nodes=dto_alloc(c,(size_t)t->nodeEnd*sizeof(*t->nodes));
    t->parents=dto_alloc(c,(size_t)t->nodeEnd*sizeof(*t->parents));
    t->proxies=dto_alloc(c,(size_t)t->proxyCapacity*sizeof(*t->proxies));
  }
  for(int i=0;i<t->nodeEnd && !c->status;i++){
    b3TreeNode*n=t->nodes+i;F(c,n->flagIndex);
    if(b3IsEmptyNode(n)){if(c->reading)*n=b3MakeEmptyNode();}
    else{f_b3AABB(c,&n->aabb);F(c,n->height);}
    F(c,t->parents[i]);
  }
  for(int i=0;i<t->proxyCapacity && !c->status;i++){
    b3TreeProxy*p=t->proxies+i;F(c,p->node);
    if(p->node==B3_NULL_INDEX)F(c,p->next);
    else{F(c,p->userData);F(c,p->categoryBits);if(c->reading)p->next=B3_NULL_INDEX;}
  }
}
static int float_equal(float a, float b) {
  uint32_t x, y;
  memcpy(&x, &a, 4);
  memcpy(&y, &b, 4);
  return x == y;
}
static int vec_equal(b3Vec3 a, ogb3_vec3 b) {
  return float_equal(a.x, b.x) && float_equal(a.y, b.y) &&
         float_equal(a.z, b.z);
}
static uint32_t shape_asset(const ogb3_recovery_catalog *p, const b3Shape *s) {
  for (uint32_t i = 0; i < p->count; i++) {
    const Asset *a = p->assets + i;
    if (a->desc.kind == OGB3_RECOVERY_BOX && s->type == b3_hullShape &&
        s->hull->byteCount == (int)sizeof(b3BoxHull) &&
        memcmp(s->hull, &a->box, sizeof(a->box)) == 0)
      return a->desc.id;
    if (a->desc.kind == OGB3_RECOVERY_SPHERE && s->type == b3_sphereShape &&
        vec_equal(s->sphere.center, a->desc.a) &&
        float_equal(s->sphere.radius, a->desc.radius))
      return a->desc.id;
    if (a->desc.kind == OGB3_RECOVERY_CAPSULE && s->type == b3_capsuleShape &&
        vec_equal(s->capsule.center1, a->desc.a) &&
        vec_equal(s->capsule.center2, a->desc.b) &&
        float_equal(s->capsule.radius, a->desc.radius))
      return a->desc.id;
    if (a->desc.kind == OGB3_RECOVERY_HULL && s->type == b3_hullShape &&
        a->geometry && s->hull->byteCount == ((b3HullData *)a->geometry->data)->byteCount &&
        !memcmp(s->hull,a->geometry->data,(size_t)s->hull->byteCount))
      return a->desc.id;
    if (a->desc.kind == OGB3_RECOVERY_MESH && s->type == b3_meshShape &&
        a->geometry && vec_equal(s->mesh.scale,(ogb3_vec3){1,1,1}) &&
        s->mesh.data->byteCount == ((b3MeshData *)a->geometry->data)->byteCount &&
        !memcmp(s->mesh.data,a->geometry->data,(size_t)s->mesh.data->byteCount))
      return a->desc.id;
  }
  return 0;
}
static void bind_asset(Codec *c, b3Shape *s, uint32_t id) {
  const Asset *a = NULL;
  for (uint32_t i = 0; i < c->catalog->count; i++)
    if (c->catalog->assets[i].desc.id == id)
      a = c->catalog->assets + i;
  if (!a) {
    reject(c, OGB3_INCOMPATIBLE, 25);
    return;
  }
  if (a->desc.kind == OGB3_RECOVERY_BOX) {
    if (s->type != b3_hullShape) {
      reject(c, OGB3_CORRUPT, 26);
      return;
    }
    s->hull = &a->box.base;
  } else if (a->desc.kind == OGB3_RECOVERY_SPHERE) {
    if (s->type != b3_sphereShape) {
      reject(c, OGB3_CORRUPT, 26);
      return;
    }
    s->sphere =
        (b3Sphere){{a->desc.a.x, a->desc.a.y, a->desc.a.z}, a->desc.radius};
  } else if (a->desc.kind == OGB3_RECOVERY_CAPSULE) {
    if (s->type != b3_capsuleShape) {
      reject(c, OGB3_CORRUPT, 26);
      return;
    }
    s->capsule = (b3Capsule){{a->desc.a.x, a->desc.a.y, a->desc.a.z},
                             {a->desc.b.x, a->desc.b.y, a->desc.b.z},
                             a->desc.radius};
  } else if (a->desc.kind == OGB3_RECOVERY_HULL) {
    if (s->type != b3_hullShape || !a->geometry) {reject(c,OGB3_CORRUPT,26);return;}
    s->hull = a->geometry->data;
  } else if (a->desc.kind == OGB3_RECOVERY_MESH) {
    if (s->type != b3_meshShape || !a->geometry) {reject(c,OGB3_CORRUPT,26);return;}
    s->mesh.data = a->geometry->data;
    s->mesh.scale = (b3Vec3){1,1,1};
  } else {
    reject(c,OGB3_CORRUPT,26);
  }
}
static void begin_section(Codec *c, uint16_t tag, uint64_t *start,
                          uint64_t *end) {
  c->section_end = 0;
  uint16_t version = 1, received = tag;
  uint32_t records = 1;
  uint64_t bytes = 0;
  *start = c->pos;
  F(c, received);
  F(c, version);
  F(c, records);
  F(c, bytes);
  if (c->reading) {
    if (received != tag || version != 1 || records != 1 ||
        bytes > c->size - c->pos) {
      reject(c, OGB3_CORRUPT, 27);
      return;
    }
    *end = c->pos + bytes;
    c->section_end = *end;
  } else
    *end = 0;
  c->section = tag;
  c->record = c->field = 0;
}
static void finish_section(Codec *c, uint64_t start, uint64_t end) {
  if (c->status)
    return;
  if (c->reading) {
    if (c->pos != end)
      reject(c, OGB3_CORRUPT, 28);
  } else if (c->data)
    store_le(c->data + start + 8, c->pos - start - 16, 8);
  c->section_end = 0;
}
#define SECTION(n) begin_section(c, n, &start, &end)
#define ENDSECTION() finish_section(c, start, end)
static void wire_world(Codec *c, b3World *w) {
  const ogb3_recovery_config *l = &c->catalog->limits;
  uint64_t start, end;
  SECTION(1);
  f_b3Vec3(c, &w->gravity);
  F(c, w->hitEventThreshold);
  F(c, w->restitutionThreshold);
  F(c, w->maxLinearSpeed);
  F(c, w->contactSpeed);
  F(c, w->contactHertz);
  F(c, w->contactDampingRatio);
  F(c, w->contactRecycleDistance);
  F(c, w->restitutionIterations); F(c, w->enableRestitutionPropagation);
  F(c, w->isotropicInertiaTolerance); F(c, w->compoundShapeCount); F(c, w->simdWidth);
  F(c, w->stepIndex);
  F(c, w->splitIslandId);
  F(c, w->inv_h);
  F(c, w->inv_dt);
  F(c, w->endEventArrayIndex);
  f_b3Capacity(c, &w->maxCapacity);
  F(c, w->enableSleep);
  F(c, w->enableWarmStarting);
  F(c, w->enableContinuous);
  F(c, w->enableSpeculative);
  ENDSECTION();
  SECTION(2);
  b3IdPool *pools[] = {&w->bodyIdPool,  &w->shapeIdPool,  &w->contactIdPool,
                       &w->jointIdPool, &w->islandIdPool, &w->solverSetIdPool};
  for (unsigned i = 0; i < 6 && !c->status; i++)
    f_pool(c, pools[i]);
  ENDSECTION();
  SECTION(3);
  uint32_t sets = count(c, (uint32_t)w->solverSets.count, l->max_sparse_slots);
  if (c->reading) {
    w->solverSets.count = w->solverSets.capacity = (int)sets;
    w->solverSets.data =
        dto_alloc(c, (size_t)sets * sizeof(*w->solverSets.data));
  }
  for (uint32_t i = 0; i < sets && !c->status; i++) {
    b3SolverSet *s = w->solverSets.data + i;
    F(c, s->setIndex);
    ARRAY(c, s->bodySims, f_b3BodySim, l->max_bodies);
    ARRAY(c, s->bodyStates, f_b3BodyState, l->max_bodies);
    ARRAY(c, s->jointSims, f_joint, l->max_joints);
    ARRAY(c, s->contactIndices, f_int, l->max_contacts);
    ARRAY(c, s->islandSims, f_b3IslandSim, l->max_bodies);
  }
  ENDSECTION();
  SECTION(4);
  uint32_t bodies = count(c, (uint32_t)w->bodies.count, l->max_sparse_slots);
  if (c->reading) {
    w->bodies.count = w->bodies.capacity = (int)bodies;
    w->bodies.data = dto_alloc(c, (size_t)bodies * sizeof(*w->bodies.data));
  }
  for (uint32_t i = 0; i < bodies && !c->status; i++) {
    b3Body *b = w->bodies.data + i;
    uint8_t live = b->id == (int)i;
    F(c, live);
    if (live > 1) {
      reject(c, OGB3_CORRUPT, 36);
      return;
    }
    F(c, b->generation);
    if (c->reading) {
      b->id = live ? (int)i : -1;
      b->bodyMoveIndex = -1;
    }
    if (live)
      f_b3Body(c, b);
  }
  ENDSECTION();
  SECTION(5);
  uint32_t shapes = count(c, (uint32_t)w->shapes.count, l->max_sparse_slots);
  if (c->reading) {
    w->shapes.count = w->shapes.capacity = (int)shapes;
    w->shapes.data = dto_alloc(c, (size_t)shapes * sizeof(*w->shapes.data));
    w->fatAABBs.count=w->fatAABBs.capacity=(int)shapes;
    w->fatAABBs.data=dto_alloc(c,(size_t)shapes*sizeof(*w->fatAABBs.data));
  }
  for (uint32_t i = 0; i < shapes && !c->status; i++) {
    b3Shape *s = w->shapes.data + i;
    uint8_t live = s->id == (int)i;
    F(c, live);
    if (live > 1) {
      reject(c, OGB3_CORRUPT, 36);
      return;
    }
    F(c, s->generation);
    if (c->reading)
      s->id = live ? (int)i : -1;
    if (!live)
      continue;
    f_b3Shape_base(c, s);
    f_b3AABB(c,w->fatAABBs.data+i);
    if (s->materialCount != 1 || s->materials) {
      reject(c, c->reading ? OGB3_CORRUPT : OGB3_UNSUPPORTED, 29);
      break;
    }
    f_b3SurfaceMaterial(c, &s->material);
    uint32_t asset = c->reading ? 0 : shape_asset(c->catalog, s);
    u32(c, &asset);
    if (!c->reading && !asset) {
      reject(c, OGB3_UNSUPPORTED, 30);
      break;
    }
    if (c->reading)
      bind_asset(c, s, asset);
  }
  ENDSECTION();
  SECTION(6);
  uint32_t contacts =
      count(c, (uint32_t)w->contacts.count, l->max_sparse_slots);
  if (c->reading) {
    w->contacts.count = w->contacts.capacity = (int)contacts;
    w->contacts.data =
        dto_alloc(c, (size_t)contacts * sizeof(*w->contacts.data));
  }
  for (uint32_t i = 0; i < contacts && !c->status; i++) {
    b3Contact *v = w->contacts.data + i;
    uint8_t live = v->contactId == (int)i;
    F(c, live);
    if (live > 1) {
      reject(c, OGB3_CORRUPT, 36);
      return;
    }
    F(c, v->generation);
    if (c->reading) {
      v->contactId = live ? (int)i : -1;
      v->encodedBodySimA = v->encodedBodySimB = -1;
    }
    if (!live)
      continue;
    f_b3Contact_base(c, v);
    int mesh = (v->flags & b3_simMeshContact) != 0;
    if (mesh && c->catalog->identity.recovery_format < OGB3_AUTHORING_RECOVERY_FORMAT) {
      reject(c, c->reading ? OGB3_CORRUPT : OGB3_UNSUPPORTED, 31);
      break;
    }
    uint32_t m = count(c, (uint32_t)v->manifoldCount, mesh ? l->max_manifolds : 1);
    if (c->reading) {
      v->manifoldCount = (int)m;
      v->manifolds = dto_alloc(c, (size_t)m * sizeof(*v->manifolds));
    }
    for (unsigned j = 0; j < m && !c->status; j++)
      f_manifold(c, v->manifolds + j);
    if (v->shapeIdA < 0 || v->shapeIdB < 0 || v->shapeIdA >= w->shapes.count ||
        v->shapeIdB >= w->shapes.count) {
      reject(c, OGB3_CORRUPT, 32);
      break;
    }
    b3Shape *a = w->shapes.data + v->shapeIdA,
            *b = w->shapes.data + v->shapeIdB;
    if (mesh) {
      if (a->type != b3_meshShape ||
          (b->type != b3_hullShape && b->type != b3_sphereShape && b->type != b3_capsuleShape)) {
        reject(c, OGB3_CORRUPT, 31);
        break;
      }
      f_b3AABB(c, &v->meshContact.queryBounds);
      uint32_t n = count(c, (uint32_t)v->meshContact.triangleCache.count, MESH_CONTACT_TRIANGLES);
      if (c->reading) {
        v->meshContact.triangleCache.count = v->meshContact.triangleCache.capacity = (int)n;
        v->meshContact.triangleCache.data = dto_alloc(c, (size_t)n * sizeof(b3TriangleCache));
      }
      for (uint32_t j = 0; j < n && !c->status; j++) {
        b3TriangleCache *t = v->meshContact.triangleCache.data + j;
        F(c, t->triangleIndex);
        if (b->type == b3_hullShape) f_b3SATCache(c, &t->cache.satCache);
        else f_simplex(c, &t->cache.simplexCache);
      }
    } else if (a->type == b3_hullShape && b->type == b3_hullShape)
      f_b3SATCache(c, &v->convexContact.cache.satCache);
    else
      f_simplex(c, &v->convexContact.cache.simplexCache);
  }
  ENDSECTION();
  SECTION(7);
  uint32_t joints = count(c, (uint32_t)w->joints.count, l->max_sparse_slots);
  if (c->reading) {
    w->joints.count = w->joints.capacity = (int)joints;
    w->joints.data = dto_alloc(c, (size_t)joints * sizeof(*w->joints.data));
  }
  for (uint32_t i = 0; i < joints && !c->status; i++) {
    b3Joint *v = w->joints.data + i;
    uint8_t live = v->jointId == (int)i;
    F(c, live);
    if (live > 1) {
      reject(c, OGB3_CORRUPT, 36);
      return;
    }
    F(c, v->generation);
    if (c->reading)
      v->jointId = live ? (int)i : -1;
    if (live)
      f_b3Joint(c, v);
  }
  ENDSECTION();
  SECTION(8);
  uint32_t sensors = count(c, (uint32_t)w->sensors.count, l->max_sensors);
  if (c->reading) {
    w->sensors.count = w->sensors.capacity = (int)sensors;
    w->sensors.data = dto_alloc(c, (size_t)sensors * sizeof(*w->sensors.data));
  }
  for (uint32_t i = 0; i < sensors && !c->status; i++) {
    b3Sensor *v = w->sensors.data + i;
    F(c, v->shapeId);
    ARRAY(c, v->hits, f_b3Visitor, l->max_visitors);
    ARRAY(c, v->overlaps1, f_b3Visitor, l->max_visitors);
    ARRAY(c, v->overlaps2, f_b3Visitor, l->max_visitors);
  }
  ENDSECTION();
  SECTION(9);
  uint32_t islands = count(c, (uint32_t)w->islands.count, l->max_sparse_slots);
  if (c->reading) {
    w->islands.count = w->islands.capacity = (int)islands;
    w->islands.data = dto_alloc(c, (size_t)islands * sizeof(*w->islands.data));
  }
  for (uint32_t i = 0; i < islands && !c->status; i++) {
    b3Island *v = w->islands.data + i;
    F(c, v->setIndex);
    F(c, v->localIndex);
    F(c, v->islandId);
    F(c, v->constraintRemoveCount);
    ARRAY(c, v->bodies, f_int, l->max_bodies);
    ARRAY(c, v->contacts, f_b3ContactLink, l->max_contacts);
    ARRAY(c, v->joints, f_b3JointLink, l->max_joints);
  }
  ENDSECTION();
  SECTION(10);
  for (int i = 0; i < 3 && !c->status; i++)
    f_tree(c, w->broadPhase.trees + i);
  b3HashSet *hs = &w->broadPhase.pairSet;
  u32(c, &hs->capacity);
  u32(c, &hs->count);
  if (hs->capacity > l->max_sparse_slots * 8u) {
    reject(c, OGB3_CAPACITY, 33);
    return;
  }
  if (c->reading)
    hs->items = dto_alloc(c, (size_t)hs->capacity * sizeof(*hs->items));
  for (uint32_t i = 0; i < hs->capacity && !c->status; i++)
    f_b3SetItem(c, hs->items + i);
  ENDSECTION();
  SECTION(11);
  for (int i = 0; i < B3_GRAPH_COLOR_COUNT && !c->status; i++) {
    b3GraphColor *v = w->constraintGraph.colors + i;
    if (i != B3_OVERFLOW_INDEX)
      f_bits(c, &v->bodySet);
    ARRAY(c, v->jointSims, f_joint, l->max_joints);
    ARRAY(c, v->convexContacts, f_int, l->max_contacts);
    ARRAY(c, v->contacts, f_b3ContactSpec, l->max_contacts);
  }
  ENDSECTION();
  SECTION(12);
  if (w->endEventArrayIndex < 0 || w->endEventArrayIndex > 1) {
    reject(c, OGB3_CORRUPT, 34);
    return;
  }
  int idx = w->endEventArrayIndex;
  uint32_t se =
      count(c, (uint32_t)w->sensorEndEvents[idx].count, l->max_pending_sensors);
  if (c->reading) {
    w->sensorEndEvents[idx].count = w->sensorEndEvents[idx].capacity = (int)se;
    w->sensorEndEvents[idx].data =
        dto_alloc(c, (size_t)se * sizeof(b3SensorEndTouchEvent));
  }
  for (uint32_t i = 0; i < se && !c->status; i++) {
    b3SensorEndTouchEvent *e = w->sensorEndEvents[idx].data + i;
    uint64_t a = (uint32_t)e->sensorShapeId.index1 |
                 ((uint64_t)e->sensorShapeId.generation << 32),
             b = (uint32_t)e->visitorShapeId.index1 |
                 ((uint64_t)e->visitorShapeId.generation << 32);
    u64(c, &a);
    u64(c, &b);
    if (c->reading) {
      e->sensorShapeId =
          (b3ShapeId){(int32_t)(uint32_t)a, 0, (uint16_t)(a >> 32)};
      e->visitorShapeId =
          (b3ShapeId){(int32_t)(uint32_t)b, 0, (uint16_t)(b >> 32)};
      if ((a >> 32) > UINT16_MAX || (b >> 32) > UINT16_MAX)
        reject(c, OGB3_CORRUPT, 35);
    }
  }
  uint32_t ce = count(c, (uint32_t)w->contactEndEvents[idx].count,
                      l->max_pending_contacts);
  if (c->reading) {
    w->contactEndEvents[idx].count = w->contactEndEvents[idx].capacity =
        (int)ce;
    w->contactEndEvents[idx].data =
        dto_alloc(c, (size_t)ce * sizeof(b3ContactEndTouchEvent));
  }
  for (uint32_t i = 0; i < ce && !c->status; i++) {
    b3ContactEndTouchEvent *e = w->contactEndEvents[idx].data + i;
    uint64_t a = (uint32_t)e->shapeIdA.index1 |
                 ((uint64_t)e->shapeIdA.generation << 32),
             b = (uint32_t)e->shapeIdB.index1 |
                 ((uint64_t)e->shapeIdB.generation << 32),
             id = (uint32_t)e->contactId.index1 |
                  ((uint64_t)e->contactId.generation << 32);
    u64(c, &a);
    u64(c, &b);
    u64(c, &id);
    if (c->reading) {
      e->shapeIdA = (b3ShapeId){(int32_t)(uint32_t)a, 0, (uint16_t)(a >> 32)};
      e->shapeIdB = (b3ShapeId){(int32_t)(uint32_t)b, 0, (uint16_t)(b >> 32)};
      e->contactId = (b3ContactId){.index1 = (int32_t)(uint32_t)id,
                                   .generation = (uint32_t)(id >> 32)};
      if ((a >> 32) > UINT16_MAX || (b >> 32) > UINT16_MAX)
        reject(c, OGB3_CORRUPT, 35);
    }
  }
  ENDSECTION();
}
#undef SECTION
#undef ENDSECTION

/* Semantic verification: no live native lookup, mutation or assertion. Every
 * index is checked before dereference; stale prepared cache indices are not
 * treated as live references. */
#define VERIFY(x, n)                                                           \
  do {                                                                         \
    if (!(x)) {                                                                \
      reject(c, OGB3_CORRUPT, n);                                              \
      return 0;                                                                \
    }                                                                          \
  } while (0)
static int index_ok(int i, int count) { return i >= 0 && i < count; }
static int live_body(const b3World *w, int i) {
  return index_ok(i, w->bodies.count) && w->bodies.data[i].id == i;
}
static int live_shape(const b3World *w, int i) {
  return index_ok(i, w->shapes.count) && w->shapes.data[i].id == i;
}
static int live_contact(const b3World *w, int i) {
  return index_ok(i, w->contacts.count) && w->contacts.data[i].contactId == i;
}
static int live_joint(const b3World *w, int i) {
  return index_ok(i, w->joints.count) && w->joints.data[i].jointId == i;
}
static int live_island(const b3World *w, int i) {
  return index_ok(i, w->islands.count) && w->islands.data[i].islandId == i;
}
static int live_set(const b3World *w, int i) {
  return index_ok(i, w->solverSets.count) &&
         w->solverSets.data[i].setIndex == i;
}
static int quat_ok(b3Quat q, int allow_zero) {
  double n = (double)q.v.x * q.v.x + (double)q.v.y * q.v.y +
             (double)q.v.z * q.v.z + (double)q.s * q.s;
  return isfinite(n) && (fabs(n - 1) < .002 || (allow_zero && n == 0));
}
static int vec_bound(b3Vec3 v, float bound) {
  return isfinite(v.x) && isfinite(v.y) && isfinite(v.z) &&
         fabsf(v.x) <= bound && fabsf(v.y) <= bound && fabsf(v.z) <= bound;
}
static int hinge_settings_ok(const b3JointSim *v) {
  const b3RevoluteJoint *q = &v->revoluteJoint;
  return v->constraintHertz >= 0 && v->constraintDampingRatio >= 0 &&
         q->hertz >= 0 && q->dampingRatio >= 0 && q->maxMotorTorque >= 0 &&
         (!q->enableLimit || q->lowerAngle <= q->upperAngle) &&
         vec_bound(v->localFrameA.p, 1e8f) && vec_bound(v->localFrameB.p, 1e8f);
}
static int joint_type_ok(const Codec *c,b3JointType type) {
  if(type==b3_revoluteJoint)return 1;
  return c->catalog->identity.recovery_format>=OGB3_MOTION_RECOVERY_FORMAT &&
    (type==b3_distanceJoint||type==b3_motorJoint||type==b3_prismaticJoint||
     type==b3_sphericalJoint||type==b3_weldJoint||type==b3_wheelJoint);
}
/* All union scalars, impulses, local/cache frames, softness and matrices are
 * encoded by the generated dump-derived visitors above. These are the extra
 * operational settings/range constraints before native reconstruction. Cache
 * indices may legitimately be stale between preparations (same legacy rule). */
static int joint_settings_ok(const Codec *c,const b3JointSim *v) {
  if(!joint_type_ok(c,v->type))return 0;
  if(c->catalog->identity.recovery_format<OGB3_MOTION_RECOVERY_FORMAT)
    return hinge_settings_ok(v);
  if(v->constraintHertz<0||v->constraintDampingRatio<0||v->forceThreshold<0||v->torqueThreshold<0||
     v->invMassA<0||v->invMassB<0||!vec_bound(v->localFrameA.p,1e8f)||!vec_bound(v->localFrameB.p,1e8f))return 0;
  switch(v->type) {
  case b3_revoluteJoint:{const b3RevoluteJoint *q=&v->revoluteJoint;
    return hinge_settings_ok(v)&&q->lowerAngle<=q->upperAngle&&q->lowerAngle>=-3.1101767f&&q->upperAngle<=3.1101767f&&
      fabsf(q->targetAngle)<=3.1415927f&&q->lowerImpulse>=0&&q->upperImpulse>=0&&q->axialMass>=0&&quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  case b3_distanceJoint:{const b3DistanceJoint *q=&v->distanceJoint;
    return q->length>0&&q->hertz>=0&&q->dampingRatio>=0&&q->lowerSpringForce<=q->upperSpringForce&&q->minLength>=0&&q->minLength<=q->maxLength&&
      q->maxMotorForce>=0&&q->lowerImpulse>=0&&q->upperImpulse>=0&&q->axialMass>=0;}
  case b3_motorJoint:{const b3MotorJoint *q=&v->motorJoint;
    return q->maxVelocityForce>=0&&q->maxVelocityTorque>=0&&q->maxSpringForce>=0&&q->maxSpringTorque>=0&&q->linearHertz>=0&&q->linearDampingRatio>=0&&
      q->angularHertz>=0&&q->angularDampingRatio>=0&&quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  case b3_prismaticJoint:{const b3PrismaticJoint *q=&v->prismaticJoint;
    return q->hertz>=0&&q->dampingRatio>=0&&q->maxMotorForce>=0&&q->lowerTranslation<=q->upperTranslation&&q->lowerImpulse>=0&&q->upperImpulse>=0&&
      quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  case b3_sphericalJoint:{const b3SphericalJoint *q=&v->sphericalJoint;
    return q->hertz>=0&&q->dampingRatio>=0&&q->maxMotorTorque>=0&&q->coneAngle>=0&&q->coneAngle<=1.5707964f&&
      q->lowerTwistAngle<=q->upperTwistAngle&&q->lowerTwistAngle>=-3.1101767f&&q->upperTwistAngle<=3.1101767f&&
      q->lowerTwistImpulse>=0&&q->upperTwistImpulse>=0&&q->swingImpulse>=0&&q->swingMass>=0&&q->twistMass>=0&&
      quat_ok(q->targetRotation,0)&&quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  case b3_weldJoint:{const b3WeldJoint *q=&v->weldJoint;
    return q->linearHertz>=0&&q->angularHertz>=0&&q->linearDampingRatio>=0&&q->angularDampingRatio>=0&&quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  case b3_wheelJoint:{const b3WheelJoint *q=&v->wheelJoint;
    return q->maxSpinTorque>=0&&q->maxSteeringTorque>=0&&q->suspensionHertz>=0&&q->suspensionDampingRatio>=0&&q->steeringHertz>=0&&q->steeringDampingRatio>=0&&
      q->lowerSuspensionLimit<=q->upperSuspensionLimit&&q->lowerSteeringLimit<=q->upperSteeringLimit&&q->lowerSuspensionImpulse>=0&&q->upperSuspensionImpulse>=0&&
      q->lowerSteeringImpulse>=0&&q->upperSteeringImpulse>=0&&q->suspensionMass>=0&&q->spinMass>=0&&q->steeringMass>=0&&quat_ok(q->frameA.q,1)&&quat_ok(q->frameB.q,1);}
  default:return 0;
  }
}
static int aabb_ok(b3AABB b) {
  return vec_bound(b.lowerBound, 1e9f) && vec_bound(b.upperBound, 1e9f) &&
         b.lowerBound.x <= b.upperBound.x && b.lowerBound.y <= b.upperBound.y &&
         b.lowerBound.z <= b.upperBound.z;
}
static int contains(b3AABB a, b3AABB b) {
  return a.lowerBound.x <= b.lowerBound.x && a.lowerBound.y <= b.lowerBound.y &&
         a.lowerBound.z <= b.lowerBound.z && a.upperBound.x >= b.upperBound.x &&
         a.upperBound.y >= b.upperBound.y && a.upperBound.z >= b.upperBound.z;
}
static int matrix_ok(b3Matrix3 m) {
  if (!vec_bound(m.cx, 1e12f) || !vec_bound(m.cy, 1e12f) ||
      !vec_bound(m.cz, 1e12f))
    return 0;
  double scale = 1 + fabs(m.cx.x) + fabs(m.cy.y) + fabs(m.cz.z),
         e = scale * 1e-5;
  if (m.cx.x < 0 || m.cy.y < 0 || m.cz.z < 0 || fabs(m.cx.y - m.cy.x) > e ||
      fabs(m.cx.z - m.cz.x) > e || fabs(m.cy.z - m.cz.y) > e)
    return 0;
  double x = m.cx.x, y = m.cy.y, z = m.cz.z, a = m.cx.y, b = m.cx.z, d = m.cy.z;
  return x * y - a * a >= -e * scale && x * z - b * b >= -e * scale &&
         y * z - d * d >= -e * scale &&
         x * y * z + 2 * a * b * d - x * d * d - y * b * b - z * a * a >=
             -e * scale * scale;
}
static int pool_check(Codec *c, const b3IdPool *p, int n, const uint8_t *live) {
  VERIFY(p->nextIndex == n && p->freeArray.count >= 0 &&
             p->freeArray.count <= n,
         100);
  uint8_t *free_seen = dto_alloc(c, (size_t)n);
  if (c->status)
    return 0;
  for (int i = 0; i < p->freeArray.count; i++) {
    int id = p->freeArray.data[i];
    VERIFY(index_ok(id, n) && !free_seen[id] && !live[id], 101);
    free_seen[id] = 1;
  }
  for (int i = 0; i < n; i++)
    VERIFY((live[i] != 0) != (free_seen[i] != 0), 102);
  return 1;
}
static int tree_visit(Codec *c,const b3World*w,const b3DynamicTree*t,
                      int id,int parent,unsigned depth,int type,
                      uint8_t*seen,uint8_t*proxies,int*leaves){
  VERIFY(index_ok(id,t->nodeEnd)&&id!=1&&!seen[id]&&depth<64,110);
  seen[id]=1;const b3TreeNode*n=t->nodes+id;
  VERIFY(!b3IsEmptyNode(n)&&t->parents[id]==parent&&aabb_ok(n->aabb),111);
  if(b3IsLeaf(n)){
    int proxy=b3GetProxyId(n);VERIFY(index_ok(proxy,t->proxyCapacity)&&!proxies[proxy],112);
    const b3TreeProxy*p=t->proxies+proxy;
    VERIFY(p->node==id&&p->next==-1&&p->userData<=(uint64_t)INT_MAX&&live_shape(w,(int)p->userData),112);
    const b3Shape*s=w->shapes.data+p->userData;
    VERIFY(n->shapeIndex==(int)p->userData&&s->proxyKey==B3_PROXY_KEY(proxy,type)&&
           p->categoryBits==s->filter.categoryBits&&contains(n->aabb,w->fatAABBs.data[p->userData]),113);
    proxies[proxy]=1;(*leaves)++;return 1;
  }
  int a=b3GetLeftChild(n),b=a+1;
  VERIFY(a>=2&&!(a&1)&&index_ok(b,t->nodeEnd)&&(!t->dfsOrdered||a>id),114);
  if(!tree_visit(c,w,t,a,id,depth+1,type,seen,proxies,leaves)||
     !tree_visit(c,w,t,b,id,depth+1,type,seen,proxies,leaves))return 0;
  int ah=b3IsLeaf(t->nodes+a)?0:t->nodes[a].height;
  int bh=b3IsLeaf(t->nodes+b)?0:t->nodes[b].height;
  VERIFY(n->height==1+(ah>bh?ah:bh),115);
  VERIFY(contains(n->aabb,t->nodes[a].aabb)&&contains(n->aabb,t->nodes[b].aabb),116);
  VERIFY(!((t->nodes[a].flagIndex|t->nodes[b].flagIndex)&B3_MOVED_NODE)||b3IsNodeMoved(n),118);
  return 1;
}
static uint32_t pair_hash(uint64_t h) {
  h ^= h >> 33;
  h *= UINT64_C(0xff51afd7ed558ccd);
  h ^= h >> 33;
  h *= UINT64_C(0xc4ceb9fe1a85ec53);
  h ^= h >> 33;
  return (uint32_t)h;
}
static int validate_world(Codec *c, const b3World *w) {
  const ogb3_recovery_config *l = &c->catalog->limits;
  c->section = 1;
  VERIFY(w->endEventArrayIndex == 0 || w->endEventArrayIndex == 1, 120);
  VERIFY(w->fatAABBs.count==w->shapes.count&&w->compoundShapeCount==0&&w->simdWidth==4&&
         w->restitutionIterations>=0&&w->restitutionIterations<=B3_MAX_RESTITUTION_ITERATIONS&&
         isfinite(w->isotropicInertiaTolerance)&&w->isotropicInertiaTolerance>=0&&
         w->isotropicInertiaTolerance<=1,120);
  VERIFY(vec_bound(w->gravity, 1e6f) && w->maxLinearSpeed > 0 &&
             w->maxLinearSpeed <= 1e6f && w->contactHertz >= 0 &&
             w->contactHertz <= 1e6f && w->contactDampingRatio >= 0 &&
             w->contactDampingRatio <= 1e6f && w->restitutionThreshold >= 0 &&
             w->hitEventThreshold >= 0 && w->contactRecycleDistance >= 0 &&
             w->contactRecycleDistance <= 1e6f,
         121);
  float fixed_dt = 1.0f / 60.0f, fixed_h = fixed_dt / 4.0f;
  VERIFY((w->inv_h == 0 && w->inv_dt == 0) ||
             (float_equal(w->inv_h, 1.0f / fixed_h) &&
              float_equal(w->inv_dt, 1.0f / fixed_dt)),
         122);
  int nb = w->bodies.count, ns = w->shapes.count, nc = w->contacts.count,
      nj = w->joints.count, ni = w->islands.count, nt = w->solverSets.count;
  VERIFY(w->maxCapacity.staticBodyCount >= 0 &&
             w->maxCapacity.dynamicBodyCount >= 0 &&
             w->maxCapacity.staticShapeCount >= 0 &&
             w->maxCapacity.dynamicShapeCount >= 0 &&
             w->maxCapacity.contactCount >= 0,
         123);
  VERIFY(nt >= 3, 123);
  uint8_t *bm = dto_alloc(c, nb), *sm = dto_alloc(c, ns),
          *cm = dto_alloc(c, nc), *jm = dto_alloc(c, nj),
          *im = dto_alloc(c, ni), *tm = dto_alloc(c, nt);
  if (c->status)
    return 0;
  int bc = 0, sc = 0, cc = 0, jc = 0;
  for (int i = 0; i < nb; i++) {
    bm[i] = w->bodies.data[i].id == i;
    VERIFY(bm[i] || w->bodies.data[i].id == -1, 124);
    bc += bm[i];
  }
  for (int i = 0; i < ns; i++) {
    sm[i] = w->shapes.data[i].id == i;
    VERIFY(sm[i] || w->shapes.data[i].id == -1, 124);
    sc += sm[i];
  }
  for (int i = 0; i < nc; i++) {
    cm[i] = w->contacts.data[i].contactId == i;
    VERIFY(cm[i] || w->contacts.data[i].contactId == -1, 124);
    cc += cm[i];
  }
  for (int i = 0; i < nj; i++) {
    jm[i] = w->joints.data[i].jointId == i;
    VERIFY(jm[i] || w->joints.data[i].jointId == -1, 124);
    jc += jm[i];
  }
  for (int i = 0; i < ni; i++) {
    im[i] = w->islands.data[i].islandId == i;
    VERIFY(im[i] || w->islands.data[i].islandId == -1, 124);
  }
  for (int i = 0; i < nt; i++) {
    tm[i] = w->solverSets.data[i].setIndex == i;
    VERIFY(tm[i] || w->solverSets.data[i].setIndex == -1, 124);
  }
  if ((uint32_t)bc > l->max_bodies || (uint32_t)sc > l->max_shapes ||
      (uint32_t)cc > l->max_contacts || (uint32_t)jc > l->max_joints) {
    reject(c, OGB3_CAPACITY, 125);
    return 0;
  }
  c->section = 2;
  const b3IdPool *pools[] = {&w->bodyIdPool,    &w->shapeIdPool,
                             &w->contactIdPool, &w->jointIdPool,
                             &w->islandIdPool,  &w->solverSetIdPool};
  int sizes[] = {nb, ns, nc, nj, ni, nt};
  uint8_t *maps[] = {bm, sm, cm, jm, im, tm};
  for (unsigned i = 0; i < 6; i++)
    if (!pool_check(c, pools[i], sizes[i], maps[i]))
      return 0;
  VERIFY(tm[0] && tm[1] && tm[2], 126);
  uint8_t *body_sims = dto_alloc(c, nb), *joint_sims = dto_alloc(c, nj),
          *contact_sims = dto_alloc(c, nc), *island_sims = dto_alloc(c, ni),
          *shape_links = dto_alloc(c, ns);
  if (c->status)
    return 0;
  c->section = 3;
  for (int set = 0; set < nt; set++) {
    const b3SolverSet *s = w->solverSets.data + set;
    if (!tm[set]) {
      VERIFY(!s->bodySims.count && !s->bodyStates.count &&
                 !s->jointSims.count && !s->contactIndices.count &&
                 !s->islandSims.count,
             127);
      continue;
    }
    VERIFY((set == b3_awakeSet ? s->bodyStates.count == s->bodySims.count
                               : s->bodyStates.count == 0),
           128);
    if (set == b3_staticSet)
      VERIFY(!s->contactIndices.count && !s->islandSims.count, 129);
    if (set == b3_disabledSet)
      VERIFY(!s->islandSims.count, 129);
    if (set == b3_awakeSet)
      VERIFY(!s->jointSims.count, 129);
    for (int j = 0; j < s->bodySims.count; j++) {
      const b3BodySim *v = s->bodySims.data + j;
      VERIFY(live_body(w, v->bodyId) && !body_sims[v->bodyId], 130);
      body_sims[v->bodyId] = 1;
      const b3Body *b = w->bodies.data + v->bodyId;
      VERIFY(b->setIndex == set && b->localIndex == j, 131);
      uint32_t flags = b->flags & ~b3_bodyTransientFlags;
      VERIFY((v->flags & flags) == flags, 132);
      VERIFY(vec_bound(v->transform.p, 1e8f) && quat_ok(v->transform.q, 0) &&
                 quat_ok(v->rotation0, 0) && vec_bound(v->center, 1e8f) &&
                 vec_bound(v->center0, 1e8f) &&
                 vec_bound(v->localCenter, 1e8f) &&
                 vec_bound(v->force, 1e12f) && vec_bound(v->torque, 1e12f),
             133);
      VERIFY(v->minExtent >= 0 && v->minExtent <= B3_HUGE &&
                 matrix_ok(v->inertia) &&
                 v->invMass >= 0 && v->invMass <= 1e12f &&
                 matrix_ok(v->invInertiaLocal) &&
                 matrix_ok(v->invInertiaWorld) && v->linearDamping >= 0 &&
                 v->angularDamping >= 0 && fabsf(v->gravityScale) <= 1e6f,
             134);
      if (set == b3_awakeSet) {
        const b3BodyState *q = s->bodyStates.data + j;
        VERIFY((q->flags & flags) == flags &&
                   vec_bound(q->linearVelocity, 1e6f) &&
                   vec_bound(q->angularVelocity, 1e6f) &&
                   vec_bound(q->deltaPosition, 1e8f) &&
                   quat_ok(q->deltaRotation, 0),
               135);
      }
    }
    for (int j = 0; j < s->jointSims.count; j++) {
      const b3JointSim *v = s->jointSims.data + j;
      VERIFY(live_joint(w, v->jointId) && !joint_sims[v->jointId], 136);
      const b3Joint *q = w->joints.data + v->jointId;
      VERIFY(q->setIndex == set && q->colorIndex == -1 && q->localIndex == j,
             137);
      joint_sims[v->jointId] = 1;
    }
    for (int j = 0; j < s->contactIndices.count; j++) {
      int id = s->contactIndices.data[j];
      VERIFY(live_contact(w, id) && !contact_sims[id], 138);
      const b3Contact *q = w->contacts.data + id;
      VERIFY(q->setIndex == set && q->colorIndex == -1 && q->localIndex == j &&
                 set != b3_staticSet,
             139);
      contact_sims[id] = 1;
    }
    for (int j = 0; j < s->islandSims.count; j++) {
      int id = s->islandSims.data[j].islandId;
      VERIFY(live_island(w, id) && !island_sims[id], 140);
      const b3Island *q = w->islands.data + id;
      VERIFY(q->setIndex == set && q->localIndex == j, 141);
      island_sims[id] = 1;
    }
  }
  c->section = 4;
  int shape_total = 0, edge_contacts = 0, edge_joints = 0;
  for (int i = 0; i < nb; i++)
    if (bm[i]) {
      c->record = i;
      const b3Body *b = w->bodies.data + i;
      VERIFY(body_sims[i] && live_set(w, b->setIndex) &&
                 b->type >= b3_staticBody && b->type <= b3_dynamicBody,
             142);
      VERIFY(!(b->flags & ~(UINT32_C(0xffff) | b3_enableGyroscopicTorque)) && b->mass >= 0 &&
                 b->mass <= 1e12f && b->safetyFactor >= 0 && b->safetyFactor <= 1e6f &&
                 b->sleepThreshold >= 0 && b->sleepTime >= 0 &&
                 b->headChainId == -1,
             143);
      if (b->type == b3_dynamicBody)
        VERIFY(b->flags & b3_dynamicFlag, 144);
      if (b->setIndex == b3_staticSet)
        VERIFY(b->type == b3_staticBody, 145);
      if (b->type == b3_staticBody)
        VERIFY(b->setIndex == b3_staticSet || b->setIndex == b3_disabledSet,
               145);
      VERIFY(b->shapeCount >= 0 && (uint32_t)b->shapeCount <= l->max_shapes &&
                 b->contactCount >= 0 &&
                 (uint32_t)b->contactCount <= l->max_contacts &&
                 b->jointCount >= 0 && (uint32_t)b->jointCount <= l->max_joints,
             146);
      int id = b->headShapeId, prev = -1, n = 0;
      while (id != -1) {
        VERIFY(n++ < b->shapeCount && live_shape(w, id) && !shape_links[id],
               147);
        const b3Shape *s = w->shapes.data + id;
        VERIFY(s->bodyId == i && s->prevShapeId == prev, 148);
        shape_links[id] = 1;
        prev = id;
        id = s->nextShapeId;
      }
      VERIFY(n == b->shapeCount, 149);
      shape_total += n;
      id = b->headContactKey;
      prev = -1;
      n = 0;
      while (id != -1) {
        VERIFY(id >= 0 && n++ < b->contactCount && live_contact(w, id >> 1),
               150);
        const b3Contact *v = w->contacts.data + (id >> 1);
        int e = id & 1;
        VERIFY(v->edges[e].bodyId == i && v->edges[e].prevKey == prev, 151);
        prev = id;
        id = v->edges[e].nextKey;
      }
      VERIFY(n == b->contactCount, 152);
      edge_contacts += n;
      id = b->headJointKey;
      prev = -1;
      n = 0;
      while (id != -1) {
        VERIFY(id >= 0 && n++ < b->jointCount && live_joint(w, id >> 1), 153);
        const b3Joint *v = w->joints.data + (id >> 1);
        int e = id & 1;
        VERIFY(v->edges[e].bodyId == i && v->edges[e].prevKey == prev, 154);
        prev = id;
        id = v->edges[e].nextKey;
      }
      VERIFY(n == b->jointCount, 155);
      edge_joints += n;
      if (b->setIndex == b3_disabledSet)
        VERIFY(b->islandId == -1 && b->headContactKey == -1, 156);
      if (b->islandId != -1)
        VERIFY(live_island(w, b->islandId), 157);
    }
  VERIFY(shape_total == sc && edge_contacts == 2 * cc && edge_joints == 2 * jc,
         158);
  c->section = 5;
  for (int i = 0; i < ns; i++)
    if (sm[i]) {
      const b3Shape *s = w->shapes.data + i;
      VERIFY(shape_links[i] && live_body(w, s->bodyId) &&
                 (s->type == b3_sphereShape || s->type == b3_capsuleShape ||
                  s->type == b3_hullShape ||
                  (c->catalog->identity.recovery_format >= OGB3_AUTHORING_RECOVERY_FORMAT && s->type == b3_meshShape)) &&
                 s->materialCount == 1 && !s->materials &&
                 shape_asset(c->catalog, s),
             159);
      VERIFY(s->density >= 0 && s->density <= 1e6f && s->explosionScale >= 0 &&
                 s->aabbMargin >= 0 && s->material.friction >= 0 &&
                 s->material.friction <= 1e6f && s->material.restitution >= 0 &&
                 s->material.restitution <= 1e6f &&
                 s->material.rollingResistance >= 0 &&
                 vec_bound(s->material.tangentVelocity, 1e6f) &&
                 !(s->flags & ~0x7fu),
             160);
      if (s->sensorIndex != -1)
        VERIFY(index_ok(s->sensorIndex, w->sensors.count) &&
                   w->sensors.data[s->sensorIndex].shapeId == i,
               161);
      const b3Body *b = w->bodies.data + s->bodyId;
      if (s->type == b3_meshShape)
        VERIFY(b->type == b3_staticBody && s->sensorIndex == -1 &&
                   !(s->flags & b3_enableSensorEvents), 159);
      if (b->setIndex == b3_disabledSet)
        VERIFY(s->proxyKey == -1, 162);
      else {
        VERIFY(s->proxyKey >= 0 && B3_PROXY_TYPE(s->proxyKey) == b->type, 163);
        const b3DynamicTree *t = w->broadPhase.trees + b->type;
        int p = B3_PROXY_ID(s->proxyKey);
        VERIFY(index_ok(p,t->proxyCapacity)&&index_ok(t->proxies[p].node,t->nodeEnd)&&
               !b3IsEmptyNode(t->nodes+t->proxies[p].node)&&
               b3IsLeaf(t->nodes+t->proxies[p].node)&&
               b3GetProxyId(t->nodes+t->proxies[p].node)==p&&t->proxies[p].userData==(uint64_t)i,164);
        VERIFY(aabb_ok(s->aabb)&&aabb_ok(w->fatAABBs.data[i])&&
               contains(w->fatAABBs.data[i],s->aabb),165);
      }
    }
  c->section = 6;
  uint32_t total_manifolds = 0;
  for (int i = 0; i < nc; i++)
    if (cm[i]) {
      const b3Contact *v = w->contacts.data + i;
      VERIFY(live_shape(w, v->shapeIdA) && live_shape(w, v->shapeIdB) &&
                 v->shapeIdA != v->shapeIdB && v->childIndex == 0 &&
                 live_set(w, v->setIndex) && v->setIndex != b3_staticSet,
             166);
      VERIFY(v->edges[0].bodyId == w->shapes.data[v->shapeIdA].bodyId &&
                 v->edges[1].bodyId == w->shapes.data[v->shapeIdB].bodyId,
             167);
      const b3Body *endpointA = w->bodies.data + v->edges[0].bodyId;
      const b3Body *endpointB = w->bodies.data + v->edges[1].bodyId;
      /* Serialized caches are omitted; build derives them only after this graph validates.
       * A live source writer must nevertheless have consistent native caches. */
      if(!c->reading)VERIFY(v->encodedBodySimA==b3EncodeBodySimIndex(endpointA)&&
                            v->encodedBodySimB==b3EncodeBodySimIndex(endpointB),167);
      VERIFY(endpointA != endpointB && endpointA->setIndex != b3_disabledSet &&
                 endpointB->setIndex != b3_disabledSet &&
                 (endpointA->type == b3_dynamicBody ||
                  endpointB->type == b3_dynamicBody),
             221);
      VERIFY(v->friction >= 0 && v->friction <= 1e6f && v->restitution >= 0 &&
                 v->restitution <= 1e6f && v->rollingResistance >= 0 &&
                 vec_bound(v->tangentVelocity, 1e6f) &&
                 !(v->flags & ~UINT32_C(0x01ff001f)),
             168);
      if (v->islandId != -1)
        VERIFY(live_island(w, v->islandId), 169);
      /* This pin keeps manifolds exactly for touching contacts at settled
       * boundaries. Graph/solver code dereferences the convex manifold without
       * another count check. Non-touching contacts reside in a solver set. */
      int touching = (v->flags & b3_contactTouchingFlag) != 0;
      int mesh = (v->flags & b3_simMeshContact) != 0;
      const b3Shape *sa = w->shapes.data + v->shapeIdA,
                    *sb = w->shapes.data + v->shapeIdB;
      if (mesh) {
        VERIFY(c->catalog->identity.recovery_format >= OGB3_AUTHORING_RECOVERY_FORMAT &&
                   sa->type == b3_meshShape && endpointA->type == b3_staticBody &&
                   (sb->type == b3_hullShape || sb->type == b3_sphereShape || sb->type == b3_capsuleShape) &&
                   v->manifoldCount >= 0 && (uint32_t)v->manifoldCount <= l->max_manifolds &&
                   (v->manifoldCount > 0) == touching, 170);
      } else {
        VERIFY(sa->type != b3_meshShape && sb->type != b3_meshShape &&
                   v->manifoldCount == touching, 170);
      }
      VERIFY(touching || (v->colorIndex == -1 && v->islandId == -1), 170);
      if (touching) {
        VERIFY(live_island(w, v->islandId), 222);
        VERIFY((endpointA->type == b3_staticBody ||
                endpointA->islandId == v->islandId) &&
                   (endpointB->type == b3_staticBody ||
                    endpointB->islandId == v->islandId),
               222);
      }
      VERIFY(v->setIndex < b3_firstSleepingSet || touching, 170);
      VERIFY(v->setIndex != b3_disabledSet || !touching, 170);
      if (v->flags & b3_relativeTransformValid)
        VERIFY(quat_ok(v->cachedRotationA, 0) &&
                   quat_ok(v->cachedRotationB, 0) &&
                   quat_ok(v->cachedRelativePose.q, 0) &&
                   vec_bound(v->cachedRelativePose.p, 1e8f),
               220);
      total_manifolds += v->manifoldCount;
      for (int j = 0; j < v->manifoldCount; j++) {
        const b3Manifold *m = v->manifolds + j;
        VERIFY(m->pointCount >= 0 && m->pointCount <= 4 &&
                   vec_bound(m->normal, 2),
               171);
        double n = (double)m->normal.x * m->normal.x +
                   (double)m->normal.y * m->normal.y +
                   (double)m->normal.z * m->normal.z;
        VERIFY(!m->pointCount || fabs(n - 1) < .005, 172);
        for (int k = 0; k < m->pointCount; k++) {
          VERIFY(vec_bound(m->points[k].anchorA, 1e8f) &&
                     vec_bound(m->points[k].anchorB, 1e8f) &&
                     m->points[k].normalImpulse >= 0 &&
                     m->points[k].totalNormalImpulse >= 0,
                 173);
          if (mesh)
            VERIFY(index_ok(m->points[k].triangleIndex, sa->mesh.data->triangleCount), 173);
        }
      }
      if (mesh) {
        const b3Array(b3TriangleCache) *cache = &v->meshContact.triangleCache;
        VERIFY(cache->count >= 0 && (uint32_t)cache->count <= MESH_CONTACT_TRIANGLES &&
                   aabb_ok(v->meshContact.queryBounds), 174);
        for (int j = 0; j < cache->count; j++) {
          const b3TriangleCache *t = cache->data + j;
          VERIFY(index_ok(t->triangleIndex, sa->mesh.data->triangleCount) &&
                     (!j || cache->data[j-1].triangleIndex < t->triangleIndex), 174);
          if (sb->type == b3_hullShape) {
            const b3SATCache *q = &t->cache.satCache;
            const b3HullData *h = sb->hull;
            switch (q->type) {
            case b3_invalidAxis:
            case b3_backsideAxis:
              break;
            case b3_faceAxisA:
              VERIFY(q->indexA == 0, 174);
              break;
            case b3_faceAxisB:
              VERIFY(q->indexB < h->faceCount, 174);
              break;
            case b3_edgePairAxis: {
              int e = q->indexB;
              VERIFY(q->indexA < 3 && e + 1 < h->edgeCount, 174);
              const b3HullHalfEdge *edges = b3GetHullEdges(h);
              VERIFY(edges[e].twin == e+1 && edges[e+1].twin == e, 174);
              break;
            }
            default: VERIFY(0, 174);
            }
          } else {
            const b3SimplexCache *q = &t->cache.simplexCache;
            VERIFY(q->count <= 4, 175);
            for (unsigned k = 0; k < q->count; k++)
              VERIFY(q->indexA[k] < 3 && q->indexB[k] < (sb->type == b3_capsuleShape ? 2 : 1), 176);
          }
        }
        continue;
      }
      int hulls = w->shapes.data[v->shapeIdA].type == b3_hullShape &&
                  w->shapes.data[v->shapeIdB].type == b3_hullShape;
      if (hulls) {
        const b3SATCache *q = &v->convexContact.cache.satCache;
        const b3HullData *ha = w->shapes.data[v->shapeIdA].hull,
                         *hb = w->shapes.data[v->shapeIdB].hull;
        switch (q->type) {
        case b3_invalidAxis:
        case b3_manualFaceAxisA:
        case b3_manualFaceAxisB:
        case b3_manualEdgePairAxis:
          break; /* cached indices ignored by this pin */
        case b3_faceAxisA:
          VERIFY(q->indexA < ha->faceCount && q->indexB < hb->vertexCount, 174);
          break;
        case b3_faceAxisB:
          VERIFY(q->indexA < ha->vertexCount && q->indexB < hb->faceCount, 174);
          break;
        case b3_edgePairAxis: {
          int a = q->indexA, b = q->indexB;
          VERIFY(a + 1 < ha->edgeCount && b + 1 < hb->edgeCount, 174);
          const b3HullHalfEdge *ea = b3GetHullEdges(ha),
                               *eb = b3GetHullEdges(hb);
          VERIFY(ea[a].twin == a + 1 && ea[a + 1].twin == a &&
                     eb[b].twin == b + 1 && eb[b + 1].twin == b,
                 174);
          break;
        }
        default:
          VERIFY(0, 174);
        }
      } else {
        const b3SimplexCache *q = &v->convexContact.cache.simplexCache;
        VERIFY(q->count <= 4, 175);
        int na = w->shapes.data[v->shapeIdA].type == b3_hullShape      ? (int)w->shapes.data[v->shapeIdA].hull->vertexCount
                 : w->shapes.data[v->shapeIdA].type == b3_capsuleShape ? 2
                                                                       : 1,
            nn = w->shapes.data[v->shapeIdB].type == b3_hullShape      ? (int)w->shapes.data[v->shapeIdB].hull->vertexCount
                 : w->shapes.data[v->shapeIdB].type == b3_capsuleShape ? 2
                                                                       : 1;
        for (unsigned j = 0; j < q->count; j++)
          VERIFY(q->indexA[j] < na && q->indexB[j] < nn, 176);
      }
    }
  VERIFY(total_manifolds <= l->max_manifolds, 177);
  c->section = 7;
  for (int i = 0; i < nj; i++)
    if (jm[i]) {
      const b3Joint *v = w->joints.data + i;
      VERIFY(joint_type_ok(c,v->type) && live_body(w, v->edges[0].bodyId) &&
                 live_body(w, v->edges[1].bodyId) &&
                 v->edges[0].bodyId != v->edges[1].bodyId &&
                 live_set(w, v->setIndex),
             178);
      if (v->islandId != -1)
        VERIFY(live_island(w, v->islandId), 179);
    }
  c->section = 8;
  uint32_t visitors = 0;
  for (int i = 0; i < w->sensors.count; i++) {
    const b3Sensor *v = w->sensors.data + i;
    VERIFY(live_shape(w, v->shapeId) &&
               w->shapes.data[v->shapeId].sensorIndex == i,
           180);
    const b3Array(b3Visitor) *
        arrays[] = {&v->hits, &v->overlaps1, &v->overlaps2};
    for (unsigned a = 0; a < 3; a++) {
      visitors += arrays[a]->count;
      for (int j = 0; j < arrays[a]->count; j++) {
        VERIFY(index_ok(arrays[a]->data[j].shapeId, ns), 181);
        if (a && j)
          VERIFY(arrays[a]->data[j - 1].shapeId < arrays[a]->data[j].shapeId,
                 181);
      }
    }
  }
  VERIFY(visitors <= l->max_visitors, 182);
  c->section = 9;
  uint8_t *island_bodies = dto_alloc(c, nb),
          *island_contacts = dto_alloc(c, nc),
          *island_joints = dto_alloc(c, nj);
  if (c->status)
    return 0;
  for (int i = 0; i < ni; i++) {
    const b3Island *v = w->islands.data + i;
    if (!im[i]) {
      VERIFY(v->setIndex == -1 && !v->bodies.count && !v->contacts.count &&
                 !v->joints.count,
             183);
      continue;
    }
    VERIFY(island_sims[i] && live_set(w, v->setIndex) &&
               v->setIndex >= b3_awakeSet && v->constraintRemoveCount >= 0,
           184);
    for (int j = 0; j < v->bodies.count; j++) {
      int id = v->bodies.data[j];
      VERIFY(live_body(w, id) && !island_bodies[id], 185);
      const b3Body *b = w->bodies.data + id;
      VERIFY(b->islandId == i && b->islandIndex == j &&
                 b->setIndex == v->setIndex,
             186);
      island_bodies[id] = 1;
    }
    for (int j = 0; j < v->contacts.count; j++) {
      const b3ContactLink *q = v->contacts.data + j;
      VERIFY(live_contact(w, q->contactId) && !island_contacts[q->contactId],
             187);
      const b3Contact *x = w->contacts.data + q->contactId;
      VERIFY(x->islandId == i && x->islandIndex == j &&
                 x->setIndex == v->setIndex &&
                 x->edges[0].bodyId == q->bodyIdA &&
                 x->edges[1].bodyId == q->bodyIdB,
             188);
      island_contacts[q->contactId] = 1;
    }
    for (int j = 0; j < v->joints.count; j++) {
      const b3JointLink *q = v->joints.data + j;
      VERIFY(live_joint(w, q->jointId) && !island_joints[q->jointId], 189);
      const b3Joint *x = w->joints.data + q->jointId;
      VERIFY(x->islandId == i && x->islandIndex == j &&
                 x->setIndex == v->setIndex &&
                 x->edges[0].bodyId == q->bodyIdA &&
                 x->edges[1].bodyId == q->bodyIdB,
             190);
      island_joints[q->jointId] = 1;
    }
  }
  for (int i = 0; i < nb; i++)
    if (bm[i])
      VERIFY((w->bodies.data[i].islandId != -1) == (island_bodies[i] != 0),
             191);
  for (int i = 0; i < nc; i++)
    if (cm[i])
      VERIFY((w->contacts.data[i].islandId != -1) == (island_contacts[i] != 0),
             191);
  for (int i = 0; i < nj; i++)
    if (jm[i])
      VERIFY((w->joints.data[i].islandId != -1) == (island_joints[i] != 0),
             191);
  c->section = 10;
  int tree_shapes = 0;
  for (int t = 0; t < 3; t++) {
    const b3DynamicTree *v = w->broadPhase.trees + t;
    VERIFY(v->version==B3_DYNAMIC_TREE_VERSION&&v->nodeEnd>=2&&!(v->nodeEnd&1)&&
           v->nodeCapacity>=v->nodeEnd&&(uint32_t)v->nodeEnd<=l->max_tree_nodes&&
           v->proxyCapacity>=1&&(uint32_t)v->proxyCapacity<=l->max_tree_nodes&&
           v->proxyCount>=0&&v->proxyCount<=v->proxyCapacity,192);
    uint8_t*seen=dto_alloc(c,(size_t)v->nodeEnd);
    uint8_t*proxies=dto_alloc(c,(size_t)v->proxyCapacity);if(c->status)return 0;
    VERIFY(v->parents[0]==-1&&v->parents[1]==-1&&b3IsEmptyNode(v->nodes+1),193);
    seen[1]=1;int leaves=0;
    if(v->proxyCount){if(!tree_visit(c,w,v,0,-1,0,t,seen,proxies,&leaves))return 0;}
    else{VERIFY(b3IsEmptyNode(v->nodes),193);seen[0]=1;}
    int pair=v->pairFreeList,pair_count=0;
    while(pair!=-1){
      VERIFY(pair>=2&&!(pair&1)&&index_ok(pair+1,v->nodeEnd)&&!seen[pair]&&!seen[pair+1]&&
             b3IsEmptyNode(v->nodes+pair)&&b3IsEmptyNode(v->nodes+pair+1)&&v->parents[pair+1]==-1&&
             pair_count++<v->nodeEnd/2,195);
      seen[pair]=seen[pair+1]=1;pair=v->parents[pair];
    }
    for(int id=0;id<v->nodeEnd;id++)VERIFY(seen[id],194);
    int free_proxy=v->proxyFreeList,free_count=0;
    while(free_proxy!=-1){
      VERIFY(index_ok(free_proxy,v->proxyCapacity)&&!proxies[free_proxy]&&
             v->proxies[free_proxy].node==-1&&free_count++<v->proxyCapacity,195);
      proxies[free_proxy]=1;free_proxy=v->proxies[free_proxy].next;
    }
    VERIFY(leaves==v->proxyCount&&leaves+free_count==v->proxyCapacity,196);
    for(int id=0;id<v->proxyCapacity;id++)VERIFY(proxies[id],196);
    tree_shapes+=leaves;
  }
  int enabled_shapes = 0;
  for (int i = 0; i < ns; i++)
    if (sm[i] && w->shapes.data[i].proxyKey != -1)
      enabled_shapes++;
  VERIFY(tree_shapes == enabled_shapes, 200);
  const b3HashSet *hs = &w->broadPhase.pairSet;
  VERIFY(hs->capacity >= 16 && (hs->capacity & (hs->capacity - 1)) == 0 &&
             hs->count < hs->capacity && hs->count == (uint32_t)cc,
         201);
  uint32_t entries = 0;
  for (uint32_t i = 0; i < hs->capacity; i++) {
    const b3SetItem *x = hs->items + i;
    if (!x->hash) {
      VERIFY(x->key == 0, 202);
      continue;
    }
    entries++;
    VERIFY(x->key && x->hash == pair_hash(x->key), 203);
    uint32_t at = x->hash & (hs->capacity - 1), distance = 0;
    while (at != i) {
      VERIFY(hs->items[at].hash && hs->items[at].key != x->key &&
                 distance++ < hs->capacity,
             204);
      at = (at + 1) & (hs->capacity - 1);
    }
    int found = 0;
    for (int j = 0; j < nc; j++)
      if (cm[j] && b3ShapePairKey(w->contacts.data[j].shapeIdA,
                                  w->contacts.data[j].shapeIdB, 0) == x->key)
        found++;
    VERIFY(found == 1, 205);
  }
  VERIFY(entries == hs->count, 206);
  c->section = 11;
  for (int col = 0; col < B3_GRAPH_COLOR_COUNT; col++) {
    const b3GraphColor *g = w->constraintGraph.colors + col;
    uint8_t *used = dto_alloc(c, nb);
    if (c->status)
      return 0;
    for (int j = 0; j < g->jointSims.count; j++) {
      const b3JointSim *v = g->jointSims.data + j;
      VERIFY(live_joint(w, v->jointId) && !joint_sims[v->jointId], 207);
      const b3Joint *x = w->joints.data + v->jointId;
      VERIFY(x->setIndex == b3_awakeSet && x->colorIndex == col &&
                 x->localIndex == j,
             208);
      joint_sims[v->jointId] = 1;
    }
    for (int mode = 0; mode < 2; mode++) {
      int count = mode ? g->contacts.count : g->convexContacts.count;
      for (int j = 0; j < count; j++) {
        int id =
            mode ? g->contacts.data[j].contactId : g->convexContacts.data[j];
        VERIFY(live_contact(w, id) && !contact_sims[id], 209);
        const b3Contact *x = w->contacts.data + id;
        VERIFY(x->setIndex == b3_awakeSet && x->colorIndex == col &&
                   x->localIndex == j,
               210);
        if (mode)
          VERIFY(g->contacts.data[j].manifoldCount == x->manifoldCount &&
                     x->manifoldCount > 0 &&
                     (uint32_t)x->manifoldCount <= l->max_manifolds,
                 211);
        else
          VERIFY(!(x->flags & b3_simMeshContact) && x->manifoldCount == 1, 211);
        contact_sims[id] = 1;
      }
    }
    /* Membership/conflict bits contain dynamic bodies only. Static/kinematic
     * endpoints do not consume graph ownership bits in this pin. */
    for (int j = 0; j < g->jointSims.count; j++) {
      const b3JointSim *v = g->jointSims.data + j;
      VERIFY(live_body(w, v->bodyIdA) && live_body(w, v->bodyIdB), 212);
      int ids[] = {v->bodyIdA, v->bodyIdB};
      for (unsigned k = 0; k < 2; k++)
        if (w->bodies.data[ids[k]].type == b3_dynamicBody) {
          if (col != B3_OVERFLOW_INDEX)
            VERIFY(!used[ids[k]], 213);
          used[ids[k]] = 1;
        }
    }
    for (int mode = 0; mode < 2; mode++) {
      int count = mode ? g->contacts.count : g->convexContacts.count;
      for (int j = 0; j < count; j++) {
        const b3Contact *v =
            w->contacts.data +
            (mode ? g->contacts.data[j].contactId : g->convexContacts.data[j]);
        for (unsigned k = 0; k < 2; k++) {
          int id = v->edges[k].bodyId;
          VERIFY(live_body(w, id), 212);
          if (w->bodies.data[id].type == b3_dynamicBody) {
            if (col != B3_OVERFLOW_INDEX)
              VERIFY(!used[id], 213);
            used[id] = 1;
          }
        }
      }
    }
    if (col != B3_OVERFLOW_INDEX) {
      for (int id = 0; id < nb; id++)
        if (used[id])
          VERIFY((uint32_t)id / 64 < g->bodySet.blockCount &&
                     ((g->bodySet.bits[id / 64] >> (id % 64)) & 1),
                 214);
      for (uint32_t bit = 0; bit < g->bodySet.blockCount * 64; bit++) {
        int value = (g->bodySet.bits[bit / 64] >> (bit % 64)) & 1;
        VERIFY(value == (bit < (uint32_t)nb ? used[bit] : 0), 214);
      }
    }
  }
  for (int i = 0; i < nc; i++)
    if (cm[i])
      VERIFY(contact_sims[i], 215);
  for (int i = 0; i < nj; i++)
    if (jm[i])
      VERIFY(joint_sims[i], 215);
  /* Joint cache indices/indexA/indexB may be stale after sleeping/spawn. The
   * operational references are jointId/bodyIdA/B and reciprocal set/color
   * slots. */
  for (int set = 0; set < nt; set++)
    for (int j = 0; j < w->solverSets.data[set].jointSims.count; j++) {
      const b3JointSim *v = w->solverSets.data[set].jointSims.data + j;
      const b3Joint *q = w->joints.data + v->jointId;
      VERIFY(v->type == q->type && joint_type_ok(c,v->type) && v->bodyIdA == q->edges[0].bodyId &&
                 v->bodyIdB == q->edges[1].bodyId &&
                 quat_ok(v->localFrameA.q, 0) && quat_ok(v->localFrameB.q, 0) &&
                 joint_settings_ok(c,v),
             216);
    }
  for (int col = 0; col < B3_GRAPH_COLOR_COUNT; col++)
    for (int j = 0; j < w->constraintGraph.colors[col].jointSims.count; j++) {
      const b3JointSim *v = w->constraintGraph.colors[col].jointSims.data + j;
      const b3Joint *q = w->joints.data + v->jointId;
      VERIFY(v->type == q->type && joint_type_ok(c,v->type) && v->bodyIdA == q->edges[0].bodyId &&
                 v->bodyIdB == q->edges[1].bodyId &&
                 quat_ok(v->localFrameA.q, 0) && quat_ok(v->localFrameB.q, 0) &&
                 joint_settings_ok(c,v),
             216);
    }
  c->section = 12;
  int e = w->endEventArrayIndex;
  for (int i = 0; i < w->sensorEndEvents[e].count; i++) {
    const b3SensorEndTouchEvent *v = w->sensorEndEvents[e].data + i;
    VERIFY(v->sensorShapeId.index1 > 0 && v->sensorShapeId.index1 <= ns &&
               v->visitorShapeId.index1 > 0 && v->visitorShapeId.index1 <= ns,
           217);
  }
  for (int i = 0; i < w->contactEndEvents[e].count; i++) {
    const b3ContactEndTouchEvent *v = w->contactEndEvents[e].data + i;
    VERIFY(v->shapeIdA.index1 > 0 && v->shapeIdA.index1 <= ns &&
               v->shapeIdB.index1 > 0 && v->shapeIdB.index1 <= ns &&
               v->contactId.index1 > 0 && v->contactId.index1 <= nc,
           218);
  }
  VERIFY(w->splitIslandId == -1 || live_island(w, w->splitIslandId), 219);
  return !c->status;
}
#undef VERIFY

/* Detached native allocation ledger. No partial arrays are installed in the
 * shell. Manifolds and hull refs use the shell's valid owners and are unwound
 * before empty-shell teardown on any pre-assembly failure. */
typedef struct NativePiece {
  struct NativePiece *next;
  void *ptr;
  size_t size;
  int kind, count;
} NativePiece;
#ifdef OGB3_TESTING
static int64_t build_fail_after = -1;
void ogb3_recovery_test_fail_build_after(int64_t n) { build_fail_after = n; }
#endif
static int build_point(Codec *c) {
#ifdef OGB3_TESTING
  if (build_fail_after == 0) {
    reject(c, OGB3_OUT_OF_MEMORY, 300);
    return 0;
  }
  if (build_fail_after > 0)
    build_fail_after--;
#endif
  return !c->status;
}
static NativePiece *piece(Codec *c, NativePiece **list, int kind) {
  if (!build_point(c))
    return NULL;
  NativePiece *n = dto_alloc(c, sizeof(*n));
  if (!n)
    return NULL;
  n->kind = kind;
  n->next = *list;
  *list = n;
  return n;
}
static void *native_copy(Codec *c, NativePiece **list, const void *source,
                         size_t count, size_t capacity, size_t element) {
  if (!capacity)
    return NULL;
  if (capacity > SIZE_MAX / element ||
      !memory_admit(c->external, capacity * element)) {
    reject(c, OGB3_CAPACITY, 301);
    return NULL;
  }
  NativePiece *n = piece(c, list, 0);
  if (!n)
    return NULL;
  n->size = capacity * element;
  n->ptr = b3Alloc(n->size);
  memset(n->ptr, 0, n->size);
  if (count)
    memcpy(n->ptr, source, count * element);
  return n->ptr;
}
#define NCOPY(field)                                                           \
  do {                                                                         \
    (field).data = native_copy(c, &parts, (field).data, (field).count,         \
                               (field).count, sizeof(*(field).data));          \
    (field).capacity = (field).count;                                          \
  } while (0)
static void native_unwind(b3World *shell, NativePiece *parts) {
  for (NativePiece *p = parts; p; p = p->next)
    if (p->ptr) {
      if (p->kind == 1)
        b3RemoveHullFromDatabase(shell, p->ptr);
      else if (p->kind == 2)
        b3FreeManifolds(shell, p->ptr, p->count);
      else
        b3Free(p->ptr, p->size);
    }
}
static void empty_storage_free(b3World *w) {
  b3DestroyBroadPhase(&w->broadPhase);
  b3DestroyGraph(&w->constraintGraph);
  b3DestroyIdPool(&w->bodyIdPool);
  b3DestroyIdPool(&w->shapeIdPool);
  b3DestroyIdPool(&w->contactIdPool);
  b3DestroyIdPool(&w->jointIdPool);
  b3DestroyIdPool(&w->islandIdPool);
  b3DestroyIdPool(&w->solverSetIdPool);
  for (int i = 0; i < w->solverSets.count; i++) {
    b3SolverSet *s = w->solverSets.data + i;
    b3Array_Destroy(s->bodySims);
    b3Array_Destroy(s->bodyStates);
    b3Array_Destroy(s->jointSims);
    b3Array_Destroy(s->contactIndices);
    b3Array_Destroy(s->islandSims);
  }
  b3Array_Destroy(w->solverSets);
  b3Array_Destroy(w->bodies);
  b3Array_Destroy(w->shapes);
  b3Array_Destroy(w->fatAABBs);
  b3Array_Destroy(w->contacts);
  b3Array_Destroy(w->joints);
  b3Array_Destroy(w->sensors);
  b3Array_Destroy(w->islands);
  for (int i = 0; i < 2; i++) {
    b3Array_Destroy(w->sensorEndEvents[i]);
    b3Array_Destroy(w->contactEndEvents[i]);
  }
}
static ogb3_status build_native(Codec *c, const b3World *d, ogb3_world *out) {
  *out = 0;
  if (!build_point(c))
    return c->status;
  ogb3_world_def def;
  if (ogb3_world_def_default(&def)) {
    reject(c, OGB3_INCOMPATIBLE, 302);
    return c->status;
  }
  ogb3_world id = 0;
  ogb3_status status = ogb3_world_create(&def, &id);
  if (status)
    return status;
  b3WorldId native;
  memcpy(&native, &id, sizeof(native));
  b3World *shell = b3GetWorldFromId(native);
  b3World n = *d;
  NativePiece *parts = NULL;
  b3IdPool *pools[] = {&n.bodyIdPool,  &n.shapeIdPool,  &n.contactIdPool,
                       &n.jointIdPool, &n.islandIdPool, &n.solverSetIdPool};
  for (unsigned i = 0; i < 6 && !c->status; i++) {
    b3IdPool *p = pools[i];
    p->freeArray.data =
        native_copy(c, &parts, p->freeArray.data, p->freeArray.count,
                    p->nextIndex, sizeof(int));
    p->freeArray.capacity = p->nextIndex;
  }
  NCOPY(n.bodies);
  NCOPY(n.shapes);
  NCOPY(n.fatAABBs);
  NCOPY(n.contacts);
  NCOPY(n.joints);
  NCOPY(n.solverSets);
  NCOPY(n.sensors);
  NCOPY(n.islands);
  for (int i = 0; i < n.shapes.count && !c->status; i++) {
    b3Shape *s = n.shapes.data + i;
    if (s->id == i && s->type == b3_hullShape) {
      NativePiece *p = piece(c, &parts, 1);
      if (!p)
        break;
      p->ptr = (void *)b3AddHullToDatabase(shell, s->hull);
      s->hull = p->ptr;
    }
  }
  for (int i = 0; i < n.contacts.count && !c->status; i++) {
    b3Contact *v = n.contacts.data + i;
    if (v->contactId != i) {
      v->manifolds = NULL;
      continue;
    }
    if (v->manifoldCount) {
      NativePiece *p = piece(c, &parts, 2);
      if (!p)
        break;
      p->count = v->manifoldCount;
      p->ptr = b3AllocateManifolds(shell, p->count);
      memcpy(p->ptr, v->manifolds, (size_t)p->count * sizeof(b3Manifold));
      v->manifolds = p->ptr;
    }
    if (v->flags & b3_simMeshContact) {
      NCOPY(v->meshContact.triangleCache);
    }
    v->encodedBodySimA=b3EncodeBodySimIndex(n.bodies.data+v->edges[0].bodyId);
    v->encodedBodySimB=b3EncodeBodySimIndex(n.bodies.data+v->edges[1].bodyId);
  }
  for (int i = 0; i < n.solverSets.count && !c->status; i++) {
    b3SolverSet *s = n.solverSets.data + i;
    NCOPY(s->bodySims);
    NCOPY(s->bodyStates);
    NCOPY(s->jointSims);
    NCOPY(s->contactIndices);
    NCOPY(s->islandSims);
  }
  for (int i = 0; i < n.sensors.count && !c->status; i++) {
    b3Sensor *s = n.sensors.data + i;
    s->hits.data =
        native_copy(c, &parts, s->hits.data, s->hits.count,
                    s->hits.count > 4 ? s->hits.count : 4, sizeof(b3Visitor));
    s->hits.capacity = s->hits.count > 4 ? s->hits.count : 4;
    s->overlaps1.data = native_copy(
        c, &parts, s->overlaps1.data, s->overlaps1.count,
        s->overlaps1.count > 16 ? s->overlaps1.count : 16, sizeof(b3Visitor));
    s->overlaps1.capacity = s->overlaps1.count > 16 ? s->overlaps1.count : 16;
    s->overlaps2.data = native_copy(
        c, &parts, s->overlaps2.data, s->overlaps2.count,
        s->overlaps2.count > 16 ? s->overlaps2.count : 16, sizeof(b3Visitor));
    s->overlaps2.capacity = s->overlaps2.count > 16 ? s->overlaps2.count : 16;
  }
  for (int i = 0; i < n.islands.count && !c->status; i++) {
    b3Island *s = n.islands.data + i;
    NCOPY(s->bodies);
    NCOPY(s->contacts);
    NCOPY(s->joints);
  }
  for (int i = 0; i < 3 && !c->status; i++) {
    b3DynamicTree *t = n.broadPhase.trees + i;
    t->nodes=native_copy(c,&parts,t->nodes,t->nodeEnd,t->nodeEnd,sizeof(*t->nodes));
    t->parents=native_copy(c,&parts,t->parents,t->nodeEnd,t->nodeEnd,sizeof(*t->parents));
    t->proxies=native_copy(c,&parts,t->proxies,t->proxyCapacity,t->proxyCapacity,sizeof(*t->proxies));
    t->nodeCapacity=t->nodeEnd;
  }
  n.broadPhase.pairSet.items = native_copy(
      c, &parts, n.broadPhase.pairSet.items, n.broadPhase.pairSet.capacity,
      n.broadPhase.pairSet.capacity, sizeof(b3SetItem));
  for (int i = 0; i < B3_GRAPH_COLOR_COUNT && !c->status; i++) {
    b3GraphColor *g = n.constraintGraph.colors + i;
    if (i != B3_OVERFLOW_INDEX) {
      g->bodySet.bits =
          native_copy(c, &parts, g->bodySet.bits, g->bodySet.blockCount,
                      g->bodySet.blockCount, 8);
      g->bodySet.blockCapacity = g->bodySet.blockCount;
    }
    NCOPY(g->jointSims);
    NCOPY(g->convexContacts);
    NCOPY(g->contacts);
  }
  for (int i = 0; i < 2 && !c->status; i++) {
    NCOPY(n.sensorEndEvents[i]);
    NCOPY(n.contactEndEvents[i]);
  }
  if (c->status) {
    native_unwind(shell, parts);
    ogb3_world_destroy(id);
    return c->status;
  }
  for (int i = 0; i < n.bodies.count; i++)
    n.bodies.data[i].bodyMoveIndex = -1;
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < n.sensorEndEvents[i].count; j++) {
      n.sensorEndEvents[i].data[j].sensorShapeId.world0 = shell->worldId;
      n.sensorEndEvents[i].data[j].visitorShapeId.world0 = shell->worldId;
    }
    for (int j = 0; j < n.contactEndEvents[i].count; j++) {
      n.contactEndEvents[i].data[j].shapeIdA.world0 = shell->worldId;
      n.contactEndEvents[i].data[j].shapeIdB.world0 = shell->worldId;
      n.contactEndEvents[i].data[j].contactId.world0 = shell->worldId;
      n.contactEndEvents[i].data[j].contactId.padding = 0;
    }
  }
  /* Infallible assembly; all nested storage is initialized, native-owned and
   * reference-verified. The shell retains its own identity/allocator/cache
   * owners. */
#define TAKE(f)                                                                \
  do {                                                                         \
    unsigned char temp[sizeof(shell->f)];                                      \
    memcpy(temp, &shell->f, sizeof(temp));                                     \
    memcpy(&shell->f, &n.f, sizeof(temp));                                     \
    memcpy(&n.f, temp, sizeof(temp));                                          \
  } while (0)
  TAKE(bodyIdPool);
  TAKE(shapeIdPool);
  TAKE(contactIdPool);
  TAKE(jointIdPool);
  TAKE(islandIdPool);
  TAKE(solverSetIdPool);
  TAKE(bodies);
  TAKE(shapes);
  TAKE(fatAABBs);
  TAKE(contacts);
  TAKE(joints);
  TAKE(solverSets);
  TAKE(sensors);
  TAKE(islands);
  TAKE(broadPhase);
  TAKE(constraintGraph);
  TAKE(sensorEndEvents);
  TAKE(contactEndEvents);
  TAKE(gravity);
  TAKE(hitEventThreshold);
  TAKE(restitutionThreshold);
  TAKE(maxLinearSpeed);
  TAKE(contactSpeed);
  TAKE(contactHertz);
  TAKE(contactDampingRatio);
  TAKE(contactRecycleDistance);
  TAKE(restitutionIterations);TAKE(enableRestitutionPropagation);TAKE(isotropicInertiaTolerance);
  TAKE(compoundShapeCount);TAKE(simdWidth);
  TAKE(stepIndex);
  TAKE(splitIslandId);
  TAKE(inv_h);
  TAKE(inv_dt);
  TAKE(endEventArrayIndex);
  TAKE(maxCapacity);
  TAKE(enableSleep);
  TAKE(enableWarmStarting);
  TAKE(enableContinuous);
  TAKE(enableSpeculative);
#undef TAKE
  empty_storage_free(&n);
  *out = id;
  return OGB3_OK;
}
#undef NCOPY

static void native_build_target(uint8_t out[32]) {
  Hash h;
  hash_init(&h);
  static const char domain[] = "ogb3-recovery-native-build-v1";
  hash_add(&h, domain, sizeof(domain));
  hash_add(&h, OGB3_RECOVERY_BUILD_ID, strlen(OGB3_RECOVERY_BUILD_ID));
  hash_add(&h, __VERSION__, strlen(__VERSION__));
  uint64_t fp = ogb3_build_fingerprint();
  uint8_t b[8];
  store_le(b, fp, 8);
  hash_add(&h, b, 8);
  hash_finish(&h, out);
}
static uint64_t native_target(void) {
  uint64_t tag = sizeof(void *) | ((uint64_t)sizeof(float) << 8) |
                 ((uint64_t)sizeof(b3Body) << 16) |
                 ((uint64_t)sizeof(b3JointSim) << 32);
#if defined(__APPLE__)
  tag ^= UINT64_C(0x4150504c00000000);
#elif defined(__linux__)
  tag ^= UINT64_C(0x4c494e5500000000);
#endif
#if defined(__aarch64__) || defined(__arm64__)
  tag ^= UINT64_C(0x000041524d000000);
#elif defined(__x86_64__)
  tag ^= UINT64_C(0x0000583634000000);
#endif
  return tag;
}
uint32_t ogb3_recovery_format(void) { return OGB3_RECOVERY_FORMAT; }
ogb3_status ogb3_recovery_config_default(ogb3_recovery_config *out) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  if (strlen(OGB3_RECOVERY_BUILD_ID) != 64)
    return OGB3_INCOMPATIBLE;
  if (!ogb3_build_fingerprint())
    return OGB3_CAPACITY;
  *out = (ogb3_recovery_config){.profile = 1,
                                .max_bytes = OGB3_RECOVERY_MAX_BYTES,
                                .max_dto_bytes = OGB3_RECOVERY_MAX_DTO_BYTES,
                                .max_bodies = 35,
                                .max_shapes = 35,
                                .max_contacts = 147,
                                .max_joints = 1,
                                .max_sensors = 1,
                                .max_sparse_slots = 512,
                                .max_tree_nodes = 512,
                                .max_manifolds = 147,
                                .max_visitors = 128,
                                .max_pending_sensors = 35,
                                .max_pending_contacts = 147};
  native_build_target(out->build_target);
  return OGB3_OK;
}
static int profile_limits_valid(const ogb3_recovery_config *p) {
  return p->profile && p->max_bytes >= WIRE_HEADER + 16 * SECTIONS &&
         p->max_bytes <= OGB3_RECOVERY_MAX_BYTES && p->max_dto_bytes >= 4096 &&
         p->max_dto_bytes <= OGB3_RECOVERY_MAX_DTO_BYTES && p->max_bodies > 0 &&
         p->max_bodies <= 35 && p->max_shapes > 0 && p->max_shapes <= 35 &&
         p->max_contacts <= 147 && p->max_joints <= 1 && p->max_sensors <= 1 &&
         p->max_sparse_slots >= 35 && p->max_sparse_slots <= 512 &&
         p->max_tree_nodes >= 31 && p->max_tree_nodes <= 512 &&
         p->max_manifolds <= 147 && p->max_visitors <= 128 &&
         p->max_pending_sensors <= 35 && p->max_pending_contacts <= 147;
}
static int asset_valid(const ogb3_recovery_asset *a) {
  if (!a->id || a->reserved || a->kind < OGB3_RECOVERY_BOX ||
      a->kind > OGB3_RECOVERY_CAPSULE)
    return 0;
  float all[] = {a->a.x, a->a.y, a->a.z, a->b.x, a->b.y, a->b.z, a->radius};
  for (unsigned i = 0; i < 7; i++)
    if (!isfinite(all[i]) || fabsf(all[i]) > 32)
      return 0;
  if (a->kind == OGB3_RECOVERY_BOX)
    return a->a.x >= .01f && a->a.y >= .01f && a->a.z >= .01f &&
           zero_bytes(&a->b, sizeof(a->b)) && float_equal(a->radius, 0);
  if (a->kind == OGB3_RECOVERY_SPHERE)
    return a->radius >= .01f && zero_bytes(&a->b, sizeof(a->b));
  return a->radius >= .01f;
}
static void hash_asset(Hash *h, const ogb3_recovery_asset *a) {
  uint8_t b[40];
  store_le(b, a->id, 4);
  store_le(b + 4, a->kind, 4);
  const float f[] = {a->a.x, a->a.y, a->a.z, a->b.x, a->b.y, a->b.z, a->radius};
  for (unsigned i = 0; i < 7; i++) {
    uint32_t x;
    memcpy(&x, f + i, 4);
    store_le(b + 8 + 4 * i, x, 4);
  }
  store_le(b + 36, 0, 4);
  hash_add(h, b, 40);
}
ogb3_status ogb3_recovery_catalog_create(const ogb3_recovery_config *config,
                                         const ogb3_recovery_asset *assets,
                                         uint32_t count_assets,
                                         ogb3_recovery_catalog **out) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  if (!config || !assets || !count_assets ||
      count_assets > OGB3_RECOVERY_MAX_ASSETS || !profile_limits_valid(config))
    return OGB3_INVALID_ARGUMENT;
  ogb3_recovery_config actual;
  ogb3_status status = ogb3_recovery_config_default(&actual);
  if (status)
    return status;
  if (memcmp(actual.build_target, config->build_target, 32))
    return OGB3_INCOMPATIBLE;
  for (uint32_t i = 0; i < count_assets; i++)
    if (!asset_valid(assets + i) || (i && assets[i - 1].id >= assets[i].id))
      return OGB3_INVALID_ARGUMENT;
  if (!memory_admit(0, sizeof(ogb3_recovery_catalog)))
    return OGB3_CAPACITY;
  ogb3_recovery_catalog *p = ogb3_snapshot_internal_alloc(sizeof(*p));
  if (!p)
    return OGB3_OUT_OF_MEMORY;
  memset(p, 0, sizeof(*p));
  p->refs = 1;
  p->limits = *config;
  p->count = count_assets;
  p->fingerprint = ogb3_build_fingerprint();
  p->target = native_target();
  p->identity.solver_format = OGB3_STATE_DUMP_VERSION;
  p->identity.recovery_format = OGB3_RECOVERY_FORMAT;
  p->identity.profile = config->profile;
  memcpy(p->identity.build_target, actual.build_target, 32);
  Hash h;
  hash_init(&h);
  static const char asset_domain[] = "ogb3-primitives-assets-v1";
  hash_add(&h, asset_domain, sizeof(asset_domain));
  for (uint32_t i = 0; i < count_assets; i++) {
    p->assets[i].desc = assets[i];
    hash_asset(&h, assets + i);
    if (assets[i].kind == OGB3_RECOVERY_BOX)
      p->assets[i].box =
          b3MakeBoxHull(assets[i].a.x, assets[i].a.y, assets[i].a.z);
  }
  hash_finish(&h, p->identity.assets);
  hash_init(&h);
  static const char schema[] =
      "ogb3-canonical-solver-v1/logical4/paired-tree-v2/"
      "scalars35674fa92acd8462eef8965de488f13f0010147092c2eec343023954443480e9/"
      "LE/sections12/primitives/revolute/live-u8/gen16-contact32/pool-order/"
      "tree-free-probe/pending-ordered";
  hash_add(&h, schema, sizeof(schema));
  uint64_t limits[] = {config->max_bytes,           config->max_dto_bytes,
                       config->max_bodies,          config->max_shapes,
                       config->max_contacts,        config->max_joints,
                       config->max_sensors,         config->max_sparse_slots,
                       config->max_tree_nodes,      config->max_manifolds,
                       config->max_visitors,        config->max_pending_sensors,
                       config->max_pending_contacts};
  uint8_t b[8];
  for (unsigned i = 0; i < sizeof(limits) / sizeof(limits[0]); i++) {
    store_le(b, limits[i], 8);
    hash_add(&h, b, 8);
  }
  hash_finish(&h, p->identity.solver_schema);
  *out = p;
  return OGB3_OK;
}
/* V2 is separate from the byte-compatible primitive V1 constructor above. */
static ogb3_trusted_geometry asset_geometry(const Asset *a) {
  if (a->desc.kind==OGB3_RECOVERY_BOX)
    return (ogb3_trusted_geometry){OGB3_TRUSTED_HULL,sizeof(a->box),&a->box};
  if (a->desc.kind==OGB3_RECOVERY_HULL && a->geometry)
    return (ogb3_trusted_geometry){OGB3_TRUSTED_HULL,
      (uint32_t)((const b3HullData *)a->geometry->data)->byteCount,a->geometry->data};
  if (a->desc.kind==OGB3_RECOVERY_MESH && a->geometry)
    return (ogb3_trusted_geometry){OGB3_TRUSTED_MESH,
      (uint32_t)((const b3MeshData *)a->geometry->data)->byteCount,a->geometry->data};
  return (ogb3_trusted_geometry){0};
}
static int asset_native_equal(const Asset *a,const Asset *b) {
  ogb3_trusted_geometry x=asset_geometry(a),y=asset_geometry(b);
  if (x.kind && x.kind==y.kind && x.byte_count==y.byte_count)
    if (!memcmp(x.bytes,y.bytes,x.byte_count)) return 1;
  /* Hull construction can discard interior input points or reorder topology.
   * Equal resulting vertex sets describe the same convex surface even when
   * the trusted input payloads differ. Reject the alias; never choose an ID
   * by first-match order. This also catches Box versus authored Hull aliases. */
  if (x.kind==OGB3_TRUSTED_HULL && y.kind==OGB3_TRUSTED_HULL) {
    const b3HullData *ha=x.bytes,*hb=y.bytes;
    if (ha->vertexCount==hb->vertexCount) {
      const b3Vec3 *va=b3GetHullPoints(ha),*vb=b3GetHullPoints(hb);
      int equal=1;
      for (int i=0;i<ha->vertexCount && equal;i++) {
        int found=0;
        for (int j=0;j<hb->vertexCount;j++)
          if (va[i].x==vb[j].x && va[i].y==vb[j].y && va[i].z==vb[j].z) {found=1;break;}
        equal=found;
      }
      if (equal) return 1;
    }
  }
  if (a->desc.kind!=b->desc.kind) return 0;
  if (a->desc.kind==OGB3_RECOVERY_SPHERE)
    return !memcmp(&a->desc.a,&b->desc.a,sizeof(a->desc.a)) && float_equal(a->desc.radius,b->desc.radius);
  if (a->desc.kind==OGB3_RECOVERY_CAPSULE)
    return float_equal(a->desc.radius,b->desc.radius) &&
           ((!memcmp(&a->desc.a,&b->desc.a,sizeof(a->desc.a)) && !memcmp(&a->desc.b,&b->desc.b,sizeof(a->desc.b))) ||
            (!memcmp(&a->desc.a,&b->desc.b,sizeof(a->desc.a)) && !memcmp(&a->desc.b,&b->desc.a,sizeof(a->desc.b))));
  return 0;
}
static ogb3_status catalog_create_authored(uint32_t format, const ogb3_recovery_config *config,
                                           const ogb3_recovery_asset_v2 *assets,
                                           uint32_t count_assets,
                                           ogb3_recovery_catalog **out) {
  if (!out) return OGB3_INVALID_ARGUMENT;
  *out=NULL;
  if (!config || !assets || !count_assets || count_assets>OGB3_RECOVERY_MAX_ASSETS || !profile_limits_valid(config))
    return OGB3_INVALID_ARGUMENT;
  ogb3_recovery_config actual;
  ogb3_status status=ogb3_recovery_config_default(&actual);
  if (status) return status;
  if (memcmp(actual.build_target,config->build_target,32)) return OGB3_INCOMPATIBLE;
  uint64_t input_bytes=0,reserve=sizeof(ogb3_recovery_catalog)+RECOVERY_NATIVE_RESERVE;
  for (uint32_t i=0;i<count_assets;i++) {
    uint64_t bytes=0;
    status=ogb3_authoring_asset_validate(assets+i,&bytes);
    if (status) return status;
    if ((i && assets[i-1].base.id>=assets[i].base.id) ||
        (assets[i].base.kind<=OGB3_RECOVERY_CAPSULE && !asset_valid(&assets[i].base)))
      return OGB3_INVALID_ARGUMENT;
    if (bytes>config->max_dto_bytes || input_bytes>config->max_dto_bytes-bytes) return OGB3_CAPACITY;
    input_bytes+=bytes;
    /* Conservative construction reserve includes BVH/edge-table scratch,
     * native geometry, and copied call arrays; it is not an OOM guarantee. */
    reserve+=bytes+(uint64_t)assets[i].vertex_count*64+(uint64_t)assets[i].triangle_count*1024;
  }
  if (!memory_admit(0,reserve)) return OGB3_CAPACITY;
  ogb3_recovery_catalog *p=ogb3_snapshot_internal_alloc(sizeof(*p));
  if (!p) return OGB3_OUT_OF_MEMORY;
  memset(p,0,sizeof(*p));p->refs=1;p->count=count_assets;p->limits=*config;
  p->fingerprint=ogb3_build_fingerprint();p->target=native_target();
  p->identity.solver_format=OGB3_STATE_DUMP_VERSION;
  p->identity.recovery_format=format;
  p->identity.profile=config->profile;memcpy(p->identity.build_target,actual.build_target,32);
  Hash h;hash_init(&h);static const char asset_domain[]="ogb3-authored-assets-v2";
  hash_add(&h,asset_domain,sizeof(asset_domain));
  for (uint32_t i=0;i<count_assets;i++) {
    const ogb3_recovery_asset_v2 *v=assets+i;Asset *a=p->assets+i;
    a->desc=v->base;a->vertex_count=v->vertex_count;a->triangle_count=v->triangle_count;
    if (v->base.kind==OGB3_RECOVERY_BOX) a->box=b3MakeBoxHull(v->base.a.x,v->base.a.y,v->base.a.z);
    if (v->vertex_count) {
      a->vertices=ogb3_snapshot_internal_alloc((size_t)v->vertex_count*sizeof(*a->vertices));
      if (!a->vertices) {status=OGB3_OUT_OF_MEMORY;goto fail;}
      memcpy(a->vertices,v->vertices,(size_t)v->vertex_count*sizeof(*a->vertices));
    }
    if (v->triangle_count) {
      a->indices=ogb3_snapshot_internal_alloc((size_t)v->triangle_count*3*sizeof(*a->indices));
      if (!a->indices) {status=OGB3_OUT_OF_MEMORY;goto fail;}
      memcpy(a->indices,v->indices,(size_t)v->triangle_count*3*sizeof(*a->indices));
    }
    if (v->base.kind==OGB3_RECOVERY_HULL)
      status=ogb3_geometry_hull(a->vertices,a->vertex_count,&a->geometry);
    else if (v->base.kind==OGB3_RECOVERY_MESH)
      status=ogb3_geometry_mesh(a->vertices,a->vertex_count,a->indices,a->triangle_count,&a->geometry);
    if (status) goto fail;
    for (uint32_t j=0;j<i;j++) if (asset_native_equal(a,p->assets+j)) {status=OGB3_INVALID_ARGUMENT;goto fail;}
    hash_asset(&h,&a->desc);
    uint8_t bytes[8];store_le(bytes,a->vertex_count,4);store_le(bytes+4,a->triangle_count,4);hash_add(&h,bytes,8);
    for (uint32_t j=0;j<a->vertex_count;j++) {
      const float xyz[]={a->vertices[j].x,a->vertices[j].y,a->vertices[j].z};
      for (unsigned k=0;k<3;k++) {uint32_t bits;memcpy(&bits,xyz+k,4);store_le(bytes,bits,4);hash_add(&h,bytes,4);}
    }
    for (uint32_t j=0;j<a->triangle_count*3;j++) {store_le(bytes,a->indices[j],4);hash_add(&h,bytes,4);}
  }
  hash_finish(&h,p->identity.assets);hash_init(&h);
  static const char schema[]="ogb3-canonical-solver-authored-v2/logical4/paired-tree-v2/LE/sections12/hull-mesh-trustedrefs/mesh-cache-manifolds/full-verify-reencode";
  static const char motion_schema[]="ogb3-canonical-solver-motion-v3/logical4/paired-tree-v2/LE/sections12/hull-mesh-trustedrefs/mesh-cache-manifolds/all-seven-joint-unions/scalars35674fa92acd8462eef8965de488f13f0010147092c2eec343023954443480e9/full-verify-reencode";
  if(format==OGB3_MOTION_RECOVERY_FORMAT)hash_add(&h,motion_schema,sizeof(motion_schema));
  else hash_add(&h,schema,sizeof(schema));
  const uint64_t limits[]={config->max_bytes,config->max_dto_bytes,config->max_bodies,config->max_shapes,
    config->max_contacts,config->max_joints,config->max_sensors,config->max_sparse_slots,config->max_tree_nodes,
    config->max_manifolds,config->max_visitors,config->max_pending_sensors,config->max_pending_contacts};
  for (unsigned i=0;i<sizeof(limits)/sizeof(limits[0]);i++) {uint8_t bytes[8];store_le(bytes,limits[i],8);hash_add(&h,bytes,8);}
  hash_finish(&h,p->identity.solver_schema);
  if (!memory_admit(0,0)) {status=OGB3_CAPACITY;goto fail;}
  *out=p;return OGB3_OK;
fail:
  ogb3_recovery_catalog_release(p);return status;
}
ogb3_status ogb3_recovery_catalog_create_v2(const ogb3_recovery_config *c,const ogb3_recovery_asset_v2 *a,uint32_t n,ogb3_recovery_catalog **out) {
  return catalog_create_authored(OGB3_AUTHORING_RECOVERY_FORMAT,c,a,n,out);
}
ogb3_status ogb3_recovery_catalog_create_v3(const ogb3_recovery_config *c,const ogb3_recovery_asset_v2 *a,uint32_t n,ogb3_recovery_catalog **out) {
  return catalog_create_authored(OGB3_MOTION_RECOVERY_FORMAT,c,a,n,out);
}
ogb3_status ogb3_catalog_asset_lookup(const ogb3_recovery_catalog *p,uint32_t id,
                                     ogb3_catalog_asset_view *out) {
  if (!p || !id || !out) return OGB3_INVALID_ARGUMENT;
  for (uint32_t i=0;i<p->count;i++) if (p->assets[i].desc.id==id) {
    const Asset *a=p->assets+i;
    *out=(ogb3_catalog_asset_view){id,a->desc.kind,a->desc.a,a->desc.b,a->desc.radius,a->geometry};
    return OGB3_OK;
  }
  return OGB3_INVALID_ARGUMENT;
}
ogb3_status ogb3_recovery_catalog_clone(const ogb3_recovery_catalog *p,
                                        ogb3_recovery_catalog **out) {
  if (!out || !p)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  if (p->refs == UINT32_MAX)
    return OGB3_CAPACITY;
  ((ogb3_recovery_catalog *)p)->refs++;
  *out = (ogb3_recovery_catalog *)p;
  return OGB3_OK;
}
void ogb3_recovery_catalog_release(ogb3_recovery_catalog *p) {
  if (p && !--p->refs) {
    for (uint32_t i=0;i<p->count;i++) {
      ogb3_geometry_release(p->assets[i].geometry);
      ogb3_snapshot_internal_free(p->assets[i].vertices);
      ogb3_snapshot_internal_free(p->assets[i].indices);
    }
    ogb3_snapshot_internal_free(p);
  }
}
ogb3_status ogb3_recovery_identity_get(const ogb3_recovery_catalog *p,
                                       ogb3_recovery_identity *out) {
  if (!p || !out)
    return OGB3_INVALID_ARGUMENT;
  *out = p->identity;
  return OGB3_OK;
}
static void write_header(uint8_t *out, const ogb3_recovery_catalog *p,
                         uint64_t bytes) {
  memset(out, 0, WIRE_HEADER);
  memcpy(out, "OGB3REC", 7);
  store_le(out + 8, p->identity.recovery_format, 4);
  store_le(out + 12, OGB3_STATE_DUMP_VERSION, 4);
  store_le(out + 16, WIRE_HEADER, 4);
  store_le(out + 20, SECTIONS, 4);
  store_le(out + 24, p->identity.profile, 8);
  store_le(out + 32, bytes, 8);
  store_le(out + 40, p->fingerprint, 8);
  memcpy(out + 48, p->identity.build_target, 32);
  memcpy(out + 80, p->identity.assets, 32);
  memcpy(out + 112, p->identity.solver_schema, 32);
  digest(out + WIRE_HEADER, (size_t)(bytes - WIRE_HEADER), out + 144);
  store_le(out + 176, p->target, 8);
}
static ogb3_status read_header(const ogb3_recovery_catalog *p,
                               const uint8_t *data, uint64_t size) {
  if (size < WIRE_HEADER || size > p->limits.max_bytes)
    return OGB3_CAPACITY;
  if (memcmp(data, "OGB3REC", 8) ||
      load_le(data + 8, 4) != p->identity.recovery_format ||
      load_le(data + 12, 4) != OGB3_STATE_DUMP_VERSION ||
      load_le(data + 16, 4) != WIRE_HEADER ||
      load_le(data + 20, 4) != SECTIONS || load_le(data + 32, 8) != size ||
      !zero_bytes(data + 184, 8))
    return OGB3_CORRUPT;
  if (load_le(data + 24, 8) != p->identity.profile ||
      load_le(data + 40, 8) != p->fingerprint ||
      load_le(data + 176, 8) != p->target ||
      memcmp(data + 48, p->identity.build_target, 32) ||
      memcmp(data + 80, p->identity.assets, 32) ||
      memcmp(data + 112, p->identity.solver_schema, 32))
    return OGB3_INCOMPATIBLE;
  uint8_t sha[32];
  digest(data + WIRE_HEADER, (size_t)(size - WIRE_HEADER), sha);
  return memcmp(sha, data + 144, 32) ? OGB3_CORRUPT : OGB3_OK;
}
static ogb3_status encode_world(const ogb3_recovery_catalog *p, b3World *w,
                                uint8_t *out, uint64_t cap, uint64_t *required,
                                uint64_t external,
                                ogb3_recovery_diagnostic *diagnostic) {
  OGB3_OBS_BEGIN(observe_canonical_validate, OGB3_OBS_CANONICAL_VALIDATE_V1);
  for (int i = 0; i < w->shapes.count; i++)
    if (w->shapes.data[i].id == i) {
      b3Shape *s = w->shapes.data + i;
      if ((s->type != b3_sphereShape && s->type != b3_capsuleShape &&
           s->type != b3_hullShape &&
           !(p->identity.recovery_format >= OGB3_AUTHORING_RECOVERY_FORMAT && s->type == b3_meshShape)) ||
          s->materialCount != 1 || s->materials || !shape_asset(p, s))
        OGB3_OBS_RETURN(observe_canonical_validate, OGB3_UNSUPPORTED);
    }
  for (int i = 0; i < w->joints.count; i++)
    if (w->joints.data[i].jointId == i &&
        !joint_type_ok(&(Codec){.catalog=p},w->joints.data[i].type))
      OGB3_OBS_RETURN(observe_canonical_validate, OGB3_UNSUPPORTED);
  Codec check = {.catalog = p, .external = external, .diagnostic = diagnostic};
  if (!validate_world(&check, w)) {
    ogb3_status s = check.status;
    dto_free(&check);
    OGB3_OBS_RETURN(observe_canonical_validate, s);
  }
  dto_free(&check);
  OGB3_OBS_END(observe_canonical_validate, OGB3_OK);
  OGB3_OBS_BEGIN(observe_canonical_count, OGB3_OBS_CANONICAL_COUNT_V1);
  Codec count_only = {
      .catalog = p, .external = external, .diagnostic = diagnostic};
  wire_world(&count_only, w);
  if (count_only.status)
    OGB3_OBS_RETURN(observe_canonical_count, count_only.status);
  if (count_only.pos > UINT64_MAX - WIRE_HEADER ||
      count_only.pos + WIRE_HEADER > p->limits.max_bytes)
    OGB3_OBS_RETURN(observe_canonical_count, OGB3_CAPACITY);
  *required = count_only.pos + WIRE_HEADER;
  OGB3_OBS_END(observe_canonical_count, OGB3_OK);
  if (!out)
    return OGB3_OK;
  if (cap < *required)
    return OGB3_CAPACITY;
  OGB3_OBS_BEGIN(observe_canonical_emit, OGB3_OBS_CANONICAL_EMIT_V1);
  Codec writer = {.catalog = p,
                  .data = out + WIRE_HEADER,
                  .size = cap - WIRE_HEADER,
                  .diagnostic = diagnostic};
  wire_world(&writer, w);
  if (writer.status)
    OGB3_OBS_RETURN(observe_canonical_emit, writer.status);
  write_header(out, p, *required);
  OGB3_OBS_RETURN(observe_canonical_emit, OGB3_OK);
}
ogb3_status ogb3_recovery_world_admit(const ogb3_recovery_catalog *p,
                                      ogb3_world world, uint64_t external,
                                      uint64_t *required,
                                      ogb3_recovery_diagnostic *diagnostic) {
  OGB3_OBS_BEGIN(observe_admit, OGB3_OBS_ADMISSION_WORLD_V1);
  if (diagnostic)
    memset(diagnostic, 0, sizeof(*diagnostic));
  if (!required)
    OGB3_OBS_RETURN(observe_admit, OGB3_INVALID_ARGUMENT);
  *required = 0;
  if (!p)
    OGB3_OBS_RETURN(observe_admit, OGB3_INVALID_ARGUMENT);
  uint32_t valid = 0;
  ogb3_status status = ogb3_world_valid(world, &valid);
  if (status)
    OGB3_OBS_RETURN(observe_admit, status);
  if (!valid)
    OGB3_OBS_RETURN(observe_admit, OGB3_INVALID_HANDLE);
  b3WorldId id;
  memcpy(&id, &world, sizeof(id));
  b3World *w = b3GetWorldFromId(id);
  if (w->locked)
    OGB3_OBS_RETURN(observe_admit, OGB3_INVALID_ARGUMENT);
  if (!memory_admit(external, p->limits.max_dto_bytes))
    OGB3_OBS_RETURN(observe_admit, OGB3_CAPACITY);
  OGB3_OBS_RETURN(observe_admit, encode_world(p, w, NULL, 0, required, external, diagnostic));
}
ogb3_status ogb3_recovery_write(const ogb3_recovery_catalog *p,
                                const ogb3_snapshot *s, uint8_t *out,
                                uint64_t cap, uint64_t *required,
                                ogb3_recovery_diagnostic *diagnostic) {
  OGB3_OBS_BEGIN(observe_write, OGB3_OBS_RECOVERY_WRITE_V1);
  if (diagnostic)
    memset(diagnostic, 0, sizeof(*diagnostic));
  if (!p || !s || !required || (!out && cap))
    OGB3_OBS_RETURN(observe_write, OGB3_INVALID_ARGUMENT);
  ogb3_trusted_geometry geometry[OGB3_RECOVERY_MAX_ASSETS];
  uint32_t geometry_count = 0;
  for (uint32_t i = 0; i < p->count; ++i)
    if (p->assets[i].desc.kind == OGB3_RECOVERY_BOX)
      geometry[geometry_count++] = (ogb3_trusted_geometry){OGB3_TRUSTED_HULL,sizeof(b3BoxHull),&p->assets[i].box};
    else if (p->assets[i].desc.kind == OGB3_RECOVERY_HULL)
      geometry[geometry_count++] = (ogb3_trusted_geometry){OGB3_TRUSTED_HULL,
        (uint32_t)((b3HullData *)p->assets[i].geometry->data)->byteCount,p->assets[i].geometry->data};
    else if (p->assets[i].desc.kind == OGB3_RECOVERY_MESH)
      geometry[geometry_count++] = (ogb3_trusted_geometry){OGB3_TRUSTED_MESH,
        (uint32_t)((b3MeshData *)p->assets[i].geometry->data)->byteCount,p->assets[i].geometry->data};
  ogb3_status gate = ogb3_snapshot_recovery_preflight(
      s, geometry, geometry_count, p->limits.max_bodies,
      OGB3_RECOVERY_MAX_SOURCE_IMAGE_BYTES);
  if (gate)
    OGB3_OBS_RETURN(observe_write, gate);
  if (!memory_admit(0, OGB3_RECOVERY_WRITE_RESERVE_BYTES))
    OGB3_OBS_RETURN(observe_write, OGB3_CAPACITY);
  ogb3_world_def def;
  ogb3_world world = 0;
  ogb3_status status = ogb3_world_def_default(&def);
  if (!status)
    status = ogb3_world_create(&def, &world);
  if (status)
    OGB3_OBS_RETURN(observe_write, status);
  status = ogb3_snapshot_restore(world, s);
  if (!status) {
    b3WorldId id;
    memcpy(&id, &world, sizeof(id));
    status = encode_world(p, b3GetWorldFromId(id), out, cap, required, 0,
                          diagnostic);
  }
  ogb3_world_destroy(world);
  OGB3_OBS_RETURN(observe_write, status);
}
ogb3_status ogb3_recovery_read(const ogb3_recovery_catalog *p,
                               const uint8_t *data, uint64_t size,
                               uint64_t external, ogb3_snapshot **out,
                               ogb3_recovery_diagnostic *diagnostic) {
  OGB3_OBS_BEGIN(observe_read, OGB3_OBS_RECOVERY_READ_V1);
  if (diagnostic)
    memset(diagnostic, 0, sizeof(*diagnostic));
  if (!out)
    OGB3_OBS_RETURN(observe_read, OGB3_INVALID_ARGUMENT);
  *out = NULL;
  if (!p || !data)
    OGB3_OBS_RETURN(observe_read, OGB3_INVALID_ARGUMENT);
  OGB3_OBS_BEGIN(observe_parse, OGB3_OBS_RECOVERY_PARSE_VALIDATE_V1);
  ogb3_status status = read_header(p, data, size);
  if (status) {
    OGB3_OBS_END(observe_parse, status);
    OGB3_OBS_RETURN(observe_read, status);
  }
  if (!memory_admit(external,
                    p->limits.max_dto_bytes + RECOVERY_NATIVE_RESERVE)) {
    OGB3_OBS_END(observe_parse, OGB3_CAPACITY);
    OGB3_OBS_RETURN(observe_read, OGB3_CAPACITY);
  }
  Codec reader = {.catalog = p,
                  .data = (uint8_t *)data + WIRE_HEADER,
                  .size = size - WIRE_HEADER,
                  .external = external,
                  .reading = 1,
                  .diagnostic = diagnostic};
  b3World dto = {0};
  wire_world(&reader, &dto);
  if (!reader.status && reader.pos != reader.size)
    reject(&reader, OGB3_CORRUPT, 400);
  if (!reader.status)
    validate_world(&reader, &dto);
  if (reader.status) {
    status = reader.status;
    dto_free(&reader);
    OGB3_OBS_END(observe_parse, status);
    OGB3_OBS_RETURN(observe_read, status);
  }
  OGB3_OBS_END(observe_parse, OGB3_OK);
  ogb3_world world = 0;
  OGB3_OBS_BEGIN(observe_build, OGB3_OBS_RECOVERY_BUILD_V1);
  status = build_native(&reader, &dto, &world);
  OGB3_OBS_END(observe_build, status);
  if (!status) {
    b3WorldId id;
    memcpy(&id, &world, sizeof(id));
    OGB3_OBS_BEGIN(observe_verify, OGB3_OBS_RECOVERY_VERIFY_REENCODE_V1);
    uint64_t required = 0;
    status = encode_world(p, b3GetWorldFromId(id), NULL, 0, &required, external,
                          diagnostic);
    uint8_t *check = NULL;
    if (!status) {
      if (!memory_admit(external, required))
        status = OGB3_CAPACITY;
      else
        check = ogb3_snapshot_internal_alloc((size_t)required);
      if (!status && !check)
        status = OGB3_OUT_OF_MEMORY;
    }
    if (!status)
      status = encode_world(p, b3GetWorldFromId(id), check, required, &required,
                            external, diagnostic);
    if (!status && (required != size || memcmp(check, data, (size_t)size)))
      status = OGB3_CORRUPT;
    ogb3_snapshot_internal_free(check);
    OGB3_OBS_END(observe_verify, status);
    if (!status && !memory_admit(external, RECOVERY_NATIVE_RESERVE))
      status = OGB3_CAPACITY;
    if (!status)
      status = ogb3_snapshot_capture(world, out);
    if (!status && !memory_admit(external, 0)) {
      ogb3_snapshot_release(*out);
      *out = NULL;
      status = OGB3_CAPACITY;
    }
  }
  if (world)
    ogb3_world_destroy(world);
  dto_free(&reader);
  OGB3_OBS_RETURN(observe_read, status);
}

void ogb3_snapshot_local_info(const ogb3_snapshot *, uint64_t *, uint64_t *,
                              uint64_t *, uint32_t *, uint64_t *, uint64_t *,
                              uint64_t *);
ogb3_status ogb3_recovery_read_info(
    const ogb3_recovery_catalog *catalog, const uint8_t *data, uint64_t size,
    uint64_t external, ogb3_snapshot **out, uint64_t *used, uint64_t *capacity,
    uint64_t *geometry, uint32_t *count, uint64_t *normalized,
    uint64_t *wrapper, uint64_t *native, ogb3_recovery_diagnostic *diagnostic) {
  if (diagnostic)
    memset(diagnostic, 0, sizeof(*diagnostic));
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  if (!used || !capacity || !geometry || !count || !normalized || !wrapper ||
      !native)
    return OGB3_INVALID_ARGUMENT;
  ogb3_snapshot *local = NULL;
  ogb3_status status =
      ogb3_recovery_read(catalog, data, size, external, &local, diagnostic);
  if (status) {
    if (local)
      ogb3_snapshot_release(local);
    return status;
  }
  ogb3_snapshot_local_info(local, used, capacity, geometry, count, normalized,
                           wrapper, native);
  *out = local;
  return OGB3_OK;
}

ogb3_status ogb3_recovery_layout(uint32_t type, uint32_t field, uint32_t *size,
                                 uint32_t *align, uint32_t *offset) {
  if (!size || !align || !offset)
    return OGB3_INVALID_ARGUMENT;
#define LAYOUT(T, ...)                                                         \
  do {                                                                         \
    static const uint32_t offsets[] = {__VA_ARGS__};                           \
    *size = sizeof(T);                                                         \
    *align = _Alignof(T);                                                      \
    if (field == UINT32_MAX) {                                                 \
      *offset = 0;                                                             \
      return OGB3_OK;                                                          \
    }                                                                          \
    if (field >= sizeof(offsets) / sizeof(offsets[0]))                         \
      return OGB3_INVALID_ARGUMENT;                                            \
    *offset = offsets[field];                                                  \
    return OGB3_OK;                                                            \
  } while (0)
  switch (type) {
  case 1:
    LAYOUT(ogb3_recovery_config, offsetof(ogb3_recovery_config, profile),
           offsetof(ogb3_recovery_config, build_target),
           offsetof(ogb3_recovery_config, max_bytes),
           offsetof(ogb3_recovery_config, max_dto_bytes),
           offsetof(ogb3_recovery_config, max_bodies),
           offsetof(ogb3_recovery_config, max_shapes),
           offsetof(ogb3_recovery_config, max_contacts),
           offsetof(ogb3_recovery_config, max_joints),
           offsetof(ogb3_recovery_config, max_sensors),
           offsetof(ogb3_recovery_config, max_sparse_slots),
           offsetof(ogb3_recovery_config, max_tree_nodes),
           offsetof(ogb3_recovery_config, max_manifolds),
           offsetof(ogb3_recovery_config, max_visitors),
           offsetof(ogb3_recovery_config, max_pending_sensors),
           offsetof(ogb3_recovery_config, max_pending_contacts));
  case 2:
    LAYOUT(ogb3_recovery_asset, offsetof(ogb3_recovery_asset, id),
           offsetof(ogb3_recovery_asset, kind),
           offsetof(ogb3_recovery_asset, a), offsetof(ogb3_recovery_asset, b),
           offsetof(ogb3_recovery_asset, radius),
           offsetof(ogb3_recovery_asset, reserved));
  case 3:
    LAYOUT(ogb3_recovery_identity,
           offsetof(ogb3_recovery_identity, solver_format),
           offsetof(ogb3_recovery_identity, recovery_format),
           offsetof(ogb3_recovery_identity, profile),
           offsetof(ogb3_recovery_identity, build_target),
           offsetof(ogb3_recovery_identity, assets),
           offsetof(ogb3_recovery_identity, solver_schema));
  case 4:
    LAYOUT(ogb3_recovery_diagnostic, offsetof(ogb3_recovery_diagnostic, offset),
           offsetof(ogb3_recovery_diagnostic, section),
           offsetof(ogb3_recovery_diagnostic, record),
           offsetof(ogb3_recovery_diagnostic, field),
           offsetof(ogb3_recovery_diagnostic, reason));
  default:
    return OGB3_INVALID_ARGUMENT;
  }
#undef LAYOUT
}

#ifdef OGB3_TESTING
void ogb3_recovery_test_rehash(uint8_t *data, uint64_t size) {
  if (size >= WIRE_HEADER)
    digest(data + WIRE_HEADER, (size_t)(size - WIRE_HEADER), data + 144);
}
/* Produce grammar-correct, rechecksummed semantic mutations from a valid DTO.
 * This test-only writer deliberately bypasses validation; public read does not.
 */
ogb3_status ogb3_recovery_test_mutate(const ogb3_recovery_catalog *p,
                                      const uint8_t *input, uint64_t size,
                                      uint32_t code, uint8_t *out,
                                      uint64_t capacity, uint64_t *required) {
  Codec c = {.catalog = p,
             .data = (uint8_t *)input + WIRE_HEADER,
             .size = size - WIRE_HEADER,
             .reading = 1};
  b3World w = {0};
  ogb3_status s = read_header(p, input, size);
  if (s)
    return s;
  wire_world(&c, &w);
  if (c.status) {
    s = c.status;
    dto_free(&c);
    return s;
  }
  int body = -1, shape = -1, contact = -1;
  for (int i = 0; i < w.bodies.count; i++)
    if (live_body(&w, i)) {
      body = i;
      break;
    }
  for (int i = 0; i < w.shapes.count; i++)
    if (live_shape(&w, i)) {
      shape = i;
      break;
    }
  for (int i = 0; i < w.contacts.count; i++)
    if (live_contact(&w, i)) {
      contact = i;
      break;
    }
  switch (code) {
  case 60:case 61:case 62:case 63:case 64:case 65: {
    b3JointSim *joint=NULL;
    for(int i=0;i<B3_GRAPH_COLOR_COUNT;i++)if(w.constraintGraph.colors[i].jointSims.count)joint=w.constraintGraph.colors[i].jointSims.data;
    for(int i=0;i<w.solverSets.count&&!joint;i++)if(w.solverSets.data[i].jointSims.count)joint=w.solverSets.data[i].jointSims.data;
    if(!joint){s=OGB3_UNSUPPORTED;break;}
    if(code==61)joint->localFrameA.q=(b3Quat){0};
    if(code==62)joint->bodyIdA=joint->bodyIdB;
    if(code==63)joint->constraintDampingRatio=-1;
    if(code==64)w.joints.data[joint->jointId].type=b3_filterJoint;
    if(code==65){
      if(joint->type!=b3_distanceJoint){s=OGB3_UNSUPPORTED;break;}
      joint->distanceJoint.minLength=1; joint->distanceJoint.maxLength=0;
    }
    if(code==60)switch(joint->type){
    case b3_revoluteJoint:joint->revoluteJoint.hertz=-1;break;
    case b3_distanceJoint:joint->distanceJoint.hertz=-1;break;
    case b3_motorJoint:joint->motorJoint.linearHertz=-1;break;
    case b3_prismaticJoint:joint->prismaticJoint.hertz=-1;break;
    case b3_sphericalJoint:joint->sphericalJoint.hertz=-1;break;
    case b3_weldJoint:joint->weldJoint.linearHertz=-1;break;
    case b3_wheelJoint:joint->wheelJoint.suspensionHertz=-1;break;
    default:s=OGB3_UNSUPPORTED;break;
    }
    break;
  }
  case 40:
  case 41:
  case 42: {
    b3Contact *mesh = NULL;
    for (int i=0;i<w.contacts.count;i++)
      if (live_contact(&w,i) && (w.contacts.data[i].flags & b3_simMeshContact) &&
          w.contacts.data[i].meshContact.triangleCache.count) {mesh=w.contacts.data+i;break;}
    if (!mesh) {s=OGB3_UNSUPPORTED;break;}
    if (code==40) mesh->meshContact.triangleCache.data[0].triangleIndex=INT_MAX;
    if (code==41) mesh->meshContact.triangleCache.data[0].triangleIndex=-1;
    if (code==42) mesh->meshContact.queryBounds.lowerBound.x=mesh->meshContact.queryBounds.upperBound.x+1;
    break;
  }
  case 43: {
    b3Contact *mesh=NULL;
    for (int i=0;i<w.contacts.count;i++)
      if (live_contact(&w,i) && (w.contacts.data[i].flags & b3_simMeshContact) &&
          w.contacts.data[i].manifoldCount && w.contacts.data[i].manifolds[0].pointCount) {mesh=w.contacts.data+i;break;}
    if (!mesh) {s=OGB3_UNSUPPORTED;break;}
    mesh->manifolds[0].points[0].triangleIndex=INT_MAX;
    break;
  }
  case 1:
    w.shapes.data[shape].bodyId = w.bodies.count;
    break;
  case 2:
    w.bodies.data[body].type = (b3BodyType)99;
    break;
  case 3:
    w.bodyIdPool.freeArray.count = 1;
    w.bodyIdPool.freeArray.data = dto_alloc(&c, sizeof(int));
    if (!c.status)
      w.bodyIdPool.freeArray.data[0] = body;
    break;
  case 4:
    w.contacts.data[contact].edges[0].bodyId = w.bodies.count;
    break;
  case 5:
    for (int i = 0; i < B3_OVERFLOW_INDEX; i++)
      if (w.constraintGraph.colors[i].convexContacts.count ||
          w.constraintGraph.colors[i].jointSims.count) {
        w.constraintGraph.colors[i].bodySet.blockCount = 0;
        break;
      }
    break;
  case 6: {
    int id = -1;
    for (int i = 0; i < w.shapes.count; i++)
      if (live_shape(&w, i) &&
          B3_PROXY_TYPE(w.shapes.data[i].proxyKey) == b3_dynamicBody) {
        id = w.shapes.data[i].proxyKey;
        break;
      }
    if (id < 0) {
      s = OGB3_UNSUPPORTED;
      break;
    }
    b3DynamicTree*t=w.broadPhase.trees+b3_dynamicBody;
    int proxy=B3_PROXY_ID(id),node=t->proxies[proxy].node;
    if(node==0){s=OGB3_UNSUPPORTED;break;}
    t->nodes[node].flagIndex|=B3_MOVED_NODE;
    t->nodes[0].flagIndex&=~B3_MOVED_NODE;
    break;
  }
  case 7: {
    int key = w.shapes.data[shape].proxyKey;
    w.broadPhase.trees[B3_PROXY_TYPE(key)]
        .proxies[B3_PROXY_ID(key)]
        .categoryBits ^= 2;
    break;
  }
  case 8:
  case 9:
  case 10: {
    b3SATCache *q = &w.contacts.data[contact].convexContact.cache.satCache;
    q->type = code == 8 ? b3_faceAxisA : b3_edgePairAxis;
    q->indexA = code == 8 ? 6 : code == 9 ? 23 : 1;
    q->indexB = 0;
    break;
  }
  case 11:
    for (int i = 1; i < 3; i++) {
      b3DynamicTree *t = w.broadPhase.trees + i;
      if(!b3IsEmptyNode(t->nodes)&&!b3IsLeaf(t->nodes)){
        /* An internal moved marker is legal pending work in the new tree. */
        t->nodes[0].flagIndex|=B3_MOVED_NODE;
        break;
      }
    }
    break;
  case 12:
    w.shapes.data[w.bodies.data[body].headShapeId].nextShapeId =
        w.bodies.data[body].headShapeId;
    break;
  case 13:
    if (w.sensors.count && w.sensors.data[0].overlaps2.count > 1) {
      b3Visitor *v = w.sensors.data[0].overlaps2.data;
      b3Visitor t = v[0];
      v[0] = v[1];
      v[1] = t;
    } else
      s = OGB3_UNSUPPORTED;
    break;
  case 14:
    w.solverSets.data[2].setIndex = -1;
    break;
  case 15:
    w.broadPhase.trees[0].pairFreeList=0; /* root cannot be a free sibling pair */
    break;
  case 20:
    /* Empty kinematic tree falsely claims a live proxy; bounds remain encodable. */
    w.broadPhase.trees[1].proxyCount=1;
    break;
  case 21:
  case 22:
  case 23:
  case 24: {
    b3JointSim *joint = NULL;
    for (int i = 0; i < B3_GRAPH_COLOR_COUNT; ++i)
      if (w.constraintGraph.colors[i].jointSims.count)
        joint = w.constraintGraph.colors[i].jointSims.data;
    if (!joint) {
      s = OGB3_UNSUPPORTED;
      break;
    }
    if (code == 21)
      joint->revoluteJoint.maxMotorTorque = -1;
    if (code == 22)
      joint->revoluteJoint.hertz = -1;
    if (code == 24)
      joint->revoluteJoint.dampingRatio = -1;
    if (code == 23) {
      joint->revoluteJoint.enableLimit = true;
      joint->revoluteJoint.lowerAngle = 1;
      joint->revoluteJoint.upperAngle = -1;
    }
    break;
  }
  case 19:
    w.contacts.data[contact].edges[1].bodyId =
        w.contacts.data[contact].edges[0].bodyId;
    w.shapes.data[w.contacts.data[contact].shapeIdB].bodyId =
        w.contacts.data[contact].edges[0].bodyId;
    break;
  case 17:
    for (int i = 0; i < w.contacts.count; ++i)
      if (live_contact(&w, i) && w.contacts.data[i].manifoldCount) {
        contact = i;
        break;
      }
    w.contacts.data[contact].manifoldCount = 0;
    break;
  case 18:
    w.contacts.data[contact].flags |= b3_relativeTransformValid;
    w.contacts.data[contact].cachedRelativePose.q = (b3Quat){0};
    break;
  case 16:
    /* Static moved markers are now legitimate. Corrupt its root backlink instead. */
    w.broadPhase.trees[0].parents[0]=0;
    break;
  default:
    s = OGB3_INVALID_ARGUMENT;
  }
  if (!s && !c.status) {
    Codec n = {.catalog = p};
    wire_world(&n, &w);
    s = n.status;
    if (!s) {
      *required = n.pos + WIRE_HEADER;
      if (capacity < *required)
        s = OGB3_CAPACITY;
      else {
        Codec writer = {.catalog = p,
                        .data = out + WIRE_HEADER,
                        .size = capacity - WIRE_HEADER};
        wire_world(&writer, &w);
        s = writer.status;
        if (!s)
          write_header(out, p, *required);
      }
    }
  } else if (c.status)
    s = c.status;
  dto_free(&c);
  return s;
}
#endif
