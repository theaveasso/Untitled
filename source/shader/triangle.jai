TRIANGLE_SHADER :: #string GLSL 
OUT_IN vec3 iterated_color;

#ifdef VERTEX_SHADER
const vec2 pos[3] = vec2[3](
    vec2(-0.6, -0.4),
    vec2( 0.6, -0.4),
    vec2( 0.0,  0.6)
);
const vec3 col[3] = vec3[3](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() {
    gl_Position = vec4(pos[gl_VertexID], 0.0, 1.0);
    iterated_color = col[gl_VertexID];
}

#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

void main() {
    color = vec4(iterated_color, 1);
}
#endif // FRAGMENT_SHADER

GLSL