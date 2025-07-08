D3D12Device   :: struct {
    device:     *ID3D12Device;
    #if DEBUG {
        info_queue: *ID3D12InfoQueue;
    }
}

D3D12Renderer :: struct {

    vsync := false;

    factory:        *IDXGIFactory4;
    adapter:        *IDXGIAdapter1;
    swapchain:      *IDXGISwapChain3;
    using _device:   D3D12Device;

    // Sync objects
    queues:         [#run enum_highest_value(Command_Type) + 1] *ID3D12CommandQueue;
    fence:          D3D12Fence;
    fence_event:    HANDLE;

    swapchain_rtvs: [MAX_SWAPCHAIN_BUFFER_COUNT] Swapchain_Buffer;

    // Descriptor Heap
    heap_rtv:       D3D12Descriptor_Heap;
    heap_dsv:       D3D12Descriptor_Heap;
    heaps   :       [D3D12_DESCRIPTOR_HEAP_TYPE.NUM_TYPES] D3D12Descriptor_Heap;

    #if DEBUG {
        debug_layer: *ID3D12Debug1;
    }

    viewport: D3D12_VIEWPORT;
    surface_size: D3D12_RECT;
    
    ctx_buffer_count:           u32;
    ctx_active_buffer_index :   u32;
}

d3d12_renderer_init :: (using renderer: *D3D12Renderer, hwnd: HWND) -> bool {

    ok: bool;
    dxgi_factory_flags: u32 = 0;

    if DEBUG {
        if SUCCEEDED(D3D12GetDebugInterface(*uid(ID3D12Debug1_UUID), xx *debug_layer)) {
            ID3D12Debug1_EnableDebugLayer(debug_layer);
            ID3D12Debug1_SetEnableGPUBasedValidation(debug_layer, .TRUE);
            dxgi_factory_flags |= DXGI_CREATE_FACTORY_DEBUG;
        }
    }

    ok = HR(CreateDXGIFactory2(dxgi_factory_flags, *uid(IDXGIFactory4_UUID), xx *factory));
    if !ok return false;

    warp_adapter_found := false;
    ok = HR(IDXGIFactory4_EnumWarpAdapter(factory, *uid(IDXGIAdapter1_UUID), xx *adapter));
    if  ok {
        result := D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), null);
        if result == 0x1 {
            warp_adapter_found = true;
        }
    } else {
        safe_release_and_reset(*adapter);
    }

    adapter_index: u32 = 0;
    while true && !warp_adapter_found {
        if SUCCEEDED(IDXGIFactory1_EnumAdapters1(factory, adapter_index, *adapter)) {
            desc: DXGI_ADAPTER_DESC1;
            IDXGIAdapter1_GetDesc1(adapter, *desc);

            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG.SOFTWARE) continue;

            result := D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), null);
            if 0x1 == result then break;
        }

        safe_release_and_reset(*adapter);
        adapter_index += 1;
    }

    if !adapter return false;

    ok = HR(D3D12CreateDevice(adapter, ._12_0, *uid(ID3D12Device_UUID), xx *device));
    if !ok return false;

    #if DEBUG {
        if SUCCEEDED(IUnknown_QueryInterface(device, *uid(ID3D12InfoQueue_UUID), xx *info_queue)) {
            #if BREAK_ON_ERROR {
                ID3D12InfoQueue_SetBreakOnSeverity(info_queue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(info_queue, .ERROR, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(info_queue, .WARNING, .TRUE);
            }

            size := ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            }

            size = ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            while size > 1 {
                ID3D12InfoQueue_ClearStorageFilter(info_queue);
                size = ID3D12InfoQueue_GetStorageFilterStackSize(info_queue);
            }

            ID3D12InfoQueue_ClearStoredMessages(info_queue);
            ID3D12InfoQueue_SetMuteDebugOutput(info_queue, .FALSE);
        } 
    }

    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = .NONE;
    queue_desc.Type  = .DIRECT;
    ok = HR(ID3D12Device_CreateCommandQueue(device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *queues[cast(u8) Command_Type.GRAPHICS]), info_queue);
    ok = HR(ID3D12Device_CreateCommandQueue(device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *queues[cast(u8) Command_Type.COMPUTE]),  info_queue);
    ok = HR(ID3D12Device_CreateCommandQueue(device, *queue_desc, *uid(ID3D12CommandQueue_UUID), xx *queues[cast(u8) Command_Type.COPY]),     info_queue);
    if !ok return false;

    ok = d3d12_fence_init(*_device, *fence);
    if !ok return false;
    fence.value = 1;
    fence_event = CreateEventW(null, 0, 0, null);

    ok = d3d12_descriptor_heap_init(*_device, *heap_rtv, .RTV);
    ok = d3d12_descriptor_heap_init(*_device, *heap_dsv, .DSV);
    if !ok return false;

    for i : 0..D3D12_DESCRIPTOR_HEAP_TYPE.NUM_TYPES - 1 {
        d3d12_descriptor_heap_init(*_device, *heaps[i], cast(D3D12_DESCRIPTOR_HEAP_TYPE) i);
    }

    return ok;
}

