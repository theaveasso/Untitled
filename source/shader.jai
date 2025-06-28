Shader :: struct {
    // platform specific
    vertex_shader : *ID3D11VertexShader;
    pixel\_shader : *ID3D11PixelShader;
    vertex_layout : *ID3D11InputLayout;

    sampler_state : *ID3D11SamplerState;
}

shader_init :: (gfx_device : *Graphics_Device, using shader : *Shader, source : string, layout : *[]D3D11_INPUT_ELEMENT_DESC, have_sampler : bool = false) -> bool {
    vs := compile_shader(source, "VS", "vs_5_0");
    defer free(vs);
    assert(vs.data != null);
    HR(ID3D11Device_CreateVertexShader(gfx_device.d3d_device, vs.data, cast(u64) vs.count, null, *vertex_shader));

    HR(ID3D11Device_CreateInputLayout(gfx_device.d3d_device, layout.data, cast(u32) layout.count, vs.data, cast(u64) vs.count, *vertex_layout));
    ID3D11DeviceContext_IASetInputLayout(gfx_device.d3d_context, vertex_layout);

    ps := compile_shader(source, "PS", "ps_5_0");
    defer free(vs);
    assert(ps.data != null);
    HR(ID3D11Device_CreatePixelShader(gfx_device.d3d_device, ps.data, cast(u64) ps.count, null, *pixel_shader));

    if have_sampler {
        sampler_desc : D3D11_SAMPLER_DESC;
        sampler_desc.AddressU = .WRAP; 
        sampler_desc.AddressV = .WRAP;
        sampler_desc.AddressW = .WRAP;
        sampler_desc.MipLODBias = 0.0;
        sampler_desc.MaxAnisotropy = 1;
        sampler_desc.ComparisonFunc = .ALWAYS;
        sampler_desc.BorderColor[0] = 0;
        sampler_desc.BorderColor[1] = 0;
        sampler_desc.BorderColor[2] = 0;
        sampler_desc.BorderColor[3] = 0;
        sampler_desc.MinLOD = 0;
        sampler_desc.MaxLOD = FLOAT32_MAX;

        HR(ID3D11Device_CreateSamplerState(gfx_device.d3d_device, *sampler_desc, *sampler_state));
    }

    return true;
}

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
struct Material {
    float4 Ambient;
    float4 Diffuse;
    float4 Specular;
    float4 Reflect;
};

struct Directional_Light {
    float4 Ambient;
    float4 Diffuse;
    float4 Specular;
    float3 Direction;
    float  pad;
};

struct Point_Light {
    float4 Ambient;
    float4 Diffuse;
    float4 Specular;

    float3 Position;
    float  Range;

    float3 Att;
    float  pad;
};

struct Spot_Light {
    float4 Ambient;
    float4 Diffuse;
    float4 Specular;

    float3 Position;
    float  Range;

    float3 Direction;
    float  Spot;

    float3 Att;
    float  pad;
};

cbuffer VS_Constant_Buffer : register(b0) {
    matrix g_Model;
    matrix g_View;
    matrix g_Proj;
};

cbuffer PS_Constant_Buffer : register(b1) {
    Directional_Light g_DirectionalLight;
    Point_Light       g_PointLight;
    Spot_Light        g_SpotLight;

    Material          g_Material;
    float3            g_EyePositionW;
    float             pad;
};

Texture2D    g_Texture0: register(t0);
SamplerState g_Sampler0: register(s0);

struct Vertex_In {
    float3 position     : POSITION;
    float4 color_scale  : COLOR; 
    float2 uv           : TEXCOORD; 
    float3 normal       : NORMAL;
    // float4 tangent      : TANGENT;
};

struct Vertex_Out {
    float4 posH     : SV_POSITION;
    float3 posW     : POSITION; // world position
    float3 normalW  : NORMAL;   // world normal
    float2 texcoord : TEXCOORD;
    float4 color    : COLOR;
};

void compute_directional_light(Material M, Directional_Light L,
    float3 normal, 
    float3 to_eye,
    out float4 ambient,
    out float4 diffuse,
    out float4 spec) {

    ambient = float4(0.0f,0.0f,0.0f,0.0f);
    diffuse = float4(0.0f,0.0f,0.0f,0.0f);
    spec    = float4(0.0f,0.0f,0.0f,0.0f);

    float3 light_vec = -L.Direction;

    ambient = M.Ambient * L.Ambient;
    float diffuse_factor = dot(light_vec, normal);
    [flatten]
    if (diffuse_factor > 0.0) {
        float3 v = reflect(-light_vec, normal);
        float  spec_factor = pow(max(dot(v, to_eye), 0.0), M.Specular.w);

        diffuse = diffuse_factor * M.Diffuse * L.Diffuse;
        spec    = spec_factor * M.Specular * L.Specular;
    }
}

