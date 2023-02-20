# 22. Animation Refitting
In this tutorial we will consider adding movement in the scene. While this can be done straightforwardly by completely recomputing the acceleration structures, much faster updates can be performed by simply refitting those using the new vertex coordinates or instance transforms. For the sake of simplicity this document only considers updating instance matrices and the top-level acceleration structure, but the same approach can be used to update bottom-level AS as well. In the header file, we first need to modify the signature of CreateTopLevelAS to be able to indicate whether to do a full build or a simple update:

/// Create the main acceleration structure that holds
/// all instances of the scene
/// \param instances : pair of BLAS and transform
// #DXR Extra - Refitting
/// \param updateOnly: if true, perform a refit instead of a full build
void CreateTopLevelAS( const std::vector<std::pair<comptr<id3d12resource>, DirectX::XMMATRIX>>& instances, bool updateOnly = false);
To animate the scene, we use a simple time counter, to add at the end of the header file:

// #DXR Extra - Refitting
uint32_t m_time = 0;
OnUpdate
This method is called before each render. The time counter will be incremented for each frame, and used to compute a new transform matrix for the triangle:

// #DXR Extra - Refitting
// Increment the time counter at each frame, and update the corresponding instance matrix of the
// first triangle to animate its position
m_time++;
m_instances[0].second = XMMatrixRotationAxis({ 0.f, 1.f, 0.f }, static_cast<float>(m_time) / 50.0f)* XMMatrixTranslation(0.f, 0.1f * cosf(m_time / 20.f), 0.f);
CreateTopLevelAS
Change the signature according to the header:

void D3D12HelloTriangle::CreateTopLevelAS( const std::vector<std::pair<comptr<id3d12resource>, DirectX::XMMATRIX>>& instances, // pair of bottom level AS and matrix of the instance // #DXR Extra - Refitting bool updateOnly // If true the top-level AS will only be refitted and not // rebuilt from scratch
)
In case only a refit is necessary, there is no need to add the instances in the helper. Similarly, a refit does not change the size of the resulting acceleration structure so the already allocated buffers can be kept. To do that, add a condition block from the beginning of the function until the last call to CreateBuffer:

// #DXR Extra - Refitting
if (!updateOnly)
{ ...
}
The AS builder also needs to be informed that only a refit is necessary, by providing two optional parameters to the Build call. The first is our updateOnly flag to indicate a refit, and the second is the existing acceleration structure. This is required to be able to update it, and provides the flexibility to either update the AS in place, or to make a copy.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## PopulateCommandList
The last piece is a call to `CreateTopLevelAS` for each frame. The AS builder requires an open command list, so we add the call at the beginning of the
raytracing branch:
// #DXR Extra - Refitting // Refit the top-level acceleration structure to account for the new transform matrix of the // triangle. Note that the build contains a barrier, hence we can do the rendering in the // same command list CreateTopLevelAS(m_instances, true);

That's all you need!
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/animatedTriangle.gif)
# Adding Animation to the Raster Mode
For now the triangle is only animated in raytracing mode, but remains fixed in raster mode.
The way object transforms are handled with raytracing is very different from rasterization. In the latter, no data structures need to be
generated, but we need to transfer the transform matrix of the objects to the vertex shader, that will transform the positions before projecting
them into camera space for rasterization.
To do this, we will need to setup a heap, which references a buffer containing the matrices. The heap creation for raster is already covered
in the [Perspective Camera](/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_perspective) extra, so the remainder of this section assumes the perspective camera has
been setup. In looks nicer anyway!
At the end of the header file, add the following class members to create and hold a buffer containing the matrices for each object in the scene.
We store those matrices in a structure to allow more per-instance data to be passed in later chapters.
// #DXR Extra - Refitting /// Per-instance properties struct InstanceProperties { XMMATRIX objectToWorld; }; ComPtr m_instanceProperties; void CreateInstancePropertiesBuffer(); void UpdateInstancePropertiesBuffer();

