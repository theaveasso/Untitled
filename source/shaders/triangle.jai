TRIANGLE_SHADER_TEXT :: #string HLSL 

cbuffer CBuffer_Scene : register(b0) {
    float offset;
}

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
    result.position = float4(vin.position.x + offset, vin.position.y + offset, 0.0, 1.0);
    result.texcoord = vin.uv;

    return result;
}

Texture2D       g_texture: register(t1);
SamplerState    g_sampler: register(s0);

float4 PSMain(PSInput input) : SV_TARGET
{
    float inten     = offset / 2 + 0.5;
    float redinten  = inten;
    float greeninten= inten * 2;
    float4 color = float4(redinten, greeninten, 0.0f, 0.0f) * g_texture.Sample(g_sampler, input.texcoord);
    return color;
}

HLSL