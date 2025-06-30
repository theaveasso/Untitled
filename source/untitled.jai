g_engine   : Engine;

ASPECT :: (1920.0 / 1080.0);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_should_quit := false;
WANTED_MSAA :: 8;

main :: () {
    log(". Untitled 3D Game Engine ... Powered by JAI <3 d3d11!\n\n");

    ok_or_exit(engine_init(*g_engine), "Engine Initialize failed.");

    while !g_should_quit {
        reset_temporary_storage();
        update_window_events();
        for events_this_frame {
            if it.type == .QUIT then g_should_quit = true;
            if it.type == .KEYBOARD {
                if it.key_pressed if it.key_code == .ESCAPE g_should_quit = true;
            }
        }

        engine_update(*g_engine);
    }
}

// Input :: #import "Input";
#load "module.jai";

ok_or_exit  :: inline (success: bool, err_msg_format: string, args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {
    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

DEBUG :: true;