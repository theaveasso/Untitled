D3D12Descriptor_Heap :: struct {
    desc:   D3D12_DESCRIPTOR_HEAP_DESC;
    heap:   *ID3D12DescriptorHeap;
    size:   u32;

    union {
        CBV_SRV_UAV_INDEX :: struct {
            cbv: u32;
            srv: u32;
            uav: u32;
        }
        cbv_srv_uav_end_index: CBV_SRV_UAV_INDEX;
        cpu_end_index: u32;
    }

    union {
        D3D12_CBV_SRV_UAV_CPU_DESCRIPTOR_HANDLE :: struct {
            cbv: D3D12_CPU_DESCRIPTOR_HANDLE;
            srv: D3D12_CPU_DESCRIPTOR_HANDLE;
            uav: D3D12_CPU_DESCRIPTOR_HANDLE;
        }
        cbv_srv_uav_end_handle: D3D12_CBV_SRV_UAV_CPU_DESCRIPTOR_HANDLE;
        cpu_end_handle: D3D12_CPU_DESCRIPTOR_HANDLE;
    }
}

d3d12_descriptor_heap_init :: (using _device: *D3D12Device, using _heap: *D3D12Descriptor_Heap, type: D3D12_DESCRIPTOR_HEAP_TYPE = .CBV_SRV_UAV) -> success: bool {

    desc.Type = type;
    desc.NumDescriptors  = HeapSizes[type];
    desc.Flags           = .SHADER_VISIBLE;
    if type == .RTV || type == .DSV desc.Flags = .NONE;

    ok := HR(ID3D12Device_CreateDescriptorHeap(device, *desc, *uid(ID3D12DescriptorHeap_UUID), xx *heap));
    if !ok return false;

    cpu_end_index  = 0;
    cpu_end_handle = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap);
    size           = ID3D12Device_GetDescriptorHandleIncrementSize(device, desc.Type);

    if type == .CBV_SRV_UAV {
        cbv_srv_uav_end_handle.cbv = cpu_end_handle;
        d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.cbv, HeapOffset[Heap_View_Type.CBV], size);
        cbv_srv_uav_end_index.cbv = HeapOffset[Heap_View_Type.CBV];

        cbv_srv_uav_end_handle.srv = cpu_end_handle;
        d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.srv, HeapOffset[Heap_View_Type.SRV], size);
        cbv_srv_uav_end_index.srv = HeapOffset[Heap_View_Type.SRV];

        cbv_srv_uav_end_handle.uav = cpu_end_handle;
        d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.uav, HeapOffset[Heap_View_Type.UAV], size);
        cbv_srv_uav_end_index.uav = HeapOffset[Heap_View_Type.UAV];
    }

    return ok;
}

d3d12_descriptor_heap_release :: (using _heap: *D3D12Descriptor_Heap) {

    safe_release_and_reset(*heap);
}

d3d12_descriptor_heap_resource_add :: (using _device: *D3D12Device, using _heap: *D3D12Descriptor_Heap, type: Heap_View_Type, resource: *ID3D12Resource, resource_desc: *void, counter_resource: *ID3D12Resource = null) -> Handles {

    handle: Handles;

    if type == {
        case .CBV;
            #if DEBUG if desc.Type != .CBV_SRV_UAV log("CBV can only register in CBV_SRV_UAV Heap!");
            view := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);
            ID3D12Device_CreateConstantBufferView(device, cast(*D3D12_CONSTANT_BUFFER_VIEW_DESC) resource_desc, cbv_srv_uav_end_handle.cbv);
            d3d12_gpu_descriptor_handle_offset(*view, cbv_srv_uav_end_index.cbv, size);
            handle.cpu = cbv_srv_uav_end_handle.cbv;
            handle.gpu = view;
            d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.cbv, 1, size);
            cbv_srv_uav_end_index.cbv += 1;

        case .SRV;
            #if DEBUG if desc.Type != .CBV_SRV_UAV log("SRV can only register in CBV_SRV_UAV Heap!");
            view := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);
            ID3D12Device_CreateShaderResourceView(device, resource, cast(*D3D12_SHADER_RESOURCE_VIEW_DESC) resource_desc, cbv_srv_uav_end_handle.srv);
            d3d12_gpu_descriptor_handle_offset(*view, cbv_srv_uav_end_index.srv, size);
            handle.cpu = cbv_srv_uav_end_handle.srv;
            handle.gpu = view;
            d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.srv, 1, size);
            cbv_srv_uav_end_index.srv += 1;

        case .UAV;
            #if DEBUG if desc.Type != .CBV_SRV_UAV log("UAV can only register in CBV_SRV_UAV Heap!");
            view := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);
            ID3D12Device_CreateUnorderedAccessView(device, resource, counter_resource, cast(*D3D12_UNORDERED_ACCESS_VIEW_DESC) resource_desc, cbv_srv_uav_end_handle.uav);
            d3d12_gpu_descriptor_handle_offset(*view, cbv_srv_uav_end_index.uav, size);
            handle.cpu = cbv_srv_uav_end_handle.uav;
            handle.gpu = view;
            d3d12_cpu_descriptor_handle_offset(*cbv_srv_uav_end_handle.uav, 1, size);
            cbv_srv_uav_end_index.uav += 1;

        case .RTV;
            #if DEBUG if desc.Type != .RTV log("RTV can only register in RTV Heap!");
            ID3D12Device_CreateRenderTargetView(device, resource, cast(*D3D12_RENDER_TARGET_VIEW_DESC) resource_desc, cpu_end_handle);
            handle.cpu = cpu_end_handle;
            d3d12_cpu_descriptor_handle_offset(*cpu_end_handle, 1, size);
            cpu_end_index += 1;

        case .DSV;
            #if DEBUG if desc.Type != .DSV log("DSV can only register in DSV Heap!");
            ID3D12Device_CreateDepthStencilView(device, resource, cast(*D3D12_DEPTH_STENCIL_VIEW_DESC) resource_desc, cpu_end_handle);
            handle.cpu = cpu_end_handle;

            d3d12_cpu_descriptor_handle_offset(*cpu_end_handle, 1, size);
            cpu_end_index += 1;
        case;
    }

    return handle;
}

d3d12_descriptor_heap_sampler_add  :: (using _device: *D3D12Device, using _heap: *D3D12Descriptor_Heap, sampler_desc: *D3D12_SAMPLER_DESC) -> Handles {

    #if DEBUG {
        if desc.Type != .SAMPLER log("Sampler can only register in SAMPLER Heap!");
    }

    handle: Handles;
    sampler:= ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);

    ID3D12Device_CreateSampler(device, sampler_desc, cpu_end_handle);
    d3d12_gpu_descriptor_handle_offset(*sampler, cpu_end_index, size);
    d3d12_cpu_descriptor_handle_offset(*cpu_end_handle, 1, size);

    handle.gpu = sampler;
    handle.cpu = cpu_end_handle;

    cpu_end_index += 1;

    return handle;
}

d3d12_descriptor_heap_handle_get :: (using _heap: *D3D12Descriptor_Heap, type: Heap_View_Type, index: u32) -> Handles {

    handle: Handles;
    gpuview := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(heap);
    cpuview := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap);
    d3d12_gpu_descriptor_handle_offset(*gpuview, HeapOffset[type]+index, size);
    d3d12_cpu_descriptor_handle_offset(*cpuview, HeapOffset[type]+index, size);

    handle.gpu = gpuview;
    handle.cpu = cpuview;
    return handle;
}