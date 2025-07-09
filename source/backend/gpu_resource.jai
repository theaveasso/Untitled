GPU_Resource :: struct {
    resource_type: Resource_Type;
    states: [..]D3D12_RESOURCE_STATES;

    resource:       *ID3D12Resource;
    upload_buffer:  *ID3D12Resource;

    srv: Handles;
    cbv: Handles;
    uavs: [..]Handles;
    rtvs: [..]Handles;
    dsvs: [..]Handles;

    gpu_addr:       D3D12_GPU_VIRTUAL_ADDRESS;
    cpu_map_addr:   *void;
}
