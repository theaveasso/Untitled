CalculateConstantBufferByteSize :: inline (bytesize: int) -> int { return (bytesize + 255) & ~255; }

NAME_D3D12_OBJECT :: inline (object: *ID3D12Object, name: string) { ID3D12Object_SetName(object, xx name.data); }

HR :: inline (hr: HRESULT, infoqueue: *ID3D12InfoQueue = null, $call := #caller_code, loc :=  #caller_location) -> bool {
    
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
        print_debug_msgs(infoqueue);
        action := call_string;
        printed_result := tprint("% % % failed!", action, hr, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        log_error(printed_result);
        return false;
    }

    return true;
}

Compile_Shader :: (using _shader: *Shader, error: *ID3DBlob, file_name: string, entry_point: string, target: string) -> bool {

    compile_flags := D3DCOMPILE.ENABLE_STRICTNESS;
    #if DEBUG {
        compile_flags |= D3DCOMPILE.DEBUG ;
        compile_flags |= D3DCOMPILE.SKIP_OPTIMIZATION;
    } 

    result: HRESULT;
    defines: [] string;
    shader, error, result = D3DCompileFromFile(file_name, defines, null, entry_point, target, xx compile_flags, 0);
    if FAILED(result) {
        msg := ID3D10Blob_GetBufferPointer(error); 
        log_error("load_assets: Failed to compile from file %", to_string(msg));
        return false;
    }

    HR(D3DReflect(ID3D10Blob_GetBufferPointer(shader), ID3D10Blob_GetBufferSize(shader), *uid(ID3D12ShaderReflection_UUID), xx *reflector));
    HR(ID3D12ShaderReflection_GetDesc(reflector, *desc));

    return true;
}

print_debug_msgs :: (infoqueue: *ID3D12InfoQueue) {
    if !infoqueue return;
    msgs_count := ID3D12InfoQueue_GetNumStoredMessages(infoqueue);
    // print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        ok := ID3D12InfoQueue_GetMessageA(infoqueue, it, null, *size);

        // WARNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg: *D3D12_MESSAGE = xx alloc(xx size);
        defer free(msg);
        ok = ID3D12InfoQueue_GetMessageA(infoqueue, it, msg, *size);

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

    ID3D12InfoQueue_ClearStoredMessages(infoqueue);
}

