g_program, g_light_program  : GLuint;
g_skybox_program : GLuint;

g_vao, g_vbo, g_ibo                 : GLuint;
g_cube_vao, g_cube_vbo, g_cube_ibo  : GLuint;
g_light_vao, g_light_vbo            : GLuint;

Skybox :: struct {
    Vetex :: struct {
        position : Vector3;
    }

    vao, vbo, ebo  : GLuint;
    cubemap_handle : GLuint;
}

g_light_source := Vector3.{1.2, -2.0, 0.0};

Vertex :: struct {
    position := Vector3.{0.0, 0.0, 0.0};
    normal   := Vector3.{0.0, 0.0, 0.0};
    uv       := Vector2.{0.0, 1.0};
}

Material :: struct {
    ambient  : Vector3;
    diffuse  : Vector3;
    specular : Vector3;

    shininess: float;
}

renderer_init :: () -> bool {
    success : bool;

    success = terrain_program_init(*g_terrain);
    success = skybox\_program_init(*g_skybox);
    // success = voxel\ _program_init(*g_world, *g_voxel);

    return success;
}

terrain_program_init :: (terrain : *Terrain) -> bool {
    success : bool;
    success, g_terrain_program = create_shader_program(TERRAIN_VERTEX_SHADER, TERRAIN_FRAGMENT_SHADER);
    if !success { log_error("Could not create terrain program"); return false; }

    terrain_triangle_list_init(terrain);

    return success;
}

skybox_program_init :: (using skybox : *Skybox) -> bool {
    success : bool;
    success, g_skybox_program = create_shader_program(SKYBOX_VERTEX_SHADER, SKYBOX_FRAGMENT_SHADER);
    if !success { log_error("Could not create skybox program"); return false; }

    vertices : [8]Skybox.Vetex = .[
        .{.{-1.0, -1.0,  1.0}},            //        7--------6
        .{.{ 1.0, -1.0,  1.0}},            //       /|       /|
        .{.{ 1.0, -1.0, -1.0}},            //      4--------5 |
        .{.{-1.0, -1.0, -1.0}},            //      | |      | |
        .{.{-1.0,  1.0,  1.0}},            //      | 3------|-2
        .{.{ 1.0,  1.0,  1.0}},            //      |/       |/
        .{.{ 1.0,  1.0, -1.0}},            //      0--------1
        .{.{-1.0,  1.0, -1.0}},            //
    ];

    indices : [36]u32 = .[
        1, 2, 6, 6, 5, 1, // Right
        0, 4, 7, 7, 3, 0, // Left
        4, 5, 6, 6, 7, 4, // Top	
	    0, 3, 2, 2, 1, 0, // Bottom
	    0, 1, 5, 5, 4, 0, // Back
	    3, 7, 6, 6, 2, 3, // Front
    ];

    glGenVertexArrays(1, *vao);
    glGenBuffers(1, *vbo);
    glGenBuffers(1, *ebo);

    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Skybox.Vetex) * vertices.count, vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Skybox.Vetex), cast(*void)0);

    glUseProgram(g_skybox_program);
    set_uniform(g_skybox_program, "skybox", int, cubemap_handle);
    glUseProgram(0);

    return success;
}

voxel_program_init :: (world : *World, using voxel : *Voxel) -> bool {
    success : bool;

    return success;
}

immediate_skybox :: (using skybox : *Skybox) {
    old_cull_face_mode, old_depth_func_mode : GLint;
    glGetIntegerv(GL_CULL_FACE_MODE, *old_cull_face_mode);
    glGetIntegerv(GL_DEPTH_FUNC,     *old_depth_func_mode);

    glCullFace(GL_FRONT);
    glDepthFunc(GL_LEQUAL);

    glUseProgram(g_skybox_program);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemap_handle);

    view := make_matrix4(make_matrix3(g_camera.view));
    set_uniform(g_skybox_program, "viewproj", Matrix4, g_camera.projection * view);

    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, null);

    glCullFace(xx old_cull_face_mode);
    glDepthFunc(xx old_depth_func_mode);
}

