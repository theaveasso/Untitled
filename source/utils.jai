MAX_SIZE :: 0x4_0000;

GetImageBytesPerTexel :: inline (tf: DXGI_FORMAT) -> int {

   using DXGI_FORMAT;

    if tf == {
        case R8_TYPELESS;           #through;
        case R8G8_SINT;             #through;
        case R16_FLOAT;             #through;
        case D16_UNORM;             return 2;
        case R8G8B8A8_TYPELESS;     #through;
        case R8G8B8A8_UNORM;        #through;
        case R8G8B8A8_UNORM_SRGB;   #through;
        case R8G8B8A8_UINT;         #through;
        case R8G8B8A8_SNORM;        #through;
        case R8G8B8A8_SINT;         #through;
        case R16G16_TYPELESS;       #through;
        case R16G16_FLOAT;          #through;
        case R16G16_UNORM;          #through;
        case R16G16_UINT;           #through;
        case R16G16_SNORM;          #through;
        case R16G16_SINT;           #through;
        case R32_TYPELESS;          #through;
        case D32_FLOAT;             return 4;
        case R16G16B16A16_TYPELESS; #through;
        case R16G16B16A16_FLOAT;    #through;
        case R16G16B16A16_UNORM;    #through;
        case R16G16B16A16_SNORM;    #through;
        case R16G16B16A16_SINT;     #through;
        case R32G32_TYPELESS;       #through;
        case R32G32_FLOAT;          #through;
        case R32G32_UINT;           #through;
        case R32G32_SINT;           return 8;
        case R32G32B32_UINT;        #through;
        case R32G32B32_SINT;        return 12;
        case R32G32B32A32_TYPELESS; #through;
        case R32G32B32A32_FLOAT;    #through;
        case R32G32B32A32_UINT;     #through;
        case R32G32B32A32_SINT;     #through;
        case R32G32B32_TYPELESS;    #through;
        case R32G32B32_FLOAT;       return 16;
    }

    return 0;
}

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
            dst := D3D12_TEXTURE_COPY_LOCATION_INIT(dest, cast(u32) (i + first_subresource));
            src := D3D12_TEXTURE_COPY_LOCATION_INIT(intermediate, layouts[i]);
            ID3D12GraphicsCommandList_CopyTextureRegion(cmdlist, *dst, 0, 0, 0, *src, null);
        }
    }

    return required_size;
}

// Heap allocating update subresource implementation
UpdateSubresource :: inline (
    cmdlist:            *ID3D12GraphicsCommandList, 
    dest:               *ID3D12Resource, 
    intermediate:       *ID3D12Resource, 
    intermediate_offset:s64,
    first_subresource:  u64,
    num_subresource:    u32,
    src_data:           *D3D12_SUBRESOURCE_DATA) -> u64 {

    required_size : u64 = 0;
    mem_to_alloc  : s64 = cast(s64) ((size_of(D3D12_PLACED_SUBRESOURCE_FOOTPRINT) + size_of(u32) + size_of(u64)) * num_subresource);
    if mem_to_alloc > MAX_SIZE return 0;

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
    mip_level: u16 = 1,
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

D3D12_TEXTURE_COPY_LOCATION_INIT :: inline (
    resource: *ID3D12Resource,
     footprint: D3D12_PLACED_SUBRESOURCE_FOOTPRINT) -> D3D12_TEXTURE_COPY_LOCATION {

    ret: D3D12_TEXTURE_COPY_LOCATION;
    ret.pResource  = resource;
    ret.Type       = .PLACED_FOOTPRINT;
    ret.PlacedFootprint = footprint;
    return ret;
}

D3D12_TEXTURE_COPY_LOCATION_INIT :: inline (
    resource: *ID3D12Resource, 
    sub: u32) -> D3D12_TEXTURE_COPY_LOCATION {

    ret: D3D12_TEXTURE_COPY_LOCATION;
    ret.pResource          = resource;
    ret.Type               = .SUBRESOURCE_INDEX;
    ret.SubresourceIndex   = sub;
    return ret;
}