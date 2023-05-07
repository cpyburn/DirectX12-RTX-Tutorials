# 3.0 Extra - DXR Tutorial Extra : Indexed Geometry
In this tutorial, we will use real indices instead of auto generated system indexes - PrimitiveIndex().

## .h Header file
```c++
// 3.0 Extra
ComPtr<ID3D12Resource> m_indexBuffer;
D3D12_INDEX_BUFFER_VIEW m_indexBufferView;
```

## LoadAssets method
```c++
// 3.0 Extra
Vertex triangleVertices[] = 
{
  {{0.0f, 0.25f * m_aspectRatio, 0.0f}, {1.0f, 1.0f, 0.0f, 1.0f}},
  {{0.25f, -0.25f * m_aspectRatio, 0.0f}, {0.0f, 1.0f, 1.0f, 1.0f}},
  {{-0.25f, -0.25f * m_aspectRatio, 0.0f}, {1.0f, 0.0f, 1.0f, 1.0f}}
};
```

Then, we need to create and set the indices right after setting m_vertexBufferView.
```c++
// 3.0 Extra - Create the index buffer
{
  std::vector<UINT> indices = { 0, 1, 2, 0, 3, 1, 0, 2, 3, 1, 3, 2 };
  const UINT indexBufferSize = static_cast<UINT>(indices.size()) * sizeof(UINT);
  CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD);
  CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(indexBufferSize);
  ThrowIfFailed(m_device->CreateCommittedResource(
    &heapProperty, 
    D3D12_HEAP_FLAG_NONE, 
    &bufferResource, 
    D3D12_RESOURCE_STATE_GENERIC_READ, 
    nullptr, IID_PPV_ARGS(&m_indexBuffer)));
  // Copy the triangle data to the index buffer.
  UINT8* pIndexDataBegin;
  CD3DX12_RANGE readRange(0, 0);		// We do not intend to read from this resource on the CPU.
  ThrowIfFailed(m_indexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pIndexDataBegin)));
  memcpy(pIndexDataBegin, indices.data(), indexBufferSize);
  m_indexBuffer->Unmap(0, nullptr);

  // Initialize the index buffer view.
  m_indexBufferView.BufferLocation = m_indexBuffer->GetGPUVirtualAddress();
  m_indexBufferView.Format = DXGI_FORMAT_R32_UINT;
  m_indexBufferView.SizeInBytes = indexBufferSize;
}
```

## PopulateCommandList method
To draw in the raster, you simply need to change how it is draw, by making the following changes in PopulateCommandList().
```c++
// 3.0 Extra
m_commandList->IASetIndexBuffer(&m_indexBufferView);
m_commandList->DrawIndexedInstanced(3, 1, 0, 0, 0);
```

## CreateBottomLevelAS method
To see this geometry in the raytracing path, we need to improve the CreateBottomLevelAS method to support indexed geometry. We first change the signature of the method to include index buffers:
```c++
D3D12HelloTriangle::AccelerationStructureBuffers D3D12HelloTriangle::CreateBottomLevelAS(std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vVertexBuffers, std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vIndexBuffers)
```
We then replace the beginning of the method as follows so that the bottom-level AS helper is called with indexing if needed:
```c++
// 3.0 Extra - Adding all vertex buffers and not transforming their position. 
for (size_t i = 0; i < vVertexBuffers.size(); i++)
{
  // 
  for (const auto& buffer : vVertexBuffers)
  {
    if (i < vIndexBuffers.size() && vIndexBuffers[i].second > 0)
      bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), vIndexBuffers[i].first.Get(), 0, vIndexBuffers[i].second, nullptr, 0, true);
    else
      bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), 0, 0);
  }
}
```

## CreateAccelerationStructures method
The acceleration structure build calls also need to be updated to reflect the new interface as well as to add the new geometry:
```c++
// 3.0 Extra
AccelerationStructureBuffers bottomLevelBuffers = CreateBottomLevelAS({ {m_vertexBuffer.Get(), 3} }, { {m_indexBuffer.Get(), 3} });
```
But the shading is not correct with the raytracer. This is because we are accessing invalid data in the Hit Shader.
```c++
// 3.0 Extra
uint vertId = 3 * indices[PrimitiveIndex()];
```

## CreateHitSignature
Changing the shader is not enough, we need to inform the shader that more information is needed.
Do to this, change the signature in `CreateHitSignature`.
```c++
// 3.0 Extra
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 0); //t0
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 1); //t1
```

## CreateShaderBindingTable
Finally, we need to bind the new data to the shader and we are doing it in the `CreateShaderBindingTable` by modifying
the data pass to the `HitGroup`.
```c++
// 3.0 Extra
m_sbtHelper.AddHitGroup(L"HitGroup", 
  { 
    (void*)(m_vertexBuffer->GetGPUVirtualAddress()), 
    // 3.0 Extra
    (void*)(m_indexBuffer->GetGPUVirtualAddress()) 
  });
```

Now the result in the raytracer is similar to the rasterizer. Note that if you have other hit groups attached to the same root signature, you would have to adjust their list of root parameters as well. 
