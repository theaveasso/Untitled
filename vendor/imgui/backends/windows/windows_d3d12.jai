//
// This file was auto-generated using the following command:
//
// jai ./generate.jai - -debug -backend_d3d12 -
//



// Initialization data, for ImGui_ImplDX12_Init()
ImplDX12_InitInfo :: struct {
    Device:                       *ID3D12Device;
    CommandQueue:                 *ID3D12CommandQueue; // Command queue used for queuing texture uploads.
    NumFramesInFlight:            s32;
    RTVFormat:                    DXGI_FORMAT; // RenderTarget format.
    DSVFormat:                    DXGI_FORMAT; // DepthStencilView format.
    UserData:                     *void;

    // Allocating SRV descriptors for textures is up to the application, so we provide callbacks.
    // (current version of the backend will only allocate one descriptor, from 1.92 the backend will need to allocate more)
    SrvDescriptorHeap:            *ID3D12DescriptorHeap;
    SrvDescriptorAllocFn:         #type (info: *ImplDX12_InitInfo, out_cpu_desc_handle: *D3D12_CPU_DESCRIPTOR_HANDLE, out_gpu_desc_handle: *D3D12_GPU_DESCRIPTOR_HANDLE) -> void #c_call;
    SrvDescriptorFreeFn:          #type (info: *ImplDX12_InitInfo, cpu_desc_handle: D3D12_CPU_DESCRIPTOR_HANDLE, gpu_desc_handle: D3D12_GPU_DESCRIPTOR_HANDLE) -> void #c_call;

    LegacySingleSrvCpuDescriptor: D3D12_CPU_DESCRIPTOR_HANDLE; // To facilitate transition from single descriptor to allocator callback, you may use those.
    LegacySingleSrvGpuDescriptor: D3D12_GPU_DESCRIPTOR_HANDLE;

    Constructor :: (this: *ImplDX12_InitInfo) -> void #cpp_method #foreign imgui_d3d12 "??0ImGui_ImplDX12_InitInfo@@QEAA@XZ";
}

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplDX12_Init :: (info: *ImplDX12_InitInfo) -> bool #foreign imgui_d3d12 "?ImGui_ImplDX12_Init@@YA_NPEAUImGui_ImplDX12_InitInfo@@@Z";
ImplDX12_Shutdown :: () -> void #foreign imgui_d3d12 "?ImGui_ImplDX12_Shutdown@@YAXXZ";
ImplDX12_NewFrame :: () -> void #foreign imgui_d3d12 "?ImGui_ImplDX12_NewFrame@@YAXXZ";
ImplDX12_RenderDrawData :: (draw_data: *ImDrawData, graphics_command_list: *ID3D12GraphicsCommandList) -> void #foreign imgui_d3d12 "?ImGui_ImplDX12_RenderDrawData@@YAXPEAUImDrawData@@PEAUID3D12GraphicsCommandList@@@Z";

// Legacy initialization API Obsoleted in 1.91.5
// - font_srv_cpu_desc_handle and font_srv_gpu_desc_handle are handles to a single SRV descriptor to use for the internal font texture, they must be in 'srv_descriptor_heap'
// - When we introduced the ImGui_ImplDX12_InitInfo struct we also added a 'ID3D12CommandQueue* CommandQueue' field.
ImplDX12_Init :: (device: *ID3D12Device, num_frames_in_flight: s32, rtv_format: DXGI_FORMAT, srv_descriptor_heap: *ID3D12DescriptorHeap, font_srv_cpu_desc_handle: D3D12_CPU_DESCRIPTOR_HANDLE, font_srv_gpu_desc_handle: D3D12_GPU_DESCRIPTOR_HANDLE) -> bool #foreign imgui_d3d12 "?ImGui_ImplDX12_Init@@YA_NPEAUID3D12Device@@HW4DXGI_FORMAT@@PEAUID3D12DescriptorHeap@@UD3D12_CPU_DESCRIPTOR_HANDLE@@UD3D12_GPU_DESCRIPTOR_HANDLE@@@Z";

// Use if you want to reset your rendering device without losing Dear ImGui state.
ImplDX12_CreateDeviceObjects :: () -> bool #foreign imgui_d3d12 "?ImGui_ImplDX12_CreateDeviceObjects@@YA_NXZ";
ImplDX12_InvalidateDeviceObjects :: () -> void #foreign imgui_d3d12 "?ImGui_ImplDX12_InvalidateDeviceObjects@@YAXXZ";

// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = NULL to handle this manually.
ImplDX12_UpdateTexture :: (tex: *ImTextureData) -> void #foreign imgui_d3d12 "?ImGui_ImplDX12_UpdateTexture@@YAXPEAUImTextureData@@@Z";

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplDX12_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
ImplDX12_RenderState :: struct {
    Device:      *ID3D12Device;
    CommandList: *ID3D12GraphicsCommandList;
}

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplWin32_Init :: (hwnd: *void) -> bool #foreign imgui_d3d12 "?ImGui_ImplWin32_Init@@YA_NPEAX@Z";
ImplWin32_InitForOpenGL :: (hwnd: *void) -> bool #foreign imgui_d3d12 "?ImGui_ImplWin32_InitForOpenGL@@YA_NPEAX@Z";
ImplWin32_Shutdown :: () -> void #foreign imgui_d3d12 "?ImGui_ImplWin32_Shutdown@@YAXXZ";
ImplWin32_NewFrame :: () -> void #foreign imgui_d3d12 "?ImGui_ImplWin32_NewFrame@@YAXXZ";

// DPI-related helpers (optional)
// - Use to enable DPI awareness without having to create an application manifest.
// - Your own app may already do this via a manifest or explicit calls. This is mostly useful for our examples/ apps.
// - In theory we could call simple functions from Windows SDK such as SetProcessDPIAware(), SetProcessDpiAwareness(), etc.
//   but most of the functions provided by Microsoft require Windows 8.1/10+ SDK at compile time and Windows 8/10+ at runtime,
//   neither we want to require the user to have. So we dynamically select and load those functions to avoid dependencies.
ImplWin32_EnableDpiAwareness :: () -> void #foreign imgui_d3d12 "?ImGui_ImplWin32_EnableDpiAwareness@@YAXXZ";
ImplWin32_GetDpiScaleForHwnd :: (hwnd: *void) -> float #foreign imgui_d3d12 "?ImGui_ImplWin32_GetDpiScaleForHwnd@@YAMPEAX@Z";
ImplWin32_GetDpiScaleForMonitor :: (monitor: *void) -> float #foreign imgui_d3d12 "?ImGui_ImplWin32_GetDpiScaleForMonitor@@YAMPEAX@Z";

// Transparency related helpers (optional) [experimental]
// - Use to enable alpha compositing transparency with the desktop.
// - Use together with e.g. clearing your framebuffer with zero-alpha.
ImplWin32_EnableAlphaCompositing :: (hwnd: *void) -> void #foreign imgui_d3d12 "?ImGui_ImplWin32_EnableAlphaCompositing@@YAXPEAX@Z";

#scope_file

imgui_d3d12 :: #library,no_dll "ImGui_d3d12.static";
