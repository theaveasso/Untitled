Handles :: struct {
    gpu:    D3D12_GPU_DESCRIPTOR_HANDLE;
    cpu:  D3D12_CPU_DESCRIPTOR_HANDLE;
}

UTD_D3D12_SHADER_BYTECODE :: inline (shader: *ID3DBlob) -> D3D12_SHADER_BYTECODE {

    d: D3D12_SHADER_BYTECODE;
    d.BytecodeLength    = ID3D10Blob_GetBufferSize(shader);
    d.pShaderBytecode   = ID3D10Blob_GetBufferPointer(shader);
    return d;
}

D3D12_RASTERIZER_DESC_INIT :: inline () -> D3D12_RASTERIZER_DESC {

    d: D3D12_RASTERIZER_DESC;
    d.FillMode              = .SOLID;
    d.CullMode              = .BACK;
    d.FrontCounterClockwise = .FALSE;
    d.DepthBias             = D3D12_DEFAULT_DEPTH_BIAS;
    d.DepthBiasClamp        = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    d.SlopeScaledDepthBias  = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    d.DepthClipEnable       = .FALSE;
    d.MultisampleEnable     = .FALSE;
    d.AntialiasedLineEnable = .FALSE;
    return d;
}

D3D12_BLEND_DESC_INIT :: inline () -> D3D12_BLEND_DESC {

    d: D3D12_BLEND_DESC;
    d.AlphaToCoverageEnable = .FALSE;
    d.IndependentBlendEnable= .FALSE;
    for i : 0..7 {
        d.RenderTarget[i].LogicOpEnable = .FALSE;
        d.RenderTarget[i].LogicOp       = .CLEAR;
        d.RenderTarget[i].BlendEnable   = .FALSE;
        d.RenderTarget[i].SrcBlend      = .ONE;
        d.RenderTarget[i].DestBlend     = .ZERO;
        d.RenderTarget[i].BlendOp       = .ADD;
        d.RenderTarget[i].SrcBlendAlpha = .ONE;
        d.RenderTarget[i].DestBlendAlpha= .ZERO;
        d.RenderTarget[i].BlendOpAlpha  = .ADD;
        d.RenderTarget[i].RenderTargetWriteMask = cast(u8) D3D12_COLOR_WRITE_ENABLE.ALL;
    }
    return d;
}

D3D12_DEPTH_STENCIL_DESC_INIT :: inline () -> D3D12_DEPTH_STENCIL_DESC {

    d: D3D12_DEPTH_STENCIL_DESC;
    d.DepthEnable    = .FALSE;
    d.StencilEnable  = .FALSE;
    return d;
}

D3D12_RENDER_TARGET_FORMAT_INIT :: inline () -> D3D12Render_Taget_Format {

    d: D3D12Render_Taget_Format;
    d.depth_enable  = false;
    d.num_of_rts    = 1;
    d.rt_clearvalue[0] = .{color=.[0.0, 0.0, 0.0, 1.0]};
    d.rt_flags      = .ALLOW_RENDER_TARGET;
    d.rt_formats[0] = .R8G8B8A8_UNORM_SRGB;
    return d;
}

D3D12_DESCRIPTOR_RANGE1_INIT :: inline (type: D3D12_DESCRIPTOR_RANGE_TYPE, counts: u32, base_shader_register: u32, register_space: u32 = 0, offset_in_descriptors_from_table_start := D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND) -> D3D12_DESCRIPTOR_RANGE1 {

    d: D3D12_DESCRIPTOR_RANGE1;
    d.RangeType             = type;
    d.NumDescriptors        = counts;
    d.BaseShaderRegister    = base_shader_register;
    d.RegisterSpace         = register_space;
    d.OffsetInDescriptorsFromTableStart = xx offset_in_descriptors_from_table_start;
    return d;
}

D3D12_ROOT_DESCRIPTOR1_INIT :: inline (shader_register: u32, register_space: u32, flags: D3D12_ROOT_DESCRIPTOR_FLAGS) -> D3D12_ROOT_DESCRIPTOR1 {

    d: D3D12_ROOT_DESCRIPTOR1;
    d.ShaderRegister = shader_register;
    d.RegisterSpace  = register_space;
    d.Flags          = flags; 
    return d;
}

D3D12_ROOT_PARAMETER1_INIT_TABLE :: inline (num_descriptor_range: u32, range: *D3D12_DESCRIPTOR_RANGE1, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    d: D3D12_ROOT_PARAMETER1;
    d.ParameterType                         = .DESCRIPTOR_TABLE;
    d.DescriptorTable.NumDescriptorRanges   = num_descriptor_range;
    d.DescriptorTable.pDescriptorRanges     = range;
    d.ShaderVisibility                      = visibility;
    return d;
}

