#include "Common.hlsl"

struct STriVertex
{
	float3 vertex; 
	float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0);

// 19.12 #DXR Extra: Per-Instance Data
//cbuffer Colors : register(b0)
//{
//    float4 A[3];
//    float4 B[3];
//    float4 C[3];
//}

// 19.13 #DXR Extra: Per-Instance Data
//struct MyStructColor
//{
//    float4 a; 
//    float4 b; 
//    float4 c;
//};
//cbuffer Colors : register(b0)
//{
//    MyStructColor Tint[3];
//}

// 20.5 #DXR Extra: Per-Instance Data
cbuffer Colors : register(b0)
{
    float3 A;
    float3 B;
    float3 C;
}

// 21.2 #DXR Extra - Another ray type
struct ShadowHitInfo
{
    bool isHit;
};

// 21.2 #DXR Extra - Another ray type
// Raytracing acceleration structure, accessed as a SRV
RaytracingAccelerationStructure SceneBVH : register(t2);

//[shader("closesthit")]
//void ClosestHit(inout HitInfo payload, Attributes attrib)
//{
//    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
//    //uint vertId = 3 * PrimitiveIndex();
//    //float3 hitColor = BTriVertex[vertId + 0].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
//    //// 19.3
//    //switch (InstanceID())
//    //{
//    //case 0: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(0, 1, 0); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
//    //    break;
//    //case 1: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(1, 1, 0); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
//    //    break;
//    //case 2: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(0, 1, 1); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
//    //    break;
//    //}
//
//    // 19.12 #DXR Extra: Per-Instance Data
//    //float3 hitColor = float3(0.6, 0.7, 0.6);
//    //// Shade only the first 3 instances (triangles)
//    //if (InstanceID() < 3)
//    //{
//    //    hitColor = A[InstanceID()].xyz * barycentrics.x + B[InstanceID()].xyz * barycentrics.y + C[InstanceID()].xyz * barycentrics.z;
//    //}
//
//    // 19.13 #DXR Extra: Per-Instance Data
//    //int instanceID = InstanceID();
//    //float3 hitColor = Tint[instanceID].a * barycentrics.x + Tint[instanceID].b * barycentrics.y + Tint[instanceID].c * barycentrics.z;
//
//    // 20.5 #DXR Extra: Per-Instance Data
//    float3 hitColor = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
//
//    payload.colorAndDistance = float4(hitColor, RayTCurrent());
//}

// 20.7 #DXR Extra: Per-Instance Data
[shader("closesthit")]
void PlaneClosestHit(inout HitInfo payload, Attributes attrib)
{
    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
    float3 hitColor = float3(0.7, 0.7, 0.3);
    payload.colorAndDistance = float4(hitColor, RayTCurrent());
}

// 21.2 #DXR Extra - Another ray type 
[shader("closesthit")]
void PlaneClosestHit(inout HitInfo payload, Attributes attrib)
{
    float3 lightPos = float3(2, 2, -2);
    // Find the world - space hit position 
    float3 worldOrigin = WorldRayOrigin() + RayTCurrent() * WorldRayDirection();
    float3 lightDir = normalize(lightPos - worldOrigin);
    // Fire a shadow ray. The direction is hard-coded here, but can be fetched 
    // from a constant-buffer 
    RayDesc ray;
    ray.Origin = worldOrigin;
    ray.Direction = lightDir;
    ray.TMin = 0.01;
    ray.TMax = 100000;
    bool hit = true;
    // Initialize the ray payload 
    ShadowHitInfo shadowPayload;
    shadowPayload.isHit = false;
    // Trace the ray 
    TraceRay(
        // Acceleration structure 
        SceneBVH,
        // Flags can be used to specify the behavior upon hitting a surface 
        RAY_FLAG_NONE,
        // Instance inclusion mask, which can be used to mask out some geometry to 
        // this ray by and-ing the mask with a geometry mask. The 0xFF flag then 
        // indicates no geometry will be masked 
        0xFF,
        // Depending on the type of ray, a given object can have several hit 
        // groups attached (ie. what to do when hitting to compute regular 
        // shading, and what to do when hitting to compute shadows). Those hit 
        // groups are specified sequentially in the SBT, so the value below 
        // indicates which offset (on 4 bits) to apply to the hit groups for this 
        // ray. In this sample we only have one hit group per object, hence an 
        // offset of 0. 
        1,
        // The offsets in the SBT can be computed from the object ID, its instance 
        // ID, but also simply by the order the objects have been pushed in the 
        // acceleration structure. This allows the application to group shaders in 
        // the SBT in the same order as they are added in the AS, in which case 
        // the value below represents the stride (4 bits representing the number 
        // of hit groups) between two consecutive objects. 
        0,
        // Index of the miss shader to use in case several consecutive miss 
        // shaders are present in the SBT. This allows to change the behavior of 
        // the program when no geometry have been hit, for example one to return a 
        // sky color for regular rendering, and another returning a full 
        // visibility value for shadow rays. This sample has only one miss shader, 
        // hence an index 0 
        1,
        // Ray information to trace 
        ray,
        // Payload associated to the ray, which will be used to communicate 
        // between the hit/miss shaders and the raygen
        shadowPayload);

    float factor = shadowPayload.isHit ? 0.3 : 1.0;
    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
    float4 hitColor = float4(float3(0.7, 0.7, 0.3) * factor, RayTCurrent());
    payload.colorAndDistance = float4(hitColor);
}