#run build();

build :: () {

    set_build_options_dc(.{do_output=false});

	options := get_build_options();

    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

DECLARATIONS_TO_OMIT :: string.[
];

ENUMS_TO_OMIT :: string.[
];

generate_bindings :: () -> bool {

    output_filename: string;
    opts: Generate_Bindings_Options;

    {
        using opts;

        #if OS == .WINDOWS {
            output_filename = "bindings/windows/windows.jai";
            array_add(*libpaths, "bindings/windows/x64");

            footer = FOOTER_WIN;
            generate_library_declarations = false;

        } /*else #if OS == .LINUX {
            strip_flags = 0;
            output_filename = "linux/linux.jai";
            array_add(*libpaths, "linux/bin");

            footer = FOOTER_LINUX;
            generate_library_declarations = false;

        } else #if OS == .MACOS {
            strip_flags = 0;
            output_filename = "macos/macos.jai";
        }*/ else {
            assert(false, "this OS is currently unsupported. You might be able to add support for it though!");
        }

        array_add(*libnames, "assimp");
        array_add(*include_paths, "include");
        array_add(*source_files, "include/assimp/aabb.h");
        array_add(*source_files, "include/assimp/anim.h");
        array_add(*source_files, "include/assimp/camera.h");
        array_add(*source_files, "include/assimp/light.h");
        array_add(*source_files, "include/assimp/material.h");
        array_add(*source_files, "include/assimp/mesh.h");
        array_add(*source_files, "include/assimp/metadata.h");
        array_add(*source_files, "include/assimp/texture.h");
        array_add(*source_files, "include/assimp/cimport.h");
        array_add(*source_files, "include/assimp/cexport.h");
        array_add(*source_files, "include/assimp/scene.h");
        array_add(*source_files, "include/assimp/postprocess.h");

        visitor = custom_visitor;
        generate_compile_time_struct_checks = false;
    }

    return generate_bindings(opts, output_filename);
}

custom_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {

    if parent_decl return .RECURSE;

    if array_find(DECLARATIONS_TO_OMIT, decl.name) {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    if decl.kind == .ENUM && array_find(ENUMS_TO_OMIT, decl.name) {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    return .RECURSE;
}

#scope_file

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Check";
#import "Bindings_Generator";
#import "File";

FOOTER_WIN :: #string END
zlib :: #library,no_dll,link_always "x64/zlibstatic";
assimp :: #library,no_dll "x64/assimp";
END

FOOTER_LINUX :: #string END
END