D3D12_ROOT_PARAMETER1_INIT_UAV :: inline (shader_register: u32, register_space: u32 = 0, descriptor_flags: D3D12_ROOT_DESCRIPTOR_FLAGS, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    d: D3D12_ROOT_PARAMETER1;
    d.ParameterType     = .UAV;
    d.Descriptor        = D3D12_ROOT_DESCRIPTOR1_INIT(shader_register, register_space, descriptor_flags);
    d.ShaderVisibility  = visibility;
    return d;
}

D3D12_SAMPLER_INIT :: (filter: D3D12_FILTER = .MIN_MAG_MIP_LINEAR, u: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, v: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, w: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, border_color:= Default_Border_Color, miplodbias : float = 0, maxanisotropy:=D3D12_DEFAULT_MAX_ANISOTROPY, minlod: float = 0, maxlod:= D3D12_FLOAT32_MAX, comparison_func : D3D12_COMPARISON_FUNC = .NEVER)-> D3D12Sampler {

    d: D3D12Sampler;
    d.desc.Filter   = filter;
    d.desc.AddressU = u;
    d.desc.AddressV = v;
    d.desc.AddressW = w;
    d.desc.MipLODBias       = miplodbias;
    d.desc.MaxAnisotropy    = xx maxanisotropy;
    d.desc.ComparisonFunc   = comparison_func;
    d.desc.BorderColor      = border_color;
    d.desc.MinLOD           = minlod;
    d.desc.MaxLOD           = xx maxlod;
    return d;
}


d3d12_cpu_desciptor_handle_offset :: inline (this: *D3D12_CPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}

d3d12_gpu_desciptor_handle_offset :: inline (this: *D3D12_GPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}

backend_init :: (using engine: *Engine) -> bool {

    ok: bool;
    dxgi_factory_flags: u32 = 0;

    if DEBUG {
        debug_interface: *ID3D12Debug1;
        if HR(D3D12GetDebugInterface(*uid(ID3D12Debug1_UUID), xx *debug_interface)) {
            HR(IUnknown_QueryInterface(debug_interface, *uid(ID3D12Debug1_UUID), xx *d3ddebug_controller));
            ID3D12Debug1_EnableDebugLayer(d3ddebug_controller);
            ID3D12Debug1_SetEnableGPUBasedValidation(d3ddebug_controller, .TRUE);
            dxgi_factory_flags |= DXGI_CREATE_FACTORY_DEBUG;

            IUnknown_Release(debug_interface);
            debug_interface = null;
        }
    }

    ok = HR(CreateDXGIFactory2(dxgi_factory_flags, *uid(IDXGIFactory4_UUID), xx *d3dfactory));
    D3D12_SetDebugObjectName(d3dfactory, *uid(IDXGIFactory4_UUID), "d3dfactory");
    if !ok {
        backend_fini(engine);
        return false;
    }

    warp_adapter_found := false;
    ok = HR(IDXGIFactory4_EnumWarpAdapter(d3dfactory, *uid(IDXGIAdapter1_UUID), xx *d3dadapter));
    if  ok {
        result := D3D12CreateDevice(d3dadapter, ._12_0, *uid(ID3D12Device_UUID), null);
        if result == 0x1 {
            warp_adapter_found = true;
        }
    } else {
        if d3dadapter IUnknown_Release(d3dadapter);
        d3dadapter = null;
    }

    adapter_index: u32 = 0;
    while true && !warp_adapter_found {
        if SUCCEEDED(IDXGIFactory1_EnumAdapters1(d3dfactory, adapter_index, *d3dadapter)) {
            desc: DXGI_ADAPTER_DESC1;
            IDXGIAdapter1_GetDesc1(d3dadapter, *desc);

            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG.SOFTWARE) continue;

            result := D3D12CreateDevice(d3dadapter, ._12_0, *uid(ID3D12Device_UUID), null);
            if 0x1 == result then break;
        }

        IUnknown_Release(d3dadapter);
        d3dadapter = null;
        adapter_index += 1;
    }

    D3D12_SetDebugObjectName(d3dadapter, *uid(IDXGIAdapter1_UUID), "d3dadapter");

    if !d3dadapter {
        #if ASSERT_ON_FAIL assert(false, "Obtaining IDXGIAdapter1 failed!");
        backend_fini(engine);
        return false;
    }

    return true;
}

backend_fini :: (using engine: *Engine) {
    #if DEBUG {
        if d3ddebug_controller IUnknown_Release(d3ddebug_controller);
        d3ddebug_controller = null;
    } 

    if d3dfactory {
        IUnknown_Release(d3dfactory);
        d3dfactory = null;
    }
    if d3dadapter {
        IUnknown_Release(d3dadapter);
        d3dadapter = null;
    }
}


