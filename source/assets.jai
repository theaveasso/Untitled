CubeMap :: struct {
    gl_handle : GLuint;
}

font_init :: () -> bool {
    pixel_height := g_window_height / 24;
    g_font = Simp.get_font_at_size("resources/fonts", "DungeonFont.ttf", pixel_height);
    assert(g_font != null);
    return g_font != null;
}

texture_init :: () -> bool {
    success : bool;
    success = Simp.texture_load_from_file(map=*g_map_block, filename="resources/assets/Block.png", build_mipmaps=false);

    skybox_paths : [6]string = .[
        "resources/assets/skybox/SB_Stylished_01/px.png",
        "resources/assets/skybox/SB_Stylished_01/nx.png",
        "resources/assets/skybox/SB_Stylished_01/py.png",
        "resources/assets/skybox/SB_Stylished_01/ny.png",
        "resources/assets/skybox/SB_Stylished_01/pz.png",
        "resources/assets/skybox/SB_Stylished_01/nz.png",
    ];
    success = cubemap_load_from_file(skybox=*g_skybox, filenames=skybox_paths);

    return success;
}

texture_fini :: () {
    Simp.texture_destroy(*g_map_block);
}

cubemap_load_from_file :: (using skybox : *Skybox, filenames : [6]string) -> bool {
    glGenTextures(1, *cubemap_handle);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemap_handle);

    w, h, ch : s32;
    for i : 0..filenames.count - 1 {
        stbi_set_flip_vertically_on_load(0);
        bitmap: Simp.Bitmap;
        if !Simp.bitmap_load(*bitmap, filenames[i]) {
            return false;
        }
        
        defer Simp.deinit(*bitmap);

        internal_format, gl_format, gl_type, compressed := Simp.get_ogl_format(bitmap.format, (bitmap.flags & .IS_SRGB) != 0);
        bpp := Simp.get_image_bytes_per_texel(bitmap.format);
        stride_in_pixels := ifx bpp then bitmap.stride/bpp else bitmap.width;

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glPixelStorei(GL_UNPACK_ROW_LENGTH, xx stride_in_pixels);

        glTexImage2D(xx (GL_TEXTURE_CUBE_MAP_POSITIVE_X + i), 0, xx internal_format, xx bitmap.width, xx bitmap.height, 0, gl_format, gl_type, bitmap.data.data);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
    }

    return true;
}