void compute_point_light(Material M, Point_Light L,
    float3 pos,
    float3 normal,
    float3 to_eye,
    out float4 ambient,
    out float4 diffuse,
    out float4 spec) {

    ambient = float4(0.0f,0.0f,0.0f,0.0f);
    diffuse = float4(0.0f,0.0f,0.0f,0.0f);
    spec    = float4(0.0f,0.0f,0.0f,0.0f);

    float3 light_vec = L.Position - pos;
    float  d = length(light_vec);

    if (d > L.Range) return;
    light_vec /= d;

    ambient = M.Ambient * L.Ambient;

    float diffuse_factor = dot(light_vec, normal);
    [flatten]
    if (diffuse_factor > 0.0) {
        float3 v = reflect(-light_vec, normal);
        float  spec_factor = pow(max(dot(v, to_eye), 0.0), M.Specular.w);

        diffuse = diffuse_factor * M.Diffuse * L.Diffuse;
        spec    = spec_factor * M.Specular * L.Specular;
    }

    float att = 1.0f / dot(L.Att, float3(1.0, d, d * d));

    diffuse *= att;
    spec    *= att;
}

void compute_spot_light(Material M, Spot_Light L,
    float3 pos,
    float3 normal,
    float3 to_eye,
    out float4 ambient,
    out float4 diffuse,
    out float4 spec) {

    ambient = float4(0.0f,0.0f,0.0f,0.0f);
    diffuse = float4(0.0f,0.0f,0.0f,0.0f);
    spec    = float4(0.0f,0.0f,0.0f,0.0f);

    float3 light_vec = L.Position - pos;
    float  d = length(light_vec);

    if (d > L.Range) return;
    light_vec /= d;

    ambient = M.Ambient * L.Ambient;

    float diffuse_factor = dot(light_vec, normal);
    [flatten]
    if (diffuse_factor > 0.0) {
        float3 v = reflect(-light_vec, normal);
        float  spec_factor = pow(max(dot(v, to_eye), 0.0), M.Specular.w);

        diffuse = diffuse_factor * M.Diffuse * L.Diffuse;
        spec    = spec_factor * M.Specular * L.Specular;
    }

    float spot = pow(max(dot(-light_vec, L.Direction), 0.0), L.Spot);
    float att  = spot / dot(L.Att, float3(1.0, d, d * d));

    ambient *= spot;
    diffuse *= att;
    spec    *= att;
}

Vertex_Out VS(Vertex_In v_in) {
    Vertex_Out v_out;
    matrix view_proj = mul(g_Proj, g_View);
    float4 pos_w     = mul(g_Model, float4(v_in.position, 1.0f));

    v_out.posH = mul(view_proj, pos_w);
    // v_out.normalW = mul(v_in.Normal, float(3x3) g_WorldInvTranspose);
    v_out.normalW = v_in.normal;
    v_out.posW    = pos_w.xyz; 
    v_out.color   = v_in.color_scale;
    v_out.texcoord= v_in.uv;

    return v_out;
}

float4 PS(Vertex_Out p_in) : SV_Target {
    // p_in.normalW = normalize(p_in.normalW);

    // float3 to_eye_w = normalize(g_EyePositionW - p_in.posW);

    // float4 ambient, diffuse, spec;
    // float4 A, D, S;

    // ambient = diffuse = spec = float4(0.0f, 0.0f, 0.0f, 0.0f);
    // A = D = S = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // compute_directional_light(g_Material, g_DirectionalLight, p_in.normalW, to_eye_w, A, D, S);
    // ambient += A;
    // diffuse += D;
    // spec    += S;

    // compute_point_light(g_Material, g_PointLight, p_in.posW, p_in.normalW, to_eye_w, A, D, S);
    // ambient += A;
    // diffuse += D;
    // spec    += S;

    // compute_spot_light(g_Material, g_SpotLight, p_in.posW, p_in.normalW, to_eye_w, A, D, S);
    // ambient += A;
    // diffuse += D;
    // spec    += S;

    // float4 lit_color = p_in.color * (ambient + diffuse) + spec;
    // lit_color.a = g_Material.Diffuse.a * p_in.color.a;
    // return lit_color;
    // return p_in.color;

    float4 out_color;
    out_color = g_Texture0.Sample(g_Sampler0, p_in.texcoord);
    return out_color;
}

HLSL