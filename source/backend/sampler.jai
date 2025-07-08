D3D12Sampler :: struct {
    desc: D3D12_SAMPLER_DESC;
    sampler: Handles; 
}

make_d3d12_sampler :: (_device: *D3D12Device, using _sampler: *D3D12Sampler, heap: *D3D12Descriptor_Heap) {

    sampler = d3d12_descriptor_heap_sampler_add(_device, heap, *desc);
}