Mesh_Geometry :: struct {
    name: string;

    // System memory copies.
    // Use Blobs because the vertex/index format can be generic
    // It is up to the client to cast appropriately.
    cpu_vertex_buffer: *ID3DBlob;
    cpu_index\_buffer: *ID3DBlob;

    gpu_vertex_buffer: *ID3D12Resource;
    gpu_index\_buffer: *ID3D12Resource;

    vertex_buffer_uploader: *ID3D12Resource;
    index\_buffer_uploader: *ID3D12Resource;

    // Data about the buffers.
    vertex_bytestride : u32 = 0;
    vertex_buffer_bytestride : u32 = 0;
    index_format : DXGI_FORMAT = .R32_UINT;
    index_buffer_bytestride : u32 = 0; 

    // A MeshGeometry may store multiple geometries in one vertex/index buffer.
    // Use this container to define the submesh geometries so we can draw the submeshes individually
    draw_args: Table(string, Submesh_Geometry);
}

// Defines a subrange of geometry in a MeshGeometry.
// This is for when multiple geopmetries are stored in one vertex and index buffer.
// It provides the offsets and data needed to draw a subset of geometry stores in the vertex and index buffers.
Submesh_Geometry :: struct {
    index_count:            u32 = 0;
    start_index_location:   u32 = 0;
    base_vertex_location:   s32 = 0;

    // Bounding box of the geometry defined by this submesh.
    // bounding_box: Bounding_Box;
}

mesh_geometry_fini :: (using mesh: *Mesh_Geometry) {

    if gpu_vertex_buffer {
        IUnknown_Release(gpu_vertex_buffer);
        gpu_vertex_buffer = null;
    }
    if gpu_index\_buffer {
        IUnknown_Release(gpu_index\_buffer);
        gpu_index\_buffer = null;
    }
    if cpu_vertex_buffer  {
        IUnknown_Release(cpu_vertex_buffer);
        cpu_vertex_buffer = null;
    }
    if cpu_index\_buffer  {
        IUnknown_Release(cpu_index_buffer);
        cpu_index_buffer = null;
    }
}

mesh_geometry_get_vbv :: (using mesh: *Mesh_Geometry) -> D3D12_VERTEX_BUFFER_VIEW {
    
    vbv: D3D12_VERTEX_BUFFER_VIEW;
    vbv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(gpu_vertex_buffer);
    vbv.SizeInBytes    = vertex_buffer_bytestride;
    vbv.StrideInBytes  = vertex_bytestride;

    return vbv;
}

mesh_geometry_get_ibv :: inline (using mesh: *Mesh_Geometry) -> D3D12_INDEX_BUFFER_VIEW {

    ibv: D3D12_INDEX_BUFFER_VIEW;
    ibv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(gpu_index_buffer);
    ibv.SizeInBytes    = index_buffer_bytestride;
    ibv.Format         = index_format;

    return ibv;
}

mesh_geometry_dispose_uploaders :: inline (using mesh: *Mesh_Geometry) {

    if vertex_buffer_uploader IUnknown_Release(vertex_buffer_uploader);
    if index_buffer_uploader  IUnknown_Release(index_buffer_uploader);
    vertex_buffer_uploader = null;
    index\_buffer_uploader = null;
}

