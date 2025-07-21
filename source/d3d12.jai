Scene_CBuffer :: struct {
    transform:  Matrix4;
}

CBV_SRV_UAV_HEAP_OFFSET :: enum {
    RENDER_TARGET :: 0;
    CBV           :: 1;
    SRV           :: 2;
    TEXTURE_SRV   :: 3;
    COUNT;
}

Window_Resolution :: struct {
    width:  u32;
    height: u32;
}

Scene_Vertex :: struct {
    position:   Vector3;
    uv:         Vector2;
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
    depth_buffers:      [..] *ID3D12Resource;

    intermediate_rt:    *ID3D12Resource;
    scene_cmdallocator: [..] *ID3D12CommandAllocator;
    post\_cmdallocator: [..] *ID3D12CommandAllocator;
    scene_cmdlist:      Command_List;
    post\_cmdlist:      *ID3D12GraphicsCommandList;

    scene_rootsig:      *ID3D12RootSignature;
    post\_rootsig:      *ID3D12RootSignature;
    scene_pipeline_state: *ID3D12PipelineState;
    post\_pipeline_state: *ID3D12PipelineState;

    dsv_heap:            Descriptor_Heap;
    rtv_heap:            Descriptor_Heap;
    cbvsrvuav_heap:      Descriptor_Heap; 

    // app resource
    post\_vertex_buffer:        *ID3D12Resource;
    post\_vertex_buffer_view:   D3D12_VERTEX_BUFFER_VIEW;
    scene_constant_buffer:      Buffer;
    texture:                    Texture;

    scene_vbuffer:              Buffer;
    scene_ibuffer:              Buffer;

    world_matrix_buffer: Buffer;

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
    using state.d3d12;
    success: bool;

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

    ok_or_exit(HR(D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), xx *device)), "backend init: Failed to create D3D12Device");
    #if DEBUG {
        if HR(IUnknown_QueryInterface(device, *uid(ID3D12InfoQueue_UUID), xx *infoqueue)) {
            #if BREAK_ON_ERROR {
                ID3D12InfoQueue_SetBreakOnSeverity(infoqueue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(infoqueue, .ERROR, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(infoqueue, .WARNING, .TRUE);
            }

            size := ID3D12InfoQueue_GetStorageFilterStackSize(infoqueue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(infoqueue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(infoqueue);
            }

            ID3D12InfoQueue_ClearStoredMessages(infoqueue);
            ID3D12InfoQueue_SetMuteDebugOutput(infoqueue, .FALSE);
        }
    }

    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = .NONE;
    queue_desc.Type  = .DIRECT;
    ok_or_exit(HR(ID3D12Device_CreateCommandQueue(device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *commandq)), "backend init: Failed to create D3D12CommandQueue!");
    NAME_D3D12_OBJECT(commandq, "commandq");

    ctx_buffer_count = 2;

    swapchain_desc: DXGI_SWAP_CHAIN_DESC1;
    swapchain_desc.BufferCount  = ctx_buffer_count;
    swapchain_desc.Width        = xx info.window_width;
    swapchain_desc.Height       = xx info.window_height;
    swapchain_desc.Format       = .R8G8B8A8_UNORM;
    swapchain_desc.BufferUsage  = .RENDER_TARGET_OUTPUT;
    swapchain_desc.SwapEffect   = .FLIP_DISCARD;
    swapchain_desc.SampleDesc.Count = 1;
    swapchain_desc.Flags        = ifx tearing_support then xx DXGI_SWAP_CHAIN_FLAG.ALLOW_TEARING else cast(u32) 0;

    ok_or_exit(HR(IDXGIFactory2_CreateSwapChainForHwnd(factory, xx commandq, info.hwnd, *swapchain_desc, null, null, xx *swapchain), infoqueue), "backend init: Failed to create D3D12Swapchain!");

    if tearing_support IDXGIFactory_MakeWindowAssociation(factory, info.hwnd, xx DXGI_MWA.NO_ALT_ENTER);
    ctx_current_frame_index = IDXGISwapChain3_GetCurrentBackBufferIndex(swapchain);

    success, rtv_heap       = make_descriptor_heap(.RTV, ctx_buffer_count + 1);
    success, cbvsrvuav_heap = make_descriptor_heap(.CBV_SRV_UAV, xx CBV_SRV_UAV_HEAP_OFFSET.COUNT, .SHADER_VISIBLE);
    success, dsv_heap       = make_descriptor_heap(.DSV, ctx_buffer_count);
    ok_or_exit(success);

    array_resize(*scene_cmdallocator, ctx_buffer_count);
    array_resize(*post\_cmdallocator, ctx_buffer_count);
    for i: 0..ctx_buffer_count - 1 {
        ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *scene_cmdallocator[i])), "backend init: Failed to create D3D12CommandAllocator!");
        ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *post\_cmdallocator[i])), "backend init: Failed to create D3D12CommandAllocator!");
    }

    safe_release_and_reset(*factory);
    safe_release_and_reset(*adapter);

    return true;
}