d3d12_renderer_release  :: (using renderer: *D3D12Renderer) {

    CloseHandle(fence_event);
    d3d12_fence_release(*fence);

    d3d12_descriptor_heap_release(*heap_rtv);
    d3d12_descriptor_heap_release(*heap_dsv);
    for i : 0..D3D12_DESCRIPTOR_HEAP_TYPE.NUM_TYPES - 1 {
        d3d12_descriptor_heap_release(*heaps[i]);
    }
    safe_release_and_reset(*queues[cast(u8) cast(u8) Command_Type.GRAPHICS]);
    safe_release_and_reset(*queues[cast(u8) cast(u8) Command_Type.COMPUTE]);
    safe_release_and_reset(*queues[cast(u8) cast(u8) Command_Type.COPY]);

    #if DEBUG {
        if device {
            debug_device: *ID3D12DebugDevice;
            result := IUnknown_QueryInterface(device, *uid(ID3D12DebugDevice_UUID), xx *debug_device);
            safe_release_and_reset(*device);

            if SUCCEEDED(result) {
                ID3D12DebugDevice_ReportLiveDeviceObjects(debug_device, D3D12_RLDO_FLAGS.DETAIL | .IGNORE_INTERNAL);
                safe_release_and_reset(*debug_device);
                print_debug_msgs(info_queue);
            }
        } 
    }

    safe_release_and_reset(*device);
    safe_release_and_reset(*factory);
    safe_release_and_reset(*adapter);

    #if DEBUG {
        safe_release_and_reset(*info_queue);
        safe_release_and_reset(*debug_layer);
    }
}

