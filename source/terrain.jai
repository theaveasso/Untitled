Terrain :: struct {
    heightmap       : []float;
    triangle_list   : Triangle_List;

    texture_tiles   : [MAX_TEXTURE_TILES]Terrain_Tile;
    texture_scale   := 1.0;

    terrain_size            : int;
    world_scale             : float;
    min_height, max_height  : float;

    program         : Shader_Program(Terrain_Uniforms);
}

Terrain_Uniforms :: struct {
    viewproj        : GLint = -1;
    max_height      : GLint = -1;
    diffuse_texture : GLint = -1;
}

Texture_Height_Description :: struct {
    low     : float;
    optimal : float;
    hight   : float;
}

Terrain_Tile :: struct {
    bitmap : NSimp.Bitmap;
    height_desc : Texture_Height_Description;
}

terrain_init :: (_scale: float = 4.0, _terrain_size: int = 32, _min_height: float, _max_height: float, fnl_state: *FNL_State) -> Terrain {
    using terrain : Terrain;
    world_scale  = _scale;
    min_height   = _min_height;
    max_height   = _max_height;
    terrain_size = _terrain_size;

    // terrain_textures_path : [MAX_TEXTURE_TILES]string = .[
    //     "resources/assets/terrain/Ground_1.jpg",
    //     // "resources/assets/terrain/Ground_2.jpg",
    //     // "resources/assets/terrain/Ground_3.jpg",
    //     // "resources/assets/terrain/Snow_1.jpg",
    // ];

    // for terrain_textures_path {
    //     ok := NSimp.bitmap_load(*texture_tiles[it_index].bitmap, it);
    //     ok_or_exit(ok, "Could not load bitmap from file '%'\n", it);
    // }

    program.gl_handle = create_shader_program(TERRAIN_SHADER);
    ok_or_exit(program.gl_handle != -1, "Could not create shader program");

    program.uniforms.viewproj    = gluniform_loc(program.gl_handle, "viewproj");
    program.uniforms.max_height  = gluniform_loc(program.gl_handle, "max_height");
    program.uniforms.diffuse_texture = gluniform_loc(program.gl_handle, "diffuse_texture");

    terrain_generate(*terrain, fnl_state);

    glUseProgram(program.gl_handle);

    gluniform_set(float, program.uniforms.max_height, MAX_TERRAIN_HEIGHT);
    gluniform_set(int,   program.uniforms.diffuse_texture,             0);

    glUseProgram(0);

    glGenVertexArrays(1, *triangle_list.vao);
    glBindVertexArray(triangle_list.vao);

    glGenBuffers(1, *triangle_list.vbo);
    glBindBuffer(GL_ARRAY_BUFFER, triangle_list.vbo);

    glGenBuffers(1, *triangle_list.ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, triangle_list.ibo);

    terrain_populate_buffer(*terrain);

    glattrib_set(0, 3, GL_FLOAT, GL_FALSE, size_of(Triangle_List.Vertex), cast(*void)0);
    glattrib_set(1, 2, GL_FLOAT, GL_FALSE, size_of(Triangle_List.Vertex), cast(*void) size_of(Vector3));

    glBindVertexArray(0);

    return terrain;
}

terrain_draw :: (using terrain: *Terrain) {
    glUseProgram(program.gl_handle);
    defer glUseProgram(0);

    glBindVertexArray(triangle_list.vao);
    defer glBindVertexArray(0);
    // glActiveTexture(GL_TEXTURE0);
    // glBindTexture(GL_TEXTURE_2D, texture_tiles[0].image.gl_handle);

    gluniform_set(Matrix4, program.uniforms.viewproj, g_camera.view_proj);

    glDrawElements(triangle_list.primitive, xx triangle_list.indices_count, GL_UNSIGNED_INT, null);
}

