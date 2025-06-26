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

    vertex_shader : *ID3D11VertexShader;
    pixel\_shader : *ID3D11PixelShader;
    vertex_layout : *ID3D11InputLayout;
    vertex_buffer : *ID3D11Buffer;
}

Vertex_Pos_Color :: struct {
    pos     : Vector3;
    color   : Vector4;
}

engine_init    :: (using engine : *Engine) -> bool {
    success := false;

    hwnd = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb=.[0, 0, 0]);
    success = hwnd != null;

    enable_4x_msaa = true;
    success = graphics_device_init(*renderer, hwnd, enable_4x_msaa, *quality_4x_msaa);
    success = engine_effect_init(engine);
    success = engine_resource_init(engine);

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
    vertices : [3]Vertex_Pos_Color = .[
        .{pos=.{0.0, 0.5, 0.5}, color=.{0.0, 1.0, 0.0, 1.0}},
        .{pos=.{0.5, -0.5, 0.5}, color=.{0.0, 0.0, 1.0, 1.0}},
        .{pos=.{-0.5, -0.5, 0.5}, color=.{1.0, 0.0, 0.0, 1.0}},
    ];

    bd : D3D11_BUFFER_DESC;
    bd.Usage = .DEFAULT;
    bd.ByteWidth = size_of(Vertex_Pos_Color) * 3;
    bd.BindFlags = .VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;

    id : D3D11_SUBRESOURCE_DATA;
    id.pSysMem = vertices.data;

    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *bd, *id, *vertex_buffer));

    stride : u32 = size_of(Vertex_Pos_Color);
    offset : u32 = 0; 

    ID3D11DeviceContext_IASetVertexBuffers(renderer.d3d_context, 0, 1, *vertex_buffer, *stride, *offset);
    ID3D11DeviceContext_IASetPrimitiveTopology(renderer.d3d_context, .TRIANGLELIST);

    return true;
}

engine_update  :: () {
    renderer_clear(*g_engine.renderer);

    using g_engine.renderer;
    ID3D11DeviceContext_VSSetShader(d3d_context, g_engine.vertex_shader, null, 0);
    ID3D11DeviceContext_PSSetShader(d3d_context, g_engine.pixel_shader, null, 0);
    ID3D11DeviceContext_Draw(d3d_context, 3, 0);

    renderer_present(*g_engine.renderer);
}

engine_draw2d  :: (engine : *Engine) {
}

engine_draw3d  :: () {
}

engine_postupdate :: () {
}
