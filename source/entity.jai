Entity :: struct {
    mesh:      *Mesh;
    material:  *Material;
    
    world:      Matrix4;
}

make_entity :: (mesh: *Mesh, material: *Material) -> Entity {

    ret: Entity;
    ret.mesh        = mesh;
    ret.material    = material;
    ret.world       = Matrix4_Identity;
    return ret;
}