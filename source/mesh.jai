Mesh_Vertex :: struct {
    position: Vector3;
    normal:   Vector3;

    // color:    Vector4;

    // joints:   Vector4;
    // weights: [4]s16;
}

CBuffer_Mesh :: struct {
    world:      Matrix4;
    material_id:u32; 
    _pad:        Vector3;
}

Skinned_Mesh :: struct {
    vertices: []Mesh_Vertex;
    indices:  []u32;

    buffer_vertex: *ID3D11Buffer;
    buffer_index:  *ID3D11Buffer;

    buffer_mesh:  *ID3D11Buffer;
}

mesh_load_from_file :: (mesh: *Skinned_Mesh, filename: string) -> bool {
    data := gltf_parse_file(filename);
    gltf_load_buffers(*data);

    total_vertex_count, total_index_count : s64;
    for data.meshes {
        for it.primitives {
            using it;

            if position_accessor != -1 {
                accessor := data.accessors[position_accessor];
                total_vertex_count += accessor.count;
            }

            if indices_accessor != -1 {
                accessor := data.accessors[indices_accessor];
                total_index_count += accessor.count;
            }
        }
    }

    mesh.vertices = NewArray(total_vertex_count, Mesh_Vertex);
    mesh.indices  = NewArray(total_index_count, u32);

    vertex_offset, index_offset : s64 = 0;
    for data.meshes {
        for it.primitives {
            using it;

            vertices: [..]float;
            if position_accessor != -1 {
                accessor := data.accessors[position_accessor];
                read_buffer_from_accessor(*data, accessor, *vertices);

                for i : 0..accessor.count - 1 {
                    mesh.vertices[vertex_offset+i].position = .{vertices[i*3+0], vertices[i*3+1], vertices[i*3+2]};
                }
            }

            normals: [..]float;
            if normal_accessor != -1 {
                accessor := data.accessors[normal_accessor];
                read_buffer_from_accessor(*data, accessor, *normals);

                for i : 0..accessor.count - 1 {
                    mesh.vertices[vertex_offset+i].normal = .{normals[i*3+0], normals[i*3+1], normals[i*3+2]};
                }
            }

            vertex_offset += vertices.count;

            indices: [..]u32;
            if indices_accessor != -1 {
                accessor := data.accessors[indices_accessor];
                read_buffer_from_accessor(*data, accessor, *indices);

                for i : 0..accessor.count - 1 {
                    mesh.indices[index_offset+i] = indices[i] + cast(u32)index_offset;
                }
                index_offset += accessor.count;
            }
        }
    }

    return true;
}

mesh_reset :: (gfx_device: *Graphics_Device, using mesh: *Skinned_Mesh) -> bool {
    success: bool;

    success = cbuffer_create(gfx_device, *buffer_vertex, .VERTEX_BUFFER, cast(u32) (size_of(Mesh_Vertex) * vertices.count));
    success = cbuffer_create(gfx_device, *buffer_index,  .INDEX_BUFFER, cast(u32) (size_of(u32) * indices.count));
    success = cbuffer_create(gfx_device, *buffer_mesh,   .CONSTANT_BUFFER, cast(u32) size_of(CBuffer_Mesh));

    D3D11SetDebugObjectName(gfx_device.d3d_device, buffer_vertex,   "Skinned_Mesh_VertexBuffer");
    D3D11SetDebugObjectName(gfx_device.d3d_device, buffer_index,    "Skinned_Mesh_IndexBuffer");
    D3D11SetDebugObjectName(gfx_device.d3d_device, buffer_mesh,     "Skinned_Mesh_MeshBuffer");

    return success;
}

#import, dir "../vendor/gltf_parser";