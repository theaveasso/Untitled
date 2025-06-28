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