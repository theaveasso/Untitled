save_terrain_file :: "terrain.dat";
save_terrain_path :: "resources/heightmap";

g_terrain_program : GLuint;
g_terrain_vao, g_terrain_vbo, g_terrain_ibo : GLuint;

Terrain_Strategy :: enum u8 {
    Flat\_Formation;
    Fault_Formation;
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
    data        : []float;
    row_count   : u64;
    col_count   : u64;

    vertices    : []Vertex;
    indices     : []u32;
}

terrain_height_at :: (terrain : *Terrain, x : u64, z : u64) -> float {
    return terrain.data[z * terrain.row_count + x];
}

make_terrain_vertex :: (terrain : *Terrain, x : u64, z : u64) -> Terrain.Vertex {
    y := terrain_height_at(terrain, x, z);
    return .{position=.{xx (x * terrain.world_scale), y, xx (z * terrain.world_scale)}};
}

terrain_save_to_file :: (filename : string, strategy : Terrain_Strategy = .Flat_Formation, rows : u32 = 10, cols : u32 = 10, iter : u32 = 10, min_height : float = -1, max_height : float = 1) {
    terrain : Terrain;
    terrain.row_count = rows;
    terrain.col_count = cols;

    terrain.data = NewArray(rows * cols, float);

    if strategy == {
        case .Flat\_Formation; terrain_flat\_formation(*terrain);
        case .Fault_Formation; terrain_fault_formation(*terrain, iter, min_height, max_height);
    }

    file, success := file_open(filename, for_writing=true, keep_existing_content=false);
    if !success { log_error("Could not read terrain data %\n", filename); exit(1); };

    defer file_close(*file);

    row_count := cast(u64) rows;
    file_write(*file, *row_count, size_of(u64));

    col_count := cast(u64) cols;
    file_write(*file, *col_count, size_of(u64));

    file_write(*file, terrain.data.data, xx (size_of(float) * terrain.row_count * terrain.col_count));
}

terrain_load_from_file :: (terrain : *Terrain, filename : string) {
    file, success := file_open(filename);
    if !success { log_error("Could not read terrain data %\n", filename); exit(1); };

    defer file_close(*file);

    file_read(*file, *terrain.row_count, size_of(u64));
    file_read(*file, *terrain.col_count, size_of(u64));

    total_count := terrain.row_count * terrain.col_count;
    terrain.data = NewArray(xx total_count, float);
    file_read(*file, terrain.data.data, cast(s64) (size_of(float) * total_count));
}

terrain_triangle_list_init :: (terrain : *Terrain) {
    glGenVertexArrays(1, *g_terrain_vao);
    glBindVertexArray(g_terrain_vao);
    defer glBindVertexArray(0);

    glGenBuffers(1, *g_terrain_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_terrain_vbo);

    glGenBuffers(1, *g_terrain_ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_terrain_ibo);

    terrain.vertices = NewArray(cast(s64) (terrain.row_count * terrain.col_count), Terrain.Vertex);
    terrain.indices  = NewArray((cast(s64) terrain.row_count - 1) * (cast(s64) terrain.col_count - 1) * 6, u32);

    // populate buffer data
    v_index := 0;
    for z : 0..terrain.col_count - 1 {
        for x : 0..terrain.row_count - 1 {
            terrain.vertices[v_index] = make_terrain_vertex(terrain, x, z);
            assert(v_index < terrain.vertices.count);

            v_index += 1;
        }
    }
    assert(v_index == terrain.vertices.count);

    i_index := 0;
    for z : 0..terrain.col_count - 2 {
        for x : 0..terrain.row_count - 2 {
            index_bl := cast(u32) (z * terrain.row_count + x);
            index_tl := cast(u32) ((z + 1) * terrain.row_count + x);
            index_tr := cast(u32) ((z + 1) * terrain.row_count + x + 1);
            index_br := cast(u32) (z * terrain.row_count + x + 1);

            terrain.indices[i_index + 0] = index_bl;
            terrain.indices[i_index + 1] = index_tl;
            terrain.indices[i_index + 2] = index_tr;

            terrain.indices[i_index + 3] = index_bl;
            terrain.indices[i_index + 4] = index_tr;
            terrain.indices[i_index + 5] = index_br;

            i_index += 6;
        }
    }
    assert(i_index == terrain.indices.count);

    glBufferData(GL_ARRAY_BUFFER, size_of(Terrain.Vertex) * terrain.vertices.count, terrain.vertices.data, GL_STATIC_DRAW);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * terrain.indices.count, terrain.indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Terrain.Vertex), cast(*void)0);
}

terrain_triangle_list_draw :: (terrain : *Terrain) {
    glUseProgram(g_terrain_program);
    glBindVertexArray(g_terrain_vao);

    set_uniform(g_terrain_program, "viewproj", Matrix4, g_camera.view_proj);

    glDrawElements(GL_TRIANGLES, cast(u32) terrain.indices.count, GL_UNSIGNED_INT, null);
    glBindVertexArray(0);
}

TERRAIN_VERTEX_SHADER :: #string GLSL
#version 450 core

layout (location = 0) in vec3 position;

out vec4 v_color;

uniform mat4 viewproj;

void main() {
    gl_Position = viewproj * vec4(position, 1.0);

    float gray = clamp(0.3 + position.y * 0.2, 0.0, 1.0);
    v_color = vec4(gray, gray, gray, 1.0);
}
GLSL

TERRAIN_FRAGMENT_SHADER :: #string GLSL
#version 450 core

in vec4 v_color;

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
    for z : 0..terrain.col_count - 1 {
        for x : 0..terrain.row_count - 1 {
            terrain.data[z * terrain.row_count + x] = 0;
        }
    }
}

terrain_fault_formation :: (terrain : *Terrain, iter : u32, min_height : float, max_height : float) {
    get_random_terrain_points :: (row : u64, col : u64, p1 : *Terrain_Point, p2 : *Terrain_Point) {
        p1.* = .{xx (floor(random_get_zero_to_one() * row)), xx (floor(random_get_zero_to_one() * col))};

        for i : 0..1000 {
            p2.* = .{xx (floor(random_get_zero_to_one() * row)), xx (floor(random_get_zero_to_one() * col))};
            if !is_equal(p1, p2) break;

            assert(i != 999);
        }
    }

    delta_height := max_height - min_height;

    for i : 1..iter {
        iteration_ratio : float = cast(float) i / iter;
        height := max_height - iteration_ratio * delta_height;

        p1, p2 : Terrain_Point;
        get_random_terrain_points(terrain.row_count, terrain.col_count, *p1, *p2);

        dir_x := p2.x - p1.x;
        dir_z := p2.z - p1.z;

        for z : 0..terrain.col_count - 1 {
            for x : 0..terrain.row_count - 1 {
                dx := cast(float)(xx x - p1.x);
                dz := cast(float)(xx z - p1.z);
                cross := dx * dir_z - dir_x * dz;
                if cross > 0 {
                    terrain.data[z * terrain.row_count + x] += height;
                }
            }
        }
    }
}
