cbuffer Scene_CBuffer : register(b0) {
    float4x4 transform;
    float4   offset;
};

struct VS_Input {
    float3 position: POSITION;
    float4 color:    COLOR;
};

struct PS_Input {
    float4 position: SV_POSITION;
    float4 color:    COLOR;
};

PS_Input VSMain(VS_Input vin) {

    PS_Input result;
    result.position = float4(vin.position, 1.0f);
    result.color    = vin.color;
    return result;
}

float4 PSMain(PS_Input pin) : SV_TARGET {
    return pin.color;
}