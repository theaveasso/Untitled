Buffer :: struct {
    using #as base: GPU_Resource;
}

Structured_Buffer_Type :: enum {
    READ        :: 1;
    READ_WRITE  :: 2;
}

make_index_buffer  :: () {

}

make_vertex_buffer :: () {

}

make_constants_buffer  :: (descriptor_heap: *Descriptor_Heap, stride_size: u32) -> success: bool, Buffer {

    CheckInit();
    using state.d3d12;

    ret: Buffer;

    buffersize := CalculateConstantBufferByteSize(stride_size);
    success := HR(ID3D12Device_CreateCommittedResource(
        device,
        *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD),
        .NONE, 
        *D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx buffersize),
        .GENERIC_READ,
        null,
        *uid(ID3D12Resource_UUID),
        xx *ret.upload_buffer));
    if !success return false, .{};

    ret.gpu_addr = ID3D12Resource_GetGPUVirtualAddress(ret.upload_buffer);

    cbv_desc: D3D12_CONSTANT_BUFFER_VIEW_DESC;
    cbv_desc.SizeInBytes = xx buffersize;
    cbv_desc.BufferLocation = ret.gpu_addr;

    gpu_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    gpu_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.CBV * descriptor_heap.size);

    cbv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    cbv_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.CBV * descriptor_heap.size);
    ID3D12Device_CreateConstantBufferView(device, *cbv_desc, cbv_handle);

    ret.cbv.cpu = cbv_handle;
    ret.cbv.gpu = gpu_handle;

    return true, ret;
}

make_structured_buffer :: (descriptor_heap: *Descriptor_Heap, stride_size: u32, element_count: u32, counter: bool = false, raw: bool = false, padding: bool = false) -> success: bool, Buffer {

    CheckInit();
    using state.d3d12;

    ret: Buffer;

    if padding stride_size = xx (stride_size + 16) &~ 16;

    buffersize := element_count * stride_size;
    success := HR(ID3D12Device_CreateCommittedResource(
        device,
        *D3D12_HEAP_PROPERTIES_INIT(),
        .NONE, 
        *D3D12_RESOURCE_DESC_INIT_AS_BUFFER(buffersize),
        .COMMON,
        null,
        *uid(ID3D12Resource_UUID),
        xx *ret.resource));
    if !success return false, .{};

    success = HR(ID3D12Device_CreateCommittedResource(
        device,
        *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD),
        .NONE, 
        *D3D12_RESOURCE_DESC_INIT_AS_BUFFER(buffersize),
        .GENERIC_READ,
        null,
        *uid(ID3D12Resource_UUID),
        xx *ret.upload_buffer));
    if !success return false, .{};

    // create shader resource view
    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Format                     = .UNKNOWN;
    srv_desc.ViewDimension              = .BUFFER;
    srv_desc.Shader4ComponentMapping    = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Buffer.FirstElement        = 0;
    srv_desc.Buffer.NumElements         = element_count;
    srv_desc.Buffer.StructureByteStride = stride_size;
    srv_desc.Buffer.Flags               = ifx raw then .RAW else .NONE;

    gpu_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    gpu_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.SRV * descriptor_heap.size);

    srv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    srv_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.SRV * descriptor_heap.size);
    ID3D12Device_CreateShaderResourceView(device, ret.resource, *srv_desc, srv_handle);

    ret.srv.cpu = srv_handle;
    ret.srv.gpu = gpu_handle;

    return true, ret;
}

deinit :: (buffer: *Buffer) {

    safe_release_and_reset(*buffer.resource);
    safe_release_and_reset(*buffer.upload_buffer);
}