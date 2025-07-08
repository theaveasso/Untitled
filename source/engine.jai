Engine :: struct {
    width:  u32 = 800;
    height: u32 = 600;

    should_quit : bool;

    hwnd:   HWND;

    using gfx: Graphics_Device;
    using cmd_encoder: Command_Encoder;

    cmdlist:      D3D12CommandList;
    cmdallocator: D3D12CommandAllocator;

    pipeline: D3D12Pipeline;

    gfx_pipeline: Graphic_Pipeline;

    vertex_buffer_view: D3D12_VERTEX_BUFFER_VIEW;
    index\_buffer_view: D3D12_INDEX_BUFFER_VIEW;

    vertex\ _buffer: Buffer;
    index\  _buffer: Buffer;
    constant_buffer: Buffer;

    texture: D3D12Texture;
    sampler: D3D12Sampler;

    geometry_box: Mesh_Geometry;
    cbuffer_object: Upload_Buffer(Matrix4);

    heap_cbvsrv:  D3D12Descriptor_Heap;
    heap_sampler: D3D12Descriptor_Heap;

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

    if !d3d12_cmd_allocator_init(gfx.d3ddevice, *cmdallocator, .GRAPHICS) {
        log_error("d3d12_cmd_allocator_init failed!");
        return false;
    }

    cmdlist.allocator = *cmdallocator;
    if !d3d12_cmd_list_init(gfx.d3ddevice, *cmdlist) {
        log_error("d3d12_cmdlist_init falied!");
        return false;
    }

    if !gfx_pipeline_init(gfx.d3ddevice, *gfx_pipeline, d3dinfo_queue) {
        log_error("graphic pipeline init failed!");
        return false;
    }

    if !d3d12_descriptor_heap_init(gfx.d3ddevice, *heap_cbvsrv) return false;
    if !d3d12_descriptor_heap_init(gfx.d3ddevice, *heap_sampler, .SAMPLER) return false;

    if !buffer_create_vertex_buffer(*gfx, *vertex_buffer, 4 * 4 * size_of(float), 4 * size_of(float)) return false;

    if !buffer_create_index_buffer(*gfx, *index_buffer, 6 * size_of(u32)) return false;
    if !buffer_create_constant_buffer(*gfx, *constant_buffer, *heap_cbvsrv, size_of(float)) return false;

    sampler = D3D12_SAMPLER_INIT();
    make_d3d12_sampler(*gfx._d3ddevice, *sampler, *heap_sampler);

    effect_init  (engine);
    resource_init(engine);

    return true;
} 

effect_init   :: (using engine: *Engine) -> bool {

    array_resize(*pipeline.root_signature.parameters, 2);

    pipeline.root_signature.parameters[0].type       = .SRV;
    pipeline.root_signature.parameters[0].bind_slot  = 0;
    pipeline.root_signature.parameters[0].res_counts = 1;
    pipeline.root_signature.parameters[0].resource   = *texture;
    pipeline.root_signature.parameters[0].visibility = .PIXEL;

    pipeline.root_signature.parameters[1].type       = .SAMPLER;
    pipeline.root_signature.parameters[1].bind_slot  = 0;
    pipeline.root_signature.parameters[1].res_counts = 1;
    pipeline.root_signature.parameters[1].sampler    = *sampler;
    pipeline.root_signature.parameters[1].visibility = .PIXEL;

    d3d12_root_signature_init(gfx.d3ddevice, *pipeline.root_signature, gfx.d3dinfo_queue);

    vs_shader: D3D12Shader = .{type=.VS};
    ps_shader: D3D12Shader = .{type=.PS};

    vs_success := compile_d3d_shader(*vs_shader, TRIANGLE_SHADER_TEXT, "VSMain");
    ps_success := compile_d3d_shader(*ps_shader, TRIANGLE_SHADER_TEXT, "PSMain");

    shader_set: Shader_Set;
    table_add(*shader_set.shaders, "VS", vs_shader);
    table_add(*shader_set.shaders, "PS", ps_shader);

    blend\      _state := D3D12Blend_State.{state=D3D12_BLEND_DESC_INIT()};
    rasterizer\ _state := D3D12Rasterizer_State.{state=D3D12_RASTERIZER_DESC_INIT()};
    depthstencil_state := D3D12Depth_Stencil_State.{state=D3D12_DEPTH_STENCIL_DESC_INIT()};
    rt_format          := D3D12_RENDER_TARGET_FORMAT_INIT();

    ok := make_d3d12_graphics_pipeline(gfx.d3ddevice, *pipeline, *rasterizer_state, *blend_state, *rt_format, *depthstencil_state, *shader_set, .NONE_SPLIT, infoqueue=gfx.d3dinfo_queue);
    return ok;
}

