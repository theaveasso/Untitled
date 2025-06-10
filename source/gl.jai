Shader_Program :: struct {
    gl_handle : GLuint;
}

create_shader_program :: (shader_text: string) -> GLuint {
    LOG_BUFFER_SIZE :: 512;

    make_shader_object :: (shader: string, prefix: string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        //shader_str := temp_c_string(shader);
        shaders: [2] *u8;
        lengths: [2] s32;

        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        lengths[0] = xx prefix.count;
        lengths[1] = xx shader.count;

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            log("%", to_string(log_data.data), flags=.ERROR);
            return 0;
        }

        return shader_object;
    }

    PREFIX_V :: #string END
    #version 460 core
    #define VERTEX_SHADER
    #define OUT_IN out
    END

    PREFIX_F :: #string END
    #version 460 core
    #define FRAGMENT_SHADER
    #define OUT_IN in
    END

    shader_v := make_shader_object(shader_text, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_text, PREFIX_F, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success then {
        log_data: [LOG_BUFFER_SIZE] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        log_error("%", to_string(log_data.data));
        return 0;
    }

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    return shader_p;
}

g_triangle_program : Shader_Program;
g_vao : GLuint;