Scene_CBuffer :: struct {
    transform:  Matrix4;
}

Window_Resolution :: struct {
    width:  u32;
    height: u32;
}

Scene_Vertex :: struct {
    position:   Vector3;
    color:      Vector4;
}

Post_Vertex ::  struct {
    position:  Vector4;
    uv:        Vector2;
}

D3D12_CONTEXT :: struct {
    // pipeline object
    scene_viewport: D3D12_VIEWPORT;
    post\_viewport: D3D12_VIEWPORT;
    scene_scissor_rect: D3D12_RECT;
    post\_scissor_rect: D3D12_RECT;

    device:             *ID3D12Device;
    #if DEBUG infoqueue:*ID3D12InfoQueue;
    swapchain:          *IDXGISwapChain3;
    commandq:           *ID3D12CommandQueue;
    render_targets:     [..] *ID3D12Resource;
    intermediate_rt:    *ID3D12Resource;
    scene_cmdallocator: [..] *ID3D12CommandAllocator;
    post\_cmdallocator: [..] *ID3D12CommandAllocator;
    scene_cmdlist:      *ID3D12GraphicsCommandList;
    post\_cmdlist:      *ID3D12GraphicsCommandList;

    scene_rootsig:      *ID3D12RootSignature;
    post\_rootsig:      *ID3D12RootSignature;
    scene_pipeline_state: *ID3D12PipelineState;
    post\_pipeline_state: *ID3D12PipelineState;

    rtv_heap:           *ID3D12DescriptorHeap;
    rtv_descriptor_size: u32;
    cbvsrvuav_heap:     *ID3D12DescriptorHeap;
    cbvsrvuav_descriptor_size: u32;

    // app resource
    scene_vertex_buffer:        *ID3D12Resource;
    scene_index\_buffer:        *ID3D12Resource;
    scene_vertex_buffer_view:   D3D12_VERTEX_BUFFER_VIEW;
    scene_index\_buffer_view:   D3D12_INDEX_BUFFER_VIEW;
    post\_vertex_buffer:        *ID3D12Resource;
    post\_vertex_buffer_view:   D3D12_VERTEX_BUFFER_VIEW;
    scene_constant_buffer:      *ID3D12Resource;

    cbv_mapaddr: *void;
    scene_cbuffer: Scene_CBuffer;

    // synchronization objects
    frame_index: u32;
    fence_event: HANDLE;
    fence:      *ID3D12Fence;
    fence_values: [..] u64; 

    ctx_buffer_count: u32;
    ctx_current_frame_index: u32;
    tearing_support: bool;
    current_resolution_index: u32 = 0;
}

resolution_options : [] Window_Resolution = .[
    .{ 800,  600},
    .{1200,  900},
    .{1280,  720},
    .{1920, 1080},
    .{1920, 1200},
    .{2560, 1440},
    .{3440, 1440},
    .{3840, 2160},
];

