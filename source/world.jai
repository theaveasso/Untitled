CHUNK_WIDTH  :: 16;
CHUNK_HEIGHT :: 256;
CHUNK_DEPTH  :: 16;

Block_Type :: enum u8 {
    Block_Type_Air;
    Block_Type_Grass;
}

Block :: struct {
    type : Block_Type = .Block_Type_Air;
}

Chunk :: struct {
    position : Vector2;
    data     : [CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_DEPTH]Block;
}

World :: struct {
    fnl    : FNL_State;

    chunks : [..]Chunk;
}

make_world :: () -> World {
    using world : World;
    fnl.noise_type   = .Noise_Type_Perlin;
    fnl.fractal_type = .Fractal_Type_FBM;
    fnl.frequency    = 0.3;

    array_reserve(*chunks, 64);

    array_add(*chunks, make_chunk(*world, .{g_camera.position.x, g_camera.position.z}));
    return world;
}

make_chunk :: (world : *World, position: Vector2) -> Chunk {
    chunk : Chunk;

    for z : 0..CHUNK_DEPTH - 1 {
        for x : 0..CHUNK_WIDTH - 1 {
            noise_val := get_noise_2d(*world.fnl, xx x, xx z);
            height := cast(int)((noise_val + 1.0) * 0.5 * (80 - 1));
            for y : 0..CHUNK_HEIGHT - 1 {
                if y <= height chunk.data[(y * CHUNK_WIDTH * CHUNK_DEPTH) + z * CHUNK_WIDTH + x].type = .Block_Type_Grass;
            }
        }
    }

    return chunk;
}