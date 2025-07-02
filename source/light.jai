CBuffer_Hemispheric :: struct {
    down:  Vector4;
    range: Vector4;
}

Forward_Lighting :: struct {
    CBUFFER_HEMISPHERIC :: 0;
    CBUFFER_DIRECTIONAL :: 1;
    CBUFFER_POINT       :: 2;
    CBUFFER_SPOT        :: 3;

    constant_buffer: [4]*ID3D11Buffer;

    hemispheric_ambient:CBuffer_Hemispheric;
    directional_light:  CBuffer_DirectionalLight;
    point_light:        CBuffer_DirectionalLight;
    spot_light:         CBuffer_DirectionalLight;
}

CBuffer_DirectionalLight :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;
    direction:Vector3;
    pad     : float;
}

CBuffer_PointLight :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;

    position: Vector3;
    range   : float; 

    att     : Vector3;
    pad     : float;
}

CBuffer_SpotLight :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;

    position: Vector3;
    range   : float; 

    direction: Vector3;
    spot    : float;

    att     : Vector3;
    pad     : float;
}

forward_lighting_init :: (gfx_device: *Graphics_Device, 
                          using foward_lighting: *Forward_Lighting) -> bool {

    success: bool;

    hemispheric_ambient.down  = xyzw(0.25, 0.22, 0.20, 1.0);
    hemispheric_ambient.range = xyzw(0.60, 0.70, 0.80, 1.0) - hemispheric_ambient.down;

    directional_light.ambient  = xyzw(0.2, 0.2, 0.2, 1.0);   // soft ambient gray
    directional_light.diffuse  = xyzw(1.0, 0.95, 0.85, 1.0); // warm sunlight color
    directional_light.specular = xyzw(1.0, 1.0, 1.0, 1.0);   // white specular highlights
    directional_light.direction = normalize(xyz(-0.5, -1.0, -0.3)); // light shining diagonally down

    success = cbuffer_create2(gfx_device, *constant_buffer[CBUFFER_HEMISPHERIC], .CONSTANT_BUFFER, size_of(CBuffer_Hemispheric), *hemispheric_ambient);
    success = cbuffer_create2(gfx_device, *constant_buffer[CBUFFER_DIRECTIONAL], .CONSTANT_BUFFER, size_of(CBuffer_DirectionalLight));
    success = cbuffer_create2(gfx_device, *constant_buffer[CBUFFER_POINT      ], .CONSTANT_BUFFER, size_of(CBuffer_PointLight));
    success = cbuffer_create2(gfx_device, *constant_buffer[CBUFFER_SPOT       ], .CONSTANT_BUFFER, size_of(CBuffer_SpotLight));

    return success;
}

foward_lighting_pass :: (gfx_device: *Graphics_Device,
                         using foward_lighting: *Forward_Lighting) {

    ID3D11DeviceContext_PSSetConstantBuffers(gfx_device.d3d_context, 3, 1, *constant_buffer[CBUFFER_HEMISPHERIC]);

    ID3D11DeviceContext_PSSetConstantBuffers(gfx_device.d3d_context, 4, 1, *constant_buffer[CBUFFER_DIRECTIONAL]);
    cbuffer_map(gfx_device, constant_buffer[CBUFFER_DIRECTIONAL], *directional_light, size_of(CBuffer_DirectionalLight));
}