backend_init :: (info: *Window_Info) -> bool {
    CheckInit();

    dxgi_factory_flags : u32 = 0;
    #if DEBUG {
        debug_controller: *ID3D12Debug3;
        if HR(D3D12GetDebugInterface(*uid(ID3D12Debug_UUID), xx *debug_controller)) {
            ID3D12Debug_EnableDebugLayer(debug_controller);
            ID3D12Debug3_SetEnableGPUBasedValidation(debug_controller, .TRUE);
            dxgi_factory_flags |= DXGI_CREATE_FACTORY_DEBUG;
        }
    }

    factory : *IDXGIFactory4;
    ok_or_exit(HR(CreateDXGIFactory2(dxgi_factory_flags, *uid(IDXGIFactory2_UUID), xx *factory)), "backend init: Failed to create D3D12Factory");

    warp_adapter_found := false;
    adapter: *IDXGIAdapter1;
    ok_or_exit(HR(IDXGIFactory4_EnumWarpAdapter(factory, *uid(IDXGIAdapter1_UUID), xx *adapter)), "backend init: Failed to enumerate D3D12Adapter");

    adapter_index: u32 = 0;
    while true && !warp_adapter_found {
        if HR(IDXGIFactory1_EnumAdapters1(factory, adapter_index, *adapter)) {
            desc: DXGI_ADAPTER_DESC1;
            IDXGIAdapter1_GetDesc1(adapter, *desc);

            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG.SOFTWARE) continue;
            result := D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), null);
            if result == 0x1 then break;
        }

        safe_release_and_reset(*adapter);
        adapter_index += 1;
    }

    ok_or_exit(adapter != null, "backend init: Failed to enumerate D3D12Adapter");

    ok_or_exit(HR(D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), xx *state.d3d12.device)), "backend init: Failed to create D3D12Device");
    #if DEBUG {
        if HR(IUnknown_QueryInterface(state.d3d12.device, *uid(ID3D12InfoQueue_UUID), xx *state.d3d12.infoqueue)) {
            #if BREAK_ON_ERROR {
                ID3D12InfoQueue_SetBreakOnSeverity(state.d3d12.infoqueue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(state.d3d12.infoqueue, .ERROR, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(state.d3d12.infoqueue, .WARNING, .TRUE);
            }

            size := ID3D12InfoQueue_GetStorageFilterStackSize(state.d3d12.infoqueue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(state.d3d12.infoqueue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(state.d3d12.infoqueue);
            }

            ID3D12InfoQueue_ClearStoredMessages(state.d3d12.infoqueue);
            ID3D12InfoQueue_SetMuteDebugOutput(state.d3d12.infoqueue, .FALSE);
        }
    }

    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = .NONE;
    queue_desc.Type  = .DIRECT;
    ok_or_exit(HR(ID3D12Device_CreateCommandQueue(state.d3d12.device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *state.d3d12.commandq)), "backend init: Failed to create D3D12CommandQueue!");
    NAME_D3D12_OBJECT(state.d3d12.commandq, "commandq");

    // ok_or_exit(HR(ID3D12Device_CreateFence(state.d3d12.device, 0, .NONE, *uid(ID3D12Fence_UUID), xx *state.d3d12.fence)), "backend init: Failed to create D3D12Fence!");
    // state.d3d12.fence_event = CreateEventW(null, 0, 0, null);

    state.d3d12.ctx_buffer_count = 2;

    swapchain_desc: DXGI_SWAP_CHAIN_DESC1;
    swapchain_desc.BufferCount  = state.d3d12.ctx_buffer_count;
    swapchain_desc.Width        = xx info.window_width;
    swapchain_desc.Height       = xx info.window_height;
    swapchain_desc.Format       = .R8G8B8A8_UNORM;
    swapchain_desc.BufferUsage  = .RENDER_TARGET_OUTPUT;
    swapchain_desc.SwapEffect   = .FLIP_DISCARD;
    swapchain_desc.SampleDesc.Count = 1;
    swapchain_desc.Flags        = ifx state.d3d12.tearing_support then xx DXGI_SWAP_CHAIN_FLAG.ALLOW_TEARING else cast(u32) 0;

    ok_or_exit(HR(IDXGIFactory2_CreateSwapChainForHwnd(factory, xx state.d3d12.commandq, info.hwnd, *swapchain_desc, null, null, xx *state.d3d12.swapchain), state.d3d12.infoqueue), "backend init: Failed to create D3D12Swapchain!");

    if state.d3d12.tearing_support IDXGIFactory_MakeWindowAssociation(factory, info.hwnd, xx DXGI_MWA.NO_ALT_ENTER);
    state.d3d12.ctx_current_frame_index = IDXGISwapChain3_GetCurrentBackBufferIndex(state.d3d12.swapchain);

    rtv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
    rtv_heap_desc.NumDescriptors = state.d3d12.ctx_buffer_count + 1; // +1 for the intermediate render target
    rtv_heap_desc.Type           = .RTV;
    rtv_heap_desc.Flags          = .NONE;
    ok_or_exit(HR(ID3D12Device_CreateDescriptorHeap(state.d3d12.device, *rtv_heap_desc, *uid(ID3D12DescriptorHeap_UUID), xx *state.d3d12.rtv_heap)), "backend init: Failed to create D3D12DescriptorHeap!");
    
    cbvsrvuav_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
    cbvsrvuav_heap_desc.NumDescriptors = state.d3d12.ctx_buffer_count + 1; // +1 for the intermediate render target
    cbvsrvuav_heap_desc.Type           = .CBV_SRV_UAV;
    cbvsrvuav_heap_desc.Flags          = .SHADER_VISIBLE;
    ok_or_exit(HR(ID3D12Device_CreateDescriptorHeap(state.d3d12.device, *cbvsrvuav_heap_desc, *uid(ID3D12DescriptorHeap_UUID), xx *state.d3d12.cbvsrvuav_heap)), "backend init: Failed to create D3D12DescriptorHeap!");

    state.d3d12.rtv_descriptor_size         = ID3D12Device_GetDescriptorHandleIncrementSize(state.d3d12.device, .RTV);
    state.d3d12.cbvsrvuav_descriptor_size   = ID3D12Device_GetDescriptorHandleIncrementSize(state.d3d12.device, .CBV_SRV_UAV);

    array_resize(*state.d3d12.scene_cmdallocator, state.d3d12.ctx_buffer_count);
    array_resize(*state.d3d12.post\_cmdallocator, state.d3d12.ctx_buffer_count);
    for i: 0..state.d3d12.ctx_buffer_count - 1 {
        ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(state.d3d12.device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *state.d3d12.scene_cmdallocator[i])), "backend init: Failed to create D3D12CommandAllocator!");
        ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(state.d3d12.device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *state.d3d12.post\_cmdallocator[i])), "backend init: Failed to create D3D12CommandAllocator!");
    }

    safe_release_and_reset(*factory);
    safe_release_and_reset(*adapter);

    return true;
}

quad_width := 0.5;
quad_height := 0.5;

