compile_shader :: (source: string, entry_point: string, shader_model: string, loc := #caller_location) -> string {
    flags := D3DCOMPILE.ENABLE_STRICTNESS;
    #if DEBUG {
        flags |= .DEBUG;
        flags |= .SKIP_OPTIMIZATION;
    }

    defines : []string;
    bytecode, errors, hr := D3DCompile(source, "source", defines, null, entry_point, shader_model, xx flags, 0);
    defer free(errors);

    if FAILED(hr) {
        printed_result := tprint("D3DCompile failed: % %", errors, loc);
        #if ASSERT_ON_FAIL assert(false, printed_result);

        MessageBoxW(null, utf8_to_wide("D3DCompile failed"), utf8_to_wide("Untitle: Error"), MB_ICONERROR | MB_OK);
        return "";
    }

    return bytecode;
}

SHADER_TEXT :: #string HLSL
cbuffer Constant_Buffer : register(b0) {
    matrix g_Model;
    matrix g_View;
    matrix g_Proj;
};

struct Vertex_In {
    float3 pos      : POSITION;
    float4 color    : COLOR; 
};

struct Vertex_Out {
    float4 posH     : SV_POSITION;
    float4 color    : COLOR;
};

Vertex_Out VS(Vertex_In v_in) {
    Vertex_Out v_out;
    v_out.posH = mul(g_Proj, mul(g_View, mul(g_Model, float4(v_in.pos, 1.0f))));
    v_out.color = v_in.color;

    return v_out;
}

float4 PS(Vertex_Out p_in) : SV_Target {
    return p_in.color;
}

HLSL