D3D12_DESCRIPTOR_RANGE1_INIT :: inline (
    type: D3D12_DESCRIPTOR_RANGE_TYPE,
    num_descriptors: u32,
    base_shader_register: u32,
    register_space: u32 = 0,
    flags: D3D12_DESCRIPTOR_RANGE_FLAGS = .NONE,
    offset_in_descriptors_from_table_start: u32 = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND) -> D3D12_DESCRIPTOR_RANGE1 {
    ret: D3D12_DESCRIPTOR_RANGE1;
    ret.RangeType            = type;
    ret.NumDescriptors       = num_descriptors;
    ret.BaseShaderRegister   = base_shader_register;
    ret.RegisterSpace        = register_space; 
    ret.Flags                = flags;
    ret.OffsetInDescriptorsFromTableStart = offset_in_descriptors_from_table_start;
    return ret;
}
D3D12_ROOT_DESCRIPTOR_TABLE1_INIT :: inline (
    num_descriptor_range: u32,
    descriptor_range: *D3D12_DESCRIPTOR_RANGE1) -> D3D12_ROOT_DESCRIPTOR_TABLE1 {
    ret: D3D12_ROOT_DESCRIPTOR_TABLE1;
    ret.NumDescriptorRanges = num_descriptor_range;
    ret.pDescriptorRanges   = descriptor_range;
    return ret;
}
D3D12_ROOT_PARAMETER1_INIT_AS_DESCRIPTOR_TABLE :: inline (
    num_descriptor_range: u32,
    range: *D3D12_DESCRIPTOR_RANGE1,
    visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {
    ret: D3D12_ROOT_PARAMETER1;
    ret.ParameterType    = .DESCRIPTOR_TABLE;
    ret.DescriptorTable  = D3D12_ROOT_DESCRIPTOR_TABLE1_INIT(num_descriptor_range, range);
    ret.ShaderVisibility = visibility;
    return ret;
}
D3D12_ROOT_PARAMETER1_INIT_AS_CONSTANTS :: inline (
    num_32_bit_values: u32,
    shader_register: u32,
    register_space:  u32 = 0,
    visibility: D3D12_SHADER_VISIBILITY = .ALL) -> D3D12_ROOT_PARAMETER1 {
    ret: D3D12_ROOT_PARAMETER1;
    ret.ParameterType            = ._32BIT_CONSTANTS;
    ret.Constants.ShaderRegister = shader_register;
    ret.Constants.RegisterSpace  = register_space;
    ret.Constants.Num32BitValues = num_32_bit_values;
    ret.ShaderVisibility         = visibility;
    return ret;
}
D3D12_SHADER_BYTECODE_INIT :: inline (
    shader: *ID3DBlob) -> D3D12_SHADER_BYTECODE {
    ret: D3D12_SHADER_BYTECODE;       
    ret.pShaderBytecode = ID3D10Blob_GetBufferPointer(shader);
    ret.BytecodeLength  = ID3D10Blob_GetBufferSize(shader);
    return ret;
}
D3D12_BLEND_DESC_INIT :: inline (
) -> D3D12_BLEND_DESC {
    ret: D3D12_BLEND_DESC;
    ret.AlphaToCoverageEnable   = .FALSE;
    ret.IndependentBlendEnable  = .FALSE; 

    rtb_desc: D3D12_RENDER_TARGET_BLEND_DESC;
    rtb_desc.BlendEnable    = .FALSE;
    rtb_desc.LogicOpEnable  = .FALSE;
    rtb_desc.SrcBlend       = .ONE;
    rtb_desc.DestBlend      = .ZERO;
    rtb_desc.BlendOp        = .ADD;
    rtb_desc.SrcBlendAlpha  = .ONE;
    rtb_desc.DestBlendAlpha = .ZERO;
    rtb_desc.BlendOpAlpha   = .ADD;
    rtb_desc.LogicOp        = .NOOP;
    rtb_desc.RenderTargetWriteMask = xx D3D12_COLOR_WRITE_ENABLE.ALL;
    for i: 0..D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT - 1 {
        ret.RenderTarget[i] = rtb_desc;
    }
    return ret;
}
D3D12_RASTERIZER_DESC_INIT :: inline (
) -> D3D12_RASTERIZER_DESC {
    ret: D3D12_RASTERIZER_DESC;
    ret.FillMode                = .SOLID;
    ret.CullMode                = .BACK;
    ret.FrontCounterClockwise   = .FALSE;
    ret.DepthBias               = D3D12_DEFAULT_DEPTH_BIAS;
    ret.DepthBiasClamp          = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    ret.SlopeScaledDepthBias    = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    ret.DepthClipEnable         = .TRUE;
    ret.MultisampleEnable       = .FALSE;
    ret.AntialiasedLineEnable   = .FALSE;
    ret.ForcedSampleCount       = 0;
    ret.ConservativeRaster      = D3D12_CONSERVATIVE_RASTERIZATION_MODE.OFF;
    return ret;
}
D3D12_DEPTH_STENCIL_DESC_INIT :: inline (
    depth_test: bool = false) -> D3D12_DEPTH_STENCIL_DESC {
    ret: D3D12_DEPTH_STENCIL_DESC;
    ret.DepthEnable     = ifx depth_test then .TRUE else .FALSE;
    ret.DepthWriteMask  = ifx depth_test then .ALL else .ZERO;
    ret.DepthFunc       = .LESS;
    ret.StencilEnable   = .FALSE;
    return ret;
}
D3D12_HEAP_PROPERTIES_INIT :: inline (
    type: D3D12_HEAP_TYPE = .DEFAULT) -> D3D12_HEAP_PROPERTIES {
    ret: D3D12_HEAP_PROPERTIES;
    ret.Type                 = type;
    ret.CPUPageProperty      = .UNKNOWN;
    ret.MemoryPoolPreference = .UNKNOWN;
    ret.CreationNodeMask     = 1;
    ret.VisibleNodeMask      = 1;
    return ret;
}
D3D12_RESOURCE_DESC_INIT_AS_BUFFER :: inline (
    buffer_size: u64,
    flags: D3D12_RESOURCE_FLAGS = .NONE,
    alignment: u32 = 0) -> D3D12_RESOURCE_DESC {
    ret: D3D12_RESOURCE_DESC;
    ret.Dimension           = .BUFFER;
    ret.Alignment           = 0;
    ret.Width               = buffer_size;
    ret.Height              = 1;
    ret.DepthOrArraySize    = 1;
    ret.MipLevels           = 1;
    ret.Format              = .UNKNOWN;
    ret.SampleDesc.Count    = 1;
    ret.SampleDesc.Quality  = 0;
    ret.Layout              = .ROW_MAJOR;
    ret.Flags               = flags;
    return ret;
}
D3D12_RESOURCE_DESC_INIT_AS_TEXTURE2D :: inline (
    format: DXGI_FORMAT,
    width: u64,
    height: u64,
    depth_or_array_size: u16 = 1,
    mip_level: u16 = 0,
    sample_count: u32 = 1,
    sample_quality: u32 = 0,
    flags: D3D12_RESOURCE_FLAGS = .NONE,
    layout: D3D12_TEXTURE_LAYOUT = .UNKNOWN,
    alignment: u32 = 0) -> D3D12_RESOURCE_DESC {
    ret: D3D12_RESOURCE_DESC;
    ret.Dimension           = .TEXTURE2D;
    ret.Alignment           = alignment;
    ret.Width               = xx width;
    ret.Height              = xx height;
    ret.DepthOrArraySize    = depth_or_array_size;
    ret.MipLevels           = mip_level;
    ret.Format              = format;
    ret.SampleDesc.Count    = sample_count;
    ret.SampleDesc.Quality  = sample_quality;
    ret.Layout              = layout;
    ret.Flags               = flags;
    return ret;
}
D3D12_RESOURCE_DESC_INIT_AS_TEXTURE3D :: inline (
    format: DXGI_FORMAT,
    width: u64,
    height: u64,
    depth_or_array_size: u16 = 1,
    mip_level: u16 = 0,
    sample_count: u32 = 1,
    sample_quality: u32 = 0,
    flags: D3D12_RESOURCE_FLAGS = .NONE,
    layout: D3D12_TEXTURE_LAYOUT = .UNKNOWN,
    alignment: u32 = 0) -> D3D12_RESOURCE_DESC {
    ret: D3D12_RESOURCE_DESC;
    ret.Dimension           = .TEXTURE3D;
    ret.Alignment           = alignment;
    ret.Width               = xx width;
    ret.Height              = xx height;
    ret.DepthOrArraySize    = depth_or_array_size;
    ret.MipLevels           = mip_level;
    ret.Format              = format;
    ret.SampleDesc.Count    = sample_count;
    ret.SampleDesc.Quality  = sample_quality;
    ret.Layout              = layout;
    ret.Flags               = flags;
    return ret;
}
D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION :: inline (
    resource: *ID3D12Resource, 
    state_before: D3D12_RESOURCE_STATES, 
    state_after: D3D12_RESOURCE_STATES,
    subresource:=D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
    flags : D3D12_RESOURCE_BARRIER_FLAGS = .NONE) -> D3D12_RESOURCE_BARRIER {
    ret: D3D12_RESOURCE_BARRIER;
    ret.Type    = .TRANSITION;
    ret.Flags   = flags;
    ret.Transition.pResource   = resource;
    ret.Transition.Subresource = xx subresource;
    ret.Transition.StateBefore = state_before;
    ret.Transition.StateAfter  = state_after;
    return ret;
}