#import "Math";

rotation_matrix :: ($T: Type, q: Quaternion, is_left_hand : bool) -> T {
    m: T;

    #if T == Matrix4  m._44 = 1;

    xs := q.x * 2;
    ys := q.y * 2;
    zs := q.z * 2;

    wx := q.w * xs;
    wy := q.w * ys;
    wz := q.w * zs;

    _xx := q.x * xs;
    xy := q.x * ys;
    xz := q.x * zs;

    yy := q.y * ys;
    yz := q.y * zs;
    zz := q.z * zs;

    m._11 = 1.0 - (yy + zz);
    m._12 = xy - wz;

    m._21 = xy + wz;
    m._22 = 1.0 - (_xx + zz);
    m._33 = 1.0 - (_xx + yy);

    if is_left_hand {
        m._13 = (xz + wy) * -1;

        m._23 = (yz - wx) * -1;

        m._31 = (xz - wy) * -1;
        m._32 = (yz + wx) * -1;
    } else {
        m._13 = xz + wy;

        m._23 = yz - wx;

        m._31 = xz - wy;
        m._32 = yz - wx;
    }

    return m;
}

make_projection_matrix :: (fov_vertical: float, aspect_ratio_horizontal_over_vertical: float, z_near: float, z_far: float, x_offset:=0.0, y_offset:=0.0, depth_range_01:=false, is_left_hand: bool) -> Matrix4 {
    result := Matrix4_Identity;

    tan_theta := tan(fov_vertical * 0.5);
    cot_theta := 1 / tan_theta;

    f := z_far;
    n := z_near;
    denom := 1 / (f - n);

    result._11 = cot_theta / aspect_ratio_horizontal_over_vertical;
    result._22 = cot_theta;
    result._33 = ifx is_left_hand f * denom else -(f + n) * denom;
    result._43 = ifx is_left_hand 1.0 else -1.0;
    result._34 = ifx is_left_hand n * -1 * f * denom else -2 * f * n * denom ;
    result._44 = 0;

    result._13 = x_offset; // / w;
    result._23 = y_offset; // / h;

    if depth_range_01 {
        result._33 = result._33 * 0.5 + result._43 * 0.5;
        result._34 = result._34 * 0.5 + result._44 * 0.5;
    }

    return result;
}
