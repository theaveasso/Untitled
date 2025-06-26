Engine :: struct {
    screen_width, screen_height : u32;

    is_paused      : bool;
    is_minimized   : bool;
    is_maximized   : bool;
    is_resizing    : bool;

    enable\_4x_msaa : bool;
    quality_4x_msaa : u32;


    hwnd     : Window_Type;
    renderer : Graphics_Device;

    rasterizer_state : *ID3D11RasterizerState;

    vertex_shader : *ID3D11VertexShader;
    pixel\_shader : *ID3D11PixelShader;
    vertex_layout : *ID3D11InputLayout;
    vertex_buffer : *ID3D11Buffer;
    index\_buffer : *ID3D11Buffer;
    constant_buffer:*ID3D11Buffer;

    vertices_count : u32;
    indices\_count : u32;
}

Vertex_Pos_Color :: struct {
    pos     : Vector3;
    color   : Vector4;
}

Constant_Buffer :: struct {
    model   : Matrix4;
    view    : Matrix4;
    proj    : Matrix4;
}

engine_init    :: (using engine : *Engine) -> bool {
    success := false;

    hwnd = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb=.[0, 0, 0]);
    success = hwnd != null;

    enable_4x_msaa = true;
    success = graphics_device_init(*renderer, hwnd, enable_4x_msaa, *quality_4x_msaa);
    success = engine_effect_init(engine);
    success = engine_resource_init(engine);

    raster_desc : D3D11_RASTERIZER_DESC;
    raster_desc.FillMode = .SOLID;
    raster_desc.CullMode = .NONE;
    raster_desc.FrontCounterClockwise = 0;

    ID3D11Device_CreateRasterizerState(renderer.d3d_device, *raster_desc, *rasterizer_state);
    ID3D11DeviceContext_RSSetState(renderer.d3d_context, rasterizer_state);

    return success;
}

engine_effect_init :: (using engine : *Engine) -> bool {
    vs := compile_shader(SHADER_TEXT, "VS", "vs_5_0");
    defer free(vs);
    assert(vs.data != null);
    HR(ID3D11Device_CreateVertexShader(renderer.d3d_device, vs.data, cast(u64) vs.count, null, *vertex_shader));

    layout : [2]D3D11_INPUT_ELEMENT_DESC = .[
        .{"POSITION", 0, .R32G32B32_FLOAT, 0, 0, .VERTEX_DATA, 0},
        .{"COLOR", 0, .R32G32B32A32_FLOAT, 0, 12, .VERTEX_DATA, 0},
    ];

    HR(ID3D11Device_CreateInputLayout(renderer.d3d_device, layout.data, cast(u32) layout.count, vs.data, cast(u64) vs.count, *vertex_layout));
    ID3D11DeviceContext_IASetInputLayout(renderer.d3d_context, vertex_layout);

    ps := compile_shader(SHADER_TEXT, "PS", "ps_5_0");
    defer free(vs);
    assert(ps.data != null);
    HR(ID3D11Device_CreatePixelShader(renderer.d3d_device, ps.data, cast(u64) ps.count, null, *pixel_shader));

    return true;
}

