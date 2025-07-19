Entity :: struct {
    local_transform: Transform;
}

make_entity :: (position: Vector3 = .{0, 0, 0}, rotation: Quaternion = .{0, 0, 0, 1}, scale: Vector3 = .{1, 1, 1}) -> Entity {

    ret: Entity;
    ret.local_transform = make_transform(position, rotation, scale);
    return ret;
}