immediate_light :: (model : Matrix4 = Matrix4_Identity) {
    glUseProgram(g_light_program);
    glBindVertexArray(g_light_vao);

    set_uniform(g_light_program, "model", Matrix4, model);
    set_uniform(g_light_program, "viewproj", Matrix4, g_camera.view_proj);

    glDrawArrays(GL_TRIANGLES, 0, cast(u32) cube_vertices.count);
    glBindVertexArray(0);
}

immediate_cube :: (using voxel : *Voxel, model : Matrix4 = Matrix4_Identity) {
    glUseProgram(program);
    glBindVertexArray(vao);

    set_uniform(program, "model",    Matrix4, model);
    set_uniform(program, "viewproj", Matrix4, g_camera.view_proj);

    glDrawElements(GL_TRIANGLES, 32, GL_UNSIGNED_INT, null);
    glBindVertexArray(0);
}

immediate_quad :: (model : Matrix4 = Matrix4_Identity) {
    glUseProgram(g_program);

    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ibo);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, g_map_block.gl_handle);

    rot : Quaternion;
    set_from_axis_and_angle(*rot, 0.5, 1, 0, xx (seconds_since_init() * 55 * PI / 180.));

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    set_uniform(g_program, "diffuse_texture", int, 0);
    set_uniform(g_program, "model", Matrix4, make_translation_matrix4(.{0, 0, -1}) * rotation_matrix(Matrix4, rot));
    set_uniform(g_program, "viewproj", Matrix4, g_camera.view_proj);

    glDrawElements(GL_TRIANGLES, cast(u32) 36, GL_UNSIGNED_INT, null);
}

set_uniform :: (program: GLuint, name: *u8, $T: Type, val : T) {
    location := glGetUniformLocation(program, name);
    if location <  0 log_error("Unknown parameter: '%'\n", to_string(name));
    if location >= 0 {
        #if T == {
            case Matrix4;   glUniformMatrix4fv(location, 1, GL_TRUE, *val._11);
            case Vector2;
            case Vector3;   glUniform3f(location, val.x, val.y, val.z);
            case float;
            case int;       glUniform1i(location, cast(s32)val);
        }
    }
}

SKYBOX_VERTEX_SHADER   :: #string GLSL 
#version 330 core

layout (location = 0) in vec3 position;

out vec3 v_texcoord;

uniform mat4 viewproj;

void main() {
    vec4 pos = viewproj * vec4(position, 1.0);
    gl_Position = pos.xyww;
    v_texcoord  = position;
}
GLSL

SKYBOX_FRAGMENT_SHADER :: #string GLSL 
#version 330 core

in  vec3 v_texcoord;

out vec4 frag_color;

uniform samplerCube skybox;

void main() {
    frag_color = texture(skybox, v_texcoord);
}

GLSL

VERT_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 uv;

uniform mat4 model;
uniform mat4 viewproj;

out vec2 v_texcoord;
out vec3 v_normal;
out vec4 v_position;

void main() {
    v_texcoord  = uv;
    v_normal    = mat3(transpose(inverse(model))) * normal;
    v_position  = vec4(model * position);

    gl_Position = viewproj * v_position;
}

GLSL

FRAG_SHADER :: #string GLSL
#version 450 core

struct Material {
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
};

in vec4 v_position;
in vec3 v_normal;
in vec2 v_texcoord;

out vec4 frag_color;

// uniform sampler2D diffuse_texture;

uniform vec3 light_color;
uniform vec3 view_position;
uniform vec3 light_position;

uniform Material material;

void main() {
    vec3 ambient     = material.ambient * light_color;

    vec3 n           = normalize(v_normal);
    vec3 light_dir   = normalize(light_position.xyz - v_position.xyz);
    float diff       = max(dot(n, light_dir), 0.0);
    vec3 diffuse     = light_color * (diff * material.diffuse);

    vec3 view_dir    = normalize(view_position.xyz - v_position.xyz);
    vec3 reflect_dir = reflect(-light_dir, n);
    float spec       = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);
    vec3 specular    = light_color * (spec * material.specular);

    vec3 result      = ambient + diffuse + specular;
    frag_color       = vec4(result, 1.0);
}