quad_width := 0.5;
quad_height := 0.5;

load_assets :: () {

    CheckInit();
    using state.d3d12;

    // This is the highest version the sample supports. If CheckFeatureSupport succeeds, the HighestVersion returned will not be greater than this.
    feature_data : D3D12_FEATURE_DATA_ROOT_SIGNATURE;
    feature_data.HighestVersion = ._1_1;
    if !HR(ID3D12Device_CheckFeatureSupport(device, .ROOT_SIGNATURE, *feature_data, size_of(D3D12_FEATURE_DATA_ROOT_SIGNATURE))) {
        feature_data.HighestVersion = ._1_0;
    }

    // Create a rootsig consisting of a desciptor table with a single CBV
    {
        ranges : [3] D3D12_DESCRIPTOR_RANGE1;
        root_parameters : [3] D3D12_ROOT_PARAMETER1;

        ranges[0] = D3D12_DESCRIPTOR_RANGE1_INIT(.CBV, 1, 0, 0, .DATA_STATIC);
        ranges[1] = D3D12_DESCRIPTOR_RANGE1_INIT(.SRV, 1, 0, 0, .DATA_VOLATILE);
        ranges[2] = D3D12_DESCRIPTOR_RANGE1_INIT(.SRV, 1, 1, 0, .DATA_STATIC);
        root_parameters[0] = D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE(1, *ranges[0], .VERTEX);
        root_parameters[1] = D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE(1, *ranges[1], .VERTEX);
        root_parameters[2] = D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE(1, *ranges[2], .PIXEL);

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
        ok_or_exit(HR(ID3D12Device_CreateRootSignature(device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *scene_rootsig)), "load_assets: Failed to create D3D12RootSignature");
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
        ok_or_exit(HR(ID3D12Device_CreateRootSignature(device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *post_rootsig)), "load_assets: Failed to create D3D12RootSignature");
        NAME_D3D12_OBJECT(post_rootsig, "post_rootsig");
    }

    {
        scene_vertex_shader: Shader;
        scene_pixel\_shader: Shader;
        post\_vertex_shader: Shader;
        post\_pixel\_shader: Shader;
        compute\    _shader: Shader;

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
        pso_desc.DepthStencilState      = D3D12_DEPTH_STENCIL_DESC_INIT(true);
        pso_desc.PrimitiveTopologyType  = .TRIANGLE;
        pso_desc.NumRenderTargets       = 1; 
        pso_desc.RTVFormats[0]          = .R8G8B8A8_UNORM;
        pso_desc.DSVFormat              = .D32_FLOAT;
        pso_desc.SampleDesc.Count       = 1;

        pso_desc.pRootSignature         = scene_rootsig;
        pso_desc.VS                     = D3D12_SHADER_BYTECODE_INIT(scene_vertex_shader.shader);
        pso_desc.PS                     = D3D12_SHADER_BYTECODE_INIT(scene_pixel\_shader.shader);
        input_elem_desc                 := shader_get_input_element(*scene_vertex_shader, .NON_SPLIT);
        pso_desc.InputLayout            = .{input_elem_desc.data, xx input_elem_desc.count};
        ok_or_exit(HR(ID3D12Device_CreateGraphicsPipelineState(device, *pso_desc, *uid(ID3D12PipelineState_UUID), xx *scene_pipeline_state)), "load_assets: Failed to create D3D12GraphicsPipelineState!");

        pso_desc.pRootSignature         = post_rootsig;
        pso_desc.DSVFormat              = .UNKNOWN;
        pso_desc.DepthStencilState      = D3D12_DEPTH_STENCIL_DESC_INIT();
        pso_desc.VS                     = D3D12_SHADER_BYTECODE_INIT(post_vertex_shader.shader);
        pso_desc.PS                     = D3D12_SHADER_BYTECODE_INIT(post_pixel\_shader.shader);
        scale_elem_desc                 := shader_get_input_element(*post\_vertex_shader, .NON_SPLIT);
        pso_desc.InputLayout            = .{scale_elem_desc.data, xx scale_elem_desc.count};
        ok_or_exit(HR(ID3D12Device_CreateGraphicsPipelineState(device, *pso_desc, *uid(ID3D12PipelineState_UUID), xx *post_pipeline_state)), "load_assets: Failed to create D3D12GraphicsPipelineState!");
    }

    // single use command allocator and command list for resource creating
    cmdallocator : *ID3D12CommandAllocator;
    ok_or_exit(HR(ID3D12Device_CreateCommandAllocator(device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *cmdallocator)), "load_asset: Failed to create D3D12CommandAllocator!");
    defer safe_release_and_reset(*cmdallocator);

    ok, cmdlist := make_command_list(cmdallocator, .DIRECT);
    if !ok log_error("Failed create intermediate D3D12CommandList");
    defer deinit(*cmdlist);
    
    // create the command lists
    {
        // ok_or_exit(HR(ID3D12Device_CreateCommandList(device, 0, .DIRECT, scene_cmdallocator[ctx_current_frame_index], null,  *uid(ID3D12CommandList_UUID), xx *scene_cmdlist)), "load_asset: Failed to create D3D12GraphicCommandList!");
        ok_or_exit(HR(ID3D12Device_CreateCommandList(device, 0, .DIRECT, post\_cmdallocator[ctx_current_frame_index], null,  *uid(ID3D12CommandList_UUID), xx *post\_cmdlist)), "load_asset: Failed to create D3D12GraphicCommandList!");

        ok:, scene_cmdlist = make_command_list(scene_cmdallocator[ctx_current_frame_index], .DIRECT);
        commandlist_close(*scene_cmdlist);
        ok_or_exit(HR(ID3D12GraphicsCommandList_Close(post_cmdlist)), "load_assets: Failed to close D3D12GraphicsCommandList!");
    }

    load_size_dependent_resource();
    load_scene_resolution_dependent_resource();

    post_vertex_upload_buffer: *ID3D12Resource; defer safe_release_and_reset(*post_vertex_upload_buffer);
    // create/update the fullscreen quad vertex buffer
    {
        // define the geoometry for a fullscreen quad
        quadvertices : [] Post_Vertex = .[
            .{.{-1, -1, 0, 1}, .{0, 1}},
            .{.{-1,  1, 0, 1}, .{0, 0}},
            .{.{ 1, -1, 0, 1}, .{1, 1}},
            .{.{ 1,  1, 0, 1}, .{1, 0}},
        ];
        vertex_buffer_size := size_of(Post_Vertex) * quadvertices.count;
        vbuffer_desc := D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx vertex_buffer_size);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *vbuffer_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *post_vertex_buffer)), "load_size_dependent_resource: Failed to create CommittedResource!");
        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *vbuffer_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *post_vertex_upload_buffer)), "load_assets: Failed to create CommittedResource!");

        cpu_mapaddr: *void;
        read_range: D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(post_vertex_upload_buffer, 0, *read_range, xx *cpu_mapaddr);
        memcpy(cpu_mapaddr, xx quadvertices.data, xx vertex_buffer_size);
        ID3D12Resource_Unmap(post_vertex_upload_buffer, 0, null);
        
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(post_vertex_buffer, .COMMON, .COPY_DEST));
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist.cmdlist, post_vertex_buffer, 0, post_vertex_upload_buffer, 0, xx vertex_buffer_size);
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(post_vertex_buffer, .COPY_DEST, .VERTEX_AND_CONSTANT_BUFFER));
        
        post_vertex_buffer_view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(post_vertex_buffer);
        post_vertex_buffer_view.StrideInBytes  = size_of(Post_Vertex);
        post_vertex_buffer_view.SizeInBytes    = xx vertex_buffer_size;
    }

    // create the constant buffer
    {
        success:, scene_constant_buffer = make_constants_buffer(*cbvsrvuav_heap, xx size_of(Scene_CBuffer));

        // map and initialize the constant buffer.
        // we don't unmap this until the app closes. keeping things mapped for the lifetime of the resource is okay
        read_range : D3D12_RANGE = .{0, 0};
        ID3D12Resource_Map(scene_constant_buffer.upload_buffer, 0, *read_range, xx *scene_constant_buffer.map_addr);
        memcpy(scene_constant_buffer.map_addr, *scene_cbuffer, size_of(Scene_CBuffer));
    }

    {
        success:, world_matrix_buffer = make_structured_buffer(*cbvsrvuav_heap, xx size_of(Matrix4), MAX_ENTITIES);
        world_matrices: [..] Matrix4;
        for state.scene.entities {
            array_add(*world_matrices, transpose(it.local_transform.world));
        }

        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(world_matrix_buffer.resource, .COMMON, .COPY_DEST));
        commandlist_update_buffer_data(*cmdlist, *world_matrix_buffer, world_matrices.data, xx world_matrices.count * size_of(Matrix4));
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(world_matrix_buffer.resource, .COPY_DEST, .GENERIC_READ));
    }

    bitmap: Bitmap;
    defer deinit(*bitmap);
    {
        bitmap_load(*bitmap, "resources/textures/dirt_12-256x256.png");

        success:, texture = make_texture2d_from_bitmap(*cbvsrvuav_heap, *bitmap);
        ok_or_exit(success, "load_assets: Failed to create Texture!");

        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(texture.resource, .COMMON, .COPY_DEST));
        commandlist_update_texture_data(*cmdlist, *texture, bitmap.data.data);
        ID3D12GraphicsCommandList_ResourceBarrier(cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(texture.resource, .COPY_DEST, .PIXEL_SHADER_RESOURCE));
    }

    {
        ppf := aiPostProcessSteps.Triangulate | aiPostProcessSteps.CalcTangentSpace;
        tscene := aiImportFileEx("resources/meshes/sphere.fbx", ppf.(u32), null);
        defer aiFreeScene(tscene);

        assert(tscene != null);

        meshes: []*aiMesh;
        meshes.data = tscene.mMeshes;
        meshes.count = tscene.mNumMeshes;

        success:, scene_vbuffer = make_vertex_buffer(size_of(Vector3), xx (meshes[0].mNumVertices));
        success,  scene_ibuffer = make_index\_buffer(size_of(u32), xx (3 * meshes[0].mNumFaces));

        index_data: [..] u32;
        index_data.allocator = temp;
        array_resize(*index_data, meshes[0].mNumFaces * 3);

        for i: 0..meshes[0].mNumFaces - 1 {
            index_data[i * 3    ] = meshes[0].mFaces[i].mIndices[0];
            index_data[i * 3 + 1] = meshes[0].mFaces[i].mIndices[1];
            index_data[i * 3 + 2] = meshes[0].mFaces[i].mIndices[2];
        }

        commandlist_resource_transition(*cmdlist, scene_vbuffer.resource, .COMMON, .COPY_DEST);
        commandlist_resource_transition(*cmdlist, scene_ibuffer.resource, .COMMON, .COPY_DEST);

        commandlist_update_buffer_data(*cmdlist, *scene_vbuffer, meshes[0].mVertices, size_of(Vector3) * meshes[0].mNumVertices);
        commandlist_update_buffer_data(*cmdlist, *scene_ibuffer, index_data.data, size_of(u32) * 3 * meshes[0].mNumFaces);

        print("index %\n", index_data.count);

        commandlist_resource_transition(*cmdlist, scene_vbuffer.resource, .COPY_DEST, .VERTEX_AND_CONSTANT_BUFFER);
        commandlist_resource_transition(*cmdlist, scene_ibuffer.resource, .COPY_DEST, .INDEX_BUFFER);
    }

    // close the resource creation command list and execute it to begin the vbuffer copy into the default heap
    commandlist_close(*cmdlist);
    cmdlists : [] *ID3D12CommandList = .[cmdlist.cmdlist];
    commandlist_execute(commandq, cmdlists.count, cmdlists.data);

    array_resize(*fence_values, ctx_buffer_count);
    {
        ok_or_exit(HR(ID3D12Device_CreateFence(device, fence_values[ctx_current_frame_index], .NONE, *uid(ID3D12Fence_UUID), xx *fence)), "load_assets: Failed to create D3D12Fence");
        fence_values[ctx_current_frame_index] += 1;
        fence_event = CreateEventW(null, 0, 0, null);
        if fence_event == null {
            log_error("load_assets: Failed to create EventW!");
            exit(1);
        }

        wait_for_gpu();
    }
}

