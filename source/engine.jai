Engine :: struct {
    width:  u32 = 800;
    height: u32 = 600;

    should_quit : bool;

    hwnd:   HWND;

    renderer:     D3D12Renderer;
    cmdlist:      D3D12CommandList;
    cmdallocator: D3D12CommandAllocator;

    pipeline: D3D12Pipeline;

    vertex\ _buffer: D3D12Buffer;
    index\  _buffer: D3D12Buffer;
    constant_buffer: D3D12Buffer;

    texture: D3D12Texture;
    sampler: D3D12Sampler;
}

engine_init :: (using engine: *Engine) -> bool {
    hwnd = Window.create_window(width, height, "Hello Sailor");

    ok := d3d12_renderer_init(*renderer, hwnd);
    if !ok { 
        log_error("d3d12 renderer init failed!");
        return false; 
    }

    ok  = d3d12_swapchain_init(*renderer, hwnd, xx width, xx height); 
    if !ok {
        log_error("d3d12 swapchain init failed!");
        return false;
    }

    if !d3d12_cmd_allocator_init(*renderer._device, *cmdallocator, .GRAPHICS) {
        log_error("d3d12_cmd_allocator_init failed!");
        return false;
    }

    cmdlist.allocator = *cmdallocator;
    if !d3d12_cmd_list_init(*renderer._device, *cmdlist) {
        log_error("d3d12_cmdlist_init falied!");
        return false;
    }

    if !make_d3d12_vertex_buffer(*renderer._device, *vertex_buffer, 4 * 4 * size_of(float), 4 * size_of(float)) {
        log_error("make_d3d12_vertex_buffer falied!");
        return false;
    }
    if !make_d3d12_index_buffer(*renderer._device, *index_buffer, 6 * size_of(u32)) {
        log_error("make_d3d12_index_buffer failed!");
        return false;
    }
    if !make_d3d12_constant_buffer(*renderer._device, *constant_buffer, *renderer.heap_cbv_srv_uav, size_of(float)) {
        log_error("make_d3d12_constant_buffer failed!");
        return false;
    }

    sampler = D3D12_SAMPLER_INIT();
    make_d3d12_sampler(*renderer._device, *sampler, *renderer.heap_sampler);

    ok = engine_resource_init(engine);
    if !ok {
        log_error("engine resource init failed!");
        return false;
    }

    ok = effect_init(engine);
    if !ok {
        log_error("engine effect init failed!");
        return false;
    }

    return true;
} 

effect_init   :: (using engine: *Engine) -> bool {

    array_resize(*pipeline.root_signature.parameters, 2);

    pipeline.root_signature.parameters[0].type       = .SRV;
    pipeline.root_signature.parameters[0].bind_slot  = 0;
    pipeline.root_signature.parameters[0].res_counts = 1;
    pipeline.root_signature.parameters[0].resource   = *texture;
    pipeline.root_signature.parameters[0].is_table   = true;
    pipeline.root_signature.parameters[0].visibility = .PIXEL;

    pipeline.root_signature.parameters[1].type       = .SAMPLER;
    pipeline.root_signature.parameters[1].bind_slot  = 0;
    pipeline.root_signature.parameters[1].res_counts = 1;
    pipeline.root_signature.parameters[1].sampler    = *sampler;
    pipeline.root_signature.parameters[1].visibility = .PIXEL;

    d3d12_root_signature_init(*renderer._device, *pipeline.root_signature);

    vs_shader: D3D12Shader = .{type=.VS};
    ps_shader: D3D12Shader = .{type=.PS};

    vs_success := compile_d3d_shader(*vs_shader, TRIANGLE_SHADER_TEXT, "VSMain");
    ps_success := compile_d3d_shader(*ps_shader, TRIANGLE_SHADER_TEXT, "PSMain");

    shader_set: Shader_Set;
    table_add(*shader_set.shaders, "VS", vs_shader);
    table_add(*shader_set.shaders, "PS", ps_shader);

    blend\      _state := UTD3D12_BLEND_DESC_INIT();
    rasterizer\ _state := UTD3D12_RASTERIZER_DESC_INIT();
    depthstencil_state := UTD3D12_DEPTH_STENCIL_DESC_INIT();
    rt_format          := UTD3D12_RENDER_TARGET_FORMAT_INIT();

    ok := make_d3d12_graphics_pipeline(*renderer._device, *pipeline, *rasterizer_state, *blend_state, *rt_format, *depthstencil_state, *shader_set, .NONE_SPLIT);
    return ok;
}

engine_effect_fini :: (using engine: *Engine) {

    d3d12_pipeline_release(*pipeline);
}

