g_window   : Window_Type;

ASPECT :: (1920.0 / 1080.0);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_should_quit := false;
WANTED_MSAA :: 8;

main :: () {
    g_window = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA);
    ok_or_exit(g_window != null, "Could not create window");

    while !g_should_quit {
        reset_temporary_storage();
        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == {
                case .QUIT; g_should_quit = true;
                case .KEYBOARD;
                    if is_key_down(.ESCAPE) g_should_quit = true;
            }
        }
    }
}

#import "Basic";
#import "Math";

#import "Window_Creation";

Input :: #import "Input";

is_key_down :: inline (key_code : Input.Key_Code) -> bool { return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0; }

ok_or_exit  :: inline (success: bool, err_msg_format: string, args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {
    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

DEBUG :: true;