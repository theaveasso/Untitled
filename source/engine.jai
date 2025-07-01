MAX_SPRITES  :: 1024;
MAX_VERTICES :: 25000;
MAX_MESH     :: 256;

BUFFER_BINDING_CAMERA :: 2;

UI:: struct {
    toggle_grid: bool;
    toggle_axis: bool;
}

g_control_camera: bool;

Engine :: struct {
    screen_width, screen_height : u32;

    is_paused      : bool;
    is_minimized   : bool;
    is_maximized   : bool;
    is_resizing    : bool;

    enable\_4x_msaa : bool;
    quality_4x_msaa : u32;

    hwnd:       Window_Type;
    gfx_device: Graphics_Device;
    camera:     Camera; 

    ui:   UI;

    forward_lighting: Forward_Lighting;

    vertex_buffer : *ID3D11Buffer;
    index\_buffer : *ID3D11Buffer;

    drawcommand   : DrawCommand;
    line_commands : Line_DrawCommand;

    loaded_meshes : Table(string, Skinned_Mesh);

    constant_buffer: [4]*ID3D11Buffer;

    vertices_count : u32;
    indices\_count : u32;

    directional_light : Directional_Light; 
    point\     _light : Point_Light;
    spot\      _light : Spot_Light;  

    gpu_pixel\_buffer : PS_Constant_Buffer;

    // shaders
    shader_sprite : Shader;
    shader_line   : Shader;
    shader_mesh   : Shader;

    // rastersizer
    is_wireframe: bool = false;

    rs_mesh_wireframe:  *ID3D11RasterizerState;
    rs_mesh_solid:      *ID3D11RasterizerState;
}

g_dirextx_texture : Texture;

DrawCommand :: struct {
    vertex_buffer: *ID3D11Buffer;
    index_buffer:  *ID3D11Buffer;

    num_vertices: s32;
    num_indices: s32;

    vertices: [MAX_SPRITES*4]Immediate_Vertex;
    indices:  [MAX_SPRITES*6]u32;
}

Line_DrawCommand :: struct {
    vertex_buffer: *ID3D11Buffer;
    index_buffer:  *ID3D11Buffer;

    num_vertices: s32;

    vertices: [MAX_VERTICES]Line_Vertex;
}

Immediate_Vertex :: struct {
    position:    Vector3;
    color_scale: Vector4;
    uv0:         Vector2;
    normal:      Vector3;
    texture_id:  float;
}

Line_Vertex :: struct {
    position:    Vector3;
    color_scale: Vector4;
}

immediate_vertex_input_layout :[]D3D11_INPUT_ELEMENT_DESC = .[
    .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
    .{"COLOR",     0, .R32G32B32A32_FLOAT, 0, 12, .VERTEX_DATA, 0},
    .{"TEXCOORD",  0, .R32G32_FLOAT,       0, 28, .VERTEX_DATA, 0},
    .{"NORMAL",    0, .R32G32B32_FLOAT,    0, 36, .VERTEX_DATA, 0},
    .{"TEXTURE_ID",0, .R32_FLOAT,          0, 48, .VERTEX_DATA, 0},
];

mesh_vertex_input_layout :[]D3D11_INPUT_ELEMENT_DESC = .[
    .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
    .{"NORMAL",    0, .R32G32B32_FLOAT,    0, 12, .VERTEX_DATA, 0}
];

line_vertex_input_layout :[]D3D11_INPUT_ELEMENT_DESC = .[
    .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
    .{"COLOR",     0, .R32G32B32A32_FLOAT, 0, 12, .VERTEX_DATA, 0},
];

Material :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;
    reflect : Vector4;
}

CBuffer_Perframe :: struct {
    projection2d: Matrix4;
}

PS_Constant_Buffer :: struct{
    directional_light : Directional_Light;
    eye_position      : Vector3;
    pad               : float;
}

