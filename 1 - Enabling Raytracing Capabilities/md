## 6. Enabling Raytracing Capabilities

Raytracing-enabled Device and Command List
Our sample uses the simplest APIs of DirectX12, exposed in the ID3D12Device and ID3D12GraphicsCommandList classes. The raytracing APIs are much more advanced and recent, and were included in the ID3D12Device5 and ID3D12GraphicsCommandList4 classes. In D3D12HelloTriangle.h, we replace the declaration of m_device and m_commandList accordingly:

ComPtr<id3d12device5> m_device;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ C ComPtr m_commandList;

## Checking for Raytracing Support
In `D3D12HelloTriangle.h`, we add a method for checking whether the device supports raytracing:void CheckRaytracingSupport();
The body of the function is added to the D3D12HelloTriangle.cpp file. The raytracing features are part of the D3D12_FEATURE_DATA_D3D12_OPTIONS5 feature set:

void D3D12HelloTriangle::CheckRaytracingSupport() { D3D12_FEATURE_DATA_D3D12_OPTIONS5 options5 = {}; ThrowIfFailed(m_device->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS5, &options5, sizeof(options5))); if (options5.RaytracingTier < D3D12_RAYTRACING_TIER_1_0) throw std::runtime_error("Raytracing not supported on device");
}
We then add a call to this method at the end of OnInit:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We will also add the ability to switch between Raster and RayTracing by pressing the `SPACEBAR`.
In `D3D12HelloTriangle.h`, for convenience, we also introduce a function to switch between raytracing and raster at runtime.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ C virtual void OnKeyUp(UINT8 key); bool m_raster = true;
All the code snippets go into the private section.
!!! Tip All the code snippets go into the private section.
OnInit()
In the original D3D12HelloTriangle sample, the LoadAssets method creates, initializes and closes the command list. The raytracing setup will require an open command list, and for clarity we prefer adding the methods initializing the raytracing in the OnInit method. Therefore we need to move the following lines from LoadAssets() and put them at the end of the OnInit() function.

// Command lists are created in the recording state, but there is
// nothing to record yet. The main loop expects it to be closed, so
// close it now.
ThrowIfFailed(m_commandList->Close());
LoadPipeline()
This is not required, but for consistency you can change the feature level to D3D_FEATURE_LEVEL_12_1.

PopulateCommandList()
Find the block clearing the buffer and issuing the draw commands:

const float clearColor[] = { 0.0f, 0.2f, 0.4f, 1.0f };
m_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
m_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
m_commandList->IASetVertexBuffers(0, 1, &m_vertexBufferView);
m_commandList->DrawInstanced(3, 1, 0, 0);
and replace it by the following, so that we will execute this block only in rasterization mode. In the raytracing path we will simply clear the buffer with a different color for now.

// Record commands.
// #DXR
if (m_raster)
{ const float clearColor[] = { 0.0f, 0.2f, 0.4f, 1.0f }; m_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST); m_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr); m_commandList->IASetVertexBuffers(0, 1, &m_vertexBufferView); m_commandList->DrawInstanced(3, 1, 0, 0);
}
else
{ const float clearColor[] = { 0.6f, 0.8f, 0.4f, 1.0f }; m_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
}
OnKeyUp()
Add the following function for toggling between raster and ray-traced modes.

//-----------------------------------------------------------------------------
//
//
void D3D12HelloTriangle::OnKeyUp(UINT8 key)
{ // Alternate between rasterization and raytracing using the spacebar if (key == VK_SPACE) { m_raster = !m_raster; }
}
WindowProc()
The following is not required, but it adds the convenience to quit the application by pressing the ESC key. In the Win32Application.cpp file, in WindowProc, add the following code to the WM_KEYDOWN case to quit the application.

if (static_cast<uint8>(wParam) == VK_ESCAPE) PostQuitMessage(0);
Result
If everything went well, you should be able to compile, run and when pressing the spacebar, toggle between raster and raytracing mode. We are not doing any raytracing yet, but this will be our starting point.
