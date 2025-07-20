#define MAX_ENTITIES
cbuffer Scene_CBuffer : register(b0) {
    float4x4 transform;
};

struct VS_Input {
    float3 position:   POSITION;
    float2 uv:         TEXCOORD;
    uint   instance_id: SV_InstanceID;
};

struct PS_Input {
    float4 position:    SV_POSITION;
    float2 uv:          TEXCOORD;
};

StructuredBuffer<matrix> world_matrices: register(t0);

Texture2D g_texture: register(t1);
SamplerState g_sampler: register(s0);

PS_Input VSMain(VS_Input vin) {

    PS_Input result;
    result.position = mul(float4(vin.position, 1.0f), world_matrices[vin.instance_id]);
    result.position = mul(result.position, transform);
    result.uv       = vin.uv;
    return result;
}

float4 PSMain(PS_Input pin) : SV_TARGET {
    return g_texture.Sample(g_sampler, pin.uv);
}