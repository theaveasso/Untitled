TEXTURE_USAGE :: enum_flags u32 {
    SRV         :: 0x01;
    UAV         :: 0x02;
    RTV         :: 0x04;
    DSV         :: 0x08;
    SRV_DSV     :: SRV | DSV; 
    SRV_UAV     :: SRV | UAV;
    SRV_RTV     :: SRV | RTV;
    SRV_RTV_UAV :: SRV | RTV | UAV;
}

TEXTURE_SRV_TYPE :: enum u8 {
    TEXTURE2D;
    TEXTURE3D;
    TEXTURECUBE;
}

TEXTURE_ALL_MIP_USE :: enum_flags u32 {
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

    layouts:     [] D3D12_PLACED_SUBRESOURCE_FOOTPRINT;

    num_rows:    [] u32;
    row_sizes:   [] u64;

    bytesize: u32    = 0;
    is_cubemap: bool = false;

    srv_type:       TEXTURE_SRV_TYPE;
    mipuse:         TEXTURE_ALL_MIP_USE;
    texture_usage:  TEXTURE_USAGE;
    usage:          D3D12_RESOURCE_FLAGS = .NONE;
}

make_d3d12_texture :: (using renderer: *D3D12Renderer, using _texture: *D3D12Texture,
                       _format: DXGI_FORMAT, width: u32, height: u32, _usage:= TEXTURE_USAGE.SRV,
                       arraysize := 1, _miplevel := 1, _srv_type := TEXTURE_SRV_TYPE.TEXTURE2D, _mipuse := TEXTURE_ALL_MIP_USE.NONE,
                       _clear_value:= Default_Border_Color, state: D3D12_RESOURCE_STATES = .PIXEL_SHADER_RESOURCE) -> bool {

    bytesize        = xx get_image_bytes_per_texel(_format);
    format          = _format;
    texture_usage   = _usage;
    mipuse          = _mipuse;
    srv_type        = _srv_type;

    temp_clear : *D3D12_CLEAR_VALUE = null; 
    if (texture_usage & TEXTURE_USAGE.RTV) > 0 {
        clear_value.Format = _format;
        clear_value.Color  = _clear_value; 
        usage |= .ALLOW_RENDER_TARGET;
        temp_clear.* = clear_value;
    }

    if (texture_usage & TEXTURE_USAGE.DSV) > 0 {
        clear_value.Format = _format;
        if clear_value.Format == .R32_TYPELESS clear_value.Format = .D32_FLOAT;
        if clear_value.Format == .R16_TYPELESS clear_value.Format = .D16_UNORM;
        clear_value.DepthStencil.Depth   = 1.0;
        clear_value.DepthStencil.Stencil = 0;
        usage |= .ALLOW_DEPTH_STENCIL;
        temp_clear.* = clear_value;
    }

    if (texture_usage & TEXTURE_USAGE.UAV) > 0 {
        usage |= .ALLOW_UNORDERED_ACCESS;
    }

    desc.Width  = width;
    desc.Height = height;
    desc.DepthOrArraySize = xx arraysize;
    if (_srv_type & TEXTURE_SRV_TYPE.TEXTURECUBE) > 0 {
        desc.DepthOrArraySize *= 6;
    }
    desc.MipLevels  = xx _miplevel;
    desc.Format     = _format;
    desc.Dimension  = .TEXTURE2D;
    if (srv_type & TEXTURE_SRV_TYPE.TEXTURE3D) > 0 {
        desc.Dimension = .TEXTURE3D;
    }
    desc.SampleDesc.Count   = 1;
    desc.SampleDesc.Quality = 0;

    // gpu buffer
    ok := HR(ID3D12Device_CreateCommittedResource(device, *UTD3D12_HEAP_PROPERTIES(), .NONE, *desc, state, temp_clear, *uid(ID3D12Resource_UUID), xx *resource));
    if !ok return false;

    total_sub := desc.MipLevels * desc.DepthOrArraySize;
    array_resize(*states, total_sub);
    for *states {
        it.* = state;
    }

    layouts   = NewArray(total_sub, D3D12_PLACED_SUBRESOURCE_FOOTPRINT);
    num_rows  = NewArray(total_sub, u32);
    row_sizes = NewArray(total_sub, u64);

    upload_buffer_size: u64;
    ID3D12Device_GetCopyableFootprints(device, *desc, 0, desc.DepthOrArraySize * desc.MipLevels, 0, layouts.data, num_rows.data, row_sizes.data, *upload_buffer_size);

    // upload buffer
    ok = HR(ID3D12Device_CreateCommittedResource(device, *UTD3D12_HEAP_PROPERTIES(.UPLOAD), .NONE, *UTD3D12_BUFFER_RESOURCE_DESC(xx upload_buffer_size), .GENERIC_READ, null, *uid(ID3D12Resource_UUID), xx *upload_buffer));
    if !ok return false;
    
    make_srv(*_device, _texture, *heap_cbv_srv_uav);
    if (texture_usage & TEXTURE_USAGE.RTV) > 0 make_rtvs(*_device, _texture, *heap_rtv);
    if (texture_usage & TEXTURE_USAGE.DSV) > 0 make_dsv (*_device, _texture, *heap_dsv);
    if (texture_usage & TEXTURE_USAGE.UAV) > 0 make_uavs(*_device, _texture, *heap_cbv_srv_uav);

    return ok;
}

