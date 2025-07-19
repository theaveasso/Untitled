Transform :: struct {
    position: Vector3;
    rotation: Quaternion;
    scale:    Vector3;

    world:    Matrix4;
}

make_transform :: (pos: Vector3, rot: Quaternion, scl: Vector3) -> Transform {
    return Transform.{pos, rot, scl, make_col_translation_matrix4(pos) * rotation_matrix_lh(Matrix4, rot) * make_scale_matrix4(scl)};
}

make_world_matrix :: (using transform: *Transform) -> Matrix4 {
    return make_col_translation_matrix4(position) * rotation_matrix_lh(Matrix4, rotation) * make_scale_matrix4(scale);
}