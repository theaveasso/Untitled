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

rotation_matrix_lh :: ($T: Type, q: Quaternion) -> T {

    ret: T;

    #if T == Matrix4 ret._44 = 1;

    xs := q.x * 2;
    ys := q.y * 2;
    zs := q.z * 2;

    wx := q.w * xs;
    wy := q.w * ys;
    wz := q.w * zs;

    _xx := q.x * xs;
    xy  := q.x * ys;
    xz  := q.x * zs;

    yy := q.y * ys;
    yz := q.y * zs;
    zz := q.z * zs;

    ret._11 = 1.0 - (yy + zz);
    ret._12 = xy + wz;
    ret._13 = xz - wy;

    ret._21 = xy - wz;
    ret._22 = 1.0 - (_xx + zz);
    ret._23 = yz + wx;

    ret._31 = xz + wy;
    ret._32 = yz - wx;
    ret._33 = 1.0 - (_xx + yy);

    return ret;

}