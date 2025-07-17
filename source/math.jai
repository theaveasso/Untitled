make_look_at_matrix_lh :: (viewpoint: Vector3, look_at: Vector3, reference_up_vector: Vector3) -> Matrix4 {

    zaxis := normalize(look_at - viewpoint);
    xaxis := normalize(cross(reference_up_vector, zaxis));
    yaxis := cross(zaxis, xaxis);

    ret: Matrix4;
    ret._11 = xaxis.x;
    ret._12 = yaxis.x;
    ret._13 = zaxis.x;
    ret._14 = 0;

    ret._21 = xaxis.y;
    ret._22 = yaxis.y;
    ret._23 = zaxis.y;
    ret._24 = 0;

    ret._31 = xaxis.z;
    ret._32 = yaxis.z;
    ret._33 = zaxis.z;
    ret._34 = 0;

    ret._41 = -dot(xaxis, viewpoint);
    ret._42 = -dot(yaxis, viewpoint);
    ret._43 = -dot(zaxis, viewpoint);
    ret._44 = 1;

    return ret;
}

make_projection_matrix_lh :: (fov_vertical: float, aspect_ratio_horizontal_over_vertical: float, z_near: float, z_far: float) -> Matrix4 {

    f := 1.0 / tan(fov_vertical * 0.5);
    range := z_far - z_near;

    ret: Matrix4 = Matrix4_Identity;
    ret._11 = f / aspect_ratio_horizontal_over_vertical;

    ret._22 = f;

    ret._33 = z_far / (z_far - z_near);
    ret._34 = 1;

    ret._43 = -z_near * z_far / (z_far - z_near);
    ret._44 = 0;

    return ret;
}