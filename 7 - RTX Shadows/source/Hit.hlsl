#include "Common.hlsl"

//struct STriVertex
//{
//	float3 vertex; 
//	float4 color;
//};
//
//StructuredBuffer<STriVertex> BTriVertex : register(t0);

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

[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
    //uint vertId = 3 * PrimitiveIndex();
    //float3 hitColor = BTriVertex[vertId + 0].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
    //// 19.3
    //switch (InstanceID())
    //{
    //case 0: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(0, 1, 0); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
    //    break;
    //case 1: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(1, 1, 0); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
    //    break;
    //case 2: hitColor = (barycentrics.x + barycentrics.y + barycentrics.z) * float3(0, 1, 1); // add a color that is different for each instance and then multiply that by hitcolor from vertex data buffer (BTriVertex) so triangles look different
    //    break;
    //}

    // 19.12 #DXR Extra: Per-Instance Data
    //float3 hitColor = float3(0.6, 0.7, 0.6);
    //// Shade only the first 3 instances (triangles)
    //if (InstanceID() < 3)
    //{
    //    hitColor = A[InstanceID()].xyz * barycentrics.x + B[InstanceID()].xyz * barycentrics.y + C[InstanceID()].xyz * barycentrics.z;
    //}

    // 19.13 #DXR Extra: Per-Instance Data
    //int instanceID = InstanceID();
    //float3 hitColor = Tint[instanceID].a * barycentrics.x + Tint[instanceID].b * barycentrics.y + Tint[instanceID].c * barycentrics.z;

    // 20.5 #DXR Extra: Per-Instance Data
    float3 hitColor = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;

    payload.colorAndDistance = float4(hitColor, RayTCurrent());
}

// 20.7 #DXR Extra: Per-Instance Data
[shader("closesthit")]
void PlaneClosestHit(inout HitInfo payload, Attributes attrib)
{
    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y); 
    float3 hitColor = float3(0.7, 0.7, 0.3); 
    payload.colorAndDistance = float4(hitColor, RayTCurrent());
}