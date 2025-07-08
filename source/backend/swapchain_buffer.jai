Swapchain_Buffer :: struct {
    desc: D3D12_RENDER_TARGET_VIEW_DESC;
    resource: *ID3D12Resource;
    state: [..] D3D12_RESOURCE_STATES;
    rtvs:  [..] Handles;
}