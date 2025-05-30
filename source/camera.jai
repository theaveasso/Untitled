Camera :: struct {
    FLY_SPEED           :: 1.0;
    ROTATION_SPEED      :: 0.3;
    ROTATION_SMOOTHING  :: 0.3;

    fov := 60.0;

    rotation_input  : Vector2;
    position        : Vector3;
    euler_angles    : Vector3;
    rotation        : Quaternion;

    transform       := Matrix4_Identity;
    view            := Matrix4_Identity;
    projection      := Matrix4_Identity;
    view_proj       := Matrix4_Identity;
}

flying_camera_update :: (dt: float) {
    using g_camera;

    mouse_delta : Vector2;
    move\_input : Vector3;
    move\_speed : float;

    move\_speed = FLY_SPEED;
    mouse_delta = xy(xx Input.mouse_delta_x, xx Input.mouse_delta_y);

    move\_input.x = cast(float) is_key_down(xx #char "D") - cast(float) is_key_down(xx #char "A");
    move\_input.y = cast(float) is_key_down(xx #char "E") - cast(float) is_key_down(xx #char "Q");
    move\_input.z = cast(float) is_key_down(xx #char "S") - cast(float) is_key_down(xx #char "W");
    move\_input   = rotate(unit_vector(move_input), rotation);

    position += move_input * move_speed;
    rotation_input = lerp(rotation_input, mouse_delta, ROTATION_SMOOTHING);

    delta := rotation_input * ROTATION_SPEED;
    euler_angles.x  += delta.x * PI / 180.0;
    euler_angles.y  += delta.y * PI / 180.0;
    euler_angles.y   = clamp(euler_angles.y, -80 * PI / 180.0, 80 * PI / 180.0);

    yaw   : Quaternion;
    pitch : Quaternion;
    set_from_axis_and_angle(*yaw, 0, -1, 0, euler_angles.x);
    set_from_axis_and_angle(*pitch, -1, 0, 0, euler_angles.y);
    rotation = yaw * pitch;

    transform = make_translation_matrix4(position) * rotation_matrix(Matrix4, rotation);
    success: , view = inverse(transform);
    if !success { print("Could not invert the transform\n"); }

    vx, vy, vw, vh := get_dimensions(g_window, false);
    aspect_ratio := vw / cast (float) vh;
    projection  = make_projection_matrix(fov * PI / 180.0, aspect_ratio, 0.1, 1000.0);
    view_proj    = projection * view;
}