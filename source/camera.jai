Camera :: struct {
    FLY_SPEED          :: 0.1;
    ROTATION_SPEED     :: 0.1;
    ROTATION_SMOOTHING :: 0.1;

    fov    := 60.0;
    aspect : float; 

    position:       Vector3;

    euler_angles:   Vector3;
    rotation:       Quaternion;
    rotation_input: Vector2;


    transform:=         Matrix4_Identity;
    view_matrix:=       Matrix4_Identity;
    projection_matrix:= Matrix4_Identity;
    viewproj_matrix:=   Matrix4_Identity;
}

CBuffer_Camera :: struct {
    position: Vector3;
    pad:      float;
}

camera_update :: (using camera: *Camera, dt: float) {
    mouse_delta: Vector2;
    move_input:  Vector3;
    move_speed:  float;

    move_speed = FLY_SPEED;

    if g_control_camera {
        mouse_delta = xy (xx mouse_delta_x, xx mouse_delta_y);

        if is_key_down(.SHIFT) then move_speed *= 2;
        move_speed *= dt;
        move_input.x = cast(float) is_key_down(xx #char "D") - cast(float) is_key_down(xx #char "A");
        move_input.y = cast(float) is_key_down(xx #char "E") - cast(float) is_key_down(xx #char "Q");
        move_input.z = cast(float) is_key_down(xx #char "W") - cast(float) is_key_down(xx #char "S");
        move_input = rotate(unit_vector(move_input), rotation);
    }

    position += move_input * move_speed;

    rotation_input = lerp(rotation_input, mouse_delta, ROTATION_SMOOTHING);
    delta:= rotation_input * ROTATION_SPEED;
    euler_angles.x += delta.x * PI / 180;
    euler_angles.y += delta.y * PI / 180;
    euler_angles.y = clamp(euler_angles.y, -80 * PI / 180.0, 80 * PI / 180);

    yaw: Quaternion;
    set_from_axis_and_angle(*yaw, 0, -1, 0, euler_angles.x);
    pitch: Quaternion;
    set_from_axis_and_angle(*pitch, -1, 0, 0, euler_angles.y);
    rotation = yaw*pitch;

    transform = make_translation_matrix4(position) * rotation_matrix(Matrix4, rotation, is_left_hand=true);
    success:, view_matrix = inverse(transform);
    if !success log_error("Unable to invert the transform update_flying_camera!");

    projection_matrix = make_projection_matrix(fov * PI / 180.0, aspect, 0.1, 1000.0, is_left_hand=true);
    viewproj_matrix = projection_matrix * view_matrix;
}

set_camera_control :: inline (control: bool) {
    g_control_camera = control;
    if g_control_camera 
        hide_cursor();
    else 
        show_cursor();
}