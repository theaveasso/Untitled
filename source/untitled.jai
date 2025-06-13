g_window   : Window_Type;
g_camera   : Camera;

ASPECT :: (1920.0 / 1080.0);
VPIXELS :: 1080;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_should_quit := false;
WANTED_MSAA :: 8;

main :: () {
    g_window = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA);
    ok_or_exit(g_window != null, "Could not create window");

    msaa := NSimp.prepare_window(g_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    success : bool;
    success = glrenderer_init(g_window);
    ok_or_exit(success, "Could not initialize OpenGL context"); 

    g_camera.position = xyz(-60, 120, -40);
    g_camera.euler_angles.x = 125 * PI / 180.0;
    g_camera.euler_angles.y = -50 * PI / 180.0;

    noise: FNL_State;
    terrain := terrain_init(4, 128, 0, 70, *noise);

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

        flying_camera_update(*g_camera, 0.1667);

        glViewport(0, 0, xx g_window_width, xx g_window_height);
        glClearColor(.0, .0, .0, 1.);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        terrain_draw(*terrain);
        NSimp.swap_buffers(g_window);
    }
}

#import, dir "../vendor/FastNoiseLite";
NSimp :: #import, dir "../vendor/NotSimp";

#import "Basic";
#import "String";
#import "GL";
#import "Math";
#import "Window_Creation";
#import "stb_image";
#import "Bucket_Array";

#load "gl.jai";
#load "terrain.jai";
#load "camera.jai";
#load "quadtree.jai";
#load "math.jai";

Input :: #import "Input";

SHADER :: #import, dir "shader";

is_key_down :: inline (key_code : Input.Key_Code) -> bool { return (Input.input_button_states[cast (s64) key_code] & .DOWN) != 0; }

ok_or_exit :: inline (success: bool, err_msg_format: string, args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {
    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

DEBUG :: true;