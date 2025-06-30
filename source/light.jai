CBuffer_Hemispheric :: struct {
    down:  Vector4;
    range: Vector4;
}

Forward_Lighting :: struct {
    constant_buffer: [1]*ID3D11Buffer;

    hemispheric_ambient: CBuffer_Hemispheric;
}

Directional_Light :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;
    direction:Vector3;
    pad     : float;
}

Point_Light :: struct {
    ambient : Vector4;
    diffuse : Vector4;
    specular: Vector4;

    position: Vector3;
    range   : float; 

    att     : Vector3;
    pad     : float;
}

Spot_Light :: struct {
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

make_directional_light :: (_diffuse: Vector4, _direction: Vector3) -> Directional_Light {
    directional_light: Directional_Light;
    directional_light.diffuse   = _diffuse;
    directional_light.direction = _direction;
    directional_light.specular  = .{1.0, 1.0, 1.0, 1.0};

    return directional_light;
}

forward_lighting_init :: (gfx_device: *Graphics_Device, 
                          using foward_lighting: *Forward_Lighting) {

    hemispheric_ambient.down  = xyzw(0.25, 0.22, 0.20, 1.0);
    hemispheric_ambient.range = xyzw(0.60, 0.70, 0.80, 1.0) - hemispheric_ambient.down;

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DYNAMIC;
    cbd.BindFlags = .CONSTANT_BUFFER;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size_of(CBuffer_Hemispheric);
    HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, *constant_buffer[0]));
}

foward_lighting_pass :: (gfx_device: *Graphics_Device,
                         using foward_lighting: *Forward_Lighting) {

    ID3D11DeviceContext_PSSetConstantBuffers(gfx_device.d3d_context, 2, 1, *constant_buffer[0]);
    gfx_map_buffer(gfx_device, constant_buffer[0], *hemispheric_ambient, size_of(CBuffer_Hemispheric));
}