GLSL

LIGHT_VERT_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec4 position;

uniform mat4 model;
uniform mat4 viewproj;

void main() {
    gl_Position = viewproj * model * position;
}

GLSL

LIGHT_FRAG_SHADER :: #string GLSL
#version 450 core

out vec4 frag_color;

void main() {
    frag_color = vec4(1.0, 1.0, 1.0, 1.0);
}
GLSL;


block_render_object_init :: (block : *Block, position : Vector3) {
    pf    := 0.5;
    start := 0.5;

    // array_find()
    print("meme g %\n", *g_block_specifications);
    // block_specification_find(g_block_specifications, .Block_Type_Grass);
}

quad_position_for_face :: (direction : Vertex_Direction) -> [4]Vector3 {
    result : [4]Vector3;

    half := 0.5;
    if direction == {
        case .Vertex_Direction_Front;   return .[.{-half, -half, +half}, .{+half, -half, +half}, .{+half, +half, +half}, .{-half, +half, +half}];
        case .Vertex_Direction_Back;    return .[.{+half, -half, -half}, .{-half, -half, -half}, .{-half, +half, -half}, .{+half, +half, -half}];
        case .Vertex_Direction_Top;     return .[.{-half, +half, +half}, .{+half, +half, +half}, .{+half, +half, -half}, .{-half, +half, -half}];
        case .Vertex_Direction_Bottom;  return .[.{-half, -half, -half}, .{+half, -half, -half}, .{+half, -half, +half}, .{-half, -half, +half}];
        case .Vertex_Direction_Left;    return .[.{-half, -half, -half}, .{-half, -half, +half}, .{-half, +half, +half}, .{-half, +half, -half}];
        case .Vertex_Direction_Right;   return .[.{+half, -half, +half}, .{+half, -half, -half}, .{+half, +half, -half}, .{+half, +half, +half}];
        case; return .[.{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}];
    }
}

create_shader_program :: (vert_source : string, frag_source : string) -> bool, GLuint {
    check_compile_errors :: (shader : GLuint) -> bool, info_log : string {
        success : s32;
        glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
        if !success {
            info_len : s32;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, *info_len);
            info_data := cast(*u8) alloc(info_len,,temp);
            glGetShaderInfoLog(shader, xx info_len, xx *info_len, info_data);
            result : string;
            result.data = info_data; 
            result.count = info_len;

            return false, result;
        }
        return true, "";
    }

    check_link_errors :: (program: GLuint) -> bool, info_log : string {
        success : s32;
        glGetProgramiv(program, GL_LINK_STATUS, *success);
        if !success {
            info_len : s32;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, *info_len);
            info_data := cast(*u8) alloc(info_len,,temp);
            glGetProgramInfoLog(program, xx info_len, xx *info_len, info_data);
            result : string;
            result.data = info_data; 
            result.count = info_len;

            return false, result;
        }
        return true, "";
    } 

    vs := glCreateShader(GL_VERTEX_SHADER);
    defer glDeleteShader(vs);

    vert_src := *u8.[vert_source.data];
    vert_len := s32.[xx vert_source.count];
    glShaderSource(vs, 1, vert_src.data, vert_len.data);
    glCompileShader(vs);
    ok, info_log := check_compile_errors(vs);
    if !ok { print("Could not compile vertex shader %\n", info_log); return false, 0; }

    fs := glCreateShader(GL_FRAGMENT_SHADER);
    defer glDeleteShader(fs);

    frag_src := *u8.[frag_source.data];
    frag_len := s32.[xx frag_source.count];
    glShaderSource(fs, 1, frag_src.data, frag_len.data);
    glCompileShader(fs);
    ok, info_log = check_compile_errors(fs);
    if !ok { print("Could not compile fragment shader %\n", info_log); return false, 0; }

    program := glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    ok, info_log = check_link_errors(program);
    if !ok { print("Could not link shader program %\n", info_log); return false, 0; }

    return true, program;
}

