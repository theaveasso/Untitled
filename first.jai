OUTPUT_EXECUTABLE_NAME := "untitled";

#run {
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace("Target Workspace");
    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;

    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("source/untitled.jai", w);
    compiler_end_intercept(w);

}

#import "Compiler";