load_size_dependent_resource :: () {

    CheckInit();
    using state.d3d12;

    update_post_view_and_scissor();

    // create frame resource
    {
        array_resize(*render_targets, ctx_buffer_count);
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(rtv_heap.heap);
        for i: 0..ctx_buffer_count - 1 {
            IDXGISwapChain_GetBuffer(swapchain, xx i, *uid(ID3D12Resource_UUID), xx *render_targets[i]);
            ID3D12Device_CreateRenderTargetView(device, render_targets[i], null, rtv_handle);
            rtv_handle.ptr += xx (1 * rtv_heap.size);
        }
    }
}

load_scene_resolution_dependent_resource :: () {
    
    CheckInit();
    using state.d3d12;

    current_width  := resolution_options[current_resolution_index].width;
    current_height := resolution_options[current_resolution_index].height;

    // setup the scene viewport and scissoor rect to match the current scene rendering resolutioon
    {
        scene_viewport.Width  = xx current_width;
        scene_viewport.Height = xx current_height;
        
        scene_scissor_rect.right  = xx current_width;
        scene_scissor_rect.bottom = xx current_height;
    }
    
    // update post process viewport and scissor rect
    update_post_view_and_scissor();

    // create RTV for the intermediate render target
    swapchain_desc: D3D12_RESOURCE_DESC = ID3D12Resource_GetDesc(render_targets[ctx_current_frame_index]); 
    {
        clear_value: D3D12_CLEAR_VALUE;
        clear_value.Format = swapchain_desc.Format;
        clear_value.Color  = .[0, 0, 0, 0];
        rt_desc := D3D12_RESOURCE_DESC_INIT_AS_TEXTURE2D(swapchain_desc.Format, xx current_width, xx current_height, 1, 1, swapchain_desc.SampleDesc.Count, swapchain_desc.SampleDesc.Quality, .ALLOW_RENDER_TARGET, .UNKNOWN, 0);

        ok_or_exit(HR(ID3D12Device_CreateCommittedResource(device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *rt_desc, .RENDER_TARGET, *clear_value, *uid(ID3D12Resource_UUID), xx *intermediate_rt)), "load_size_dependent_resource: Failed to create CommittedResource!");
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(rtv_heap.heap);
        rtv_handle.ptr += xx (ctx_buffer_count * rtv_heap.size);
        ID3D12Device_CreateRenderTargetView(device, intermediate_rt, null, rtv_handle);
    }

    srv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(cbvsrvuav_heap.heap);
    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Format                  = swapchain_desc.Format;
    srv_desc.ViewDimension           = .TEXTURE2D;
    srv_desc.Shader4ComponentMapping = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Texture2D.MipLevels     = 1;
    ID3D12Device_CreateShaderResourceView(device, intermediate_rt, *srv_desc, srv_handle);

    // create DSV for the intermediate render target
    {
        dsv_desc: D3D12_DEPTH_STENCIL_VIEW_DESC;
        dsv_desc.Format = .D32_FLOAT;
        dsv_desc.ViewDimension = .TEXTURE2D;
        dsv_desc.Flags    = .NONE;

        depth_optimized_clear_value: D3D12_CLEAR_VALUE;
        depth_optimized_clear_value.Format               = .D32_FLOAT;
        depth_optimized_clear_value.DepthStencil.Depth   = 1.0;
        depth_optimized_clear_value.DepthStencil.Stencil = 0;

        array_resize(*depth_buffers, ctx_buffer_count);
        dsv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(dsv_heap.heap);
        for *depth_buffers {
            ok_or_exit(HR(ID3D12Device_CreateCommittedResource(
                device, 
                *D3D12_HEAP_PROPERTIES_INIT(),
                .NONE,
                *D3D12_RESOURCE_DESC_INIT_AS_TEXTURE2D(.D32_FLOAT, xx current_width, xx current_height, flags=.ALLOW_DEPTH_STENCIL),
                .DEPTH_WRITE,
                *depth_optimized_clear_value,
                *uid(ID3D12Resource_UUID),
                xx it)), "load_assets: Failed to create D3D12Resource!");

            ID3D12Device_CreateDepthStencilView(device, it.*, *dsv_desc, dsv_handle);
            dsv_handle.ptr += xx (1 * dsv_heap.size);
        }
    }
}