load_assets :: () {
    CheckInit();

    // This is the highest version the sample supports. If CheckFeatureSupport succeeds, the HighestVersion returned will not be greater than this.
    feature_data : D3D12_FEATURE_DATA_ROOT_SIGNATURE;
    feature_data.HighestVersion = ._1_1;
    if !HR(ID3D12Device_CheckFeatureSupport(state.d3d12.device, .ROOT_SIGNATURE, *feature_data, size_of(D3D12_FEATURE_DATA_ROOT_SIGNATURE))) {
        feature_data.HighestVersion = ._1_0;
    }

    // Create a rootsig consisting of a desciptor table with a single CBV
    {
        ranges : [1] D3D12_DESCRIPTOR_RANGE1;
        root_parameters : [1] D3D12_ROOT_PARAMETER1;

        ranges[0] = D3D12_DESCRIPTOR_RANGE1_INIT(.CBV, 1, 0, 0, .DATA_STATIC);
        root_parameters[0] = D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE(1, *ranges[0], .VERTEX);

        rootsig_flags : D3D12_ROOT_SIGNATURE_FLAGS = .ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
        rootsig_desc : D3D12_VERSIONED_ROOT_SIGNATURE_DESC;
        rootsig_desc.Version = ._1_1;
        rootsig_desc.Desc_1_1.NumParameters      = xx root_parameters.count;
        rootsig_desc.Desc_1_1.pParameters        = root_parameters.data;
        rootsig_desc.Desc_1_1.NumStaticSamplers  = 0;
        rootsig_desc.Desc_1_1.pStaticSamplers    = null;
        rootsig_desc.Desc_1_1.Flags              = rootsig_flags;

        signature:  *ID3DBlob;
        error:      *ID3DBlob;
        ok_or_exit(HR(D3D12SerializeVersionedRootSignature(*rootsig_desc, *signature, *error)), "load_assets: Failed to serialize versioned root signature!");
        ok_or_exit(HR(ID3D12Device_CreateRootSignature(state.d3d12.device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *state.d3d12.scene_rootsig)), "load_assets: Failed to create D3D12RootSignature");
        NAME_D3D12_OBJECT(state.d3d12.scene_rootsig, "scene_rootsig");
    }

    // Create a rootsig consisting of a desciptor table with a SRV and a sampler
    {
        ranges : [1] D3D12_DESCRIPTOR_RANGE1;
        root_parameters : [1] D3D12_ROOT_PARAMETER1;

        ranges[0] = D3D12_DESCRIPTOR_RANGE1_INIT(.SRV, 1, 0);
        root_parameters[0] = D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE(1, *ranges[0], .PIXEL);

        sampler: D3D12_STATIC_SAMPLER_DESC;
        sampler.Filter          = .MIN_MAG_POINT_MIP_LINEAR;
        sampler.AddressU        = .BORDER;
        sampler.AddressV        = .BORDER;
        sampler.AddressW        = .BORDER;
        sampler.MipLODBias      = 0;
        sampler.MaxAnisotropy   = 0;
        sampler.ComparisonFunc  = .NEVER;
        sampler.MinLOD          = 0;
        sampler.MaxLOD          = 0;
        sampler.ShaderRegister  = 0;
        sampler.RegisterSpace   = 0;
        sampler.ShaderVisibility= .PIXEL;

        rootsig_flags : D3D12_ROOT_SIGNATURE_FLAGS = .ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
        rootsig_desc : D3D12_VERSIONED_ROOT_SIGNATURE_DESC;
        rootsig_desc.Version = ._1_1;
        rootsig_desc.Desc_1_1.NumParameters      = xx root_parameters.count;
        rootsig_desc.Desc_1_1.pParameters        = root_parameters.data;
        rootsig_desc.Desc_1_1.NumStaticSamplers  = 1;
        rootsig_desc.Desc_1_1.pStaticSamplers    = *sampler;
        rootsig_desc.Desc_1_1.Flags              = rootsig_flags;

        signature:  *ID3DBlob;
        error:      *ID3DBlob;
        ok_or_exit(HR(D3D12SerializeVersionedRootSignature(*rootsig_desc, *signature, *error)), "load_assets: Failed to serialize versioned root signature!");
        ok_or_exit(HR(ID3D12Device_CreateRootSignature(state.d3d12.device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *state.d3d12.post_rootsig)), "load_assets: Failed to create D3D12RootSignature");
        NAME_D3D12_OBJECT(state.d3d12.post_rootsig, "post_rootsig");
    }

    // creating pipeling state
    {
        scene_vertex_shader: Shader;
        scene_pixel\_shader: Shader;
        post\_vertex_shader: Shader;
        post\_pixel\_shader: Shader;
        error: *ID3DBlob;
        result: HRESULT;
        
        Compile_Shader(*scene_vertex_shader, error, "resources/shaders/SceneShader.hlsl", "VSMain", "vs_5_0");
        Compile_Shader(*scene_pixel\_shader, error, "resources/shaders/SceneShader.hlsl", "PSMain", "ps_5_0");
        Compile_Shader(*post\_vertex_shader, error, "resources/shaders/PostShader.hlsl",  "VSMain", "vs_5_0");
        Compile_Shader(*post\_pixel\_shader, error, "resources/shaders/PostShader.hlsl",  "PSMain", "ps_5_0");

        pso_desc: D3D12_GRAPHICS_PIPELINE_STATE_DESC;
        pso_desc.BlendState             = D3D12_BLEND_DESC_INIT();
        pso_desc.SampleMask             = INFINITE;
        pso_desc.RasterizerState        = D3D12_RASTERIZER_DESC_INIT();
        pso_desc.DepthStencilState      = D3D12_DEPTH_STENCIL_DESC_INIT();
        pso_desc.PrimitiveTopologyType  = .TRIANGLE;
        pso_desc.NumRenderTargets       = 1; 
        pso_desc.RTVFormats[0]          = DXGI_FORMAT.R8G8B8A8_UNORM;
        pso_desc.DSVFormat              = DXGI_FORMAT.UNKNOWN;
        pso_desc.SampleDesc.Count       = 1;

        pso_desc.pRootSignature         = state.d3d12.scene_rootsig;
        pso_desc.VS                     = D3D12_SHADER_BYTECODE_INIT(scene_vertex_shader.shader);
        pso_desc.PS                     = D3D12_SHADER_BYTECODE_INIT(scene_pixel\_shader.shader);
        input_elem_desc                 := shader_get_input_element(*scene_vertex_shader, .NON_SPLIT);
        pso_desc.InputLayout            = .{input_elem_desc.data, xx input_elem_desc.count};
        ok_or_exit(HR(ID3D12Device_CreateGraphicsPipelineState(state.d3d12.device, *pso_desc, *uid(ID3D12PipelineState_UUID), xx *state.d3d12.scene_pipeline_state)), "load_assets: Failed to create D3D12GraphicsPipelineState!");
        NAME_D3D12_OBJECT(state.d3d12.scene_pipeline_state, "scene_pipeline_state");

        pso_desc.pRootSignature         = state.d3d12.post_rootsig;
        pso_desc.VS                     = D3D12_SHADER_BYTECODE_INIT(post_vertex_shader.shader);
        pso_desc.PS                     = D3D12_SHADER_BYTECODE_INIT(post_pixel\_shader.shader);
        scale_elem_desc                 := shader_get_input_element(*post\_vertex_shader, .NON_SPLIT);
        pso_desc.InputLayout            = .{scale_elem_desc.data, xx scale_elem_desc.count};
        ok_or_exit(HR(ID3D12Device_CreateGraphicsPipelineState(state.d3d12.device, *pso_desc, *uid(ID3D12PipelineState_UUID), xx *state.d3d12.post_pipeline_state)), "load_assets: Failed to create D3D12GraphicsPipelineState!");
        NAME_D3D12_OBJECT(state.d3d12.post_pipeline_state, "post_pipeline_state");
    }

    // single use command allocator and command list for resource creating
    cmdallocator : *ID3D12CommandAllocator;
    ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(state.d3d12.device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *cmdallocator)), "load_asset: Failed to create D3D12CommandAllocator!");
    defer safe_release_and_reset(*cmdallocator);
    NAME_D3D12_OBJECT(cmdallocator, "intermediate_cmdallocator");

    cmdlist: *ID3D12GraphicsCommandList;
    ok_or_exit(HR(ID3D12Device_CreateCommandList(state.d3d12.device, 0, .DIRECT, cmdallocator, null,  *uid(ID3D12CommandList_UUID), xx *cmdlist)), "load_asset: Failed to create D3D12GraphicCommandList!");
    defer safe_release_and_reset(*cmdlist);
    NAME_D3D12_OBJECT(cmdlist, "intermediate_cmdlist");
    
    // create the command lists
    {
        ok_or_exit(HR(ID3D12Device_CreateCommandList(state.d3d12.device, 0, .DIRECT, state.d3d12.scene_cmdallocator[state.d3d12.ctx_current_frame_index], null,  *uid(ID3D12CommandList_UUID), xx *state.d3d12.scene_cmdlist)), "load_asset: Failed to create D3D12GraphicCommandList!");
        ok_or_exit(HR(ID3D12Device_CreateCommandList(state.d3d12.device, 0, .DIRECT, state.d3d12.post\_cmdallocator[state.d3d12.ctx_current_frame_index], null,  *uid(ID3D12CommandList_UUID), xx *state.d3d12.post\_cmdlist)), "load_asset: Failed to create D3D12GraphicCommandList!");
        NAME_D3D12_OBJECT(state.d3d12.scene_cmdlist, "state.d3d12.scene_cmdlist");
        NAME_D3D12_OBJECT(state.d3d12.post_cmdlist, "state.d3d12.post_cmdlist");

        ok_or_exit(HR(ID3D12GraphicsCommandList_Close(state.d3d12.scene_cmdlist)), "load_assets: Failed to close D3D12GraphicsCommandList!");
        ok_or_exit(HR(ID3D12GraphicsCommandList_Close(state.d3d12.post_cmdlist)), "load_assets: Failed to close D3D12GraphicsCommandList!");
    }

    load_size_dependent_resource();
    load_scene_resolution_dependent_resource();

    scene_vertex_upload_buffer : *ID3D12Resource; defer safe_release_and_reset(*scene_vertex_upload_buffer);
    scene_index\_upload_buffer : *ID3D12Resource; defer safe_release_and_reset(*scene_index_upload_buffer);
    {
        // define the geometry for a thin quad that will animate across the screen
        x := quad_width  / 2.0;
        y := quad_height / 2.0;
        quadvertices : [] Scene_Vertex = .[
            .{.{-0.5,  0.5, 1.0}, .{1.0, 0.0, 0.0, 1.0}},
            .{.{ 0.5,  0.5, 1.0}, .{0.0, 1.0, 0.0, 1.0}},
            .{.{ 0.5, -0.5, 1.0}, .{0.0, 0.0, 1.0, 1.0}},
            .{.{-0.5, -0.5, 1.0}, .{0.0, 0.0, 1.0, 1.0}},
        ];
        vertex_buffer_size := size_of(Scene_Vertex) * quadvertices.count;
        vbuffer_desc := D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx vertex_buffer_size);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *vbuffer_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *state.d3d12.scene_vertex_buffer)), "load_assets: Failed to create CommittedResource!");
        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *vbuffer_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *scene_vertex_upload_buffer)), "load_assets: Failed to create CommittedResource!");

        cpu_mapaddr: *void;
        read_range: D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(scene_vertex_upload_buffer, 0, *read_range, xx *cpu_mapaddr);
        memcpy(cpu_mapaddr, xx quadvertices.data, xx vertex_buffer_size);
        ID3D12Resource_Unmap(scene_vertex_upload_buffer, 0, null);
        
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.scene_vertex_buffer, .COMMON, .COPY_DEST));
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, state.d3d12.scene_vertex_buffer, 0, scene_vertex_upload_buffer, 0, xx vertex_buffer_size);
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.scene_vertex_buffer, .COPY_DEST, .VERTEX_AND_CONSTANT_BUFFER));
        
        state.d3d12.scene_vertex_buffer_view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(state.d3d12.scene_vertex_buffer);
        state.d3d12.scene_vertex_buffer_view.StrideInBytes  = size_of(Scene_Vertex);
        state.d3d12.scene_vertex_buffer_view.SizeInBytes    = xx vertex_buffer_size;

        quadindices : [] u32 = .[0, 1, 2, 0, 2, 3];
        index_buffer_size := size_of(u32) * quadindices.count;
        ibuffer_desc := D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx index_buffer_size);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *ibuffer_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *state.d3d12.scene_index_buffer)), "load_assets: Failed to create CommittedResource!");
        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *ibuffer_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *scene_index_upload_buffer)), "load_assets: Failed to create CommittedResource!");

        icpu_mapaddr: *void;
        irr: D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(scene_index_upload_buffer, 0, *irr, xx *icpu_mapaddr);
        memcpy(icpu_mapaddr, xx quadindices.data, xx index_buffer_size);
        ID3D12Resource_Unmap(scene_index_upload_buffer, 0, null);

        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.scene_index_buffer, .COMMON, .COPY_DEST));
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, state.d3d12.scene_index_buffer, 0, scene_index_upload_buffer, 0, xx index_buffer_size);
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.scene_index_buffer, .COPY_DEST, .INDEX_BUFFER));

        state.d3d12.scene_index_buffer_view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(state.d3d12.scene_index_buffer);
        state.d3d12.scene_index_buffer_view.SizeInBytes    = xx index_buffer_size;
        state.d3d12.scene_index_buffer_view.Format         = .R32_UINT;
    }

    post_vertex_upload_buffer: *ID3D12Resource; defer safe_release_and_reset(*post_vertex_upload_buffer);
    // create/update the fullscreen quad vertex buffer
    {
        post_vertex_upload_buffer: *ID3D12Resource;
        // define the geoometry for a fullscreen quad
        quadvertices : [] Post_Vertex = .[
            .{.{-1, -1, 0, 1}, .{0, 1}},
            .{.{-1,  1, 0, 1}, .{0, 0}},
            .{.{ 1, -1, 0, 1}, .{1, 1}},
            .{.{ 1,  1, 0, 1}, .{1, 0}},
        ];
        vertex_buffer_size := size_of(Post_Vertex) * quadvertices.count;
        vbuffer_desc := D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx vertex_buffer_size);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *vbuffer_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *state.d3d12.post_vertex_buffer)), "load_size_dependent_resource: Failed to create CommittedResource!");
        NAME_D3D12_OBJECT(state.d3d12.post_vertex_buffer, "state.d3d12.post_vertex_buffer");
        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *vbuffer_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *post_vertex_upload_buffer)), "load_assets: Failed to create CommittedResource!");

        cpu_mapaddr: *void;
        read_range: D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(post_vertex_upload_buffer, 0, *read_range, xx *cpu_mapaddr);
        memcpy(cpu_mapaddr, xx quadvertices.data, xx vertex_buffer_size);
        ID3D12Resource_Unmap(post_vertex_upload_buffer, 0, null);
        
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.post_vertex_buffer, .COMMON, .COPY_DEST));
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, state.d3d12.post_vertex_buffer, 0, post_vertex_upload_buffer, 0, xx vertex_buffer_size);
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.post_vertex_buffer, .COPY_DEST, .VERTEX_AND_CONSTANT_BUFFER));
        
        state.d3d12.post_vertex_buffer_view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(state.d3d12.post_vertex_buffer);
        state.d3d12.post_vertex_buffer_view.StrideInBytes  = size_of(Post_Vertex);
        state.d3d12.post_vertex_buffer_view.SizeInBytes    = xx vertex_buffer_size;
    }

    // create the constant buffer
    {
        aligned_cb_size := CalculateConstantBufferByteSize(size_of(Scene_CBuffer));
        total_size := aligned_cb_size * state.d3d12.ctx_buffer_count;
        cbuffer_desc := D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx total_size);
        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *cbuffer_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *state.d3d12.scene_constant_buffer)), "load_size_dependent_resource: Failed to create CommittedResource!");
        NAME_D3D12_OBJECT(state.d3d12.scene_constant_buffer, "state.d3d12.scene_constant_buffer");

        base_buffer_location := ID3D12Resource_GetGPUVirtualAddress(state.d3d12.scene_constant_buffer);

        cpu_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.cbvsrvuav_heap);
        cpu_handle.ptr += xx (1 * state.d3d12.cbvsrvuav_descriptor_size);
        
        cbv_desc: D3D12_CONSTANT_BUFFER_VIEW_DESC;
        cbv_desc.SizeInBytes = xx CalculateConstantBufferByteSize(size_of(Scene_CBuffer));
        for i: 0..state.d3d12.ctx_buffer_count - 1 {
            cbv_desc.BufferLocation = xx base_buffer_location + (i * xx CalculateConstantBufferByteSize(size_of(Scene_CBuffer)));
            ID3D12Device_CreateConstantBufferView(state.d3d12.device, *cbv_desc, cpu_handle);
            cpu_handle.ptr += xx (1 * state.d3d12.cbvsrvuav_descriptor_size);
        }

        // map and initialize the constant buffer.
        // we don't unmap this until the app closes. keeping things mapped for the lifetime of the resource is okay
        read_range : D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(state.d3d12.scene_constant_buffer, 0, *read_range, xx *state.d3d12.cbv_mapaddr);
        memcpy(state.d3d12.cbv_mapaddr, *state.d3d12.scene_cbuffer, size_of(Scene_CBuffer));
    }

    // close the resource creation command list and execute it to begin the vbuffer copy into the default heap
    ID3D12GraphicsCommandList_Close(cmdlist);
    cmdlists : [] *ID3D12CommandList = .[cmdlist];
    ID3D12CommandQueue_ExecuteCommandLists(state.d3d12.commandq, xx cmdlists.count, cmdlists.data);

    array_resize(*state.d3d12.fence_values, state.d3d12.ctx_buffer_count);
    {
        ok_or_exit(HR(ID3D12Device_CreateFence(state.d3d12.device, state.d3d12.fence_values[state.d3d12.ctx_current_frame_index], .NONE, *uid(ID3D12Fence_UUID), xx *state.d3d12.fence)), "load_assets: Failed to create D3D12Fence");
        state.d3d12.fence_values[state.d3d12.ctx_current_frame_index] += 1;
        state.d3d12.fence_event = CreateEventW(null, 0, 0, null);
        if state.d3d12.fence_event == null {
            log_error("load_assets: Failed to create EventW!");
            exit(1);
        }

        wait_for_gpu();
    }
}

