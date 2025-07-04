Command_Encoder :: struct {
    d3d_cmd_allocator: *ID3D12CommandAllocator;
    d3d_cmd_lists: [FRAME_COUNT] *ID3D12GraphicsCommandList;
    d3d_submit_fence: *ID3D12Fence;
    d3d_submit_event: *void;
}

Graphic_Pipeline :: struct {
    d3d_root_signature: *ID3D12RootSignature;
    d3d_pipeline_state: *ID3D12PipelineState;
}

Graphics_Device :: struct {
    d3d_device:     *ID3D12Device;
    d3d_queue:      *ID3D12CommandQueue;
    d3d_info_queue: *ID3D12InfoQueue;
    d3d_queue_w_fence: *ID3D12Fence;
    d3d_queue_w_event: *void;

    VSYNC :: false;
    MAX_SWAPCHAIN_BUFFER_COUNT :: 3;

    d3d_swapchain:  *IDXGISwapChain3;
    d3d_rtvs:       [MAX_SWAPCHAIN_BUFFER_COUNT] *ID3D12Resource;
    d3d_rtv_heap:   *ID3D12DescriptorHeap;
    d3d_rtv_heap_inc_size: u32;

    d3d_present_fence: *ID3D12Fence;
    d3d_present_event: *void;

    ctx_buffer_count:       u32;
    ctx_active_buffer_index:u32;
    ctx_present_counter:    u64;
}

render_context_init :: (using engine: *Engine) -> bool {
    if !VSYNC {
        ctx_buffer_count = 3;
    } else {
        ctx_buffer_count = 2;
    }

    swapchain_desc: DXGI_SWAP_CHAIN_DESC1;
    swapchain_desc.Width            = width;
    swapchain_desc.Height           = height;
    swapchain_desc.Format           = .R8G8B8A8_UNORM;
    swapchain_desc.SampleDesc.Count = 1;
    swapchain_desc.BufferUsage      = .RENDER_TARGET_OUTPUT;
    swapchain_desc.BufferCount      = ctx_buffer_count;
    swapchain_desc.SwapEffect       = .FLIP_SEQUENTIAL;

    result := HR(IDXGIFactory2_CreateSwapChainForHwnd(d3d_factory, xx d3d_queue, hwnd, *swapchain_desc, null, null, xx *d3d_swapchain));
    if FAILED(result) {
        log_error("IDXGIFactory2_CreateSwapChainForHwnd failed: '%'!", result);
        render_context_fini(engine);
        return false;
    }

    IDXGIFactory_MakeWindowAssociation(d3d_factory, hwnd, xx DXGI_MWA.NO_ALT_ENTER);

    rtv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
    rtv_heap_desc.Type              = .RTV;
    rtv_heap_desc.NumDescriptors    = ctx_buffer_count;
    rtv_heap_desc.Flags             = .NONE;
    result = HR(ID3D12Device_CreateDescriptorHeap(d3d_device, *rtv_heap_desc, *uid(ID3D12DescriptorHeap_UUID), xx *d3d_rtv_heap));
    if FAILED(result) {
        log_error("[D3D12] ID3D12Device_CreateDescriptorHeap failed: '%'", result);
        render_context_fini(engine);
        return false;
    }
    d3d_rtv_heap_inc_size = ID3D12Device_GetDescriptorHandleIncrementSize(d3d_device, .RTV);

    rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(d3d_rtv_heap);
    for n : 0..ctx_buffer_count-1 {
        result = HR(IDXGISwapChain_GetBuffer(d3d_swapchain, xx n, *uid(ID3D12Resource_UUID), xx *d3d_rtvs[n]));
        if FAILED(result) {
            log_error("IDXGISwapChain_GetBuffer failed!");
            render_context_fini(engine);
            return false;
        }

        rtv_desc: D3D12_RENDER_TARGET_VIEW_DESC;
        rtv_desc.ViewDimension = .TEXTURE2D;
        rtv_desc.Format = .R8G8B8A8_UNORM_SRGB;
        ID3D12Device_CreateRenderTargetView(d3d_device, d3d_rtvs[n], *rtv_desc, rtv_handle);
        rtv_handle.ptr += (1 * d3d_rtv_heap_inc_size);
    }

    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(d3d_swapchain);

    result = HR(ID3D12Device_CreateFence(d3d_device, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_present_fence));
    if FAILED(result) {
        log_error("ID3D12Device_CreateFence failed!");
        render_context_init(engine);
        return false;
    }

    d3d_present_event = CreateEventW(null, 0, 0, null);
    if d3d_present_event == null {
        log_error("CreateEventW failed!");
        render_context_init(engine);
        return false;
    }

    return true;
}

