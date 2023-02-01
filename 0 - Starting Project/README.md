# DirectX-RTX-Tutorials 0
This is the starting point of this [Tutorial](https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-1)
### Credit for the original work goes to Martin-Karl Lefrançois and Pascal Gautron. 
### I am only filling in the gaps in explaination and fixing broken code
### This goes up to step 6.7 

## Fixed:
* logic_error by adding #include < stdexcept >
* wstring by adding #include < xstring >

## 1. NVIDIA DXR Sample
Welcome to Part 1 of the DirectX 12 DXR ray tracing tutorial. The focus of these documents and the provided code is to showcase a basic integration of raytracing within an existing DirectX 12 sample, using the new DXR API. Note that for educational purposes all the code is contained in a very small set of files. A real integration would require additional levels of abstraction.

## 2. Introduction
The recent integration of ray tracing into the DirectX 12 API, called DXR, has spawned a great deal of excitement among game developers. This post, along with the provided code showcases a basic tutorial on integrating ray tracing within an existing DirectX 12 sample using the new DXR API. You’ll learn how to add ray tracing to an existing application so that the ray tracing and raster paths share the same geometry buffers. This part one of a two-part tutorial, which deals with the initial setup of Windows 10 and DX12 for ray tracing. These two posts showcase basic intergration of ray tracing within an existing DirectX sample. 

## 2.1 Goal of the Tutorial
The goal of this tutorial is to add raytracing to an existing program, so that the raytracing and raster paths share the same geometry buffers. Step-by-step, we will go through the major building blocks required to do raytracing. You will also be invited to add code snippets that will enable the ray-tracer step-by-step. The following building blocks are required to add raytracing functionalities:

* Detecting and enabling raytracing features
* Creating the bottom- and top-level acceleration structures (BLAS and TLAS) providing high-performance ray-geometry intersection capabilities
* Creating and adding shaders: Ray Generation, Hit and Miss describing how to create new rays, and what to do upon an intersection or miss
* Creating a raytracing pipeline with the various programs: Ray Generation, Hit and Miss. This is used to pack together all the shaders used in the raytracing process
* Creating a shading binding table (SBT) associating the geometry with the corresponding shaders
In the Extras we will extend the minimal program by adding some more elements: See the Going Further section. We will add the ability to switch between raster and raytracing, by pressing the SPACEBAR. At any time you can go to the References section, providing external links to more resources around DXR.

## 3. Windows Version
Before going further: make sure you are running Windows 10 Version 1809 or later.

## 4. Starting point: Hello Triangle
There are many samples for DirectX 12 under Microsoft GitHub, but for this example, you only need HelloTriangle.

### HelloTriangle [Download](https://developer.nvidia.com/rtx/raytracing/dxr/tutorial/Files/HelloTriangle.zip) the HelloTriangle Zip
Make sure that you have the latest Windows SDK installed

Open the solution, build and run.

![Figure 1: The result of the HelloTriangle from Microsoft](1.PNG)
The result of the HelloTriangle from Microsoft

### Errors on compilation If you have a compilation issue, check that you have the latest Windows SDK installed. Right-Click the solution and select “Retarget solution” to the latest SDK.

## 5. DXR Utilities
In the following tutorial, we will use some utility functions that are abstracting some really verbose implementation. The implementation of those abstractions, available here, is fully documented and should help clarifying the concepts of DXR.

### DXR Helpers [Download](https://developer.nvidia.com/rtx/raytracing/dxr/tutorial/Files/DXRHelpers.zip) the utility classes and copy to the project directory.

1. Add the utility files to the solution
2. Select all .cpp and set the precompile flag to Not Using Precompiled Headers 
[!Project Properties](2.PNG)
3. Add $(ProjectDir) to the project include C/C++> General> Additional Include Directories

### After each step, you should be able to run the sample. At this point, nothing visual has changed.
