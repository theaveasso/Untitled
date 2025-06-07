CHUNK_WIDTH  :: 16;
CHUNK_HEIGHT :: 1;
CHUNK_DEPTH  :: 16;
CHUNK_RENDER_DISTANCE :: 4;

Vertex_Direction :: enum u8 {
    Vertex_Direction_Front;
    Vertex_Direction_Back;
    Vertex_Direction_Top;
    Vertex_Direction_Bottom;
    Vertex_Direction_Left;
    Vertex_Direction_Right;
    Vertex_Direction_Count;
}

Block_Specification :: struct {
    type      : Block_Type;
    textures  : Face_Texture; // Top, Bottom, Side
}

g_block_specifications : []Block_Specification;

block_specification_init :: () {
    g_block_specifications = NewArray(xx Block_Type.Block_Type_Count, Block_Specification);

    spec : Block_Specification = ---;
    spec.type = .Block_Type_Air;
    set\   _block_specification(*spec, .[block_texture_coord(0), block_texture_coord(0), block_texture_coord(0)]);
    g_block_specifications[Block_Type.Block_Type_Air] = spec;

    spec = .{};
    spec.type = .Block_Type_Grass;
    set\   _block_specification(*spec, .[block_texture_coord(3), block_texture_coord(3), block_texture_coord(2)]);
    g_block_specifications[Block_Type.Block_Type_Grass] = spec;

    spec = .{};
    spec.type = .Block_Type_Dirt;
    set\   _block_specification(*spec, .[block_texture_coord(0), block_texture_coord(3), block_texture_coord(2)]);
    g_block_specifications[Block_Type.Block_Type_Dirt] = spec;
}

block_specification_find :: (specs : *[]Block_Specification, type : Block_Type) -> bool, Block_Specification {
    for specs.* if it.type == type return true, it; 
    return false, .{};
}

set_\   block_specification :: (using spce : *Block_Specification, uv : [3]Vector2) {
    textures.Face_Texture_Top    = uv[0];
    textures.Face_Texture_Bottom = uv[1];
    textures.Face_Texture_Side   = uv[2];
}

Block_Type :: enum u8 {
    Block_Type_Air;
    Block_Type_Grass;
    Block_Type_Dirt;
    Block_Type_Count;
}

Block :: struct {
    type     : Block_Type = .Block_Type_Air;
    position : Vector3;
}

Chunk :: struct {
    position : Vector2;
    data     : [CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_DEPTH]Block;

    // GL Mesh
    vao, vbo, ibo : GLuint;
    vertices : [..]Vertex;
    indices  : [..]u32;

    vertices_count, indices_count : s32;
}

World :: struct {
    fnl     : FNL_State;

    chunks  : [..]Chunk;

    program : GLuint;
}

make_world :: () -> bool, World {
    using world : World;
    fnl.noise_type   = .Noise_Type_Perlin;
    fnl.fractal_type = .Fractal_Type_FBM;
    fnl.frequency    = 0.3;

    success: bool;
    success, program = create_shader_program(VOXEL_VERTEX_SHADER, VOXEL_FRAGMENT_SHADER);
    if !success { log_error("Could not create voxel program"); return false, .{}; }

    glUseProgram(program);
    set_uniform(program, "map", int, 0);

    array_add(*chunks, make_chunk(*world, .{g_camera.position.x, g_camera.position.z}));
    return success, world;
}

chunk_index :: inline (x : s64, y : s64, z : s64) -> s64 { return (y * CHUNK_DEPTH * CHUNK_WIDTH) + (z * CHUNK_WIDTH) + x; }

make_chunk :: (world : *World, position: Vector2) -> Chunk {
    load_meshes :: inline (using chunk : *Chunk) {
        array_reserve(*vertices, CHUNK_DEPTH * CHUNK_HEIGHT * CHUNK_DEPTH * 24);
        array_reserve(*indices,  CHUNK_DEPTH * CHUNK_HEIGHT * CHUNK_DEPTH * 36);

        for z : 0..CHUNK_DEPTH - 1 {
            for x : 0..CHUNK_WIDTH - 1 {
                for y : 0..CHUNK_HEIGHT - 1 {
                    world_x := position.x * CHUNK_WIDTH +  x;
                    world_z := position.y * CHUNK_HEIGHT + z;
                    world_y := y;
                    load_block_all_faces(*data[chunk_index(x, y, z)], .{xx world_x, xx world_y, xx world_z}, *chunk.vertices, *chunk.indices);
                }
            }
        }
    }

    load_blocks :: inline (using chunk : *Chunk) {
        for z : 0..CHUNK_DEPTH - 1 {
            for x : 0..CHUNK_WIDTH - 1 {
                for y : 0..CHUNK_HEIGHT - 1 {
                    data[chunk_index(x, y, z)].type = ifx xx y > (sin(xx x / 5.0) + sin(xx z / 5.0) * 8 + 20) then .Block_Type_Air else .Block_Type_Grass;
                    data[chunk_index(x, y, z)].position = .{position.x + x, xx y, position.y + z};
                }
            }
        }
    }

    setup_gl_state :: inline (using chunk: *Chunk) {
        glGenVertexArrays(1, *vao);
        glBindVertexArray(vao);
        defer glBindVertexArray(0);

        glGenBuffers(1, *vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * vertices.count, vertices.data, GL_STATIC_DRAW);

        glGenBuffers(1, *ibo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(u32) * indices.count, indices.data, GL_STATIC_DRAW);

        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)0);
        glEnableVertexAttribArray(0);

        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) size_of(Vector3));
        glEnableVertexAttribArray(1);

        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) (size_of(Vector3) * 2));
        glEnableVertexAttribArray(2);

        vertices_count = xx vertices.count;
        indices\_count = xx indices.count;

        array_free(vertices);
        array_free(indices);
    }

    chunk : Chunk;
    chunk.position = position;
    load_blocks(*chunk);
    load_meshes(*chunk);
    setup_gl_state(*chunk);

    return chunk;
}

