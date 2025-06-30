Graphics_Device :: struct {
    // d3d11 stuff
    feature_level   := D3D_FEATURE_LEVEL._11_1;

    d3d_device              : *ID3D11Device;
    d3d_context             : *ID3D11DeviceContext;
    d3d_deferred_context    : *ID3D11DeviceContext;
    swapchain               : *IDXGISwapChain;
    depth_stencil_buffer    : *ID3D11Texture2D;
    render_target_view      : *ID3D11RenderTargetView;
    depth_stencil_view      : *ID3D11DepthStencilView;

    viewport                : D3D11_VIEWPORT;

}

graphics_device_init :: (using rdsys : *Graphics_Device, hwnd : Window_Type, enable_4x_msaa : bool, quality_4x_msaa : *u32) -> bool {
    hr : HRESULT = S_OK;

    create_device_flags : D3D11_CREATE_DEVICE_FLAG;
    #if DEBUG create_device_flags |= .DEBUG;
    
    create_device_types := D3D_DRIVER_TYPE.[.HARDWARE, .WARP, .REFERENCE];
    create_device_feature_levels := D3D_FEATURE_LEVEL.[._11_1, ._11_0, ._10_1, ._10_0];

    for 0..create_device_types.count - 1 {
        device_type := create_device_types[it];
        HR(D3D11CreateDevice(null, device_type, null, create_device_flags, create_device_feature_levels.data, create_device_feature_levels.count, D3D11_SDK_VERSION, *d3d_device, *feature_level, *d3d_context));

        if hr == E_INVALIDARG {
            HR(D3D11CreateDevice(null, device_type, null, create_device_flags, create_device_feature_levels.data + 1, create_device_feature_levels.count - 1, D3D11_SDK_VERSION, *d3d_device, *feature_level, *d3d_context));
        }

        if SUCCEEDED(hr) break;
    }

    if FAILED(hr) {
        MessageBoxA(null, "D3D11CreateDevice failed!", "Untitled", MB_ICONERROR);
        return false;
    }

    if feature_level != ._11_0 && feature_level != ._11_1 {
        MessageBoxA(null, "D3D11 feature level 11 unsupported!", "Untitled", MB_ICONERROR);
        return false;
    }

    ID3D11Device_CheckMultisampleQualityLevels(d3d_device, .R8G8B8A8_UNORM, 4, xx quality_4x_msaa);
    assert(quality_4x_msaa.* > 0);

    HR(ID3D11Device_CreateDeferredContext(d3d_device, 0, *d3d_deferred_context));

    dxgi_factory : *IDXGIFactory1;
    dxgi_device  : *IDXGIDevice;
    HR(IUnknown_QueryInterface(d3d_device, *uid(IDXGIDevice_UUID), xx *dxgi_device));

    adapter : *IDXGIAdapter;
    HR(IDXGIDevice_GetAdapter(dxgi_device, *adapter));
    HR(IDXGIObject_GetParent(adapter, *uid(IDXGIFactory1_UUID), xx *dxgi_factory));

    IUnknown_Release(dxgi_device);

    dxgi_factory2 : *IDXGIFactory2;
    HR(IUnknown_QueryInterface(dxgi_factory, *uid(IDXGIFactory2_UUID), xx *dxgi_factory2));

    IUnknown_QueryInterface(d3d_context, *uid(ID3D11DeviceContext_UUID), xx *d3d_context);

    rc : RECT;
    GetClientRect(hwnd, *rc);

    width  := rc.right - rc.left;
    height := rc.bottom - rc.top;

    if dxgi_factory2 != null {
        sd : DXGI_SWAP_CHAIN_DESC1;
        sd.Width    = xx width;
        sd.Height   = xx height;
        sd.Format = DXGI_FORMAT.R8G8B8A8_UNORM;
        if enable_4x_msaa {
            sd.SampleDesc.Count     = 4;
            sd.SampleDesc.Quality   = quality_4x_msaa.* - 1;
        } else {
            sd.SampleDesc.Count     = 1;
            sd.SampleDesc.Quality   = 0;
        }
        sd.BufferUsage = .RENDER_TARGET_OUTPUT;
        sd.SwapEffect  = .DISCARD;
        sd.BufferCount = 1;

        fd : DXGI_SWAP_CHAIN_FULLSCREEN_DESC;
        fd.RefreshRate.Numerator = 60;
        fd.RefreshRate.Denominator = 1;
        fd.Scaling = .UNSPECIFIED;
        fd.ScanlineOrdering = .UNSPECIFIED;       
        fd.Windowed = 1;

        swapchain1 : *IDXGISwapChain1;
        HR(IDXGIFactory2_CreateSwapChainForHwnd(dxgi_factory2, d3d_device, hwnd, *sd, *fd, null, *swapchain1));
        HR(IUnknown_QueryInterface(swapchain1, *uid(IDXGISwapChain_UUID), xx *swapchain));

        IUnknown_Release(dxgi_factory2);
    } else {
        sd : DXGI_SWAP_CHAIN_DESC;
        sd.BufferDesc.Width     = xx width;
        sd.BufferDesc.Height    = xx height;
        sd.BufferDesc.RefreshRate.Numerator = 60;
        sd.BufferDesc.RefreshRate.Denominator = 1;
        sd.BufferDesc.Scaling = .UNSPECIFIED;
        sd.BufferDesc.ScanlineOrdering = .UNSPECIFIED;       
        sd.BufferDesc.Format = .R8G8B8A8_UNORM;
        if enable_4x_msaa {
            sd.SampleDesc.Count     = 4;
            sd.SampleDesc.Quality   = quality_4x_msaa.* - 1;
        } else {
            sd.SampleDesc.Count     = 1;
            sd.SampleDesc.Quality   = 0;
        }
        sd.BufferUsage = .RENDER_TARGET_OUTPUT;
        sd.SwapEffect  = .DISCARD;
        sd.BufferCount = 1;
        sd.Windowed = 1;
        sd.OutputWindow = hwnd;

        HR(IDXGIFactory_CreateSwapChain(dxgi_factory, d3d_device, *sd, *swapchain));
        IUnknown_Release(dxgi_factory);
    }

    HR(IDXGIFactory_MakeWindowAssociation(dxgi_factory, hwnd, cast(u32) DXGI_MWA.NO_ALT_ENTER | .NO_WINDOW_CHANGES));

    D3D11SetDebugObjectName(d3d_device, d3d_context, "ImmediateContext");
    D3D11SetDebugObjectName(d3d_device, d3d_deferred_context, "DeferredContext");
    D3D11SetDebugObjectName(d3d_device, swapchain, "Swapchain");

    renderer_resize(rdsys, width, height, enable_4x_msaa, quality_4x_msaa);

    vp : D3D11_VIEWPORT;
    vp.Width = xx width;
    vp.Height = xx height;
    vp.MinDepth = 0.0;
    vp.MaxDepth = 1.0;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;

    // ? should we use deferred context instead
    ID3D11DeviceContext_RSSetViewports(d3d_context, 1, *vp);
    ID3D11DeviceContext_OMSetRenderTargets(d3d_context, 1, *render_target_view, depth_stencil_view);

    return true;
}

