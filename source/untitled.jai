g_window : Window_Type;
g_should_quit := false;

ASPECT  :: (16. / 9.);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

main :: () {
    g_window = create_window(width=g_window_width, height=g_window_height, window_name="Untitled", background_color_rgb=.[.0, .0, .0]);

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

    }
}

#load "module.jai";