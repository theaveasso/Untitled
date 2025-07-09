HR :: inline (hr: HRESULT, info_queue: *ID3D12InfoQueue = null, $call := #caller_code, loc :=  #caller_location) -> bool {
    
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
        if info_queue print_debug_msgs(info_queue);
        action := call_string;
        printed_result := tprint("% % % failed!", action, hr, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        log_error(printed_result);
        return false;
    }

    return true;
}

calc_constant_buffer_byte_size :: inline (bytesize: s64) -> s64 { return (bytesize + 255) & ~255; }

print_debug_msgs :: (d3d12_info_queue:*ID3D12InfoQueue) {
    if !d3d12_info_queue return;
    msgs_count := ID3D12InfoQueue_GetNumStoredMessages(d3d12_info_queue);
    // print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        ok := ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, null, *size);

        // WARNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg: *D3D12_MESSAGE = xx alloc(xx size);
        defer free(msg);
        ok = ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, msg, *size);

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

    ID3D12InfoQueue_ClearStoredMessages(d3d12_info_queue);
}

compile_d3d_shader :: (using _shader: *D3D12Shader, source: string, entry_point: string) -> bool {
    flags := D3DCOMPILE.ENABLE_STRICTNESS; 
        // Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
        // Setting this flag improves the shader debugging experience, but still allows  
        // the shaders to be optimized and to run exactly the way they will run in  
        // the release configuration of this program. 
    #if DEBUG {
        flags |= .DEBUG; 
        // Disable optimizations to further improve shader debugging 
        flags |= .SKIP_OPTIMIZATION; 
        flags |= .ENABLE_UNBOUNDED_DESCRIPTOR_TABLES;
        flags |= .PACK_MATRIX_COLUMN_MAJOR;
    } else {
        flags |= .ENABLE_UNBOUNDED_DESCRIPTOR_TABLES;
        flags |= .PACK_MATRIX_COLUMN_MAJOR;
    }
    error: *ID3DBlob;
    defines: D3D_SHADER_MACRO;

    hr := D3DCompile(xx source.data, xx source.count, null, *defines, D3D_COMPILE_STANDARD_FILE_INCLUDE, xx entry_point.data, Target_Shader_Models[type], xx flags, 0, *shader, *error);

    if FAILED(hr) { 
        msg := ID3D10Blob_GetBufferPointer(error); defer free(msg);
        log_error("D3DCompile failed: %", to_string(msg));
        return false;
    } 

    HR(D3DReflect(ID3D10Blob_GetBufferPointer(shader), ID3D10Blob_GetBufferSize(shader), *uid(ID3D12ShaderReflection_UUID), xx *reflector));
    HR(ID3D12ShaderReflection_GetDesc(reflector, *desc));

    return true;
}

D3D12_SetDebugObjectName :: inline (resource: *ID3D12Object, guid: *GUID, name: string) {
    #if DEBUG {
        ID3D12Object_SetPrivateData(resource, guid, xx name.count, name.data);
    }
}

D3D12_SetDebugObjectName :: inline (resource: *IDXGIObject, guid: *GUID,  name: string) {
    #if DEBUG {
        IDXGIObject_SetPrivateData(resource, guid, xx name.count, name.data);
    }
}