//
// This file was auto-generated using the following command:
//
// jai ./generate.jai - -backend_d3d11 - -debug
//



// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplDX11_Init :: (device: *ID3D11Device, device_context: *ID3D11DeviceContext) -> bool #foreign imgui_d3d11 "?ImGui_ImplDX11_Init@@YA_NPEAUID3D11Device@@PEAUID3D11DeviceContext@@@Z";
ImplDX11_Shutdown :: () -> void #foreign imgui_d3d11 "?ImGui_ImplDX11_Shutdown@@YAXXZ";
ImplDX11_NewFrame :: () -> void #foreign imgui_d3d11 "?ImGui_ImplDX11_NewFrame@@YAXXZ";
ImplDX11_RenderDrawData :: (draw_data: *ImDrawData) -> void #foreign imgui_d3d11 "?ImGui_ImplDX11_RenderDrawData@@YAXPEAUImDrawData@@@Z";

// Use if you want to reset your rendering device without losing Dear ImGui state.
ImplDX11_CreateDeviceObjects :: () -> bool #foreign imgui_d3d11 "?ImGui_ImplDX11_CreateDeviceObjects@@YA_NXZ";
ImplDX11_InvalidateDeviceObjects :: () -> void #foreign imgui_d3d11 "?ImGui_ImplDX11_InvalidateDeviceObjects@@YAXXZ";

// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = NULL to handle this manually.
ImplDX11_UpdateTexture :: (tex: *ImTextureData) -> void #foreign imgui_d3d11 "?ImGui_ImplDX11_UpdateTexture@@YAXPEAUImTextureData@@@Z";

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplDX11_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
ImplDX11_RenderState :: struct {
    Device:               *ID3D11Device;
    DeviceContext:        *ID3D11DeviceContext;
    SamplerDefault:       *ID3D11SamplerState;
    VertexConstantBuffer: *ID3D11Buffer;
}

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplWin32_Init :: (hwnd: *void) -> bool #foreign imgui_d3d11 "?ImGui_ImplWin32_Init@@YA_NPEAX@Z";
ImplWin32_InitForOpenGL :: (hwnd: *void) -> bool #foreign imgui_d3d11 "?ImGui_ImplWin32_InitForOpenGL@@YA_NPEAX@Z";
ImplWin32_Shutdown :: () -> void #foreign imgui_d3d11 "?ImGui_ImplWin32_Shutdown@@YAXXZ";
ImplWin32_NewFrame :: () -> void #foreign imgui_d3d11 "?ImGui_ImplWin32_NewFrame@@YAXXZ";

// DPI-related helpers (optional)
// - Use to enable DPI awareness without having to create an application manifest.
// - Your own app may already do this via a manifest or explicit calls. This is mostly useful for our examples/ apps.
// - In theory we could call simple functions from Windows SDK such as SetProcessDPIAware(), SetProcessDpiAwareness(), etc.
//   but most of the functions provided by Microsoft require Windows 8.1/10+ SDK at compile time and Windows 8/10+ at runtime,
//   neither we want to require the user to have. So we dynamically select and load those functions to avoid dependencies.
ImplWin32_EnableDpiAwareness :: () -> void #foreign imgui_d3d11 "?ImGui_ImplWin32_EnableDpiAwareness@@YAXXZ";
ImplWin32_GetDpiScaleForHwnd :: (hwnd: *void) -> float #foreign imgui_d3d11 "?ImGui_ImplWin32_GetDpiScaleForHwnd@@YAMPEAX@Z";
ImplWin32_GetDpiScaleForMonitor :: (monitor: *void) -> float #foreign imgui_d3d11 "?ImGui_ImplWin32_GetDpiScaleForMonitor@@YAMPEAX@Z";

// Transparency related helpers (optional) [experimental]
// - Use to enable alpha compositing transparency with the desktop.
// - Use together with e.g. clearing your framebuffer with zero-alpha.
ImplWin32_EnableAlphaCompositing :: (hwnd: *void) -> void #foreign imgui_d3d11 "?ImGui_ImplWin32_EnableAlphaCompositing@@YAXPEAX@Z";

#scope_file

imgui_d3d11 :: #library,no_dll "ImGui_d3d11.static";
