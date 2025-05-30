g_program : GLuint;
g_vao, g_vbo, g_ibo : GLuint;

renderer_init :: () -> bool {
    sucess : bool;
    sucess, g_program = create_shader_program(VERT_SHADER, FRAG_SHADER);

    glGenBuffers(1, *g_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    defer glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vector4) * vertices.count, vertices.data, GL_STATIC_DRAW);

    glGenBuffers(1, *g_ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ibo);
    defer glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);

    glGenVertexArrays(1, *g_vao);
    glBindVertexArray(g_vao);
    defer glBindVertexArray(0);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, size_of(Vector4), cast (*void) 0);

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

set_uniform_matrix4 :: (program : GLuint, name : *u8, m: Matrix4) {
    loc := glGetUniformLocation(program, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniformMatrix4fv(loc, 1, GL_TRUE, *m._11);
}

VERT_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec4 position;

uniform mat4 model;
uniform mat4 viewproj;

void main() {
    gl_Position = viewproj * model * position;
}

GLSL

FRAG_SHADER :: #string GLSL
#version 450 core

out vec4 frag_color;

void main() {
    frag_color = vec4(1.0, 1.0, 1.0, 1.0);
}

GLSL

#scope_file

vertices : [4]Vector4 = .[
    .{-1, -1, -5, 1},
    .{ 1, -1, -5, 1},
    .{-1,  1, -5, 1},
    .{ 1,  1, -5, 1},
];

indices  : [4]u32 = .[0, 1, 2, 3];

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