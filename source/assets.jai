font_init :: () -> bool {
    pixel_height := g_window_height / 24;
    g_font = Simp.get_font_at_size("resources/fonts", "DungeonFont.ttf", pixel_height);
    assert(g_font != null);
    return g_font != null;
}

texture_init :: () -> bool {
    ok := Simp.texture_load_from_file(map=*g_map_block, filename="resources/assets/BrickWall_BaseColor.jpg", build_mipmaps=false);
    assert(ok);
    return ok;
}

texture_fini :: () {
    Simp.texture_destroy(*g_map_block);
}