update_post_view_and_scissor :: () {

    CheckInit();
    using state.d3d12;

    view_width_ratio  := cast(float) (resolution_options[current_resolution_index].width / xx state.current_window_info.window_width);
    view_height_ratio := cast(float) (resolution_options[current_resolution_index].height / xx state.current_window_info.window_height);

    x, y := 1.0;
    if view_width_ratio < view_height_ratio {
        x = view_width_ratio / view_height_ratio;
    } else {
        y = view_height_ratio / view_width_ratio;
    }

    post_viewport.TopLeftX = state.current_window_info.window_width * (1.0 - x) / 2.0;
    post_viewport.TopLeftY = state.current_window_info.window_height * (1.0 - y) / 2.0;
    post_viewport.Width    = x * state.current_window_info.window_width;
    post_viewport.Height   = y * state.current_window_info.window_height;

    post_scissor_rect.left   = xx post_viewport.TopLeftX;
    post_scissor_rect.right  = xx (post_viewport.TopLeftX + post_viewport.Width);
    post_scissor_rect.top    = xx post_viewport.TopLeftY;
    post_scissor_rect.bottom = xx (post_viewport.TopLeftY + post_viewport.Height);
}

wait_for_gpu :: () {

    CheckInit();
    using state.d3d12;

    ok_or_exit(HR(ID3D12CommandQueue_Signal(commandq, fence, xx fence_values[ctx_current_frame_index])), "wait_for_gpu: Failed to signal command queue!");
    ok_or_exit(HR(ID3D12Fence_SetEventOnCompletion(fence, fence_values[ctx_current_frame_index], fence_event)), "wait_for_gpu: Failed to set event on complete!");
    WaitForSingleObject(fence_event, INFINITE);

    fence_values[ctx_current_frame_index] += 1;
}

