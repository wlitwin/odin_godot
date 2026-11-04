/* Scalar state comparison for Box3D 33626332. Private ABI stays in C.
 * The serializer's POD storage is deliberately not used as a digest. */
#include "state_dump.h"
#include "state_dump_internal.h"
#include "body.h"
#include "contact.h"
#include "joint.h"
#include "shape.h"
#include "island.h"
#include "sensor.h"
#include "physics_world.h"
#include "solver_set.h"
#include "table.h"
#include "dynamic_tree.h"
#include "compound.h"
#include "recording.h"
#include "box3d/box3d.h"
#include "box3d/collision.h"
#include <stdlib.h>
#include <string.h>

/* Shared wrapper domain: public snapshot_allocation_stats includes this temporary. */
void* ogb3_snapshot_internal_alloc(size_t);
void ogb3_snapshot_internal_free(void*);

typedef struct { uint8_t* data; uint64_t size,capacity; int failed; } Dump;
#ifdef OGB3_TESTING
static uint64_t test_dump_walks;
static void (*test_after_alloc)(uint32_t);
void ogb3_state_dump_test_reset_walks(void) { test_dump_walks = 0; }
uint64_t ogb3_state_dump_test_walks(void) { return test_dump_walks; }
void ogb3_state_dump_test_after_alloc(void (*callback)(uint32_t)) {
    test_after_alloc = callback;
}
#endif
static void put(Dump* d,const void* p,uint64_t n) {
    if(d->failed || n>UINT64_MAX-d->size){d->failed=1;return;}
    if(d->data && d->size+n<=d->capacity) memcpy(d->data+d->size,p,(size_t)n);
    d->size+=n;
}
#define VAL(d,x) put((d),&(x),sizeof(x))
static void i32(Dump* d,int32_t x){VAL(d,x);}
static void n_b3JointSim(Dump*,const b3JointSim*);
static void n_b3TreeNode(Dump*,const b3TreeNode*);
static void n_b3Manifold(Dump*,const b3Manifold*);
static void n_b3SimplexCache(Dump*,const b3SimplexCache*);
static void n_b3MeshNode(Dump*,const b3MeshNode*);
/* BEGIN GENERATED FIELD EMITTERS: generate_fields.py */
static void n_b3AABB(Dump*, const b3AABB*);
static void n_b3Body(Dump*, const b3Body*);
static void n_b3BodySim(Dump*, const b3BodySim*);
static void n_b3BodyState(Dump*, const b3BodyState*);
static void n_b3Capacity(Dump*, const b3Capacity*);
static void n_b3Capsule(Dump*, const b3Capsule*);
static void n_b3ContactEdge(Dump*, const b3ContactEdge*);
static void n_b3ContactLink(Dump*, const b3ContactLink*);
static void n_b3ContactSpec(Dump*, const b3ContactSpec*);
static void n_b3DistanceJoint(Dump*, const b3DistanceJoint*);
static void n_b3Filter(Dump*, const b3Filter*);
static void n_b3HeightFieldData(Dump*, const b3HeightFieldData*);
static void n_b3HullData(Dump*, const b3HullData*);
static void n_b3HullFace(Dump*, const b3HullFace*);
static void n_b3HullHalfEdge(Dump*, const b3HullHalfEdge*);
static void n_b3HullVertex(Dump*, const b3HullVertex*);
static void n_b3IslandSim(Dump*, const b3IslandSim*);
static void n_b3Joint(Dump*, const b3Joint*);
static void n_b3JointEdge(Dump*, const b3JointEdge*);
static void n_b3JointLink(Dump*, const b3JointLink*);
static void n_b3ManifoldPoint(Dump*, const b3ManifoldPoint*);
static void n_b3Matrix3(Dump*, const b3Matrix3*);
static void n_b3MeshData(Dump*, const b3MeshData*);
static void n_b3MeshTriangle(Dump*, const b3MeshTriangle*);
static void n_b3MotorJoint(Dump*, const b3MotorJoint*);
static void n_b3ParallelJoint(Dump*, const b3ParallelJoint*);
static void n_b3Plane(Dump*, const b3Plane*);
static void n_b3Pos(Dump*, const b3Pos*);
static void n_b3PrismaticJoint(Dump*, const b3PrismaticJoint*);
static void n_b3Quat(Dump*, const b3Quat*);
static void n_b3RevoluteJoint(Dump*, const b3RevoluteJoint*);
static void n_b3SATCache(Dump*, const b3SATCache*);
static void n_b3SetItem(Dump*, const b3SetItem*);
static void n_b3Softness(Dump*, const b3Softness*);
static void n_b3Sphere(Dump*, const b3Sphere*);
static void n_b3SphericalJoint(Dump*, const b3SphericalJoint*);
static void n_b3SurfaceMaterial(Dump*, const b3SurfaceMaterial*);
static void n_b3Transform(Dump*, const b3Transform*);
static void n_b3Vec2(Dump*, const b3Vec2*);
static void n_b3Vec3(Dump*, const b3Vec3*);
static void n_b3Visitor(Dump*, const b3Visitor*);
static void n_b3WeldJoint(Dump*, const b3WeldJoint*);
static void n_b3WheelJoint(Dump*, const b3WheelJoint*);
static void n_b3WorldTransform(Dump*, const b3WorldTransform*);

