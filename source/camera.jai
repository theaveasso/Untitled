Camera :: struct {
    FLY\    _SPEED :: 1.0;
    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;

    position:     Vector3;
    euler_angles: Vector3;
    rotation:     Quaternion;
    rotation_input: Vector2;

    viewpoint: Vector3;
    lookat: Vector3 = .{0, 0, 0};
    up:     Vector3 = .{0, 1, 0};

    transform:  Matrix4 = Matrix4_Identity;
    view:       Matrix4 = Matrix4_Identity;
    projection: Matrix4 = Matrix4_Identity;
    viewproj:   Matrix4 = Matrix4_Identity;

    dirty := true;
}

camera_update :: () {

  CheckInit();
  using state.camera;

  mouse_delta : Vector2;
  move_input :  Vector3;
  move_speed :  float;

  x, y, width, height, success := get_dimensions(state.current_window_info.hwnd, true);
  aspect_ratio := cast(float) width / height;

  if state.control_camera {
    mouse_delta = xy(xx Input.mouse_delta_x, xx Input.mouse_delta_y);
    rotation_input = lerp(rotation_input, mouse_delta, ROTATION_SMOOTHING);
    delta := rotation_input * ROTATION_SPEED;

    euler_angles.x += delta.x * PI / 180.0;
    euler_angles.y += delta.y * PI / 180.0;
    euler_angles.y = clamp(euler_angles.y, -80 * PI / 180.0, 80 * PI / 180.0);

    yaw, pitch: Quaternion;
    set_from_axis_and_angle(*yaw,   .{0, 1, 0}, euler_angles.x);
    set_from_axis_and_angle(*pitch, .{1, 0, 0}, euler_angles.y);
    rotation = yaw * pitch;

    move_speed = FLY_SPEED;
    if is_key_down(.SHIFT) then move_speed *= 5;
    move_speed *= state.deltatime;
    move_input.x = cast(float) is_key_down(xx #char "A") - cast(float) is_key_down(xx #char "D");
    move_input.y = cast(float) is_key_down(xx #char "E") - cast(float) is_key_down(xx #char "Q");
    move_input.z = cast(float) is_key_down(xx #char "S") - cast(float) is_key_down(xx #char "W");

    if length_squared(move_input) > 0.00001 {
      // move_input = rotate(unit_vector(move_input), rotation); // TODO 
      position += move_input * move_speed;
    }

    dirty = true;
  }

  if dirty {
    view = rotation_matrix_lh(Matrix4, conjugate(rotation)) * make_col_translation_matrix4(position);
    projection = make_projection_matrix_lh(55 * PI / 180, aspect_ratio, 0.1, 1000);
    viewproj = view * projection;

    dirty = false;
  }
}