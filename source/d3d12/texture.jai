Texture :: struct {
    using #as base: GPU_Resource;
    resource_desc: D3D12_RESOURCE_DESC;

    width:      s32;
    height:     s32;
    bpp:        s32;

    layouts : [] D3D12_PLACED_SUBRESOURCE_FOOTPRINT;
    num_rows: [] u32;
    row_size_in_bytes: [] u64;
}

make_texture2d_from_bitmap :: (bitmap: *Bitmap, descriptor_heap: *Descriptor_Heap) -> success: bool, Texture {

    CheckInit();
    using state.d3d12;

    ret: Texture;
    ret.resource_desc = D3D12_RESOURCE_DESC_INIT_AS_TEXTURE2D(bitmap.format, xx bitmap.width, xx bitmap.height);
    ret.bpp     = xx GetImageBytesPerTexel(bitmap.format);
    ret.width   = xx bitmap.width; 
    ret.height  = xx bitmap.height;

    success := HR(ID3D12Device_CreateCommittedResource(device, *D3D12_HEAP_PROPERTIES_INIT(), .NONE, *ret.resource_desc, .COMMON, null, *uid(ID3D12Resource_UUID), xx *ret.resource));
    if !success return false, .{};

    num_subresources := ret.resource_desc.MipLevels * ret.resource_desc.DepthOrArraySize;

    ret.layouts  = NewArray(num_subresources, D3D12_PLACED_SUBRESOURCE_FOOTPRINT);
    ret.num_rows = NewArray(num_subresources, u32);
    ret.row_size_in_bytes = NewArray(num_subresources, u64);

    upload_buffer_size: u64;
    ID3D12Device_GetCopyableFootprints(device, *ret.resource_desc, 0, xx num_subresources, 0, ret.layouts.data, ret.num_rows.data, ret.row_size_in_bytes.data, *upload_buffer_size);

    success = HR(ID3D12Device_CreateCommittedResource(device, *D3D12_HEAP_PROPERTIES_INIT(.UPLOAD), .NONE, *D3D12_RESOURCE_DESC_INIT_AS_BUFFER(xx upload_buffer_size), .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *ret.upload_buffer));
    if !success return false, .{};

    ret.base.srv = create_shader_resource_view(*ret, descriptor_heap);

    return true, ret;
}

deinit :: (using texture: *Texture) {

    array_free(layouts);
    array_free(num_rows);
    array_free(row_size_in_bytes);

    safe_release_and_reset(*resource);
    safe_release_and_reset(*upload_buffer);
}

create_shader_resource_view :: (_texture: *Texture, descriptor_heap: *Descriptor_Heap) -> Descriptor_Handle {

    CheckInit();
    using state.d3d12;

    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Format                     = _texture.resource_desc.Format;
    srv_desc.ViewDimension              = .TEXTURE2D; // TODO make this more generalize
    srv_desc.Shader4ComponentMapping    = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Texture2D.MipLevels        = _texture.resource_desc.MipLevels;

    gpu_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    gpu_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.TEXTURE_SRV * descriptor_heap.size);

    srv_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(descriptor_heap.heap);
    srv_handle.ptr += xx (xx CBV_SRV_UAV_HEAP_OFFSET.TEXTURE_SRV * descriptor_heap.size);
    ID3D12Device_CreateShaderResourceView(device, _texture.resource, *srv_desc, srv_handle);

    return .{srv_handle, gpu_handle};
}