save_terrain_file :: "terrain.dat";
save_terrain_path :: "resources/heightmap";

g_terrain_program : GLuint;
g_terrain_vao, g_terrain_vbo, g_terrain_ibo : GLuint;

Terrain_Strategy :: enum u8 {
    Flat\   _Formation;
    Fault\  _Formation;
    Midpoint_Displacement;
}

Terrain_Point :: struct {
    x : int;    // OpenGL coordinate system
    z : int;    // OpenGL coordinate system
}

Terrain :: struct {
    Vertex :: struct {
        position : Vector3;
    }

    world_scale : float = 1.0;
    size        : int;
    min_height  : float;
    max_height  : float;

    data        : []float;

    vertices    : []Vertex;
    indices     : []u32;
}

terrain_height_at :: (using terrain : *Terrain, x : int, z : int) -> float {
    return data[z * size + x];
}

make_terrain_vertex :: (using terrain : *Terrain, x : int, z : int) -> Terrain.Vertex {
    y := terrain_height_at(terrain, x, z);
    return .{position=.{xx (x * world_scale), y, xx (z * world_scale)}};
}

terrain_save_to_file :: (filename : string, strategy : Terrain_Strategy = .Flat_Formation, _size: u32 = 10, iter : u32 = 10, roughness : float = 2.0, _min_height : float = -1, _max_height : float = 1) {
    using terrain : Terrain;
    size       = _size;
    terrain.data = NewArray(size * size, float);

    if strategy == {
        case .Flat\_Formation;       terrain_flat\_formation(*terrain);
        case .Fault_Formation;       terrain_fault_formation(*terrain, iter);
        case .Midpoint_Displacement; terrain_mp_displacement(*terrain, roughness);
    }

    for data { 
        if it < min_height min_height = it; 
        if it > max_height max_height = it; 
    }

    file, success := file_open(filename, for_writing=true, keep_existing_content=false);
    if !success { log_error("Could not read terrain data %\n", filename); exit(1); };

    defer file_close(*file);

    file_write(*file, *size, size_of(u32));
    file_write(*file, *min_height, size_of(float));
    file_write(*file, *max_height, size_of(float));
    file_write(*file, data.data, xx (size_of(float) * size * size));
}

terrain_load_from_file :: (terrain : *Terrain, filename : string) {
    file, success := file_open(filename);
    if !success { log_error("Could not read terrain data %\n", filename); exit(1); };

    defer file_close(*file);

    file_read(*file, *terrain.size , size_of(u32));
    file_read(*file, *terrain.min_height, size_of(float));
    file_read(*file, *terrain.max_height, size_of(float));

    terrain.data = NewArray(xx (terrain.size * terrain.size), float);
    file_read(*file, terrain.data.data, xx (size_of(float) * terrain.size * terrain.size));
}

terrain_triangle_list_init :: (using terrain : *Terrain) {
    glGenVertexArrays(1, *g_terrain_vao);
    glBindVertexArray(g_terrain_vao);
    defer glBindVertexArray(0);

    glGenBuffers(1, *g_terrain_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_terrain_vbo);

    glGenBuffers(1, *g_terrain_ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_terrain_ibo);

    vertices = NewArray(xx (size * size), Terrain.Vertex);
    indices  = NewArray(xx ((size - 1) * (size - 1) * 6), u32);

    // populate buffer data
    v_index := 0;
    for z : 0..size - 1 {
        for x : 0..size - 1 {
            vertices[v_index] = make_terrain_vertex(terrain, xx x, xx z);
            assert(v_index < vertices.count);

            v_index += 1;
        }
    }
    assert(v_index == vertices.count);

    i_index := 0;
    for z : 0..size - 2 {
        for x : 0..size - 2 {
            index_bl := z * size + x;
            index_tl := (z + 1) * size + x;
            index_tr := (z + 1) * size + x + 1;
            index_br := z * size+ x + 1;

            indices[i_index + 0] = xx index_bl;
            indices[i_index + 1] = xx index_tl;
            indices[i_index + 2] = xx index_tr;

            indices[i_index + 3] = xx index_bl;
            indices[i_index + 4] = xx index_tr;
            indices[i_index + 5] = xx index_br;

            i_index += 6;
        }
    }
    assert(i_index == indices.count);

    glBufferData(GL_ARRAY_BUFFER, size_of(Terrain.Vertex) * vertices.count, vertices.data, GL_STATIC_DRAW);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Terrain.Vertex), cast(*void)0);
}

terrain_triangle_list_draw :: (using terrain : *Terrain) {
    glUseProgram(g_terrain_program);
    glBindVertexArray(g_terrain_vao);

    set_uniform(g_terrain_program, "viewproj", Matrix4, g_camera.view_proj);
    set_uniform(g_terrain_program, "min_height", float, min_height);
    set_uniform(g_terrain_program, "max_height", float, max_height);

    glDrawElements(GL_TRIANGLES, cast(u32) indices.count, GL_UNSIGNED_INT, null);
    glBindVertexArray(0);
}

TERRAIN_VERTEX_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec3 position;

out vec4 v_color;
out vec3 world_pos;

uniform mat4 viewproj;
uniform float min_height;
uniform float max_height;

