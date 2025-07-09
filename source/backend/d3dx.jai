Handles :: struct {
    gpu:  D3D12_GPU_DESCRIPTOR_HANDLE;
    cpu:  D3D12_CPU_DESCRIPTOR_HANDLE;
}

UTD3D12Texture :: inline () -> D3D12Texture {

    texture: D3D12Texture;
    texture.resource_type = .TEXTURE;
    texture.bytesize      = 0;
    return texture;
}

UTD3D12_TEXTURE_COPY_LOCATION_INIT :: inline (resource: *ID3D12Resource, footprint: D3D12_PLACED_SUBRESOURCE_FOOTPRINT) -> D3D12_TEXTURE_COPY_LOCATION {

    location: D3D12_TEXTURE_COPY_LOCATION;
    location.pResource  = resource;
    location.Type       = .PLACED_FOOTPRINT;
    location.PlacedFootprint = footprint;
    return location;
}

UTD3D12_TEXTURE_COPY_LOCATION_INIT :: inline (resource: *ID3D12Resource, sub: u32)-> D3D12_TEXTURE_COPY_LOCATION {

    location: D3D12_TEXTURE_COPY_LOCATION;
    location.pResource          = resource;
    location.Type               = .SUBRESOURCE_INDEX;
    location.SubresourceIndex   = sub;
    return location;
}

UTD_D3D12_SHADER_BYTECODE :: inline (_shader: *ID3DBlob) -> D3D12_SHADER_BYTECODE {

    shader: D3D12_SHADER_BYTECODE;
    shader.BytecodeLength    = ID3D10Blob_GetBufferSize(_shader);
    shader.pShaderBytecode   = ID3D10Blob_GetBufferPointer(_shader);
    return shader;
}

UTD3D12_RASTERIZER_DESC_INIT :: inline () -> D3D12Rasterizer_State {

    using rasterizer_state: D3D12Rasterizer_State;
    state.FillMode              = .SOLID;
    state.CullMode              = .BACK;
    state.FrontCounterClockwise = .FALSE;
    state.DepthBias             = D3D12_DEFAULT_DEPTH_BIAS;
    state.DepthBiasClamp        = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    state.SlopeScaledDepthBias  = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    state.DepthClipEnable       = .FALSE;
    state.MultisampleEnable     = .FALSE;
    state.AntialiasedLineEnable = .FALSE;
    return rasterizer_state;
}

UTD3D12_BLEND_DESC_INIT :: inline () -> D3D12Blend_State {

    using blend_state: D3D12Blend_State;
    state.AlphaToCoverageEnable = .FALSE;
    state.IndependentBlendEnable= .FALSE;
    for i : 0..7 {
        state.RenderTarget[i].LogicOpEnable = .FALSE;
        state.RenderTarget[i].LogicOp       = .CLEAR;
        state.RenderTarget[i].BlendEnable   = .FALSE;
        state.RenderTarget[i].SrcBlend      = .ONE;
        state.RenderTarget[i].DestBlend     = .ZERO;
        state.RenderTarget[i].BlendOp       = .ADD;
        state.RenderTarget[i].SrcBlendAlpha = .ONE;
        state.RenderTarget[i].DestBlendAlpha= .ZERO;
        state.RenderTarget[i].BlendOpAlpha  = .ADD;
        state.RenderTarget[i].RenderTargetWriteMask = cast(u8) D3D12_COLOR_WRITE_ENABLE.ALL;
    }
    return blend_state;
}

UTD3D12_DEPTH_STENCIL_DESC_INIT :: inline () -> D3D12Depth_Stencil_State {

    using depth_stencil_state: D3D12Depth_Stencil_State;
    state.DepthEnable    = .FALSE;
    state.StencilEnable  = .FALSE;
    return depth_stencil_state;
}

UTD3D12_RENDER_TARGET_FORMAT_INIT :: inline () -> D3D12Render_Taget_Format {

    using rtf: D3D12Render_Taget_Format;
    depth_enable  = false;
    num_of_rts    = 1;
    rt_clearvalue[0] = .{color=.[0.0, 0.0, 0.0, 1.0]};
    rt_flags      = .ALLOW_RENDER_TARGET;
    rt_formats[0] = .R8G8B8A8_UNORM;
    return rtf;
}

UTD3D12_HEAP_PROPERTIES :: inline (type: D3D12_HEAP_TYPE = .DEFAULT) -> D3D12_HEAP_PROPERTIES {

    prop: D3D12_HEAP_PROPERTIES;
    prop.Type                   = type;
    prop.CPUPageProperty        = .UNKNOWN;
    prop.MemoryPoolPreference   = .UNKNOWN;
    prop.CreationNodeMask       = 1;
    prop.VisibleNodeMask        = 1;
    return prop;
}