load_size_dependent_resource :: () {

    CheckInit();
    update_post_view_and_scissor();

    // create frame resource
    {
        array_resize(*state.d3d12.render_targets, state.d3d12.ctx_buffer_count);
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.rtv_heap);
        for i: 0..state.d3d12.ctx_buffer_count - 1 {
            IDXGISwapChain_GetBuffer(state.d3d12.swapchain, xx i, *uid(ID3D12Resource_UUID), xx *state.d3d12.render_targets[i]);
            ID3D12Device_CreateRenderTargetView(state.d3d12.device, state.d3d12.render_targets[i], null, rtv_handle);
            rtv_handle.ptr += xx (1 * state.d3d12.rtv_descriptor_size);
        }
    }
}

load_scene_resolution_dependent_resource :: () {
    
    CheckInit();
    current_width  := resolution_options[state.d3d12.current_resolution_index].width;
    current_height := resolution_options[state.d3d12.current_resolution_index].height;

    // setup the scene viewport and scissoor rect to match the current scene rendering resolutioon
    {
        state.d3d12.scene_viewport.Width  = xx current_width;
        state.d3d12.scene_viewport.Height = xx current_height;
        
        state.d3d12.scene_scissor_rect.right  = xx current_width;
        state.d3d12.scene_scissor_rect.bottom = xx current_height;
    }
    
    // update post process viewport and scissor rect
    update_post_view_and_scissor();

    // create RTV for the intermediate render target
    swapchain_desc: D3D12_RESOURCE_DESC = ID3D12Resource_GetDesc(state.d3d12.render_targets[state.d3d12.ctx_current_frame_index]); 
    {
        clear_value: D3D12_CLEAR_VALUE;
        clear_value.Format = swapchain_desc.Format;
        clear_value.Color  = .[0, 0, 0, 0];
        rt_desc := D3D12_RESOURCE_DESC_INIT_AS_TEXTURE2D(swapchain_desc.Format, xx current_width, xx current_height, 1, 1, swapchain_desc.SampleDesc.Count, swapchain_desc.SampleDesc.Quality, .ALLOW_RENDER_TARGET, .UNKNOWN, 0);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(state.d3d12.device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *rt_desc, .RENDER_TARGET, *clear_value, *uid(ID3D12Resource_UUID), xx *state.d3d12.intermediate_rt)), "load_size_dependent_resource: Failed to create CommittedResource!");
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.rtv_heap);
        rtv_handle.ptr += xx (state.d3d12.ctx_buffer_count * state.d3d12.rtv_descriptor_size);
        ID3D12Device_CreateRenderTargetView(state.d3d12.device, state.d3d12.intermediate_rt, null, rtv_handle);
    }

    srv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.cbvsrvuav_heap);
    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Format                  = swapchain_desc.Format;
    srv_desc.ViewDimension           = .TEXTURE2D;
    srv_desc.Shader4ComponentMapping = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Texture2D.MipLevels     = 1;
    ID3D12Device_CreateShaderResourceView(state.d3d12.device, state.d3d12.intermediate_rt, *srv_desc, srv_handle);
}

