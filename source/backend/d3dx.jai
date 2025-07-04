backend_init :: (using engine: *Engine) -> bool {

    result: HRESULT;
    dxgi_factory_flags: u32 = 0;

    if DEBUG {
        debug_interface: *ID3D12Debug1;
        if SUCCEEDED(HR(D3D12GetDebugInterface(*uid(ID3D12Debug1_UUID), xx *debug_interface))) {
            ID3D12Debug1_EnableDebugLayer(debug_interface);
            dxgi_factory_flags |= DXGI_CREATE_FACTORY_DEBUG;
        }
    }

    result = HR(CreateDXGIFactory2(dxgi_factory_flags, *uid(IDXGIFactory4_UUID), xx *d3d_factory));
    if FAILED(result) {
        backend_fini(engine);
        return false;
    }

    warp_adapter_found := false;
    result = HR(IDXGIFactory4_EnumWarpAdapter(d3d_factory, *uid(IDXGIAdapter1_UUID), xx *d3d_adapter));
    if SUCCEEDED(result) {
        result = D3D12CreateDevice(d3d_adapter, ._12_0, *uid(ID3D12Device_UUID), null);
        if result == 0x1 {
            warp_adapter_found = true;
        }
    } else {
        if d3d_adapter IUnknown_Release(d3d_adapter);
        d3d_adapter = null;
    }

    adapter_index: u32 = 0;
    while true && !warp_adapter_found {
        if SUCCEEDED(IDXGIFactory1_EnumAdapters1(d3d_factory, adapter_index, *d3d_adapter)) {
            desc: DXGI_ADAPTER_DESC1;
            IDXGIAdapter1_GetDesc1(d3d_adapter, *desc);

            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG.SOFTWARE) continue;

            result = D3D12CreateDevice(d3d_adapter, ._12_0, *uid(ID3D12Device_UUID), null);
            if 0x1 == result then break;
        }

        IUnknown_Release(d3d_adapter);
        d3d_adapter = null;
        adapter_index += 1;
    }

    if !d3d_adapter {
        #if ASSERT_ON_FAIL assert(false, "Obtaining IDXGIAdapter1 failed!");
        backend_fini(engine);
        return false;
    }

    return true;
}

backend_fini :: (using engine: *Engine) {
    if d3d_factory IUnknown_Release(d3d_factory);
    if d3d_adapter IUnknown_Release(d3d_adapter);
}


backend_device_init :: (using engine: *Engine) -> bool {
    result := HR(D3D12CreateDevice(d3d_adapter, ._12_0, *uid(ID3D12Device_UUID), xx *d3d_device));
    if FAILED(result) {
        backend_device_fini(engine);
        return false;
    }

    #if DEBUG {
        if SUCCEEDED(IUnknown_QueryInterface(d3d_device, *uid(ID3D12InfoQueue_UUID), xx *d3d_info_queue)) {
            #if BREAK_ON_ERROR {
                ID3D12InfoQueue_SetBreakOnSeverity(d3d_info_queue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(d3d_info_queue, .ERROR, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(d3d_info_queue, .WARNING, .TRUE);
            }

            size := ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3d_info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3d_info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(d3d_info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(d3d_info_queue);
            }

            ID3D12InfoQueue_ClearStoredMessages(d3d_info_queue);
            ID3D12InfoQueue_SetMuteDebugOutput(d3d_info_queue, .FALSE);
        } else {
            log_error("IUnknown_QueryInterface 'IDXGIDevice' failed!");
        }
    }

    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = .NONE;
    queue_desc.Type  = .DIRECT;
    result = HR(ID3D12Device_CreateCommandQueue(d3d_device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *d3d_queue));
    if FAILED(result) {
        log_error("ID3D12Device_CreateCommandQueue failed!");
        backend_device_fini(engine);
        return false;
    }

    result = HR(ID3D12Device_CreateFence(d3d_device, 0, .NONE, *uid(ID3D12Fence_UUID), xx *d3d_queue_w_fence));
    if FAILED(result) {
        log_error("ID3D12Device_CreateFence failed!");
        backend_device_fini(engine);
        return false;
    }

    d3d_queue_w_event = CreateEventW(null, 0, 0, null);
    if d3d_queue_w_event == null {
        #if ASSERT_ON_FAIL assert(false, "CreateEventW failed!");
        backend_device_fini(engine);
        return false;
    }

    return true;
}

backend_device_fini :: (using engine: *Engine) {
    if d3d_queue IUnknown_Release(d3d_queue);
    if d3d_queue_w_fence IUnknown_Release(d3d_queue_w_fence);
    if d3d_queue_w_event CloseHandle(xx d3d_queue_w_event);

    #if DEBUG {
        if d3d_device {
            debug_device: *ID3D12DebugDevice;
            ok := IUnknown_QueryInterface(d3d_device, *uid(ID3D12DebugDevice_UUID), xx *debug_device);
            IUnknown_Release(d3d_device);
            if ok == S_OK && debug_device {
                ID3D12DebugDevice_ReportLiveDeviceObjects(debug_device, D3D12_RLDO_FLAGS.DETAIL | .IGNORE_INTERNAL);
                IUnknown_Release(debug_device);
                print_debug_msgs(d3d_info_queue);
            }
        } 
    } else {
        if d3d_device IUnknown_Release(xx d3d_device);
    }

    if d3d_info_queue IUnknown_Release(d3d_info_queue);
}

backend_queue_wait_for_idle :: (using gfx: *Graphics_Device) {
    value: u64 = ID3D12Fence_GetCompletedValue(d3d_queue_w_fence);
    signal_value := value + 10;
    ID3D12CommandQueue_Signal(d3d_queue, d3d_queue_w_fence, signal_value);

    if ID3D12Fence_GetCompletedValue(d3d_queue_w_fence) < signal_value {
        ID3D12Fence_SetEventOnCompletion(d3d_queue_w_fence, signal_value, d3d_queue_w_event);
        WaitForSingleObject(d3d_queue_w_event, 0xffff_ffff);
    }
}