resource_init :: (using engine: *Engine) {

    vertices_triangle : []float = .[
        -0.25,  0.25, 0.0, 0.0,
         0.25,  0.25, 1.0, 1.0,
         0.25, -0.25, 1.0, 1.0,
        -0.25, -0.25, 0.0, 1.0,
    ];
    indices_triangle : []u32 = .[0, 1, 2, 0, 2, 3];

    d3d12_cmd_list_resource_transition(*cmdlist, *vertex_buffer, .COPY_DEST);
    d3d12_cmd_list_resource_transition(*cmdlist, *index_buffer, .COPY_DEST, true);

    d3d12_cmd_list_update_buffer_data(*cmdlist, *vertex_buffer, vertices_triangle.data, xx (4 * 4 * size_of(float)));
    d3d12_cmd_list_update_buffer_data(*cmdlist, *index_buffer, indices_triangle.data, xx (6 * size_of(u32)));

    d3d12_cmd_list_resource_transition(*cmdlist, *vertex_buffer, .VERTEX_AND_CONSTANT_BUFFER);
    d3d12_cmd_list_resource_transition(*cmdlist, *index_buffer, .INDEX_BUFFER, true);

    d3d12_cmd_list_close(*cmdlist, gfx.d3dinfo_queue);
    gfx_execute_commands(*gfx, *cmdlist);
    gfx_insert_signal_fence(*gfx, .GRAPHICS);
    gfx_wait_fence_increment(*gfx);
}

resource_fini :: (using engine: *Engine) {

    d3d12_descriptor_heap_fini(*heap_cbvsrv);
    d3d12_descriptor_heap_fini(*heap_sampler);

    buffer_fini(*vertex_buffer);
    buffer_fini(*index_buffer);
    buffer_fini(*constant_buffer);

    mesh_geometry_fini(*geometry_box);
}

engine_fini :: (using engine: *Engine) {
    wait_for_idle(*gfx);

    resource_fini(engine);

    d3d12_cmd_allocator_release(*cmdallocator);
    d3d12_cmd_list_release(*cmdlist);

    command_encoder_fini(*cmd_encoder);
    gfx_pipeline_fini(*gfx_pipeline);
    render_context_fini(engine);
    backend_device_fini(engine);
    backend_fini(engine);
}

