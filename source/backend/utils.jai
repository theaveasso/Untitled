HR :: inline (hr: HRESULT, $call := #caller_code, loc :=  #caller_location) -> HRESULT {
    
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
        action := ifx call_string else "";
        printed_result := tprint("% % % failed!", action, hr, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        log_error(printed_result);
        return hr;
    }

    return S_OK;
}

print_debug_msgs :: (d3d12_info_queue:*ID3D12InfoQueue) {
    if !d3d12_info_queue return;
    msgs_count := ID3D12InfoQueue_GetNumStoredMessages(d3d12_info_queue);
    // print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        result := ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, null, *size);

        // WARNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg: *D3D12_MESSAGE = xx alloc(xx size);
        defer free(msg);
        result = ID3D12InfoQueue_GetMessageA(d3d12_info_queue, it, msg, *size);

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

compile_d3d_shader :: (source: string, entry_point: string, shader_model: string) -> string, bool {
    flags := D3DCOMPILE.ENABLE_STRICTNESS; 
    #if DEBUG {
        // Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
        // Setting this flag improves the shader debugging experience, but still allows  
        // the shaders to be optimized and to run exactly the way they will run in  
        // the release configuration of this program. 
        flags |= .DEBUG; 
        // Disable optimizations to further improve shader debugging 
        flags |= .SKIP_OPTIMIZATION; 
    }
    defines: [] string;
    bytecode, errors, hr := D3DCompile(source, "source", defines, null, entry_point, shader_model, xx flags, 0);
    defer free(errors);

    if FAILED(hr) { 
        free(bytecode);
        if errors log_error("compile_shader: Error msg: %", errors);
        return "", false;
    } 
    return bytecode, true;
}