#scope_file

vertices : [4]Vertex= .[
    .{position=.{-0.5, -0.5, 0.0}, uv=.{0.0, 1.0}}, 
    .{position=.{ 0.5, -0.5, 0.0}, uv=.{1.0, 1.0}}, 
    .{position=.{ 0.5,  0.5, 0.0}, uv=.{1.0, 0.0}}, 
    .{position=.{-0.5,  0.5, 0.0}, uv=.{0.0, 0.0}}, 
];

indices  : [6]u32 = .[0, 1, 2, 0, 2, 3];

cube_vertices : [36]Vertex = .[
    .{.{-0.5, -0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{0.0, 0.0}},
    .{.{ 0.5, -0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{1.0, 1.0}},
    .{.{-0.5,  0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5, -0.5}, .{ 0.0,  0.0, -1.0}, .{0.0, 0.0}},

    .{.{-0.5, -0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{0.0, 0.0}},
    .{.{ 0.5, -0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{1.0, 1.0}},
    .{.{-0.5,  0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5,  0.5}, .{ 0.0,  0.0,  1.0}, .{0.0, 0.0}},

    .{.{-0.5,  0.5,  0.5}, .{-1.0,  0.0,  0.0}, .{1.0, 0.0}},
    .{.{-0.5,  0.5, -0.5}, .{-1.0,  0.0,  0.0}, .{1.0, 1.0}},
    .{.{-0.5, -0.5, -0.5}, .{-1.0,  0.0,  0.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5, -0.5}, .{-1.0,  0.0,  0.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5,  0.5}, .{-1.0,  0.0,  0.0}, .{0.0, 0.0}},
    .{.{-0.5,  0.5,  0.5}, .{-1.0,  0.0,  0.0}, .{1.0, 0.0}},

    .{.{ 0.5,  0.5,  0.5}, .{ 1.0,  0.0,  0.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5, -0.5}, .{ 1.0,  0.0,  0.0}, .{1.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5}, .{ 1.0,  0.0,  0.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5}, .{ 1.0,  0.0,  0.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5,  0.5}, .{ 1.0,  0.0,  0.0}, .{0.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5}, .{ 1.0,  0.0,  0.0}, .{1.0, 0.0}},

    .{.{-0.5, -0.5, -0.5}, .{ 0.0, -1.0,  0.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5}, .{ 0.0, -1.0,  0.0}, .{1.0, 1.0}},
    .{.{ 0.5, -0.5,  0.5}, .{ 0.0, -1.0,  0.0}, .{1.0, 0.0}},
    .{.{ 0.5, -0.5,  0.5}, .{ 0.0, -1.0,  0.0}, .{1.0, 0.0}},
    .{.{-0.5, -0.5,  0.5}, .{ 0.0, -1.0,  0.0}, .{0.0, 0.0}},
    .{.{-0.5, -0.5, -0.5}, .{ 0.0, -1.0,  0.0}, .{0.0, 1.0}},

    .{.{-0.5,  0.5, -0.5}, .{ 0.0,  1.0,  0.0}, .{0.0, 1.0}},
    .{.{ 0.5,  0.5, -0.5}, .{ 0.0,  1.0,  0.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5,  0.5}, .{ 0.0,  1.0,  0.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5}, .{ 0.0,  1.0,  0.0}, .{1.0, 0.0}},
    .{.{-0.5,  0.5,  0.5}, .{ 0.0,  1.0,  0.0}, .{0.0, 0.0}},
    .{.{-0.5,  0.5, -0.5}, .{ 0.0,  1.0,  0.0}, .{0.0, 1.0}}
];

cube_indices : [36]u32 = .[
     0,  1,  2,  2,  3,  0,
     4,  5,  6,  6,  7,  4,
     8,  9, 10, 10, 11,  8,
    12, 13, 14, 14, 15, 12,
    16, 17, 18, 18, 19, 16,
    20, 21, 22, 22, 23, 20,
]; 