renderer_on_fini :: (using rdsys : *Graphics_Device) {
    if d3d_context ID3D11DeviceContext_ClearState(d3d_context);

    if render_target_view   IUnknown_Release(render_target_view);
    if swapchain            IUnknown_Release(swapchain);
    if d3d_context          IUnknown_Release(d3d_context);
    if d3d_device           IUnknown_Release(d3d_device);
}

imgui_init :: (hwnd : Window_Type, using rdsys : *Graphics_Device) -> bool {

    IMGUI.CreateContext();
    io := IMGUI.GetIO();
    io.ConfigFlags_ |= .NavEnableKeyboard;
    io.ConfigFlags_ |= .DockingEnable;
    io.ConfigWindowsMoveFromTitleBarOnly = true;

    IMGUI.StyleColorsDark();

    ImplWin32_Init(hwnd);
    ImplDX11_Init(d3d_device, d3d_context);

    return true;
}


renderer_clear        :: (using rdsys : *Graphics_Device) {
    color: [4]float = .[0.0, 0.0, 0.0, 1.0];
    ID3D11DeviceContext_ClearRenderTargetView(d3d_context, render_target_view, *color);
    ID3D11DeviceContext_ClearDepthStencilView(d3d_context, depth_stencil_view, cast(u32) D3D11_CLEAR_FLAG.DEPTH | D3D11_CLEAR_FLAG.STENCIL, 1.0, 0);
}

