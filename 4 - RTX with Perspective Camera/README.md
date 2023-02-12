DXR Tutorial Extra : Perspective Camera
Welcome to the next section of the tutorial. If you miss the first tutorial, it is here The bases of this tutorial starts at the end of the previous one. You can download the entire project here At the end of the first tutorial, a triangle is visible using an orthographic camera:  In this tutorial we will extend this to a more natural perspective camera. To do this, the camera matrices need to be passed to the shaders through a the constant buffer m_cameraBuffer. For use in the rasterization pipeline we will also create the heap m_constHeap in which the camera buffer will be referenced. Add the following declarations in the header file:

// #DXR Extra: Perspective Camera
void CreateCameraBuffer();
void UpdateCameraBuffer();
ComPtr< ID3D12Resource > m_cameraBuffer;
ComPtr< ID3D12DescriptorHeap > m_constHeap;
uint32_t m_cameraBufferSize = 0;
At the end of the source file, add the implementation of the creation of the camera buffer. This method is creating a buffer to contain all matrices. We then create a heap referencing the camera buffer, that will be used in the rasterization path.

//----------------------------------------------------------------------------------
//
// The camera buffer is a constant buffer that stores the transform matrices of
// the camera, for use by both the rasterization and raytracing. This method
// allocates the buffer where the matrices will be copied. For the sake of code
// clarity, it also creates a heap containing only this buffer, to use in the
// rasterization path.
//
// #DXR Extra: Perspective Camera
void D3D12HelloTriangle::CreateCameraBuffer() { uint32_t nbMatrix = 4; // view, perspective, viewInv, perspectiveInv m_cameraBufferSize = nbMatrix * sizeof(XMMATRIX); // Create the constant buffer for all matrices m_cameraBuffer = nv_helpers_dx12::CreateBuffer( m_device.Get(), m_cameraBufferSize, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ, nv_helpers_dx12::kUploadHeapProps); // Create a descriptor heap that will be used by the rasterization shaders m_constHeap = nv_helpers_dx12::CreateDescriptorHeap( m_device.Get(), 1, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, true); // Describe and create the constant buffer view. D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = {}; cbvDesc.BufferLocation = m_cameraBuffer->GetGPUVirtualAddress(); cbvDesc.SizeInBytes = m_cameraBufferSize; // Get a handle to the heap memory on the CPU side, to be able to write the // descriptors directly D3D12_CPU_DESCRIPTOR_HANDLE srvHandle = m_constHeap->GetCPUDescriptorHandleForHeapStart(); m_device->CreateConstantBufferView(&cbvDesc, srvHandle);
}
UpdateCameraBuffer
Add the following function which creates and copies the viewmodel and perspective matrices of the camera.

// #DXR Extra: Perspective Camera
//--------------------------------------------------------------------------------
// Create and copies the viewmodel and perspective matrices of the camera
//
void D3D12HelloTriangle::UpdateCameraBuffer() { std::vector<xmmatrix> matrices(4); // Initialize the view matrix, ideally this should be based on user // interactions The lookat and perspective matrices used for rasterization are // defined to transform world-space vertices into a [0,1]x[0,1]x[0,1] camera // space XMVECTOR Eye = XMVectorSet(1.5f, 1.5f, 1.5f, 0.0f); XMVECTOR At = XMVectorSet(0.0f, 0.0f, 0.0f, 0.0f); XMVECTOR Up = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f); matrices[0] = XMMatrixLookAtRH(Eye, At, Up); float fovAngleY = 45.0f * XM_PI / 180.0f; matrices[1] = XMMatrixPerspectiveFovRH(fovAngleY, m_aspectRatio, 0.1f, 1000.0f); // Raytracing has to do the contrary of rasterization: rays are defined in // camera space, and are transformed into world space. To do this, we need to // store the inverse matrices as well. XMVECTOR det; matrices[2] = XMMatrixInverse(&det, matrices[0]); matrices[3] = XMMatrixInverse(&det, matrices[1]); // Copy the matrix contents uint8_t *pData; ThrowIfFailed(m_cameraBuffer->Map(0, nullptr, (void **)&pData)); memcpy(pData, matrices.data(), m_cameraBufferSize); m_cameraBuffer->Unmap(0, nullptr);
}
CreateShaderResourceHeap
The camera buffer needs to be accessed by the raytracing path as well. To this end, we modify CreateShaderResourceHeap and add a reference to the camera buffer in the heap used by the raytracing. The heap then needs to be made bigger, to contain the additional reference