move_to_next_frame :: () {

    CheckInit();
    using state.d3d12;

    current_fence_value := fence_values[ctx_current_frame_index];
    ok_or_exit(HR(ID3D12CommandQueue_Signal(commandq, fence, xx current_fence_value)), "wait_for_gpu: Failed to signal command queue!");
    
    ctx_current_frame_index = IDXGISwapChain3_GetCurrentBackBufferIndex(swapchain);
    if ID3D12Fence_GetCompletedValue(fence) < fence_values[ctx_current_frame_index] {
        ok_or_exit(HR(ID3D12Fence_SetEventOnCompletion(fence, fence_values[ctx_current_frame_index], fence_event)), "wait_for_gpu: Failed to set event on complete!");
        WaitForSingleObject(fence_event, INFINITE);
    }
    fence_values[ctx_current_frame_index] = current_fence_value + 1;
}

backend_update :: () {

    CheckInit();
    wait_for_gpu();

    t := seconds_since_init();

    if !Input.input_application_has_focus && state.control_camera set_camera_control(false);
    if state.control_camera {
        x, y, w, h := get_dimensions(state.current_window_info.hwnd, true);
        set_mouse_pointer_position(w / 2, h / 2);
    }

    camera_update();
}

backend_render :: () {

    CheckInit();
    using state.d3d12;

    backend_populate_commandlists();
    cmdlists : [] *ID3D12CommandList = .[scene_cmdlist.cmdlist, post_cmdlist];
    ID3D12CommandQueue_ExecuteCommandLists(commandq, xx cmdlists.count, cmdlists.data);
    ok_or_exit(HR(IDXGISwapChain_Present(swapchain, 0, 0)));
    
    move_to_next_frame();
}

