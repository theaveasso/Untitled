g_window : Window_Type;
g_camera : Camera;
g_should_quit := false;

g_font : *Simp.Dynamic_Font;

ASPECT  :: (16. / 9.);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

main :: () {
    g_window = create_window(width=g_window_width, height=g_window_height, window_name="Untitled", background_color_rgb=.[.0, .0, .0]);
    Simp.set_render_target(g_window);

    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glLogicOp(GL_INVERT);

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
        Simp.clear_render_target(.0, .0, .0, 1.);

        immediate_mesh();

        Simp.swap_buffers(g_window);
    }
}

font_init :: () {
    pixel_height := g_window_height / 24;
    g_font = Simp.get_font_at_size("resources/fonts", "DungeonFont.ttf", pixel_height);
    assert(g_font != null);
}

resources_init :: () -> bool {
    font_init();

    return true;
}

is_key_down :: (key_code : Input.Key_Code) -> bool {
    return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0;
}

#load "module.jai";