engine_init    :: (using engine : *Engine) -> bool {
    success := false;

    screen_width = xx g_window_width;
    screen_height = xx g_window_height;

    hwnd = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb=.[0, 0, 0]);
    success = hwnd != null;

    enable_4x_msaa = true;
    success = graphics_device_init(*gfx_device, hwnd, enable_4x_msaa, *quality_4x_msaa);
    success = imgui_init(hwnd, *gfx_device);
    success = engine_effect_init(engine);
    success = engine_resource_init(engine);

    raster_desc : D3D11_RASTERIZER_DESC;
    raster_desc.CullMode = .NONE;
    raster_desc.FrontCounterClockwise = 0;
    raster_desc.DepthClipEnable = 1;

    raster_desc.FillMode = .SOLID;
    ID3D11Device_CreateRasterizerState(gfx_device.d3d_device, *raster_desc, *rs_mesh_solid);

    raster_desc.FillMode = .WIREFRAME;
    ID3D11Device_CreateRasterizerState(gfx_device.d3d_device, *raster_desc, *rs_mesh_wireframe);

    camera.position = xyz(1, 1.3, -20);
    camera.euler_angles.x = -20 * PI / 180.0;
    camera.euler_angles.y =  10 * PI / 180.0;
    camera.aspect = cast(float) screen_width / screen_height;

    return success;
}

engine_effect_init :: (using engine : *Engine) -> bool {
    success: bool;
    success = shader_init(*gfx_device, *shader_mesh,   SHADER_MESH, *mesh_vertex_input_layout);
    success = shader_init(*gfx_device, *shader_sprite, SHADER_SPRITE, *immediate_vertex_input_layout);
    success = shader_init(*gfx_device, *shader_line,   SHADER_LINE, *line_vertex_input_layout);

    return success;
}

engine_resource_init :: (using engine : *Engine) -> bool {
    box_mesh := make_box(2, 2, 2);
    // geometry_mesh_reset(*gfx_device, *box_mesh, vertex_buffer, index_buffer);
    // vertices_count = xx box_mesh.vertices.count;
    // indices_count  = xx box_mesh.indices.count;
    drawcommands_init(engine);
    line_commands_init(engine);

    forward_lighting_init(*gfx_device, *forward_lighting);

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DYNAMIC;
    cbd.BindFlags = .CONSTANT_BUFFER;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size_of(Matrix4);
    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, *constant_buffer[0]));
    cbd.ByteWidth = size_of(PS_Constant_Buffer);
    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, *constant_buffer[1]));

    cbd.ByteWidth = size_of(Matrix4);
    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, *constant_buffer[2]));
    cbd.ByteWidth = size_of(Matrix4);
    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, *constant_buffer[3]));

    gpu_pixel_buffer.eye_position = .{0.0, 0.0, -5.0};

    texture_load_from_file(*gfx_device, *g_dirextx_texture, "resources/rock_wall_13_diff_4k.jpg");

    find_and_load_meshes(engine);

    ID3D11DeviceContext_IASetPrimitiveTopology(gfx_device.d3d_context, .TRIANGLELIST);

    ID3D11DeviceContext_VSSetShader(gfx_device.d3d_context, shader_sprite.vertex_shader, null, 0);
    ID3D11DeviceContext_VSSetConstantBuffers(gfx_device.d3d_context, 0, 1, *constant_buffer[0]);

    ID3D11DeviceContext_PSSetShader(gfx_device.d3d_context, shader_sprite.pixel_shader, null, 0);
    ID3D11DeviceContext_PSSetConstantBuffers(gfx_device.d3d_context, 1, 1, *constant_buffer[1]);

    ID3D11DeviceContext_VSSetShader(gfx_device.d3d_context, shader_mesh.vertex_shader, null, 0);
    ID3D11DeviceContext_PSSetConstantBuffers(gfx_device.d3d_context, 0, 1, *constant_buffer[2]);

    return true;
}

