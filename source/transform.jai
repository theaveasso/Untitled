Transform :: struct {
    /// space information
    //  local space information
    position:       Vector3;
    scale:          Vector3;
    rotation:       Quaternion;

    //  global space infromation concatenate in matrix
    world:    Matrix4 = Matrix4_Identity;
}

make_transform :: (pos: Vector3, rot: Quaternion, scl: Vector3) -> Transform {
    return Transform.{pos, scl, rot, make_col_translation_matrix4(pos) * rotation_matrix_lh(Matrix4, rot) * make_scale_matrix4(scl)};
}

make_world_matrix :: (using transform: *Transform) -> Matrix4 {
    return make_col_translation_matrix4(position) * rotation_matrix_lh(Matrix4, rotation) * make_scale_matrix4(scale);
}