make_default_buffer :: (
    d3ddevice: *ID3D12Device, 
    cmdlist: *ID3D12GraphicsCommandList,
    init_data: *void = null,
    size: u32,
    upload_buffer: *ID3D12Resource) -> *ID3D12Resource {

    default_buffer: *ID3D12Resource;

    heap_prop: D3D12_HEAP_PROPERTIES;
    heap_prop.CPUPageProperty       = .UNKNOWN;
    heap_prop.MemoryPoolPreference  = .UNKNOWN;
    heap_prop.CreationNodeMask      = 1;
    heap_prop.VisibleNodeMask       = 1;

    resource_desc: D3D12_RESOURCE_DESC;
    resource_desc.Dimension         = .BUFFER;
    resource_desc.Alignment         = 0;
    resource_desc.Width             = xx size;
    resource_desc.Height            = 1;
    resource_desc.DepthOrArraySize  = 1;
    resource_desc.MipLevels         = 1;
    resource_desc.Format            = .UNKNOWN;
    resource_desc.SampleDesc.Count  = 1;
    resource_desc.SampleDesc.Quality= 0;
    resource_desc.Layout            = .ROW_MAJOR;
    resource_desc.Flags             = .NONE;

    // Create the actual defualt buffer resource.
    heap_prop.Type                  = .DEFAULT;
    ok := HR(ID3D12Device_CreateCommittedResource(d3ddevice, *heap_prop, .NONE, *resource_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *default_buffer));
    if !ok return null;

    // In order to copy CPU memory data into default buffer, we need to create an itermediate upload heap.
    heap_prop.Type = .UPLOAD;
    ok =  HR(ID3D12Device_CreateCommittedResource(d3ddevice, *heap_prop, .NONE, *resource_desc, .GENERIC_READ ,null, *uid(ID3D12Resource_UUID), xx *upload_buffer));
    if !ok return null;

    // Describe the data we want to copy into the default buffer;
    subresource_data: D3D12_SUBRESOURCE_DATA;
    subresource_data.pData = init_data;
    subresource_data.RowPitch = xx size;
    subresource_data.SlicePitch = subresource_data.RowPitch;

    // Schedule to copy the data to the default buffer resource.
    // At a high level, the helper function 'UpdateSubresources' will copy the CPU memory into the intermediate upload heap.
    // Then, using 'ID3D12CommandList_CopySubresourceRegion'.
    // The intermediate upload heap data will be copied to buffer.
    barrier: D3D12_RESOURCE_BARRIER;
    barrier.Type                   = .TRANSITION;
    barrier.Flags                  = .NONE;
    barrier.Transition.pResource   = default_buffer;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    barrier.Transition.StateBefore = .COMMON;
    barrier.Transition.StateAfter  = .COPY_DEST;
    ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *barrier);

    UpdateSubresources(cmdlist, default_buffer, upload_buffer, 0, 0, 1, *subresource_data);

    barrier.Transition.StateBefore = .COPY_DEST;
    barrier.Transition.StateAfter  = .GENERIC_READ;
    ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *barrier);

    // Note: 'upload_buffer' has to be kept alive after the above function calls,
    // because the command list has not been executed yet that performs the actual copy.
    // The caller can Release the 'upload_buffer' after it knowns the copy has been executed.
    
    return default_buffer;
}

HR :: inline (hr: HRESULT, d3dinfo_queue: *ID3D12InfoQueue = null, $call := #caller_code, loc :=  #caller_location) -> bool {
    
    call_string :: #run -> string {
        root := compiler_get_nodes(call);

        if root.kind == {
        case .PROCEDURE_CALL;
            proc_call := cast(*Code_Procedure_Call) root;
            expression := proc_call.arguments_sorted[0];

            if expression.kind != .PROCEDURE_CALL {
                return "";
            }

            call := cast(*Code_Procedure_Call) expression;
            if call.procedure_expression.kind != .IDENT {
                return "";
            }

            return (cast(*Code_Ident) call.procedure_expression).name;

        case .IDENT;
            return (cast(*Code_Ident) root).name;

        case;
            return "";
        }
    };

    if FAILED(hr) {
        if d3dinfo_queue print_debug_msgs(d3dinfo_queue);
        action := call_string;
        printed_result := tprint("% % % failed!", action, hr, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        log_error(printed_result);
        return false;
    }

    return true;
}

calc_constant_buffer_byte_size :: inline (bytesize: s64) -> s64 { return (bytesize + 255) & ~255; }