static void n_b3Body(Dump* d, const b3Body* v) {
    VAL(d, v->setIndex);
    VAL(d, v->localIndex);
    VAL(d, v->headContactKey);
    VAL(d, v->contactCount);
    VAL(d, v->headShapeId);
    VAL(d, v->shapeCount);
    VAL(d, v->headChainId);
    VAL(d, v->headJointKey);
    VAL(d, v->jointCount);
    VAL(d, v->islandId);
    VAL(d, v->islandIndex);
    VAL(d, v->sleepThreshold);
    VAL(d, v->sleepTime);
    VAL(d, v->sleepVelocity);
    VAL(d, v->safetyFactor);
    VAL(d, v->mass);
    VAL(d, v->id);
    VAL(d, v->flags);
    VAL(d, v->type);
    VAL(d, v->generation);
}
static void n_b3Vec3(Dump* d, const b3Vec3* v) {
    VAL(d, v->x);
    VAL(d, v->y);
    VAL(d, v->z);
}
static void n_b3Quat(Dump* d, const b3Quat* v) {
    n_b3Vec3(d, &v->v);
    VAL(d, v->s);
}
static void n_b3WorldTransform(Dump* d, const b3WorldTransform* v) {
    n_b3Vec3(d, &v->p);
    n_b3Quat(d, &v->q);
}
static void n_b3Pos(Dump* d, const b3Pos* v) {
    VAL(d, v->x);
    VAL(d, v->y);
    VAL(d, v->z);
}
static void n_b3Matrix3(Dump* d, const b3Matrix3* v) {
    n_b3Vec3(d, &v->cx);
    n_b3Vec3(d, &v->cy);
    n_b3Vec3(d, &v->cz);
}
static void n_b3BodySim(Dump* d, const b3BodySim* v) {
    n_b3WorldTransform(d, &v->transform);
    n_b3Pos(d, &v->center);
    VAL(d, v->flags);
    VAL(d, v->minExtent);
    n_b3Vec3(d, &v->maxExtent);
    n_b3Quat(d, &v->rotation0);
    n_b3Pos(d, &v->center0);
    n_b3Vec3(d, &v->localCenter);
    n_b3Vec3(d, &v->force);
    n_b3Vec3(d, &v->torque);
    VAL(d, v->invMass);
    n_b3Matrix3(d, &v->inertia);
    n_b3Matrix3(d, &v->invInertiaLocal);
    n_b3Matrix3(d, &v->invInertiaWorld);
    VAL(d, v->linearDamping);
    VAL(d, v->angularDamping);
    VAL(d, v->gravityScale);
    VAL(d, v->bodyId);
}
static void n_b3BodyState(Dump* d, const b3BodyState* v) {
    n_b3Vec3(d, &v->linearVelocity);
    n_b3Vec3(d, &v->angularVelocity);
    n_b3Vec3(d, &v->deltaPosition);
    VAL(d, v->flags);
    n_b3Quat(d, &v->deltaRotation);
}
static void n_b3JointEdge(Dump* d, const b3JointEdge* v) {
    VAL(d, v->bodyId);
    VAL(d, v->prevKey);
    VAL(d, v->nextKey);
}
static void n_b3Joint(Dump* d, const b3Joint* v) {
    VAL(d, v->setIndex);
    VAL(d, v->colorIndex);
    VAL(d, v->localIndex);
    n_b3JointEdge(d, &v->edges[0]);
    n_b3JointEdge(d, &v->edges[1]);
    VAL(d, v->jointId);
    VAL(d, v->islandId);
    VAL(d, v->islandIndex);
    VAL(d, v->type);
    VAL(d, v->generation);
    VAL(d, v->collideConnected);
}
static void n_b3Transform(Dump* d, const b3Transform* v) {
    n_b3Vec3(d, &v->p);
    n_b3Quat(d, &v->q);
}
static void n_b3Softness(Dump* d, const b3Softness* v) {
    VAL(d, v->biasRate);
    VAL(d, v->massScale);
    VAL(d, v->impulseScale);
}
static void n_b3JointSim_base(Dump* d, const b3JointSim* v) {
    VAL(d, v->jointId);
    VAL(d, v->bodyIdA);
    VAL(d, v->bodyIdB);
    VAL(d, v->type);
    n_b3Transform(d, &v->localFrameA);
    n_b3Transform(d, &v->localFrameB);
    VAL(d, v->invMassA);
    VAL(d, v->invMassB);
    n_b3Matrix3(d, &v->invIA);
    n_b3Matrix3(d, &v->invIB);
    VAL(d, v->constraintHertz);
    VAL(d, v->constraintDampingRatio);
    n_b3Softness(d, &v->constraintSoftness);
    VAL(d, v->forceThreshold);
    VAL(d, v->torqueThreshold);
    VAL(d, v->fixedRotation);
}
static void n_b3AABB(Dump* d, const b3AABB* v) {
    n_b3Vec3(d, &v->lowerBound);
    n_b3Vec3(d, &v->upperBound);
}
static void n_b3Filter(Dump* d, const b3Filter* v) {
    VAL(d, v->categoryBits);
    VAL(d, v->maskBits);
    VAL(d, v->groupIndex);
}
static void n_b3Shape_base(Dump* d, const b3Shape* v) {
    VAL(d, v->id);
    VAL(d, v->bodyId);
    VAL(d, v->prevShapeId);
    VAL(d, v->nextShapeId);
    VAL(d, v->sensorIndex);
    VAL(d, v->proxyKey);
    VAL(d, v->type);
    VAL(d, v->density);
    VAL(d, v->explosionScale);
    VAL(d, v->aabbMargin);
    n_b3AABB(d, &v->aabb);
    n_b3Vec3(d, &v->localCentroid);
    VAL(d, v->materialCount);
    n_b3Filter(d, &v->filter);
    VAL(d, v->generation);
    VAL(d, v->flags);
}
static void n_b3ContactEdge(Dump* d, const b3ContactEdge* v) {
    VAL(d, v->bodyId);
    VAL(d, v->prevKey);
    VAL(d, v->nextKey);
}
static void n_b3Contact_base(Dump* d, const b3Contact* v) {
    VAL(d, v->setIndex);
    VAL(d, v->colorIndex);
    VAL(d, v->localIndex);
    n_b3ContactEdge(d, &v->edges[0]);
    n_b3ContactEdge(d, &v->edges[1]);
    VAL(d, v->shapeIdA);
    VAL(d, v->shapeIdB);
    VAL(d, v->childIndex);
    VAL(d, v->islandId);
    VAL(d, v->islandIndex);
    VAL(d, v->contactId);
    VAL(d, v->encodedBodySimA);
    VAL(d, v->encodedBodySimB);
    VAL(d, v->flags);
    n_b3Quat(d, &v->cachedRotationA);
    n_b3Quat(d, &v->cachedRotationB);
    n_b3Transform(d, &v->cachedRelativePose);
    VAL(d, v->friction);
    VAL(d, v->restitution);
    VAL(d, v->rollingResistance);
    n_b3Vec3(d, &v->tangentVelocity);
    VAL(d, v->generation);
}
static void n_b3Visitor(Dump* d, const b3Visitor* v) {
    VAL(d, v->shapeId);
    VAL(d, v->generation);
}
static void n_b3IslandSim(Dump* d, const b3IslandSim* v) {
    VAL(d, v->islandId);
}
static void n_b3ContactSpec(Dump* d, const b3ContactSpec* v) {
    VAL(d, v->contactId);
    VAL(d, v->manifoldStart);
    VAL(d, v->manifoldCount);
}
static void n_b3SetItem(Dump* d, const b3SetItem* v) {
    VAL(d, v->key);
    VAL(d, v->hash);
}
static void n_b3SurfaceMaterial(Dump* d, const b3SurfaceMaterial* v) {
    VAL(d, v->friction);
    VAL(d, v->restitution);
    VAL(d, v->rollingResistance);
    n_b3Vec3(d, &v->tangentVelocity);
    VAL(d, v->userMaterialId);
}
static void n_b3Sphere(Dump* d, const b3Sphere* v) {
    n_b3Vec3(d, &v->center);
    VAL(d, v->radius);
}
static void n_b3Capsule(Dump* d, const b3Capsule* v) {
    n_b3Vec3(d, &v->center1);
    n_b3Vec3(d, &v->center2);
    VAL(d, v->radius);
}
static void n_b3SATCache(Dump* d, const b3SATCache* v) {
    VAL(d, v->separation);
    VAL(d, v->type);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
}
static void n_b3Capacity(Dump* d, const b3Capacity* v) {
    VAL(d, v->staticShapeCount);
    VAL(d, v->dynamicShapeCount);
    VAL(d, v->staticBodyCount);
    VAL(d, v->dynamicBodyCount);
    VAL(d, v->contactCount);
}
static void n_b3HullData(Dump* d, const b3HullData* v) {
    VAL(d, v->version);
    VAL(d, v->hash);
    n_b3AABB(d, &v->aabb);
    VAL(d, v->surfaceArea);
    VAL(d, v->volume);
    VAL(d, v->innerRadius);
    n_b3Vec3(d, &v->center);
    n_b3Matrix3(d, &v->centralInertia);
    VAL(d, v->vertexCount);
    VAL(d, v->vertexOffset);
    VAL(d, v->pointOffset);
    VAL(d, v->edgeCount);
    VAL(d, v->edgeOffset);
    VAL(d, v->faceCount);
    VAL(d, v->planeOffset);
    VAL(d, v->faceOffset);
    VAL(d, v->soaVertexOffset);
    VAL(d, v->soaNormalOffset);
    VAL(d, v->edgeCosineOffset);
    VAL(d, v->byteCount);
}
static void n_b3HullVertex(Dump* d, const b3HullVertex* v) {
    VAL(d, v->edge);
}
static void n_b3HullHalfEdge(Dump* d, const b3HullHalfEdge* v) {
    VAL(d, v->next);
    VAL(d, v->twin);
    VAL(d, v->origin);
    VAL(d, v->face);
}
static void n_b3HullFace(Dump* d, const b3HullFace* v) {
    VAL(d, v->edge);
}
static void n_b3Plane(Dump* d, const b3Plane* v) {
    n_b3Vec3(d, &v->normal);
    VAL(d, v->offset);
}
static void n_b3MeshData(Dump* d, const b3MeshData* v) {
    VAL(d, v->version);
    VAL(d, v->hash);
    VAL(d, v->byteCount);
    n_b3AABB(d, &v->bounds);
    VAL(d, v->surfaceArea);
    VAL(d, v->treeHeight);
    VAL(d, v->degenerateCount);
    VAL(d, v->nodeOffset);
    VAL(d, v->nodeCount);
    VAL(d, v->vertexOffset);
    VAL(d, v->vertexCount);
    VAL(d, v->triangleOffset);
    VAL(d, v->triangleCount);
    VAL(d, v->materialOffset);
    VAL(d, v->materialCount);
    VAL(d, v->flagsOffset);
}
static void n_b3MeshTriangle(Dump* d, const b3MeshTriangle* v) {
    VAL(d, v->index1);
    VAL(d, v->index2);
    VAL(d, v->index3);
}
static void n_b3HeightFieldData(Dump* d, const b3HeightFieldData* v) {
    VAL(d, v->version);
    VAL(d, v->hash);
    VAL(d, v->byteCount);
    n_b3AABB(d, &v->aabb);
    VAL(d, v->minHeight);
    VAL(d, v->maxHeight);
    VAL(d, v->heightScale);
    n_b3Vec3(d, &v->scale);
    VAL(d, v->columnCount);
    VAL(d, v->rowCount);
    VAL(d, v->heightsOffset);
    VAL(d, v->materialOffset);
    VAL(d, v->flagsOffset);
    VAL(d, v->clockwise);
}
static void n_b3ManifoldPoint(Dump* d, const b3ManifoldPoint* v) {
    n_b3Vec3(d, &v->anchorA);
    n_b3Vec3(d, &v->anchorB);
    VAL(d, v->separation);
    VAL(d, v->normalImpulse);
    VAL(d, v->totalNormalImpulse);
    VAL(d, v->normalVelocity);
    VAL(d, v->baseSeparation);
    VAL(d, v->featureId);
    VAL(d, v->triangleIndex);
    VAL(d, v->persisted);
}
static void n_b3ContactLink(Dump* d, const b3ContactLink* v) {
    VAL(d, v->contactId);
    VAL(d, v->bodyIdA);
    VAL(d, v->bodyIdB);
}
static void n_b3JointLink(Dump* d, const b3JointLink* v) {
    VAL(d, v->jointId);
    VAL(d, v->bodyIdA);
    VAL(d, v->bodyIdB);
}
static void n_b3DistanceJoint(Dump* d, const b3DistanceJoint* v) {
    VAL(d, v->length);
    VAL(d, v->hertz);
    VAL(d, v->dampingRatio);
    VAL(d, v->lowerSpringForce);
    VAL(d, v->upperSpringForce);
    VAL(d, v->minLength);
    VAL(d, v->maxLength);
    VAL(d, v->maxMotorForce);
    VAL(d, v->motorSpeed);
    VAL(d, v->impulse);
    VAL(d, v->lowerImpulse);
    VAL(d, v->upperImpulse);
    VAL(d, v->motorImpulse);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Vec3(d, &v->anchorA);
    n_b3Vec3(d, &v->anchorB);
    n_b3Vec3(d, &v->deltaCenter);
    n_b3Softness(d, &v->distanceSoftness);
    VAL(d, v->axialMass);
    VAL(d, v->enableSpring);
    VAL(d, v->enableLimit);
    VAL(d, v->enableMotor);
}
static void n_b3MotorJoint(Dump* d, const b3MotorJoint* v) {
    n_b3Vec3(d, &v->linearVelocity);
    n_b3Vec3(d, &v->angularVelocity);
    VAL(d, v->maxVelocityForce);
    VAL(d, v->maxVelocityTorque);
    VAL(d, v->linearHertz);
    VAL(d, v->linearDampingRatio);
    VAL(d, v->maxSpringForce);
    VAL(d, v->angularHertz);
    VAL(d, v->angularDampingRatio);
    VAL(d, v->maxSpringTorque);
    n_b3Vec3(d, &v->linearVelocityImpulse);
    n_b3Vec3(d, &v->angularVelocityImpulse);
    n_b3Vec3(d, &v->linearSpringImpulse);
    n_b3Vec3(d, &v->angularSpringImpulse);
    n_b3Softness(d, &v->linearSpring);
    n_b3Softness(d, &v->angularSpring);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->deltaCenter);
    n_b3Matrix3(d, &v->angularMass);
}
static void n_b3Vec2(Dump* d, const b3Vec2* v) {
    VAL(d, v->x);
    VAL(d, v->y);
}
static void n_b3ParallelJoint(Dump* d, const b3ParallelJoint* v) {
    VAL(d, v->hertz);
    VAL(d, v->dampingRatio);
    VAL(d, v->maxTorque);
    n_b3Vec2(d, &v->perpImpulse);
    n_b3Vec3(d, &v->perpAxisX);
    n_b3Vec3(d, &v->perpAxisY);
    n_b3Quat(d, &v->quatA);
    n_b3Quat(d, &v->quatB);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Softness(d, &v->softness);
}
static void n_b3RevoluteJoint(Dump* d, const b3RevoluteJoint* v) {
    n_b3Vec3(d, &v->linearImpulse);
    n_b3Vec2(d, &v->perpImpulse);
    VAL(d, v->springImpulse);
    VAL(d, v->motorImpulse);
    VAL(d, v->lowerImpulse);
    VAL(d, v->upperImpulse);
    VAL(d, v->hertz);
    VAL(d, v->dampingRatio);
    VAL(d, v->maxMotorTorque);
    VAL(d, v->motorSpeed);
    VAL(d, v->targetAngle);
    VAL(d, v->lowerAngle);
    VAL(d, v->upperAngle);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->rotationAxisZ);
    n_b3Vec3(d, &v->perpAxisX);
    n_b3Vec3(d, &v->perpAxisY);
    n_b3Vec3(d, &v->deltaCenter);
    VAL(d, v->deltaAngle);
    VAL(d, v->axialMass);
    n_b3Softness(d, &v->springSoftness);
    VAL(d, v->enableSpring);
    VAL(d, v->enableMotor);
    VAL(d, v->enableLimit);
}
static void n_b3SphericalJoint(Dump* d, const b3SphericalJoint* v) {
    n_b3Vec3(d, &v->linearImpulse);
    n_b3Vec3(d, &v->springImpulse);
    n_b3Vec3(d, &v->motorImpulse);
    VAL(d, v->lowerTwistImpulse);
    VAL(d, v->upperTwistImpulse);
    VAL(d, v->swingImpulse);
    VAL(d, v->hertz);
    VAL(d, v->dampingRatio);
    VAL(d, v->maxMotorTorque);
    n_b3Vec3(d, &v->motorVelocity);
    VAL(d, v->lowerTwistAngle);
    VAL(d, v->upperTwistAngle);
    VAL(d, v->coneAngle);
    n_b3Quat(d, &v->targetRotation);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->deltaCenter);
    n_b3Vec3(d, &v->swingAxis);
    n_b3Vec3(d, &v->twistJacobian);
    n_b3Matrix3(d, &v->rotationMass);
    VAL(d, v->swingMass);
    VAL(d, v->twistMass);
    n_b3Softness(d, &v->springSoftness);
    VAL(d, v->enableSpring);
    VAL(d, v->enableMotor);
    VAL(d, v->enableConeLimit);
    VAL(d, v->enableTwistLimit);
}
static void n_b3PrismaticJoint(Dump* d, const b3PrismaticJoint* v) {
    n_b3Vec2(d, &v->perpImpulse);
    n_b3Vec3(d, &v->angularImpulse);
    VAL(d, v->springImpulse);
    VAL(d, v->motorImpulse);
    VAL(d, v->lowerImpulse);
    VAL(d, v->upperImpulse);
    VAL(d, v->hertz);
    VAL(d, v->dampingRatio);
    VAL(d, v->maxMotorForce);
    VAL(d, v->motorSpeed);
    VAL(d, v->targetTranslation);
    VAL(d, v->lowerTranslation);
    VAL(d, v->upperTranslation);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->jointAxis);
    n_b3Vec3(d, &v->perpAxisY);
    n_b3Vec3(d, &v->perpAxisZ);
    n_b3Vec3(d, &v->deltaCenter);
    VAL(d, v->deltaAngle);
    n_b3Matrix3(d, &v->rotationMass);
    n_b3Softness(d, &v->springSoftness);
    VAL(d, v->enableSpring);
    VAL(d, v->enableLimit);
    VAL(d, v->enableMotor);
}
static void n_b3WeldJoint(Dump* d, const b3WeldJoint* v) {
    VAL(d, v->linearHertz);
    VAL(d, v->linearDampingRatio);
    VAL(d, v->angularHertz);
    VAL(d, v->angularDampingRatio);
    n_b3Softness(d, &v->linearSpring);
    n_b3Softness(d, &v->angularSpring);
    n_b3Vec3(d, &v->linearImpulse);
    n_b3Vec3(d, &v->angularImpulse);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->deltaCenter);
    n_b3Matrix3(d, &v->angularMass);
}
static void n_b3WheelJoint(Dump* d, const b3WheelJoint* v) {
    n_b3Vec2(d, &v->linearImpulse);
    n_b3Vec2(d, &v->angularImpulse);
    VAL(d, v->spinImpulse);
    VAL(d, v->maxSpinTorque);
    VAL(d, v->spinSpeed);
    VAL(d, v->suspensionSpringImpulse);
    VAL(d, v->lowerSuspensionImpulse);
    VAL(d, v->upperSuspensionImpulse);
    VAL(d, v->lowerSuspensionLimit);
    VAL(d, v->upperSuspensionLimit);
    VAL(d, v->suspensionHertz);
    VAL(d, v->suspensionDampingRatio);
    VAL(d, v->steeringSpringImpulse);
    VAL(d, v->lowerSteeringImpulse);
    VAL(d, v->upperSteeringImpulse);
    VAL(d, v->lowerSteeringLimit);
    VAL(d, v->upperSteeringLimit);
    VAL(d, v->targetSteeringAngle);
    VAL(d, v->maxSteeringTorque);
    VAL(d, v->steeringHertz);
    VAL(d, v->steeringDampingRatio);
    VAL(d, v->indexA);
    VAL(d, v->indexB);
    n_b3Transform(d, &v->frameA);
    n_b3Transform(d, &v->frameB);
    n_b3Vec3(d, &v->deltaCenter);
    VAL(d, v->spinMass);
    VAL(d, v->suspensionMass);
    VAL(d, v->steeringMass);
    n_b3Softness(d, &v->suspensionSoftness);
    n_b3Softness(d, &v->steeringSoftness);
    VAL(d, v->enableSpinMotor);
    VAL(d, v->enableSuspensionSpring);
    VAL(d, v->enableSuspensionLimit);
    VAL(d, v->enableSteering);
    VAL(d, v->enableSteeringLimit);
    VAL(d, v->enableSteeringMotor);
}
/* END GENERATED FIELD EMITTERS */

