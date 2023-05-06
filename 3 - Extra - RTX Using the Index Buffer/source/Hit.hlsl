#include "Common.hlsl"

struct STriVertex
{
	float3 vertex; 
	float4 color;
};
StructuredBuffer<STriVertex> BTriVertex : register(t0);
// 3.0 Extra
StructuredBuffer<int> indices: register(t1);

[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
    float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
    //uint vertId = 3 * PrimitiveIndex();
    // 3.0 Extra
    uint vertId = 3 * indices[PrimitiveIndex()];
    float3 hitColor = BTriVertex[vertId + 0].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
    payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
