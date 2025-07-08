D3D12Buffer :: struct {
    using #as base: GPU_Resource;

    type: Buffer_Type;
    heap_type: D3D12_HEAP_TYPE;

    size: u32;
    counter: bool;

    union {
        vbv: D3D12_VERTEX_BUFFER_VIEW;
        ibv: D3D12_INDEX_BUFFER_VIEW;
    }
}

d3d12_buffer_release :: (using buffer: *D3D12Buffer) {

    safe_release_and_reset(*resource);
    safe_release_and_reset(*upload_buffer);
}

make_d3d12_vertex_buffer :: (using _device: *D3D12Device, using buffer: *D3D12Buffer, _size: u32, stride: u32, _heap_type: D3D12_HEAP_TYPE = .DEFAULT) -> bool {

    if resource {
        log_error("D3D12Buffer created, Are you sure?");
        return false;
    }
    counter = false;

    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type                    = _heap_type;
    heap_properties.CPUPageProperty         = .UNKNOWN;
    heap_properties.MemoryPoolPreference    = .UNKNOWN;
    heap_properties.CreationNodeMask        = 1;
    heap_properties.VisibleNodeMask         = 1;

    resource_desc: D3D12_RESOURCE_DESC;
    resource_desc.Dimension         = .BUFFER;
    resource_desc.Alignment         = 0;
    resource_desc.Width             = xx _size;
    resource_desc.Height            = 1;
    resource_desc.DepthOrArraySize  = 1;
    resource_desc.MipLevels         = 1;
    resource_desc.Format            = .UNKNOWN;
    resource_desc.SampleDesc.Count  = 1;
    resource_desc.SampleDesc.Quality= 0;
    resource_desc.Layout            = .ROW_MAJOR;
    resource_desc.Flags             = .NONE;

    ok := HR(ID3D12Device_CreateCommittedResource(device, *heap_properties, .NONE, *resource_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *resource), info_queue);
    if !ok return false;

    vbv.BufferLocation  = ID3D12Resource_GetGPUVirtualAddress(resource);
    vbv.SizeInBytes     = _size;
    vbv.StrideInBytes   = stride;

    type = .VERTEX;
    array_add(*state, .VERTEX_AND_CONSTANT_BUFFER);
    heap_type = _heap_type;
    size = _size;
    gpu_addr = ID3D12Resource_GetGPUVirtualAddress(resource);

    if heap_type == .DEFAULT {
        heap_properties.Type = .UPLOAD;

        ok = HR(ID3D12Device_CreateCommittedResource(device, *heap_properties, .NONE, *resource_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *upload_buffer));
        if !ok return false;
    }

    return true;
}

make_d3d12_index_buffer :: (using _device: *D3D12Device, using buffer: *D3D12Buffer, _size: u32, format: DXGI_FORMAT = .R32_UINT, _heap_type: D3D12_HEAP_TYPE = .DEFAULT) -> bool {

    if resource {
        log_error("D3D12Buffer created, Are you sure?");
        return false;
    };
    counter = false;

    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type                    = _heap_type;
    heap_properties.CPUPageProperty         = .UNKNOWN;
    heap_properties.MemoryPoolPreference    = .UNKNOWN;
    heap_properties.CreationNodeMask        = 1;
    heap_properties.VisibleNodeMask         = 1;

    resource_desc: D3D12_RESOURCE_DESC;
    resource_desc.Dimension         = .BUFFER;
    resource_desc.Alignment         = 0;
    resource_desc.Width             = _size;
    resource_desc.Height            = 1;
    resource_desc.DepthOrArraySize  = 1;
    resource_desc.MipLevels         = 1;
    resource_desc.Format            = .UNKNOWN;
    resource_desc.SampleDesc.Count  = 1;
    resource_desc.SampleDesc.Quality= 0;
    resource_desc.Layout            = .ROW_MAJOR;
    resource_desc.Flags             = .NONE;

    ok := HR(ID3D12Device_CreateCommittedResource(device, *heap_properties, .NONE, *resource_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *resource));
    if !ok return false;

    ibv.BufferLocation  = ID3D12Resource_GetGPUVirtualAddress(resource);
    ibv.SizeInBytes     = _size;
    ibv.Format          = .R32_UINT;

    type = .INDEX;
    array_add(*state, .INDEX_BUFFER);
    heap_type = _heap_type;
    size = _size;
    gpu_addr = ID3D12Resource_GetGPUVirtualAddress(resource);

    if heap_type == .DEFAULT {
        heap_properties.Type = .UPLOAD;

        ok = HR(ID3D12Device_CreateCommittedResource(device, *heap_properties, .NONE, *resource_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *upload_buffer));
        if !ok return false;
    }

    return true;
}

make_d3d12_constant_buffer :: (using _device: *D3D12Device, using buffer: *D3D12Buffer, heap: *D3D12Descriptor_Heap, _size: u32) -> bool {

    if resource {
        log_error("D3D12Buffer created, Are you sure?");
        return false;
    }

    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type                    = .UPLOAD;
    heap_properties.CPUPageProperty         = .UNKNOWN;
    heap_properties.MemoryPoolPreference    = .UNKNOWN;
    heap_properties.CreationNodeMask        = 1;
    heap_properties.VisibleNodeMask         = 1;

    resource_desc: D3D12_RESOURCE_DESC;
    resource_desc.Dimension         = .BUFFER;
    resource_desc.Alignment         = 0;
    resource_desc.Width             = xx calc_constant_buffer_byte_size(_size);
    resource_desc.Height            = 1;
    resource_desc.DepthOrArraySize  = 1;
    resource_desc.MipLevels         = 1;
    resource_desc.Format            = .UNKNOWN;
    resource_desc.SampleDesc.Count  = 1;
    resource_desc.SampleDesc.Quality= 0;
    resource_desc.Layout            = .ROW_MAJOR;
    resource_desc.Flags             = .NONE;

    ok := HR(ID3D12Device_CreateCommittedResource(device, *heap_properties, .NONE, *resource_desc, .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *resource), info_queue);
    if !ok return false;

    type = .CONSTANT;
    array_add(*state, .GENERIC_READ);
    heap_type = .UPLOAD;
    gpu_addr = ID3D12Resource_GetGPUVirtualAddress(resource);

    cbv_desc: D3D12_CONSTANT_BUFFER_VIEW_DESC;
    cbv_desc.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(resource);
    cbv_desc.SizeInBytes    = xx calc_constant_buffer_byte_size(_size);
    cbv = d3d12_descriptor_heap_resource_add(_device, heap, .CBV, resource, xx *cbv_desc);
    size = xx calc_constant_buffer_byte_size(_size);

    return true;
}

buffer_map_to_cpu :: (using buffer: *D3D12Buffer) {

    if heap_type == .UPLOAD {
        log("Only resource in Upload Heap can map too CPU");
    }

    read_range: D3D12_RANGE = .{0, 0};
    ID3D12Resource_Map(resource, 0, *read_range, *cpu_map_addr);
}

buffer_unmap_to_cpu :: (using buffer: *D3D12Buffer) {

    read_range: D3D12_RANGE = .{0, 0};
    ID3D12Resource_Unmap(resource, 0, *read_range);
}

buffer_update_buffer_from_cpu :: (using buffer: *D3D12Buffer, data: *void, _size: s64) {
    
    if cpu_map_addr memcpy(cpu_map_addr, data, _size);
    else log("D3D12Buffer is not mappting to CPU, need to map first");
}