static void n_b3JointSim(Dump* d,const b3JointSim* v) {
    n_b3JointSim_base(d,v);
    switch(v->type){
#define J(kind,field,typ) case kind: n_##typ(d,&v->field); break
    J(b3_distanceJoint,distanceJoint,b3DistanceJoint);
    J(b3_motorJoint,motorJoint,b3MotorJoint);
    J(b3_parallelJoint,parallelJoint,b3ParallelJoint);
    J(b3_revoluteJoint,revoluteJoint,b3RevoluteJoint);
    J(b3_sphericalJoint,sphericalJoint,b3SphericalJoint);
    J(b3_prismaticJoint,prismaticJoint,b3PrismaticJoint);
    J(b3_weldJoint,weldJoint,b3WeldJoint);
    J(b3_wheelJoint,wheelJoint,b3WheelJoint);
    case b3_filterJoint: break;
    default: d->failed=1;
#undef J
    }
}
static void n_b3TreeNode(Dump* d,const b3TreeNode* v) {
    VAL(d,v->flagIndex);
    if(b3IsEmptyNode(v))return;
    n_b3AABB(d,&v->aabb);
    /* The tagged union is a shape index for leaves and height for interiors. */
    VAL(d,v->height);
}
static void n_b3Manifold(Dump* d,const b3Manifold* v) {
    VAL(d,v->pointCount);
    if(v->pointCount<0 || v->pointCount>4){d->failed=1;return;}
    for(int i=0;i<v->pointCount;i++)n_b3ManifoldPoint(d,v->points+i);
    n_b3Vec3(d,&v->normal);VAL(d,v->twistImpulse);
    n_b3Vec3(d,&v->frictionImpulse);n_b3Vec3(d,&v->rollingImpulse);
}
static void n_b3SimplexCache(Dump* d,const b3SimplexCache* v) {
    VAL(d,v->metric);VAL(d,v->count);
    if(v->count>4){d->failed=1;return;}
    put(d,v->indexA,v->count);put(d,v->indexB,v->count);
}
static void n_b3MeshNode(Dump* d,const b3MeshNode* v) {
    n_b3Vec3(d,&v->lowerBound); n_b3Vec3(d,&v->upperBound);
    i32(d,v->data.asNode.axis);i32(d,v->data.asNode.childOffset);VAL(d,v->triangleOffset);
}
#define ARRAY(d,a,norm) do { i32(d,(a).count); for(int ai=0;ai<(a).count;ai++)norm(d,(a).data+ai); }while(0)
static void n_int(Dump*d,const int*v){VAL(d,*v);}
static void pool(Dump*d,const b3IdPool*p){VAL(d,p->nextIndex);ARRAY(d,p->freeArray,n_int);}
static void bits(Dump*d,const b3BitSet*b){VAL(d,b->blockCount);put(d,b->bits,8ull*b->blockCount);}
static void tree(Dump*d,const b3DynamicTree*t){
    VAL(d,t->version);VAL(d,t->nodeEnd);VAL(d,t->pairFreeList);
    VAL(d,t->proxyCount);VAL(d,t->proxyCapacity);VAL(d,t->proxyFreeList);VAL(d,t->dfsOrdered);
    for(int i=0;i<t->nodeEnd;i++){n_b3TreeNode(d,t->nodes+i);VAL(d,t->parents[i]);}
    for(int i=0;i<t->proxyCapacity;i++){
        const b3TreeProxy*p=t->proxies+i;VAL(d,p->node);
        if(p->node==B3_NULL_INDEX)VAL(d,p->next);
        else{VAL(d,p->userData);VAL(d,p->categoryBits);}
    }
}
static void hull(Dump*d,const b3HullData*h){
    n_b3HullData(d,h);
    for(int i=0;i<h->vertexCount;i++)n_b3HullVertex(d,b3GetHullVertices(h)+i);
    for(int i=0;i<h->vertexCount;i++)n_b3Vec3(d,b3GetHullPoints(h)+i);
    for(int i=0;i<h->edgeCount;i++)n_b3HullHalfEdge(d,b3GetHullEdges(h)+i);
    for(int i=0;i<h->faceCount;i++){n_b3HullFace(d,b3GetHullFaces(h)+i);n_b3Plane(d,b3GetHullPlanes(h)+i);}
    const float*soa=b3GetHullSoaVertices(h);
    if(soa)for(int i=0;i<3*((h->vertexCount+7)&~7);i++)VAL(d,soa[i]);
    soa=b3GetHullSoaNormals(h);
    if(soa)for(int i=0;i<3*((h->faceCount+7)&~7);i++)VAL(d,soa[i]);
    soa=b3GetHullEdgeCosines(h);
    if(soa)for(int i=0;i<h->edgeCount/2;i++)VAL(d,soa[i]);
}
static void mesh(Dump*d,const b3MeshData*m){
    n_b3MeshData(d,m);
    for(int i=0;i<m->nodeCount;i++)n_b3MeshNode(d,b3GetMeshNodes(m)+i);
    for(int i=0;i<m->vertexCount;i++)n_b3Vec3(d,b3GetMeshVertices(m)+i);
    for(int i=0;i<m->triangleCount;i++)n_b3MeshTriangle(d,b3GetMeshTriangles(m)+i);
    put(d,(const uint8_t*)m+m->materialOffset,m->triangleCount);
    put(d,(const uint8_t*)m+m->flagsOffset,m->triangleCount);
}
static void height(Dump*d,const b3HeightFieldData*h){
    n_b3HeightFieldData(d,h);
    put(d,(const uint8_t*)h+h->heightsOffset,2ull*h->rowCount*h->columnCount);
    uint64_t cells=(uint64_t)(h->rowCount-1)*(h->columnCount-1);
    put(d,(const uint8_t*)h+h->materialOffset,cells);
    put(d,(const uint8_t*)h+h->flagsOffset,2*cells);
}
static void compound(Dump*d,const b3CompoundData*c){
    VAL(d,c->version);n_b3AABB(d,&c->bounds);VAL(d,c->nodeCount);
    const b3TreeNode*nodes=(const b3TreeNode*)((const uint8_t*)c+c->nodeOffset);
    for(int i=0;i<c->nodeCount;i++)n_b3TreeNode(d,nodes+i);
    VAL(d,c->materialCount);
    const b3SurfaceMaterial* mats=(const b3SurfaceMaterial*)((const uint8_t*)c+c->materialOffset);
    for(int i=0;i<c->materialCount;i++)n_b3SurfaceMaterial(d,mats+i);
    VAL(d,c->capsuleCount);VAL(d,c->hullCount);VAL(d,c->meshCount);VAL(d,c->sphereCount);
    int count=(c->capsuleCount+c->hullCount+c->meshCount+c->sphereCount);
    for(int i=0;i<count;i++){
        b3ChildShape child=b3GetCompoundChild(c,i);
        VAL(d,child.type);n_b3Transform(d,&child.transform);
        VAL(d,child.materialCount);put(d,child.materialIndices,2ull*(uint64_t)child.materialCount);
        switch(child.type){
            case b3_capsuleShape:n_b3Capsule(d,&child.capsule);break;
            case b3_sphereShape:n_b3Sphere(d,&child.sphere);break;
            case b3_hullShape:hull(d,child.hull);break;
            case b3_meshShape:mesh(d,child.mesh.data);n_b3Vec3(d,&child.mesh.scale);break;
            default:d->failed=1;
        }
    }
}
static void geometry(Dump*d,const b3Shape*s){
    switch(s->type){
        case b3_capsuleShape:n_b3Capsule(d,&s->capsule);break;
        case b3_sphereShape:n_b3Sphere(d,&s->sphere);break;
        case b3_hullShape:hull(d,s->hull);break;
        case b3_meshShape:mesh(d,s->mesh.data);n_b3Vec3(d,&s->mesh.scale);break;
        case b3_heightShape:height(d,s->heightField);break;
        case b3_compoundShape:compound(d,s->compound);break;
        default:d->failed=1;
    }
}
static void cache(Dump*d,const b3ContactCache*c,int sat){
    if(sat)n_b3SATCache(d,&c->satCache);else n_b3SimplexCache(d,&c->simplexCache);
}
static void contact(Dump*d,const b3World*w,const b3Contact*c){
    n_b3Contact_base(d,c);VAL(d,c->manifoldCount);
    for(int j=0;j<c->manifoldCount;j++)n_b3Manifold(d,c->manifolds+j);
    const b3Shape*a=w->shapes.data+c->shapeIdA,*b=w->shapes.data+c->shapeIdB;
    b3ShapeType ta=a->type;
    if(ta==b3_compoundShape)ta=b3GetCompoundChild(a->compound,c->childIndex).type;
    if(c->flags&b3_simMeshContact){
        n_b3AABB(d,&c->meshContact.queryBounds);
        i32(d,c->meshContact.triangleCache.count);
        for(int j=0;j<c->meshContact.triangleCache.count;j++){
            const b3TriangleCache*t=c->meshContact.triangleCache.data+j;
            VAL(d,t->triangleIndex);cache(d,&t->cache,b->type==b3_hullShape);
        }
    }else cache(d,&c->convexContact.cache,ta==b3_hullShape&&b->type==b3_hullShape);
}
/* Current end buffer is a future delivery queue, not completed output. */
static uint64_t pending_shape_key(b3ShapeId id){return (uint32_t)id.index1|((uint64_t)id.generation<<32);}
static uint64_t pending_contact_key(b3ContactId id){return (uint32_t)id.index1|((uint64_t)id.generation<<32);}
static void pending_ends(Dump*d,const b3World*w){
    int index=w->endEventArrayIndex;if(index<0||index>1){d->failed=1;return;}
    int sensors=w->sensorEndEvents[index].count,contacts=w->contactEndEvents[index].count;
    if(sensors<0||contacts<0){d->failed=1;return;}
    i32(d,sensors);
    for(int i=0;i<sensors;i++){
        const b3SensorEndTouchEvent*e=w->sensorEndEvents[index].data+i;
        if(e->sensorShapeId.index1<=0||e->visitorShapeId.index1<=0){d->failed=1;return;}
        uint64_t sensor=pending_shape_key(e->sensorShapeId),visitor=pending_shape_key(e->visitorShapeId);VAL(d,sensor);VAL(d,visitor);
    }
    i32(d,contacts);
    for(int i=0;i<contacts;i++){
        const b3ContactEndTouchEvent*e=w->contactEndEvents[index].data+i;
        if(e->shapeIdA.index1<=0||e->shapeIdB.index1<=0||e->contactId.index1<=0){d->failed=1;return;}
        uint64_t a=pending_shape_key(e->shapeIdA),b=pending_shape_key(e->shapeIdB),contact=pending_contact_key(e->contactId);VAL(d,a);VAL(d,b);VAL(d,contact);
    }
}
static void dump_world(Dump*d,const b3World*w){
#ifdef OGB3_TESTING
    test_dump_walks++;
#endif
    uint32_t version=OGB3_STATE_DUMP_VERSION;VAL(d,version);
    n_b3Vec3(d,&w->gravity);
#define CONFIG(f) VAL(d,w->f)
    CONFIG(hitEventThreshold);CONFIG(restitutionThreshold);CONFIG(maxLinearSpeed);CONFIG(contactSpeed);
    CONFIG(contactHertz);CONFIG(contactDampingRatio);CONFIG(contactRecycleDistance);
    CONFIG(restitutionIterations);CONFIG(enableRestitutionPropagation);CONFIG(isotropicInertiaTolerance);
    CONFIG(compoundShapeCount);CONFIG(simdWidth);
    CONFIG(stepIndex);CONFIG(splitIslandId);CONFIG(inv_h);CONFIG(inv_dt);CONFIG(endEventArrayIndex);
    n_b3Capacity(d,&w->maxCapacity);
    CONFIG(enableSleep);CONFIG(enableWarmStarting);CONFIG(enableContinuous);CONFIG(enableSpeculative);
#undef CONFIG
    pool(d,&w->bodyIdPool);pool(d,&w->shapeIdPool);pool(d,&w->contactIdPool);
    pool(d,&w->jointIdPool);pool(d,&w->islandIdPool);pool(d,&w->solverSetIdPool);
    i32(d,w->solverSets.count);
    for(int i=0;i<w->solverSets.count;i++){
        const b3SolverSet*s=w->solverSets.data+i;VAL(d,s->setIndex);
        ARRAY(d,s->bodySims,n_b3BodySim);ARRAY(d,s->bodyStates,n_b3BodyState);
        ARRAY(d,s->jointSims,n_b3JointSim);ARRAY(d,s->contactIndices,n_int);ARRAY(d,s->islandSims,n_b3IslandSim);
    }
    i32(d,w->bodies.count);
    for(int i=0;i<w->bodies.count;i++){
        const b3Body*v=w->bodies.data+i;VAL(d,v->id);VAL(d,v->generation);
        if(v->id==i)n_b3Body(d,v);
    }
    i32(d,w->shapes.count);
    for(int i=0;i<w->shapes.count;i++){
        const b3Shape*v=w->shapes.data+i;VAL(d,v->id);VAL(d,v->generation);
        if(v->id==i){n_b3Shape_base(d,v);n_b3AABB(d,w->fatAABBs.data+i);for(int j=0;j<v->materialCount;j++)n_b3SurfaceMaterial(d,b3GetShapeMaterials(v)+j);geometry(d,v);}
    }
    i32(d,w->contacts.count);
    for(int i=0;i<w->contacts.count;i++){
        const b3Contact*v=w->contacts.data+i;VAL(d,v->contactId);VAL(d,v->generation);
        if(v->contactId==i)contact(d,w,v);
    }
    i32(d,w->joints.count);
    for(int i=0;i<w->joints.count;i++){
        const b3Joint*v=w->joints.data+i;VAL(d,v->jointId);VAL(d,v->generation);
        if(v->jointId==i)n_b3Joint(d,v);
    }
    i32(d,w->sensors.count);
    for(int i=0;i<w->sensors.count;i++){
        const b3Sensor*s=w->sensors.data+i;VAL(d,s->shapeId);
        ARRAY(d,s->hits,n_b3Visitor);ARRAY(d,s->overlaps1,n_b3Visitor);ARRAY(d,s->overlaps2,n_b3Visitor);
    }
    i32(d,w->islands.count);
    for(int i=0;i<w->islands.count;i++){
        const b3Island*s=w->islands.data+i;
        VAL(d,s->setIndex);VAL(d,s->localIndex);VAL(d,s->islandId);VAL(d,s->constraintRemoveCount);
        ARRAY(d,s->bodies,n_int);ARRAY(d,s->contacts,n_b3ContactLink);ARRAY(d,s->joints,n_b3JointLink);
    }
    for(int t=0;t<b3_bodyTypeCount;t++)tree(d,&w->broadPhase.trees[t]);
    const b3HashSet*hs=&w->broadPhase.pairSet;VAL(d,hs->capacity);VAL(d,hs->count);
    for(uint32_t i=0;i<hs->capacity;i++)n_b3SetItem(d,hs->items+i);
    for(int i=0;i<B3_GRAPH_COLOR_COUNT;i++){
        const b3GraphColor*c=w->constraintGraph.colors+i;
        if(i!=B3_OVERFLOW_INDEX)bits(d,&c->bodySet);
        ARRAY(d,c->jointSims,n_b3JointSim);ARRAY(d,c->convexContacts,n_int);ARRAY(d,c->contacts,n_b3ContactSpec);
    }
    pending_ends(d,w);
}
const char* ogb3_state_coverage(void){return OGB3_STATE_COVERAGE_ID;}
uint32_t ogb3_state_version(void){return OGB3_STATE_DUMP_VERSION;}
int32_t ogb3_state_dump(uint32_t packed,uint8_t* bytes,uint64_t capacity,uint64_t* required){
    if(!required || (!bytes&&capacity))return OGB3_INVALID_ARGUMENT;
    b3WorldId id;_Static_assert(sizeof(id)==sizeof(packed),"world packing");memcpy(&id,&packed,sizeof(id));
    if(!b3World_IsValid(id))return OGB3_INVALID_HANDLE;
    const b3World*w=b3GetWorldFromId(id);if(!w->inUse)return OGB3_INVALID_HANDLE;
    if(w->locked)return OGB3_INVALID_ARGUMENT;
    Dump count={0};dump_world(&count,w);*required=count.size;
    if(count.failed)return OGB3_UNSUPPORTED;
    if(!bytes)return OGB3_OK;
    if(capacity<count.size)return OGB3_CAPACITY;
    Dump output={bytes,0,capacity,0};dump_world(&output,w);
    return output.failed?OGB3_UNSUPPORTED:OGB3_OK;
}
/* Do not carry a b3World pointer across the allocation below. Reacquire its
 * actual packed identity, including inUse and idle state, before emitting. */
