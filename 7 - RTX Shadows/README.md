# 21. RTX Shadows
DXR allows using several ray types, typically to render different effects such as primary rays, which we have been doing in the previous tutorials, and shadow rays. Before starting this tutorial we first need to add some more geometry to cast shadows on, and a perspective camera. Once done, the image should look like this:  We first need to declare the new shader library for the shadow shaders, as well as its root signature at the end of the header:
```c++
// 21. #DXR Extra - Another ray type
ComPtr<IDxcBlob> m_shadowLibrary;
ComPtr<ID3D12RootSignature> m_shadowSignature;
```
## 21.1 ShadowRay.hlsl
Create a file ShadowRay.hlsl, add it to the project, and exclude it from the build to avoid fxc to be called during the build. This file will contain the shader code executed when tracing a shadow ray:
```c++
// 21.1 #DXR Extra - Another ray type
// Ray payload for the shadow rays
struct ShadowHitInfo
{
	bool isHit;
};

struct Attributes
{
	float2 uv;
};

[shader("closesthit")]
void ShadowClosestHit(inout ShadowHitInfo hit, Attributes bary)
{
	hit.isHit = true;
}

[shader("miss")]
void ShadowMiss(inout ShadowHitInfo hit : SV_RayPayload)
{
	hit.isHit = false;
}
```
This ray type has its own payload ShadowHitInfo. When hitting a surface the payload is set to true, while when missing all geometry the ShadowMiss is invoked, setting the payload to false.

## 21. Hit.hlsl
The hit shader needs to be able to cast shadow rays, so we first declare the shadow ray payload at the beginning of the file:

// #DXR Extra - Another ray type
struct ShadowHitInfo
{ bool isHit;
};
To cast more rays, the hit shader for the plane needs to access the top-level acceleration structure.

// #DXR Extra - Another ray type
// Raytracing acceleration structure, accessed as a SRV
RaytracingAccelerationStructure SceneBVH : register(t2);
The PlaneClosestHit function can then be modified to shoot shadow rays. From the hit point we initialize a shadow ray towards a hardcoded light position lightPos. The payload after the trace call indicates whether a surface has been hit, and we use it to modify the output color.

// #DXR Extra - Another ray type
[shader("closesthit")] void ClosestHit(inout HitInfo payload, Attributes attrib) { float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y); uint vertId = 3 * PrimitiveIndex(); // #DXR Extra: Per-Instance Data float3 hitColor = float3(0.6, 0.7, 0.6); // Shade only the first 3 instances (triangles) if (InstanceID() < 3) { // #DXR Extra: Per-Instance Data hitColor = BTriVertex[indices[vertId + 0]].color * barycentrics.x + BTriVertex[indices[vertId + 1]].color * barycentrics.y + BTriVertex[indices[vertId + 2]].color * barycentrics.z; } payload.colorAndDistance = float4(hitColor, RayTCurrent());
} // #DXR Extra - Another ray type [shader("closesthit")] void PlaneClosestHit(inout HitInfo payload, Attributes attrib) { float3 lightPos = float3(2, 2, -2); // Find the world - space hit position float3 worldOrigin = WorldRayOrigin() + RayTCurrent() * WorldRayDirection(); float3 lightDir = normalize(lightPos - worldOrigin); // Fire a shadow ray. The direction is hard-coded here, but can be fetched // from a constant-buffer RayDesc ray; ray.Origin = worldOrigin; ray.Direction = lightDir; ray.TMin = 0.01; ray.TMax = 100000; bool hit = true; // Initialize the ray payload ShadowHitInfo shadowPayload; shadowPayload.isHit = false; // Trace the ray TraceRay( // Acceleration structure SceneBVH, // Flags can be used to specify the behavior upon hitting a surface RAY_FLAG_NONE, // Instance inclusion mask, which can be used to mask out some geometry to // this ray by and-ing the mask with a geometry mask. The 0xFF flag then // indicates no geometry will be masked 0xFF, // Depending on the type of ray, a given object can have several hit // groups attached (ie. what to do when hitting to compute regular // shading, and what to do when hitting to compute shadows). Those hit // groups are specified sequentially in the SBT, so the value below // indicates which offset (on 4 bits) to apply to the hit groups for this // ray. In this sample we only have one hit group per object, hence an // offset of 0. 1, // The offsets in the SBT can be computed from the object ID, its instance // ID, but also simply by the order the objects have been pushed in the // acceleration structure. This allows the application to group shaders in // the SBT in the same order as they are added in the AS, in which case // the value below represents the stride (4 bits representing the number // of hit groups) between two consecutive objects. 0, // Index of the miss shader to use in case several consecutive miss // shaders are present in the SBT. This allows to change the behavior of // the program when no geometry have been hit, for example one to return a // sky color for regular rendering, and another returning a full // visibility value for shadow rays. This sample has only one miss shader, // hence an index 0 1, // Ray information to trace ray, // Payload associated to the ray, which will be used to communicate // between the hit/miss shaders and the raygen shadowPayload); float factor = shadowPayload.isHit ? 0.3 : 1.0; float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y); float4 hitColor = float4(float3(0.7, 0.7, 0.3) * factor, RayTCurrent()); payload.colorAndDistance = float4(hitColor);
}
## 21. CreateHitSignature
Since the hit shader now needs to access the scene data, its root signature needs to be enhanced to get access to the SRV containing the top-level acceleration structure, which is stored in the second slot of the heap. Add this code after adding the root parameter:

// #DXR Extra - Another ray type
// Add a single range pointing to the TLAS in the heap
rsc.AddHeapRangesParameter({ { 2 /*t2*/, 1, 0, D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 1 /*2nd slot of the heap*/ },
});
## 21. CreateRaytracingPipeline
We now need to load the shader library and export the corresponding symbols:

// #DXR Extra - Another ray type
m_shadowLibrary = nv_helpers_dx12::CompileShaderLibrary(L"ShadowRay.hlsl");
pipeline.AddLibrary(m_shadowLibrary.Get(), { L"ShadowClosestHit", L"ShadowMiss" });
m_shadowSignature = CreateHitSignature();
The new closest hit shader also requires to be put into a hit group:

// #DXR Extra - Another ray type
// Hit group for all geometry when hit by a shadow ray
pipeline.AddHitGroup(L"ShadowHitGroup", L"ShadowClosestHit");
That hit group is then associated with its root signature:

// #DXR Extra - Another ray type
pipeline.AddRootSignatureAssociation(m_shadowSignature.Get(), { L"ShadowHitGroup" });
The miss program for shadows has the same signature as the original miss shader, so we can simply associate it to the same root signature by modifying the miss shader association:

// #DXR Extra - Another ray type
pipeline.AddRootSignatureAssociation(m_missSignature.Get(), {L"Miss", L"ShadowMiss"});
Since it will now be possible to shoot rays from a hit point, this means rays are traced recursively. We then increase the allowed recursion level to 2, keeping in mind that this level needs to be kept as low as possible:

// #DXR Extra - Another ray type
pipeline.SetMaxRecursionDepth(2);
## 21. CreateShaderBindingTable
The raytracing pipeline is ready to shoot shadow rays, but the actual shader still needs to be associated to the geometry in the Shader Binding Table. To do this, we add the shadow miss program after the original miss:

// #DXR Extra - Another ray type
m_sbtHelper.AddMissProgram(L"ShadowMiss", {});
The shadow hit group is added right after adding each addition of the original hit group, so that all the geometry can be hit:

// #DXR Extra - Another ray type
m_sbtHelper.AddHitGroup(L"ShadowHitGroup", {});
The resources for the plane hit group need to be enhanced to give access to the heap:

// #DXR Extra - Another ray type
m_sbtHelper.AddHitGroup(L"PlaneHitGroup", {(void*)(m_constantBuffers[0]->GetGPUVirtualAddress()), heapPointer});
## 21. CreateTopLevelAS
The last addition is required to associate the geometry with the corresponding hit groups. In the previous tutorials we indicated that the hit group index of an instance is equal to its instance index, since we only had one hit group per instance. Now we have two hit groups (primary and shadow), so the hit group index has to be 2*i, where i is the instance index:

// #DXR Extra - Another ray type
for (size_t i = 0; i < instances.size(); i++)
{ m_topLevelASWrapper.AddInstance(instances[i].first.Get(), instances[i].second, static_cast<uint>(i), static_cast<uint>(2*i) /*2 hit groups per instance*/);
}
Running this program should now show shadows projected on the plane:  This example introduces how to use several ray types with an application to simple shadows. A more efficient shadow ray implementation would only use a miss shader setting the payload to false, and no closest hit shader. This modification is left as an exercise for the reader.