engine_resource_init :: (using engine : *Engine) -> bool {
    vertices_quad : [4]Vertex_Pos_Color = .[
        // // Triangle 1
        // .{pos = .{-0.5,  0.5, 0.5}, color = .{1.0, 0.0, 0.0, 1.0}}, // Top-left
        // .{pos = .{ 0.5, -0.5, 0.5}, color = .{0.0, 1.0, 0.0, 1.0}}, // Bottom-right
        // .{pos = .{-0.5, -0.5, 0.5}, color = .{0.0, 0.0, 1.0, 1.0}}, // Bottom-left

        // // Triangle 2
        // .{pos = .{-0.5,  0.5, 0.5}, color = .{1.0, 0.0, 0.0, 1.0}}, // Top-left
        // .{pos = .{ 0.5,  0.5, 0.5}, color = .{1.0, 1.0, 0.0, 1.0}}, // Top-right
        // .{pos = .{ 0.5, -0.5, 0.5}, color = .{0.0, 1.0, 0.0, 1.0}}, // Bottom-right

        .{pos = .{-0.5,  0.5, 0.0}, color = .{1, 0, 0, 1}}, // Top-left     
        .{pos = .{ 0.5,  0.5, 0.0}, color = .{0, 1, 0, 1}}, // Top-right    
        .{pos = .{ 0.5, -0.5, 0.0}, color = .{0, 0, 1, 1}}, // Bottom-right 
        .{pos = .{-0.5, -0.5, 0.0}, color = .{1, 1, 0, 1}}, // Bottom-left  
    ];
    indices_quad : [6]u32 = .[0, 1, 2, 0, 2, 3];

    //    5________ 6
    //    /|      /|
    //   /_|_____/ |
    //  1|4|_ _ 2|_|7
    //   | /     | /
    //   |/______|/
    //  0       3
    vertices_box : [8]Vertex_Pos_Color = .[
        // Front face
        .{pos = .{-1, -1, -1}, color = .{0, 1, 1, 1}},
        .{pos = .{-1,  1, -1}, color = .{0, 1, 0, 1}},
        .{pos = .{ 1,  1, -1}, color = .{0, 0, 1, 1}},
        .{pos = .{ 1, -1, -1}, color = .{1, 1, 0, 1}},
        // Back fac1
        .{pos = .{-1, -1,  1}, color = .{1, 1, 0, 1}},
        .{pos = .{-1,  1,  1}, color = .{0, 1, 1, 1}},
        .{pos = .{ 1,  1,  1}, color = .{1, 0, 0, 1}},
        .{pos = .{ 1, -1,  1}, color = .{0, 1, 1, 1}},
    ];

    indices_box: [36]u32 = .[
        // Front face
        0, 1, 2, 2, 3, 0,
        // Back face
        7, 6, 5, 5, 4, 7,
        // Left face
        4, 5, 1, 1, 0, 4,
        // Right face
        3, 2, 6, 6, 7, 3,
        // Top face
        1, 5, 6, 6, 2, 1,
        // Bottom face
        4, 0, 3, 3, 7, 4,
    ];

    vertices_count = vertices_box.count;
    indices\_count = indices_box.count;

    vbd : D3D11_BUFFER_DESC;
    vbd.Usage = .IMMUTABLE;
    vbd.ByteWidth = size_of(Vertex_Pos_Color) * vertices_count;
    vbd.BindFlags = .VERTEX_BUFFER;
    vbd.CPUAccessFlags = 0;

    vid : D3D11_SUBRESOURCE_DATA;
    vid.pSysMem = vertices_box.data;
    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *vbd, *vid, *vertex_buffer));

    ibd : D3D11_BUFFER_DESC;
    ibd.Usage = .DEFAULT;
    ibd.ByteWidth = size_of(u32) * indices_count;
    ibd.BindFlags = .INDEX_BUFFER;
    ibd.CPUAccessFlags = 0;

    iid : D3D11_SUBRESOURCE_DATA;
    iid.pSysMem = indices_box.data;
    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *ibd, *iid, *index_buffer));

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DYNAMIC;
    cbd.ByteWidth = size_of(Constant_Buffer);
    cbd.BindFlags = .CONSTANT_BUFFER;
    cbd.CPUAccessFlags = .WRITE;
    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *cbd, null, *constant_buffer));

    stride : u32 = size_of(Vertex_Pos_Color);
    offset : u32 = 0; 

    ID3D11DeviceContext_IASetVertexBuffers(renderer.d3d_context, 0, 1, *vertex_buffer, *stride, *offset);
    ID3D11DeviceContext_IASetIndexBuffer(renderer.d3d_context, index_buffer, .R32_UINT, 0);
    ID3D11DeviceContext_IASetPrimitiveTopology(renderer.d3d_context, .TRIANGLELIST);

    ID3D11DeviceContext_VSSetShader(renderer.d3d_context, g_engine.vertex_shader, null, 0);
    ID3D11DeviceContext_VSSetConstantBuffers(renderer.d3d_context, 0, 1, *constant_buffer);

    ID3D11DeviceContext_PSSetShader(renderer.d3d_context, g_engine.pixel_shader, null, 0);

    return true;
}

phi, theta := 0.0;

engine_update  :: () {
    phi += 0.0001;
    theta += 0.00015;

    rotation, yaw, pitch : Quaternion;

    set_from_axis_and_angle(*yaw, .{1, 0, 0}, phi);
    set_from_axis_and_angle(*pitch, .{0, 1, 0}, phi);
    rotation = yaw * pitch;

    model := translate(Matrix4_Identity, .{0, 0, 5}) * rotation_matrix(Matrix4, rotation);
    view := make_look_at_matrix(.{0, 0, -5}, .{0, 0, 0}, .{0, 1, 0}, false);
    proj := make_projection_matrix(25 * PI / 180.0, xx ASPECT, 0.1, 1000);

    cb := Constant_Buffer.{model=transpose(model), view=transpose(view), proj=transpose(proj)};
    using g_engine.renderer;

    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, g_engine.constant_buffer, 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *cb, size_of(Constant_Buffer));
    ID3D11DeviceContext_Unmap(d3d_context, g_engine.constant_buffer, 0);

    renderer_clear(*g_engine.renderer);

    ID3D11DeviceContext_DrawIndexed(d3d_context, g_engine.indices_count, 0, 0);

    renderer_present(*g_engine.renderer);
}

engine_draw2d  :: (engine : *Engine) {
}

engine_draw3d  :: () {
}

engine_postupdate :: () {
}