update_post_view_and_scissor :: () {

    CheckInit();
    view_width_ratio  := cast(float) (resolution_options[state.d3d12.current_resolution_index].width / xx state.current_window_info.window_width);
    view_height_ratio := cast(float) (resolution_options[state.d3d12.current_resolution_index].height / xx state.current_window_info.window_height);

    x, y := 1.0;
    if view_width_ratio < view_height_ratio {
        x = view_width_ratio / view_height_ratio;
    } else {
        y = view_height_ratio / view_width_ratio;
    }

    state.d3d12.post_viewport.TopLeftX = state.current_window_info.window_width * (1.0 - x) / 2.0;
    state.d3d12.post_viewport.TopLeftY = state.current_window_info.window_height * (1.0 - y) / 2.0;
    state.d3d12.post_viewport.Width    = x * state.current_window_info.window_width;
    state.d3d12.post_viewport.Height   = y * state.current_window_info.window_height;

    state.d3d12.post_scissor_rect.left   = xx state.d3d12.post_viewport.TopLeftX;
    state.d3d12.post_scissor_rect.right  = xx (state.d3d12.post_viewport.TopLeftX + state.d3d12.post_viewport.Width);
    state.d3d12.post_scissor_rect.top    = xx state.d3d12.post_viewport.TopLeftY;
    state.d3d12.post_scissor_rect.bottom = xx (state.d3d12.post_viewport.TopLeftY + state.d3d12.post_viewport.Height);
}

