Descriptor_Heap :: struct {
    heap: *ID3D12DescriptorHeap;
    size: u32;
}

make_descriptor_heap :: (type: D3D12_DESCRIPTOR_HEAP_TYPE, num_descriptors: u32, flags: D3D12_DESCRIPTOR_HEAP_FLAGS = .NONE, node_make: u32 = 0) -> success: bool, Descriptor_Heap {

    CheckInit();
    using state.d3d12;

    heap: Descriptor_Heap;

    desc: D3D12_DESCRIPTOR_HEAP_DESC;
    desc.Type           = type;
    desc.NumDescriptors = num_descriptors;
    desc.Flags          = flags;
    desc.NodeMask       = 0;
    
    success := HR(ID3D12Device_CreateDescriptorHeap(device, *desc, *uid(ID3D12DescriptorHeap_UUID), xx *heap.heap));
    if !success return false, .{};

    heap.size = ID3D12Device_GetDescriptorHandleIncrementSize(device, type);
    return true, heap;
}

deinit :: (using descriptor_heap: *Descriptor_Heap) {

    safe_release_and_reset(*heap);
}