backend_device_init :: (using engine: *Engine) -> bool {
    ok := HR(D3D12CreateDevice(d3dadapter, ._12_0, *uid(ID3D12Device_UUID), xx *d3ddevice));
    D3D12_SetDebugObjectName(d3ddevice, *uid(ID3D12Device_UUID), "Untitled D3D12 Device");
    if !ok {
        backend_device_fini(engine);
        return false;
    }

    #if DEBUG {
        if SUCCEEDED(IUnknown_QueryInterface(d3ddevice, *uid(ID3D12InfoQueue_UUID), xx *d3dinfo_queue)) {
            #if BREAK_ON_ERROR {
                ID3D12InfoQueue_SetBreakOnSeverity(d3dinfo_queue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(d3dinfo_queue, .ERROR, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(d3dinfo_queue, .WARNING, .TRUE);
            }

            size := ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3dinfo_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3dinfo_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3dinfo_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3dinfo_queue);
            }

            ID3D12InfoQueue_ClearStoredMessages(d3dinfo_queue);
            ID3D12InfoQueue_SetMuteDebugOutput(d3dinfo_queue, .FALSE);
        } else {
            log_error("IUnknown_QueryInterface 'ID3D12InfoQueue_UUID' failed! %");
        }
    }

    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = .NONE;
    queue_desc.Type  = .DIRECT;
    ok = HR(ID3D12Device_CreateCommandQueue(d3ddevice, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *d3d_queue));
    if !ok {
        log_error("ID3D12Device_CreateCommandQueue failed!");
        backend_device_fini(engine);
        return false;
    }

    ok = HR(ID3D12Device_CreateFence(d3ddevice, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_queue_w_fence));
    D3D12_SetDebugObjectName(d3d_queue_w_fence, *uid(ID3D12Fence_UUID), "d3d_queue_w_fence");
    if !ok {
        log_error("ID3D12Device_CreateFence failed!");
        backend_device_fini(engine);
        return false;
    }

    d3d_queue_w_event = CreateEventW(null, 0, 0, null);
    if d3d_queue_w_event == null {
        #if ASSERT_ON_FAIL assert(false, "CreateEventW failed!");
        backend_device_fini(engine);
        return false;
    }

    ok = d3d12_descriptor_heap_init(d3ddevice, *heap_rtv, .RTV);
    if !ok return false;

    ok = d3d12_descriptor_heap_init(d3ddevice, *heap_dsv, .DSV);
    if !ok return false;

    d3d12_fence_init(d3ddevice, *fence);

    return true;
}

backend_device_fini :: (using engine: *Engine) {

    d3d12_fence_release(*gfx.fence);

    if d3d_queue {
        IUnknown_Release(d3d_queue);
        d3d_queue = null;
    }

    if d3d_queue_w_fence {
        IUnknown_Release(d3d_queue_w_fence);
        d3d_queue_w_fence = null;
    }

    if d3d_queue_w_event {
        CloseHandle(xx d3d_queue_w_event);
        d3d_queue_w_event = null;
    }

    #if DEBUG {
        if d3ddevice {
            d3ddebug_device: *ID3D12DebugDevice;
            ok := IUnknown_QueryInterface(d3ddevice, *uid(ID3D12DebugDevice_UUID), xx *d3ddebug_device);
            IUnknown_Release(d3ddevice);
            d3ddevice = null;

            if !ok && d3ddebug_device {
                ID3D12DebugDevice_ReportLiveDeviceObjects(d3ddebug_device, D3D12_RLDO_FLAGS.DETAIL | .IGNORE_INTERNAL);
                IUnknown_Release(d3ddebug_device);
                d3ddebug_device = null;
                print_debug_msgs(d3dinfo_queue);
            }
        } 
    } else {
        if d3ddevice {
            IUnknown_Release(xx d3ddevice);
            d3ddevice = null;
        }
    }

    if d3dinfo_queue {
        IUnknown_Release(d3dinfo_queue);
        d3ddevice = null;
    }
}

backend_queue_wait_for_idle :: (using gfx: *Graphics_Device) {

    // Advance the fence value to mark commands up to this fence point.
    value: u64 = ID3D12Fence_GetCompletedValue(d3d_queue_w_fence);
    signal_value := value + 10;

    // Add an instruction to the command queue to set a new fence point.
    // Because we are on the GPU timeline, the new fence point won't be set until the GPU
    // finishes processing all the commands prior to this Signal().
    ID3D12CommandQueue_Signal(d3d_queue, d3d_queue_w_fence, signal_value);

    // Wait until the GPU has completed commands up to this fence point.
    if ID3D12Fence_GetCompletedValue(d3d_queue_w_fence) < signal_value {
        // Fire event when GPU hits current fence.
        ID3D12Fence_SetEventOnCompletion(d3d_queue_w_fence, signal_value, d3d_queue_w_event);

        // Wait until the GPU hits current fence event is fired.
        WaitForSingleObject(d3d_queue_w_event, 0xffff_ffff);
    }
}

