g_window : Window_Type;
g_camera : Camera;
g_should_quit := false;

g_font : *Simp.Dynamic_Font;
g_map_block: Simp.Texture; // @Temp Block.png

ASPECT  :: (16. / 9.);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

main :: () {
    g_window = create_window(width=g_window_width, height=g_window_height, window_name="Untitled", background_color_rgb=.[.0, .0, .0]);
    Simp.set_render_target(g_window);

    glEnable(GL_DEPTH_TEST);  
    glFrontFace(GL_CCW);

    if !renderer\_init() exit(1);
    if !resources_init() exit(1);

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

        g_light_source.x = sin(cast(float32) seconds_since_init()) * 3.0;
        g_light_source.x = cos(cast(float32) seconds_since_init()) * 3.0;

        immediate_light(make_translation_matrix4(g_light_source));
        immediate_cube();
        // immediate_quad();

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