engine_resource_init :: (using engine: *Engine) -> bool {

    start:= seconds_since_init();
    if !make_d3d12_texture(*renderer, *texture, .R8G8B8A8_UNORM, 256, 256) {
        log_error("make_d3d12_texture failed!");
        return false;
    }

    row_pitch  := texture.desc.Width * 4;
    cel_pitch  := row_pitch >> 3;
    cel_height := texture.desc.Width >> 3;
    texture_size := row_pitch * texture.desc.Height;

    texture_data := NewArray(xx texture_size, u8);
    index : u64 = 0;
    while index < texture_size {
        x := index % texture.desc.Width;
        y := index / texture.desc.Width;
        i := x / cel_pitch; 
        j := y / cel_height;

        if i % 2 == j % 2 {
            texture_data[index]     = 0x00;
            texture_data[index + 1] = 0x00;
            texture_data[index + 2] = 0x00;
            texture_data[index + 3] = 0xff;
        } else {
            texture_data[index]     = 0xff;
            texture_data[index + 1] = 0xff;
            texture_data[index + 2] = 0xff;
            texture_data[index + 3] = 0xff;
        }

        index += 4;
    }

    vertices_triangle : []float = .[
        -0.5,  0.5, 0.0, 0.0,
         0.5,  0.5, 1.0, 0.0,
         0.5, -0.5, 1.0, 1.0,
        -0.5, -0.5, 0.0, 1.0,
    ];
    indices_triangle : []u32 = .[0, 1, 2, 0, 2, 3];

    d3d12_cmd_list_resource_transition(*cmdlist, *vertex_buffer, .COPY_DEST);
    d3d12_cmd_list_resource_transition(*cmdlist, *texture,       .COPY_DEST);
    d3d12_cmd_list_resource_transition(*cmdlist, *index_buffer,  .COPY_DEST, true);

    d3d12_cmd_list_update_buffer\_data(*cmdlist, *vertex_buffer, vertices_triangle.data, xx (4 * 4 * size_of(float)));
    d3d12_cmd_list_update_texture_data(*cmdlist, *texture, texture_data.data);
    d3d12_cmd_list_update_buffer\_data(*cmdlist, *index_buffer, indices_triangle.data, xx (6 * size_of(u32)));

    d3d12_cmd_list_resource_transition(*cmdlist, *vertex_buffer, .VERTEX_AND_CONSTANT_BUFFER);
    d3d12_cmd_list_resource_transition(*cmdlist, *texture,       .PIXEL_SHADER_RESOURCE);
    d3d12_cmd_list_resource_transition(*cmdlist, *index_buffer,  .INDEX_BUFFER, true);

    d3d12_cmd_list_close(*cmdlist);
    gfx_execute_commands(*renderer, *cmdlist);
    gfx_insert_signal_fence(*renderer, .GRAPHICS);
    gfx_wait_fence_increment(*renderer);

    print("--- resource init took % \n", seconds_since_init() - start);

    return true;
}

engine_resource_fini :: (using engine: *Engine) {

    d3d12_texture_release(*texture);

    d3d12_buffer_release(*vertex_buffer);
    d3d12_buffer_release(*index_buffer);
    d3d12_buffer_release(*constant_buffer);
}

engine_fini :: (using engine: *Engine) {
    
    engine_effect_fini(engine);
    engine_resource_fini(engine);

    d3d12_cmd_allocator_release(*cmdallocator);
    d3d12_cmd_list_release(*cmdlist);

    d3d12_swapchain_release(*renderer);
    d3d12_renderer_release(*renderer);
}

engine_update :: (using engine: *Engine) {

    using renderer;
    ctx_active_buffer_index = IDXGISwapChain3_GetCurrentBackBufferIndex(renderer.swapchain);
    d3d12_cmd_list_reset_w_allocator(*cmdlist, *pipeline);

    dhs: [2]*ID3D12DescriptorHeap;
    dhs[0] = renderer.heap_cbv_srv_uav.heap;
    dhs[1] = renderer.heap_sampler.heap;
    d3d12_cmd_list_bind_heap(*cmdlist, dhs.data, xx dhs.count);
    d3d12_cmd_list_bind_graphics_root_signature(*cmdlist, *pipeline.root_signature);

    d3d12_cmd_list_set_viewport(*cmdlist, *renderer.viewport);
    d3d12_cmd_list_set_scissor(*cmdlist, *renderer.surface_size);

    d3d12_cmd_list_swapchain_buffer_transition(*cmdlist, *renderer.swapchain_rtvs[ctx_active_buffer_index], .RENDER_TARGET, true);
    d3d12_cmd_list_bind_rt(*cmdlist, *renderer.swapchain_rtvs[ctx_active_buffer_index]);

    clear_color: [4]float = .[0.0, 0.2, 0.4, 1.0];
    d3d12_cmd_list_clear_rtv(*cmdlist, *renderer.swapchain_rtvs[ctx_active_buffer_index], *clear_color);

    d3d12_cmd_list_set_topology(*cmdlist, .TRIANGLELIST);

    d3d12_cmd_list_bind_vbuffer(*cmdlist, *vertex_buffer);
    d3d12_cmd_list_bind_ibuffer(*cmdlist, *index_buffer);

    d3d12_cmd_list_draw_index_instanced(*cmdlist, 6, 1, 0, 0);
    d3d12_cmd_list_swapchain_buffer_transition(*cmdlist, *renderer.swapchain_rtvs[ctx_active_buffer_index], .PRESENT, true);

    d3d12_cmd_list_close(*cmdlist,);
    gfx_execute_commands(*renderer, *cmdlist);

    gfx_present(*renderer);

    gfx_insert_signal_fence(*renderer, .GRAPHICS);
    gfx_wait_fence_increment(*renderer);
}