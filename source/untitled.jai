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
    camera:              Camera;
    control_camera:      bool;

    scene:               Scene;

    deltatime := 0.01667;
}

#add_context untitled : *Untitled_State;

MAX_ENTITIES :: 3;

main :: () {
    CheckInit();
    hwnd := create_window(window_width, window_height, "Untitled", wanted_msaa=WANTED_MSAA, background_color_rgb = .[0, 0, 0]);
    
    state.current_window_info = .{ hwnd=hwnd, window_width=window_width, window_height=window_height};

    state.camera.position = .{0, 0, 2};

    e1 := make_entity(position = .{0, 0, 0}, scale = xyz(0.5));
    e2 := make_entity(.{0,  3, 3}, scale = xyz(0.3));
    e3 := make_entity(.{0, -2, 0}, scale = xyz(0.6));
    array_add(*state.scene.entities, *e1);
    array_add(*state.scene.entities, *e2);
    array_add(*state.scene.entities, *e3);

    ok_or_exit(backend_init(*state.current_window_info));
    load_assets();

    while !g_should_quit {
        frame_start := current_time_monotonic();
        reset_temporary_storage();
        Input.update_window_events();

        for Input.events_this_frame {
            if it.type == {
                case .QUIT; g_should_quit = true;
                case .KEYBOARD;
                    if it.key_pressed {
                        if it.key_code == .CTRL set_camera_control(!state.control_camera);
                    }
                    if is_key_down(.ESCAPE) g_should_quit = true;
            }
        }

        backend_update();
        backend_render();
        frame_end := current_time_monotonic();
        state.deltatime = cast(float) to_float64_seconds(frame_end - frame_start);
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
#load "camera.jai";
#load "math.jai";
#load "entity.jai";
#load "mesh.jai";
#load "material.jai";
#load "scene.jai";
#load "transform.jai";
#load "d3d12/module.jai";

is_key_down :: inline (key_code : Input.Key_Code) -> bool { return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0; }

ok_or_exit :: inline (success: bool, err_msg_format: string = "", args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {
    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

set_camera_control :: inline (control: bool) {

    CheckInit();
    state.control_camera = control;
    if   state.control_camera hide_cursor();
    else show_cursor();
}

hide_cursor :: inline () {

    #if OS == .WINDOWS {
        win32 :: #import "Windows";
        win32.ShowCursor(0);
    } else {
        #assert("OS is not supported");
    }
}

show_cursor :: inline () {

    #if OS == .WINDOWS {
        win32 :: #import "Windows";
        win32.ShowCursor(1);
    } else {
        #assert("OS is not supported");
    }
}

set_mouse_pointer_position :: inline (x: int, y: int) {

    #if OS ==.WINDOWS {
        user32 :: #system_library "User32";
        SetCursorPos :: (x: s32, y: s32) -> s32 #foreign user32;
        SetCursorPos(xx x, xx y);
    } else {
        #assert("OS is not supported");
    }
}

DEBUG :: true;
BREAK_ON_ERROR :: false;
ASSERT_ON_FAIL :: true;