engine_update  :: (using engine: *Engine) {
    ImplDX11_NewFrame();
    ImplWin32_NewFrame();
    IMGUI.NewFrame();

    renderer_clear(*g_engine.gfx_device);
    camera_update(*camera, 0.01667);
    ui_update(*ui);

    gfx_set_shader(*gfx_device, *shader_line);
    gfx_set_projection(*gfx_device, constant_buffer[BUFFER_BINDING_CAMERA], *camera);
    if ui.toggle_axis draw_axis(*gfx_device, *line_commands);
    if ui.toggle_grid draw_grid(*gfx_device, *line_commands);
    gfx_flush_line_commands(*gfx_device, *line_commands);

    gfx_set_shader(*gfx_device, *shader_mesh);
    if is_wireframe 
        ID3D11DeviceContext_RSSetState(gfx_device.d3d_context, rs_mesh_wireframe);
    else
        ID3D11DeviceContext_RSSetState(gfx_device.d3d_context, rs_mesh_solid);

    // forward lighting pass
    foward_lighting_pass(*gfx_device, *forward_lighting);
    gfx_draw_mesh(*gfx_device, table_find_pointer(*loaded_meshes, "Grayfish"));

    // engine_scene_update(*g_engine, 0.1667);

    // gfx_set_shader(*gfx_device, *shader_sprite);
    // gfx_set_projection2d(*gfx_device, constant_buffer[0], xx screen_width, xx screen_height);
    // gfx_set_texture(*gfx_device, *shader_sprite, *g_dirextx_texture);
    // gfx_draw_quad(*gfx_device, *drawcommand, 0, 0, 100, 100);
    // gfx_draw_quad(*gfx_device, *drawcommand, 100, 0, 100, 100, .{1.0, 0.0, 0.0, 1.0});
    // gfx_draw_quad(*gfx_device, *drawcommand, 200, 0, 100, 100, .{0.0, 1.0, 0.0, 1.0});
    // gfx_draw_quad(*gfx_device, *drawcommand, 300, 0, 100, 100, .{0.0, 0.0, 1.0, 1.0});
    // gfx_draw_quad(*gfx_device, *drawcommand, .{400, 0, 100, 100}, 1);

    // gfx_flush(*gfx_device, *drawcommand);

    // gfx_set_shader(*gfx_device, *shader_mesh);

    IMGUI.Render();
    ImplDX11_RenderDrawData(IMGUI.GetDrawData());
    renderer_present(*gfx_device);
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

            geometry_mesh_reset(*gfx_device, *mesh_data, vertex_buffer, index_buffer);
        }

        IMGUI.Separator();
        IMGUI.Text("Material");

        IMGUI.Separator();
        IMGUI.Text("Light");
        if IMGUI.Combo(to_c_string("Light Type"), *current_light_index, light_types.data, cast(s32) light_types.count) {
            if current_light_index ==  {
                case; #through;
                case 0; gpu_pixel_buffer.directional_light = make_directional_light(.{1.0, 1.0, 1.0, 1.0}, .{0.0, -1.0, 0.0});
            }
        }

        IMGUI.PushID(current_light_index);
        if current_light_index == {
            case 0;
                IMGUI.ColorEdit3("Ambient",  *gpu_pixel_buffer.directional_light.ambient.xyz);
                IMGUI.ColorEdit3("Diffuse",  *gpu_pixel_buffer.directional_light.diffuse.xyz);
                IMGUI.ColorEdit3("Specular", *gpu_pixel_buffer.directional_light.specular.xyz);
        }
        IMGUI.PopID();

    }
    IMGUI.End();

    rotation, yaw, pitch : Quaternion;

    set_from_axis_and_angle(*yaw, .{1, 0, 0}, phi);
    set_from_axis_and_angle(*pitch, .{0, 1, 0}, theta);
    rotation = yaw * pitch;

    // model := translate(Matrix4_Identity, .{tx, ty, 5}) * rotation_matrix(Matrix4, rotation) * make_scale_matrix4(xyz(scale));
    view := make_look_at_matrix(.{0, 0, -5}, .{0, 0, 0}, .{0, 1, 0}, false);
    proj := make_projection_matrix(25 * PI / 180.0, xx ASPECT, 0.1, 1000);

    using g_engine.gfx_device;

    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, g_engine.constant_buffer[1], 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, *gpu_pixel_buffer, size_of(PS_Constant_Buffer));
    ID3D11DeviceContext_Unmap(d3d_context, g_engine.constant_buffer[1], 0);

    // Pixel shader set texture and sampler
    ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *g_dirextx_texture.image_view);
    ID3D11DeviceContext_PSSetSamplers(d3d_context, 0, 1, *shader_sprite.sampler_state);
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