d3d12_texture_release :: (using _texture: *D3D12Texture) {

    array_free(layouts);
    array_free(num_rows);
    array_free(row_sizes);

    array_reset(*rtvs);
    array_reset(*dsvs);
    array_reset(*uavs);
    safe_release_and_reset(*resource);
    safe_release_and_reset(*upload_buffer);
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

make_srv  :: inline (using _device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    srv_desc: D3D12_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Shader4ComponentMapping = xx D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
    srv_desc.Format = desc.Format;

    if srv_desc.Format == .R32_TYPELESS then srv_desc.Format = .D32_FLOAT;
    if srv_desc.Format == .R16_TYPELESS then srv_desc.Format = .R16_UNORM;

    if srv_type == {
        case .TEXTURE2D;
            if desc.DepthOrArraySize == 1 {
                srv_desc.ViewDimension                  = .TEXTURE2D;
                srv_desc.Texture2D.MipLevels            = desc.MipLevels;
            } else {
                srv_desc.ViewDimension                  = .TEXTURE2DARRAY;
                srv_desc.Texture2DArray.ArraySize       = desc.DepthOrArraySize;
                srv_desc.Texture2DArray.FirstArraySlice = 0;
                srv_desc.Texture2DArray.MipLevels       = desc.MipLevels;
            }
        case .TEXTURE3D;
            srv_desc.ViewDimension                      = .TEXTURE3D;
            srv_desc.Texture3D.MipLevels                = desc.MipLevels;
            srv_desc.Texture3D.MostDetailedMip          = 0;
        case .TEXTURECUBE;
            if desc.DepthOrArraySize > 6 {
                srv_desc.ViewDimension                  = .TEXTURECUBEARRAY;
                srv_desc.TextureCubeArray.NumCubes      = desc.DepthOrArraySize / 6;
                srv_desc.TextureCubeArray.First2DArrayFace = 0;
                srv_desc.TextureCubeArray.MostDetailedMip  = 0;
                srv_desc.TextureCubeArray.MipLevels     = desc.MipLevels;
            } else {
                srv_desc.ViewDimension                  = .TEXTURECUBE;
                srv_desc.TextureCube.MostDetailedMip    = 0;
                srv_desc.TextureCube.MipLevels          = desc.MipLevels;
            }
    }

    base.srv = d3d12_descriptor_heap_resource_add(_device, heap, .SRV, resource, xx *srv_desc);
}

make_rtvs :: inline (using _device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    rtv_desc: D3D12_RENDER_TARGET_VIEW_DESC;
    rtv_desc.Format = desc.Format;

    if rtv_desc.Format == .R32_TYPELESS then rtv_desc.Format = .D32_FLOAT;
    if rtv_desc.Format == .R16_TYPELESS then rtv_desc.Format = .R16_UNORM;

    if srv_type == .TEXTURE3D {
        rtv_desc.ViewDimension = .TEXTURE3D;
        if (mipuse & .RTV) == 0 {
            array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                rtv_desc.Texture3D.MipSlice = i;
                array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
            }
        }
    } else if desc.DepthOrArraySize > 1 {
        rtv_desc.ViewDimension                  = .TEXTURE2DARRAY;
        rtv_desc.Texture2DArray.PlaneSlice      = 0;
        rtv_desc.Texture2DArray.ArraySize       = desc.DepthOrArraySize;
        rtv_desc.Texture2DArray.FirstArraySlice = 0;
        if (mipuse & .RTV) == 0 {
            array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                rtv_desc.Texture2DArray.MipSlice = i;
                array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
            }
        }
    } else {
        rtv_desc.ViewDimension = .TEXTURE2D;
        rtv_desc.Texture2D.PlaneSlice = 0;
        if (mipuse & .RTV) == 0 {
            array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                rtv_desc.Texture2D.MipSlice = i;
                array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *rtv_desc));
            }
        }
    }
}