wait_for_gpu :: () {

    CheckInit();
    ok_or_exit(HR(ID3D12CommandQueue_Signal(state.d3d12.commandq, state.d3d12.fence, xx state.d3d12.fence_values[state.d3d12.ctx_current_frame_index])), "wait_for_gpu: Failed to signal command queue!");
    ok_or_exit(HR(ID3D12Fence_SetEventOnCompletion(state.d3d12.fence, state.d3d12.fence_values[state.d3d12.ctx_current_frame_index], state.d3d12.fence_event)), "wait_for_gpu: Failed to set event on complete!");
    WaitForSingleObject(state.d3d12.fence_event, INFINITE);

    state.d3d12.fence_values[state.d3d12.ctx_current_frame_index] += 1;
}

move_to_next_frame :: () {

    CheckInit();
    current_fence_value := state.d3d12.fence_values[state.d3d12.ctx_current_frame_index];
    ok_or_exit(HR(ID3D12CommandQueue_Signal(state.d3d12.commandq, state.d3d12.fence, xx current_fence_value)), "wait_for_gpu: Failed to signal command queue!");
    
    state.d3d12.ctx_current_frame_index = IDXGISwapChain3_GetCurrentBackBufferIndex(state.d3d12.swapchain);
    if ID3D12Fence_GetCompletedValue(state.d3d12.fence) < state.d3d12.fence_values[state.d3d12.ctx_current_frame_index] {
        ok_or_exit(HR(ID3D12Fence_SetEventOnCompletion(state.d3d12.fence, state.d3d12.fence_values[state.d3d12.ctx_current_frame_index], state.d3d12.fence_event)), "wait_for_gpu: Failed to set event on complete!");
        WaitForSingleObject(state.d3d12.fence_event, INFINITE);
    }
    state.d3d12.fence_values[state.d3d12.ctx_current_frame_index] = current_fence_value + 1;
}