void main() {
    gl_Position = viewproj * vec4(position, 1.0);
    world_pos = position;

    float height_ratio = (position.y - min_height) / (max_height - min_height);
    height_ratio = clamp(height_ratio, 0.0, 1.0);
    v_color = vec4(vec3(height_ratio), 1.0);
}
GLSL

TERRAIN_FRAGMENT_SHADER :: #string GLSL
#version 450 core

in vec4 v_color;
in vec3 world_pos;

out vec4 frag_color;

void main() {
    frag_color = v_color;
}

GLSL

#scope_file

is_equal :: (tp1 : *Terrain_Point, tp2 : *Terrain_Point) -> bool {
    return ((tp1.x == tp2.x) && (tp1.z == tp2.z));
}

terrain_flat_formation :: (terrain : *Terrain) {
    for z : 0..terrain.size - 1 {
        for x : 0..terrain.size - 1 {
            terrain.data[z * terrain.size + x] = 0;
        }
    }
}

terrain_fault_formation :: (using terrain : *Terrain, iter : u32) {
    get_random_terrain_points :: (size : int, p1 : *Terrain_Point, p2 : *Terrain_Point) {
        p1.* = .{xx (floor(random_get_zero_to_one() * size)), xx (floor(random_get_zero_to_one() * size))};

        for i : 0..1000 {
            p2.* = .{xx (floor(random_get_zero_to_one() * size)), xx (floor(random_get_zero_to_one() * size))};
            if !is_equal(p1, p2) break;

            assert(i != 999);
        }
    }

    delta_height := max_height - min_height;

    for i : 1..iter {
        iteration_ratio : float = cast(float) i / iter;
        height := max_height - iteration_ratio * delta_height;

        p1, p2 : Terrain_Point;
        get_random_terrain_points(size, *p1, *p2);

        dir_x := p2.x - p1.x;
        dir_z := p2.z - p1.z;

        for z : 0..size - 1 {
            for x : 0..size - 1 {
                dx := cast(float)(xx x - p1.x);
                dz := cast(float)(xx z - p1.z);
                cross := dx * dir_z - dir_x * dz;
                if cross > 0 {
                    data[z * size + x] += height;
                }
            }
        }
    }
}

terrain_mp_displacement :: (using terrain : *Terrain, roughness : float) {
    assert(data.data  != null);
    assert(data.count == (size * size));

    next_pow2 :: inline (x : int) -> int {
        ret := 1;
        if x == 1 return 2;
        while ret < x ret = ret * 2;
        return ret;
    }

    diamond_step :: inline (using terrain : *Terrain, rec_size : int, current_height : float) {
        half := cast(int) rec_size / 2;

        z := 0;
        while z <= size - 1 { defer z += rec_size;
            x := 0;
            while x <= size - 1 { defer x += rec_size;
                next_x := xx (x + rec_size) % size;
                next_z := xx (z + rec_size) % size;
                mid\_x := xx (x + half)     % size;
                mid\_z := xx (z + half)     % size;

                if next_x < x  next_x = size - 1;
                if next_z < z  next_z = size - 1;

                tl := terrain_height_at(terrain,      x,      z);
                tr := terrain_height_at(terrain, next_x,      z);
                bl := terrain_height_at(terrain,      x, next_z);
                br := terrain_height_at(terrain, next_x, next_z);

                midpoint := (tl + tr + bl + br) / 4.0;
                rand     := random_get_within_range(min=-current_height, max=current_height);
                data[mid_z * size + mid_x] = midpoint + rand;
            }
        }
    }

    square_step :: inline (using terrain : *Terrain, rec_size : int, current_height : float) {
        half := cast(int) rec_size / 2;

        z := 0;
        while z <= size - 1{ defer z += rec_size;
            x := 0;
            while x <= size - 1{ defer x += rec_size;
                next_x := xx (x + rec_size) % size;
                next_z := xx (z + rec_size) % size;
                mid\_x := xx (x + half)     % size;
                mid\_z := xx (z + half)     % size;

                if next_x < x  next_x = size - 1;
                if next_z < z  next_z = size - 1;

                prev_mid_x := (x - half + size) % size;
                prev_mid_z := (z - half + size) % size;

                curr_tl := terrain_height_at(terrain,      x,      z); // current  top left
                curr_tr := terrain_height_at(terrain, next_x,      z); // current  top right
                curr_bl := terrain_height_at(terrain,      x, next_z); // current  bottom left
                curr_cx := terrain_height_at(terrain, mid\_x, mid\_z); // current  center

                prev_xc := terrain_height_at(terrain,      mid_x, prev_mid_z); // previous center x
                prev_zc := terrain_height_at(terrain,      prev_mid_x, mid_z); // previous center z

                curr_lm := (curr_tl + curr_cx + curr_bl + prev_xc) / 4.0 + random_get_within_range(min=-current_height, max=current_height);
                curr_tm := (curr_tl + curr_cx + curr_tr + prev_zc) / 4.0 + random_get_within_range(min=-current_height, max=current_height);

                data[mid_z * size + x] = curr_lm;
                data[z * size + mid_x] = curr_tm;
            }
        }
    }

    rec\   _size   := next_pow2(size);
    current_height := cast(float) (rec_size / 2.0);
    height\_reduce := pow(2.0, -roughness);

    while rec_size > 0 {
        diamond_step(terrain, rec_size, current_height);
        square\_step(terrain, rec_size, current_height);
        
        rec_size /= 2;
        current_height *= height_reduce;
    }

}
