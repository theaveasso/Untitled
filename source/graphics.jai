Command_Encoder :: struct {
    d3dcmd_allocator: *ID3D12CommandAllocator;
    d3dcmd_lists: [FRAME_COUNT] *ID3D12GraphicsCommandList;
    d3d_submit_fence: *ID3D12Fence;
    d3d_submit_event: *void;
}

Graphic_Pipeline :: struct {
    d3droot_signature: *ID3D12RootSignature;
    d3dpipeline_state: *ID3D12PipelineState;
}

D3D12Device :: struct {
    d3ddevice:     *ID3D12Device;
    d3dinfo_queue: *ID3D12InfoQueue;
}

Graphics_Device :: struct {
    d3dfactory: *IDXGIFactory4;
    d3dadapter: *IDXGIAdapter1;

    using _d3ddevice: D3D12Device;
    d3d_queue:     *ID3D12CommandQueue;
    d3d_queue_w_fence: *ID3D12Fence;
    d3d_queue_w_event: *void;

    #if DEBUG {
        d3ddebug_controller: *ID3D12Debug1;
        d3ddebug_device:     *ID3D12DebugDevice;
    }

    VSYNC :: false;
    MAX_SWAPCHAIN_BUFFER_COUNT :: 3;

    fence: D3D12Fence;

    d3dswapchain:  *IDXGISwapChain3;
    d3drtvs:       [MAX_SWAPCHAIN_BUFFER_COUNT] *ID3D12Resource;

    heap_rtv: D3D12Descriptor_Heap;
    heap_dsv: D3D12Descriptor_Heap;

    d3drtv_heap:   *ID3D12DescriptorHeap;
    d3d_rtv_heap_inc_size: u32;

    d3dcbv_heap: *ID3D12DescriptorHeap;

    d3d_present_fence: *ID3D12Fence;
    d3d_present_event: *void;

    viewport: D3D12_VIEWPORT;
    surface_size: D3D12_RECT;

    ctx_buffer_count:       u32;
    ctx_active_buffer_index:u32;
    ctx_present_counter:    u64;

    swapchain_rtvs: [MAX_SWAPCHAIN_BUFFER_COUNT]Swapchain_Buffer;
}

Immediate_Vertex :: struct {
    position:   Vector3;
    color:      Vector4;
}

VS_UBO :: struct {
    ubo_projection: Matrix4;
    ubo_model:      Matrix4;
}

Upload_Buffer :: struct ($T: Type) {
    upload_buffer: *ID3D12Resource;
    mapped_data: *void;

    element_bytesize: u32 = 0;
    is_constant_buffer: bool = false;
}

render_context_init :: (using engine: *Engine) -> bool {

    if !VSYNC {
        ctx_buffer_count = 3;
    } else {
        ctx_buffer_count = 2;
    }

    gfx_update_window(engine);

    ok := HR(ID3D12Device_CreateFence(d3ddevice, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_present_fence));
    D3D12_SetDebugObjectName(d3d_present_fence, *uid(ID3D12Fence_UUID), "d3d_present_fence");
    if !ok {
        log_error("ID3D12Device_CreateFence failed!");
        render_context_fini(engine);
        return false;
    }

    d3d_present_event = CreateEventW(null, 0, 0, null);
    if d3d_present_event == null {
        log_error("CreateEventW failed!");
        render_context_fini(engine);
        return false;
    }

    return true;
}

render_context_fini :: (using engine: *Engine) {
    if d3dswapchain IUnknown_Release(d3dswapchain);
    if d3drtv_heap  IUnknown_Release(d3drtv_heap);

    for 0..ctx_buffer_count - 1 {
        if d3drtvs[it] IUnknown_Release(d3drtvs[it]);
    }

    if d3d_present_fence IUnknown_Release(d3d_present_fence);
    if d3d_present_event CloseHandle(d3d_present_event);
}

