Fence_State :: enum {
    UNUSED;
    INSERTED;
    FINISHED;
}

D3D12Fence :: struct {
    fence: *ID3D12Fence;
    value: u64;
    flags: D3D12_FENCE_FLAGS;
    state: Fence_State;
    event: HANDLE;
}

d3d12_fence_init :: (device: *ID3D12Device, using _fence: *D3D12Fence, _flags: D3D12_FENCE_FLAGS = .NONE) -> bool {

    ok: bool;
    ok = HR(ID3D12Device_CreateFence(device, 0, flags, *uid(ID3D12Fence_UUID), xx *fence));
    if !ok return false;

    event = CreateEventW(null, 0, 0, null);
    flags = _flags;
    value = 1;
    state = .UNUSED;

    return ok;
}

d3d12_fence_release :: (using _fence: *D3D12Fence) {

    safe_release_and_reset(*fence);
}