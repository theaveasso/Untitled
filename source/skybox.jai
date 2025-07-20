Skybox_Constants :: struct {
    world: Matrix4;
}

Skybox :: struct {
    constants: Skybox_Constants;
    constants_buffer: Buffer;
}