// #DXR Extra: Perspective Camera
// Create a SRV/UAV/CBV descriptor heap. We need 3 entries - 1 SRV for the TLAS, 1 UAV for the
// raytracing output and 1 CBV for the camera matrices
m_srvUavHeap = nv_helpers_dx12::CreateDescriptorHeap( m_device.Get(), 3, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, true);
At the end of the method, we add the actual camera buffer reference:

// #DXR Extra: Perspective Camera
// Add the constant buffer for the camera after the TLAS
srvHandle.ptr += m_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
// Describe and create a constant buffer view for the camera
D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = {};
cbvDesc.BufferLocation = m_cameraBuffer->GetGPUVirtualAddress();
cbvDesc.SizeInBytes = m_cameraBufferSize;
m_device->CreateConstantBufferView(&cbvDesc, srvHandle);
CreateRayGenSignature
Since we have changed our heap and want to access the new matrices, the Root Signature of the RayGen shader must be changed. Add the extra entry to access the constant buffer through the b0 register.

rsc.AddHeapRangesParameter( {{0 /*u0*/, 1 /*1 descriptor */, 0 /*use the implicit register space 0*/, D3D12_DESCRIPTOR_RANGE_TYPE_UAV /* UAV representing the output buffer*/, 0 /*heap slot where the UAV is defined*/}, {0 /*t0*/, 1, 0, D3D12_DESCRIPTOR_RANGE_TYPE_SRV /*Top-level acceleration structure*/, 1}, {0 /*b0*/, 1, 0, D3D12_DESCRIPTOR_RANGE_TYPE_CBV /*Camera parameters*/, 2}});
LoadAssets
The buffer starts with 2 matrices:

The view matrix, representing the location of the camera
The projection matrix, a simple representation of the behavior of the camera lens
Those matrices are the classical ones used in the rasterization process, projecting the world-space positions of the vertices into a unit cube. However, to obtain a raytracing result consistent with the rasterization, we need to do the opposite: the rays are initialized as if we had an orthographic camera located at the origin. We then need to transform the ray origin and direction into world space, using the inverse view and projection matrices. The camera buffer stores all 4 matrices, where the raster and raytracing paths will access only the ones needed. We now need to indicate that the rasterization shaders will use the camera buffer, by modifying their root signature at the beginning of LoadAssets. The shader now takes one constant buffer (CBV) parameter, accessible from the currently bound heap:

// #DXR Extra: Perspective Camera
// The root signature describes which data is accessed by the shader. The camera matrices are held
// in a constant buffer, itself referenced the heap. To do this we reference a range in the heap,
// and use that range as the sole parameter of the shader. The camera buffer is associated in the
// index 0, making it accessible in the shader in the b0 register.
CD3DX12_ROOT_PARAMETER constantParameter;
CD3DX12_DESCRIPTOR_RANGE range;
range.Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);
constantParameter.InitAsDescriptorTable(1, &range, D3D12_SHADER_VISIBILITY_ALL);
CD3DX12_ROOT_SIGNATURE_DESC rootSignatureDesc;
rootSignatureDesc.Init(1, &constantParameter, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);
PopulateCommandList
Until now the rasterization path did not require access to any resources, hence we did not bind any heap for use by the shaders. Add the following lines at the beginning of the rasterization path:

if (m_raster)
{ // #DXR Extra: Perspective Camera std::vector< ID3D12DescriptorHeap* > heaps = { m_constHeap.Get() }; m_commandList->SetDescriptorHeaps(static_cast<uint>(heaps.size()), heaps.data()); // set the root descriptor table 0 to the constant buffer descriptor heap m_commandList->SetGraphicsRootDescriptorTable( 0, m_constHeap->GetGPUDescriptorHandleForHeapStart());
OnInit
In the initialization of the application, we need to call the creation of the buffer. Add the following just after CreateRaytracingOutputBuffer().

// #DXR Extra: Perspective Camera
// Create a buffer to store the modelview and perspective camera matrices
CreateCameraBuffer();
OnUpdate
It is not needed to update the camera matrix at each frame since it is not modified, but this is something that it is usually done. See the Camera Manipulator Section where we are adding the ability to move the the camera interactively.

// Update frame-based values.
void D3D12HelloTriangle::OnUpdate()
{ // #DXR Extra: Perspective Camera UpdateCameraBuffer();
}
shaders.hlsl
The last step to use the camera buffer for rasterization is to use the newly created buffer inside the shader. Since the buffer is associated to the register b0, we add the declaration at the beginning of the file. Note that since only the view and projection matrices are required, and they are at the beginning of the buffer, we only declare those in the shader:

// #DXR Extra: Perspective Camera
cbuffer CameraParams : register(b0)
{ float4x4 view; float4x4 projection;
}
We need to modify the vertex shader to use the matrices:

PSInput VSMain(float4 position : POSITION, float4 color : COLOR)
{ PSInput result; // #DXR Extra: Perspective Camera float4 pos = position; pos = mul(view, pos); pos = mul(projection, pos); result.position = pos; result.color = color; return result;
}
The program should now run, showing this image in the rasterization mode: 

RayGen.hlsl
The raytracing mode requires changes in the ray generation shader. For this we first add the declaration of the camera buffer. Here, we use all the available matrices:

// #DXR Extra: Perspective Camera
cbuffer CameraParams : register(b0)
{ float4x4 view; float4x4 projection; float4x4 viewI; float4x4 projectionI;
}
The ray generation then uses the inverse matrices to generate a ray: using a ray starting on a [0,1]x[0,1] square on the XY plane, and with a direction along the Z axis, we apply the inverse transforms to generate a perspective projection at the actual camera location. For this, we replace the origin and direction in the RayDesc initialization:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
And voila! The perspective camera is also available in raytracing mode:
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/perspectiveRaytracing.png)
# Camera Manipulator
It is also possible to easily add an interactive camera.
For this, you will need a utility class `manipulator` which you can find under this [ZIP](Manipulator.zip) file.
Copy the GLM folder and manipulator.[h|cpp] to the tutorial and add the manipulator to the project.
![Figure [Fig]: The default camera manipulator](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/)
## DXSample
In the file `DXSample.h`, add the following virtual functions
virtual void OnButtonDown(UINT32) {} virtual void OnMouseMove(UINT8, UINT32) {}

## WindowProc
In the `WindowProc` of `Win32Application.cpp`, capture the mouse button and movement and transfer it to the application
case WM_LBUTTONDOWN: case WM_RBUTTONDOWN: case WM_MBUTTONDOWN: if (pSample) { pSample->OnButtonDown(static_cast(lParam)); } return 0; case WM_MOUSEMOVE: if (pSample) { pSample->OnMouseMove(static_cast(wParam), static_cast(lParam)); } return 0;

## D3D12HelloTriangle
Add the declaration of the overloaded functions to the class.
// #DXR Extra: Perspective Camera++ void OnButtonDown(UINT32 lParam); void OnMouseMove(UINT8 wParam, UINT32 lParam);

In the source file of D3D12HelloTriangle, add the following headers
#include “glm/gtc/type_ptr.hpp” #include “manipulator.h” #include “Windowsx.h”

## OnInit
The camera manipulator need to be initialized with the size of the window and a startup position.
Add the following at the beginning of the `OnInit`
nv_helpers_dx12::CameraManip.setWindowSize(GetWidth(), GetHeight()); nv_helpers_dx12::CameraManip.setLookat(glm::vec3(1.5f, 1.5f, 1.5f), glm::vec3(0, 0, 0), glm::vec3(0, 1, 0));

## OnButtonDown && OnMouseMove
Create the implementation for the mouse interaction
//-------------------------------------------------------------------------------------------------- // // void D3D12HelloTriangle::OnButtonDown(UINT32 lParam) { nv_helpers_dx12::CameraManip.setMousePosition(-GET_X_LPARAM(lParam), -GET_Y_LPARAM(lParam)); } //-------------------------------------------------------------------------------------------------- // // void D3D12HelloTriangle::OnMouseMove(UINT8 wParam, UINT32 lParam) { using nv_helpers_dx12::Manipulator; Manipulator::Inputs inputs; inputs.lmb = wParam & MK_LBUTTON; inputs.mmb = wParam & MK_MBUTTON; inputs.rmb = wParam & MK_RBUTTON; if (!inputs.lmb && !inputs.rmb && !inputs.mmb) return; // no mouse button pressed inputs.ctrl = GetAsyncKeyState(VK_CONTROL); inputs.shift = GetAsyncKeyState(VK_SHIFT); inputs.alt = GetAsyncKeyState(VK_MENU); CameraManip.mouseMove(-GET_X_LPARAM(lParam), -GET_Y_LPARAM(lParam), inputs); }

## UpdateCameraBuffer
Finally, we need to extract the camera matrix from the manipulator and update the
buffer of matrices.
Replace the code that is setting `matrices[0]`, by:
const glm::mat4& mat = nv_helpers_dx12::CameraManip.getMatrix(); memcpy(&matrices[0].r->m128_f32[0], glm::value_ptr(mat), 16 * sizeof(float)); ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
