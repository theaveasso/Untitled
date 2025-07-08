Swapchain_Buffer :: struct {
    desc: DXGI_MODE_DESC;
    resource: *ID3D12Resource;
    states: [..] D3D12_RESOURCE_STATES;
    rtvs:  [..] Handles;
}