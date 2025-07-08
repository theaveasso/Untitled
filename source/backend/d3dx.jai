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


d3d12_cpu_desciptor_handle_offset :: inline (this: *D3D12_CPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}

d3d12_gpu_desciptor_handle_offset :: inline (this: *D3D12_GPU_DESCRIPTOR_HANDLE, offset_scaled_by_inc_size: int, descriptor_inc_size: u32 = 1) {
    this.ptr += xx (offset_scaled_by_inc_size * descriptor_inc_size);
}