engine_update :: (using engine: *Engine) {

    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(gfx.d3dswapchain);

    d3d12_cmd_list_reset_w_allocator(*cmdlist, *pipeline, gfx.d3dinfo_queue);

    dhs: [2]*ID3D12DescriptorHeap;
    dhs[0] = heap_cbvsrv.heap;
    dhs[1] = heap_sampler.heap;
    d3d12_cmd_list_bind_heap(*cmdlist, dhs.data, xx dhs.count);
    d3d12_cmd_list_bind_graphics_root_signature(*cmdlist, *pipeline.root_signature);

    d3d12_cmd_list_set_viewport(*cmdlist, *viewport);
    d3d12_cmd_list_set_scissor(*cmdlist, *surface_size);

    d3d12_cmd_list_swapchain_buffer_transition(*cmdlist, *gfx.swapchain_rtvs[ctx_active_buffer_index], .RENDER_TARGET, true);
    d3d12_cmd_list_bind_rt(*cmdlist, *gfx.swapchain_rtvs[ctx_active_buffer_index]);

    clear_color: [4]float = .[0.0, 0.2, 0.4, 1.0];
    d3d12_cmd_list_clear_rtv(*cmdlist, *gfx.swapchain_rtvs[ctx_active_buffer_index], *clear_color);

    d3d12_cmd_list_set_topology(*cmdlist, .TRIANGLELIST);

    d3d12_cmd_list_bind_vbuffer(*cmdlist, *vertex_buffer);
    d3d12_cmd_list_bind_ibuffer(*cmdlist, *index_buffer);

    d3d12_cmd_list_draw_index_instanced(*cmdlist, 6, 1, 0, 0);
    d3d12_cmd_list_swapchain_buffer_transition(*cmdlist, *gfx.swapchain_rtvs[ctx_active_buffer_index], .PRESENT, true);

    d3d12_cmd_list_close(*cmdlist, gfx.d3dinfo_queue);
    gfx_execute_commands(*gfx, *cmdlist);

    gfx_present(engine);

    gfx_insert_signal_fence(*gfx, .GRAPHICS);
    gfx_wait_fence_increment(*gfx);
    // {
    //     wait_value: u64;
    //     if submit_counter < FRAME_COUNT {
    //         wait_value = 0;
    //     } else {
    //         wait_value = (submit_counter - FRAME_COUNT) + 1;
    //     }

    //     if ID3D12Fence_GetCompletedValue(cmd_encoder.d3d_submit_fence) < wait_value {
    //         ID3D12Fence_SetEventOnCompletion(cmd_encoder.d3d_submit_fence, wait_value, cmd_encoder.d3d_submit_event);
    //         WaitForSingleObject(cmd_encoder.d3d_submit_event, 0xffff_ffff);
    //     }
    // }

    // ok: bool;
    // cmd_list := cmd_encoder.d3dcmd_lists[active_frame_index];

    // HR(ID3D12CommandAllocator_Reset(d3dcmd_allocator));
    // HR(ID3D12GraphicsCommandList_Reset(cmd_list, cmd_encoder.d3dcmd_allocator, gfx_pipeline.d3dpipeline_state));

    // ID3D12GraphicsCommandList_SetGraphicsRootSignature(cmd_list, gfx_pipeline.d3droot_signature);
    // ID3D12GraphicsCommandList_IASetPrimitiveTopology(cmd_list, .TRIANGLELIST);

    // ID3D12GraphicsCommandList_RSSetViewports(cmd_list, 1, *viewport); 
    // ID3D12GraphicsCommandList_RSSetScissorRects(cmd_list, 1, *surface_size);

    // rt_barrier: D3D12_RESOURCE_BARRIER;
    // rt_barrier.Type                   = .TRANSITION;
    // rt_barrier.Flags                  = .NONE;
    // rt_barrier.Transition.pResource   = d3drtvs[ctx_active_buffer_index];
    // rt_barrier.Transition.StateBefore = .PRESENT;
    // rt_barrier.Transition.StateAfter  = .RENDER_TARGET;
    // rt_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    // ID3D12GraphicsCommandList_ResourceBarrier(cmd_list, 1, *rt_barrier);

    // rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(d3drtv_heap);
    // rtv_handle.ptr = rtv_handle.ptr + (ctx_active_buffer_index * d3d_rtv_heap_inc_size);
    // ID3D12GraphicsCommandList_OMSetRenderTargets(cmd_list, 1, *rtv_handle, .FALSE, null);

    // clear_color := float.[0.1, 0.2, 0.4, 1.0];
    // ID3D12GraphicsCommandList_ClearRenderTargetView(cmd_list, rtv_handle, *clear_color, 0, null);

    // // ID3D12GraphicsCommandList_IASetVertexBuffers(cmd_list, 0, 1, *mesh_geometry_get_vbv(*geometry_box));
    // // ID3D12GraphicsCommandList_IASetIndexBuffer(cmd_list, *mesh_geometry_get_ibv(*geometry_box));

    // submesh_box := table_find_pointer(*geometry_box.draw_args, "Box");
    // // ID3D12GraphicsCommandList_DrawIndexedInstanced(cmd_list, xx submesh_box.index_count, 1, 0, 0, 0);

    // // Indicate that the back buffer will be used to present. (end_renderpass)
    // present_barrier: D3D12_RESOURCE_BARRIER;
    // present_barrier.Type                   = .TRANSITION;
    // present_barrier.Flags                  = .NONE;
    // present_barrier.Transition.pResource   = d3drtvs[ctx_active_buffer_index];
    // present_barrier.Transition.StateBefore = .RENDER_TARGET;
    // present_barrier.Transition.StateAfter  = .PRESENT;
    // present_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    // ID3D12GraphicsCommandList_ResourceBarrier(cmd_list, 1, *present_barrier);

    // ok = HR(ID3D12GraphicsCommandList_Close(cmd_list));

    // submit_counter += 1;
    // ID3D12CommandQueue_ExecuteCommandLists(d3d_queue, 1, xx *cmd_encoder.d3dcmd_lists[active_frame_index]);
    // ID3D12CommandQueue_Signal(d3d_queue, cmd_encoder.d3d_submit_fence, submit_counter);

    // active_frame_index = (active_frame_index+1) % FRAME_COUNT;

}

