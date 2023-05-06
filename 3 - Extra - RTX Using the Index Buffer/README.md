TODO: this is working but documentation needs to be cleaned up

DXR Tutorial Extra : Indexed Geometry
Welcome to the next section of the tutorial. If you miss the first tutorial, it is here The bases of this tutorial starts at the end of the previous one. You can download the entire project here The first tutorial only shows a triangle, which can feel a bit simplistic:  In this tutorial, we will convert the plane triangle to a three dimensional one, a tetrahedron. Do do this, we will convert the simple triangle to an indexed version of it. Add the new resources

ComPtr<id3d12resource> m_indexBuffer;
D3D12_INDEX_BUFFER_VIEW m_indexBufferView;
LoadAssets
Instead of a simple triangle, let's create a tetrahedron, which requires 4 vertices.

Vertex triangleVertices[] = { {{std::sqrtf(8.f / 9.f), 0.f, -1.f / 3.f}, {1.f, 0.f, 0.f, 1.f}}, {{-std::sqrtf(2.f / 9.f), std::sqrtf(2.f / 3.f), -1.f / 3.f}, {0.f, 1.f, 0.f, 1.f}}, {{-std::sqrtf(2.f / 9.f), -std::sqrtf(2.f / 3.f), -1.f / 3.f}, {0.f, 0.f, 1.f, 1.f}}, {{0.f, 0.f, 1.f}, {1, 0, 1, 1}}};
Then, we need to create and set the indices right after setting m_vertexBufferView.

//----------------------------------------------------------------------------------------------
// Indices
std::vector<uint> indices = {0, 1, 2, 0, 3, 1, 0, 2, 3, 1, 3, 2};
const UINT indexBufferSize = static_cast<uint>(indices.size()) * sizeof(UINT);
CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD);
CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(indexBufferSize);
ThrowIfFailed(m_device->CreateCommittedResource( &heapProperty, D3D12_HEAP_FLAG_NONE, &bufferResource, // D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&m_indexBuffer)));
// Copy the triangle data to the index buffer.
UINT8* pIndexDataBegin;
ThrowIfFailed(m_indexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pIndexDataBegin)));
memcpy(pIndexDataBegin, indices.data(), indexBufferSize);
m_indexBuffer->Unmap(0, nullptr);
// Initialize the index buffer view.
m_indexBufferView.BufferLocation = m_indexBuffer->GetGPUVirtualAddress();
m_indexBufferView.Format = DXGI_FORMAT_R32_UINT;
m_indexBufferView.SizeInBytes = indexBufferSize;
PopulateCommandList
To draw the tetrahedron in the raster, you simply need to change how it is draw, by making the following changes in PopulateCommandList().

m_commandList->IASetVertexBuffers(0, 1, &m_vertexBufferView);
m_commandList->IASetIndexBuffer(&m_indexBufferView);
m_commandList->DrawIndexedInstanced(12, 1, 0, 0, 0);
The result image is not great an will be quite flat 

CreateBottomLevelAS
To see this geometry in the raytracing path, we need to improve the CreateBottomLevelAS method to support indexed geometry. We first change the signature of the method to include index buffers:

AccelerationStructureBuffers CreateBottomLevelAS( std::vector<std::pair<comptr<id3d12resource>, uint32_t>> vVertexBuffers, std::vector<std::pair<comptr<id3d12resource>, uint32_t>> vIndexBuffers = {});
We then replace the beginning of the method as follows so that the bottom-level AS helper is called with indexing if needed:

// #DXR Extra: Indexed Geometry
D3D12HelloTriangle::AccelerationStructureBuffers
D3D12HelloTriangle::CreateBottomLevelAS( std::vector<std::pair<comptr<id3d12resource>, uint32_t>> vVertexBuffers, std::vector<std::pair<comptr<id3d12resource>, uint32_t>> vIndexBuffers) { nv_helpers_dx12::BottomLevelASGenerator bottomLevelAS; // Adding all vertex buffers and not transforming their position. for (size_t i = 0; i < vVertexBuffers.size(); i++) { // for (const auto &buffer : vVertexBuffers) { if (i < vIndexBuffers.size() && vIndexBuffers[i].second > 0) bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), vIndexBuffers[i].first.Get(), 0, vIndexBuffers[i].second, nullptr, 0, true); else bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), 0, 0); }
CreateAccelerationStructures
The acceleration structure build calls also need to be updated to reflect the new interface as well as to add the new geometry:

// Build the bottom AS from the Triangle vertex buffer
AccelerationStructureBuffers bottomLevelBuffers =
CreateBottomLevelAS({{m_vertexBuffer.Get(), 4}}, {{m_indexBuffer.Get(), 12}});
But the shading is not correct with the raytracer. This is because we are accessing invalid data in the Hit Shader.


Shading issue
Hit Shader
In the hit shader, we will need to access the indices

StructuredBuffer<int> indices: register(t1);
Then in the shader access the right vertex

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateHitSignature
Changing the shader is not enough, we need to inform the shader that more information is needed.
Do to this, change the signature in `CreateHitSignature`.
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 0 /t0/); // vertices and colors rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 1 /t1/); // indices

## CreateShaderBindingTable
Finally, we need to bind the new data to the shader and we are doing it in the `CreateShaderBindingTable` by modifying
the data pass to the `HitGroup`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ m_sbtHelper.AddHitGroup(L"HitGroup", {(void*)(m_vertexBuffer->GetGPUVirtualAddress()), (void*)(m_indexBuffer->GetGPUVirtualAddress())});
Now the result in the raytracer is similar to the rasterizer. Note that if you have other hit groups attached to the same root signature, you would have to adjust their list of root parameters as well. 