d3d12_swapchain_init :: (using renderer: *D3D12Renderer, hwnd: HWND, width: u32, height: u32, format: DXGI_FORMAT = .R8G8B8A8_UNORM, _vsync:= false) -> bool {

    surface_size.left   = 0;
    surface_size.top    = 0;
    surface_size.right  = xx width;
    surface_size.bottom = xx height;

    viewport.TopLeftX = 0.0;
    viewport.TopLeftY = 0.0;
    viewport.Width    = xx width;
    viewport.Height   = xx height;
    viewport.MinDepth = 0.0;
    viewport.MaxDepth = 1.0; 

    ctx_buffer_count = ifx _vsync then cast(u32) 3 else cast(u32) 2;
    vsync = _vsync;

    swapchain_desc: DXGI_SWAP_CHAIN_DESC1;
    swapchain_desc.Width            = width;
    swapchain_desc.Height           = height;
    swapchain_desc.Format           = format;
    swapchain_desc.SampleDesc.Count = 1;
    swapchain_desc.BufferUsage      = .RENDER_TARGET_OUTPUT;
    swapchain_desc.BufferCount      = ctx_buffer_count;
    swapchain_desc.SwapEffect       = .FLIP_SEQUENTIAL;

    ok := HR(IDXGIFactory2_CreateSwapChainForHwnd(factory, xx queues[cast(u8) Command_Type.GRAPHICS], hwnd, *swapchain_desc, null, null, xx *swapchain), info_queue);
    if !ok return false;

    IDXGIFactory_MakeWindowAssociation(factory, hwnd, xx DXGI_MWA.NO_ALT_ENTER);

    rtv_desc: D3D12_RENDER_TARGET_VIEW_DESC;
    rtv_desc.Format         = format;
    rtv_desc.ViewDimension  = .TEXTURE2D;
    rtv_desc.Texture2D.MipSlice     = 0;
    rtv_desc.Texture2D.PlaneSlice   = 0;

    backbuffer_desc : DXGI_MODE_DESC;
    backbuffer_desc.Format = xx format;
    backbuffer_desc.Width  = xx width;
    backbuffer_desc.Height = xx height;

    for i: 0..ctx_buffer_count - 1 {
        ok = HR(IDXGISwapChain_GetBuffer(swapchain, xx i, *uid(ID3D12Resource_UUID), xx *swapchain_rtvs[i].resource));
        swapchain_rtvs[i].desc = backbuffer_desc;
        array_add(*swapchain_rtvs[i].states, .PRESENT);
        array_add(*swapchain_rtvs[i].rtvs, d3d12_descriptor_heap_resource_add(*_device, *heap_rtv, .RTV, swapchain_rtvs[i].resource, xx *rtv_desc));

        if !ok return false;
    }

    return true;
}

d3d12_swapchain_release :: (using renderer: *D3D12Renderer) {

    for swapchain_rtvs {
        safe_release_and_reset(*it.resource);
    }
    safe_release_and_reset(*swapchain);
}

gfx_execute_commands :: (using renderer: *D3D12Renderer, cmds: *D3D12CommandList, counts: u32 = 1) {
    
    lists: [MAX_SUBMIT_COMMANDLIST]*ID3D12CommandList;
    for i: 0..counts {
        lists[i] = cmds[i].cmdlist;
    }

    ID3D12CommandQueue_ExecuteCommandLists(queues[xx Command_Type.GRAPHICS], counts, xx *lists);
}

gfx_insert_signal_fence :: (using renderer: *D3D12Renderer, type: Command_Type) {

    ID3D12CommandQueue_Signal(queues[xx Command_Type.GRAPHICS], fence.fence, fence.value);
    fence.state = .INSERTED;
}

gfx_wait_fence_increment :: (using renderer: *D3D12Renderer) {

    if fence.state == .INSERTED {
        if ID3D12Fence_GetCompletedValue(fence.fence) < fence.value {
            ID3D12Fence_SetEventOnCompletion(fence.fence, fence.value, fence.event);
            WaitForSingleObject(fence.event, INFINITE);
        }
        fence.value += 1;
        fence.state = .FINISHED;
    }
}

gfx_wait_fence :: (using renderer: *D3D12Renderer) {

    if fence.state == .INSERTED {
        if ID3D12Fence_GetCompletedValue(fence.fence) < fence.value {
            ID3D12Fence_SetEventOnCompletion(fence.fence, fence.value, fence.event);
            WaitForSingleObject(fence.event, INFINITE);
        }
        fence.state = .FINISHED;
    }
}

gfx_present :: (using renderer: *D3D12Renderer) {

    ok: bool;
    if vsync ok = HR(IDXGISwapChain_Present(xx swapchain, 1, 0));
    else     ok = HR(IDXGISwapChain_Present(xx swapchain, 0, 0));
    #if DEBUG assert(ok, "IDXGISwapChain_Present failed");
}