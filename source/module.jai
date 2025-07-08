MAX_SUBMIT_COMMANDLIST :: 30;

Clear_Value :: struct {
    union {
        color: [4]float;
        depthstencil: D3D12_DEPTH_STENCIL_VALUE;
    }
}

Shader_Type :: enum u8 {
    VS :: 0;
    PS :: 1;
    CS :: 2;
    GS :: 3;
    DS :: 4;
    HS :: 5;
}

Parameter_Type :: enum {
    UNDEFINED;
    ROOTCONSTANT;
    CBV;
    SRV;
    UAV;
    SAMPLER;
}

Pipeline_Type :: enum {
    GRAPHICS;
    COMPUTE;
}

Command_Type :: enum u8 {
    GRAPHICS :: 0;
    COMPUTE  :: 1;
    COPY     :: 2;
}

Resource_Type :: enum u8 {
    BUFFER;
    TEXTURE;
    VOLATILE_CONSTANT_BUFFER;
}

Heap_View_Type :: enum u8 {
    CBV;
    SRV;
    UAV;
    RTV;
    DSV;
}

Buffer_Type :: enum u8 {
    NONE;
    VERTEX;
    INDEX;
    CONSTANT;
    STRUCTURED;
    STRUCTURED_COUNTER;
}

HeapSizes  : [D3D12_DESCRIPTOR_HEAP_TYPE.NUM_TYPES]u32    : .[3000, 10, 10, 10]; 
HeapOffset : [#run enum_highest_value(Heap_View_Type)+1]u32 : .[0, 1000, 2000, 0, 0]; 

Default_Border_Color : [4]float : .[0.0, 0.0, 0.0, 0.0];

Target_Shader_Models : [6]*u8 = .["vs_5_1", "ps_5_1", "cs_5_1", "gs_5_1", "ds_5_1", "hs_5_1"];

MAX_SWAPCHAIN_BUFFER_COUNT :: 3;

#import "Compiler";
#import "Basic";
#import "Windows";
#import "Math";
#import "String";
#import "Hash_Table";

Window :: #import "Window_Creation";
Input  :: #import "Input";

#import "dxgi";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS = true);
#import "d3d_compiler";

#load "engine.jai";
#load "backend/module.jai";
#load "shaders/module.jai";