render_context_fini :: (using engine: *Engine) {
    if d3d_swapchain IUnknown_Release(d3d_swapchain);
    if d3d_rtv_heap  IUnknown_Release(d3d_rtv_heap);

    for 0..ctx_buffer_count - 1 {
        if d3d_rtvs[it] IUnknown_Release(d3d_rtvs[it]);
    }

    if d3d_present_fence IUnknown_Release(d3d_present_fence);
    if d3d_present_event CloseHandle(d3d_present_event);
}

command_encoder_init :: (using engine: *Engine) -> bool {

    result := HR(ID3D12Device_CreateCommandAllocator(d3d_device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *d3d_cmd_allocator));
    if FAILED(result) {
        log_error("[D3D12] ID3D12Device_CreateCommandAllocator failed: '%'", result);
        command_encoder_fini(*cmd_encoder);
        return false;
    }

    for i: 0..FRAME_COUNT - 1 {
        result = HR(ID3D12Device_CreateCommandList(d3d_device, 0, .DIRECT, d3d_cmd_allocator, null, *uid(ID3D12GraphicsCommandList_UUID), xx *d3d_cmd_lists[i]));
        if FAILED(result) {
            log_error("[D3D12] ID3D12Device_CreateCommandList failed: '%'", result);
            command_encoder_fini(*cmd_encoder);
            return false;
        }
        ID3D12GraphicsCommandList_Close(d3d_cmd_lists[i]);
    }

    result = HR(ID3D12Device_CreateFence(d3d_device, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_submit_fence));
    if FAILED(result) {
        log_error("[D3D12] ID3D12Device_CreateFence failed: '%'", result);
        command_encoder_fini(*cmd_encoder);
        return false;
    }

    d3d_submit_event = CreateEventW(null, 0, 0, null);
    if d3d_submit_event == null {
        log_error("[D3D12] CreateEventW failed: 'd3d_submit_event'");
        command_encoder_fini(*cmd_encoder);
        return false;
    }

    return true;
}

command_encoder_fini :: (using command_encoder: *Command_Encoder ) {
    if d3d_cmd_allocator ID3D12CommandAllocator_Reset(d3d_cmd_allocator);
    for i: 0..FRAME_COUNT - 1 {
        if d3d_cmd_lists[i] IUnknown_Release(d3d_cmd_lists[i]);
    }
    if d3d_cmd_allocator IUnknown_Release(d3d_cmd_allocator);
    if d3d_submit_fence  IUnknown_Release(d3d_submit_fence);
    if d3d_submit_event  CloseHandle(d3d_submit_event);
}

