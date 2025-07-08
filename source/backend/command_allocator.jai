D3D12CommandAllocator :: struct {
    type:      Command_Type;
    allocator: *ID3D12CommandAllocator;
}

d3d12_cmd_allocator_init :: (device: *ID3D12Device, cmdallocator: *D3D12CommandAllocator, _type: Command_Type) -> bool {

    ok: bool;
    if _type == {
        case .GRAPHICS;
            ok = HR(ID3D12Device_CreateCommandAllocator(device, .DIRECT, *uid(ID3D12CommandAllocator_UUID), xx *cmdallocator.allocator));
        case .COMPUTE;
            ok = HR(ID3D12Device_CreateCommandAllocator(device, .COMPUTE, *uid(ID3D12CommandAllocator_UUID), xx *cmdallocator.allocator));
        case .COPY;
            ok = HR(ID3D12Device_CreateCommandAllocator(device, .COPY, *uid(ID3D12CommandAllocator_UUID), xx *cmdallocator.allocator));
    }

    return ok;
}

d3d12_cmd_allocator_release :: inline (using _allocator: *D3D12CommandAllocator) { safe_release(allocator); }
d3d12_cmd_allocator_reset   :: inline (using _allocator: *D3D12CommandAllocator, infoqueue: *ID3D12InfoQueue = null) -> bool { return HR(ID3D12CommandAllocator_Reset(allocator), infoqueue); }