backend_update :: () {

    CheckInit();
    scene_cbuffer := state.d3d12.scene_cbuffer;
    scene_cbuffer.transform = transpose(state.camera.viewproj);

    offset := state.d3d12.ctx_current_frame_index * CalculateConstantBufferByteSize(size_of(Scene_CBuffer));
    memcpy(state.d3d12.cbv_mapaddr + offset, *scene_cbuffer, size_of(Scene_CBuffer));
}

backend_render :: () {

    CheckInit();
    backend_populate_commandlists();
    cmdlists : [] *ID3D12CommandList = .[state.d3d12.scene_cmdlist, state.d3d12.post_cmdlist];
    ID3D12CommandQueue_ExecuteCommandLists(state.d3d12.commandq, xx cmdlists.count, cmdlists.data);
    ok_or_exit(HR(IDXGISwapChain_Present(state.d3d12.swapchain, 0, 0)));
    
    move_to_next_frame();
}

backend_populate_commandlists :: () {

    CheckInit();
    
    scene_cmdlist := state.d3d12.scene_cmdlist;
    post\_cmdlist := state.d3d12.post\_cmdlist;

    ok_or_exit(HR(ID3D12CommandAllocator_Reset(state.d3d12.scene_cmdallocator[state.d3d12.ctx_current_frame_index])), "backend_populate_commandlists: Failed to reset D3D12CommandAllocator!");
    ok_or_exit(HR(ID3D12CommandAllocator_Reset(state.d3d12.post_cmdallocator[state.d3d12.ctx_current_frame_index])), "backend_populate_commandlists: Failed to reset D3D12CommandAllocator!");
    
    ok_or_exit(HR(ID3D12GraphicsCommandList_Reset(scene_cmdlist, state.d3d12.scene_cmdallocator[state.d3d12.ctx_current_frame_index], state.d3d12.scene_pipeline_state)), "backend_populate_commandlists: Failed to reset D3D12CommandList!");
    ok_or_exit(HR(ID3D12GraphicsCommandList_Reset(post_cmdlist, state.d3d12.post_cmdallocator[state.d3d12.ctx_current_frame_index], state.d3d12.post_pipeline_state)), "backend_populate_commandlists: Failed to reset D3D12CommandList!");
    
    // populate scene commandlist to render scene to intermediate render target
    {
        ID3D12GraphicsCommandList_SetGraphicsRootSignature(scene_cmdlist, state.d3d12.scene_rootsig);
        heaps: [] *ID3D12DescriptorHeap = .[state.d3d12.cbvsrvuav_heap];
        ID3D12GraphicsCommandList_SetDescriptorHeaps(scene_cmdlist, xx heaps.count, xx heaps.data);

        cbv_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(state.d3d12.cbvsrvuav_heap);
        cbv_handle.ptr += xx ((state.d3d12.ctx_current_frame_index + 1) * state.d3d12.cbvsrvuav_descriptor_size);
        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(scene_cmdlist, 0, cbv_handle);
        ID3D12GraphicsCommandList_RSSetViewports(scene_cmdlist, 1, *state.d3d12.scene_viewport);
        ID3D12GraphicsCommandList_RSSetScissorRects(scene_cmdlist, 1, *state.d3d12.scene_scissor_rect);
    
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.rtv_heap);
        rtv_handle.ptr += xx (state.d3d12.ctx_buffer_count * state.d3d12.rtv_descriptor_size);
        ID3D12GraphicsCommandList_OMSetRenderTargets(scene_cmdlist, 1, *rtv_handle, .FALSE, null);

        clear_color : [4] float = .[0, 0, 0, 0];
        ID3D12GraphicsCommandList_ClearRenderTargetView(scene_cmdlist, rtv_handle, *clear_color, 0, null);
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(scene_cmdlist, .TRIANGLELIST);
        ID3D12GraphicsCommandList_IASetVertexBuffers(scene_cmdlist, 0, 1, *state.d3d12.scene_vertex_buffer_view);
        ID3D12GraphicsCommandList_IASetIndexBuffer(scene_cmdlist, *state.d3d12.scene_index_buffer_view);

        ID3D12GraphicsCommandList_DrawIndexedInstanced(scene_cmdlist, 6, 1, 0, 0, 0);
    }

    ok_or_exit(HR(ID3D12GraphicsCommandList_Close(scene_cmdlist)), "backend_populate_commandlists: Failed to close D3D12GraphicsCommandList");

    {
        ID3D12GraphicsCommandList_SetGraphicsRootSignature(post_cmdlist, state.d3d12.post_rootsig);
        heaps: [] *ID3D12DescriptorHeap = .[state.d3d12.cbvsrvuav_heap];
        ID3D12GraphicsCommandList_SetDescriptorHeaps(post_cmdlist, xx heaps.count, xx heaps.data);

        {
            barriers : [] D3D12_RESOURCE_BARRIER = .[
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.render_targets[state.d3d12.ctx_current_frame_index], .COMMON, .RENDER_TARGET),
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.intermediate_rt, .RENDER_TARGET, .PIXEL_SHADER_RESOURCE),
            ];
            ID3D12GraphicsCommandList_ResourceBarrier(post_cmdlist, xx barriers.count, xx barriers.data);
        }

        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(post_cmdlist, 0, ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(state.d3d12.cbvsrvuav_heap));
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(post_cmdlist, .TRIANGLELIST);
        ID3D12GraphicsCommandList_RSSetViewports(post_cmdlist, 1, *state.d3d12.post_viewport);
        ID3D12GraphicsCommandList_RSSetScissorRects(post_cmdlist, 1, *state.d3d12.post_scissor_rect);

        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(state.d3d12.rtv_heap);
        rtv_handle.ptr += xx (state.d3d12.ctx_current_frame_index * state.d3d12.rtv_descriptor_size);
        ID3D12GraphicsCommandList_OMSetRenderTargets(post_cmdlist, 1, *rtv_handle, .FALSE, null);

        clear_color : [4] float = .[0.2, 0.4, 0.6, 1.0];
        ID3D12GraphicsCommandList_ClearRenderTargetView(post_cmdlist, rtv_handle, *clear_color, 0, null);
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(post_cmdlist, .TRIANGLESTRIP);
        ID3D12GraphicsCommandList_IASetVertexBuffers(post_cmdlist, 0, 1, *state.d3d12.post_vertex_buffer_view);

        ID3D12GraphicsCommandList_DrawInstanced(post_cmdlist, 4, 1, 0, 0);

        {
            barriers : [] D3D12_RESOURCE_BARRIER = .[
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.render_targets[state.d3d12.ctx_current_frame_index], .RENDER_TARGET, .PRESENT),
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(state.d3d12.intermediate_rt, .PIXEL_SHADER_RESOURCE, .RENDER_TARGET),
            ];
            ID3D12GraphicsCommandList_ResourceBarrier(post_cmdlist, xx barriers.count, xx barriers.data);
        }
    }

    ok_or_exit(HR(ID3D12GraphicsCommandList_Close(post_cmdlist)), "backend_populate_commandlists: Failed to close D3D12GraphicsCommandList");
}