immediate_chunk :: (using world : *World) {
    chunk_x := floor(g_camera.position.x / CHUNK_WIDTH);
    chunk_z := floor(g_camera.position.z / CHUNK_DEPTH);

    // chunk_added := false;
    // for z : cast(int)(chunk_z - CHUNK_RENDER_DISTANCE)..cast(int)(chunk_z + CHUNK_RENDER_DISTANCE) {
    //     for x : cast(int)(chunk_x - CHUNK_RENDER_DISTANCE)..cast(int)(chunk_x + CHUNK_RENDER_DISTANCE) {
    //         found := false;
    //         for chunks {
    //             if it.position.x == xx x && it.position.y == xx z { found = true; break; }
    //         }

    //         if !found && !chunk_added {
    //             array_add(*chunks, make_chunk(world, .{xx x, xx z}));
    //             chunk_added = true;
    //         }
    //     }
    // }

    glUseProgram(program);
    set_uniform(program, "viewproj", Matrix4, g_camera.view_proj);
    for chunks {
        draw_chunk(*it);
    }
}

draw_chunk :: (using chunk: *Chunk) {
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, g_map_block.gl_handle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glDrawElements(g_drawmode, xx indices_count, GL_UNSIGNED_INT, null);
}

Face_Texture   :: struct  {
    Face_Texture_Top    : Vector2;
    Face_Texture_Bottom : Vector2;
    Face_Texture_Side   : Vector2;
}

Face_Direction :: enum u8 {
    Face_Direction_Top;
    Face_Direction_Bottom;
    Face_Direction_Left;
    Face_Direction_Right;
    Face_Direction_Front;
    Face_Direction_Back;
}

CANVAS_SIZE :: 16;
CELL\ _SIZE :: 1.0 / CANVAS_SIZE;

block_texture_coord :: (_x : u8 = 0, _y : u8 = 0) -> Vector2 {
    x := _x % CANVAS_SIZE;
    y := _y % CANVAS_SIZE;
    return .{x * CELL_SIZE, y * CELL_SIZE};
}

load_block_\   face  :: (using block : *Block, _position : Vector3, direction : Face_Direction, vertices : *[..]Vertex, indices : *[..]u32) {
    if type == .Block_Type_Air return;

    ok, spec := block_specification_find(*g_block_specifications, type);
    offset := Vector2.{0.0, 0.0};

    if direction == {
        case .Face_Direction_Top;    offset += spec.textures.Face_Texture_Top;
        case .Face_Direction_Bottom; offset += spec.textures.Face_Texture_Bottom;
        case;                        offset += spec.textures.Face_Texture_Side;
    }

    uv_coords := Vector2.[
        offset + .{0.0,       CELL_SIZE}, // Bottom Left
        offset + .{CELL_SIZE, CELL_SIZE}, // Bottom Right
        offset + .{CELL_SIZE,       0.0}, // Top Right
        offset + .{0.0,             0.0}, // Top Left
    ];

    index_offset := vertices.count;
    for i : 0..3 {
        array_add(vertices, .{position=_position + FACE_VERTICES[FACE_INDICES[direction][i]], uv=uv_coords[i], normal=BLOCK_NORMAL[direction]});
    }

    array_add(indices, cast(u32)(index_offset + 0));
    array_add(indices, cast(u32)(index_offset + 1));
    array_add(indices, cast(u32)(index_offset + 2));

    array_add(indices, cast(u32)(index_offset + 0));
    array_add(indices, cast(u32)(index_offset + 2));
    array_add(indices, cast(u32)(index_offset + 3));
}

load_block_all_faces :: (block: *Block, position : Vector3, vertices : *[..]Vertex, indices : *[..]u32) {
    load_block_face(block, position, .Face_Direction_Top,    vertices, indices);
    load_block_face(block, position, .Face_Direction_Bottom, vertices, indices);
    load_block_face(block, position, .Face_Direction_Left,   vertices, indices);
    load_block_face(block, position, .Face_Direction_Right,  vertices, indices);
    load_block_face(block, position, .Face_Direction_Front,  vertices, indices);
    load_block_face(block, position, .Face_Direction_Back,   vertices, indices);
}

#scope_file

FACE_VERTICES := Vector3.[
    .{0.0, 0.0, 0.0}, // Bottom front left
    .{1.0, 0.0, 0.0}, // Bottom front right
    .{1.0, 1.0, 0.0}, // Top front right
    .{0.0, 1.0, 0.0}, // Top front left
    .{0.0, 0.0, 1.0}, // Bottom back left
    .{1.0, 0.0, 1.0}, // Bottom back right
    .{1.0, 1.0, 1.0}, // Top back right
    .{0.0, 1.0, 1.0}, // Top back left
];

FACE_INDICES  : [6][4]u32 = .[
    .[3, 2, 6, 7], // Top
    .[1, 0, 4, 5], // Bottom
    .[0, 1, 2, 3], // Front
    .[5, 4, 7, 6], // Back
    .[2, 6, 5, 1], // Right
    .[7, 3, 0, 4], // Left
]; 

BLOCK_NORMAL : [6]Vector3 = .[
    .{ 0.0,  1.0,  0.0}, // Top
    .{ 0.0, -1.0,  0.0}, // Bottom
    .{ 0.0,  0.0, -1.0}, // Front
    .{ 0.0,  0.0,  1.0}, // Back
    .{ 1.0,  0.0,  0.0}, // Right
    .{-1.0,  0.0,  0.0}, // Left
];