Texture_Usage :: enum_flags u32 {
    SRV         :: 0x01;
    UAV         :: 0x02;
    RTV         :: 0x04;
    DSV         :: 0x08;
    SRV_DSV     :: SRV | DSV; 
    SRV_UAV     :: SRV | UAV;
    SRV_RTV     :: SRV | RTV;
    SRV_RTV_UAV :: SRV | RTV | UAV;
}

Texture_SRV_Type :: enum u8 {
    TEXTURE_2D;
    TEXTURE_3D;
    TEXTURE_CUBE;
}

Texture_ALL_Mips_Use :: enum_flags u32 {
    NONE :: 0x00;
    UAV  :: 0x01;
    RTV  :: 0x02;
    DSV  :: 0x04;
    ALL  :: UAV | RTV | DSV;
}

D3D12Texture :: struct {
    using #as base: GPU_Resource;

    desc:        D3D12_RESOURCE_DESC;
    clear_value: D3D12_CLEAR_VALUE;
    format:      DXGI_FORMAT;
    layout:     *D3D12_PLACED_SUBRESOURCE_FOOTPRINT;

    num_rows:       *u32;
    num_row_size:   *u64;

    bytesize: u32    = 0;
    is_cubemap: bool = false;

    usage: D3D12_RESOURCE_FLAGS;
}

make_d3d12_texture :: (device: *D3D12Device, using _texture: *D3D12Texture, heap: *D3D12Descriptor_Heap) {

}

d3d12_texture_release :: (using _texture: *D3D12Texture) {

    safe_release(resource);
}

d3d12_texture_add_srv  :: (device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Shader4ComponentMapping = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Format = format;

    if is_cubemap {
        srv_desc.ViewDimension = .TEXTURECUBEARRAY;
        srv_desc.TextureCubeArray.First2DArrayFace = 0;
    } else {
        srv_desc.ViewDimension = .TEXTURECUBE;
        srv_desc.TextureCube.MipLevels = desc.MipLevels;
        srv_desc.TextureCube.MostDetailedMip = 0;
    }

    base.srv = d3d12_descriptor_heap_resource_add(device, heap, .SRV, resource, xx *srv_desc);
}

d3d12_texture_add_dsv :: (device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {
    
    dsv_desc: D3D12_DEPTH_STENCIL_VIEW_DESC;
    dsv_desc.Format = format;

    if dsv_desc.Format == .R32_TYPELESS dsv_desc.Format = .D32_FLOAT;
    if dsv_desc.Format == .R16_TYPELESS dsv_desc.Format = .D16_UNORM;

    dsv_desc.ViewDimension = .TEXTURE2D;
    
    if is_cubemap || desc.DepthOrArraySize > 1 {
        dsv_desc.ViewDimension = .TEXTURE2DARRAY;
        dsv_desc.Texture2DArray.FirstArraySlice = 0;
        dsv_desc.Texture2DArray.ArraySize = desc.DepthOrArraySize;
    }
    dsv_desc.Flags = .NONE;

    array_add(*dsvs, d3d12_descriptor_heap_resource_add(device, heap, .DSV, resource, xx *dsv_desc));
}

d3d12_texture_add_rtv :: (device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    array_add(*rtvs, d3d12_descriptor_heap_resource_add(device, heap, .RTV, resource, null));
}

d3d12_texture_add_uav :: (device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    uav_desc: D3D12_UNORDERED_ACCESS_VIEW_DESC;
    uav_desc.Format = format;

    if uav_desc.Format == .R32_TYPELESS uav_desc.Format = .D32_FLOAT;
    if uav_desc.Format == .R16_TYPELESS uav_desc.Format = .R16_UNORM;

    uav_desc.ViewDimension      = .TEXTURE2D;
    uav_desc.Texture2D.MipSlice = 0;
    uav_desc.Texture2D.PlaneSlice = 0;

    array_add(*uavs, d3d12_descriptor_heap_resource_add(device, heap, .UAV, resource, xx *uav_desc));
}


#scope_file

make_srv  :: inline (using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {
}

make_rtvs :: inline (using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {
}

make_dsv  :: inline (using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

}

make_uavs :: inline (using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

}