renderer_exec_cmdlist :: (using rdsys : *Graphics_Device) {
    cmdlist : *ID3D11CommandList;
    HR(ID3D11DeviceContext_FinishCommandList(d3d_deferred_context, 0, xx *cmdlist));

    ID3D11DeviceContext_ExecuteCommandList(d3d_context, cmdlist, 0);
}

renderer_present :: (using rdsys : *Graphics_Device) {
    HR(IDXGISwapChain_Present(swapchain, 0, 0));
}

renderer_draw :: (using rdsys : *Graphics_Device) {
    renderer_clear(rdsys);
    renderer_exec_cmdlist(rdsys);
    renderer_present(rdsys);
}

renderer_resize :: (using rdsys : *Graphics_Device, width : int, height : int, enable_4x_msaa : bool, quality_4x_msaa : *u32) {
    back_buffer : *ID3D11Texture2D;
    HR(IDXGISwapChain_ResizeBuffers(swapchain, 1, xx width, xx height, .R8G8B8A8_UNORM, 0));
    HR(IDXGISwapChain_GetBuffer(swapchain, 0, *uid(ID3D11Texture2D_UUID), xx *back_buffer));
    HR(ID3D11Device_CreateRenderTargetView(d3d_device, back_buffer, null, *render_target_view));

    D3D11SetDebugObjectName(d3d_device, back_buffer, "BackBuffer[0]");
    IUnknown_Release(back_buffer);

    depth_stencil_desc : D3D11_TEXTURE2D_DESC;
    depth_stencil_desc.Width = xx width;
    depth_stencil_desc.Height = xx height;
    depth_stencil_desc.MipLevels = 1;
    depth_stencil_desc.ArraySize = 1;
    depth_stencil_desc.Format = .D24_UNORM_S8_UINT;
    if enable_4x_msaa {
        depth_stencil_desc.SampleDesc.Count     = 4;
        depth_stencil_desc.SampleDesc.Quality   = quality_4x_msaa.* - 1;
    } else {
        depth_stencil_desc.SampleDesc.Count     = 1;
        depth_stencil_desc.SampleDesc.Quality   = 0;
    }
    depth_stencil_desc.Usage = .DEFAULT;
    depth_stencil_desc.BindFlags = .DEPTH_STENCIL;
    depth_stencil_desc.CPUAccessFlags = 0;
    depth_stencil_desc.MiscFlags = 0;

    HR(ID3D11Device_CreateTexture2D(d3d_device, *depth_stencil_desc, null, *depth_stencil_buffer));
    HR(ID3D11Device_CreateDepthStencilView(d3d_device, depth_stencil_buffer, null, *depth_stencil_view));
}

gfx_set_projection2d :: (using gfx_device : *Graphics_Device, 
                         projection: *ID3D11Buffer, render_target_width: float, render_target_height: float) {
    data := CBuffer_Perframe.{
        projection2d=orthographic_projection_matrix(0, render_target_width*1, render_target_height, 0, -1.0, 1.0)
    };

    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, projection, 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *data, size_of(CBuffer_Perframe));
    ID3D11DeviceContext_Unmap(d3d_context, projection, 0);
}

gfx_set_shader :: (using gfx_device: *Graphics_Device, shader: *Shader) {
    ID3D11DeviceContext_VSSetShader(d3d_context, shader.vertex_shader, null, 0);
    ID3D11DeviceContext_PSSetShader(d3d_context, shader.pixel_shader, null, 0);
}

gfx_set_texture :: (using gfx_device: *Graphics_Device, shader: *Shader, texture: *Texture) {
    gfx_set_shader(gfx_device, shader);

    ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *texture.image_view);
    ID3D11DeviceContext_PSSetSamplers(d3d_context, 0, 1, *shader.sampler_state);
}