At the end of the source file, we add the allocation of the buffer containing the instance properties, where `CreateBuffer` internally calls
`CreateCommittedResource` with a buffer dimension `D3D12_RESOURCE_DIMENSION_BUFFER`. Note that this buffer is allocated on the upload heap
as it will be mapped afterwards:
//-------------------------------------------------------------------------------------------------- // Allocate memory to hold per-instance information // #DXR Extra - Refitting void D3D12HelloTriangle::CreateInstancePropertiesBuffer() { uint32_t bufferSize = ROUND_UP(static_cast(m_instances.size()) * sizeof(InstanceProperties), D3D12_CONSTANT_BUFFER_DATA_PLACEMENT_ALIGNMENT); // Create the constant buffer for all matrices m_instanceProperties = nv_helpers_dx12::CreateBuffer( m_device.Get(), bufferSize, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ, nv_helpers_dx12::kUploadHeapProps); }

The actual data is copied in the buffer through mapping by `UpdateInstancePropertiesBuffer`:
//-------------------------------------------------------------------------------------------------- // Copy the per-instance data into the buffer // #DXR Extra - Refitting void D3D12HelloTriangle::UpdateInstancePropertiesBuffer() { InstanceProperties current = nullptr; CD3DX12_RANGE readRange(0, 0); // We do not intend to read from this resource on the CPU. ThrowIfFailed(m_instanceProperties->Map(0, &readRange, reinterpret_cast(¤t))); for (const auto &inst : m_instances) { current->objectToWorld = inst.second; current++; } m_instanceProperties->Unmap(0, nullptr); }

## CreateCameraBuffer
This method already contains the creation of `m_constHeap`, which references the buffer holding the camera matrices. We will enhance
that heap by adding a reference to our `m_instanceProperties` buffer. The heap had a size of `1`, so we first need to make it larger:
// #DXR Extra - Refitting // Create a descriptor heap that will be used by the rasterization shaders: // Camera matrices and per-instance matrices m_constHeap = nv_helpers_dx12::CreateDescriptorHeap( m_device.Get(), 2, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, true);

At the end of the method, create a view on the `m_instanceProperties` buffer:
// #DXR Extra - Refitting // Add the per-instance buffer srvHandle.ptr += m_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV); D3D12_SHADER_RESOURCE_VIEW_DESC srvDesc; srvDesc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING; srvDesc.Format = DXGI_FORMAT_UNKNOWN; srvDesc.ViewDimension = D3D12_SRV_DIMENSION_BUFFER; srvDesc.Buffer.FirstElement = 0; srvDesc.Buffer.NumElements = static_cast(m_instances.size()); srvDesc.Buffer.StructureByteStride = sizeof(InstanceProperties); srvDesc.Buffer.Flags = D3D12_BUFFER_SRV_FLAG_NONE; // Write the per-instance buffer view in the heap m_device->CreateShaderResourceView(m_instanceProperties.Get(), &srvDesc, srvHandle);

## LoadAssets
Now the buffer is available in the heap, we need to modify the root signature of the shader to access it. We will also add a root constant
parameter, which will allow us to specify which instance is currently rendering, so that the shader can find the corresponding matrix in the buffer.
The original root signature for the rasterization shaders does not use our helpers, but uses the ones defined in `d3dx12.h`. To minimize code changes,
we will continue using those helpers here.
Right after the initialization of `constantParameter`, add a new root parameter corresponding to the per-instance properties buffer. Note that
the `Init` contains 4 parameters (compared to 2 for `constantParameter`). In order, the parameters are first the type, set as a Shader Resource View (SRV),
then the number of descriptors in the range (`1` in our case). The first `0` indicates the register index, meaning the buffer will be mapped to
`register(t0)` (`t` is for SRV bindings). The second `0` is the register space, which is set to the implicit `space0`. Finally, the lat `1` is the
index of the heap slot containing the view to the per-instance properties buffer, which is in the second position behind the camera parameters.
// #DXR Extra - Refitting // Per-instance properties buffer CD3DX12_ROOT_PARAMETER matricesParameter; CD3DX12_DESCRIPTOR_RANGE matricesRange; matricesRange.Init(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 1 / desc count*/, 0 /register/, 0 /space/, 1 /heap slot/); matricesParameter.InitAsDescriptorTable(1, &matricesRange, D3D12_SHADER_VISIBILITY_ALL);