print_debug_msgs :: (d3d12_info_queue:*ID3D12InfoQueue) {
    if !d3d12_info_queue return;
    msgs_count := ID3D12InfoQueue_GetNumStoredMessages(d3d12_info_queue);
    // print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        ok := ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, null, *size);

        // WARNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg: *D3D12_MESSAGE = xx alloc(xx size);
        defer free(msg);
        ok = ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, msg, *size);

        str: string;
        str.data  = msg.pDescription;
        str.count = xx msg.DescriptionByteLength;

        prefix: string;
        if  msg.Severity == {
            case .CORRUPTION; prefix = "CORRUPTION";
            case .ERROR;      prefix = "ERROR";
            case .WARNING;    prefix = "WARNING";
            case .INFO;       prefix = "INFO";
            case .MESSAGE;    prefix = "MESSAGE";
        }

        category: string;
        if  msg.Category == {
            case .APPLICATION_DEFINED;   category = "APPLICATION_DEFINED";
            case .MISCELLANEOUS;         category = "MISCELLANEOUS";
            case .INITIALIZATION;        category = "INITIALIZATION";
            case .CLEANUP;               category = "CLEANUP";
            case .COMPILATION;           category = "COMPILATION";
            case .STATE_CREATION;        category = "STATE_CREATION";
            case .STATE_SETTING;         category = "STATE_SETTING";
            case .STATE_GETTING;         category = "STATE_GETTING";
            case .RESOURCE_MANIPULATION; category = "RESOURCE_MANIPULATION";
            case .EXECUTION;             category = "EXECUTION";
            case .SHADER;                category = "SHADER";
        }

        print("[D3D12][%]:% - %, \n", prefix, category, msg.ID);
        print("%\n", str);
    }

    ID3D12InfoQueue_ClearStoredMessages(d3d12_info_queue);
}

compile_d3d_shader :: (using _shader: *D3D12Shader, source: string, entry_point: string) -> bool {
    flags := D3DCOMPILE.ENABLE_STRICTNESS; 
    #if DEBUG {
        // Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
        // Setting this flag improves the shader debugging experience, but still allows  
        // the shaders to be optimized and to run exactly the way they will run in  
        // the release configuration of this program. 
        flags |= .DEBUG; 
        // Disable optimizations to further improve shader debugging 
        flags |= .SKIP_OPTIMIZATION; 
        flags |= .ENABLE_UNBOUNDED_DESCRIPTOR_TABLES;
        flags |= .PACK_MATRIX_COLUMN_MAJOR;
    } else {
        flags |= .ENABLE_UNBOUNDED_DESCRIPTOR_TABLES;
        flags |= .PACK_MATRIX_COLUMN_MAJOR;
    }
    error: *ID3DBlob;
    defines: D3D_SHADER_MACRO;

    hr := D3DCompile(xx source.data, xx source.count, null, *defines, D3D_COMPILE_STANDARD_FILE_INCLUDE, xx entry_point.data, Target_Shader_Models[type], xx flags, 0, *shader, *error);

    if FAILED(hr) { 
        msg := ID3D10Blob_GetBufferPointer(error); defer free(msg);
        log_error("D3DCompile failed: %", to_string(msg));
        return false;
    } 

    HR(D3DReflect(ID3D10Blob_GetBufferPointer(shader), ID3D10Blob_GetBufferSize(shader), *uid(ID3D12ShaderReflection_UUID), xx *reflector));
    HR(ID3D12ShaderReflection_GetDesc(reflector, *desc));

    return true;
}

D3D12_SetDebugObjectName :: inline (resource: *ID3D12Object, guid: *GUID, name: string) {
    #if DEBUG {
        ID3D12Object_SetPrivateData(resource, guid, xx name.count, name.data);
    }
}

D3D12_SetDebugObjectName :: inline (resource: *IDXGIObject, guid: *GUID,  name: string) {
    #if DEBUG {
        IDXGIObject_SetPrivateData(resource, guid, xx name.count, name.data);
    }
}

MAX_SUBRESOURCES :: 16;

