#load "buffer.jai";
#load "command_list.jai";
#load "command_queue.jai";
#load "descriptor_heap.jai";
#load "shader.jai";
#load "texture.jai";

Descriptor_Handle :: struct {
    cpu: D3D12_CPU_DESCRIPTOR_HANDLE;
    gpu: D3D12_GPU_DESCRIPTOR_HANDLE;
}

GPU_Resource :: struct {
    resource:       *ID3D12Resource;
    upload_buffer:  *ID3D12Resource;

    srv:            Descriptor_Handle;
    cbv:            Descriptor_Handle;
    uavs:      [..] Descriptor_Handle;
    rtvs:      [..] Descriptor_Handle;
    dsvs:      [..] Descriptor_Handle; 

    gpu_addr: D3D12_GPU_VIRTUAL_ADDRESS;
    map_addr: *void;
}