UTD3D12_BUFFER_RESOURCE_DESC :: inline (size: u32) -> D3D12_RESOURCE_DESC {

    desc: D3D12_RESOURCE_DESC;
    desc.Dimension =        .BUFFER;
    desc.Alignment =        0;
    desc.Width =            xx size;
    desc.Height =           1;
    desc.DepthOrArraySize = 1;
    desc.MipLevels =        1;
    desc.Format =           .UNKNOWN;
    desc.SampleDesc.Count = 1;
    desc.SampleDesc.Quality=0;
    desc.Layout =           .ROW_MAJOR;
    desc.Flags =            .NONE;
    return desc;
}

UTD3D12_ROOT_CONSTANTS_INIT :: inline (shader_register: u32, register_space: u32, num_32_bit_values: u32) -> D3D12_ROOT_CONSTANTS {

    root_constant: D3D12_ROOT_CONSTANTS;
    root_constant.ShaderRegister = shader_register;
    root_constant.RegisterSpace  = register_space;
    root_constant.Num32BitValues = num_32_bit_values;
    return root_constant;
}

D3D12_DESCRIPTOR_RANGE1_INIT :: inline (type: D3D12_DESCRIPTOR_RANGE_TYPE, counts: u32, base_shader_register: u32, register_space: u32 = 0, offset_in_descriptors_from_table_start := D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND) -> D3D12_DESCRIPTOR_RANGE1 {

    desc: D3D12_DESCRIPTOR_RANGE1;
    desc.RangeType             = type;
    desc.NumDescriptors        = counts;
    desc.BaseShaderRegister    = base_shader_register;
    desc.RegisterSpace         = register_space;
    desc.OffsetInDescriptorsFromTableStart = xx offset_in_descriptors_from_table_start;
    return desc;
}

D3D12_ROOT_DESCRIPTOR1_INIT :: inline (shader_register: u32, register_space: u32, flags: D3D12_ROOT_DESCRIPTOR_FLAGS) -> D3D12_ROOT_DESCRIPTOR1 {

    desc: D3D12_ROOT_DESCRIPTOR1;
    desc.ShaderRegister = shader_register;
    desc.RegisterSpace  = register_space;
    desc.Flags          = flags; 
    return desc;
}

D3D12_ROOT_PARAMETER1_INIT_TABLE :: inline (num_descriptor_range: u32, range: *D3D12_DESCRIPTOR_RANGE1, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    desc: D3D12_ROOT_PARAMETER1;
    desc.ParameterType                         = .DESCRIPTOR_TABLE;
    desc.DescriptorTable.NumDescriptorRanges   = num_descriptor_range;
    desc.DescriptorTable.pDescriptorRanges     = range;
    desc.ShaderVisibility                      = visibility;
    return desc;
}

D3D12_ROOT_PARAMETER1_INIT_CBV :: inline (shader_register: u32, register_space: u32 = 0, descriptor_flags: D3D12_ROOT_DESCRIPTOR_FLAGS, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    desc: D3D12_ROOT_PARAMETER1;
    desc.ParameterType     = .CBV;
    desc.Descriptor        = D3D12_ROOT_DESCRIPTOR1_INIT(shader_register, register_space, descriptor_flags);
    desc.ShaderVisibility  = visibility;
    return desc;
}

D3D12_ROOT_PARAMETER1_INIT_SRV :: inline (shader_register: u32, register_space: u32 = 0, descriptor_flags: D3D12_ROOT_DESCRIPTOR_FLAGS, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    desc: D3D12_ROOT_PARAMETER1;
    desc.ParameterType     = .SRV;
    desc.Descriptor        = D3D12_ROOT_DESCRIPTOR1_INIT(shader_register, register_space, descriptor_flags);
    desc.ShaderVisibility  = visibility;
    return desc;
}