backend_fini :: () {

    CheckInit();
    wait_for_gpu();
    using state.d3d12;

    // app resource;
    safe_release_and_reset(*scene_vertex_buffer);
    safe_release_and_reset(*scene_index\_buffer);
    safe_release_and_reset(*post_vertex\_buffer);
    safe_release_and_reset(*scene_constant_buffer);

    // pipeline object
    safe_release_and_reset(*rtv_heap);
    safe_release_and_reset(*cbvsrvuav_heap);

    safe_release_and_reset(*scene_rootsig);
    safe_release_and_reset(*post\_rootsig);
    safe_release_and_reset(*scene_pipeline_state);
    safe_release_and_reset(*post\_pipeline_state);

    safe_release_and_reset(*post_cmdlist);
    safe_release_and_reset(*scene_cmdlist);

    for post_cmdallocator {
        safe_release_and_reset(*it);
    }
    for scene_cmdallocator {
        safe_release_and_reset(*it);
    }

    safe_release_and_reset(*intermediate_rt);
    for render_targets {
        safe_release_and_reset(*it);
    }

    safe_release_and_reset(*fence);

    safe_release_and_reset(*commandq);
    safe_release_and_reset(*swapchain);

    #if DEBUG {
        if device {
            debug_device: *ID3D12DebugDevice;
            result := IUnknown_QueryInterface(device, *uid(ID3D12DebugDevice_UUID), xx *debug_device);
            safe_release_and_reset(*device);

            if SUCCEEDED(result) {
                ID3D12DebugDevice_ReportLiveDeviceObjects(debug_device, D3D12_RLDO_FLAGS.DETAIL | D3D12_RLDO_FLAGS.IGNORE_INTERNAL);
                safe_release_and_reset(*debug_device);
                print_debug_msgs(infoqueue);
            }
        }
        safe_release_and_reset(*infoqueue);
    } 

    safe_release_and_reset(*device);
}