#scope_file
drawcommands_init :: (using engine: *Engine) {
    vbd : D3D11_BUFFER_DESC;
    vbd.Usage = .DYNAMIC;
    vbd.ByteWidth = cast(u32) (size_of(Immediate_Vertex) * MAX_SPRITES * 4);
    vbd.BindFlags = .VERTEX_BUFFER;
    vbd.CPUAccessFlags = .WRITE;

    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *vbd, null, *drawcommand.vertex_buffer));

    ibd : D3D11_BUFFER_DESC;
    ibd.Usage = .DYNAMIC;
    ibd.ByteWidth = cast(u32) (size_of(u32) * MAX_SPRITES * 6);
    ibd.BindFlags = .INDEX_BUFFER;
    ibd.CPUAccessFlags = .WRITE;

    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *ibd, null, *drawcommand.index_buffer));

    D3D11SetDebugObjectName(gfx_device.d3d_device, vertex_buffer, "DrawCommand_VertexBuffer");
    D3D11SetDebugObjectName(gfx_device.d3d_device, index\_buffer, "DrawCommand_IndexBuffer");
}

line_commands_init :: (using engine: *Engine) {
    vbd : D3D11_BUFFER_DESC;
    vbd.Usage = .DYNAMIC;
    vbd.ByteWidth = cast(u32) (size_of(Line_Vertex) * MAX_VERTICES);
    vbd.BindFlags = .VERTEX_BUFFER;
    vbd.CPUAccessFlags = .WRITE;

    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *vbd, null, *line_commands.vertex_buffer));

    D3D11SetDebugObjectName(gfx_device.d3d_device, vertex_buffer, "LineCommands_VertexBuffer");
}

find_and_load_meshes :: inline (using engine: *Engine) {
    mesh : Skinned_Mesh;

    loaded := mesh_load_from_file(*mesh, "resources/mesh/grayfish.glb");
    if loaded {
        mesh_reset(*gfx_device, *mesh);
        table_add(*loaded_meshes, copy_string("Grayfish"), mesh);
    } else {
        log_error("mesh_load_from_file");
    }
}

draw_axis :: inline (gfx_device: *Graphics_Device, commands: *Line_DrawCommand) {

    gfx_draw_line(gfx_device, commands, .{}, .{x=100}, .{x=1, w=1});
    gfx_draw_line(gfx_device, commands, .{}, .{y=100}, .{y=1, w=1});
    gfx_draw_line(gfx_device, commands, .{}, .{z=100}, .{z=1, w=1});
}

draw_grid :: inline (gfx_device: *Graphics_Device, commands: *Line_DrawCommand) {

    for i: -10..10 {
        gfx_draw_line(gfx_device, commands, .{xx i * 10.0, 0, -100}, .{xx i * 10.0, 0, 100}, .{0.4, 0.4, 0.4, 1});
    }

    for i: -10..10 {
        gfx_draw_line(gfx_device, commands, .{-100, 0, xx i * 10.0}, .{100, 0, xx i * 10.0}, .{0.4, 0.4, 0.4, 1});
    }
}

ui_update :: (using state: *UI) {
    if IMGUI.Begin("UI") {
        IMGUI.Checkbox("Toggle Axis", *toggle_axis);
        IMGUI.Checkbox("Toggle Grid Line", *toggle_grid);
    }
    IMGUI.End();
}