command_encoder_init :: (using engine: *Engine) -> bool {

    ok := HR(ID3D12Device_CreateCommandAllocator(d3ddevice, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *d3dcmd_allocator));
    D3D12_SetDebugObjectName(d3dcmd_allocator, *uid(ID3D12CommandAllocator_UUID), "d3dcmd_allocator");
    if !ok {
        log_error("[D3D12] ID3D12Device_CreateCommandAllocator failed!");
        command_encoder_fini(*cmd_encoder);
        return false;
    }

    for i: 0..FRAME_COUNT - 1 {
        ok = HR(ID3D12Device_CreateCommandList(d3ddevice, 0, .DIRECT, d3dcmd_allocator, null, *uid(ID3D12GraphicsCommandList_UUID), xx *d3dcmd_lists[i]));
        D3D12_SetDebugObjectName(d3dcmd_lists[i], *uid(ID3D12GraphicsCommandList_UUID), copy_string(tprint("d3d_cmd_lists_%", i)));
        if !ok {
            log_error("[D3D12] ID3D12Device_CreateCommandList failed!");
            command_encoder_fini(*cmd_encoder);
            return false;
        }
        ID3D12GraphicsCommandList_Close(d3dcmd_lists[i]);
    }

    ok = HR(ID3D12Device_CreateFence(d3ddevice, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_submit_fence));
    D3D12_SetDebugObjectName(d3d_submit_fence, *uid(ID3D12Fence_UUID), "d3d_submit_fence");
    if !ok {
        log_error("[D3D12] ID3D12Device_CreateFence failed!");
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
    if d3dcmd_allocator ID3D12CommandAllocator_Reset(d3dcmd_allocator);
    for i: 0..FRAME_COUNT - 1 {
        if d3dcmd_lists[i] IUnknown_Release(d3dcmd_lists[i]);
    }
    if d3dcmd_allocator IUnknown_Release(d3dcmd_allocator);
    if d3d_submit_fence  IUnknown_Release(d3d_submit_fence);
    if d3d_submit_event  CloseHandle(d3d_submit_event);
}

gfx_pipeline_init :: (device: *ID3D12Device, using pipeline: *Graphic_Pipeline, d3dinfo_queue: *ID3D12InfoQueue = null) -> bool {

    return true;
}

gfx_pipeline_fini :: (using gfx_pipeline: *Graphic_Pipeline) {
    if d3dpipeline_state IUnknown_Release(d3dpipeline_state);
    if d3droot_signature IUnknown_Release(d3droot_signature);
}

gfx_execute_commands :: (using gfx: *Graphics_Device, cmds: *D3D12CommandList, counts: u32 = 1) {
    
    lists: [MAX_SUBMIT_COMMANDLIST]*ID3D12CommandList;
    for i: 0..counts {
        lists[i] = cmds[i].cmdlist;
    }

    ID3D12CommandQueue_ExecuteCommandLists(d3d_queue, counts, xx *lists);
}

gfx_insert_signal_fence :: (using gfx: *Graphics_Device, type: Command_Type) {

    ID3D12CommandQueue_Signal(d3d_queue, fence.fence, fence.value);
    fence.state = .INSERTED;
}

gfx_wait_fence_increment :: (using gfx: *Graphics_Device, force: bool = false) {

    if fence.state == .INSERTED || force {
        if ID3D12Fence_GetCompletedValue(fence.fence) < fence.value {
            ID3D12Fence_SetEventOnCompletion(fence.fence, fence.value, fence.event);
            WaitForSingleObject(fence.event, INFINITE);
        }
        fence.value += 1;
        fence.state = .FINISHED;
    }
}

gfx_wait_fence :: (using gfx: *Graphics_Device, force: bool = false) {

    if fence.state == .INSERTED || force {
        if ID3D12Fence_GetCompletedValue(fence.fence) < fence.value {
            ID3D12Fence_SetEventOnCompletion(fence.fence, fence.value, fence.event);
            WaitForSingleObject(fence.event, INFINITE);
        }
        fence.state = .FINISHED;
    }
}

gfx_begin :: (cmd: *ID3D12GraphicsCommandList, color: [3]float = .[0.0, 0.0, 0.0]) {

    // clear_color : [4]float = .[color[0], color[1], color[2], 1.0];
    // ID3D12GraphicsCommandList_ClearRenderTargetView(cmd, rtv_handle, *clear_color, 0, null);
    // ID3D12GraphicsCommandList_DrawIndexedInstanced(cmd, 3, 1, 0, 0);
}

gfx_present :: (using engine: *Engine) {

    ok: bool;
    if VSYNC {
        ok = HR(IDXGISwapChain_Present(xx d3dswapchain, 1, 0));
    } else {
        ok = HR(IDXGISwapChain_Present(xx d3dswapchain, 0, 0));
    }
    #if DEBUG assert(ok, "IDXGISwapChain_Present failed");

    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(d3dswapchain);
}

gfx_update_window :: (using engine: *Engine) {

    x, y, _width, _height, success := Window.get_dimensions(hwnd, false);
    if !success {
        log_error("windows get_dimensions failed!");
    }

    width  = xx _width;
    height = xx _height;

    backend_queue_wait_for_idle(*gfx);

    backend_framebuffer_fini(*gfx);
    backend_swapchain_init(*gfx, hwnd, width, height);
    backend_framebuffer_init(*gfx, width, height);
}

make_descriptor_heap :: (d3ddevice: *ID3D12Device, d3dcbv_heap: *ID3D12DescriptorHeap) -> bool {
    cbv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
    cbv_heap_desc.Type = .CBV_SRV_UAV;
    cbv_heap_desc.NumDescriptors = 1;
    cbv_heap_desc.Flags = .SHADER_VISIBLE;
    cbv_heap_desc.NodeMask = 0;

    return HR(ID3D12Device_CreateDescriptorHeap(d3ddevice, *cbv_heap_desc, *uid(ID3D12DescriptorHeap_UUID), xx *d3dcbv_heap));
}

make_upload_buffer :: (using upload_buffer: *Upload_Buffer, count: u32 = 1) -> bool {

    if is_constant_buffer element_bytesize = calc_constant_buffer_byte_size(size_of(upload_buffer.T));

    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type = .UPLOAD;
    heap_properties.CPUPageProperty = .UNKNOWN;
    heap_properties.MemoryPoolPreference = .UNKNOWN;
    heap_properties.CreationNodeMask = 1;
    heap_properties.VisibleNodeMask  = 1;

    resource_desc: D3D12_RESOURCE_DESC;
    resource_desc.Dimension =       .BUFFER;
    resource_desc.Alignment =       0;
    resource_desc.Width =           xx (count * element_bytesize);
    resource_desc.Height =          1;
    resource_desc.DepthOrArraySize =1;
    resource_desc.MipLevels =       1;
    resource_desc.Format =          .UNKNOWN;
    resource_desc.SampleDesc.Count= 1;
    resource_desc.SampleDesc.Quality= 0;
    resource_desc.Layout =          .ROW_MAJOR;
    resource_desc.Flags =           .NONE;

    ok := HR(ID3D12Device_CreateCommittedResource(d3ddevice, *heap_properties, .NONE, *resource_desc, .GENERIC_READ, null, *uid(ID3D12Resource), *buffer));
    return SUCCEEDED(result);
}

destroy_upload_buffer :: (using upload_buffer: *Upload_Buffer) {
    // todo
}