D3D12_ROOT_PARAMETER1_INIT_UAV :: inline (shader_register: u32, register_space: u32 = 0, descriptor_flags: D3D12_ROOT_DESCRIPTOR_FLAGS, visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {

    desc: D3D12_ROOT_PARAMETER1;
    desc.ParameterType     = .UAV;
    desc.Descriptor        = D3D12_ROOT_DESCRIPTOR1_INIT(shader_register, register_space, descriptor_flags);
    desc.ShaderVisibility  = visibility;
    return desc;
}

D3D12_SAMPLER_INIT :: (filter: D3D12_FILTER = .MIN_MAG_MIP_LINEAR, u: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, v: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, w: D3D12_TEXTURE_ADDRESS_MODE = .CLAMP, border_color:= Default_Border_Color, miplodbias : float = 0, maxanisotropy:=D3D12_DEFAULT_MAX_ANISOTROPY, minlod: float = 0, maxlod:= D3D12_FLOAT32_MAX, comparison_func : D3D12_COMPARISON_FUNC = .NEVER)-> D3D12Sampler {

    using _sampler: D3D12Sampler;
    desc.Filter   = filter;
    desc.AddressU = u;
    desc.AddressV = v;
    desc.AddressW = w;
    desc.MipLODBias       = miplodbias;
    desc.MaxAnisotropy    = xx maxanisotropy;
    desc.ComparisonFunc   = comparison_func;
    desc.BorderColor      = border_color;
    desc.MinLOD           = minlod;
    desc.MaxLOD           = xx maxlod;
    return _sampler;
}

d3d12_cpu_descriptor_handle_offset :: inline (this: *D3D12_CPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}

d3d12_gpu_descriptor_handle_offset :: inline (this: *D3D12_GPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}

UpdateSubresource :: (
    cmdlist:            *ID3D12GraphicsCommandList,
    dest:               *ID3D12Resource,
    intermediate:       *ID3D12Resource, 
    first_subresource:  u64,
    num_subresource:    u32,
    required_size:      u64,
    layouts:            *D3D12_PLACED_SUBRESOURCE_FOOTPRINT,
    num_rows:           *u32,
    row_sizes:          *u64, 
    src_data:           *D3D12_SUBRESOURCE_DATA) -> u64 {

    intermediate_desc := ID3D12Resource_GetDesc(intermediate);
    destination\_desc := ID3D12Resource_GetDesc(dest);
    if intermediate_desc.Dimension != .BUFFER return 0;
    if intermediate_desc.Width < cast(u64) required_size + layouts[0].Offset return 0;
    if (destination_desc.Dimension == .BUFFER && first_subresource != 0 || num_subresource != 1) return 0;

    data: *u8;
    ok := HR(ID3D12Resource_Map(intermediate, 0, null, xx *data));
    if !ok return 0;

    for i: 0..num_subresource - 1 {
        layout := layouts[i];
        dest_data: D3D12_MEMCPY_DEST;
        dest_data.pData      = data + layout.Offset;
        dest_data.RowPitch   = xx layout.Footprint.RowPitch;
        dest_data.SlicePitch = xx layout.Footprint.RowPitch * num_rows[i];
        memcpy_subresource(*dest_data, *src_data[i], xx row_sizes[i], num_rows[i], layout.Footprint.Depth);
    }
    ID3D12Resource_Unmap(intermediate, 0, null);

    if destination_desc.Dimension == .BUFFER {
        ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, dest, 0, intermediate, layouts[0].Offset, layouts[0].Footprint.Width);
    } else {
        for i: 0..num_subresource - 1 {
            dst := UTD3D12_TEXTURE_COPY_LOCATION_INIT(dest, cast(u32) (i + first_subresource));
            src := UTD3D12_TEXTURE_COPY_LOCATION_INIT(intermediate, layouts[i]);
            ID3D12GraphicsCommandList_CopyTextureRegion(cmdlist, *dst, 0, 0, 0, *src, null);
        }
    }

    return required_size;
}

// Heap allocating update subresource implementation
update_subresource :: inline (
    cmdlist:            *ID3D12GraphicsCommandList, 
    dest:               *ID3D12Resource, 
    intermediate:       *ID3D12Resource, 
    intermediate_offset:s64,
    first_subresource:  u64,
    num_subresource:    u32,
    src_data:           *D3D12_SUBRESOURCE_DATA) -> u64 {

    required_size : u64 = 0;
    mem_to_alloc  : s64 = cast(s64) ((size_of(D3D12_PLACED_SUBRESOURCE_FOOTPRINT) + size_of(u32) + size_of(u64)) * num_subresource);
    if mem_to_alloc > SIZE_MAX return 0;

    mem := alloc(mem_to_alloc); defer free(mem);
    if mem == null return 0;

    layouts  := cast(*D3D12_PLACED_SUBRESOURCE_FOOTPRINT) mem;
    rowsizes := cast(*u64) (layouts + num_subresource);
    numrows  := cast(*u32) (rowsizes + num_subresource);

    destination_desc := ID3D12Resource_GetDesc(dest);
    device : *ID3D12Device;
    ok := HR(ID3D12DeviceChild_GetDevice(dest, *uid(ID3D12Device_UUID), xx *device)); defer safe_release_and_reset(*device);
    ID3D12Device_GetCopyableFootprints(device, *destination_desc, xx first_subresource, num_subresource, xx intermediate_offset, layouts, numrows, rowsizes, *required_size);
    if !ok return 0;

    return UpdateSubresource(cmdlist, dest, intermediate, first_subresource, num_subresource, required_size, layouts, numrows, rowsizes, src_data);
}

memcpy_subresource :: (dest: *D3D12_MEMCPY_DEST, src: *D3D12_SUBRESOURCE_DATA, row_size: s64, num_rows: u32, num_slices: u32) {

    for z: 0..num_slices - 1 {
        dest_slice: *u8 = cast(*u8) dest.pData + dest.SlicePitch * z;
        src_slice:  *u8 = cast(*u8) src.pData + src.SlicePitch * z;
        for y: 0..num_rows - 1 {
            memcpy(dest_slice + dest.RowPitch * y, src_slice + src.RowPitch * y, row_size);
        }
    }
}

#scope_file