gfx_flush :: (using gfx_device: *Graphics_Device, dc: *DrawCommand) {
    stride : u32 = size_of(Immediate_Vertex);
    offset : u32 = 0; 
    ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, *dc.vertex_buffer, *stride, *offset);
    ID3D11DeviceContext_IASetIndexBuffer(d3d_context, dc.index_buffer, .R32_UINT, 0);

    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, dc.vertex_buffer, 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *dc.vertices, size_of(Immediate_Vertex) * dc.num_vertices);
    ID3D11DeviceContext_Unmap(d3d_context, dc.vertex_buffer, 0);

    mapped_data1 : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, dc.index_buffer, 0, .WRITE_DISCARD, 0, *mapped_data1));
    memcpy(mapped_data1.pData, *dc.indices, size_of(u32) * dc.num_indices);
    ID3D11DeviceContext_Unmap(d3d_context, dc.index_buffer, 0);

    ID3D11DeviceContext_DrawIndexed(d3d_context, xx dc.num_indices, 0, 0);
    dc.num_vertices = 0;
    dc.num_indices  = 0;
}

gfx_draw_quad :: (gfx_device: *Graphics_Device, dc: *DrawCommand,
                  x: float, y: float, width: float, height: float, tint:= Vector4.{1.0, 1.0, 1.0, 1.0}) {

    CheckVerticesSpace(4, dc);
    gfx_put_vertex(*v[0], .{x, y, 0.0},         tint, 0.0, 1.0);
    gfx_put_vertex(*v[1], .{x+width, y, 0.0},   tint, 1.0, 0.0);
    gfx_put_vertex(*v[2], .{x+width, y+height, 0.0}, tint, 1.0, 1.0);
    gfx_put_vertex(*v[3], .{x, y+height, 0.0},  tint, 0.0, 1.0);

    CheckIndicesSpace(6, dc);
    i[0] = cast(u32) dc.num_vertices + 0;
    i[1] = cast(u32) dc.num_vertices + 1;
    i[2] = cast(u32) dc.num_vertices + 2;

    i[3] = cast(u32) dc.num_vertices + 2;
    i[4] = cast(u32) dc.num_vertices + 3;
    i[5] = cast(u32) dc.num_vertices + 0;

    dc.num_vertices += 4;
    dc.num_indices  += 6;
}

gfx_draw_quad :: (gfx_device: *Graphics_Device, dc: *DrawCommand,
                  using source: Vector4, texture_handle : u32, tint:= Vector4.{1.0, 1.0, 1.0, 1.0}) {

    CheckVerticesSpace(4, dc);
    gfx_put_vertex(*v[0], .{x, y, 0.0},     tint, 0.0, 0.0, texture_handle);
    gfx_put_vertex(*v[1], .{x+z, y, 0.0},   tint, 1.0, 0.0, texture_handle);
    gfx_put_vertex(*v[2], .{x+z, y+w, 0.0}, tint, 1.0, 1.0, texture_handle);
    gfx_put_vertex(*v[3], .{x, y+w, 0.0},   tint, 0.0, 1.0, texture_handle);

    CheckIndicesSpace(6, dc);
    i[0] = cast(u32) dc.num_vertices + 0;
    i[1] = cast(u32) dc.num_vertices + 1;
    i[2] = cast(u32) dc.num_vertices + 2;

    i[3] = cast(u32) dc.num_vertices + 2;
    i[4] = cast(u32) dc.num_vertices + 3;
    i[5] = cast(u32) dc.num_vertices + 0;

    dc.num_vertices += 4;
    dc.num_indices  += 6;
}

#scope_file

gfx_immediate_vertex_pointer :: inline (dc: *DrawCommand) -> *Immediate_Vertex {
    return dc.vertices.data + dc.num_vertices;
}
gfx_index_pointer :: inline (dc: *DrawCommand) -> *u32 {
    return dc.indices.data + dc.num_indices;
}

gfx_put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector3, color: Vector4, u: float, v: float) {
    position     = p;
    color_scale  = color;
    normal       = .{z=1};
    uv0.x        = u;
    uv0.y        = v;
}

gfx_put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector3, color: Vector4, u: float, v: float, texture_handle: u32) {
    position     = p;
    color_scale  = color;
    normal       = .{z=1};
    uv0.x        = u;
    uv0.y        = v;
    texture_id   = cast(float) texture_handle;
}


CheckVerticesSpace :: (n: s32, dc: *DrawCommand) #expand {
    `v := gfx_immediate_vertex_pointer(dc);
}

CheckIndicesSpace :: (n: s32, dc: *DrawCommand) #expand {
    `i := gfx_index_pointer(dc);
}