Our rasterization code does not use instancing per se: instead, each object has its own `Draw*Instanced` call. To allow the shader to find
the matrix corresponding to the currently rendered object, we pass the index of the per-instance properties as a 32-bit root constant. Add
the lines below right after initializing the `matricesParameter` descriptor: we have one constant value, bound to `register(b1)`, as `b` stands
for both root constants and constant buffers.
// #DXR Extra - Refitting // Per-instance properties index for the current geometry CD3DX12_ROOT_PARAMETER indexParameter; indexParameter.InitAsConstants(1 /value count/, 1 /register/);

The initialization of the root signature is then changed to use all 3 parameters instead of just the camera parameters:
// #DXR Extra - Refitting std::vector params = {constantParameter, matricesParameter, indexParameter}; CD3DX12_ROOT_SIGNATURE_DESC rootSignatureDesc; rootSignatureDesc.Init(static_cast(params.size()), params.data(), 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

Since we are rendering a single triangle, we can disable culling at the end of the initialization of the `D3D12_GRAPHICS_PIPELINE_STATE_DESC`
to make it visible under all orientations:
// #DXR Extra - Refitting psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;

## PopulateCommandList
The access to the actual data needs to be specified for each root signature parameter just before rendering. In the rasterization path,
replace the call to `SetGraphicsRootDescriptorTable` by the setup for each root signature parameter. We then have one call to
`SetGraphicsRootDescriptorTable` for each buffer: since they use the same heap, they refer to the same pointer. The instance index
is set to 0 since we have only one object in the scene. This is done by calling `SetGraphicsRoot32BitConstant`.
// #DXR Extra - Refitting D3D12_GPU_DESCRIPTOR_HANDLE handle = m_constHeap->GetGPUDescriptorHandleForHeapStart(); // Access to the camera buffer, 1st parameter of the root signature m_commandList->SetGraphicsRootDescriptorTable(0, handle); // Access to the per-instance properties buffer, 2nd parameter of the root signature m_commandList->SetGraphicsRootDescriptorTable(1, handle); // Instance index in the per-instance properties buffer, 3rd parameter of the root signature // Here we set the value to 0, and since we have only 1 constant, the offset is 0 as well m_commandList->SetGraphicsRoot32BitConstant(2, 0, 0);

Note that when adding other objects, which have their own `Draw*` call, the call to `SetGraphicsRoot32BitConstant` needs to be done
for each with the corresponding index.
## OnInit
Add the creation of the buffer just before calling `CreateCameraBuffer`:
// #DXR Extra - Refitting CreateInstancePropertiesBuffer();

## OnUpdate
The contents of the buffer need to be updated for each frame, so we add a call to `UpdateInstancePropertiesBuffer` right after `UpdateCameraBuffer`:
// #DXR Extra - Refitting UpdateInstancePropertiesBuffer();

## shaders.hlsl
The last modification is the vertex shader. We first need to add the access to the per-instance properties and to the instance index. Note the
binding to `t0` and `b1` matching the description of the root signature:
// #DXR Extra - Refitting struct InstanceProperties { float4×4 objectToWorld; }; StructuredBuffer instanceProps : register(t0); uint instanceIndex : register(b1);

In `VSMain`, we can now simply multiply the vertex position by the instance matrix to transform it:
// #DXR Extra - Refitting float4 pos = mul(instanceProps[instanceIndex].objectToWorld, position); ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now the animation is also visible in the rasterization path!