backend_framebuffer_fini :: (using gfx: *Graphics_Device) {

    for n: 0..ctx_buffer_count - 1 {
        if d3drtvs[n] {
            IUnknown_Release(d3drtvs[n]);
            d3drtvs[n] = null;
        }
    }

    if d3drtv_heap {
        IUnknown_Release(d3drtv_heap);
        d3drtv_heap = null;
    }
}

backend_swapchain_init :: (using gfx: *Graphics_Device, hwnd: HWND, width: u32, height: u32) -> bool {

    surface_size.left   = 0;
    surface_size.top    = 0;
    surface_size.right  = xx width;
    surface_size.bottom = xx height;

    viewport.TopLeftX = 0.0;
    viewport.TopLeftY = 0.0;
    viewport.Width    = xx width;
    viewport.Height   = xx height;
    viewport.MinDepth = 0.0;
    viewport.MaxDepth = 1.0; 

    if d3dswapchain != null {
        IDXGISwapChain_ResizeBuffers(d3dswapchain, ctx_buffer_count, width, height, .R8G8B8A8_UNORM, 0);
    } else {
        swapchain_desc: DXGI_SWAP_CHAIN_DESC1;
        swapchain_desc.Width            = width;
        swapchain_desc.Height           = height;
        swapchain_desc.Format           = .R8G8B8A8_UNORM;
        swapchain_desc.SampleDesc.Count = 1;
        swapchain_desc.BufferUsage      = .RENDER_TARGET_OUTPUT;
        swapchain_desc.BufferCount      = ctx_buffer_count;
        swapchain_desc.SwapEffect       = .FLIP_SEQUENTIAL;

        ok := HR(IDXGIFactory2_CreateSwapChainForHwnd(d3dfactory, xx d3d_queue, hwnd, *swapchain_desc, null, null, xx *d3dswapchain));
        if !ok {
            log_error("IDXGIFactory2_CreateSwapChainForHwnd failed!");
            return false;
        }

        IDXGIFactory_MakeWindowAssociation(d3dfactory, hwnd, xx DXGI_MWA.NO_ALT_ENTER);
    }

    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(d3dswapchain);

    return true;
}

backend_framebuffer_init :: (using gfx: *Graphics_Device, width: u32, height: u32) -> bool {

    ok: bool;
    for n : 0..ctx_buffer_count - 1 {
        ok = HR(IDXGISwapChain_GetBuffer(d3dswapchain, xx n, *uid(ID3D12Resource_UUID), xx *swapchain_rtvs[n].resource));
        if !ok return false;


        rtv_desc: D3D12_RENDER_TARGET_VIEW_DESC;
        rtv_desc.ViewDimension = .TEXTURE2D;
        rtv_desc.Format = .R8G8B8A8_UNORM_SRGB;

        swapchain_rtvs[n].desc  = rtv_desc;
        array_add(*swapchain_rtvs[n].state, .PRESENT);
        array_add(*swapchain_rtvs[n].rtvs, d3d12_descriptor_heap_resource_add(d3ddevice, *heap_rtv, .RTV, swapchain_rtvs[n].resource, xx *rtv_desc));
    }

    return true;
}

backend_make_descriptor_range :: (type: D3D12_DESCRIPTOR_RANGE_TYPE, num_descriptors: u32, base_register_space: u32) -> D3D12_DESCRIPTOR_RANGE {

    descriptor_range: D3D12_DESCRIPTOR_RANGE;
    descriptor_range.RangeType = type;
    descriptor_range.NumDescriptors = num_descriptors;
    descriptor_range.BaseShaderRegister = base_register_space;
    descriptor_range.RegisterSpace = 0;
    descriptor_range.OffsetInDescriptorsFromTableStart = 0;
    return descriptor_range;
}

backend_root_parameter_init_as_descriptor_table :: (root_parameter: *D3D12_ROOT_PARAMETER, num_descriptor_range: u32, descriptor_range: *D3D12_DESCRIPTOR_RANGE) {

    root_parameter.ParameterType = .DESCRIPTOR_TABLE;
    root_parameter.DescriptorTable.NumDescriptorRanges = num_descriptor_range;
    root_parameter.DescriptorTable.pDescriptorRanges   = descriptor_range;
    root_parameter.ShaderVisibility = .ALL;
}