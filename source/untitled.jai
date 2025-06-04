g_window : Window_Type;
g_camera : Camera;
g_should_quit := false;

g_font : *Simp.Dynamic_Font;
g_map_block : Simp.Texture; // @Temp Block.png

g_skybox : Skybox;
g_voxel  : Voxel;


ASPECT  :: (16. / 9.);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_seed : u64;
g_terrain : Terrain;

main :: () {
    g_seed = random_get();
    g_window = create_window(width=g_window_width, height=g_window_height, window_name="Untitled", background_color_rgb=.[.0, .0, .0]);
    Simp.set_render_target(g_window);

    glEnable(GL_DEPTH_TEST);  

    g_camera.position = xyz(1, 2.3, 4.3);
    g_camera.euler_angles.x = -20 * PI / 180.0;
    g_camera.euler_angles.y = 30 * PI / 180.0;

    filename := tprint("%/%", save_terrain_path, save_terrain_file);
    terrain_save_to_file(filename=filename, strategy=.Midpoint_Displacement, _size=256, roughness=3, _min_height=0, _max_height=10);
    terrain_load_from_file(*g_terrain, filename);

    if !renderer\_init() exit(1);
    if !resources_init() exit(1);

    gap := 2.0;

    while !g_should_quit {
        reset_temporary_storage();

        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == {
                case .QUIT; g_should_quit = true;
                case .KEYBOARD;
                    if it.key_code == {
                        case .ESCAPE; if it.key_pressed g_should_quit = true;
                    }
            }
        }

        flying_camera_update(0.00167);

        glClearColor(.0, .0, .0, 1.);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // terrain_triangle_list_draw(*g_terrain);
        immediate_cube(*g_voxel);
        immediate_skybox(*g_skybox);

        Simp.swap_buffers(g_window);
    }
}

resources_init :: () -> bool {
    return font_init() && texture_init();
}

is_key_down :: (key_code : Input.Key_Code) -> bool {
    return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0;
}

#load "module.jai";