backend_populate_commandlists :: () {

    CheckInit();
    using state.d3d12;
    
    ok_or_exit(HR(ID3D12CommandAllocator_Reset(post_cmdallocator[ctx_current_frame_index])), "backend_populate_commandlists: Failed to reset D3D12CommandAllocator!");
    ok_or_exit(HR(ID3D12GraphicsCommandList_Reset(post_cmdlist, post_cmdallocator[ctx_current_frame_index], post_pipeline_state)), "backend_populate_commandlists: Failed to reset D3D12CommandList!");

    commandlist_reset_w_allocator(*scene_cmdlist, scene_pipeline_state);
    
    // populate scene commandlist to render scene to intermediate render target
    {
        ID3D12GraphicsCommandList_SetGraphicsRootSignature(scene_cmdlist.cmdlist, scene_rootsig);
        heaps: [] *ID3D12DescriptorHeap = .[cbvsrvuav_heap.heap];
        ID3D12GraphicsCommandList_SetDescriptorHeaps(scene_cmdlist.cmdlist, xx heaps.count, xx heaps.data);

        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(scene_cmdlist.cmdlist, 0, scene_constant_buffer.cbv.gpu);
        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(scene_cmdlist.cmdlist, 1, world_matrix_buffer.srv.gpu);
        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(scene_cmdlist.cmdlist, 2, texture.srv.gpu);

        ID3D12GraphicsCommandList_RSSetViewports(scene_cmdlist.cmdlist, 1, *scene_viewport);
        ID3D12GraphicsCommandList_RSSetScissorRects(scene_cmdlist.cmdlist, 1, *scene_scissor_rect);
    
        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(rtv_heap.heap);
        rtv_handle.ptr += xx (ctx_buffer_count * rtv_heap.size);
        dsv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(dsv_heap.heap);
        dsv_handle.ptr += xx (ctx_current_frame_index * dsv_heap.size);
        ID3D12GraphicsCommandList_OMSetRenderTargets(scene_cmdlist.cmdlist, 1, *rtv_handle, .FALSE, *dsv_handle);

        clear_color : [4] float = .[0, 0, 0, 0];
        ID3D12GraphicsCommandList_ClearRenderTargetView(scene_cmdlist.cmdlist, rtv_handle, *clear_color, 0, null);

        ID3D12GraphicsCommandList_ClearDepthStencilView(scene_cmdlist.cmdlist, dsv_handle, .DEPTH, 1.0, 0, 1, *scene_scissor_rect);

        ID3D12GraphicsCommandList_IASetPrimitiveTopology(scene_cmdlist.cmdlist, .TRIANGLELIST);
        // ID3D12GraphicsCommandList_IASetVertexBuffers(scene_cmdlist.cmdlist, 0, 1, *scene_vertex_buffer_view);
        // ID3D12GraphicsCommandList_IASetIndexBuffer(scene_cmdlist.cmdlist, *scene_index_buffer_view);
        ID3D12GraphicsCommandList_IASetVertexBuffers(scene_cmdlist.cmdlist, 0, 1, *scene_vbuffer.vbv);
        ID3D12GraphicsCommandList_IASetIndexBuffer(scene_cmdlist.cmdlist, *scene_ibuffer.ibv);

        cbuffer : Scene_CBuffer = .{transform = transpose(state.camera.viewproj)};
        memcpy(scene_constant_buffer.map_addr, *cbuffer, size_of(Scene_CBuffer));

        world_matrices: [..] Matrix4;
        for state.scene.entities {
            yaw : Quaternion;
            pitch: Quaternion;
            set_from_axis_and_angle(*yaw, .{0, 1, 0}, state.deltatime * 2);
            set_from_axis_and_angle(*pitch, .{1, 0, 0}, state.deltatime * 5);

            delta := normalize(yaw * pitch);
            it.local_transform.rotation = normalize(delta * it.local_transform.rotation);

            world := make_world_matrix(*it.local_transform);
            array_add(*world_matrices, transpose(world));
        }

        ID3D12GraphicsCommandList_ResourceBarrier(scene_cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(world_matrix_buffer.resource, .COMMON, .COPY_DEST));
        commandlist_update_buffer_data(*scene_cmdlist, *world_matrix_buffer, world_matrices.data, xx world_matrices.count * size_of(Matrix4));
        ID3D12GraphicsCommandList_ResourceBarrier(scene_cmdlist.cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(world_matrix_buffer.resource, .COPY_DEST, .GENERIC_READ));

        ID3D12GraphicsCommandList_DrawIndexedInstanced(scene_cmdlist.cmdlist, 9216, xx state.scene.entities.count, 0, 0, 0);
    }

    commandlist_close(*scene_cmdlist);
    {
        ID3D12GraphicsCommandList_SetGraphicsRootSignature(post_cmdlist, post_rootsig);
        heaps: [] *ID3D12DescriptorHeap = .[cbvsrvuav_heap.heap];
        ID3D12GraphicsCommandList_SetDescriptorHeaps(post_cmdlist, xx heaps.count, xx heaps.data);

        {
            barriers : [] D3D12_RESOURCE_BARRIER = .[
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(render_targets[ctx_current_frame_index], .COMMON, .RENDER_TARGET),
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(intermediate_rt, .RENDER_TARGET, .PIXEL_SHADER_RESOURCE),
            ];
            ID3D12GraphicsCommandList_ResourceBarrier(post_cmdlist, xx barriers.count, xx barriers.data);
        }

        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(post_cmdlist, 0, ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(cbvsrvuav_heap.heap));
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(post_cmdlist, .TRIANGLELIST);
        ID3D12GraphicsCommandList_RSSetViewports(post_cmdlist, 1, *post_viewport);
        ID3D12GraphicsCommandList_RSSetScissorRects(post_cmdlist, 1, *post_scissor_rect);

        rtv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(rtv_heap.heap);
        rtv_handle.ptr += xx (ctx_current_frame_index * rtv_heap.size);
        ID3D12GraphicsCommandList_OMSetRenderTargets(post_cmdlist, 1, *rtv_handle, .FALSE, null);

        clear_color : [4] float = .[0.2, 0.4, 0.6, 1.0];
        ID3D12GraphicsCommandList_ClearRenderTargetView(post_cmdlist, rtv_handle, *clear_color, 0, null);
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(post_cmdlist, .TRIANGLESTRIP);
        ID3D12GraphicsCommandList_IASetVertexBuffers(post_cmdlist, 0, 1, *post_vertex_buffer_view);

        ID3D12GraphicsCommandList_DrawInstanced(post_cmdlist, 4, 1, 0, 0);

        {
            barriers : [] D3D12_RESOURCE_BARRIER = .[
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(render_targets[ctx_current_frame_index], .RENDER_TARGET, .PRESENT),
                D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(intermediate_rt, .PIXEL_SHADER_RESOURCE, .RENDER_TARGET),
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
    safe_release_and_reset(*post_vertex\_buffer);
    deinit(*scene_vbuffer);
    deinit(*scene_ibuffer);
    deinit(*scene_constant_buffer);
    deinit(*world_matrix_buffer);
    deinit(*texture);

    // pipeline object
    deinit(*rtv_heap);
    deinit(*cbvsrvuav_heap);
    deinit(*dsv_heap);

    safe_release_and_reset(*scene_rootsig);
    safe_release_and_reset(*post\_rootsig);
    safe_release_and_reset(*scene_pipeline_state);
    safe_release_and_reset(*post\_pipeline_state);

    deinit(*scene_cmdlist);
    safe_release_and_reset(*post_cmdlist);

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
    for depth_buffers {
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