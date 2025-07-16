ASPECT :: (800.0 / 600.0);
VPIXELS :: 600;

window_width  : s32 = xx (ASPECT * VPIXELS);
window_height : s32 = xx VPIXELS;

g_should_quit := false;
WANTED_MSAA :: 8;

Window_Info :: struct {
    hwnd: HWND;
    window_width, window_height: s32;
    wanted_msaa: bool = false;
    msaa:        s32  = 0;
}

Untitled_State :: struct {
    current_window_info: Window_Info;
    d3d12:               D3D12_CONTEXT;
}

#add_context untitled : *Untitled_State;

main :: () {
    CheckInit();
    hwnd := create_window(window_width, window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb = .[0, 0, 0]);
    
    state.current_window_info = .{ hwnd=hwnd, window_width=window_width, window_height=window_height};

    ok_or_exit(backend_init(*state.current_window_info));
    load_assets();

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

        backend_update();
        backend_render();
    }

    backend_fini();
}

CheckInit :: () #expand {
    if !context.untitled per_thread_init();
    `state := context.untitled;
}

per_thread_init :: inline () {
    context.untitled = New(Untitled_State);
}

#import "Basic";
#import "String";
#import "Math";
#import "Window_Creation";
#import "Windows";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true);
#import "d3d_compiler";
#import "dxgi";
#import "Compiler";

Input :: #import "Input";

#load "d3d12.jai";
#load "utils.jai";

is_key_down :: inline (key_code : Input.Key_Code) -> bool { return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0; }

ok_or_exit :: inline (success: bool, err_msg_format: string = "", args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {
    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

DEBUG :: true;
BREAK_ON_ERROR :: false;
ASSERT_ON_FAIL :: true;