// stack-allocating UpdateSubresources implementation
UpdateSubresources :: inline (
    cmdlist: *ID3D12GraphicsCommandList,
    dest: *ID3D12Resource,
    intermediate: *ID3D12Resource,
    intermediate_offset: u64,
    first_subresource: u32,
    num_subresources: u32,
    source: *D3D12_SUBRESOURCE_DATA) -> u64 {

    assert(num_subresources <= MAX_SUBRESOURCES);

    required_size : u64 = 0;
    layouts :           [MAX_SUBRESOURCES]D3D12_PLACED_SUBRESOURCE_FOOTPRINT;
    num_rows:           [MAX_SUBRESOURCES]u32;
    row_size_in_bytes:  [MAX_SUBRESOURCES]u64;

    desc : D3D12_RESOURCE_DESC = ID3D12Resource_GetDesc(dest);

    device: *ID3D12Device;
    result := HR(ID3D12DeviceChild_GetDevice(cast(*ID3D12DeviceChild) dest, *uid(ID3D12Device_UUID), xx *device));
    if !result return 0;

    ID3D12Device_GetCopyableFootprints(device, *desc, first_subresource, num_subresources, intermediate_offset, layouts.data, num_rows.data, row_size_in_bytes.data, *required_size);
    IUnknown_Release(device);

    return _UpdateSubresources(cmdlist, dest, intermediate, first_subresource, num_subresources, required_size, layouts.data, num_rows.data, row_size_in_bytes.data, source);
}

_UpdateSubresources :: inline (
    cmdlist: *ID3D12GraphicsCommandList,
    dest: *ID3D12Resource,
    intermediate: *ID3D12Resource,
    first_subresource: u32,
    num_subresources: u32,
    required_size: u64,
    layouts: *D3D12_PLACED_SUBRESOURCE_FOOTPRINT,
    num_rows: *u32,
    row_size_in_bytes: *u64,
    source: *D3D12_SUBRESOURCE_DATA) -> u64 {

    intermediate_desc := ID3D12Resource_GetDesc(intermediate);
    dest\       _desc := ID3D12Resource_GetDesc(dest);
    if intermediate_desc.Dimension != .BUFFER || intermediate_desc.Width < required_size + layouts[0].Offset || dest_desc.Dimension == .BUFFER && (first_subresource != 0 || num_subresources != 1) {
        return 0;
    }

    mapped_data: *void;
    ok := HR(ID3D12Resource_Map(intermediate, 0, null, xx *mapped_data));
    if !ok {
        return 0;
    }

    for i: 0..num_subresources - 1 {
        if layouts[i].Offset + row_size_in_bytes[i] * num_rows[i] * layouts[i].Footprint.Depth > required_size return 0;

        dest_data : D3D12_MEMCPY_DEST;
        dest_data.pData = mapped_data + layouts[i].Offset;
        dest_data.RowPitch = layouts[i].Footprint.RowPitch;
        dest_data.SlicePitch = layouts[i].Footprint.RowPitch * num_rows[i];
        MemcpySubresource(*dest_data, *source[i], xx row_size_in_bytes[i], num_rows[i], layouts[i].Footprint.Depth);
    }
    ID3D12Resource_Unmap(intermediate, 0, null);

    if dest_desc.Dimension == .BUFFER {
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, dest, 0, intermediate, layouts[0].Offset, layouts[0].Footprint.Width);
    }

    return required_size;
}

// Row-by-row memcpy
MemcpySubresource :: inline (dest: *D3D12_MEMCPY_DEST, source: *D3D12_SUBRESOURCE_DATA, row_size_in_bytes: s64, num_rows: u32, num_slices: u32) {

    for z: 0..num_slices - 1 {
        dest\ _slice := cast(*void) dest.pData + dest.SlicePitch * z;
        source_slice := cast(*void) source.pData + source.SlicePitch * z;

        for y: 0..num_rows - 1 {
            memcpy(dest_slice + dest.RowPitch * y, source_slice + source.RowPitch * y, row_size_in_bytes);
        } 
    }
}