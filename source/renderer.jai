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

    vertex_shader : *ID3D11VertexShader;
    pixel\_shader : *ID3D11PixelShader;
    vertex_layout : *ID3D11InputLayout;
    vertex_buffer : *ID3D11Buffer;
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

    HR(IDXGIFactory_MakeWindowAssociation(dxgi_factory, hwnd, cast(u32) DXGI_MWA.NO_ALT_ENTER | DXGI_MWA.NO_WINDOW_CHANGES));

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
    ID3D11DeviceContext_RSSetViewports(d3d_deferred_context, 1, *vp);
    ID3D11DeviceContext_OMSetRenderTargets(d3d_deferred_context, 1, *render_target_view, null);

    return true;
}

renderer_on_fini :: (using rdsys : *Graphics_Device) {
    if d3d_context ID3D11DeviceContext_ClearState(d3d_context);

    if render_target_view   IUnknown_Release(render_target_view);
    if swapchain            IUnknown_Release(swapchain);
    if d3d_context          IUnknown_Release(d3d_context);
    if d3d_device           IUnknown_Release(d3d_device);
}

renderer_clear        :: (using rdsys : *Graphics_Device) {
    color: [4]float = .[1.0, 0.0, 1.0, 1.0];
    ID3D11DeviceContext_ClearRenderTargetView(d3d_deferred_context, render_target_view, *color);
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

#import "dxgi";
#import "d3d11"()(INCLUDE_DEBUG_BINDINGS = true);
#import "d3d_compiler";