g_window   : *SDL_Window;
g_renderer : *SDL_Renderer;

ASPECT :: (1920.0 / 1080.0);
VPIXELS :: 1080;

g_window_width  : s32 = xx (ASPECT * VPIXELS);
g_window_height : s32 = xx VPIXELS;

g_should_quit := false;

main :: () {
    if !SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) { 
        log_error("Failed to call SDL_Init: %", to_string(SDL_GetError())); 
        return;
    }

    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    g_window = SDL_CreateWindow("Untitled", g_window_width, g_window_height, SDL_WINDOW_OPENGL);
    if g_window == null {
        log_error("Could not create SDL_Window: %", to_string(SDL_GetError()));
        return;
    }

    gl_context := SDL_GL_CreateContext(g_window);
    if gl_context == null {
        log_error("Could not create OpenGL Context: %", to_string(SDL_GetError())); 
        return;
    }

    SDL_GL_MakeCurrent(g_window, gl_context);

    gl_load(*gl, SDL_GL_GetProcAddress);

    g_triangle_program.gl_handle = create_shader_program(SHADER.TRIANGLE_SHADER);
    glGenVertexArrays(1, *g_vao);

    print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    while !g_should_quit {
        event: SDL_Event;
        while(SDL_PollEvent(*event)) {
            if event.type == {
                case xx SDL_EventType.QUIT;
                    g_should_quit = true;

                case xx SDL_EventType.KEY_DOWN;
                    if event.key.key == SDLK_ESCAPE
                        g_should_quit = true;
                case;
            }
        }

        glViewport(0, 0, xx g_window_width, xx g_window_height);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(g_triangle_program.gl_handle);
        glBindVertexArray(g_vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        SDL_GL_SwapWindow(g_window);
    }

    SDL_DestroyWindow(g_window);
    SDL_Quit();
}

#import, dir "../vendor/SDL3";
#import "Basic";
#import "String";
#import "GL";

#load "gl.jai";

SHADER :: #import, dir "shader";