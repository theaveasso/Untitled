UTEditor :: struct {
    desc:       ImplDX12_InitInfo;
    heap_srv:   D3D12Descriptor_Heap;
}

editor_init :: (using editor: *UTEditor, renderer: *D3D12Renderer, hwnd: HWND, rtformat: DXGI_FORMAT = .R8G8B8A8_UNORM, dsformat: DXGI_FORMAT = .UNKNOWN) -> bool {

    if !d3d12_descriptor_heap_init(*renderer._device, *heap_srv) return false;
    heap_handles := d3d12_descriptor_heap_handle_get(*heap_srv, .SRV, 0);

    ImGui.CreateContext();
    io := ImGui.GetIO();
    ImGui.StyleColorsDark();
    
    if !ImplWin32_Init(hwnd) return false;

    desc.Device             = renderer.device;
    desc.CommandQueue       = renderer.queues[xx Command_Type.GRAPHICS];
    desc.NumFramesInFlight  = xx renderer.ctx_buffer_count;
    desc.RTVFormat          = rtformat;
    desc.DSVFormat          = dsformat;
    desc.SrvDescriptorHeap  = heap_srv.heap;
    desc.LegacySingleSrvCpuDescriptor = heap_handles.cpu;
    desc.LegacySingleSrvGpuDescriptor = heap_handles.gpu;
    if !ImplDX12\_Init(*desc) return false;

    return true;
}

editor_fini :: (using editor: *UTEditor) {

    d3d12_descriptor_heap_release(*heap_srv);

    ImplDX12\_Shutdown();
    ImplWin32_Shutdown();
    ImGui.DestroyContext();
}