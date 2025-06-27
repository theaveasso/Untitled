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
    constant_buffer: [2]*ID3D11Buffer;

    vertices_count : u32;
    indices\_count : u32;

    directional_light : Directional_Light; 
    point\     _light : Point_Light;
    spot\      _light : Spot_Light;  

    gpu_vertex_buffer : VS_Constant_Buffer;
    gpu_pixel\_buffer : PS_Constant_Buffer;
}

Immediate_Vertex :: struct {
    position:    Vector3;
    color_scale: Vector4;
    // uv0:         Vector2;
    // uv1:         Vector2;
    normal:      Vector3;
    // tangent:     Vector4;
}

immediate_vertex_input_layout : [3]D3D11_INPUT_ELEMENT_DESC;

Material :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;
    reflect : Vector4;
}

// Light
Directional_Light :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;
    direction:Vector3;
    pad     : float;
}

Point_Light :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;

    position: Vector3;
    range   : float; 

    att     : Vector3;
    pad     : float;
}

Spot_Light :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;

    position: Vector3;
    range   : float; 

    direction: Vector3;
    spot    : float;

    att     : Vector3;
    pad     : float;
}

VS_Constant_Buffer :: struct {
    model   : Matrix4;
    view    : Matrix4;
    proj    : Matrix4;
    world_inv: Matrix4;
}

PS_Constant_Buffer :: struct{
    directional_light : Directional_Light;
    point\     _light : Point_Light;
    spot\      _light : Spot_Light;

    material          : Material;

    eye_position      : Vector3;
    pad               : float;
}

engine_init    :: (using engine : *Engine) -> bool {
    success := false;

    // context._windows_windowproc = UntitledWindowProc;
    hwnd = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb=.[0, 0, 0]);
    success = hwnd != null;

    enable_4x_msaa = true;
    success = graphics_device_init(*renderer, hwnd, enable_4x_msaa, *quality_4x_msaa);
    success = imgui_init(hwnd, *renderer);
    success = engine_effect_init(engine);
    success = engine_resource_init(engine);

    raster_desc : D3D11_RASTERIZER_DESC;
    raster_desc.FillMode = .SOLID;
    raster_desc.CullMode = .NONE;
    raster_desc.FrontCounterClockwise = 0;
    raster_desc.DepthClipEnable = 1;

    ID3D11Device_CreateRasterizerState(renderer.d3d_device, *raster_desc, *rasterizer_state);
    ID3D11DeviceContext_RSSetState(renderer.d3d_context, rasterizer_state);

    return success;
}

engine_effect_init :: (using engine : *Engine) -> bool {
    vs := compile_shader(SHADER_TEXT, "VS", "vs_5_0");
    defer free(vs);
    assert(vs.data != null);
    HR(ID3D11Device_CreateVertexShader(renderer.d3d_device, vs.data, cast(u64) vs.count, null, *vertex_shader));

    immediate_vertex_input_layout = .[
        .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
        .{"COLOR",     0, .R32G32B32A32_FLOAT, 0, 12, .VERTEX_DATA, 0},
        // .{"TEXCOORD",  0, .R32G32_FLOAT,       0, 28, .VERTEX_DATA, 0},
        .{"NORMAL",    0, .R32G32B32_FLOAT,    0, 28, .VERTEX_DATA, 0},
        // .{"TANGENT",   0, .R32G32B32A32_FLOAT, 0, 48, .VERTEX_DATA, 0},
    ];

    HR(ID3D11Device_CreateInputLayout(renderer.d3d_device, immediate_vertex_input_layout.data, cast(u32) immediate_vertex_input_layout.count, vs.data, cast(u64) vs.count, *vertex_layout));
    ID3D11DeviceContext_IASetInputLayout(renderer.d3d_context, vertex_layout);

    ps := compile_shader(SHADER_TEXT, "PS", "ps_5_0");
    defer free(vs);
    assert(ps.data != null);
    HR(ID3D11Device_CreatePixelShader(renderer.d3d_device, ps.data, cast(u64) ps.count, null, *pixel_shader));

    return true;
}