static int32_t alloc_dump_world(uint32_t packed, const b3World **out) {
    b3WorldId id;
    _Static_assert(sizeof(id) == sizeof(packed), "world packing");
    memcpy(&id, &packed, sizeof(id));
    if (!b3World_IsValid(id)) return OGB3_INVALID_HANDLE;
    const b3World *w = b3GetWorldFromId(id);
    if (!w->inUse) return OGB3_INVALID_HANDLE;
    if (w->locked) return OGB3_INVALID_ARGUMENT;
    *out = w;
    return OGB3_OK;
}
int32_t ogb3_state_dump_alloc_internal(uint32_t packed, uint8_t **out_bytes,
                                       uint64_t *out_size) {
    if (!out_bytes || !out_size) return OGB3_INVALID_ARGUMENT;
    const b3World *w;
    int32_t status = alloc_dump_world(packed, &w);
    if (status) return status;
    Dump count = {0};
    dump_world(&count, w);
    if (count.failed) return OGB3_UNSUPPORTED;
    if (count.size > SIZE_MAX) return OGB3_CAPACITY;
    uint8_t *local = ogb3_snapshot_internal_alloc((size_t)count.size);
    if (!local) return OGB3_OUT_OF_MEMORY;
#ifdef OGB3_TESTING
    void (*callback)(uint32_t) = test_after_alloc;
    test_after_alloc = NULL;
    if (callback) callback(packed);
#endif
    status = alloc_dump_world(packed, &w);
    if (status) {
        ogb3_snapshot_internal_free(local);
        return status;
    }
    /* Existing put bounds every write. A changed size or unsupported field
     * can only affect this unpublished local buffer, which is then freed. */
    Dump output = {local, 0, count.size, 0};
    dump_world(&output, w);
    if (output.failed || output.size != count.size) {
        ogb3_snapshot_internal_free(local);
        return output.failed ? OGB3_UNSUPPORTED : OGB3_CORRUPT;
    }
    *out_bytes = local;
    *out_size = output.size;
    return OGB3_OK;
}
int32_t ogb3_state_digest(uint32_t world,uint64_t*complete,uint64_t*motion){
    if(!complete||!motion)return OGB3_INVALID_ARGUMENT;
    uint64_t n=0;int32_t status=ogb3_state_dump(world,NULL,0,&n);if(status)return status;
    uint8_t*data=ogb3_snapshot_internal_alloc((size_t)n);if(!data)return OGB3_OUT_OF_MEMORY;
    status=ogb3_state_dump(world,data,n,&n);
    if(status==OGB3_OK){
        uint64_t h=14695981039346656037ull;for(uint64_t i=0;i<n;i++)h=(h^data[i])*1099511628211ull;
        *complete=h;b3WorldId id;memcpy(&id,&world,sizeof(id));*motion=b3HashWorldState(b3GetWorldFromId(id));
    }
    ogb3_snapshot_internal_free(data);return status;
}
