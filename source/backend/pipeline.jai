D3D12Root_Parameter :: struct {
    is_table: bool;
    visibility: D3D12_SHADER_VISIBILITY;
    type: Parameter_Type;
    bind_slot:      u32;
    shader_space:   u32;
    res_counts:     u32;
    uav_mip_level:  u32;

    union {
        range_flags: D3D12_DESCRIPTOR_RANGE_FLAGS;
        desc\_flags: D3D12_ROOT_DESCRIPTOR_FLAGS;
    }

    union {
        resource: *GPU_Resource;
        sampler:  *D3D12Sampler;
        constant_data: *void;
    }
}

D3D12Root_Signature :: struct {
    desc: D3D12_VERSIONED_ROOT_SIGNATURE_DESC;
    root_signature: *ID3D12RootSignature;
    parameters: [..] D3D12Root_Parameter;
}

Shader_Set :: struct {
    shaders: Table(string, D3D12Shader);
}

D3D12Render_Taget_Format :: struct {
    depth_enable: bool;
    cube\_enable: bool;

    num_of_rts: u32;
    rt_formats: [8]DXGI_FORMAT;
    ds_format:  DXGI_FORMAT;
    rt_flags:   D3D12_RESOURCE_FLAGS;
    ds_flags:   D3D12_RESOURCE_FLAGS;

    rt_clearvalue: [8]Clear_Value;
    ds_clearvalue: Clear_Value;
}

D3D12Depth_Stencil_State :: struct {
    state: D3D12_DEPTH_STENCIL_DESC;
}

D3D12Blend_State :: struct {
    state: D3D12_BLEND_DESC;
}

D3D12Rasterizer_State :: struct {
    state: D3D12_RASTERIZER_DESC;
}

D3D12Pipeline :: struct {
    type    : Pipeline_Type;
    pipeline: *ID3D12PipelineState;

    root_signature: D3D12Root_Signature;
}

d3d12_root_signature_init :: (using _device: *D3D12Device, using _root_signature: *D3D12Root_Signature) -> bool {

    feature_data: D3D12_FEATURE_DATA_ROOT_SIGNATURE;
    feature_data.HighestVersion = ._1_1;

    ok := HR(ID3D12Device_CheckFeatureSupport(device, .ROOT_SIGNATURE, *feature_data, size_of(D3D12_FEATURE_DATA_ROOT_SIGNATURE)));
    if !ok feature_data.HighestVersion = ._1_0;

    ranges: [..] D3D12_DESCRIPTOR_RANGE1;
    dx12_root_params: [..] D3D12_ROOT_PARAMETER1;
    dx12_param: D3D12_ROOT_PARAMETER1;

    array_resize(*ranges, parameters.count);
    for parameters {
        if it.type == .UNDEFINED return false;
        if it.type == {
            case .SRV;
                if it.is_table {
                    ranges[it_index] = D3D12_DESCRIPTOR_RANGE1_INIT(.SRV, parameters[it_index].res_counts, parameters[it_index].bind_slot, parameters[it_index].shader_space, xx parameters[it_index].range_flags);
                    dx12_param       = D3D12_ROOT_PARAMETER1_INIT_TABLE(1, *ranges[it_index], parameters[it_index].visibility); 
                } else {
                    dx12_param       = D3D12_ROOT_PARAMETER1_INIT_SRV(parameters[it_index].bind_slot, parameters[it_index].shader_space, xx parameters[it_index].desc_flags, parameters[it_index].visibility);
                }
            case .SAMPLER;
                ranges[it_index] = D3D12_DESCRIPTOR_RANGE1_INIT(.SAMPLER, parameters[it_index].res_counts, parameters[it_index].bind_slot, parameters[it_index].shader_space, xx parameters[it_index].range_flags);
                dx12_param       = D3D12_ROOT_PARAMETER1_INIT_TABLE(1, *ranges[it_index], parameters[it_index].visibility); 
        }
        array_add(*dx12_root_params, dx12_param);
    }

    desc.Version = ._1_1;
    desc.Desc_1_1.NumParameters     = xx dx12_root_params.count;
    desc.Desc_1_1.pParameters       = dx12_root_params.data;
    desc.Desc_1_1.NumStaticSamplers = 0;
    desc.Desc_1_1.pStaticSamplers   = null;
    desc.Desc_1_1.Flags             = .ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    signature: *ID3DBlob;
    error:     *ID3DBlob;

    result := D3D12SerializeVersionedRootSignature(*desc, *signature, *error);
    if FAILED(result) {
        msg := ID3D10Blob_GetBufferPointer(error); defer free(msg);
        log_error("D3D12SerializeVersionedRootSignature failed: %", to_string(msg));
        return false;
    };

    return HR(ID3D12Device_CreateRootSignature(device, 0, ID3D10Blob_GetBufferPointer(signature), ID3D10Blob_GetBufferSize(signature), *uid(ID3D12RootSignature_UUID), xx *root_signature));
}

