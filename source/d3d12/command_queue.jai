Command_Queue :: #type,isa *ID3D12CommandQueue;

make_command_queue :: (command_queue: *Command_Queue, type: D3D12_COMMAND_LIST_TYPE, flags: D3D12_COMMAND_QUEUE_FLAGS = .NONE) -> bool {

    CheckInit();
    using state.d3d12;

    desc: D3D12_COMMAND_QUEUE_DESC;
    desc.Type   = type;
    desc.Flags  = flags;
    return HR(ID3D12Device_CreateCommandQueue(device, *desc, *uid(ID3D12CommandQueue_UUID), xx command_queue));
}

deinit :: (command_queue: *Command_Queue) {

    safe_release_and_reset(cast(**ID3D12CommandQueue) command_queue);
}