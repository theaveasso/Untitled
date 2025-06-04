Voxel :: struct {
    Vetex :: struct {
        position : Vector3;
    }

    program        : GLuint;
    vao, vbo, ebo  : GLuint;
}

VOXEL_VERTEX_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec3 position;

uniform mat4 model;
uniform mat4 viewproj;

void main() {
    gl_Position = viewproj * model * vec4(position, 1);
}

GLSL

VOXEL_FRAGMENT_SHADER :: #string GLSL
#version 450 core

out vec4 frag_color;

void main() {
    frag_color = vec4(1.0, 1.0, 1.0, 1.0);
}

GLSL
