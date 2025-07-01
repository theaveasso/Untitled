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
                if it.key_pressed if it.key_code == .SPACEBAR set_camera_control(!g_control_camera);
                if it.key_pressed if it.key_code == xx #char "T"  g_engine.is_wireframe = !g_engine.is_wireframe;
            }
        }

        if !input_application_has_focus && g_control_camera
            set_camera_control(false);
        
        if g_control_camera {
            x, y, w, h := get_dimensions(g_engine.hwnd, false);
            set_mouse_pointer_position(w/2, h/2);
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