engine_resource_init :: (using engine : *Engine) -> bool {
    vertices_quad : [4]Immediate_Vertex = .[
        // Triangle 1
        // .{pos = .{-0.5,  0.5, 0.5}, color = .{1.0, 0.0, 0.0, 1.0}}, // Top-left
        // .{pos = .{ 0.5, -0.5, 0.5}, color = .{0.0, 1.0, 0.0, 1.0}}, // Bottom-right
        // .{pos = .{-0.5, -0.5, 0.5}, color = .{0.0, 0.0, 1.0, 1.0}}, // Bottom-left

        // Triangle 2
        // .{pos = .{-0.5,  0.5, 0.5}, color = .{1.0, 0.0, 0.0, 1.0}}, // Top-left
        // .{pos = .{ 0.5,  0.5, 0.5}, color = .{1.0, 1.0, 0.0, 1.0}}, // Top-right
        // .{pos = .{ 0.5, -0.5, 0.5}, color = .{0.0, 1.0, 0.0, 1.0}}, // Bottom-right

        .{position = .{-0.5,  0.5, 0.0}, color_scale = .{1, 0, 0, 1}}, // Top-left     
        .{position = .{ 0.5,  0.5, 0.0}, color_scale = .{0, 1, 0, 1}}, // Top-right    
        .{position = .{ 0.5, -0.5, 0.0}, color_scale = .{0, 0, 1, 1}}, // Bottom-right 
        .{position = .{-0.5, -0.5, 0.0}, color_scale = .{1, 1, 0, 1}}, // Bottom-left  
    ];
    indices_quad : [6]u32 = .[0, 1, 2, 0, 2, 3];

    //    5________ 6
    //    /|      /|
    //   /_|_____/ |
    //  1|4|_ _ 2|_|7
    //   | /     | /
    //   |/______|/
    //  0       3
    vertices_box : [8]Immediate_Vertex = .[
        // Front face
        .{position = .{-1, -1, -1}, color_scale = .{0, 1, 1, 1}, normal = .{0, 0, -1}},
        .{position = .{-1,  1, -1}, color_scale = .{0, 1, 0, 1}, normal = .{0, 0, -1}},
        .{position = .{ 1,  1, -1}, color_scale = .{0, 0, 1, 1}, normal = .{0, 0, -1}},
        .{position = .{ 1, -1, -1}, color_scale = .{1, 1, 0, 1}, normal = .{0, 0, -1}},
        // Back fac1
        .{position = .{-1, -1,  1}, color_scale = .{1, 1, 0, 1}, normal = .{0, 0, 1}},
        .{position = .{-1,  1,  1}, color_scale = .{0, 1, 1, 1}, normal = .{0, 0, 1}},
        .{position = .{ 1,  1,  1}, color_scale = .{1, 0, 0, 1}, normal = .{0, 0, 1}},
        .{position = .{ 1, -1,  1}, color_scale = .{0, 1, 1, 1}, normal = .{0, 0, 1}},
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
    vbd.ByteWidth = size_of(Immediate_Vertex) * vertices_count;
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
    cbd.BindFlags = .CONSTANT_BUFFER;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size_of(VS_Constant_Buffer);
    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *cbd, null, *constant_buffer[0]));
    cbd.ByteWidth = size_of(PS_Constant_Buffer);
    HR(ID3D11Device_CreateBuffer(renderer.d3d_device, *cbd, null, *constant_buffer[1]));

    directional_light = .{
        ambient  =xyzw(0.2, 0.2, 0.2, 1.0),
        diffuse  =xyzw(0.8, 0.8, 0.8, 1.0),
        specular =xyzw(0.5, 0.5, 0.5, 1.0),
        direction=xyz(-0.577),
    };

    point_light = .{
        position=xyz (0.0, 0.0, -10.0),
        ambient =xyzw(0.3, 0.3, 0.3, 1.0),
        diffuse =xyzw(0.7, 0.7, 0.7, 1.0),
        specular=xyzw(0.5, 0.5, 0.5, 1.0),
        att     =xyz (0.0, 1.0, 0.0),
        range=25.0,
    }; 

    spot_light = .{
        position =xyz(0.0, 0.0, -5.0),
        direction=xyz(0.0, 0.0, 1.0),
        ambient  =xyzw(0.0, 0.0, 0.0, 1.0),
        diffuse  =xyzw(1.0),
        specular =xyzw(1.0),
        att      =xyz(0.0, 1.0, 0.0),
        range=25.0,
        spot =12.0,
    };

    gpu_pixel_buffer= .{
        directional_light=directional_light,
        point_light      =point_light,
        spot_light       =spot_light,
        material         = .{ambient =xyzw(0.5, 0.5, 0.5, 1.0), diffuse =xyzw(1.0), specular=xyzw(0.5, 0.5, 0.5, 1.0)},
        eye_position     = .{0.0, 0.0, -5.0},

    };

    stride : u32 = size_of(Immediate_Vertex);
    offset : u32 = 0; 

    view := make_look_at_matrix(.{0, 0, -5}, .{0, 0, 0}, .{0, 1, 0}, false);
    proj := make_projection_matrix(25 * PI / 180.0, xx ASPECT, 0.1, 1000);

    gpu_vertex_buffer= .{
        model = Matrix4_Identity,
        view  = view,
        proj  = proj,
        world_inv = Matrix4_Identity,
    };

    ID3D11DeviceContext_IASetVertexBuffers(renderer.d3d_context, 0, 1, *vertex_buffer, *stride, *offset);
    ID3D11DeviceContext_IASetIndexBuffer(renderer.d3d_context, index_buffer, .R32_UINT, 0);
    ID3D11DeviceContext_IASetPrimitiveTopology(renderer.d3d_context, .TRIANGLELIST);

    ID3D11DeviceContext_VSSetShader(renderer.d3d_context, g_engine.vertex_shader, null, 0);
    ID3D11DeviceContext_VSSetConstantBuffers(renderer.d3d_context, 0, 1, *constant_buffer[0]);

    ID3D11DeviceContext_PSSetShader(renderer.d3d_context, g_engine.pixel_shader, null, 0);
    ID3D11DeviceContext_PSSetConstantBuffers(renderer.d3d_context, 1, 1, *constant_buffer[1]);

    return true;
}

