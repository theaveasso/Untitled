D3D12Descriptor_Heap :: struct {
    desc:   D3D12_DESCRIPTOR_HEAP_DESC;
    heap:   *ID3D12DescriptorHeap;
    size:   u32;

    union {
        CBV_SRV_UAV_INDEX :: struct {
            cbv_end_index: u32;
            srv_end_index: u32;
            uav_end_index: u32;
        }
        cbv_srv_uav_end_index: CBV_SRV_UAV_INDEX;
        cpu_end_index: u32;
    }

    union {
        D3D12_CBV_SRV_UAV_CPU_DESCRIPTOR_HANDLE :: struct {
            cbv_end_handle: D3D12_CPU_DESCRIPTOR_HANDLE;
            srv_end_handle: D3D12_CPU_DESCRIPTOR_HANDLE;
            uav_end_handle: D3D12_CPU_DESCRIPTOR_HANDLE;
        }
        cbv_srv_uav_end_handle: D3D12_CBV_SRV_UAV_CPU_DESCRIPTOR_HANDLE;
        cpu_end_handle: D3D12_CPU_DESCRIPTOR_HANDLE;
    }
}

d3d12_descriptor_heap_init :: (d3ddevice: *ID3D12Device, using _heap: *D3D12Descriptor_Heap, type: D3D12_DESCRIPTOR_HEAP_TYPE = .CBV_SRV_UAV) -> success: bool {

    desc.Type = type;
    desc.NumDescriptors  = HeapSizes[type];
    desc.Flags           = .SHADER_VISIBLE;
    if type == .RTV || type == .DSV desc.Flags = .NONE;

    success := HR(ID3D12Device_CreateDescriptorHeap(d3ddevice, *desc, *uid(ID3D12DescriptorHeap_UUID), xx *heap));
    if !success {
        return false;
    }

    cpu_end_index  = 0;
    cpu_end_handle = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap);
    size           = ID3D12Device_GetDescriptorHandleIncrementSize(d3ddevice, desc.Type);

    if type == .CBV_SRV_UAV {
        cbv_srv_uav_end_handle.cbv_end_handle = cpu_end_handle;
        d3d12_cpu_desciptor_handle_offset(*cbv_srv_uav_end_handle.cbv_end_handle, HeapOffset[Heap_View_Type.CBV], size);
        cbv_srv_uav_end_index.cbv_end_index = HeapOffset[Heap_View_Type.CBV];

        cbv_srv_uav_end_handle.srv_end_handle = cpu_end_handle;
        d3d12_cpu_desciptor_handle_offset(*cbv_srv_uav_end_handle.srv_end_handle, HeapOffset[Heap_View_Type.SRV], size);
        cbv_srv_uav_end_index.srv_end_index = HeapOffset[Heap_View_Type.SRV];

        cbv_srv_uav_end_handle.uav_end_handle = cpu_end_handle;
        d3d12_cpu_desciptor_handle_offset(*cbv_srv_uav_end_handle.uav_end_handle, HeapOffset[Heap_View_Type.UAV], size);
        cbv_srv_uav_end_index.uav_end_index = HeapOffset[Heap_View_Type.UAV];
    }

    return true;
}

d3d12_descriptor_heap_fini :: (using _heap: *D3D12Descriptor_Heap) {

    safe_release_and_reset(*heap);
}

d3d12_descriptor_heap_resource_add :: (device: *ID3D12Device, using _heap: *D3D12Descriptor_Heap, type: Heap_View_Type, resource: *ID3D12Resource, resource_desc: *void, count_resource: *ID3D12Resource = null) -> Handles {

    handle: Handles;

    if type == {
        case .CBV;
        case .SRV;
        case .UAV;
        case .RTV;
            #if DEBUG if desc.Type != .RTV log("RTV can only register in RTV Heap!");
            ID3D12Device_CreateRenderTargetView(device, resource, cast(*D3D12_RENDER_TARGET_VIEW_DESC) resource_desc, cpu_end_handle);
            handle.cpu = cpu_end_handle;

            d3d12_cpu_desciptor_handle_offset(*cpu_end_handle, 1, size);
            cpu_end_index += 1;
        case .DSV;
            #if DEBUG if desc.Type != .RTV log("DSV can only register in DSV Heap!");
        case;
    }

    return handle;
}

d3d12_descriptor_heap_sampler_add  :: (device: *ID3D12Device, using _heap: *D3D12Descriptor_Heap, sampler_desc: *D3D12_SAMPLER_DESC) -> Handles {

    #if DEBUG {
        if desc.Type != .SAMPLER log("Sampler can only register in SAMPLER Heap!");
    }

    handle: Handles;
    sampler:= ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);

    ID3D12Device_CreateSampler(device, sampler_desc, cpu_end_handle);
    d3d12_gpu_desciptor_handle_offset(*sampler, cpu_end_index, size);
    d3d12_cpu_desciptor_handle_offset(*cpu_end_handle, 1, size);

    handle.gpu = sampler;
    handle.cpu = cpu_end_handle;

    cpu_end_index += 1;

    return handle;
}

d3d12_descriptor_heap_handle_get :: (using _heap: *D3D12Descriptor_Heap, type: Heap_View_Type, index: u32) -> Handles {

    handle: Handles;
    gpuview := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);
    cpuview := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap);
    d3d12_gpu_desciptor_handle_offset(*gpuview, HeapOffset[type]+index, size);
    d3d12_cpu_desciptor_handle_offset(*cpuview, HeapOffset[type]+index, size);

    handle.gpu = gpuview;
    handle.cpu = cpuview;
    return handle;
}