wait_for_idle :: (gfx: *Graphics_Device) {
    backend_queue_wait_for_idle(gfx);
}

// make_box_geometry :: (using mesh: *Mesh_Geometry, d3ddevice: *ID3D12Device, cmdlist: *ID3D12GraphicsCommandList) -> bool {

//     vertices : [8]Immediate_Vertex = .[
//         .{position=.{-1.0, -1.0, -1.0}, color=.{1.0, 1.0, 1.0, 1.0}},
// 		.{position=.{-1.0, +1.0, -1.0}, color=.{1.0, 0.0, 0.0, 1.0}},
// 		.{position=.{+1.0, +1.0, -1.0}, color=.{0.0, 1.0, 0.0, 1.0}},
// 		.{position=.{+1.0, -1.0, -1.0}, color=.{0.0, 0.0, 1.0, 1.0}},
// 		.{position=.{-1.0, -1.0, +1.0}, color=.{0.0, 1.0, 1.0, 1.0}},
// 		.{position=.{-1.0, +1.0, +1.0}, color=.{1.0, 1.0, 0.0, 1.0}},
// 		.{position=.{+1.0, +1.0, +1.0}, color=.{1.0, 0.0, 1.0, 1.0}},
// 		.{position=.{+1.0, -1.0, +1.0}, color=.{0.0, 0.0, 0.0, 1.0}},
//     ];

//     indices : [36]u32 = .[
//         0,1,2, 0,2,3,
//         4,6,5, 4,7,6,
//         4,5,1, 4,1,0,
//         3,2,6, 3,6,7,
//         1,5,6, 1,6,2,
//         4,0,3, 4,3,7,
//     ];

//     vb_bytesize := vertices.count * size_of(Immediate_Vertex);
//     ib_bytesize := indices.count * size_of(u32);

//     mesh.name = "Box-Geometry";

//     ok := false;
//     ok = HR(D3DCreateBlob(xx vb_bytesize, *mesh.cpu_vertex_buffer));
//     if !ok {
//         #if ASSERT_ON_FAIL assert(ok, "make_box_geometry D3DCreateBlob failed");
//         log_error("make_box_geometry D3DCreateBlob failed");
//         return false;
//     }
//     memcpy(ID3D10Blob_GetBufferPointer(mesh.cpu_vertex_buffer), vertices.data, xx vertices.count);

//     ok = HR(D3DCreateBlob(xx ib_bytesize, *mesh.cpu_index_buffer));
//     if !ok {
//         #if ASSERT_ON_FAIL assert(ok, "make_box_geometry D3DCreateBlob failed");
//         log_error("make_box_geometry D3DCreateBlob failed");
//         return false;
//     }
//     memcpy(ID3D10Blob_GetBufferPointer(mesh.cpu_index_buffer), indices.data, xx indices.count);

//     mesh.gpu_vertex_buffer = make_default_buffer(d3ddevice, cmdlist, xx vertices.data, xx vertices.count, mesh.vertex_buffer_uploader);
//     mesh.gpu_index_buffer  = make_default_buffer(d3ddevice, cmdlist, xx indices.data, xx indices.count, mesh.index_buffer_uploader);

//     mesh.vertex_bytestride = size_of(Immediate_Vertex);
//     mesh.vertex_buffer_bytestride = xx vb_bytesize;
//     mesh.index_format = .R32_UINT;
//     mesh.index_buffer_bytestride = xx ib_bytesize;

//     submesh: Submesh_Geometry;
//     submesh.index_count = xx indices.count;
//     submesh.start_index_location = 0;
//     submesh.base_vertex_location = 0;

//     table_add(*mesh.draw_args, copy_string("Box"), submesh);

//     return true;
// }

// flush_command_queue :: (gfx: *Graphics_Device) {
// }
