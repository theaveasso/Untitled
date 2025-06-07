Voxel :: struct {
    Vertex :: struct {
        position :  Vector3;
        uv       := Vector2.{0, 0};
    }

    program        : GLuint;
    vao, vbo, ebo  : GLuint;
}

VOXEL_VERTEX_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 uv;

out vec2 v_texcoord;

uniform mat4 viewproj;

void main() {
    v_texcoord = uv;
    gl_Position = viewproj * vec4(position, 1);
}

GLSL

VOXEL_FRAGMENT_SHADER :: #string GLSL
#version 450 core

in  vec2 v_texcoord;
out vec4 frag_color;

uniform sampler2D map;

void main() {
    frag_color = vec4(texture(map, v_texcoord));
}

GLSL
