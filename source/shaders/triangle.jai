TRIANGLE_SHADER_TEXT :: #string HLSL 

struct PSInput
{
    float4 position : SV_POSITION;
    float4 color    : COLOR;
};

static float2 positions[3] = {
    float2( 0.0,  0.5),
    float2( 0.5, -0.5),
    float2(-0.5, -0.5)
};

static float3 colors[3] = {
    float3(1.0, 0.0, 0.0),
    float3(0.0, 1.0, 0.0),
    float3(0.0, 0.0, 1.0)
};


PSInput VS(uint vertex_id: SV_VERTEXID)
{
    PSInput result;
    result.position = float4(positions[vertex_id], 0.0, 1.0);
    result.color    = float4(colors[vertex_id], 1.0);

    return result;
}

float4 PS(PSInput input) : SV_TARGET
{
    return input.color;
}

HLSL