Mesh_Data :: struct ($T: Type) {
    vertices : []T;
    indices  : []u32;
}

make_sphere :: (radius: float = 1.0, levels: u32 = 20, slices : u32 = 20, color : Vector4 = .{0.0, 0.8, 0.0, 1.0}) -> Mesh_Data(Immediate_Vertex) {
    using sphere : Mesh_Data(Immediate_Vertex);

    return sphere;
}

make_box :: (width : float = 1.0, height : float = 1.0, depth : float = 1.0, color : Vector4 = .{0.0, 0.8, 0.0, 1.0}) -> Mesh_Data(Immediate_Vertex) {
    using box : Mesh_Data(Immediate_Vertex); 
    vertices = NewArray(24, Immediate_Vertex);
    indices  = NewArray(36, u32);

    half_width  := width / 2.0;
    half_height := height / 2.0;
    half_depth  := depth / 2.0;

    // position
    vertices[0].position  = .{ half_width, -half_height, -half_depth};
    vertices[1].position  = .{ half_width,  half_height, -half_depth};
    vertices[2].position  = .{ half_width,  half_height,  half_depth};
    vertices[3].position  = .{ half_width, -half_height,  half_depth};

    vertices[4].position  = .{-half_width, -half_height,  half_depth};
    vertices[5].position  = .{-half_width,  half_height,  half_depth};
    vertices[6].position  = .{-half_width,  half_height, -half_depth};
    vertices[7].position  = .{-half_width, -half_height, -half_depth};

    vertices[8].position  = .{-half_width,  half_height, -half_depth};
    vertices[9].position  = .{-half_width,  half_height,  half_depth};
    vertices[10].position = .{ half_width,  half_height,  half_depth};
    vertices[11].position = .{ half_width,  half_height, -half_depth};

    vertices[12].position = .{ half_width, -half_height, -half_depth};
    vertices[13].position = .{ half_width, -half_height,  half_depth};
    vertices[14].position = .{-half_width, -half_height,  half_depth};
    vertices[15].position = .{-half_width, -half_height, -half_depth};

    vertices[16].position = .{ half_width, -half_height,  half_depth};
    vertices[17].position = .{ half_width,  half_height,  half_depth};
    vertices[18].position = .{-half_width,  half_height,  half_depth};
    vertices[19].position = .{-half_width, -half_height,  half_depth};

    vertices[20].position = .{-half_width, -half_height, -half_depth};
    vertices[21].position = .{-half_width,  half_height, -half_depth};
    vertices[22].position = .{ half_width,  half_height, -half_depth};
    vertices[23].position = .{ half_width, -half_height, -half_depth};

    // uv
    for i : 0..5 {
        vertices[i * 4].uv0     = .{0.0, 1.0};
        vertices[i * 4 + 1].uv0 = .{0.0, 0.0};
        vertices[i * 4 + 2].uv0 = .{1.0, 0.0};
        vertices[i * 4 + 3].uv0 = .{1.0, 1.0};
    }

    for i : 0..5 {
        normal : Vector3;
        if i == {
            case 0; normal = .{ 1.0, 0.0, 0.0};
            case 1; normal = .{-1.0, 0.0, 0.0};
            case 2; normal = .{0.0,  1.0, 0.0};
            case 3; normal = .{1.0, -1.0, 0.0};
            case 4; normal = .{0.0, 0.0,  1.0};
            case 5; normal = .{0.0, 0.0, -1.0};
            case;   normal = .{0, 0, 0};
        }

        base := i * 4;
        for j : 0..3 {
            vertices[base + j].normal = normal;
            vertices[base + j].color_scale = color;
        }
    }

    box.indices = .[
         0,  1,  2,  2,  3,  0,
         4,  5,  6,  6,  7,  4,
         8,  9, 10, 10, 11,  8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    ];

    return box;
}

make_cylinder :: () -> Mesh_Data(Immediate_Vertex) {
    cylinder : Mesh_Data(Immediate_Vertex);

    return cylinder;
}

make_cylinder_no_cap :: () -> Mesh_Data(Immediate_Vertex) {
    cylinder : Mesh_Data(Immediate_Vertex);

    return cylinder;
}

make_cone :: (radius : float = 1.0, height : float = 2.0, color : Vector4 = .{0.0, 0.8, 0.0, 1.0} ) -> Mesh_Data(Immediate_Vertex) {
    cone : Mesh_Data(Immediate_Vertex);

    return cone;
}

make_cone_no_cap :: (radius : float = 1.0, height : float = 2.0, color : Vector4 = .{0.0, 0.8, 0.0, 1.0} ) -> Mesh_Data(Immediate_Vertex) {
    cone : Mesh_Data(Immediate_Vertex);

    return cone;
}