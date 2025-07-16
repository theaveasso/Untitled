Texture2D g_texture: register(t0);
SamplerState g_sampler: register(s0);

struct VS_Input {
    float4 position: POSITION;
    float2 uv:       TEXCOORD;
};

struct PS_Input {
    float4 position: SV_POSITION;
    float2 uv:       TEXCOORD;
};

PS_Input VSMain(VS_Input vin) {

    PS_Input result;
    result.position = vin.position;
    result.uv       = vin.uv;
    return result;
}

float4 PSMain(PS_Input pin) : SV_TARGET {
    return g_texture.Sample(g_sampler, pin.uv);
}