gfx_pipeline_init :: (device: *ID3D12Device, using pipeline: *Graphic_Pipeline) -> bool {

    root_signature_desc: D3D12_ROOT_SIGNATURE_DESC;
    root_signature_desc.NumParameters       = 0;
    root_signature_desc.pParameters         = null;
    root_signature_desc.NumStaticSamplers   = 0;
    root_signature_desc.pStaticSamplers     = null;

    signature: *ID3DBlob;
    error: *ID3DBlob;
    result := HR(D3D12SerializeRootSignature(*root_signature_desc, ._1, *signature, *error));
    if FAILED(result) {
        log_error("[D3D12] D3D12SerializeRootSignature failed: %", result);
        gfx_pipeline_fini(pipeline);
        return false;
        
    }

    result = ID3D12Device_CreateRootSignature(device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *d3d_root_signature);
    if FAILED(result) {
        log_error("[D3D12] ID3D12Device_CreateRootSignature failed: '%'", result);
        return false;
    }

    vs_bytecode, vs_success := compile_d3d_shader(TRIANGLE_SHADER_TEXT, "VS", "vs_5_0");
    #if DEBUG assert(vs_success, "compile_shader failed: Vertex SHADER_TEX!");
    defer free(vs_bytecode);

    ps_bytecode, ps_success := compile_d3d_shader(TRIANGLE_SHADER_TEXT, "PS", "ps_5_0");
    #if DEBUG assert(ps_success, "compile_shader failed: Vertex SHADER_TEX!");
    defer free(ps_bytecode);

    de: D3D12_GRAPHICS_PIPELINE_STATE_DESC;
    de.pRootSignature=          d3d_root_signature;

    de.VS.pShaderBytecode=      vs_bytecode.data;
    de.VS.BytecodeLength=       xx vs_bytecode.count;

    de.PS.pShaderBytecode =     ps_bytecode.data;
    de.PS.BytecodeLength=       xx ps_bytecode.count;

    de.BlendState.AlphaToCoverageEnable = .FALSE;
    de.BlendState.IndependentBlendEnable= .FALSE;
    for i : 0..7 {
        de.BlendState.RenderTarget[i].LogicOpEnable = .FALSE;
        de.BlendState.RenderTarget[i].LogicOp       = .CLEAR;
        de.BlendState.RenderTarget[i].BlendEnable   = .FALSE;
        de.BlendState.RenderTarget[i].SrcBlend      = .ONE;
        de.BlendState.RenderTarget[i].DestBlend     = .ZERO;
        de.BlendState.RenderTarget[i].BlendOp       = .ADD;
        de.BlendState.RenderTarget[i].SrcBlendAlpha = .ONE;
        de.BlendState.RenderTarget[i].DestBlendAlpha= .ZERO;
        de.BlendState.RenderTarget[i].BlendOpAlpha  = .ADD;
        de.BlendState.RenderTarget[i].RenderTargetWriteMask = cast(u8) D3D12_COLOR_WRITE_ENABLE.ALL;
    }

    de.SampleMask                       = 0xffff_ffff;

    de.RasterizerState.FillMode              = .SOLID;
    de.RasterizerState.CullMode              = .BACK;
    de.RasterizerState.FrontCounterClockwise = .FALSE;
    de.RasterizerState.DepthBias             = D3D12_DEFAULT_DEPTH_BIAS;
    de.RasterizerState.DepthBiasClamp        = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    de.RasterizerState.SlopeScaledDepthBias  = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    de.RasterizerState.DepthClipEnable       = .FALSE;
    de.RasterizerState.MultisampleEnable     = .FALSE;
    de.RasterizerState.AntialiasedLineEnable = .FALSE;

    de.DepthStencilState.DepthEnable    = .FALSE;
    de.DepthStencilState.StencilEnable  = .FALSE;
    de.InputLayout.pInputElementDescs   = null;
    de.InputLayout.NumElements          = 0;
    de.IBStripCutValue                  = .DISABLED;
    de.PrimitiveTopologyType            = .TRIANGLE;
    de.NumRenderTargets                 = 1;
    de.RTVFormats[0]                    = .R8G8B8A8_UNORM_SRGB;
    de.SampleDesc.Count                 = 1;
    de.SampleDesc.Quality               = 0;

    result = HR(ID3D12Device_CreateGraphicsPipelineState(device, *de, *uid(ID3D12PipelineState_UUID), xx *d3d_pipeline_state));
    if FAILED(result) {
        log_error("[D3D12] ID3D12Device_CreateGraphicsPipelineState failed: '%'", result);
        gfx_pipeline_fini(pipeline);
        return false;
    }

    return true;
}

gfx_pipeline_fini :: (using gfx_pipeline: *Graphic_Pipeline) {
    if d3d_pipeline_state IUnknown_Release(d3d_pipeline_state);
    if d3d_root_signature IUnknown_Release(d3d_root_signature);
}

gfx_begin :: (cmd: *ID3D12GraphicsCommandList, color: [3]float = .[0.0, 0.0, 0.0]) {

    // clear_color : [4]float = .[color[0], color[1], color[2], 1.0];
    // ID3D12GraphicsCommandList_ClearRenderTargetView(cmd, rtv_handle, *clear_color, 0, null);
    // ID3D12GraphicsCommandList_DrawIndexedInstanced(cmd, 3, 1, 0, 0);
}

gfx_present :: (using engine: *Engine) {
    ctx_present_counter += 1;
    ID3D12CommandQueue_Signal(d3d_queue, d3d_present_fence, ctx_present_counter);

    if ID3D12Fence_GetCompletedValue(d3d_present_fence) < ctx_present_counter {
        ID3D12Fence_SetEventOnCompletion(d3d_present_fence, ctx_present_counter, d3d_present_event);
        WaitForSingleObject(d3d_present_event, 0xffff_ffff);
    }

    result: HRESULT;
    if VSYNC {
        result = HR(IDXGISwapChain_Present(xx d3d_swapchain, 1, 0));
    } else {
        result = HR(IDXGISwapChain_Present(xx d3d_swapchain, 0, 0));
    }
    #if DEBUG assert(SUCCEEDED(result), "IDXGISwapChain_Present failed");

    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(d3d_swapchain);
}
