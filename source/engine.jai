Engine :: struct {
    width:  u32 = 800;
    height: u32 = 600;

    should_quit : bool;

    hwnd:   HWND;

    d3d_factory: *IDXGIFactory4;
    d3d_adapter: *IDXGIAdapter1;
    using gfx: Graphics_Device;
    using cmd_encoder: Command_Encoder;

    gfx_pipeline: Graphic_Pipeline;

    active_frame_index: u32;
    submit_counter: u64;
}

engine_init :: (using engine: *Engine) -> bool {
    hwnd = Window.create_window(width, height, "Hello Sailor");

    if !backend_init(engine) {
        log_error("backend init failed!");
        return false;
    }

    if !backend_device_init(engine) {
        log_error("backend device init failed!");
        return false;
    }

    if !render_context_init(engine) {
        log_error("render context init failed!");
        return false;
    }

    if !command_encoder_init(engine) {
        log_error("backend command encoder init faild!");
        return false;
    }

    if !gfx_pipeline_init(gfx.d3d_device, *gfx_pipeline) {
        log_error("graphic pipeline init failed!");
        return false;
    }

    return true;
} 

engine_fini :: (using engine: *Engine) {
    wait_for_idle(*gfx);

    command_encoder_fini(*cmd_encoder);
    gfx_pipeline_fini(*gfx_pipeline);
    render_context_fini(engine);
    backend_device_fini(engine);
    backend_fini(engine);
}

engine_update :: (using engine: *Engine) {
    {
        wait_value: u64;
        if submit_counter < FRAME_COUNT {
            wait_value = 0;
        } else {
            wait_value = (submit_counter - FRAME_COUNT) + 1;
        }

        if ID3D12Fence_GetCompletedValue(cmd_encoder.d3d_submit_fence) < wait_value {
            ID3D12Fence_SetEventOnCompletion(cmd_encoder.d3d_submit_fence, wait_value, cmd_encoder.d3d_submit_event);
            WaitForSingleObject(cmd_encoder.d3d_submit_event, 0xffff_ffff);
        }
    }

    result: HRESULT;
    cmd_list := cmd_encoder.d3d_cmd_lists[active_frame_index];

    result = HR(ID3D12GraphicsCommandList_Reset(cmd_list, cmd_encoder.d3d_cmd_allocator, gfx_pipeline.d3d_pipeline_state));

    ID3D12GraphicsCommandList_SetGraphicsRootSignature(cmd_list, gfx_pipeline.d3d_root_signature);
    ID3D12GraphicsCommandList_IASetPrimitiveTopology(cmd_list, .TRIANGLELIST);

    viewport: D3D12_VIEWPORT;
    viewport.TopLeftX = 0.0;
    viewport.TopLeftY = 0.0;
    viewport.Width    = xx width;
    viewport.Height   = xx height;
    viewport.MinDepth = 0.0;
    viewport.MaxDepth = 1.0; 
    ID3D12GraphicsCommandList_RSSetViewports(cmd_list, 1, *viewport); 

    surface_size: D3D12_RECT;
    surface_size.left = 0;
    surface_size.top  =  0;
    surface_size.right = xx width;
    surface_size.bottom = xx height;
    ID3D12GraphicsCommandList_RSSetScissorRects(cmd_list, 1, *surface_size);

    rt_barrier: D3D12_RESOURCE_BARRIER;
    rt_barrier.Type                   = .TRANSITION;
    rt_barrier.Flags                  = .NONE;
    rt_barrier.Transition.pResource   = d3d_rtvs[ctx_active_buffer_index];
    rt_barrier.Transition.StateBefore = .PRESENT;
    rt_barrier.Transition.StateAfter  = .RENDER_TARGET;
    rt_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(cmd_list, 1, *rt_barrier);

    rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(d3d_rtv_heap);
    rtv_handle.ptr = rtv_handle.ptr + (ctx_active_buffer_index * d3d_rtv_heap_inc_size);
    ID3D12GraphicsCommandList_OMSetRenderTargets(cmd_list, 1, *rtv_handle, .FALSE, null);

    clear_color := float.[0.1, 0.2, 0.4, 1.0];
    ID3D12GraphicsCommandList_ClearRenderTargetView(cmd_list, rtv_handle, *clear_color, 0, null);

    ID3D12GraphicsCommandList_DrawInstanced(cmd_list, 3, 1, 0, 0);

    // Indicate that the back buffer will be used to present. (end_renderpass)
    present_barrier: D3D12_RESOURCE_BARRIER;
    present_barrier.Type                   = .TRANSITION;
    present_barrier.Flags                  = .NONE;
    present_barrier.Transition.pResource   = d3d_rtvs[ctx_active_buffer_index];
    present_barrier.Transition.StateBefore = .RENDER_TARGET;
    present_barrier.Transition.StateAfter  = .PRESENT;
    present_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(cmd_list, 1, *present_barrier);

    result = HR(ID3D12GraphicsCommandList_Close(cmd_list));

    submit_counter += 1;
    ID3D12CommandQueue_ExecuteCommandLists(d3d_queue, 1, xx *cmd_encoder.d3d_cmd_lists[active_frame_index]);
    ID3D12CommandQueue_Signal(d3d_queue, cmd_encoder.d3d_submit_fence, submit_counter);

    active_frame_index = (active_frame_index+1) % FRAME_COUNT;

    gfx_present(engine);
}

wait_for_idle :: (gfx: *Graphics_Device) {
    backend_queue_wait_for_idle(gfx);
}