d3d12_root_signature_release :: (using _root_signature: *D3D12Root_Signature) {

}

make_d3d12_graphics_pipeline :: (using _device: *D3D12Device, using _pipeline: *D3D12Pipeline, 
                                 rasterizer_state: *D3D12Rasterizer_State,
                                 blend_state: *D3D12Blend_State,
                                 format: *D3D12Render_Taget_Format, 
                                 depthstencil_state: *D3D12Depth_Stencil_State,
                                 shader_set: *Shader_Set, 
                                 inputlayout: Vertex_Input_Layout_Type,
                                 topology: D3D12_PRIMITIVE_TOPOLOGY_TYPE = .TRIANGLE) -> bool {

    type = .GRAPHICS;

    pso_desc: D3D12_GRAPHICS_PIPELINE_STATE_DESC;

    vsshader := table_find_pointer(*shader_set.shaders, "VS");
    if vsshader {
        pso_desc.VS = UTD_D3D12_SHADER_BYTECODE(vsshader.shader);

        input_elements := shader_get_input_element(vsshader, inputlayout);
        pso_desc.InputLayout.NumElements = xx input_elements.count;
        pso_desc.InputLayout.pInputElementDescs = input_elements.data;
    }

    psshader := table_find_pointer(*shader_set.shaders, "PS");
    if psshader {
        pso_desc.PS = UTD_D3D12_SHADER_BYTECODE(psshader.shader);
    }

    pso_desc.pRootSignature  = root_signature.root_signature;
    pso_desc.RasterizerState = rasterizer_state.state;
    pso_desc.BlendState      = blend_state.state;
    pso_desc.PrimitiveTopologyType = topology;
    pso_desc.NumRenderTargets = format.num_of_rts;
    
    for i: 0..format.num_of_rts {
        pso_desc.RTVFormats[i] = format.rt_formats[i];
    }

    pso_desc.DepthStencilState = depthstencil_state.state;
    pso_desc.DSVFormat = format.ds_format;

    if pso_desc.DSVFormat == .R32_TYPELESS pso_desc.DSVFormat = .D32_FLOAT;
    if pso_desc.DSVFormat == .R16_TYPELESS pso_desc.DSVFormat = .D16_UNORM;

    pso_desc.SampleDesc.Count = 1;
    pso_desc.SampleMask       = INFINITE;

    return HR(ID3D12Device_CreateGraphicsPipelineState(device, *pso_desc, *uid(ID3D12PipelineState_UUID), xx *pipeline));

}

make_d3d12_compute_pipeline  :: (using _device: *D3D12Device) -> bool {

    return true;
}

d3d12_pipeline_release :: (using _pipeline: *D3D12Pipeline) {

    safe_release_and_reset(*pipeline);
    safe_release_and_reset(*root_signature.root_signature);
}