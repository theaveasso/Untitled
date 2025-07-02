g_engine   : Engine;

ASPECT :: (1920.0 / 1080.0);
VPIXELS :: 720;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_should_quit := false;
WANTED_MSAA :: 8;

g_cputimer : CPU_Timer;

main :: () {
    log(". Untitled 3D Game Engine ... Powered by JAI <3 d3d11!\n\n");

    if !engine_init(*g_engine) {
        log_error("engine_init failed\n");
        exit(3);
    }

    vshader: Vertex_Shader;
    sbindable_create(*g_engine.gfx_device, *vshader, cast(*void)temp_c_string(SHADER_MESH));

    input_layout: Input_Layout;
    input_layout_desc : Input_Layout_Desc = .{
        layout= .[
            .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
            .{"NORMAL",    0, .R32G32B32_FLOAT,    0, 12, .VERTEX_DATA, 0}
        ],
        bytecode= vshader.bytecode
    };
    sbindable_create(*g_engine.gfx_device, *input_layout, cast(*void)*input_layout_desc);


    // desc := Input_Layout_Desc.{
    //     layout= .[
    //        .{"POSITION",  0, .R32G32B32_FLOAT,    0,  0, .VERTEX_DATA, 0},
    //        .{"COLOR",     0, .R32G32B32A32_FLOAT, 0, 12, .VERTEX_DATA, 0},
    //        .{"TEXCOORD",  0, .R32G32_FLOAT,       0, 28, .VERTEX_DATA, 0},
    //     ]
    // };
    // sbindable_create(*g_engine.gfx_device, *test3, cast(*void)*desc);

    // input_layout : Input_Layout(Matrix4); 
    // bindable_create(*g_engine.gfx_device, *input_layout, cast(*void) *desc);

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

#load "module.jai";

DEBUG :: true;