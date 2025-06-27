Mesh_Data :: struct ($T: Type) {
    vertices : []T;
    indices  : []u32;
}

make_sphere :: (radius: float = 1.0, levels: u32 = 20, slices : u32 = 20, color : Vector4 = .{0.0, 0.8, 0.0, 1.0}) -> Mesh_Data(Immediate_Vertex) {
    using sphere : Mesh_Data(Immediate_Vertex);
    vertices = NewArray(2 + (levels - 1) * (slices + 1), Immediate_Vertex);
    indices  = NewArray(6 * (levels - 1) * slices + 10, u32);

    phi, theta := 0.0;
    per_phi   := PI / levels;
    per_theta := 2 * PI / slices;

    x, y, z : float;

    vertex_index : u32 = 0;
    index\_index : u32 = 0;

    vertices[vertex_index] = .{position = .{0, radius, 0}, normal=.{0, 1, 0}, color_scale=color};
    top_index := vertex_index; 
    vertex_index += 1;

    for level : 1..levels {
        phi = per_phi * xx level;

        for slice : 0..slices - 1 {
            theta = per_theta * xx slice;

            x = radius * sin(phi) * cos(theta);
            y = radius * cos(phi);
            z = radius * sin(phi) * sin(phi);

            position := xyz(x, y, z);
            normal   := normalize(position);

            vertices[vertex_index] = .{position=position, normal=normal, color_scale=color};
            vertex_index += 1;
        }
    }

    vertices[vertex_index] = .{position=.{0, -radius, 0}, normal=.{0, -1, 0}, color_scale=color};
    bottom_index := vertex_index;
    vertex_index += 1;

    if levels > 1 {
        for slice : 1..slices - 2 {
            indices[index_index + 0] = 0;
            indices[index_index + 1] = slice % (slices + 1) + 1;
            indices[index_index + 2] = slice;

            index_index += 3;
        }
    }

    for i : 0..levels - 2 {
        for j : 1..slices - 1 {
            indices[xx index_index + 0] = (i - 1) * (slices + 1) + j;
            indices[xx index_index + 1] = (i - 1) * (slices + 1) + j % (slices + 1) + 1;
            indices[xx index_index + 2] = i * (slices + 1) + j % (slices + 1) + 1;

            indices[xx index_index + 3] = i * (slices + 1) + j % (slices + 1) + 1;
            indices[xx index_index + 4] = i * (slices + 1) * j;
            indices[xx index_index + 5] = (i - 1) * (slices + 1) + j;

            index_index += 6;
        }
    }

    if levels > 1 {
        for j : 1..slices - 2 {
            indices[index_index + 0] = (levels - 2) * (slices + 1) + j;
            indices[index_index + 1] = (levels - 2) * (slices + 1) + j % (slices + 1) + 1;
            indices[index_index + 2] = (levels - 1) * (slices + 1) + 1;

            index_index += 3;
        }
    }

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

    // uv0
    // for i : 0..5 {
    //     vertices[i * 4].uv0     = .{0.0, 1.0};
    //     vertices[i * 4 + 1].uv0 = .{0.0, 0.0};
    //     vertices[i * 4 + 2].uv0 = .{1.0, 0.0};
    //     vertices[i * 4 + 3].uv0 = .{1.0, 1.0};
    // }

    // normal, tangent, color
    for i : 0..3 {
        vertices[i].normal = .{1.0, 0.0, 0.0};
        // vertices[i].tangent= .{0.0, 0.0, 1.0, 1.0};
        vertices[i].color_scale = color;

        vertices[i + 4].normal = .{-1.0, 0.0, 0.0};
        // vertices[i + 4].tangent= .{0.0, 0.0, -1.0, 1.0};
        vertices[i + 4].color_scale = color;

        vertices[i + 4].normal = .{0.0, 1.0, 0.0};
        // vertices[i + 4].tangent= .{1.0, 0.0, 0.0, 1.0};
        vertices[i + 4].color_scale = color;

        vertices[i + 8].normal = .{0.0, -1.0, 0.0};
        // vertices[i + 8].tangent= .{-1.0, 0.0, 0.0, 1.0};
        vertices[i + 8].color_scale = color;

        vertices[i + 12].normal = .{0.0, -1.0, 0.0};
        // vertices[i + 12].tangent= .{0.0, 0.0, -1.0, 1.0};
        vertices[i + 12].color_scale = color;

        vertices[i + 16].normal = .{0.0, 0.0, 1.0};
        // vertices[i + 16].tangent= .{-1.0, 0.0, 0.0, 1.0};
        vertices[i + 16].color_scale = color;

        vertices[i + 20].normal = .{1.0, 0.0, -1.0};
        // vertices[i + 20].tangent= .{1.0, 0.0, 0.0, 1.0};
        vertices[i + 20].color_scale = color;
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