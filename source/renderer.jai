g_program : GLuint;
g_vao, g_vbo, g_ibo : GLuint;
g_cube_vao, g_cube_vbo, g_cube_ibo : GLuint;

Vertex :: struct {
    position := Vector4.{0.0, 0.0, 0.0, 0.0};
    uv       := Vector2.{0.0, 1.0};
}

renderer_init :: () -> bool {
    sucess : bool;
    sucess, g_program = create_shader_program(VERT_SHADER, FRAG_SHADER);

    glGenVertexArrays(1, *g_vao);
    glBindVertexArray(g_vao);

    glGenBuffers(1, *g_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * vertices.count, vertices.data, GL_STATIC_DRAW);

    glGenBuffers(1, *g_ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ibo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector4));

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    glGenVertexArrays(1, *g_cube_vao);
    glBindVertexArray(g_cube_vao);

    glGenBuffers(1, *g_cube_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_cube_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * cube_vertices.count, cube_vertices.data, GL_STATIC_DRAW);

    // glGenBuffers(1, *g_cube_ibo);
    // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_cube_ibo);
    // glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * cube_indices.count, cube_indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector4));

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    return sucess;
}

immediate_mesh :: (model : Matrix4 = Matrix4_Identity) {
    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ibo);
    glUseProgram(g_program);

    dt := sin(seconds_since_init() * 2) / 2;

    rotation : Quaternion;
    set_from_axis_and_angle(*rotation, .{0, 1, 0}, xx dt);

    set_uniform_matrix4(g_program, "model", rotation_matrix(Matrix4, rotation));
    set_uniform_matrix4(g_program, "viewproj", g_camera.view_proj);

    glDrawElements(GL_TRIANGLE_STRIP, cast(u32) indices.count, GL_UNSIGNED_INT, null);
}

immediate_cube :: (model : Matrix4 = Matrix4_Identity) {
    glBindVertexArray(g_cube_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_cube_vbo);
    // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_cube_ibo);
    glUseProgram(g_program);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, g_map_block.gl_handle);

    rot : Quaternion;
    set_from_axis_and_angle(*rot, 0.5, 1, 0, xx (seconds_since_init() * 55 * PI / 180.));

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    set_uniform(g_program, "diffuse_texture", int, 0);
    set_uniform(g_program, "model", Matrix4, make_translation_matrix4(.{0, 0, -2}) * rotation_matrix(Matrix4, rot));
    set_uniform(g_program, "viewproj", Matrix4, g_camera.view_proj);

    glDrawArrays(GL_TRIANGLES, 0, cast(u32) cube_vertices.count);
}

immediate_quad :: (model : Matrix4 = Matrix4_Identity) {
    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ibo);
    glUseProgram(g_program);

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
            case float;
            case int;       glUniform1i(location, cast(s32)val);
        }
    }
}

set_uniform_matrix4 :: (program : GLuint, name : *u8, m: Matrix4) {
    loc := glGetUniformLocation(program, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniformMatrix4fv(loc, 1, GL_TRUE, *m._11);
}

VERT_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec4 position;
layout (location = 1) in vec2 uv;

uniform mat4 model;
uniform mat4 viewproj;

out vec2 v_texcoord;

void main() {
    v_texcoord  = uv;
    gl_Position = viewproj * model * position;
}

GLSL

FRAG_SHADER :: #string GLSL
#version 450 core

in vec2 v_texcoord;

out vec4 frag_color;

uniform sampler2D diffuse_texture;

void main() {
    frag_color = texture(diffuse_texture, v_texcoord);
}

GLSL

#scope_file

vertices : [4]Vertex= .[
    .{.{-0.5, -0.5, 0.0, 1.0}, .{0.0, 1.0}}, 
    .{.{ 0.5, -0.5, 0.0, 1.0}, .{1.0, 1.0}}, 
    .{.{ 0.5,  0.5, 0.0, 1.0}, .{1.0, 0.0}}, 
    .{.{-0.5,  0.5, 0.0, 1.0}, .{0.0, 0.0}}, 
];

indices  : [6]u32 = .[0, 1, 2, 0, 2, 3];

cube_vertices : [36]Vertex = .[
    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 0.0}},
    .{.{ 0.5, -0.5, -0.5, 1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{-0.5,  0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 0.0}},

    .{.{-0.5, -0.5,  0.5, 1.0}, .{0.0, 0.0}},
    .{.{ 0.5, -0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 1.0}},
    .{.{-0.5,  0.5,  0.5, 1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5,  0.5, 1.0}, .{0.0, 0.0}},

    .{.{-0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{-0.5,  0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{-0.5, -0.5,  0.5, 1.0}, .{0.0, 0.0}},
    .{.{-0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},

    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5,  0.5, 1.0}, .{0.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},

    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{ 0.5, -0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{ 0.5, -0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{ 0.5, -0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{-0.5, -0.5,  0.5, 1.0}, .{0.0, 0.0}},
    .{.{-0.5, -0.5, -0.5, 1.0}, .{0.0, 1.0}},

    .{.{-0.5,  0.5, -0.5, 1.0}, .{0.0, 1.0}},
    .{.{ 0.5,  0.5, -0.5, 1.0}, .{1.0, 1.0}},
    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{ 0.5,  0.5,  0.5, 1.0}, .{1.0, 0.0}},
    .{.{-0.5,  0.5,  0.5, 1.0}, .{0.0, 0.0}},
    .{.{-0.5,  0.5, -0.5, 1.0}, .{0.0, 1.0}}
];

cube_indices : [36]u32 = .[
     0,  1,  2,  2,  3,  0,
     4,  5,  6,  6,  7,  4,
     8,  9, 10, 10, 11,  8,
    12, 13, 14, 14, 15, 12,
    16, 17, 18, 18, 19, 16,
    20, 21, 22, 22, 23, 20,
]; 

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