make_dsv  :: inline (using _device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    dsv_desc: D3D12_DEPTH_STENCIL_VIEW_DESC;
    dsv_desc.Format = desc.Format;

    if dsv_desc.Format == .R32_TYPELESS then dsv_desc.Format = .D32_FLOAT;
    if dsv_desc.Format == .R16_TYPELESS then dsv_desc.Format = .R16_UNORM;

    if desc.DepthOrArraySize > 1 {
        dsv_desc.ViewDimension              = .TEXTURE2DARRAY;
        dsv_desc.Texture2DArray.ArraySize   = desc.DepthOrArraySize;
        dsv_desc.Texture2DArray.FirstArraySlice = 0;
        if (mipuse & .DSV) == 0 {
            array_add(*dsvs, d3d12_descriptor_heap_resource_add(_device, heap, .DSV, resource, xx *dsv_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                dsv_desc.Texture2DArray.MipSlice = i;
                array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .DSV, resource, xx *dsv_desc));
            }
        }
    } else {
        dsv_desc.ViewDimension              = .TEXTURE2D;
        if (mipuse & .DSV) == 0 {
            array_add(*dsvs, d3d12_descriptor_heap_resource_add(_device, heap, .DSV, resource, xx *dsv_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                dsv_desc.Texture2D.MipSlice = i;
                array_add(*rtvs, d3d12_descriptor_heap_resource_add(_device, heap, .DSV, resource, xx *dsv_desc));
            }
        }
    }
}

make_uavs :: inline (using _device: *D3D12Device, using _texture: D3D12Texture, heap: *D3D12Descriptor_Heap) {

    uav_desc: D3D12_UNORDERED_ACCESS_VIEW_DESC;
    uav_desc.Format = desc.Format;

    if uav_desc.Format == .R32_TYPELESS then uav_desc.Format = .D32_FLOAT;
    if uav_desc.Format == .R16_TYPELESS then uav_desc.Format = .R16_UNORM;

    if srv_type == .TEXTURE3D {
        uav_desc.ViewDimension = .TEXTURE3D;
        if (mipuse & .RTV) == 0 {
            array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .UAV, resource, xx *uav_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                uav_desc.Texture3D.MipSlice = i;
                array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .UAV, resource, xx *uav_desc));
            }
        }
    } else if desc.DepthOrArraySize > 1 {
        uav_desc.ViewDimension                  = .TEXTURE2DARRAY;
        uav_desc.Texture2DArray.PlaneSlice      = 0;
        uav_desc.Texture2DArray.ArraySize       = desc.DepthOrArraySize;
        uav_desc.Texture2DArray.FirstArraySlice = 0;
        if (mipuse & .UAV) == 0 {
            array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .UAV, resource, xx *uav_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                uav_desc.Texture2DArray.MipSlice = i;
                array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .UAV, resource, xx *uav_desc));
            }
        }
    } else {
        uav_desc.ViewDimension = .TEXTURE2D;
        uav_desc.Texture2D.PlaneSlice = 0;
        if (mipuse & .UAV) == 0 {
            array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *uav_desc));
        } else {
            for i: 0..desc.MipLevels - 1 {
                uav_desc.Texture2D.MipSlice = i;
                array_add(*uavs, d3d12_descriptor_heap_resource_add(_device, heap, .RTV, resource, xx *uav_desc));
            }
        }
    }
}