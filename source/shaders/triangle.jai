TRIANGLE_SHADER_TEXT :: #string HLSL 

struct VSInput {
    float2 position : POSITION;
    float2 uv       : TEXCOORD;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD;
};

PSInput VSMain(VSInput vin)
{
    PSInput result;
    result.position = float4(vin.position, 0.0, 1.0);
    result.texcoord = vin.uv;

    return result;
}

Texture2D       g_texture: register(t0);
SamplerState    g_sampler: register(s0);

float4 PSMain(PSInput input) : SV_TARGET
{
    float4 color = g_texture.Sample(g_sampler, input.texcoord);
    return color;
}

HLSL