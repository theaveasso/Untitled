#import "dxgi";
#import "d3d11"()(INCLUDE_DEBUG_BINDINGS = true);
#import "d3d_compiler";

IMGUI :: #import, dir "../vendor/imgui";
#load "../vendor/imgui/backends/imgui_impl_dx11.jai";

#import "Basic";
#import "Compiler";
#import "String";
#import "Windows_Utf8";
#import "Hash_Table";
#import "Math";
#import "Windows";
#import "Window_Creation";

#load "Input/module.jai";

ImDrawData      :: IMGUI.ImDrawData;
ImTextureData   :: IMGUI.ImTextureData;

#load "geometry.jai";
#load "engine.jai";
#load "renderer.jai";
#load "shader.jai";


ASSERT_ON_FAIL  :: true;
BREAK_ON_ERROR  :: false; 

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
        action := ifx call_string else "Something";
        printed_result := tprint("% failed: % %", action, hr, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        log_error(printed_result);
        return hr;
    }

    return S_OK;
}

D3D11SetDebugObjectName :: inline (device : *ID3D11Device, resource: *ID3D11DeviceChild, name: string) {
    #if DEBUG {
        HR(ID3D11Device_SetPrivateData(device, *uid(WKPDID_D3DDebugObjectName), xx name.count, name.data));
    }
}

D3D11SetDebugObjectName :: inline (device : *ID3D11Device, resource: *IDXGIObject, name: string) {
    #if DEBUG {
        HR(ID3D11Device_SetPrivateData(device, *uid(WKPDID_D3DDebugObjectName), xx name.count, name.data));
    }
}

#scope_file;
// using,except(END) Key_Code; // Key_Current_State.END would conflict with this. Sigh.

key_down_table: Table(WPARAM, bool);