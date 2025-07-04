DEBUG          :: true;
ASSERT_ON_FAIL :: #run ifx DEBUG then true else false;
BREAK_ON_ERROR :: #run ifx DEBUG then true else false;

FRAME_COUNT :: 2;

main :: () {
    engine: Engine;

    if !engine_init(*engine) {
        log_error("engine init failed!");
        exit(3);
    }

    defer engine_fini(*engine);

    while !engine.should_quit {
        Input.update_window_events();

        for Input.events_this_frame {
            if it.type == .QUIT then engine.should_quit = true;
            if it.type == .KEYBOARD {
                if it.key_code == {
                    case .ESCAPE; if it.key_pressed engine.should_quit = true;
                }
            }
        }

        engine_update(*engine);
    }

}

#import "Compiler";
#import "Basic";
#import "Windows";

Window :: #import "Window_Creation";
Input  :: #import "Input";

#import "dxgi";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS = true);
#import "d3d_compiler";

#load "engine.jai";
#load "graphics.jai";
#load "backend/module.jai";
#load "shaders/module.jai";