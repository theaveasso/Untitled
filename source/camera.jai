Camera :: struct {
    position: Vector3;
    rotation: Quaternion;

    viewpoint: Vector3;
    lookat: Vector3 = .{0, 0, 0};
    up:     Vector3 = .{0, 1, 0};

    view :      Matrix4 = Matrix4_Identity;
    projection: Matrix4 = Matrix4_Identity;
    viewproj:   Matrix4 = Matrix4_Identity;
}

camera_update :: () {

  CheckInit();
  using state.camera;

  x, y, width, height, success := get_dimensions(state.current_window_info.hwnd, true);
  aspect_ratio := cast(float) width / height;

  view = make_look_at_matrix_lh(viewpoint, lookat, up);
  projection = make_projection_matrix_lh(55 * PI / 180, aspect_ratio, 0.1, 1000);
  viewproj = view * projection;
}