terrain_generate :: inline (using terrain: *Terrain, fnl_state: *FNL_State) {
    heightmap = NewArray(xx (terrain_size * terrain_size), float);

    // Noie config
    fnl_base, fnl_ridge, fnl_erosion, fnl_warp : FNL_State;
    fnl_base\  .frequency = 0.02;
    fnl_base\  .octaves = 4;
    fnl_base\  .fractal_type = .FBM;

    fnl_ridge\ .frequency = 0.08;
    fnl_ridge\ .octaves = 3;
    fnl_base\  .fractal_type = .RIDGED;

    fnl_erosion.frequency = 0.08;
    fnl_warp\  .frequency = 0.005;

    // Noise
    lmin, lmax : float = ---;
    for z : 0..terrain_size - 1 {
        for x : 0..terrain_size - 1 {
            xf := cast(float) x;
            zf := cast(float) z;

            // domain warp offset
            warp_x := get_noise_2d(*fnl_warp, xf, zf) * 8.0;
            warp_z := get_noise_2d(*fnl_warp, xf + 100, zf + 100) * 8.0;

            // base noise with domain warp
            base   := get_noise_2d(*fnl_base, xf + warp_x, zf + warp_z);

            // ridge noise for mountain peaks
            ridge  := 1.0 - abs(get_noise_2d(*fnl_ridge, xf, zf)); 

            erosion_mask := get_noise_2d(*fnl_erosion, xf, zf);

            height := base * 0.6 + ridge * 0.4;
            height *= erosion_mask;

            heightmap[z * terrain_size + x] = height;
            if lmin > height lmin = height;
            if lmax < height lmax = height;
        }
    }

    // Normalize
    for i : 0..heightmap.count - 1{
        heightmap[i] = (heightmap[i] - lmin) / (lmax - lmin);
        heightmap[i] *= MAX_TERRAIN_HEIGHT;
    }
}

terrain_interpolated_height_at :: inline (using terrain : *Terrain, x : int, z : int) -> float {

}

terrain_height_at :: inline (using terrain : *Terrain, x : int, z : int) -> float {
    return heightmap[xx (z * terrain_size + x)];
}

terrain_populate_buffer :: (using terrain : *Terrain) {
    vertices : [..]Triangle_List.Vertex;
    defer array_free(vertices);
    array_reserve(*vertices, terrain_size * terrain_size);

    terrain_vertices_init(terrain, *vertices);

    indices  : [..]u32;
    defer array_free(indices);
    array_reserve(*indices, (terrain_size - 1) * (terrain_size - 1) * 6);

    terrain_indices_init(terrain, *indices);

    glBufferData(GL_ARRAY_BUFFER, size_of(Triangle_List.Vertex) * vertices.count, vertices.data, GL_STATIC_DRAW);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);
}

terrain_vertices\_init :: inline (using terrain : *Terrain, vertices : *[..]Triangle_List.Vertex) {
    for z : 0..terrain_size - 1 {
        for x : 0..terrain_size - 1 {
            pos := Vector3.{x * world_scale, terrain_height_at(terrain, x, z), z * world_scale};
            uv  := Vector2.{texture_scale * x / terrain_size, texture_scale * z / terrain_size};
            array_add(vertices, Triangle_List.Vertex.{position=pos, uv=uv});
        }
    }
    triangle_list.vertices_count = vertices.count;
}

terrain_indices_init :: inline (using terrain : *Terrain, indices  : *[..]u32) {
    for z : 0..terrain_size - 2 {
        for x : 0..terrain_size - 2 {
            bl :=  z    * terrain_size + x;
            tl := (z+1) * terrain_size + x;
            tr := (z+1) * terrain_size + (x+1);
            br :=  z    * terrain_size + (x+1);

            array_add(indices, xx bl);
            array_add(indices, xx tl);
            array_add(indices, xx tr);

            array_add(indices, xx bl);
            array_add(indices, xx tr);
            array_add(indices, xx br);
        }
    }
    triangle_list.indices_count = indices.count;
}

terrain_texture_generate :: (using terrain : *Terrain) {
    calculate_texture_regions :: (using terrain : *Terrain) {
    }

    BPP := 3; // bytes per pixel
    // int texture_bytes = texture_size * texture_size * BPP;
}

TERRAIN_SHADER :: #string GLSL
OUT_IN vec4 iterated_color;
OUT_IN vec2 TexCoords;

#ifdef VERTEX_SHADER
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 uv;

uniform mat4  viewproj;
uniform float max_height;

vec3 terrain_color(float h) {
    h /= max_height;
    // if (h < 0.2)        return vec3(0.1, 0.3, 0.8);
    // else if (h < 0.3)   return vec3(0.8, 0.8, 0.3);
    // else if (h < 0.6)   return vec3(0.1, 0.6, 0.2);
    // else if (h < 0.85)  return vec3(0.4, 0.3, 0.2);
    // else                return vec3(1.0, 1.0, 1.0);
    return vec3(h, h, h);
}

void main() {
    gl_Position = viewproj * vec4(position, 1.0);
    iterated_color = vec4(terrain_color(position.y), 1.0);
    TexCoords = uv.xy;
}

#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;

void main() {
    vec4 color_tex = iterated_color * texture(diffuse_texture, TexCoords);
    if (color_tex.a < 0.1) discard;

    color = color_tex;
}
#endif // FRAGMENT_SHADER
GLSL

MAX_TERRAIN_HEIGHT  :: cast(float)128.0;
MAX_TEXTURE_TILES   :: 1;