engine_update  :: () {
    ImplDX11_NewFrame();
    ImplWin32_NewFrame();
    IMGUI.NewFrame();

    engine_scene_update(*g_engine, 0.1667);

    renderer_clear(*g_engine.renderer);

    using g_engine.renderer;
    ID3D11DeviceContext_DrawIndexed(d3d_context, g_engine.indices_count, 0, 0);

    IMGUI.Render();
    ImplDX11_RenderDrawData(IMGUI.GetDrawData());
    renderer_present(*g_engine.renderer);
}

#scope_file
is_open := true;
tx, ty, phi, theta := 0.0;
scale := 1.0;

animate_cube : bool = true;

current_light_index : s32 = 0;
current_mesh\_index : s32 = 0;

light_types : [3]*u8 = .["Directional Light", "Point Light", "Spot Light"];
mesh\_types : [4]*u8 = .["Box", "Sphere", "Cylinder", "Cone"];

engine_scene_update :: (using engine : *Engine, dt : float) {
    if animate_cube {
        phi += 0.0003 * dt;
        theta += 0.00037 * dt;
    }

    io := IMGUI.GetIO();

    if (!IMGUI.IsAnyItemActive()) {
        if (IMGUI.IsMouseDragging(.Left)) {
            tx -= io.MouseDelta.x * 0.01;
            ty -= io.MouseDelta.y * 0.01;
        } else if (IMGUI.IsMouseDragging(.Right)) {
            phi -= io.MouseDelta.y * 0.01;
            theta -= io.MouseDelta.x * 0.01;
        } else if (io.MouseWheel != 0.0) {
            scale += 0.02 * io.MouseWheel;
            Clamp(*scale, 0.2, 2);
        }
    }

    if IMGUI.Begin("Use ImGui") {
        IMGUI.Checkbox("Animate Cube", *animate_cube);
        IMGUI.SameLine(0.0, 25.0);
        if IMGUI.Button("Reset Params") {
            tx, ty , phi, theta = 0.0;
            scale = 1.0;
        }

        IMGUI.SliderFloat("Scale", *scale, 0.2, 1);

        IMGUI.Text(tprint("Phi: % degree", phi));
        IMGUI.SliderFloat("##1", *phi, -PI, PI, "");

        IMGUI.Text(tprint("Theta: % degree", theta));
        IMGUI.SliderFloat("##2", *theta, -PI, PI, "");

        IMGUI.Separator();
        IMGUI.Text("Mesh");
        if IMGUI.Combo(to_c_string("Mesh Type"), *current_mesh_index, mesh_types.data, cast(s32) mesh_types.count) {
            mesh_data : Mesh_Data(Immediate_Vertex);
            if current_mesh_index == {
                case; #through;
                case 0; mesh_data = make_box();
                case 1; mesh_data = make_sphere();
            }

            vertices_count = xx mesh_data.vertices.count;
            indices_count =  xx mesh_data.indices.count;

            geometry_mesh_reset(*renderer, *mesh_data, vertex_buffer, index_buffer);
        }

        IMGUI.Separator();
        IMGUI.Text("Material");

        IMGUI.Separator();
        IMGUI.Text("Light");
        if IMGUI.Combo(to_c_string("Light Type"), *current_light_index, light_types.data, cast(s32) light_types.count) {
            // gpu_pixel_buffer.directional
        }

        IMGUI.PushID(current_light_index);
        if current_light_index == {
            case 0;
                IMGUI.ColorEdit3("Ambient",  *gpu_pixel_buffer.directional_light.ambient.xyz);
                IMGUI.ColorEdit3("Diffuse",  *gpu_pixel_buffer.directional_light.diffuse.xyz);
                IMGUI.ColorEdit3("Specular", *gpu_pixel_buffer.directional_light.specular.xyz);
            case 1;
                IMGUI.ColorEdit3("Ambient",  *gpu_pixel_buffer.point_light.ambient.xyz);
                IMGUI.ColorEdit3("Diffuse",  *gpu_pixel_buffer.point_light.diffuse.xyz);
                IMGUI.ColorEdit3("Specular", *gpu_pixel_buffer.point_light.specular.xyz);
                IMGUI.InputFloat("Range",    *gpu_pixel_buffer.point_light.range);
                IMGUI.InputFloat3("Range",   *gpu_pixel_buffer.point_light.att);
            case 2;
                IMGUI.ColorEdit3("Ambient",  *gpu_pixel_buffer.spot_light.ambient.xyz);
                IMGUI.ColorEdit3("Diffuse",  *gpu_pixel_buffer.spot_light.diffuse.xyz);
                IMGUI.ColorEdit3("Specular", *gpu_pixel_buffer.spot_light.specular.xyz);
        }
        IMGUI.PopID();

    }
    IMGUI.End();

    rotation, yaw, pitch : Quaternion;

    set_from_axis_and_angle(*yaw, .{1, 0, 0}, phi);
    set_from_axis_and_angle(*pitch, .{0, 1, 0}, theta);
    rotation = yaw * pitch;

    model := translate(Matrix4_Identity, .{tx, ty, 5}) * rotation_matrix(Matrix4, rotation) * make_scale_matrix4(xyz(scale));
    view := make_look_at_matrix(.{0, 0, -5}, .{0, 0, 0}, .{0, 1, 0}, false);
    proj := make_projection_matrix(25 * PI / 180.0, xx ASPECT, 0.1, 1000);

    cb := VS_Constant_Buffer.{model=transpose(model), view=transpose(view), proj=transpose(proj)};
    using g_engine.renderer;

    mapped_data : D3D11_MAPPED_SUBRESOURCE;

    HR(ID3D11DeviceContext_Map(d3d_context, g_engine.constant_buffer[0], 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *cb, size_of(VS_Constant_Buffer));
    ID3D11DeviceContext_Unmap(d3d_context, g_engine.constant_buffer[0], 0);

    HR(ID3D11DeviceContext_Map(d3d_context, g_engine.constant_buffer[1], 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *gpu_pixel_buffer, size_of(PS_Constant_Buffer));
    ID3D11DeviceContext_Unmap(d3d_context, g_engine.constant_buffer[1], 0);
}

engine_draw2d  :: (engine : *Engine) {
}

engine_draw3d  :: () {
}

engine_postupdate :: () {
}

geometry_mesh_reset :: (using gfx_device : *Graphics_Device, mesh_data : *Mesh_Data($T), vertex_buffer : *ID3D11Buffer, index_buffer : *ID3D11Buffer) {
    vertex_buffer = null;
    index\_buffer = null;

    vbd : D3D11_BUFFER_DESC;
    vbd.Usage = .IMMUTABLE;
    vbd.ByteWidth = cast(u32) (mesh_data.vertices.count * size_of(T));
    vbd.BindFlags = .VERTEX_BUFFER;
    vbd.CPUAccessFlags = 0;

    vid : D3D11_SUBRESOURCE_DATA;
    vid.pSysMem = mesh_data.vertices.data;

    HR(ID3D11Device_CreateBuffer(d3d_device, *vbd, *vid, *vertex_buffer));

    stride : u32 = size_of(T);
    offset : u32 = 0; 
    ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, *vertex_buffer, *stride, *offset);

    ibd : D3D11_BUFFER_DESC;
    ibd.Usage = .IMMUTABLE;
    ibd.ByteWidth = cast(u32) (mesh_data.indices.count * size_of(u32));
    ibd.BindFlags = .INDEX_BUFFER;
    ibd.CPUAccessFlags = 0;

    iid : D3D11_SUBRESOURCE_DATA;
    iid.pSysMem = mesh_data.indices.data;

    HR(ID3D11Device_CreateBuffer(d3d_device, *ibd, *iid, *index_buffer));
    ID3D11DeviceContext_IASetIndexBuffer(d3d_context, index_buffer, .R32_UINT, 0);

    D3D11SetDebugObjectName(d3d_device, vertex_buffer, "VertexBuffer");
    D3D11SetDebugObjectName(d3d_device, index\_buffer, "IndexBuffer");
}